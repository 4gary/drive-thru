-- Client effects: the three lighting states (normal / weird / scare) + power-out + dawn, light
-- flicker (with a reduced-flashing option), captions with direction, scare vignette, BOOP flash,
-- banners, beacons, pings, quick-chat bubbles, the pour meter and client-side weird events.
-- Design doc §6.2 (lighting states), §6.5 (accessibility: every audio cue has a visual twin).

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local Anomalies = require(Shared.Data.Anomalies)
local Kit = require(script.Parent.Parent.UI.Kit)
local State = require(script.Parent.State)
local Audio = require(script.Parent.Audio)

local T = Kit.Theme
local player = Players.LocalPlayer

local Effects = {}

local gui: ScreenGui
local root: Frame
local captionList: Frame
local bannerFrame: Frame
local flash: Frame
local vignette: { Frame } = {}
local pourBar: Frame
local cc: ColorCorrectionEffect

---------------------------------------------------------------------------
-- Lighting
---------------------------------------------------------------------------

local lightState = "Normal"
local overrides: { [string]: number } = {} -- state -> until (os.clock)
local LIGHT_COLORS = {
	Normal = Color3.fromRGB(255, 240, 210),
	Weird = Color3.fromRGB(200, 255, 190),
	Scare = Color3.fromRGB(255, 50, 40),
	Out = Color3.fromRGB(200, 20, 20),
	Dawn = Color3.fromRGB(255, 200, 150),
}

local function interiorLights(): { BasePart }
	local out = {}
	for _, p in CollectionService:GetTagged("InteriorLight") do
		if p:IsA("BasePart") then
			table.insert(out, p)
		end
	end
	return out
end

local function setLights(color: Color3, brightness: number, on: boolean)
	for _, part in interiorLights() do
		local light = part:FindFirstChildOfClass("PointLight")
		if light then
			light.Color = color
			light.Brightness = brightness
			light.Enabled = on
		end
		part.Color = color
		part.Material = if on then Enum.Material.Neon else Enum.Material.SmoothPlastic
	end
end

local function desiredState(): string
	local now = os.clock()
	for _, name in { "Dawn", "Out", "Scare" } do
		if (overrides[name] or 0) > now then
			return name
		end
	end
	local shift = State.shift
	if State.isCrew() and shift then
		if shift.scare and (shift.scare.phase == "Active" or shift.scare.phase == "Warning") then
			return "Scare"
		end
		if (shift.weird or 0) >= 50 or (shift.flags and shift.flags.revealed) then
			return "Weird"
		end
	end
	return "Normal"
end

local function applyLightState(stateName: string)
	lightState = stateName
	if stateName == "Normal" then
		setLights(LIGHT_COLORS.Normal, 1.15, true)
		TweenService:Create(cc, TweenInfo.new(1), { TintColor = Color3.new(1, 1, 1), Saturation = 0, Brightness = 0, Contrast = 0 }):Play()
	elseif stateName == "Weird" then
		setLights(LIGHT_COLORS.Weird, 1.0, true)
		TweenService:Create(cc, TweenInfo.new(2), { TintColor = Color3.fromRGB(225, 255, 225), Saturation = 0.15, Brightness = -0.03, Contrast = 0.05 }):Play()
	elseif stateName == "Scare" then
		setLights(LIGHT_COLORS.Scare, 0.8, true)
		TweenService:Create(cc, TweenInfo.new(0.4), { TintColor = Color3.fromRGB(255, 190, 190), Saturation = -0.2, Brightness = -0.08, Contrast = 0.15 }):Play()
	elseif stateName == "Out" then
		setLights(LIGHT_COLORS.Out, 0.5, true)
		TweenService:Create(cc, TweenInfo.new(0.2), { TintColor = Color3.fromRGB(255, 140, 140), Saturation = -0.4, Brightness = -0.2, Contrast = 0.2 }):Play()
	elseif stateName == "Dawn" then
		setLights(LIGHT_COLORS.Dawn, 0.6, true)
		TweenService:Create(cc, TweenInfo.new(3), { TintColor = Color3.fromRGB(255, 225, 190), Saturation = 0.1, Brightness = 0.1, Contrast = 0 }):Play()
	end
