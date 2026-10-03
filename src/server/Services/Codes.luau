-- The corporate fax machine: redeem codes (design doc §11.4). Built-in codes live in Data/Codes;
-- live-ops can add more without an update by writing a table to the "LiveCodes" key of the
-- "NightShift_LiveOps" DataStore, e.g. { NEWCODE = { reward = { paychecks = 50 }, message = "..." } }.

local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CodeData = require(Shared.Data.Codes)
local Cosmetics = require(Shared.Data.Cosmetics)
local ctx = require(script.Parent.Context)

local Codes = {}

local liveCodes: { [string]: any } = {}

local function lookup(code: string)
	return liveCodes[code] or CodeData[code]
end

function Codes.init()
	task.spawn(function()
		local ok, result = pcall(function()
			return DataStoreService:GetDataStore("NightShift_LiveOps"):GetAsync("LiveCodes")
		end)
		if ok and type(result) == "table" then
			for code, entry in result do
				if type(code) == "string" and type(entry) == "table" then
					liveCodes[string.upper(code)] = entry
				end
			end
		end
	end)

	ctx.onRequest("RedeemCode", function(player, data)
		local code = string.upper((string.gsub(tostring(data.code or ""), "%s", "")))
		if code == "" then
			return { ok = false, message = "The fax machine beeps at you." }
		end
		local entry = lookup(code)
		if not entry then
			return { ok = false, message = "INVALID CODE. Corporate is disappointed." }
		end
		if entry.expires and os.time() > entry.expires then
			return { ok = false, message = "That code has expired." }
		end
		if not ctx.PlayerData.markRedeemed(player, code) then
			return { ok = false, message = "You already redeemed that one." }
		end
		local reward = entry.reward or {}
		if reward.paychecks then
			ctx.PlayerData.addPaychecks(player, reward.paychecks)
		end
		if reward.cosmetic and Cosmetics.ById[reward.cosmetic] then
			ctx.PlayerData.own(player, reward.cosmetic)
		end
		ctx.Badges.award(player, "fax")
		return { ok = true, message = entry.message or "Code redeemed!" }
	end)
end

return Codes
