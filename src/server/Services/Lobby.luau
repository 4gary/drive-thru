-- The Munchie's Parking Lot (design doc §7.1, §7.10): clock-in booths (party up, pick a night,
-- Solo / Friends / Public), sending crews to a private shift server (reserved servers when the game
-- is published; in-place in Studio), reconnect, Quick Start, the leaderboard and the lobby TV.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Layout = require(Shared.Builders.Layout)
local Nights = require(Shared.Data.Nights)
local Util = require(Shared.Util)
local ctx = require(script.Parent.Context)

local Lobby = {}

local booths: { [string]: any } = {}
local playerBooth: { [Player]: string } = {}
local rejected: { [Player]: string } = {}
local friendCache: { [string]: boolean } = {}
local shiftServer = false
local reserved: any = nil
local nameCache: { [number]: string } = {}

function Lobby.isShiftServer(): boolean
	return shiftServer
end

local function hosting(): string
	if Config.HostingMode == "InPlace" or RunService:IsStudio() then
		return "InPlace"
	end
	return "Reserved"
end

local function unlockedFor(player: Player): number
	local profile = ctx.PlayerData.get(player)
	return if profile then profile.nightsUnlocked else 1
end

local function isFriend(a: Player, b: Player): boolean
	local key = math.min(a.UserId, b.UserId) .. ":" .. math.max(a.UserId, b.UserId)
	if friendCache[key] == nil then
		local ok, result = pcall(function()
			return a:IsFriendsWithAsync(b.UserId)
		end)
		friendCache[key] = ok and result == true
	end
	return friendCache[key]
end

---------------------------------------------------------------------------
-- Booths
---------------------------------------------------------------------------

local function resetBooth(booth)
	booth.members = {}
	booth.leader = nil
	booth.countdownEnd = nil
	booth.privacy = "Public"
	booth.night = 1
end

local function leaveBooth(player: Player)
	local id = playerBooth[player]
	if not id then
		return
	end
	playerBooth[player] = nil
	local booth = booths[id]
	local index = table.find(booth.members, player)
	if index then
		table.remove(booth.members, index)
	end
	if #booth.members == 0 then
		resetBooth(booth)
	elseif booth.leader == player then
		booth.leader = booth.members[1]
		booth.night = math.min(booth.night, unlockedFor(booth.leader))
		ctx.notify(booth.leader, "You're the shift leader now.")
	end
end

local function joinBooth(player: Player, booth): boolean
	if #booth.members == 0 then
		booth.members = { player }
		booth.leader = player
		booth.night = unlockedFor(player)
		booth.privacy = "Public"
		booth.countdownEnd = os.clock() + Config.BoothCountdown
		playerBooth[player] = booth.id
		return true
	end
	if #booth.members >= Config.MaxCrew then
		return false
	end
	if booth.privacy == "Solo" then
		return false
	end
	if booth.privacy == "Friends" and not isFriend(player, booth.leader) then
		return false
	end
	table.insert(booth.members, player)
	playerBooth[player] = booth.id
	booth.countdownEnd = math.max(booth.countdownEnd or 0, os.clock() + 6)
	return true
end

local function launchInPlace(players: { Player }, night: number, leader: Player?, fastStart: boolean): boolean
	if ctx.Shift.session then
		for _, p in players do
			ctx.notify(p, "Another crew is on shift in this server's kitchen. Hang tight!", "warn")
		end
		return false
	end
	return ctx.Shift.start({
		players = players,
		night = night,
		leaderUserId = if leader then leader.UserId else nil,
		mode = "InPlace",
		fastStart = fastStart,
	})
end

local function launchReserved(players: { Player }, night: number, leader: Player?, fastStart: boolean)
	local ok, code = pcall(function()
		return TeleportService:ReserveServer(game.PlaceId)
	end)
	if not ok then
		warn("[Lobby] ReserveServer failed, running in-place: " .. tostring(code))
		launchInPlace(players, night, leader, fastStart)
		return
	end
	local crew = {}
	for _, p in players do
		table.insert(crew, p.UserId)
		ctx.PlayerData.setActiveShift(p, { code = code, night = night, expires = os.time() + Config.RejoinWindowSeconds })
		ctx.notify(p, "Clocking in... heading to your private shift.", "good")
	end
	local options = Instance.new("TeleportOptions")
	options.ReservedServerAccessCode = code
	options:SetTeleportData({ night = night, crew = crew, leader = if leader then leader.UserId else crew[1], fastStart = fastStart })
	local tpOk, err = pcall(function()
		TeleportService:TeleportAsync(game.PlaceId, players, options)
	end)
	if not tpOk then
		warn("[Lobby] teleport failed, running in-place: " .. tostring(err))
		for _, p in players do
			ctx.PlayerData.setActiveShift(p, nil)
		end
		launchInPlace(players, night, leader, fastStart)
	end