end

function Effects.flicker(count: number, interval: number?)
	local gap = interval or 0.12
	if State.setting("reducedFlashing") then
		-- a gentle dip instead of strobing
		setLights(LIGHT_COLORS[lightState] or LIGHT_COLORS.Normal, 0.3, true)
		task.delay(count * gap * 2, function()
			applyLightState(desiredState())
		end)
		return
	end
	task.spawn(function()
		for _ = 1, count do
			setLights(LIGHT_COLORS[lightState] or LIGHT_COLORS.Normal, 0, false)
			task.wait(gap)
			setLights(LIGHT_COLORS[lightState] or LIGHT_COLORS.Normal, 1.15, true)
			task.wait(gap * 1.5)
		end
		applyLightState(desiredState())
	end)
end

---------------------------------------------------------------------------
-- Overlays
---------------------------------------------------------------------------

local function directionText(pos: Vector3?): string
	local camera = workspace.CurrentCamera
	if not pos or not camera then
		return ""
	end
	local rel = camera.CFrame:PointToObjectSpace(pos)
	local distance = rel.Magnitude
	if distance < 6 then
		return " — right here"
	end
	local side
	if rel.Z > 0 and math.abs(rel.X) < rel.Z then
		side = "behind"
	elseif math.abs(rel.X) > math.abs(rel.Z) * 0.6 then
		side = if rel.X < 0 then "left" else "right"
	else
		side = "ahead"
	end
	return " — " .. side
end

function Effects.caption(text: string, pos: Vector3?, duration: number?)
	if not State.setting("captions") then
		return
	end
	local label = Kit.label(captionList, text .. directionText(pos), {
		Size = UDim2.new(1, 0, 0, 30),
		BackgroundTransparency = 0.35,
		BackgroundColor3 = Color3.new(0, 0, 0),
		TextColor3 = Color3.fromRGB(255, 245, 210),
		Font = T.bold,
		MaxText = 22,
	})
	Kit.corner(label, 8)
	label.LayoutOrder = math.floor(os.clock() * 100)
	while #captionList:GetChildren() > 5 do
		local oldest: Instance? = nil
		for _, c in captionList:GetChildren() do
			if c:IsA("TextLabel") then
				oldest = c
				break
			end
		end
		if oldest then
			oldest:Destroy()
		else
			break
		end
	end
	task.delay(duration or 3, function()
		if label.Parent then
			Kit.fade(label, 1, 0.4)
			task.wait(0.45)
			label:Destroy()
		end
	end)
end

function Effects.banner(title: string, subtitle: string?, color: Color3?, duration: number?)
	Kit.clear(bannerFrame)
	local card = Kit.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(640, if subtitle then 130 else 90),
		BackgroundColor3 = color or T.ketchup,
		BackgroundTransparency = 0.05,
		Parent = bannerFrame,
	})
	Kit.corner(card, 18)
	Kit.stroke(card, T.mustard, 3)
	Kit.label(card, title, {
		Size = UDim2.new(1, -20, 0, 70),
		Position = UDim2.fromOffset(10, 6),
		Font = T.title,
		TextColor3 = T.white,
		MaxText = 56,
	})
	if subtitle then
		Kit.label(card, subtitle, {
			Size = UDim2.new(1, -20, 0, 44),
			Position = UDim2.fromOffset(10, 78),
			Font = T.bold,
			TextColor3 = T.paper,
			MaxText = 22,
		})
	end
	local scale = Kit.new("UIScale", { Scale = 0.6, Parent = card })
	TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	task.delay(duration or 2.8, function()
		if card.Parent then
			TweenService:Create(scale, TweenInfo.new(0.2), { Scale = 0.01 }):Play()
			task.wait(0.22)
			card:Destroy()
		end
	end)
