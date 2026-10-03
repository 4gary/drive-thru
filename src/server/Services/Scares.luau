-- The Scare Director + scare events (design doc §5.3):
--   Rush Hour      Mr. Munch walks the floor. Hide or get booped. (Night 3+; checks hiding spots Night 4+)
--   High Beams     a driverless car's headlights sweep the kitchen. Crouch below the window line. (Night 4+)
--   LightsOutSafe  Night 2's tutorial "hide!" that turns out to be nothing.
-- Pacing rules: a clear warning, never two scares too close together, none in the first minutes,
-- a hard max per night, and a comedy beat after each one.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Layout = require(Shared.Builders.Layout)
local ModelFactory = require(Shared.Builders.ModelFactory)
local ctx = require(script.Parent.Context)

local Scares = {}

local current: any = nil
local queue: { any } = {}
local lastScareEnd = -math.huge
local countThisNight = 0
local generation = 0
local spawned: { Instance } = {}
local hiddenStatue: { [BasePart]: number } = {}

function Scares.active(): boolean
	return current ~= nil
end

function Scares.snapshot()
	if not current then
		return nil
	end
	return { kind = current.kind, phase = current.phase }
end

function Scares.request(id: string, opts: { [string]: any }?)
	table.insert(queue, { id = id, opts = opts or {}, at = os.clock() })
end

---------------------------------------------------------------------------
-- Statue helpers
---------------------------------------------------------------------------

local function statue(): Model?
	return ctx.map.Rooms:FindFirstChild("MunchStatue") :: Model?
end

function Scares.setStatueVisible(visible: boolean)
	local model = statue()
	if not model then
		return
	end
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d.Name ~= "Root" then
			if not visible then
				if hiddenStatue[d] == nil then
					hiddenStatue[d] = d.Transparency
				end
				d.Transparency = 1
			elseif hiddenStatue[d] ~= nil then
				d.Transparency = hiddenStatue[d]
				hiddenStatue[d] = nil
			end
		elseif d:IsA("SurfaceGui") then
			d.Enabled = visible
		end
	end
end

local function cleanupSpawned()
	for _, inst in spawned do
		if inst.Parent then
			inst:Destroy()
		end
	end
	table.clear(spawned)
end

---------------------------------------------------------------------------
-- Vision
---------------------------------------------------------------------------

local function rayParams(exclude: { Instance }): RaycastParams
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local list = table.clone(exclude)
	table.insert(list, ctx.map.Dynamic)
	table.insert(list, ctx.map.Lights)
	for _, p in Players:GetPlayers() do
		if p.Character then
			table.insert(list, p.Character)
		end
	end
	params.FilterDescendantsInstances = list
	return params
end

local function canSee(eye: Vector3, facing: Vector3, player: Player, params: RaycastParams): boolean
	if player:GetAttribute("Hidden") or player:GetAttribute("Ghost") then
		return false
	end
	local character = player.Character
	local head = character and character:FindFirstChild("Head") :: BasePart?
	if not head then
		return false
	end
	local toTarget = head.Position - eye
	local distance = toTarget.Magnitude
	if distance > Config.Munch.ViewRange then
		return false
	end
	local flat = Vector3.new(toTarget.X, 0, toTarget.Z)
	if distance > Config.Munch.HearRange and flat.Magnitude > 0.01 then
		local dot = math.clamp(flat.Unit:Dot(facing), -1, 1)
		if math.deg(math.acos(dot)) > Config.Munch.ViewAngle / 2 then
			return false
		end
	end
	return workspace:Raycast(eye, toTarget, params) == nil
end

---------------------------------------------------------------------------
-- Rush Hour (Mr. Munch)
---------------------------------------------------------------------------

local function nearestWaypointAhead(pos: Vector3, fromIndex: number): number
	local best, bestDist = fromIndex, math.huge
	for i = fromIndex, #Layout.MunchPath do
		local d = (Layout.MunchPath[i] - pos).Magnitude
		if d < bestDist then
			best, bestDist = i, d
		end
	end
	return best
end

