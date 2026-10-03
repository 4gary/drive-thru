-- The pickup window inspection (design doc §5.1 detection channels, §7.8 "a single swipe cycles
-- Window <-> Mirror <-> Lane Cam <-> Receipt", big HAND OUT / REFUSE buttons placed apart).
--   WINDOW   the real 3D view out the pickup window (ears, fingers, faces, hats)
--   MIRROR   the convex safety mirror (a ViewportFrame "reflection" — waves late, wrong head...)
--   LANE CAM the CCTV view (camera-only tells: missing shadows, one tall guy, painted faces)
--   RECEIPT  what the printer printed
--   UV       (Night 4+) hidden marks glow

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Layout = require(Shared.Builders.Layout)
local ModelFactory = require(Shared.Builders.ModelFactory)
local Kit = require(script.Parent.Parent.UI.Kit)
local State = require(script.Parent.State)
local Panels = require(script.Parent.Panels)
local CameraView = require(script.Parent.CameraView)
local World = require(script.Parent.World)
local Effects = require(script.Parent.Effects)
local Audio = require(script.Parent.Audio)

local T = Kit.Theme
local player = Players.LocalPlayer

local WindowPanel = {}

local TABS = { "WINDOW", "MIRROR", "LANE CAM", "RECEIPT" }
local HINTS = {
	WINDOW = "Look closely: ears, fingers, faces, hats, who's even driving.",
	MIRROR = "Reflections don't lie. Is it doing what they're doing?",
	["LANE CAM"] = "On camera: shadows, passengers, the driver... what's different?",
	RECEIPT = "Check the name and the total.",
}

local layer: Frame
local tabBar: Frame
local tabButtons: { [string]: TextButton } = {}
local hintLabel: TextLabel
local infoLabel: TextLabel
local mirrorFrame: Frame
local viewport: ViewportFrame
local camOverlay: Frame
local receiptCard: Frame
local handOut: TextButton
local refuse: TextButton
local uvButton: TextButton
local data: any = nil
local tab = "WINDOW"
local mirrorToken = 0
local cc: ColorCorrectionEffect? = nil
local decided = false

local function camCFrame(name: string): (CFrame, number)
	local c = Layout.Cameras[name]
	return CFrame.lookAt(c.from, c.to), c.fov
end

---------------------------------------------------------------------------
-- Mirror (viewport reflection)
---------------------------------------------------------------------------

local function stripChannelParts(model: Instance)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			local channel = d:GetAttribute("Channel")
			if channel == "CamOnly" or channel == "UVOnly" then
				d:Destroy()
			end
		elseif d:IsA("BillboardGui") or d:IsA("Script") or d:IsA("LocalScript") then
			d:Destroy()
		end
	end
end

local function replaceWithMunchHead(clone: Model)
	local knockoff = clone:FindFirstChild("KnockoffHead")
	local bunBottom = knockoff and knockoff:FindFirstChild("BunBottom") :: BasePart?
	if not knockoff or not bunBottom then
		return
	end
	local munch = ModelFactory.buildMunch({ scale = 0.6 })
	local head = munch:FindFirstChild("Head") :: Model?
	local munchBun = head and head:FindFirstChild("BunBottom") :: BasePart?
	if head and munchBun then
		local delta = bunBottom.CFrame * munchBun.CFrame:Inverse()
		for _, d in head:GetDescendants() do
			if d:IsA("BasePart") then
				d.CFrame = delta * d.CFrame
			end
		end
		head.Parent = clone
	end
	knockoff:Destroy()
	munch:Destroy()
end

local function addTears(clone: Model)
	for _, d in clone:GetDescendants() do
		if d:IsA("Frame") and d.Name == "Face" then
			for i, x in { 0.3, 0.7 } do
				local tear = Instance.new("Frame")
				tear.Name = "Tear" .. i
				tear.AnchorPoint = Vector2.new(0.5, 0.5)
				tear.Position = UDim2.fromScale(x, 0.62)
				tear.Size = UDim2.fromScale(0.07, 0.16)
				tear.BackgroundColor3 = Color3.fromRGB(90, 160, 255)
				tear.BorderSizePixel = 0
				tear.ZIndex = 5
				local corner = Instance.new("UICorner")
				corner.CornerRadius = UDim.new(0.5, 0)
				corner.Parent = tear
				tear.Parent = d
			end
		end
	end
end

local function buildMirror()
	mirrorToken += 1
	local token = mirrorToken
	viewport:ClearAllChildren()
	if not data or not data.car or not data.car.Parent then
		return
	end
	local ok, clone = pcall(function()
		return data.car:Clone()
	end)
	if not ok or not clone then
		return
	end
	stripChannelParts(clone)
	local tell = data.mirrorTell or "None"
	if tell == "MunchReflection" then
		replaceWithMunchHead(clone)
	elseif tell == "NoReflection" then
		for _, name in { "Head", "Torso", "Hair", "Hand", "Arm" } do
			local p = clone:FindFirstChild(name)
			if p then
				p:Destroy()
			end
		end
	elseif tell == "Crying" then
		addTears(clone)
	end
	clone.Parent = viewport
	local camera = Instance.new("Camera")
	local cf, fov = camCFrame("Mirror")
	camera.CFrame = cf
	camera.FieldOfView = fov
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	-- the reflection waves while the real customer doesn't
	if tell == "LateWave" or tell == "Crying" then
		local hand = clone:FindFirstChild("Hand") :: Model?
		local palm = hand and hand:FindFirstChild("Palm") :: BasePart?
		if hand and palm then
			local baseCFrames = {}
			for _, p in hand:GetChildren() do
				if p:IsA("BasePart") then
					baseCFrames[p] = palm.CFrame:ToObjectSpace(p.CFrame)
				end
			end
			local pivot = palm.CFrame
			task.spawn(function()
				local t = 0
				while token == mirrorToken and tab == "MIRROR" do
					t += RunService.RenderStepped:Wait()
					local wave = pivot * CFrame.Angles(0, 0, math.rad(math.sin(t * 7) * 30))
					for p, rel in baseCFrames do
						p.CFrame = wave * rel
					end
				end
			end)
		end
	end
end

---------------------------------------------------------------------------
-- Receipt
---------------------------------------------------------------------------

local function buildReceipt()
	Kit.clear(receiptCard)
	local r = data and data.receipt
	local list = Kit.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = receiptCard })
	Kit.list(list, Enum.FillDirection.Vertical, 2, Enum.HorizontalAlignment.Center)
	local function line(text: string, props: { [string]: any }?)
		local p = { Size = UDim2.new(1, 0, 0, 24), TextColor3 = T.ink, Font = T.mono, MaxText = 16, LayoutOrder = #list:GetChildren() }
		if props then
			for k, v in props do
				p[k] = v
			end
		end
		return Kit.label(list, text, p)
	end
	line("MUNCHIE'S #001 — EXIT 13", { Font = T.bold })
	line("OPEN LATE. OPEN ALWAYS.", { MaxText = 13 })
	line("--------------------------")
	if not r then
		line("(no receipt — nobody took", { MaxText = 14 })
		line(" this car's order)", { MaxText = 14 })
		return
	end
	line(("TICKET #%d   %s"):format(r.number or 0, r.time or ""))
	line("GUEST: " .. tostring(r.name or "GUEST"), { Font = T.bold })
	line("--------------------------")
	for _, item in r.lines or {} do
		line(item, { TextXAlignment = Enum.TextXAlignment.Left })
	end
	if #(r.lines or {}) == 0 then
		line("(nothing)")
	end
	line("--------------------------")
	line("TOTAL  " .. tostring(r.total or ""), { Font = T.bold })
	if r.note and r.note ~= "" then
		line(r.note, { Font = T.hand, TextColor3 = Color3.fromRGB(80, 60, 160), MaxText = 20 })
	end
	if r.warm then
		line("(it's warm. and damp.)", { Font = T.hand, TextColor3 = T.bad, MaxText = 18 })
	end
	line("THANK YOU! COME BACK ALWAYS.", { MaxText = 13 })
end

---------------------------------------------------------------------------
-- Tabs
---------------------------------------------------------------------------

local function setTab(name: string)
	tab = name
	for tabName, button in tabButtons do
		button.BackgroundColor3 = if tabName == name then T.ketchup else T.panelLight
	end
	hintLabel.Text = HINTS[name] or ""
	mirrorFrame.Visible = name == "MIRROR"
	camOverlay.Visible = name == "LANE CAM"
	receiptCard.Visible = name == "RECEIPT"
	if name == "LANE CAM" then
		local cf, fov = camCFrame("LaneCam")
		CameraView.push("LaneCam", cf, fov)
		World.setMode("LaneCam")
		if cc then
			cc.Enabled = true
		end
		local noSignal = camOverlay:FindFirstChild("NoSignal") :: TextLabel?
		if noSignal then
			noSignal.Visible = Effects.flagActive("MascotMob")
		end
	else
		CameraView.pop("LaneCam")
		World.setMode("Normal")
		if cc then
			cc.Enabled = false
		end
	end
	if name == "MIRROR" then
		buildMirror()
	else
		mirrorToken += 1
	end
	if name == "RECEIPT" then
		buildReceipt()
	end
end

local function cycle(step: number)
	local index = table.find(TABS, tab) or 1
	index = ((index - 1 + step) % #TABS) + 1
	setTab(TABS[index])
end

local function decide(decision: string)
	if not data or decided then
		return
	end
	decided = true
	handOut.Active = false
	refuse.Active = false
	if decision == "refuse" then
		Audio.play("Shutter")
	end
	State.action("Decide", { carId = data.carId, decision = decision })
end

---------------------------------------------------------------------------

local function build()
	layer = Panels.layer("Window", 1)
	layer.Active = false
	-- tabs
	tabBar = Kit.new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 12), Size = UDim2.fromOffset(820, 56), BackgroundTransparency = 1, Parent = layer })
	Kit.list(tabBar, Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Center)
	Kit.button(tabBar, "◀", T.ink, function()
		cycle(-1)
	end, { Size = UDim2.fromOffset(56, 52), LayoutOrder = 0 })
	for i, name in TABS do
		tabButtons[name] = Kit.button(tabBar, name, T.panelLight, function()
			setTab(name)
		end, { Size = UDim2.fromOffset(150, 52), LayoutOrder = i })
	end
	Kit.button(tabBar, "▶", T.ink, function()
		cycle(1)
	end, { Size = UDim2.fromOffset(56, 52), LayoutOrder = 10 })
	uvButton = Kit.button(layer, "🔦 UV", T.panelLight, function()
		World.setUV(not World.uv)
		uvButton.BackgroundColor3 = if World.uv then T.uv else T.panelLight
		State.action("UsedUV")
	end, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -16, 0, 76), Size = UDim2.fromOffset(140, 52), Visible = false })
	Kit.button(layer, "✕ BACK", T.ink, function()
		WindowPanel.userClose()
	end, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -16, 0, 14), Size = UDim2.fromOffset(140, 52) })
	hintLabel = Kit.label(layer, "", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 74), Size = UDim2.fromOffset(760, 30), Font = T.bold, TextStrokeTransparency = 0.3, MaxText = 20 })
	infoLabel = Kit.label(layer, "", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -112),
		Size = UDim2.fromOffset(760, 34),
		BackgroundTransparency = 0.25,
		BackgroundColor3 = T.ink,
		Font = T.bold,
		MaxText = 18,
	})
	Kit.corner(infoLabel, 10)
	-- mirror
	mirrorFrame = Kit.new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.48), Size = UDim2.fromOffset(470, 470), BackgroundColor3 = Color3.fromRGB(190, 195, 205), Visible = false, Parent = layer })
	Kit.corner(mirrorFrame, 235)
	viewport = Kit.new("ViewportFrame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(440, 440),
		BackgroundColor3 = Color3.fromRGB(20, 22, 30),
		Ambient = Color3.fromRGB(170, 170, 180),
		LightColor = Color3.fromRGB(255, 240, 220),
		LightDirection = Vector3.new(-1, -1, -0.5),
		Parent = mirrorFrame,
	})
	Kit.corner(viewport, 220)
	Kit.label(mirrorFrame, "CONVEX SAFETY MIRROR", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 1, 6), Size = UDim2.fromOffset(300, 24), Font = T.bold, TextStrokeTransparency = 0.3, MaxText = 16 })
	-- lane cam overlay
	camOverlay = Kit.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false, Parent = layer })
	for i = 0, 40 do
		Kit.new("Frame", { Position = UDim2.fromScale(0, i / 40), Size = UDim2.new(1, 0, 0, 2), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.8, Parent = camOverlay })
	end
	Kit.label(camOverlay, "CAM 01  ● REC", { Position = UDim2.fromOffset(24, 120), Size = UDim2.fromOffset(300, 36), Font = T.mono, TextColor3 = Color3.fromRGB(255, 70, 70), TextXAlignment = Enum.TextXAlignment.Left, MaxText = 28 })
	Kit.label(camOverlay, "NO SIGNAL\n▒▓░ (knockoff mascots are dancing on the camera) ░▓▒", {
		Name = "NoSignal",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 0.1,
		BackgroundColor3 = Color3.fromRGB(30, 30, 30),
		Font = T.mono,
		Visible = false,
		MaxText = 40,
	})
	-- receipt
	receiptCard = Kit.new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.48), Size = UDim2.fromOffset(360, 470), BackgroundColor3 = Color3.fromRGB(250, 248, 240), Visible = false, Parent = layer })
	Kit.corner(receiptCard, 6)
	Kit.padding(receiptCard, 12)
	-- decision buttons (far apart)
	handOut = Kit.button(layer, "HAND OUT", T.good, function()
		decide("handout")
	end, { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 24, 1, -20), Size = UDim2.fromOffset(300, 86) })
	refuse = Kit.button(layer, "REFUSE\nSORRY, WE'RE CLOSED", T.bad, function()
		decide("refuse")
	end, { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -24, 1, -20), Size = UDim2.fromOffset(300, 86) })
