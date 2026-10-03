-- Story & lore (design doc §3, §6.2, §7.9): per-night scenery, the Employee of the Month wall
-- (with UV-only writing on the photos), Toby the trainee, Deb's guided first shift, story beats
-- (bobblehead, statue, PlayPlace light), the Night 5 reveal + Final Rush, VHS tapes and endings.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Layout = require(Shared.Builders.Layout)
local ModelFactory = require(Shared.Builders.ModelFactory)
local Anomalies = require(Shared.Data.Anomalies)
local StoryData = require(Shared.Data.Story)
local ctx = require(script.Parent.Context)

local Story = {}

local spawned: { Instance } = {}
local saved: { [Instance]: any } = {}
local tutorial: { [string]: boolean } = {}
local tobyThread: thread? = nil
local defaultFog = { start = 0, finish = 100000, color = Color3.fromRGB(192, 192, 192) }

local function track(inst: Instance)
	table.insert(spawned, inst)
	return inst
end

-- Show/hide a map instance tree without destroying it.
local function setVisible(inst: Instance, visible: boolean)
	local list = inst:GetDescendants()
	table.insert(list, inst)
	for _, d in list do
		if d:IsA("BasePart") then
			if not visible then
				if saved[d] == nil then
					saved[d] = d.Transparency
				end
				d.Transparency = 1
			elseif saved[d] ~= nil then
				d.Transparency = saved[d]
				saved[d] = nil
			end
		elseif d:IsA("SurfaceGui") or d:IsA("BillboardGui") or d:IsA("Light") or d:IsA("ParticleEmitter") then
			if d:IsA("ParticleEmitter") then
				continue
			end
			d.Enabled = visible
		end
	end
end

local function sceneryItem(name: string): Instance?
	return ctx.map.Scenery:FindFirstChild(name)
end

local function setLabel(part: Instance?, guiName: string, text: string)
	local gui = part and part:FindFirstChild(guiName)
	local label = gui and gui:FindFirstChild("Label") :: TextLabel?
	if label then
		label.Text = text
	end
end

---------------------------------------------------------------------------
-- Employee of the Month wall
---------------------------------------------------------------------------

local function photoContent(part: BasePart, photo, night: number)
	for _, child in part:GetChildren() do
		if child:IsA("SurfaceGui") then
			child:Destroy()
		end
	end
	local gui = Instance.new("SurfaceGui")
	gui.Name = "PhotoGui"
	gui.Face = Enum.NormalId.Back
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 60
	gui.LightInfluence = 0.5
	gui.Parent = part
	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(0.86, 0.86)
	frame.Position = UDim2.fromScale(0.07, 0.05)
	frame.BackgroundColor3 = Color3.fromRGB(230, 225, 210)
	frame.BorderSizePixel = 0
	frame.Parent = gui
	local visible = not photo.showFromNight or night >= photo.showFromNight
	if photo.empty or not visible then
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Text = if photo.empty then "YOU?" else ""
		label.TextColor3 = Color3.fromRGB(150, 140, 120)
		label.Font = Enum.Font.FredokaOne
		label.TextScaled = true
		label.Parent = frame
		return
	end
	local skin = Color3.fromRGB(224, 172, 105)
	local hair = Color3.fromRGB(60, 40, 30)
	local anomaly = photo.anomaly and Anomalies.ById[photo.anomaly]
	if anomaly and anomaly.person then
		skin = anomaly.person.skin or skin
		hair = anomaly.person.hairColor or hair
	elseif photo.name == "Deb" then
		skin = Color3.fromRGB(241, 194, 125)
		hair = Color3.fromRGB(150, 150, 155)
	elseif photo.name == "Toby" then
		skin = Color3.fromRGB(255, 224, 189)
		hair = Color3.fromRGB(196, 156, 82)
	end
	local faceHolder = Instance.new("Frame")
	faceHolder.Size = UDim2.fromScale(0.7, 0.55)
	faceHolder.Position = UDim2.fromScale(0.15, 0.12)
	faceHolder.BackgroundTransparency = 1
	faceHolder.Parent = frame
	local hairBar = Instance.new("Frame")
	hairBar.Size = UDim2.fromScale(0.74, 0.12)
	hairBar.Position = UDim2.fromScale(0.13, 0.06)
	hairBar.BackgroundColor3 = hair
	hairBar.BorderSizePixel = 0
	hairBar.Parent = frame
	ModelFactory.drawFace(faceHolder, skin, nil)
	local plate = Instance.new("TextLabel")
	plate.Size = UDim2.fromScale(1, 0.26)
	plate.Position = UDim2.fromScale(0, 0.72)
	plate.BackgroundTransparency = 1
	plate.TextColor3 = Color3.fromRGB(90, 80, 70)
	plate.TextTransparency = 0.35 -- every name plate is slightly faded
	plate.Font = Enum.Font.GothamBold
	plate.TextScaled = true
	plate.Text = ("%s\n%s"):format(photo.name, if photo.year then tostring(photo.year) else "")
	plate.Parent = frame