local function runMunch(s, gen: number)
	local speedMult = if s.night >= 5 then Config.Munch.Night5SpeedMultiplier else 1
	local walkSpeed = Config.Munch.WalkSpeed * speedMult
	local chaseSpeed = Config.Munch.ChaseSpeed * speedMult
	local munch = ModelFactory.buildMunch({ realMouth = s.flags.revealed == true })
	munch.Name = "MrMunch"
	local root = munch.PrimaryPart :: BasePart
	local path = Layout.MunchPath
	local pos = path[1]
	local facing = (path[2] - path[1]).Unit
	munch:PivotTo(CFrame.lookAt(pos, pos + facing))
	munch.Parent = ctx.map.Dynamic
	table.insert(spawned, munch)
	Scares.setStatueVisible(false)
	local params = rayParams({ munch })
	local index = 2
	local chasing: Player? = nil
	local lastSeen = 0
	local nextScan = 0
	local nextStep = 0
	local pauseUntil = 0
	local knocked: { [string]: boolean } = {}
	local t = 0
	local started = os.clock()
	local freezerHiders: { [Player]: boolean } = {}

	while current and current.gen == gen and ctx.Shift.isRunning() and os.clock() - started < 75 do
		local dt = RunService.Heartbeat:Wait()
		t += dt
		local now = os.clock()
		if now < pauseUntil then
			continue
		end
		local eye = pos + Vector3.new(0, 8.2, 0)

		-- look for crew
		if now >= nextScan then
			nextScan = now + 0.1
			for _, player in ctx.Shift.crewPlayers() do
				if ctx.Hiding.spotOf(player) == "Freezer" then
					freezerHiders[player] = true
				end
			end
			if chasing then
				if canSee(eye, facing, chasing, params) then
					lastSeen = now
				elseif now - lastSeen > Config.Munch.LoseSightSeconds then
					chasing = nil
					index = nearestWaypointAhead(pos, math.max(1, index - 1))
					ctx.caption("[squeak... squeak... slower now]", pos, 2)
				end
			else
				for _, member in ctx.Shift.livingMembers() do
					if canSee(eye, facing, member.player, params) then
						chasing = member.player
						lastSeen = now
						ctx.effect("Spotted", { pos = pos }, { member.player })
						ctx.caption("[SQUEAK-SQUEAK-SQUEAK]", pos, 2)
						break
					end
				end
			end
			-- Night 4+: he checks hiding spots he passes
			if not chasing and s.night >= 4 then
				for _, spotId in Layout.HidingOrder do
					local spot = Layout.HidingSpots[spotId]
					if not knocked[spotId] and (spot.prompt - pos).Magnitude < Config.Munch.KnockCheckRange then
						knocked[spotId] = true
						if #ctx.Hiding.occupants(spotId) > 0 and s.rng:NextNumber() < Config.Munch.KnockChance then
							facing = Vector3.new(spot.prompt.X - pos.X, 0, spot.prompt.Z - pos.Z).Unit
							root.CFrame = CFrame.lookAt(pos, pos + facing)
							local failed = ctx.Hiding.knock(spotId)
							for _, p in failed do
								ctx.Ghosts.boop(p, "Munch")
							end
							pauseUntil = os.clock() + 0.8
						end
					end
				end
			end
			-- Gizmo always hides badly
			if ctx.Gizmo.isHidingNear(pos, 7) then
				ctx.Gizmo.boop("Munch")
			end
		end

		-- move
		local target: Vector3
		local speed: number
		if chasing then
			local character = chasing.Character
			local targetRoot = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if not targetRoot or chasing:GetAttribute("Ghost") or chasing:GetAttribute("Hidden") then
				chasing = nil
				index = nearestWaypointAhead(pos, math.max(1, index - 1))
				continue
			end
			target = Vector3.new(targetRoot.Position.X, Layout.Floor, targetRoot.Position.Z)
			speed = chaseSpeed
			if (target - pos).Magnitude < Config.Munch.BoopDistance then
				local victim = chasing
				chasing = nil
				facing = (target - pos).Magnitude > 0.01 and (target - pos).Unit or facing
				root.CFrame = CFrame.lookAt(pos, pos + facing)
				ctx.Ghosts.boop(victim, "Munch")
				pauseUntil = os.clock() + 1.5
				index = nearestWaypointAhead(pos, math.max(1, index - 1))
				continue
			end
		else
			if index > #path then
				break
			end
			target = path[index]
			speed = walkSpeed
			if (target - pos).Magnitude < 0.6 then
				index += 1
				continue
			end
		end
		local delta = target - pos
		local step = math.min(delta.Magnitude, speed * dt)
		if delta.Magnitude > 0.01 then
			facing = Vector3.new(delta.X, 0, delta.Z).Unit
			pos += delta.Unit * step
		end
		local bob = math.abs(math.sin(t * 7)) * 0.35
		root.CFrame = CFrame.lookAt(pos, pos + facing) * CFrame.new(0, bob, 0)
		if now >= nextStep then
			nextStep = now + (if chasing then 0.28 else 0.55)
			ctx.effect("Squeak", { pos = pos, fast = chasing ~= nil })
		end
	end

	munch:Destroy()
	Scares.setStatueVisible(true)
	for player in freezerHiders do
		if player.Parent then
			ctx.Badges.award(player, "freezer")
		end
	end
end