end

function WindowPanel.open(d)
	if not layer then
		build()
	end
	data = d
	decided = false
	handOut.Active = true
	refuse.Active = true
	layer.Visible = true
	local cf, fov = camCFrame("Window")
	CameraView.push("Window", cf, fov)
	uvButton.Visible = d.uv == true
	uvButton.BackgroundColor3 = if World.uv then T.uv else T.panelLight
	local info = {}
	if d.bag then
		table.insert(info, ("Ticket #%d • Bag %d/%d"):format(d.bag.number, d.bag.ticketMatched, d.bag.ticketLines))
		if d.bag.flagged then
			table.insert(info, "⚠ FLAGGED SUSPICIOUS")
		end
	elseif not d.onFoot then
		table.insert(info, "No ticket for this car")
	end
	if d.wantsUsual then
		table.insert(info, "They want THE USUAL (check the photos with UV)")
	end
	infoLabel.Text = table.concat(info, "   •   ")
	infoLabel.Visible = #info > 0
	refuse.BackgroundColor3 = T.bad
	if d.tutorialRefuse then
		TweenService:Create(refuse, TweenInfo.new(0.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, 8, true), { BackgroundColor3 = T.mustard }):Play()
	end
	setTab("WINDOW")
	ContextActionService:BindAction("NS_WindowTabs", function(_, inputState, input)
		if inputState == Enum.UserInputState.Begin then
			cycle(if input.KeyCode == Enum.KeyCode.Left or input.KeyCode == Enum.KeyCode.A then -1 else 1)
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.Left, Enum.KeyCode.Right)
end