end

function Effects.flash(color: Color3, text: string?, duration: number?)
	flash.BackgroundColor3 = color
	flash.BackgroundTransparency = 0
	local label = flash:FindFirstChild("Label") :: TextLabel
	label.Text = text or ""
	label.TextTransparency = 0
	TweenService:Create(flash, TweenInfo.new(duration or 0.9), { BackgroundTransparency = 1 }):Play()
	TweenService:Create(label, TweenInfo.new((duration or 0.9) + 0.3), { TextTransparency = 1 }):Play()
end

local vignetteTween: { Tween } = {}
function Effects.vignette(color: Color3?, on: boolean, pulse: boolean?)
	for _, t in vignetteTween do
		t:Cancel()
	end
	table.clear(vignetteTween)
	for _, f in vignette do
		local gradient = f:FindFirstChildOfClass("UIGradient")
		if gradient then
			gradient.Color = ColorSequence.new(color or T.bad)
		end
		f.BackgroundColor3 = color or T.bad
		f.Visible = on
		f.BackgroundTransparency = 0.2
		if on and pulse then
			local tween = TweenService:Create(f, TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { BackgroundTransparency = 0.6 })
			tween:Play()
			table.insert(vignetteTween, tween)
		end
	end
end

---------------------------------------------------------------------------
-- Beacons, pings, bubbles
---------------------------------------------------------------------------

local beaconInstances: { Instance } = {}
function Effects.beacon(target: string?)
	for _, inst in beaconInstances do
		inst:Destroy()
	end
	table.clear(beaconInstances)
	if not target then
		return
	end
	local map = workspace:FindFirstChild("Munchies")
	local kitchen = map and map:FindFirstChild("Kitchen")
	local part = kitchen and kitchen:FindFirstChild(target)
	if not part or not part:IsA("BasePart") then
		return
	end
	local highlight = Instance.new("Highlight")
	highlight.FillColor = T.mustard
	highlight.FillTransparency = 0.5
	highlight.OutlineColor = T.white
	highlight.Adornee = part
	highlight.Parent = part
	table.insert(beaconInstances, highlight)
	local arrow = Instance.new("BillboardGui")
	arrow.Size = UDim2.fromOffset(120, 60)
	arrow.StudsOffset = Vector3.new(0, 4.5, 0)
	arrow.AlwaysOnTop = true
	arrow.Adornee = part
	local label = Kit.label(arrow, "▼ HERE", { Size = UDim2.fromScale(1, 1), Font = T.title, TextColor3 = T.mustard, TextStrokeTransparency = 0 })
	TweenService:Create(label, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Position = UDim2.fromOffset(0, 10) }):Play()
	arrow.Parent = part
	table.insert(beaconInstances, arrow)
end

local function showPing(data)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.Shape = Enum.PartType.Ball
	part.Size = Vector3.new(1.2, 1.2, 1.2)
	part.Material = Enum.Material.Neon
	part.Color = if data.ghost then Color3.fromRGB(200, 220, 255) else T.mustard
	part.Position = data.position
	part.Parent = workspace:FindFirstChild("ClientFx") or workspace
	local bill = Instance.new("BillboardGui")
	bill.Size = UDim2.fromOffset(170, 44)
	bill.StudsOffset = Vector3.new(0, 2.5, 0)
	bill.AlwaysOnTop = true
	bill.Adornee = part
	Kit.label(bill, (if data.ghost then "👻 " else "📍 ") .. tostring(data.name), {
		Size = UDim2.fromScale(1, 1),
		Font = T.title,
		TextColor3 = part.Color,
		TextStrokeTransparency = 0.2,
	})
	bill.Parent = part
	TweenService:Create(part, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Size = Vector3.new(2, 2, 2) }):Play()
	task.delay(data.duration or 3, function()
		part:Destroy()
	end)
end