local function rushHour(s, gen: number, opts)
	local warning = Config.Scare.WarningSeconds[s.night] or 4
	current.phase = "Warning"
	ctx.effect("ScareWarning", { kind = "RushHour", seconds = warning })
	ctx.caption("[the lights flicker... the jingle plays, slowly]", nil, warning)
	if s.data.debOnHeadset and not opts.quiet then
		ctx.radio("Deb", "Lights! HIDE! Hide now, cry later!", 3)
	end
	ctx.Bus:fire("ScareWarning", "RushHour")
	task.wait(warning)
	if not current or current.gen ~= gen then
		return
	end
	current.phase = "Active"
	ctx.effect("ScareActive", { kind = "RushHour" })
	runMunch(s, gen)
end

---------------------------------------------------------------------------
-- High Beams
---------------------------------------------------------------------------

local function highBeams(s, gen: number)
	current.phase = "Warning"
	ctx.effect("ScareWarning", { kind = "HighBeams", seconds = 3 })
	ctx.caption("[an engine revs outside — brights on]", Vector3.new(-60, 3, Layout.LaneZ), 3)
	ctx.sound("Engine", Vector3.new(-60, 3, Layout.LaneZ))
	ctx.Bus:fire("ScareWarning", "HighBeams")
	task.wait(3)
	if not current or current.gen ~= gen then
		return
	end
	current.phase = "Active"
	ctx.effect("ScareActive", { kind = "HighBeams" })
	local K = Layout.KitchenZ
	local beam = Instance.new("Part")
	beam.Name = "HighBeam"
	beam.Size = Vector3.new(Config.HighBeams.BeamWidth, 7, K.max - K.min)
	beam.Color = Color3.fromRGB(255, 240, 160)
	beam.Material = Enum.Material.Neon
	beam.Transparency = 0.72
	beam.Anchored = true
	beam.CanCollide = false
	beam.CanQuery = false
	beam.CanTouch = false
	beam.CastShadow = false
	local light = Instance.new("SpotLight")
	light.Face = Enum.NormalId.Back
	light.Range = 40
	light.Brightness = 5
	light.Color = Color3.fromRGB(255, 240, 180)
	light.Parent = beam
	beam.Parent = ctx.map.Dynamic
	table.insert(spawned, beam)
	local car = ModelFactory.buildCustomer({ person = {}, car = { kind = "Vintage", color = Color3.fromRGB(30, 30, 35) }, modifiers = { "NoDriver" } })
	car.Name = "HighBeamsCar"
	car.Parent = ctx.map.Dynamic
	table.insert(spawned, car)
	local duration = Config.HighBeams.SweepSeconds * (if s.flags.beamsFast then 0.7 else 1)
	local fromX, toX = Layout.HighBeams.fromX, Layout.HighBeams.toX
	local beamY = Layout.Floor + Config.HighBeams.WindowLine + 3.5
	local start = os.clock()
	local honked = false
	while current and current.gen == gen and ctx.Shift.isRunning() do
		local alpha = (os.clock() - start) / duration
		if alpha > 1 then
			break
		end
		local x = fromX + (toX - fromX) * alpha
		beam.CFrame = CFrame.new(x, beamY, (K.min + K.max) / 2)
		car:PivotTo(CFrame.new(x, 0, Layout.LaneZ + 2))
		for _, member in ctx.Shift.livingMembers() do
			local player = member.player
			local character = player.Character
			local head = character and character:FindFirstChild("Head") :: BasePart?
			local rootPart = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if head and rootPart and not player:GetAttribute("Hidden") then
				local p = rootPart.Position
				local inKitchen = p.Z > K.min and p.Z < K.max and math.abs(p.X) < 56
				if inKitchen and math.abs(p.X - x) < Config.HighBeams.BeamWidth / 2 then
					if head.Position.Y > Layout.Floor + Config.HighBeams.WindowLine then
						ctx.effect("Frozen", {}, { player })
						ctx.Ghosts.boop(player, "HighBeams")
					end
				end
				local since = player:GetAttribute("CrouchSince")
				if not honked and since and os.clock() - since > Config.HighBeams.CrouchCampSeconds then
					honked = true
					s.flags.beamsFast = true
					ctx.caption("[HOOOONK — the car doesn't like campers]", Vector3.new(x, 3, Layout.LaneZ), 3)
				end
			end
		end
		if ctx.Gizmo.isHidingNear(Vector3.new(x, 0, 4), Config.HighBeams.BeamWidth) then
			ctx.Gizmo.boop("HighBeams")
		end
		task.wait(0.05)
	end
	beam:Destroy()
	car:Destroy()
end

---------------------------------------------------------------------------
-- Night 2: the safe Lights Out
---------------------------------------------------------------------------

local function lightsOutSafe(s, gen: number)
	current.phase = "Active"
	ctx.effect("ScareWarning", { kind = "LightsOut", seconds = 10, safe = true })
	ctx.caption("[the menu board goes dark. The jingle plays... slowly.]", nil, 4)
	if s.data.debOnHeadset then
		ctx.radio("Deb", "UNDER THE COUNTER. NOW.", 3)
	end
	ctx.Bus:fire("ScareWarning", "LightsOutSafe")
	task.wait(10)
	if not current or current.gen ~= gen then
		return
	end
	if s.data.debOnHeadset then
		ctx.radio("Deb", "...Huh. Nothing happened. Okay. Back to work.", 4)
	end
