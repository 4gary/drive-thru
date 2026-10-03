-- The Shift Director (design doc §8.1): runs a night from pre-shift to the Shift Report.
-- Owns the clock, the night timeline, car spawning, stars, the Weird Meter, crew membership,
-- fail states, grades/rewards and the "next night / retry / lobby" choice.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Nights = require(Shared.Data.Nights)
local Util = require(Shared.Util)
local Layout = require(Shared.Builders.Layout)
local ctx = require(script.Parent.Context)

local Shift = {}
Shift.session = nil :: any

local ROLES = { "Order", "Grill", "Fry", "Window" }
Shift.Roles = ROLES

---------------------------------------------------------------------------
-- Crew helpers
---------------------------------------------------------------------------

function Shift.member(player: Player)
	local s = Shift.session
	if not s then
		return nil
	end
	local m = s.members[player.UserId]
	if m and not m.left then
		return m
	end
	return nil
end

function Shift.isCrew(player: Player): boolean
	return Shift.member(player) ~= nil
end

function Shift.crewPlayers(): { Player }
	local out = {}
	local s = Shift.session
	if not s then
		return out
	end
	for _, m in s.order do
		if not m.left and m.player.Parent == Players then
			table.insert(out, m.player)
		end
	end
	return out
end

function Shift.activeMembers()
	local out = {}
	local s = Shift.session
	if not s then
		return out
	end
	for _, m in s.order do
		if not m.left then
			table.insert(out, m)
		end
	end
	return out
end

function Shift.livingMembers()
	local out = {}
	for _, m in Shift.activeMembers() do
		if not m.ghost then
			table.insert(out, m)
		end
	end
	return out
end

-- Can this player use stations right now?
function Shift.canAct(player: Player): boolean
	local s = Shift.session
	local m = Shift.member(player)
	if not s or not m or m.ghost then
		return false
	end
	if s.phase ~= "Running" then
		return false
	end
	if player:GetAttribute("Hidden") then
		return false
	end
	return player.Character ~= nil
end

function Shift.isRunning(): boolean
	return Shift.session ~= nil and Shift.session.phase == "Running"
end

function Shift.night(): number
	return if Shift.session then Shift.session.night else 0
end

function Shift.roleHolder(role: string)
	for _, m in Shift.activeMembers() do
		if m.role == role then
			return m
		end
	end
	return nil
end

