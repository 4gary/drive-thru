-- Saved progress per player (design doc §7.7, §9.1 "Saves"): nights unlocked, Paychecks, cosmetics,
-- Field Guide, badges, endings, settings, stats. Uses DataStoreService when available and falls
-- back to in-memory saves (with a warning) in Studio without API access.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Cosmetics = require(Shared.Data.Cosmetics)
local Util = require(Shared.Util)
local ctx = require(script.Parent.Context)

local PlayerData = {}

local VERSION = 1

local function template()
	local owned = {}
	for _, item in Cosmetics.List do
		if item.default then
			owned[item.id] = true
		end
	end
	return {
		version = VERSION,
		nightsUnlocked = 1,
		nightResults = {}, -- [tostring(n)] = { grade, stars }
		paychecks = 0,
		owned = owned,
		equipped = Cosmetics.defaults(),
		fieldGuide = {}, -- [anomalyId] = "caught" | "seen"
		badges = {},
		endings = {},
		redeemed = {},
		purchases = {},
		freed = {},
		stats = { lateCaught = 0, boops = 0, served = 0, perfect = 0, nights = 0, fryCount = 0 },
		settings = { reducedFlashing = false, captions = true, fastStart = false },
		activeShift = nil,
		firstJoin = true,
	}
end

local function reconcile(data, base)
	for key, value in base do
		if data[key] == nil then
			data[key] = Util.deepCopy(value)
		elseif type(value) == "table" and type(data[key]) == "table" and next(value) ~= nil and #value == 0 then
			reconcile(data[key], value)
		end
	end
	return data
end

local store: DataStore? = nil
local memoryOnly = false
local profiles: { [Player]: any } = {}
local loaded: { [Player]: boolean } = {}
local dirty: { [Player]: boolean } = {}

local function key(userId: number): string
	return "p_" .. tostring(userId)
end

local function tryStore()
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(Config.DataStoreName)
	end)
	if ok then
		store = result
	else
		memoryOnly = true
		warn("[PlayerData] DataStores unavailable — progress will NOT save this session. (" .. tostring(result) .. ")")
		if RunService:IsStudio() then
			warn("[PlayerData] In Studio: Game Settings > Security > Enable Studio Access to API Services (after publishing) to test saving.")
		end
	end
end

local function load(player: Player)
	local data = nil
	if store and not memoryOnly then
		for attempt = 1, 3 do
			local ok, result = pcall(function()
				return (store :: DataStore):GetAsync(key(player.UserId))
			end)
			if ok then
				data = result
				break
			else
				local message = string.lower(tostring(result))
				if string.find(message, "403") or string.find(message, "studio") or string.find(message, "api") or string.find(message, "publish") then
					memoryOnly = true
					warn("[PlayerData] No API access — saves are in-memory only this session. (" .. tostring(result) .. ")")
					break
				end
				task.wait(attempt)
			end
		end
	end
	if type(data) ~= "table" then
		data = template()
	else
		data = reconcile(data, template())
		data.firstJoin = false
	end
	profiles[player] = data
	loaded[player] = true
	PlayerData.push(player)
end

local function save(player: Player): boolean
	local data = profiles[player]
	if not data or memoryOnly or not store then
		return false
	end
	local copy = Util.deepCopy(data)
	copy.firstJoin = nil
	local ok, err = pcall(function()
		(store :: DataStore):SetAsync(key(player.UserId), copy, { player.UserId })
	end)
	if not ok then
		warn("[PlayerData] save failed for " .. player.Name .. ": " .. tostring(err))
	else
		dirty[player] = nil
	end
	local saved = ok
	-- leaderboard (all-time Late Customers caught)
	pcall(function()
		local board = DataStoreService:GetOrderedDataStore(Config.LeaderboardStoreName)
		board:SetAsync(key(player.UserId), data.stats.lateCaught or 0)
	end)
	return saved
end

function PlayerData.get(player: Player)
	return profiles[player]
end

function PlayerData.waitFor(player: Player)
	local start = os.clock()
	while not loaded[player] and player.Parent and os.clock() - start < 20 do
		task.wait(0.1)
	end
	return profiles[player]
end

function PlayerData.isMemoryOnly(): boolean
	return memoryOnly
end

-- What the client menus need.
function PlayerData.summary(player: Player)
	local data = profiles[player]
	if not data then
		return nil
	end
	return {
		nightsUnlocked = data.nightsUnlocked,
		nightResults = data.nightResults,
		paychecks = data.paychecks,
		owned = data.owned,
		equipped = data.equipped,
		fieldGuide = data.fieldGuide,
		badges = data.badges,
		endings = data.endings,
		freed = data.freed,
		stats = data.stats,
		settings = data.settings,
		firstJoin = data.firstJoin,
		memoryOnly = memoryOnly,
		rejoin = if data.activeShift and data.activeShift.expires and data.activeShift.expires > os.time()
			then { night = data.activeShift.night }
			else nil,
	}
end