end

---------------------------------------------------------------------------
-- Director
---------------------------------------------------------------------------

local COMEDY = {
	"Mr. Munch took exactly one fry. He left a gold star sticker on the grill.",
	"A sticky note appears on the stars meter: 'pls don't tell corporate.'",
	"Mr. Munch straightened the napkins on his way out.",
	"The bobblehead is facing the freezer now. It wasn't before.",
}

local function resolve(s, kind: string)
	ctx.effect("ScareEnd", { kind = kind })
	ctx.Bus:fire("ScareEnded", kind)
	if kind == "RushHour" then
		local took = ctx.Stations.removePortions(1)
		for _, p in ctx.Shift.crewPlayers() do
			ctx.PlayerData.addStat(p, "fryCount", 1)
		end
		local line = COMEDY[((countThisNight - 1) % #COMEDY) + 1]
		if took == 0 and countThisNight % #COMEDY == 1 then
			line = "Mr. Munch looked for a fry. There were none. He looked disappointed. Politely."
		end
		ctx.radio("Shift Report", line, 5)
		local star = ModelFactory.buildGoldStar()
		star.CFrame = CFrame.new(Layout.Stations.Grill + Vector3.new(s.rng:NextNumber(-4, 4), 0.2, 0))
		star.Parent = ctx.map.Dynamic
		table.insert(spawned, star)
	elseif kind == "HighBeams" then
		ctx.radio("Shift Report", "The car with no driver idles at the exit... then it's just gone.", 4)
	end
end

local function start(req)
	local s = ctx.Shift.session
	generation += 1
	local gen = generation
	current = { kind = req.id, phase = "Starting", gen = gen }
	if req.id ~= "LightsOutSafe" then
		countThisNight += 1
	end
	task.spawn(function()
		local ok, err = pcall(function()
			if req.id == "RushHour" then
				rushHour(s, gen, req.opts)
			elseif req.id == "HighBeams" then
				highBeams(s, gen)
			elseif req.id == "LightsOutSafe" then
				lightsOutSafe(s, gen)
			end
		end)
		if not ok then
			warn("[Scares] " .. tostring(err))
		end
		if current and current.gen == gen then
			if ctx.Shift.isRunning() then
				resolve(s, req.id)
			end
			lastScareEnd = os.clock()
			current = nil
		end
	end)
end

local function directorTick()
	local s = ctx.Shift.session
	if not s or s.phase ~= "Running" or current then
		return
	end
	local now = os.clock()
	-- Night 5 final rush: Mr. Munch keeps walking until 6 AM
	if s.flags.finalRush and #queue == 0 then
		local gap = math.max(Config.Scare.MinGapFloor, 72 * Config.TimeScale)
		if now - lastScareEnd > gap then
			Scares.request(if countThisNight % 2 == 0 then "RushHour" else "HighBeams", { finalRush = true })
		end
	end
	if #queue == 0 then
		return
	end
	local req = queue[1]
	local forced = req.opts.forced == true
	if req.id ~= "LightsOutSafe" then
		local maxPerNight = Config.Scare.MaxPerNight[s.night] or 0
		if countThisNight >= maxPerNight and not forced then
			table.remove(queue, 1)
			return
		end
		local gapDesign = Config.Scare.MinGapDesign[s.night] or 90
		local gap = math.max(Config.Scare.MinGapFloor, gapDesign * Config.TimeScale)
		if now - lastScareEnd < gap then
			return
		end
		local noFirst = Config.Scare.NoScareFirstDesign * Config.TimeScale
		if now - s.runStart < noFirst and not forced then
			return
		end
	end
	if now - req.at > 90 and not forced then
		table.remove(queue, 1)
		return
	end
	table.remove(queue, 1)
	start(req)
end

function Scares.stop()
	generation += 1
	if current then
		current = nil
		ctx.effect("ScareEnd", { kind = "Stopped" })
	end
	table.clear(queue)
	cleanupSpawned()
	Scares.setStatueVisible(true)
end

function Scares.reset()
	Scares.stop()
	countThisNight = 0
	lastScareEnd = -math.huge
end

function Scares.forceStart(id: string)
	table.insert(queue, 1, { id = id, opts = { forced = true }, at = os.clock() })
	lastScareEnd = -math.huge
end

function Scares.init()
	task.spawn(function()
		while true do
			task.wait(0.25)
			local ok, err = pcall(directorTick)
			if not ok then
				warn("[Scares] director: " .. tostring(err))
			end
		end
	end)
end

return Scares