function WindowPanel.close()
	mirrorToken += 1
	data = nil
	ContextActionService:UnbindAction("NS_WindowTabs")
	if layer then
		layer.Visible = false
		viewport:ClearAllChildren()
	end
	CameraView.pop("LaneCam")
	CameraView.pop("Window")
	World.setMode("Normal")
	if cc then
		cc.Enabled = false
	end
end

function WindowPanel.userClose()
	State.action("CloseWindow")
	Panels.close("Window")
end

function WindowPanel.init()
	Panels.register("Window", WindowPanel)
	local tint = Instance.new("ColorCorrectionEffect")
	tint.Name = "LaneCamTint"
	tint.TintColor = Color3.fromRGB(170, 255, 170)
	tint.Saturation = -0.7
	tint.Contrast = 0.2
	tint.Enabled = false
	tint.Parent = game:GetService("Lighting")
	cc = tint
	UserInputService.TouchSwipe:Connect(function(direction)
		if data and layer and layer.Visible then
			if direction == Enum.SwipeDirection.Left then
				cycle(1)
			elseif direction == Enum.SwipeDirection.Right then
				cycle(-1)
			end
		end
	end)
	player:GetAttributeChangedSignal("Ghost"):Connect(function()
		if State.isGhost() and data then
			Panels.close("Window")
		end
	end)
end

return WindowPanel