local pushQueued: { [Player]: boolean } = {}
function PlayerData.push(player: Player)
	if pushQueued[player] then
		return
	end
	pushQueued[player] = true
	task.delay(0.2, function()
		pushQueued[player] = nil
		if player.Parent then
			ctx.Remotes.Profile:FireClient(player, PlayerData.summary(player))
		end
	end)
end

local function changed(player: Player)
	dirty[player] = true
	PlayerData.push(player)
end

function PlayerData.addPaychecks(player: Player, amount: number)
	local data = profiles[player]
	if data then
		data.paychecks = math.max(0, data.paychecks + math.floor(amount))
		changed(player)
	end
end

function PlayerData.unlockNight(player: Player, night: number)
	local data = profiles[player]
	if data and night > data.nightsUnlocked then
		data.nightsUnlocked = math.min(night, 5)
		changed(player)
	end
end

local GRADE_RANK = { Bronze = 1, Silver = 2, Gold = 3 }
function PlayerData.recordNight(player: Player, night: number, grade: string, stars: number)
	local data = profiles[player]
	if not data then
		return
	end
	local k = tostring(night)
	local prev = data.nightResults[k]
	if not prev or (GRADE_RANK[grade] or 0) > (GRADE_RANK[prev.grade] or 0) then
		data.nightResults[k] = { grade = grade, stars = math.floor(stars * 10) / 10 }
	end
	data.stats.nights += 1
	changed(player)
end

function PlayerData.addFieldGuide(player: Player, anomalyId: string, how: string)
	local data = profiles[player]
	if not data then
		return false
	end
	local current = data.fieldGuide[anomalyId]
	if current == "caught" or current == how then
		return false
	end
	data.fieldGuide[anomalyId] = how
	changed(player)
	return current == nil
end

function PlayerData.markBadge(player: Player, badgeId: string): boolean
	local data = profiles[player]
	if not data or data.badges[badgeId] then
		return false
	end
	data.badges[badgeId] = os.time()
	changed(player)
	return true
end

function PlayerData.addStat(player: Player, stat: string, amount: number?)
	local data = profiles[player]
	if data then
		data.stats[stat] = (data.stats[stat] or 0) + (amount or 1)
		dirty[player] = true
	end
end

function PlayerData.markEnding(player: Player, endingId: string)
	local data = profiles[player]
	if data and not data.endings[endingId] then
		data.endings[endingId] = os.time()
		changed(player)
	end
end

function PlayerData.markFreed(player: Player, anomalyId: string)
	local data = profiles[player]
	if data and not data.freed[anomalyId] then
		data.freed[anomalyId] = true
		changed(player)
	end
end

function PlayerData.own(player: Player, cosmeticId: string)
	local data = profiles[player]
	if data and not data.owned[cosmeticId] then
		data.owned[cosmeticId] = true
		changed(player)
	end
end

function PlayerData.equip(player: Player, slot: string, cosmeticId: string)
	local data = profiles[player]
	if data then
		data.equipped[slot] = cosmeticId
		changed(player)
	end
end

function PlayerData.setSetting(player: Player, settingKey: string, value: any)
	local data = profiles[player]
	if data and data.settings[settingKey] ~= nil and type(value) == type(data.settings[settingKey]) then
		data.settings[settingKey] = value
		changed(player)
		return true
	end
	return false
end

function PlayerData.setActiveShift(player: Player, info: any)
	local data = profiles[player]
	if data then
		data.activeShift = info
		changed(player)
		task.spawn(save, player)
	end
end

function PlayerData.markRedeemed(player: Player, code: string): boolean
	local data = profiles[player]
	if not data or data.redeemed[code] then
		return false
	end
	data.redeemed[code] = os.time()
	changed(player)
	return true
end

function PlayerData.markPurchase(player: Player, purchaseId: string): boolean
	local data = profiles[player]
	if not data or data.purchases[purchaseId] then
		return false
	end
	data.purchases[purchaseId] = os.time()
	changed(player)
	return true
end

function PlayerData.saveNow(player: Player): boolean
	return save(player)
end

function PlayerData.init()
	tryStore()
	Players.PlayerAdded:Connect(load)
	for _, p in Players:GetPlayers() do
		task.spawn(load, p)
	end
	Players.PlayerRemoving:Connect(function(player)
		save(player)
		profiles[player] = nil
		loaded[player] = nil
		dirty[player] = nil
	end)
	game:BindToClose(function()
		if RunService:IsStudio() and memoryOnly then
			return
		end
		for _, p in Players:GetPlayers() do
			task.spawn(save, p)
		end
		task.wait(2)
	end)
	task.spawn(function()
		while true do
			task.wait(Config.AutosaveSeconds)
			for player in dirty do
				task.spawn(save, player)
			end
		end
	end)
	ctx.onRequest("SetSetting", function(player, data)
		local ok = PlayerData.setSetting(player, tostring(data.key), data.value)
		return { ok = ok }
	end)
	ctx.onRequest("GetProfile", function(player)
		PlayerData.waitFor(player)
		return PlayerData.summary(player)
	end)
end

return PlayerData
