-- Locker room shop (design doc §11.3): cosmetics only. Paychecks (earned) or Robux (developer
-- products), plus a one-time Supporter Pass. Never revives, never stats, never mid-shift.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Cosmetics = require(Shared.Data.Cosmetics)
local ctx = require(script.Parent.Context)

local Shop = {}

local productToCosmetic: { [number]: string } = {}

local function inShift(player: Player): boolean
	return ctx.Shift.isCrew(player)
end

local function updateCredits()
	local wall = ctx.map.Lobby:FindFirstChild("CreditsWall")
	local gui = wall and wall:FindFirstChild("Credits")
	local label = gui and gui:FindFirstChild("Label") :: TextLabel?
	if not label then
		return
	end
	local names = {}
	for _, p in Players:GetPlayers() do
		local profile = ctx.PlayerData.get(p)
		if profile and profile.owned.tag_gold then
			table.insert(names, p.DisplayName)
		end
	end
	label.Text = "THANK YOU, SUPPORTERS!\n" .. (if #names > 0 then table.concat(names, "\n") else "(your name here?)")
end

local function checkSupporter(player: Player)
	if Config.SupporterPassId == 0 then
		return
	end
	local ok, owns = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, Config.SupporterPassId)
	end)
	if ok and owns then
		ctx.PlayerData.own(player, "tag_gold")
		updateCredits()
	end
end

function Shop.init()
	for cosmeticKey, productId in Config.DevProducts do
		if productId ~= 0 then
			productToCosmetic[productId] = cosmeticKey
		end
	end

	ctx.onRequest("BuyCosmetic", function(player, data)
		if inShift(player) then
			return { ok = false, message = "The shop is in the lobby locker room. No purchases during shifts. Ever." }
		end
		local item = Cosmetics.ById[tostring(data.id)]
		local profile = ctx.PlayerData.get(player)
		if not item or not profile then
			return { ok = false, message = "Unknown item." }
		end
		if profile.owned[item.id] then
			return { ok = false, message = "You already own that." }
		end
		if item.secret or item.default then
			return { ok = false, message = item.hint or "Not for sale." }
		end
		if item.price then
			if profile.paychecks < item.price then
				return { ok = false, message = ("You need %d more Paychecks."):format(item.price - profile.paychecks) }
			end
			ctx.PlayerData.addPaychecks(player, -item.price)
			ctx.PlayerData.own(player, item.id)
			return { ok = true, message = "Bought " .. item.name .. "!" }
		end
		if item.robux then
			local productId = Config.DevProducts[item.robux] or 0
			if productId == 0 then
				return { ok = false, message = "Not on sale yet. (Developer: add a product id in Config.DevProducts.)" }
			end
			MarketplaceService:PromptProductPurchase(player, productId)
			return { ok = true, prompted = true }
		end
		return { ok = false, message = "Not for sale." }
	end)

	ctx.onRequest("Equip", function(player, data)
		local item = Cosmetics.ById[tostring(data.id)]
		local profile = ctx.PlayerData.get(player)
		if not item or not profile or not profile.owned[item.id] then
			return { ok = false, message = "You don't own that." }
		end
		ctx.PlayerData.equip(player, item.slot, item.id)
		if not player:GetAttribute("Ghost") and not player:GetAttribute("Hidden") then
			ctx.Characters.applyCosmetics(player)
		end
		return { ok = true }
	end)

	ctx.onRequest("BuySupporter", function(player)
		if inShift(player) then
			return { ok = false, message = "Not during a shift." }
		end
		if Config.SupporterPassId == 0 then
			return { ok = false, message = "Supporter Pass isn't set up yet. (Developer: Config.SupporterPassId.)" }
		end
		MarketplaceService:PromptGamePassPurchase(player, Config.SupporterPassId)
		return { ok = true, prompted = true }
	end)

	MarketplaceService.ProcessReceipt = function(info)
		local player = Players:GetPlayerByUserId(info.PlayerId)
		if not player then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		local profile = ctx.PlayerData.waitFor(player)
		if not profile then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		local key = tostring(info.PurchaseId)
		if profile.purchases[key] then
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end
		local cosmeticId = productToCosmetic[info.ProductId]
		if not cosmeticId then
			warn("[Shop] unknown product " .. tostring(info.ProductId))
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		ctx.PlayerData.own(player, cosmeticId)
		ctx.PlayerData.markPurchase(player, key)
		ctx.notify(player, "Thank you! " .. (Cosmetics.ById[cosmeticId] and Cosmetics.ById[cosmeticId].name or cosmeticId) .. " is in your locker.", "good")
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		if purchased and passId == Config.SupporterPassId then
			ctx.PlayerData.own(player, "tag_gold")
			ctx.notify(player, "Thank you for supporting Munchie's! Golden name tag unlocked.", "good")
			updateCredits()
		end
	end)

	Players.PlayerAdded:Connect(function(player)
		ctx.PlayerData.waitFor(player)
		checkSupporter(player)
		updateCredits()
	end)
	Players.PlayerRemoving:Connect(function()
		task.defer(updateCredits)
	end)
end

return Shop