end

local function launch(booth)
	local players = {}
	for _, p in booth.members do
		if p.Parent == Players then
			table.insert(players, p)
		end
	end
	local night = booth.night
	local leader = booth.leader
	if #players == 0 then
		resetBooth(booth)
		return
	end
	local leaderProfile = leader and ctx.PlayerData.get(leader)
	local fastStart = leaderProfile ~= nil and leaderProfile.settings.fastStart == true
	if hosting() == "InPlace" then
		if launchInPlace(players, night, leader, fastStart) then
			for _, p in players do
				playerBooth[p] = nil
			end
			resetBooth(booth)
		else
			booth.countdownEnd = os.clock() + Config.BoothCountdown
		end
	else
		for _, p in players do
			playerBooth[p] = nil
		end
		resetBooth(booth)
		task.spawn(launchReserved, players, night, leader, fastStart)
	end
end

local function boothDisplay(booth)
	local display = ctx.map.Lobby:FindFirstChild("Booth" .. booth.id .. "Display")
	local gui = display and display:FindFirstChild("Display")
	local label = gui and gui:FindFirstChild("Label") :: TextLabel?
	if not label then
		return
	end
	if #booth.members == 0 then
		label.Text = "CLOCK IN " .. booth.id .. "\nStep on the pad to start a shift"
		return
	end
	local names = {}
	for _, p in booth.members do
		table.insert(names, p.DisplayName)
	end
	local nightData = Nights.get(booth.night)
	local remaining = math.max(0, math.ceil((booth.countdownEnd or os.clock()) - os.clock()))
	label.Text = ("NIGHT %d: %s\n%s (%d/%d) • %s\nClocking in: %ds"):format(booth.night, nightData.title, table.concat(names, ", "), #booth.members, Config.MaxCrew, booth.privacy, remaining)
end

local function updateBooths()
	local now = os.clock()
	for _, player in Players:GetPlayers() do
		if ctx.Shift.isCrew(player) or shiftServer then
			if playerBooth[player] then
				leaveBooth(player)
			end
			continue
		end
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local inside: string? = nil
		if root then
			for _, b in Layout.Lobby.Booths do
				local offset = root.Position - b.position
				if math.abs(offset.X) < Layout.Lobby.BoothSize / 2 and math.abs(offset.Z) < Layout.Lobby.BoothSize / 2 and offset.Y < 12 then
					inside = b.id
				end
			end
		end
		local current = playerBooth[player]
		if current ~= inside then
			if current then
				leaveBooth(player)
			end
			if inside then
				if rejected[player] ~= inside then
					if not joinBooth(player, booths[inside]) then
						rejected[player] = inside
						local booth = booths[inside]
						ctx.notify(player, if booth.privacy == "Solo" then "That crew is going solo." elseif #booth.members >= Config.MaxCrew then "That crew is full." else "That crew is friends-only.", "warn")
					end
				end
			else
				rejected[player] = nil
			end
		end
	end
	for _, booth in booths do
		if #booth.members > 0 and booth.countdownEnd and now >= booth.countdownEnd then
			launch(booth)
		end
		boothDisplay(booth)
	end
end

---------------------------------------------------------------------------
-- Lobby state for menus
---------------------------------------------------------------------------

local function lobbyState(player: Player)
	local list = {}
	for _, b in Layout.Lobby.Booths do
		local booth = booths[b.id]
		local names = {}
		for _, p in booth.members do
			table.insert(names, p.DisplayName)
		end
		table.insert(list, {
			id = booth.id,
			members = names,
			leader = if booth.leader then booth.leader.DisplayName else nil,
			isMember = playerBooth[player] == booth.id,
			isLeader = booth.leader == player,
			night = booth.night,
			nightTitle = Nights.get(booth.night).title,
			privacy = booth.privacy,
			countdown = if booth.countdownEnd then math.max(0, booth.countdownEnd - os.clock()) else nil,
		})
	end
	local profile = ctx.PlayerData.get(player)
	local s = ctx.Shift.session
	return {
		booths = list,
		myBooth = playerBooth[player],
		unlocked = if profile then profile.nightsUnlocked else 1,
		kitchenBusy = s ~= nil and s.mode == "InPlace",
		shiftServer = shiftServer,
		waitingForCrew = shiftServer and s == nil,
		rejoin = if profile and profile.activeShift and profile.activeShift.expires and profile.activeShift.expires > os.time()
			then { night = profile.activeShift.night }
			else nil,
		firstJoin = profile ~= nil and profile.firstJoin == true,
		hosting = hosting(),
	}
end

local tvIndex = 0
local TEASERS = {
	"MUNCHIE'S TV\n♪ Munch munch munchie's, the late-night lunchie's ♪",
	"TONIGHT ON MUNCHIE'S TV:\nThe Hendersons have... more kids?",
	"CORPORATE REMINDER:\nSMILING IS MANDATORY",
	"NEWS AT 11:\nLocal water tower: 'We're still here.'",
	"LATE CUSTOMER POLICY:\nDo not serve them.",
}

local function updateTV()
	local tv = ctx.map.Lobby:FindFirstChild("LobbyTV")
	local gui = tv and tv:FindFirstChild("Screen")
	local label = gui and gui:FindFirstChild("Label") :: TextLabel?
	if not label then
		return
	end
	local s = ctx.Shift.session
	if s and s.phase == "Running" then
		local names = {}
		for _, m in ctx.Shift.activeMembers() do
			table.insert(names, m.name .. (if m.ghost then " 👻" else ""))
		end
		label.Text = ("LIVE FROM THE KITCHEN\nNight %d: %s\n%s — %.1f★\n%s"):format(s.night, s.data.title, Util.formatClock(s.minutes), s.stars, table.concat(names, ", "))
	else
		tvIndex += 1
		label.Text = TEASERS[((tvIndex - 1) % #TEASERS) + 1]
	end
end

local function nameFor(userId: number): string
	if nameCache[userId] then
		return nameCache[userId]
	end
	local player = Players:GetPlayerByUserId(userId)
	if player then
		nameCache[userId] = player.DisplayName
		return player.DisplayName
	end
	local ok, name = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	nameCache[userId] = if ok then name else ("Crew #" .. userId)
	return nameCache[userId]
end

local function updateLeaderboard()
	local board = ctx.map.Lobby:FindFirstChild("Leaderboard")
	local gui = board and board:FindFirstChild("Board")
	local label = gui and gui:FindFirstChild("Label") :: TextLabel?
	if not label then
		return
	end
	local rows = {}
	local ok = pcall(function()
		local store = DataStoreService:GetOrderedDataStore(Config.LeaderboardStoreName)
		local page = store:GetSortedAsync(false, 10):GetCurrentPage()
		for i, entry in page do
			local userId = tonumber(string.match(entry.key, "%d+") or "0") or 0
			table.insert(rows, ("%d. %s — %d"):format(i, nameFor(userId), entry.value))
		end
	end)
	if not ok or #rows == 0 then
		local list = {}
		for _, p in Players:GetPlayers() do
			local profile = ctx.PlayerData.get(p)
			table.insert(list, { name = p.DisplayName, value = if profile then profile.stats.lateCaught or 0 else 0 })
		end
		table.sort(list, function(a, b)
			return a.value > b.value
		end)
		for i, entry in list do
			if i > 10 then
				break
			end
			table.insert(rows, ("%d. %s — %d"):format(i, entry.name, entry.value))
		end
	end
	label.Text = "TOP LATE-CUSTOMER CATCHERS\n" .. (if #rows > 0 then table.concat(rows, "\n") else "Be the first!")
end

---------------------------------------------------------------------------
-- Reserved shift servers
---------------------------------------------------------------------------

local function onShiftServerJoin(player: Player)
	local data = player:GetJoinData()
	local tpData = data and data.TeleportData
	if not reserved and type(tpData) == "table" then
		reserved = {
			night = tonumber(tpData.night) or 1,
			crew = if type(tpData.crew) == "table" then tpData.crew else {},
			leader = tpData.leader,
			fastStart = tpData.fastStart == true,
			startAt = os.clock() + Config.ReservedWaitForCrew,
			arrived = {},
		}
	end
	if ctx.Shift.session then
		if not ctx.Shift.addLateMember(player) then
			ctx.notify(player, "This shift is full. Sending you back to the lot...")
			task.delay(3, function()
				pcall(function()
					TeleportService:TeleportAsync(game.PlaceId, { player })
				end)
			end)
		end
		return
	end
	if reserved then
		table.insert(reserved.arrived, player)
	end
end

local function shiftServerTick()
	if ctx.Shift.session or not reserved then
		return
	end
	local arrived = {}
	for _, p in reserved.arrived do
		if p.Parent == Players then
			table.insert(arrived, p)
		end
	end
	if #arrived == 0 then
		return
	end
	local everyone = #arrived >= #reserved.crew
	if everyone or os.clock() >= reserved.startAt then
		ctx.Shift.start({ players = arrived, night = reserved.night, leaderUserId = reserved.leader, mode = "Reserved", fastStart = reserved.fastStart })
		reserved.arrived = {}
	end
end

---------------------------------------------------------------------------

function Lobby.init()
	shiftServer = game.PrivateServerId ~= "" and game.PrivateServerOwnerId == 0
	for _, b in Layout.Lobby.Booths do
		local booth = { id = b.id }
		resetBooth(booth)
		booths[b.id] = booth
	end
	Players.PlayerRemoving:Connect(function(player)
		leaveBooth(player)
		rejected[player] = nil
	end)
	if shiftServer then
		Players.PlayerAdded:Connect(onShiftServerJoin)
		for _, p in Players:GetPlayers() do
			onShiftServerJoin(p)
		end
	end

	-- lobby prompts
	local lobby = ctx.map.Lobby
	local function lobbyPrompt(partName: string, action: string, object: string, panel: string)
		local part = lobby:FindFirstChild(partName)
		if not part then
			return
		end
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = action
		prompt.ObjectText = object
		prompt.RequiresLineOfSight = false
		prompt.MaxActivationDistance = 10
		prompt.Parent = part
		prompt.Triggered:Connect(function(player)
			if not ctx.Shift.isCrew(player) then
				ctx.openPanel(player, panel, ctx.PlayerData.summary(player))
			end
		end)
	end
	lobbyPrompt("Locker", "Open Locker", "Locker Room", "Locker")
	lobbyPrompt("Fax", "Use Fax", "Corporate Fax", "Fax")
	lobbyPrompt("FieldGuideKiosk", "Read", "Field Guide & Badges", "FieldGuide")

	ctx.onAction("Booth", function(player, data)
		local id = playerBooth[player]
		local booth = id and booths[id]
		if not booth or booth.leader ~= player then
			return
		end
		if data.op == "night" then
			local n = math.floor(tonumber(data.value) or 1)
			if n >= 1 and n <= math.min(Nights.Count, unlockedFor(player)) then
				booth.night = n
			end
		elseif data.op == "privacy" and (data.value == "Solo" or data.value == "Friends" or data.value == "Public") then
			booth.privacy = data.value
			if data.value == "Solo" then
				for _, p in table.clone(booth.members) do
					if p ~= player then
						leaveBooth(p)
						rejected[p] = id
						ctx.notify(p, "The leader switched to Solo.")
					end
				end
			end
			table.clear(rejected)
		elseif data.op == "start" then
			booth.countdownEnd = os.clock()
		end
	end)

	ctx.onRequest("QuickStart", function(player, data)
		if ctx.Shift.isCrew(player) then
			return { ok = false }
		end
		leaveBooth(player)
		local profile = ctx.PlayerData.get(player)
		local night = math.clamp(math.floor(tonumber(data.night) or (if profile and profile.firstJoin then 1 else unlockedFor(player))), 1, unlockedFor(player))
		local fastStart = profile ~= nil and profile.settings.fastStart == true
		if hosting() == "InPlace" then
			local ok = launchInPlace({ player }, night, player, fastStart)
			return { ok = ok, message = if ok then nil else "The kitchen is busy. Try a clock-in pad, or wait a moment." }
		end
		task.spawn(launchReserved, { player }, night, player, fastStart)
		return { ok = true }
	end)

	ctx.onRequest("Rejoin", function(player)
		local profile = ctx.PlayerData.get(player)
		local info = profile and profile.activeShift
		if not info or not info.code or (info.expires or 0) < os.time() then
			return { ok = false, message = "No shift to rejoin." }
		end
		local options = Instance.new("TeleportOptions")
		options.ReservedServerAccessCode = info.code
		local ok, err = pcall(function()
			TeleportService:TeleportAsync(game.PlaceId, { player }, options)
		end)
		if not ok then
			ctx.PlayerData.setActiveShift(player, nil)
			return { ok = false, message = "That shift has closed. (" .. tostring(err) .. ")" }
		end
		return { ok = true }
	end)

	task.spawn(function()
		local lastSlow = 0
		while true do
			task.wait(0.25)
			local ok, err = pcall(function()
				if shiftServer then
					shiftServerTick()
				else
					updateBooths()
				end
				for _, player in Players:GetPlayers() do
					if not ctx.Shift.isCrew(player) then
						ctx.Remotes.LobbyState:FireClient(player, lobbyState(player))
					end
				end
			end)
			if not ok then
				warn("[Lobby] " .. tostring(err))
			end
			if os.clock() - lastSlow > 8 then
				lastSlow = os.clock()
				task.spawn(updateTV)
			end
		end
	end)
	task.spawn(function()
		while true do
			pcall(updateLeaderboard)
			task.wait(60)
		end
	end)
end

return Lobby