end

local function uvContent(part: BasePart, photo)
	for _, child in part:GetChildren() do
		if child:IsA("SurfaceGui") then
			child:Destroy()
		end
	end
	local text
	local anomaly = photo.anomaly and Anomalies.ById[photo.anomaly]
	if anomaly and anomaly.photo then
		text = ("THE USUAL:\n%s\n— %s, %d"):format(anomaly.photo.usualText, anomaly.photo.employee, anomaly.photo.year)
	elseif photo.name == "Bart M." then
		text = "THE PROMISE WAS A MISTAKE"
	elseif photo.name == "Toby" then
		text = "NOT A SICK DAY"
	elseif photo.name == "Deb" then
		text = "I'LL HOLD THE DOOR"
	elseif photo.empty then
		text = "CLOCK OUT"
	else
		text = "STILL HERE"
	end
	ModelFactory.surfaceText(part, Enum.NormalId.Back, text, Color3.fromRGB(255, 255, 255), Enum.Font.Arcade)
	ModelFactory.channel(part, "UVOnly")
end

function Story.setupWall(night: number)
	local wall = ctx.map.Rooms:FindFirstChild("EmployeeWall")
	if not wall then
		return
	end
	for i, photo in StoryData.WallPhotos do
		local part = wall:FindFirstChild("Photo" .. i) :: BasePart?
		if part then
			photoContent(part, photo, night)
		end
		local uv = wall:FindFirstChild("PhotoUV" .. i) :: BasePart?
		if uv then
			uvContent(uv, photo)
		end
	end
end

---------------------------------------------------------------------------
-- UV flashlight & VHS
---------------------------------------------------------------------------

function Story.giveUV()
	local s = ctx.Shift.session
	if not s or s.flags.uv then
		return
	end
	s.flags.uv = true
	ctx.notifyCrew("You got SpookyPriya's UV flashlight! Press U (or tap UV) to reveal hidden marks.", "good")
	ctx.effect("UVUnlocked", {})
end

local vhsPrompt: ProximityPrompt? = nil

local function setupVHS()
	local tape = ctx.map.Rooms:FindFirstChild("VHSTape")
	if not tape then
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Watch Tape"
	prompt.ObjectText = "VHS: Training Tape #1"
	prompt.RequiresLineOfSight = false
	prompt.MaxActivationDistance = 9
	prompt.Enabled = false
	prompt.Parent = tape
	vhsPrompt = prompt
	prompt.Triggered:Connect(function(player)
		if not ctx.Shift.canAct(player) then
			return
		end
		local tapeData = StoryData.VHSTapes[1]
		ctx.openPanel(player, "VHS", { title = tapeData.title, lines = tapeData.lines })
		ctx.Badges.award(player, "vhs")
	end)
end

---------------------------------------------------------------------------
-- Toby (Night 1)
---------------------------------------------------------------------------