local function showBubble(userId: number, text: string)
	local other = Players:GetPlayerByUserId(userId)
	local head = other and other.Character and other.Character:FindFirstChild("Head")
	if not head then
		return
	end
	local old = head:FindFirstChild("QuickChatBubble")
	if old then
		old:Destroy()
	end
	local bill = Instance.new("BillboardGui")
	bill.Name = "QuickChatBubble"
	bill.Size = UDim2.fromOffset(220, 50)
	bill.StudsOffset = Vector3.new(0, 3.2, 0)
	bill.AlwaysOnTop = true
	bill.MaxDistance = 120
	local label = Kit.label(bill, text, {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 0,
		BackgroundColor3 = T.paper,
		TextColor3 = T.ink,
		Font = T.title,
	})
	Kit.corner(label, 12)
	bill.Parent = head
	task.delay(3.5, function()
		bill:Destroy()
	end)
	if other ~= player then
		Effects.caption(("%s: %s"):format(other.DisplayName, text), nil, 3)
	end
end

---------------------------------------------------------------------------
-- Pour meter
---------------------------------------------------------------------------

local pourToken = 0
local function startPour(data)
	pourToken += 1
	local token = pourToken
	pourBar.Visible = true
	local fill = pourBar:FindFirstChild("Fill") :: Frame
	local zone = pourBar:FindFirstChild("Zone") :: Frame
	local label = pourBar:FindFirstChild("Label") :: TextLabel
	local maxFill = 1.3
	zone.Position = UDim2.fromScale(data.perfect / maxFill, 0)
	zone.Size = UDim2.fromScale((1 - data.perfect) / maxFill, 1)
	label.Text = "HOLD... let go in the GREEN"
	local start = os.clock()
	task.spawn(function()
		while token == pourToken do
			local amount = data.fill + (os.clock() - start) / data.seconds
			fill.Size = UDim2.fromScale(math.min(1, amount / maxFill), 1)
			fill.BackgroundColor3 = if amount >= data.perfect and amount <= 1 then T.good elseif amount > 1 then T.bad else (if data.kind == "Shake" then Color3.fromRGB(240, 150, 190) else Color3.fromRGB(77, 160, 230))
			if amount > 1 then
				label.Text = "OVERFLOWING!"
			end
			RunService.RenderStepped:Wait()
		end
	end)
end

local function stopPour()
	pourToken += 1
	task.delay(0.4, function()
		pourBar.Visible = false
	end)
end

---------------------------------------------------------------------------
-- Weird events on the client
---------------------------------------------------------------------------