function Shift.spawnCFrameFor(player: Player): CFrame?
	local s = Shift.session
	if not s then
		if ctx.Lobby and ctx.Lobby.isShiftServer() then
			return CFrame.new(Layout.KitchenSpawns[1])
		end
		return nil
	end
	local m = Shift.member(player)
	if not m then
		return nil
	end
	if m.respawning then
		m.respawning = false
		return CFrame.lookAt(Layout.RespawnPoint, Layout.RespawnPoint + Vector3.new(0, 0, 10))
	end
	local index = table.find(s.order, m) or 1
	local pos = Layout.KitchenSpawns[((index - 1) % #Layout.KitchenSpawns) + 1]
	return CFrame.lookAt(pos, pos + Vector3.new(0, 0, 10))
end

---------------------------------------------------------------------------
-- Score
---------------------------------------------------------------------------

function Shift.addStars(delta: number, reason: string?)
	local s = Shift.session
	if not s or s.phase ~= "Running" then
		return
	end
	s.stars = Util.clamp(s.stars + delta, 0, Config.Stars.Max)
	ctx.effect("Stars", { delta = delta, reason = reason })
	if s.stars <= 0 then
		task.defer(Shift.fail, "CorporateCalled")
	end
end

function Shift.addWeird(amount: number)
	local s = Shift.session
	if not s or s.phase ~= "Running" then
		return
	end
	s.weird = Util.clamp(s.weird + amount, 0, 100)
	if s.weird >= 100 then
		s.weird = Config.Weird.OverflowResetTo
		ctx.Badges.awardCrew("peak_weird")
		ctx.radio("Deb", if s.data.debOnHeadset then "The Weird Meter's maxed. Oh no. Oh no no." else "[the speaker hums the jingle. slowly.]")
		if s.night >= 3 then
			ctx.Scares.request("RushHour", { forced = true })
		else
			ctx.Scares.request("LightsOutSafe", { forced = true })
		end
	end
end

function Shift.moment(text: string, priority: number)
	local s = Shift.session
	if s and (not s.momentPriority or priority >= s.momentPriority) then
		s.moment = text
		s.momentPriority = priority
	end
end

---------------------------------------------------------------------------
-- Lifecycle
---------------------------------------------------------------------------

local function newMember(player: Player, role: string)
	return {
		player = player,
		userId = player.UserId,
		name = player.DisplayName,
		role = role,
		ghost = false,
		respawnAt = nil,
		respawning = false,
		boops = 0,
		hid = false,
		left = false,
		ready = false,
	}
end

local function sortedEvents(nightData)
	local events = {}
	for _, e in nightData.events do
		local copy = table.clone(e)
		copy.minute = Util.parseClock(e.t)
		table.insert(events, copy)
	end
	table.sort(events, function(a, b)
		return a.minute < b.minute
	end)
	return events
end

-- params: { players, night, leaderUserId?, mode?, fastStart? }
function Shift.start(params)
	if Shift.session then
		return false
	end
	local night = math.clamp(params.night or 1, 1, Nights.Count)
	local nightData = Nights.get(night)
	local s = {
		id = HttpService:GenerateGUID(false),
		night = night,
		data = nightData,
		members = {},
		order = {},
		leaderUserId = params.leaderUserId,
		mode = params.mode or "InPlace",
		phase = "PreShift",
		preShiftEnd = os.clock() + Config.PreShiftSeconds,
		runStart = 0,
		minutes = 0,
		minuteOffset = 0,
		stars = Config.Stars.Start,
		weird = 0,
		events = sortedEvents(nightData),
		eventIndex = 1,
		nextCarAt = 0,
		randomFrom = Util.parseClock(nightData.randomFrom or "18:30"),
		rng = Random.new(),
		flags = {},
		stats = {
			served = 0,
			perfect = 0,
			wrong = 0,
			caught = 0,
			lateServed = 0,
			lateMissed = 0,
			refusedNormal = 0,
			leftAngry = 0,
			burnt = 0,
			friesBurnt = 0,
			fires = 0,
			freed = {},
			companyRefusals = 0,
			firstCatch = nil,
		},
		fastStart = params.fastStart == true,
		moment = nil,
	}
	Shift.session = s
	for i, player in params.players do
		if player.Parent == Players and #s.order < Config.MaxCrew then
			local m = newMember(player, ROLES[((i - 1) % #ROLES) + 1])
			s.members[player.UserId] = m
			table.insert(s.order, m)
		end
	end
	if #s.order == 0 then
		Shift.session = nil
		return false
	end
	s.leaderUserId = s.leaderUserId or s.order[1].userId
	if s.fastStart then
		s.preShiftEnd = os.clock() + 6
	end

	-- reset the world for this night
	for _, name in { "Stations", "Orders", "Customers", "Window", "Scares", "Hiding", "WeirdEvents", "Ghosts", "Gizmo", "Story" } do
		local service = ctx[name]
		if service and service.reset then
			local ok, err = pcall(service.reset, s)
			if not ok then
				warn(("[Shift] %s.reset failed: %s"):format(name, tostring(err)))
			end
		end
	end

	for _, m in s.order do
		local player = m.player
		player:SetAttribute("Crew", s.id)
		player:SetAttribute("Role", m.role)
		player:SetAttribute("Ghost", false)
		local profile = ctx.PlayerData.get(player)
		if profile then
			profile.firstJoin = false
		end
		ctx.Badges.award(player, "clocked_in")
		ctx.Characters.respawn(player)
	end
	task.delay(0.6, function()
		for _, m in s.order do
			ctx.openPanel(m.player, "PreShift", Shift.preShiftData())
		end
	end)
	ctx.Bus:fire("ShiftStarted", s)
	return true
end

function Shift.preShiftData()
	local s = Shift.session
	local roles = {}
	for _, m in s.order do
		table.insert(roles, { userId = m.userId, name = m.name, role = m.role, ready = m.ready })
	end
	return {
		night = s.night,
		title = s.data.title,
		note = s.data.stickyNote,
		roles = roles,
		endsIn = math.max(0, s.preShiftEnd - os.clock()),
		allRoles = ROLES,
		leader = s.leaderUserId,
	}
end

local function refreshPreShift()
	local s = Shift.session
	if not s or s.phase ~= "PreShift" then
		return
	end
	for _, m in s.order do
		if not m.left then
			ctx.Remotes.OpenPanel:FireClient(m.player, "PreShift", Shift.preShiftData())
		end
	end
end

function Shift.begin()
	local s = Shift.session
	if not s or s.phase ~= "PreShift" then
		return
	end
	s.phase = "Running"
	s.runStart = os.clock()
	s.nextCarAt = os.clock() + 4
	for _, m in s.order do
		ctx.closePanel(m.player, "PreShift")
	end
	if s.data.debOnHeadset then
		for i, line in s.data.intro do
			task.delay((i - 1) * 4, function()
				if Shift.session == s then
					ctx.radio("Deb", line)
				end
			end)
		end
	end
	ctx.effect("ShiftBegin", { night = s.night, title = s.data.title })
	ctx.Bus:fire("ShiftRunning", s)
end

local function gradeFor(s): string
	local lateTotal = s.stats.caught + s.stats.lateServed + s.stats.lateMissed
	local ratio = if lateTotal > 0 then s.stats.caught / lateTotal else 1
	if s.stars >= 4.2 and ratio >= 0.8 then
		return "Gold"
	elseif s.stars >= 3 and ratio >= 0.5 then
		return "Silver"
	end
	return "Bronze"
end

local function boopTitles(s)
	local list = {}
	for _, m in s.order do
		table.insert(list, { name = m.name, boops = m.boops })
	end
	table.sort(list, function(a, b)
		return a.boops > b.boops
	end)
	local titles = {}
	if list[1] and list[1].boops > 0 then
		table.insert(titles, ("Most Booped: %s (%d)"):format(list[1].name, list[1].boops))
	end
	if s.stats.burnt + s.stats.friesBurnt > 0 then
		table.insert(titles, ("Most Haunted Fryer: %d things burnt"):format(s.stats.burnt + s.stats.friesBurnt))
	end
	if ctx.Gizmo and ctx.Gizmo.boops and ctx.Gizmo.boops > 0 then
		table.insert(titles, ("Gizmo got booped %d time%s. Again."):format(ctx.Gizmo.boops, if ctx.Gizmo.boops == 1 then "" else "s"))
	end
	return titles, list
end

local function stopWorld(s)
	for _, name in { "Scares", "WeirdEvents", "Customers", "Gizmo", "Hiding", "Ghosts" } do
		local service = ctx[name]
		if service and service.stop then
			pcall(service.stop, s)
		end
	end
	for _, m in s.order do
		if not m.left then
			ctx.Stations.dropHeld(m.player)
		end
	end
end

local function finishReport(s, success: boolean, reason: string?, endingId: string?)
	s.phase = "Report"
	s.reportDeadline = os.clock() + 120
	local grade = if success then gradeFor(s) else "None"
	local titles, boops = boopTitles(s)
	for _, m in s.order do
		if not m.left and m.player.Parent then
			local player = m.player
			local pay = 0
			if success then
				pay = Config.Pay.Base
					+ Config.Pay.PerStar * math.floor(s.stars)
					+ Config.Pay.PerCatch * s.stats.caught
					+ Config.Pay.PerPerfect * s.stats.perfect
					+ (if grade == "Gold" then Config.Pay.GoldBonus else 0)
				ctx.PlayerData.unlockNight(player, s.night + 1)
				ctx.PlayerData.recordNight(player, s.night, grade, s.stars)
				ctx.Badges.award(player, "night" .. s.night)
				if grade == "Gold" then
					ctx.Badges.award(player, "gold")
					local profile = ctx.PlayerData.get(player)
					if profile then
						local allGold = true
						for n = 1, 5 do
							local r = profile.nightResults[tostring(n)]
							if not r or r.grade ~= "Gold" then
								allGold = false
							end
						end
						if allGold then
							ctx.Badges.award(player, "all_gold")
						end
					end
				end
				if s.night >= 3 and m.boops == 0 and not m.hid then
					ctx.Badges.award(player, "untouchable")
				end
				if s.stats.perfect >= 10 then
					ctx.Badges.award(player, "perfect10")
				end
				if s.stats.burnt >= 3 then
					ctx.Badges.award(player, "well_done")
				end
			else
				pay = math.floor(Config.Pay.Base / 2)
			end
			ctx.PlayerData.addPaychecks(player, pay)
			ctx.PlayerData.setActiveShift(player, nil)
			ctx.openPanel(player, "Report", {
				success = success,
				reason = reason,
				ending = endingId,
				night = s.night,
				title = s.data.title,
				stars = s.stars,
				grade = grade,
				stats = {
					served = s.stats.served,
					perfect = s.stats.perfect,
					caught = s.stats.caught,
					lateServed = s.stats.lateServed,
					lateMissed = s.stats.lateMissed,
					refusedNormal = s.stats.refusedNormal,
					leftAngry = s.stats.leftAngry,
					freed = Util.count(s.stats.freed),
				},
				titles = titles,
				boops = boops,
				bestCatch = s.stats.firstCatch,
				moment = s.moment,
				paychecks = pay,
				canNext = success and s.night < Nights.Count,
				isLeader = m.userId == s.leaderUserId,
				outro = s.data.outro,
			})
		end
	end
	if success and s.data.outro and s.data.outro ~= "" then
		ctx.radio(if s.data.debOnHeadset then "Deb" else "Sticky Note", s.data.outro, 6)
	end
	ctx.Bus:fire("ShiftEnded", s, success)
end

function Shift.complete()
	local s = Shift.session
	if not s or s.phase ~= "Running" then
		return
	end
	s.phase = "Ending"
	stopWorld(s)
	if s.data.finale then
		local endingId = ctx.Story.ending(s, "survived")
		task.delay(14, function()
			if Shift.session == s then
				finishReport(s, true, nil, endingId)
			end
		end)
	else
		finishReport(s, true)
	end
end

function Shift.fail(reason: string)
	local s = Shift.session
	if not s or s.phase ~= "Running" then
		return
	end
	s.phase = "Ending"
	stopWorld(s)
	if reason == "GhostTown" then
		ctx.Badges.awardCrew("ghost_town")
		ctx.effect("GhostTown", {})
	end
	if s.data.finale and reason == "CorporateCalled" then
		local endingId = ctx.Story.ending(s, "fired")
		task.delay(12, function()
			if Shift.session == s then
				finishReport(s, false, reason, endingId)
			end
		end)
		return
	end
	ctx.effect("ShiftFailed", { reason = reason })
	task.delay(4, function()
		if Shift.session == s then
			finishReport(s, false, reason)
		end
	end)
end

-- Ends the session and sends the crew back to the lobby (or teleports them out of a shift server).
function Shift.endSession()
	local s = Shift.session
	if not s then
		return
	end
	stopWorld(s)
	Shift.session = nil
	local players = {}
	for _, m in s.order do
		if not m.left and m.player.Parent == Players then
			local player = m.player
			player:SetAttribute("Crew", nil)
			player:SetAttribute("Role", nil)
			player:SetAttribute("Ghost", false)
			ctx.closePanel(player, "All")
			table.insert(players, player)
		end
	end
	for _, name in { "Customers", "Gizmo", "Orders", "Stations", "Story" } do
		local service = ctx[name]
		if service and service.cleanup then
			pcall(service.cleanup)
		end
	end
	ctx.Bus:fire("SessionEnded", s)
	if s.mode == "Reserved" and #players > 0 then
		task.spawn(function()
			local ok, err = pcall(function()
				TeleportService:TeleportAsync(game.PlaceId, players)
			end)
			if not ok then
				warn("[Shift] teleport back to lobby failed: " .. tostring(err))
				for _, p in players do
					ctx.Characters.respawn(p)
				end
			end
		end)
	else
		for _, p in players do
			ctx.Characters.respawn(p)
		end
	end
end

function Shift.restart(night: number)
	local s = Shift.session
	if not s then
		return
	end
	local players = Shift.crewPlayers()
	local leader = s.leaderUserId
	local mode = s.mode
	stopWorld(s)
	Shift.session = nil
	for _, name in { "Customers", "Gizmo", "Orders", "Stations", "Story" } do
		local service = ctx[name]
		if service and service.cleanup then
			pcall(service.cleanup)
		end
	end
	for _, p in players do
		ctx.closePanel(p, "All")
	end
	Shift.start({ players = players, night = night, leaderUserId = leader, mode = mode })
end

function Shift.choose(player: Player?, choice: string)
	local s = Shift.session
	if not s or s.phase ~= "Report" then
		return
	end
	if player and player.UserId ~= s.leaderUserId then
		local leader = s.members[s.leaderUserId]
		if leader and not leader.left then
			ctx.notify(player, "Waiting for the shift leader to choose...")
			return
		end
	end
	if choice == "next" and s.night < Nights.Count and s.lastSuccess then
		Shift.restart(s.night + 1)
	elseif choice == "retry" then
		Shift.restart(s.night)
	else
		Shift.endSession()
	end
end

---------------------------------------------------------------------------
-- Joining / leaving mid-shift
---------------------------------------------------------------------------

function Shift.addLateMember(player: Player): boolean
	local s = Shift.session
	if not s then
		return false
	end
	local existing = s.members[player.UserId]
	if existing then
		existing.player = player
		existing.left = false
		existing.ghost = false
		player:SetAttribute("Crew", s.id)
		player:SetAttribute("Role", existing.role)
		ctx.Characters.respawn(player)
		ctx.notifyCrew(existing.name .. " clocked back in! (reconnected)")
		return true
	end
	if #Shift.activeMembers() >= Config.MaxCrew then
		return false
	end
	local m = newMember(player, ROLES[(#s.order % #ROLES) + 1])
	s.members[player.UserId] = m
	table.insert(s.order, m)
	player:SetAttribute("Crew", s.id)
	player:SetAttribute("Role", m.role)
	ctx.Characters.respawn(player)
	ctx.notifyCrew(m.name .. " joined the shift!")
	return true
end

local function onPlayerRemoving(player: Player)
	local s = Shift.session
	if not s then
		return
	end
	local m = s.members[player.UserId]
	if not m or m.left then
		return
	end
	m.left = true
	ctx.Stations.dropHeld(player)
	if ctx.Hiding then
		ctx.Hiding.forget(player)
	end
	if #Shift.activeMembers() == 0 then
		task.defer(function()
			if Shift.session == s then
				stopWorld(s)
				Shift.session = nil
				for _, name in { "Customers", "Gizmo", "Orders", "Stations", "Story" } do
					local service = ctx[name]
					if service and service.cleanup then
						pcall(service.cleanup)
					end
				end
				ctx.Bus:fire("SessionEnded", s)
			end
		end)
		return
	end
	if s.leaderUserId == player.UserId then
		s.leaderUserId = Shift.activeMembers()[1].userId
	end
	ctx.notifyCrew(m.name .. " left the shift. Gizmo will cover.")
end

---------------------------------------------------------------------------
-- Tick
---------------------------------------------------------------------------

local function carInterval(s): number
	local base = Config.CarInterval[s.night] or 25
	local minutes = s.minutes
	local rush = (minutes >= 60 and minutes <= 120) or (minutes >= 420 and minutes <= 480)
	if rush then
		base *= Config.RushMultiplier
	end
	local crew = math.max(1, #Shift.activeMembers())
	base /= 1 + Config.CrewIntervalFactor * (crew - 1)
	return base * s.rng:NextNumber(0.85, 1.15)
end

local function handleEvent(s, e)
	if e.kind == "radio" then
		ctx.radio(e.who, e.text)
	elseif e.kind == "note" then
		ctx.effect("StickyNote", { text = e.text })
	elseif e.kind == "customer" then
		ctx.Customers.enqueueScripted(e.id)
	elseif e.kind == "scare" then
		if e.ifWeird and s.weird < e.ifWeird then
			return
		end
		ctx.Scares.request(e.id, { scheduled = true })
	elseif e.kind == "beat" then
		ctx.Story.beat(e.id, e.param)
	end
end

local lastBroadcast = 0
local function tick(dt: number)
	local s = Shift.session
	if not s then
		return
	end
	local now = os.clock()
	if s.phase == "PreShift" then
		local allReady = true
		for _, m in Shift.activeMembers() do
			if not m.ready then
				allReady = false
			end
		end
		if now >= s.preShiftEnd or allReady then
			Shift.begin()
		end
	elseif s.phase == "Running" then
		s.minutes = math.min(Config.NightEndMinute, (now - s.runStart) / Config.SecondsPerGameHour * 60 + s.minuteOffset)
		while s.events[s.eventIndex] and s.events[s.eventIndex].minute <= s.minutes do
			local e = s.events[s.eventIndex]
			s.eventIndex += 1
			task.spawn(handleEvent, s, e)
		end
		if s.minutes >= s.randomFrom and now >= s.nextCarAt then
			if ctx.Customers.spawnNext() then
				s.nextCarAt = now + carInterval(s)
			else
				s.nextCarAt = now + 2
			end
		elseif s.minutes < s.randomFrom and ctx.Customers.hasScripted() and now >= s.nextCarAt then
			ctx.Customers.spawnNext(true)
			s.nextCarAt = now + 2
		end
		local passive = (Config.Weird.PassivePerNight[s.night] or 10) / (12 * Config.SecondsPerGameHour)
		s.weird = math.min(99, s.weird + passive * dt)
		if s.minutes >= Config.NightEndMinute then
			Shift.complete()
		end
	elseif s.phase == "Report" then
		if now > (s.reportDeadline or math.huge) then
			Shift.endSession()
		end
	end
	if Shift.session and now - lastBroadcast > 0.25 then
		lastBroadcast = now
		local snapshot = Shift.snapshot()
		for _, p in Shift.crewPlayers() do
			ctx.Remotes.State:FireClient(p, snapshot)
		end
	end
end

function Shift.snapshot()
	local s = Shift.session
	local now = os.clock()
	local crew = {}
	for _, m in s.order do
		if not m.left then
			table.insert(crew, {
				userId = m.userId,
				name = m.name,
				role = m.role,
				ghost = m.ghost,
				respawnIn = if m.respawnAt then math.max(0, m.respawnAt - now) else nil,
				hidden = m.player:GetAttribute("Hidden"),
			})
		end
	end
	return {
		phase = s.phase,
		night = s.night,
		title = s.data.title,
		clock = Util.formatClock(s.minutes),
		minutes = s.minutes,
		stars = s.stars,
		weird = s.weird,
		crew = crew,
		leader = s.leaderUserId,
		tickets = ctx.Orders.snapshot(),
		lane = ctx.Customers.snapshot(),
		scare = ctx.Scares.snapshot(),
		weirdEvents = ctx.WeirdEvents.snapshot(),
		flags = { uv = s.flags.uv == true, revealed = s.flags.revealed == true, doilies = s.flags.doilies == true, finalRush = s.flags.finalRush == true },
		gizmo = if ctx.Gizmo then ctx.Gizmo.snapshot() else nil,
		fryBin = ctx.Stations.fryPortions(),
	}
end

function Shift.debugSkip(minutes: number)
	local s = Shift.session
	if s and s.phase == "Running" then
		s.minuteOffset += minutes
	end
end

function Shift.init()
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	ctx.onAction("PickRole", function(player, data)
		local s = Shift.session
		local m = Shift.member(player)
		if s and m and table.find(ROLES, data.role) then
			m.role = data.role
			player:SetAttribute("Role", m.role)
			refreshPreShift()
		end
	end)
	ctx.onAction("Ready", function(player)
		local m = Shift.member(player)
		if m then
			m.ready = true
			refreshPreShift()
		end
	end)
	ctx.onAction("Choose", function(player, data)
		if Shift.isCrew(player) then
			Shift.choose(player, tostring(data.choice))
		end
	end)
	ctx.Bus:on("ShiftEnded", function(s, success)
		s.lastSuccess = success
	end)
	task.spawn(function()
		local last = os.clock()
		while true do
			task.wait(0.1)
			local now = os.clock()
			local ok, err = pcall(tick, now - last)
			if not ok then
				warn("[Shift] tick error: " .. tostring(err))
			end
			last = now
		end
	end)
end

return Shift