local TOBY_LINES = {
	"Hi! I'm Toby! I'm in training! ...I'm Toby. In training.",
	"Flip at the sizzle! At the SIZZLE!",
	"Refuse the weird ones! The WEIRD ones!",
	"Deb says don't look at the PlayPlace. I looked. I'm fine. I'm fine.",
	"Hold to pour, let go in the green! Let go. In the green.",
	"Check the mirror at the window! The MIRROR!",
}

local function spawnToby()
	local toby = ModelFactory.buildCustomer({
		person = {
			skin = Color3.fromRGB(255, 224, 189),
			hairStyle = "Short",
			hairColor = Color3.fromRGB(196, 156, 82),
			shirt = Color3.fromRGB(215, 38, 61),
		},
		car = { kind = "None" },
		modifiers = {},
	})
	toby.Name = "Toby"
	local pos = Vector3.new(22, 0, -5)
	toby:PivotTo(CFrame.lookAt(pos, pos + Vector3.new(0, 0, 1)) * CFrame.Angles(0, math.rad(180), 0))
	local torso = toby:FindFirstChild("Torso") :: BasePart?
	if torso then
		local pin = Instance.new("Part")
		pin.Size = Vector3.new(1, 0.4, 0.05)
		pin.Color = Color3.fromRGB(244, 180, 0)
		pin.CFrame = torso.CFrame * CFrame.new(0.4, 0.5, -0.6)
		pin.Anchored = true
		pin.CanCollide = false
		ModelFactory.surfaceText(pin, Enum.NormalId.Front, "IN TRAINING", Color3.fromRGB(30, 30, 30), Enum.Font.GothamBold)
		pin.Parent = toby
	end
	toby.Parent = ctx.map.Dynamic
	track(toby)
	tobyThread = task.spawn(function()
		local i = 0
		while toby.Parent do
			task.wait(28)
			i += 1
			local root = toby.PrimaryPart
			if root and ctx.Shift.isRunning() then
				local fake = { model = toby, root = root }
				ctx.Customers.say(fake, TOBY_LINES[((i - 1) % #TOBY_LINES) + 1], 5)
			end
		end
	end)
end

---------------------------------------------------------------------------
-- Per-night setup
---------------------------------------------------------------------------

local STICKY_NOTES = {
	[4] = {
		{ "Fryer is fine??", Vector3.new(5, 2.6, 6.3) },
		{ "DON'T REFUSE GERALD", Vector3.new(-46, 6.6, 7.1) },
		{ "THE PHOTOS.", Vector3.new(22, 6, -22.6) },
		{ "CLOCK OUT?", Vector3.new(52, 6.4, -12.8) },
		{ "DON'T LOOK AT THE PLAYPLACE", Vector3.new(-56.6, 6, -18) },
	},
	[5] = {
		{ "SERVE THE ONES IN THE PHOTOS", Vector3.new(-46, 6.6, 7.1) },
		{ "THE REAL ORDER IS ON THE BACK (UV)", Vector3.new(22, 6, -22.6) },
		{ "DON'T LOOK AT FRYER", Vector3.new(5, 2.6, 6.3) },
		{ "I'll hold the door. — D", Vector3.new(52, 6.4, -12.8) },
	},
}

local function placeNotes(night: number)
	for _, note in STICKY_NOTES[night] or {} do
		local part = ModelFactory.buildStickyNote(note[1])
		local pos = note[2]
		-- face whichever way is "into the room" from the wall it sits on
		local facing = if pos.Z > 5 then Vector3.new(0, 0, -1) elseif pos.X < -56 then Vector3.new(1, 0, 0) else Vector3.new(0, 0, 1)
		part.CFrame = CFrame.lookAt(pos, pos + facing)
		part.Parent = ctx.map.Dynamic
		track(part)
	end
end

local function setPosters(revealed: boolean)
	local posters = ctx.map.Kitchen:FindFirstChild("Posters")
	if not posters then
		return
	end
	local texts = if revealed then StoryData.Posters.Revealed else StoryData.Posters.Normal
	for i, text in texts do
		setLabel(posters:FindFirstChild("Poster" .. i), "Text", text)
	end
end

local function setOpenSign(text: string)
	local sign = ctx.map.Lane:FindFirstChild("OpenSign")
	setLabel(sign, "OpenText", text)
	setLabel(sign, "OpenTextBack", text)
end

function Story.reset(s)
	Story.cleanup()
	local night = s.night
	local scenery = {}
	for _, name in s.data.scenery or {} do
		scenery[name] = true
	end
	for _, name in { "Balloons", "SafetyPoster", "VisitBanner" } do
		local item = sceneryItem(name)
		if item then
			setVisible(item, scenery[name] == true)
		end
	end
	local rain = sceneryItem("Rain")
	local emitter = rain and rain:FindFirstChild("RainEmitter") :: ParticleEmitter?
	if emitter then
		emitter.Enabled = scenery.Rain == true
	end
	if scenery.Fog or scenery.Rain then
		Lighting.FogStart = 30
		Lighting.FogEnd = if scenery.Rain then 220 else 160
		Lighting.FogColor = Color3.fromRGB(70, 75, 90)
	end
	setOpenSign(if scenery.OpenAlways then "OPEN ALWAYS." else "OPEN LATE. OPEN ALWAYS.")
	setPosters(false)
	Story.setupWall(night)
	placeNotes(night)
	local playLight = ctx.map.Lights:FindFirstChild("PlayPlaceLight")
	local light = playLight and playLight:FindFirstChildOfClass("PointLight")
	if light then
		light.Enabled = false
	end
	if scenery.OfficeEmpty or night >= 4 then
		local coffee = ctx.map.Rooms:FindFirstChild("DebCoffee")
		if coffee and coffee:IsA("BasePart") then
			local steam = Instance.new("Smoke")
			steam.Name = "Steam"
			steam.Size = 0.5
			steam.Opacity = 0.2
			steam.RiseVelocity = 2
			steam.Color = Color3.fromRGB(230, 230, 230)
			steam.Parent = coffee
			track(steam)
		end
	end
	if vhsPrompt then
		vhsPrompt.Enabled = night >= 4
	end
	if night >= 5 then
		s.flags.uv = true
	end
	if night == 1 then
		spawnToby()
	end
	table.clear(tutorial)
	s.flags.tutorial = s.data.tutorial == true and not s.fastStart
end

function Story.cleanup()
	for _, inst in spawned do
		if inst.Parent then
			inst:Destroy()
		end
	end
	table.clear(spawned)
	if tobyThread then
		pcall(task.cancel, tobyThread)
		tobyThread = nil
	end
	Lighting.FogStart = defaultFog.start
	Lighting.FogEnd = defaultFog.finish
	Lighting.FogColor = defaultFog.color
	setPosters(false)
	local rain = sceneryItem("Rain")
	local emitter = rain and rain:FindFirstChild("RainEmitter") :: ParticleEmitter?
	if emitter then
		emitter.Enabled = false
	end
end

---------------------------------------------------------------------------
-- Beats
---------------------------------------------------------------------------

local function bobbleheadFace(target: Vector3)
	local bobble = ctx.map.Kitchen:FindFirstChild("Bobblehead") :: Model?
	if not bobble or not bobble.PrimaryPart then
		return
	end
	local pos = bobble.PrimaryPart.Position
	bobble:PivotTo(CFrame.lookAt(pos, Vector3.new(target.X, pos.Y, target.Z)))
end

local function statueAtWindow(seconds: number)
	ctx.Scares.setStatueVisible(false)
	local statue = ModelFactory.buildMunch({ statue = true, anchored = true, realMouth = true, scale = 0.85 })
	statue.Name = "StatueAtWindow"
	statue:PivotTo(CFrame.lookAt(Layout.StatueAtWindow, Layout.StatueAtWindow + Vector3.new(0, 0, -10)))
	statue.Parent = ctx.map.Dynamic
	track(statue)
	task.delay(seconds, function()
		statue:Destroy()
		ctx.Scares.setStatueVisible(true)
	end)
end

function Story.beat(id: string, param: any?)
	local s = ctx.Shift.session
	if not s then
		return
	end
	if id == "Bobblehead" then
		ctx.effect("Blink", {})
		local target = Vector3.new(-45, 0, -22) -- the freezer
		if param == "Player" then
			local crew = ctx.Shift.crewPlayers()
			local player = crew[s.rng:NextInteger(1, math.max(1, #crew))]
			local root = player and player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root then
				target = root.Position
			end
		end
		bobbleheadFace(target)
		ctx.caption("[...the bobblehead turned.]", Layout.Stations.Bobblehead, 3)
	elseif id == "StatueGone" then
		ctx.Scares.setStatueVisible(false)
		ctx.caption("[something in the PlayPlace is... missing]", Layout.StatuePosition, 3)
	elseif id == "PlayPlaceLight" then
		local playLight = ctx.map.Lights:FindFirstChild("PlayPlaceLight")
		local light = playLight and playLight:FindFirstChildOfClass("PointLight")
		if light then
			light.Enabled = true
		end
		ctx.radio("Deb", "Is the PlayPlace light on? ...It shouldn't be.", 4)
	elseif id == "Reveal" then
		s.flags.revealed = true
		s.flags.uv = true
		ctx.effect("PowerOut", { seconds = 25 })
		ctx.effect("Jingle", { mode = "chorus" })
		for i, line in StoryData.Reveal do
			task.delay((i - 1) * 4, function()
				if ctx.Shift.session == s and s.phase == "Running" then
					ctx.radio("...", line, 4)
				end
			end)
		end
		setPosters(true)
		task.delay(9, function()
			if ctx.Shift.session ~= s or s.phase ~= "Running" then
				return
			end
			statueAtWindow(10)
			ctx.caption("[behind the window. its smile is not painted on.]", Layout.StatueAtWindow, 4)
		end)
	elseif id == "FinalRush" then
		s.flags.finalRush = true
		ctx.radio("Every Speaker", "OPEN. ALWAYS. OPEN. ALWAYS.", 4)
		ctx.caption("[the lane floods with headlights]", nil, 4)
		for _, player in ctx.Shift.crewPlayers() do
			if ctx.Hiding.spotOf(player) == "CostumeCloset" then
				s.flags.mascot = player
			end
		end
	end
end

---------------------------------------------------------------------------
-- Endings
---------------------------------------------------------------------------

function Story.ending(s, outcome: string): string
	local id
	if outcome == "fired" then
		id = "Fired"
	else
		local freed = 0
		for _ in s.stats.freed do
			freed += 1
		end
		id = if freed >= 3 then "Freed" else "Company"
	end
	local data = StoryData.Endings[id]
	local lines = table.clone(data.lines)
	local mascot: Player? = s.flags.mascot
	for _, player in ctx.Shift.crewPlayers() do
		ctx.PlayerData.markEnding(player, id)
		ctx.Badges.award(player, data.badge)
		local personal = table.clone(lines)
		if mascot == player then
			ctx.PlayerData.markEnding(player, "Mascot")
			ctx.PlayerData.own(player, "hat_munch")
			ctx.Badges.award(player, "secret_mascot")
			table.insert(personal, "")
			table.insert(personal, "— SECRET: " .. StoryData.Endings.Mascot.title .. " —")
			for _, line in StoryData.Endings.Mascot.lines do
				table.insert(personal, line)
			end
		end
		ctx.openPanel(player, "Ending", { id = id, title = data.title, lines = personal, credits = StoryData.Credits })
	end
	ctx.effect("EndingScene", { id = id })
	return id
end

---------------------------------------------------------------------------
-- Night 1 guided tutorial (Deb on the headset + station beacons)
---------------------------------------------------------------------------

local function once(key: string): boolean
	if tutorial[key] then
		return false
	end
	tutorial[key] = true
	return true
end

local function tutorialOn(): boolean
	local s = ctx.Shift.session
	return s ~= nil and s.flags.tutorial == true and s.phase == "Running"
end

local function beacon(target: string?)
	ctx.effect("Beacon", { target = target })
end

local function hookTutorial()
	ctx.Bus:on("CarAtSpeaker", function(car)
		if tutorialOn() and car.regularId == "Tutorial" and once("speaker") then
			ctx.radio("Deb", "Car's here. Take the order at the CRT — walk up and press E. You got this.", 5)
			beacon("OrderConsole")
		end
	end)
	ctx.Bus:on("OrderTaken", function(ticket)
		if tutorialOn() and ticket.car.regularId == "Tutorial" and once("ordered") then
			ctx.radio("Deb", "Now cook. Patty on the grill. FLIP it at the sizzle, then take it when it's DONE.", 6)
			beacon("Grill")
		end
	end)
	ctx.Bus:on("PattyTaken", function()
		if tutorialOn() and once("patty") then
			ctx.radio("Deb", "Build it on the plate. Bottom bun, patty, then follow the ticket stack. Top bun last.", 6)
			beacon("AssemblyPlate")
		end
	end)
	ctx.Bus:on("BurgerBuilt", function()
		if tutorialOn() and once("burger") then
			ctx.radio("Deb", "Carry it to the bag counter and bag it. Then fries: drop a basket, pull at the DING.", 6)
			beacon("BagCounter")
		end
	end)
	ctx.Bus:on("ItemBagged", function(_ticket, item)
		if not tutorialOn() then
			return
		end
		if item.kind == "Burger" and once("bagBurger") then
			beacon("Fryer1")
		elseif item.kind == "Fries" and once("bagFries") then
			ctx.radio("Deb", "Drinks: HOLD to pour at the soda fountain. Let go in the green. Don't flood my floor.", 6)
			beacon("SodaFountain")
		elseif item.kind == "Drink" and once("bagDrink") then
			ctx.radio("Deb", "Bag's done! When the car's at the window: inspect them... then HAND OUT.", 6)
			beacon("WindowStation")
		end
	end)
	ctx.Bus:on("FriesPulled", function()
		if tutorialOn() and once("pulled") then
			beacon("FryBin")
		end
	end)
	ctx.Bus:on("CarAtWindow", function(car)
		local s = ctx.Shift.session
		if not s or s.phase ~= "Running" then
			return
		end
		if s.night == 1 and car.anomalyId == "EarlOfEars" and once("earl") then
			ctx.radio("Deb", "...Uh. Look closely.", 4)
			beacon("WindowStation")
		elseif s.night == 2 and car.anomalyId == "MirrorMandy" and once("mandy") then
			ctx.radio("Deb", "Check the side MIRROR on the window screen for this one. Trust me.", 5)
		elseif s.night == 4 and car.regularId == "SpookyPriya" and once("priya") then
			ctx.radio("SpookyPriya", "Hiii! Come to the window! I have something for you!", 4)
		end
	end)
	ctx.Bus:on("Decision", function(car, decision, result)
		local s = ctx.Shift.session
		if not s then
			return
		end
		if car.regularId == "Tutorial" and tutorialOn() then
			beacon(nil)
			if result == "perfect" then
				ctx.radio("Deb", "Ding! A tip! See? Easy. ...Mostly.", 4)
			else
				ctx.radio("Deb", "Close enough. Read the ticket next time, rookie.", 4)
			end
		elseif car.anomalyId == "EarlOfEars" and s.night == 1 then
			beacon(nil)
			if decision == "refuse" then
				ctx.radio("Deb", "GOTCHA. That's a Late Customer. We refuse 'em. Don't count ears out loud.", 6)
			else
				ctx.radio("Deb", "...Okay. We don't serve those. You'll see why.", 5)
			end
		end
	end)
end

function Story.init()
	setupVHS()
	defaultFog = { start = Lighting.FogStart, finish = Lighting.FogEnd, color = Lighting.FogColor }
	hookTutorial()
	ctx.onAction("UsedUV", function(player)
		local s = ctx.Shift.session
		if s and s.flags.uv and ctx.Shift.isCrew(player) then
			ctx.Badges.award(player, "uv")
		end
	end)
	-- show the lobby-facing look (night 1 scenery) when no shift is running
	task.defer(function()
		Story.setupWall(1)
	end)
end

return Story