local mirrored = false
local controlsHooked = false
local function hookControls()
	if controlsHooked then
		return
	end
	controlsHooked = true
	task.spawn(function()
		local ok, err = pcall(function()
			local playerModule = require(player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule") :: ModuleScript) :: any
			local controls = playerModule:GetControls()
			local original = controls.moveFunction
			if type(original) ~= "function" then
				return
			end
			controls.moveFunction = function(p, direction: Vector3, relative: boolean)
				if mirrored then
					direction = Vector3.new(-direction.X, direction.Y, direction.Z)
				end
				return original(p, direction, relative)
			end
		end)
		if not ok then
			warn("[Effects] couldn't hook controls for Mirror Mess: " .. tostring(err))
		end
	end)
end

local function weirdEvent(data)
	Effects.banner(data.banner or data.name, data.description, T.uv, 3.5)
	Audio.play("Gotcha", { speed = 0.35 })
	if data.duration and data.duration > 0 then
		State.flags[data.id] = os.clock() + data.duration
	else
		State.flags[data.id] = math.huge
	end
	if data.id == "MirrorMess" and State.isCrew() then
		hookControls()
		mirrored = true
		task.delay(data.duration, function()
			mirrored = false
		end)
	elseif data.id == "MandatoryFun" and State.isCrew() then
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			pcall(function()
				humanoid:PlayEmote("cheer")
			end)
			task.delay(2, function()
				pcall(function()
					humanoid:PlayEmote("dance")
				end)
			end)
		end
	end
end

function Effects.flagActive(id: string): boolean
	return (State.flags[id] or 0) > os.clock()
end

local hidingHighlights: { Instance } = {}
function Effects.highlightHidingSpots(on: boolean)
	for _, h in hidingHighlights do
		h:Destroy()
	end
	table.clear(hidingHighlights)
	if not on or not State.isCrew() or State.isGhost() then
		return
	end
	local map = workspace:FindFirstChild("Munchies")
	local spots = map and map:FindFirstChild("HidingSpots")
	if not spots then
		return
	end
	for _, spot in spots:GetChildren() do
		if spot:IsA("BasePart") then
			local bill = Instance.new("BillboardGui")
			bill.Size = UDim2.fromOffset(110, 40)
			bill.AlwaysOnTop = true
			bill.MaxDistance = 80
			bill.Adornee = spot
			local label = Kit.label(bill, "HIDE", { Size = UDim2.fromScale(1, 1), Font = T.title, TextColor3 = T.bad, TextStrokeTransparency = 0 })
			TweenService:Create(label, TweenInfo.new(0.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { TextTransparency = 0.6 }):Play()
			bill.Parent = spot
			table.insert(hidingHighlights, bill)
		end
	end
end

---------------------------------------------------------------------------
-- Effect dispatch
---------------------------------------------------------------------------

local lastSqueakCaption = 0
local handlers = {}

handlers.Sound = function(data)
	Audio.play(data.name, { pos = data.pos })
end
handlers.Stars = function() end -- HUD shows these
handlers.ShiftBegin = function(data)
	Effects.banner(("NIGHT %d"):format(data.night), data.title, T.ketchup, 3.5)
	Audio.jingle("normal")
end
handlers.ShiftFailed = function(data)
	if data.reason == "CorporateCalled" then
		Effects.banner("CORPORATE CALLED", "The stars hit zero. Shift over.", T.bad, 4)
	end
end
handlers.GhostTown = function()
	Effects.banner("GHOST TOWN", "Store closed early. Everyone got booped.", T.navy, 4)
end
handlers.ScareWarning = function(data)
	if data.kind == "RushHour" then
		Effects.flicker(3)
		Audio.jingle("slow")
		Effects.vignette(T.bad, true, true)
		Effects.banner("HIDE!", "The lights flickered three times...", T.bad, 2.5)
	elseif data.kind == "HighBeams" then
		Effects.vignette(Color3.fromRGB(255, 220, 90), true, true)
		Effects.banner("HEADS DOWN!", "Crouch below the window line (C) or get out of the light", T.warn, 2.5)
	elseif data.kind == "LightsOut" then
		overrides.Out = os.clock() + (data.seconds or 10)
		Effects.flicker(2)
		Audio.jingle("slow")
		Effects.vignette(T.bad, true, true)
		Effects.banner("UNDER THE COUNTER!", "Hide! (F at a hiding spot)", T.bad, 3)
		task.delay(data.seconds or 10, function()
			Effects.vignette(nil, false)
		end)
	end
	Effects.highlightHidingSpots(true)
end
handlers.ScareActive = function(data)
	if data.kind == "RushHour" then
		Effects.caption("[squeak... squeak... big shoes]", nil, 3)
	end
end
handlers.ScareEnd = function()
	Effects.vignette(nil, false)
	Effects.highlightHidingSpots(false)
	task.defer(function()
		applyLightState(desiredState())
	end)
end
handlers.Squeak = function(data)
	Audio.play("Squeak", { pos = data.pos, speed = if data.fast then 2.1 else 1.7 })
	if os.clock() - lastSqueakCaption > 1.4 then
		lastSqueakCaption = os.clock()
		Effects.caption(if data.fast then "[SQUEAK-SQUEAK-SQUEAK]" else "[squeak... squeak...]", data.pos, 1.4)
	end
end
handlers.Spotted = function()
	Effects.flash(T.bad, "!", 0.5)
	Audio.play("Boop", { speed = 0.6 })
end
handlers.Frozen = function()
	Effects.flash(Color3.fromRGB(255, 240, 150), "FROZEN IN THE HEADLIGHTS", 1.2)
end
handlers.Booped = function(data)
	Effects.flash(Color3.new(1, 1, 1), "BOOP!", 1.4)
	Audio.play("Boop")
	task.delay(0.5, function()
		Audio.play("Pwoomp")
		Effects.banner("...oh no.", ("You're a Shift Ghost. Back in %d seconds."):format(math.floor(data.seconds or 30)), T.navy, 3.5)
	end)
end
handlers.CrewBooped = function(data)
	if data.userId ~= player.UserId then
		Audio.play("Pwoomp", { pos = data.pos })
		Effects.caption(("[slide whistle — %s got BOOPED]"):format(data.name), data.pos, 3)
	end
end
handlers.Boo = function(data)
	Audio.play("Note", { pos = data.pos, speed = 0.35, volume = 0.5 })
	Effects.caption(("[oooOOOooo — %s]"):format(data.name), data.pos, 2)
	-- flicker the nearest light, locally
	local nearest, best = nil, math.huge
	for _, part in interiorLights() do
		local d = (part.Position - data.pos).Magnitude
		if d < best then
			nearest, best = part, d
		end
	end
	if nearest and best < 40 then
		local light = nearest:FindFirstChildOfClass("PointLight")
		if light then
			light.Enabled = false
			task.delay(0.25, function()
				light.Enabled = true
			end)
		end
	end
end
handlers.Blink = function()
	Effects.flicker(1, 0.2)
end
handlers.PowerOut = function(data)
	overrides.Out = os.clock() + (data.seconds or 20)
	applyLightState("Out")
	Effects.banner("THE POWER DIES", "Emergency lights only.", T.bad, 4)
end
handlers.Jingle = function(data)
	Audio.jingle(data.mode)
end
handlers.Beacon = function(data)
	Effects.beacon(data.target)
end
handlers.Pour = startPour
handlers.PourEnd = stopPour
handlers.WeirdEvent = weirdEvent
handlers.WeirdEventEnd = function(data)
	State.flags[data.id] = nil
	if data.id == "MirrorMess" then
		mirrored = false
	end
end
handlers.Gotcha = function(data)
	Effects.banner("GOTCHA!", ("%s refused. Nice catch."):format(data.name), T.good, 2.5)
	Audio.play("Gotcha")
end
handlers.Freed = function(data)
	Effects.flash(Color3.fromRGB(255, 220, 140), "FREED", 1.5)
	Effects.banner(("FREED: %s (%d)"):format(data.name, data.year), "They drive off into the morning light.", T.mustard, 4)
end
handlers.FieldGuideCard = function(data)
	local entry = Anomalies.ById[data.id]
	if entry then
		Effects.caption(("📘 New Field Guide card: %s%s"):format(entry.name, if data.how == "caught" then " (caught!)" else ""), nil, 4)
	end
end
handlers.UVUnlocked = function()
	Effects.banner("UV FLASHLIGHT", "Press U (or tap UV) to reveal hidden marks.", T.uv, 3.5)
end
handlers.StickyNote = function(data)
	Effects.banner("Sticky Note", data.text, T.mustard, 5)
end
handlers.CampWarn = function(data)
	Effects.caption(("[%s]"):format(data.message), nil, 3)
	Effects.vignette(if data.spot == "Freezer" then Color3.fromRGB(160, 220, 255) else Color3.fromRGB(150, 200, 120), true, true)
	task.delay(math.max(1, data.left or 5), function()
		if not State.isHidden() then
			Effects.vignette(nil, false)
		end
	end)
end
handlers.EndingScene = function(data)
	if data.id == "Freed" then
		overrides.Dawn = os.clock() + 60
		applyLightState("Dawn")
	end
end

---------------------------------------------------------------------------


function Effects.init()
	cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "NightShiftCC"
	cc.Parent = Lighting
	local fx = Instance.new("Folder")
	fx.Name = "ClientFx"
	fx.Parent = workspace

	gui = Kit.screen("NightShiftEffects", 20)
	root = Kit.root(gui)
	-- vignette edges
	local edges = {
		{ UDim2.new(1, 0, 0.18, 0), UDim2.fromScale(0, 0), 90 },
		{ UDim2.new(1, 0, 0.18, 0), UDim2.fromScale(0, 0.82), 270 },
		{ UDim2.new(0.14, 0, 1, 0), UDim2.fromScale(0, 0), 0 },
		{ UDim2.new(0.14, 0, 1, 0), UDim2.fromScale(0.86, 0), 180 },
	}
	for _, e in edges do
		local f = Kit.new("Frame", { Size = e[1], Position = e[2], BackgroundColor3 = T.bad, Visible = false, Parent = root })
		Kit.new("UIGradient", {
			Rotation = e[3],
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) }),
			Parent = f,
		})
		table.insert(vignette, f)
	end
	flash = Kit.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, Parent = root })
	Kit.label(flash, "", { Name = "Label", Size = UDim2.fromScale(1, 0.3), Position = UDim2.fromScale(0, 0.35), Font = T.title, TextColor3 = T.ketchup, TextTransparency = 1, MaxText = 140 })
	bannerFrame = Kit.new("Frame", { Size = UDim2.new(1, 0, 0, 160), Position = UDim2.fromScale(0, 0.2), BackgroundTransparency = 1, Parent = root })
	captionList = Kit.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -200),
		Size = UDim2.fromOffset(620, 190),
		BackgroundTransparency = 1,
		Parent = root,
	})
	local layout = Kit.list(captionList, Enum.FillDirection.Vertical, 4, Enum.HorizontalAlignment.Center)
	layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	pourBar = Kit.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.62),
		Size = UDim2.fromOffset(420, 40),
		BackgroundColor3 = T.ink,
		Visible = false,
		Parent = root,
	})
	Kit.corner(pourBar, 10)
	Kit.stroke(pourBar, T.white, 2)
	Kit.new("Frame", { Name = "Zone", BackgroundColor3 = T.good, BackgroundTransparency = 0.6, Size = UDim2.fromScale(0.2, 1), Parent = pourBar })
	Kit.new("Frame", { Name = "Fill", BackgroundColor3 = Color3.fromRGB(77, 160, 230), Size = UDim2.fromScale(0, 1), Parent = pourBar })
	Kit.label(pourBar, "", { Name = "Label", Size = UDim2.new(1, 0, 0, 26), Position = UDim2.fromOffset(0, -30), Font = T.title })

	Net.event("Effect").OnClientEvent:Connect(function(name, data)
		local handler = handlers[name]
		if handler then
			local ok, err = pcall(handler, data or {})
			if not ok then
				warn("[Effects] " .. tostring(name) .. ": " .. tostring(err))
			end
		end
	end)
	Net.event("Caption").OnClientEvent:Connect(function(data)
		Effects.caption(data.text, data.pos, data.duration)
	end)
	Net.event("Ping").OnClientEvent:Connect(showPing)
	Net.event("Bubble").OnClientEvent:Connect(showBubble)

	-- keep lighting in sync with the shift state
	task.spawn(function()
		while true do
			task.wait(0.5)
			local wanted = desiredState()
			if wanted ~= lightState then
				applyLightState(wanted)
			end
		end
	end)
	player:GetAttributeChangedSignal("Crew"):Connect(function()
		if not State.isCrew() then
			Effects.beacon(nil)
			Effects.vignette(nil, false)
			table.clear(overrides)
			table.clear(State.flags)
			mirrored = false
			applyLightState("Normal")
		end
	end)
	applyLightState("Normal")
end

return Effects
