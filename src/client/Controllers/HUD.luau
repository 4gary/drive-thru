-- The in-shift HUD (design doc §7.8): clock (top center), stars + Weird Meter (top left), crew with
-- ghost timers (top right), ticket rail (bottom), holding chip, radio box, toasts, and big buttons
-- for mobile (quick-chat, crouch, ping, UV, and Ghost Point / Boo! while booped).

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local QuickChat = require(Shared.Data.QuickChat)
local Util = require(Shared.Util)
local Kit = require(script.Parent.Parent.UI.Kit)
local State = require(script.Parent.State)
local World = require(script.Parent.World)
local Effects = require(script.Parent.Effects)

local T = Kit.Theme
local player = Players.LocalPlayer

local HUD = {}

local gui: ScreenGui
local always: ScreenGui
local root: Frame
local clockLabel: TextLabel
local nightLabel: TextLabel
local starsLabel: TextLabel
local weirdFill: Frame
local weirdLabel: TextLabel
local crewList: Frame
local rail: Frame
local holding: TextLabel
local scareLabel: TextLabel
local weirdChips: TextLabel
local gizmoChip: TextLabel
local fryChip: TextLabel
local toastList: Frame
local radioBox: Frame
local buttons: { [string]: TextButton } = {}
local chatPopup: Frame

local lastTicketSig = ""
local lastCrewSig = ""
local uvOn = false
local usedUV = false

---------------------------------------------------------------------------
-- Toasts & radio (visible everywhere)
---------------------------------------------------------------------------

local KIND_COLORS = {
	info = T.panel,
	good = T.good,
	bad = T.bad,
	warn = T.warn,
	badge = T.mustard,
}

function HUD.toast(text: string, kind: string?)
	local color = KIND_COLORS[kind or "info"] or T.panel
	local label = Kit.label(toastList, text, {
		Size = UDim2.new(1, 0, 0, 34),
		BackgroundTransparency = 0.1,
		BackgroundColor3 = color,
		TextColor3 = if kind == "badge" then T.ink else T.white,
		Font = T.bold,
		MaxText = 20,
	})
	Kit.corner(label, 10)
	Kit.padding(label, 4)
	label.LayoutOrder = math.floor(os.clock() * 100)
	local count = 0
	for _, c in toastList:GetChildren() do
		if c:IsA("TextLabel") then
			count += 1
		end
	end
	if count > 4 then
		for _, c in toastList:GetChildren() do
			if c:IsA("TextLabel") then
				c:Destroy()
				break
			end
		end
	end
	task.delay(3.5, function()
		if label.Parent then
			Kit.fade(label, 1, 0.4)
			task.wait(0.45)
			label:Destroy()
		end
	end)
end

local radioQueue: { any } = {}
local radioBusy = false
local function playRadio()
	if radioBusy then
		return
	end
	local line = table.remove(radioQueue, 1)
	if not line then
		return
	end
	radioBusy = true
	radioBox.Visible = true
	local who = radioBox:FindFirstChild("Who") :: TextLabel
	local text = radioBox:FindFirstChild("Text") :: TextLabel
	who.Text = "📻 " .. string.upper(line.who)
	text.Text = ""
	task.spawn(function()
		local full = line.text
		for i = 1, #full, 2 do
			text.Text = string.sub(full, 1, i)
			task.wait(0.015)
		end
		text.Text = full
		task.wait(line.duration or 4)
		radioBox.Visible = false
		radioBusy = false
		playRadio()
	end)
end

function HUD.radio(data)
	table.insert(radioQueue, data)
	if #radioQueue > 6 then
		table.remove(radioQueue, 1)
	end
	Effects.caption(("%s: \"%s\""):format(data.who, data.text), nil, 1)
	playRadio()
end

---------------------------------------------------------------------------
-- Actions
---------------------------------------------------------------------------

local function aimPosition(): Vector3?
	local camera = workspace.CurrentCamera
	if not camera then
		return nil
	end
	local point: Vector2
	if UserInputService.MouseEnabled and not UserInputService.TouchEnabled then
		point = UserInputService:GetMouseLocation()
	else
		point = camera.ViewportSize / 2
	end
	local ray = camera:ViewportPointToRay(point.X, point.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclude: { Instance } = {}
	if player.Character then
		table.insert(exclude, player.Character)
	end
	local fx = workspace:FindFirstChild("ClientFx")
	if fx then
		table.insert(exclude, fx)
	end
	params.FilterDescendantsInstances = exclude
	local result = workspace:Raycast(ray.Origin, ray.Direction * 250, params)
	return if result then result.Position else ray.Origin + ray.Direction * 40
end

function HUD.toggleCrouch()
	if not State.isCrew() or State.isGhost() or State.isHidden() then
		return
	end
	State.action("Crouch", { on = not player:GetAttribute("Crouching") })
end

function HUD.ping()
	if not State.isCrew() then
		return
	end
	local pos = aimPosition()
	if not pos then
		return
	end
	if State.isGhost() then
		State.action("GhostPoint", { position = pos })
	else
		State.action("Ping", { position = pos })
	end
end

function HUD.boo()
	if State.isGhost() then
		State.action("GhostBoo")
	end
end

function HUD.toggleUV()
	local shift = State.shift
	if not State.isCrew() or not shift or not shift.flags or not shift.flags.uv then
		return
	end
	uvOn = not uvOn
	World.setUV(uvOn)
	if uvOn and not usedUV then
		usedUV = true
		State.action("UsedUV")
	end
	if buttons.UV then
		buttons.UV.BackgroundColor3 = if uvOn then T.uv else T.panelLight
	end
end

function HUD.toggleChat()
	chatPopup.Visible = not chatPopup.Visible
end

---------------------------------------------------------------------------
-- Rendering
---------------------------------------------------------------------------

local function stars(value: number, knitted: boolean): string
	local full = math.floor(value + 0.001)
	local out = ""
	for i = 1, 5 do
		if i <= full then
			out ..= if knitted then "🧶" else "★"
		else
			out ..= "☆"
		end
	end
	return out .. ("  %.1f"):format(value)
end

local STATIC = { "▒", "▓", "░", "█", "#", "%", "?" }
local function noise(n: number): string
	local out = {}
	for _ = 1, n do
		table.insert(out, STATIC[math.random(1, #STATIC)])
	end
	return table.concat(out)
end

local function ticketColor(age: number): Color3
	if age < 25 then
		return T.good
	elseif age < 50 then
		return T.warn
	end
	return T.bad
end

local function renderTickets(tickets)
	local surf = Effects.flagActive("ChannelSurf")
	local sig = { if surf then "S" .. math.random() else "" }
	for _, t in tickets do
		local done = {}
		for _, l in t.lines do
			table.insert(done, if l.done then "1" else "0")
		end
		table.insert(sig, ("%d:%s:%d:%s:%s:%s"):format(t.number, table.concat(done), math.floor(t.age / 25), tostring(t.flagged), tostring(t.atWindow), tostring(t.extras)))
	end
	local signature = table.concat(sig, "|")
	if signature == lastTicketSig then
		return
	end
	lastTicketSig = signature
	Kit.clear(rail)
	for i, t in tickets do
		if i > 7 then
			break
		end
		local card = Kit.new("Frame", {
			Size = UDim2.fromOffset(160, 150),
			BackgroundColor3 = T.paper,
			LayoutOrder = i,
			Parent = rail,
		})
		Kit.corner(card, 10)
		local header = Kit.new("Frame", { Size = UDim2.new(1, 0, 0, 28), BackgroundColor3 = ticketColor(t.age), Parent = card })
		Kit.corner(header, 10)
		Kit.label(header, ("#%d%s%s"):format(t.number, if t.flagged then " ⚠" else "", if t.atWindow then " • WINDOW" else ""), {
			Size = UDim2.new(1, -10, 1, -4),
			Position = UDim2.fromOffset(5, 2),
			Font = T.title,
			TextXAlignment = Enum.TextXAlignment.Left,
			MaxText = 18,
		})
		local body = Kit.new("Frame", { Size = UDim2.new(1, -10, 1, -34), Position = UDim2.fromOffset(5, 31), BackgroundTransparency = 1, Parent = card })
		Kit.list(body, Enum.FillDirection.Vertical, 1)
		if #t.lines == 0 then
			Kit.label(body, "(nothing — empty bag)", { Size = UDim2.new(1, 0, 0, 20), TextColor3 = T.ink, MaxText = 14 })
		end
		for j, line in t.lines do
			if j > 6 then
				Kit.label(body, "...", { Size = UDim2.new(1, 0, 0, 16), TextColor3 = T.ink, MaxText = 14 })
				break
			end
			local text = (if line.done then "✓ " else "• ") .. line.label
			if surf then
				text = noise(#line.label)
			end
			Kit.label(body, text, {
				Size = UDim2.new(1, 0, 0, 18),
				TextColor3 = if line.done then T.good else T.ink,
				Font = T.bold,
				TextXAlignment = Enum.TextXAlignment.Left,
				MaxText = 14,
			})
		end
		if t.extras and t.extras > 0 then
			Kit.label(body, ("+%d extra?! (Fix Bags)"):format(t.extras), { Size = UDim2.new(1, 0, 0, 16), TextColor3 = T.bad, Font = T.bold, MaxText = 13 })
		end
	end
end

local function renderCrew(crew)
	local sig = {}
	for _, m in crew do
		table.insert(sig, ("%d:%s:%s:%d:%s"):format(m.userId, m.role, tostring(m.ghost), math.ceil(m.respawnIn or 0), tostring(m.hidden)))
	end
	local signature = table.concat(sig, "|")
	if signature == lastCrewSig then
		return
	end
	lastCrewSig = signature
	Kit.clear(crewList)
	for i, m in crew do
		local status = m.role
		local color = T.panel
		if m.ghost then
			status = "👻 BACK IN " .. Util.formatSeconds(m.respawnIn or 0)
			color = T.navy
		elseif m.hidden then
			status = "HIDING"
			color = Color3.fromRGB(60, 60, 80)
		end
		local row = Kit.label(crewList, ("%s  •  %s"):format(m.name, status), {
			Size = UDim2.new(1, 0, 0, 30),
			BackgroundTransparency = 0.15,
			BackgroundColor3 = color,
			Font = T.bold,
			TextXAlignment = Enum.TextXAlignment.Right,
			LayoutOrder = i,
			MaxText = 18,
		})
		Kit.corner(row, 8)
		Kit.padding(row, 6)
	end
end

local function render(shift)
	if not shift then
		return
	end
	clockLabel.Text = shift.clock
	nightLabel.Text = ("NIGHT %d — %s"):format(shift.night, shift.title)
	starsLabel.Text = stars(shift.stars, shift.flags and shift.flags.doilies)
	starsLabel.TextColor3 = if shift.stars < 1.5 then T.bad else T.mustard
	local weird = math.clamp(shift.weird or 0, 0, 100)
	weirdFill.Size = UDim2.fromScale(weird / 100, 1)
	weirdFill.BackgroundColor3 = T.pickle:Lerp(T.uv, weird / 100)
	weirdLabel.Text = ("WEIRD %d%%"):format(math.floor(weird))
	renderCrew(shift.crew or {})
	renderTickets(shift.tickets or {})
	if shift.scare then
		local names = { RushHour = "MR. MUNCH IS WALKING — HIDE!", HighBeams = "HIGH BEAMS — HEADS DOWN!", LightsOutSafe = "LIGHTS OUT — HIDE!" }
		scareLabel.Text = "⚠ " .. (names[shift.scare.kind] or "SOMETHING'S WRONG")
		scareLabel.Visible = true
	else
		scareLabel.Visible = false
	end
	local chips = {}
	for _, e in shift.weirdEvents or {} do
		table.insert(chips, if e.remaining then ("%s %ds"):format(e.name, math.ceil(e.remaining)) else e.name)
	end
	weirdChips.Text = table.concat(chips, "  •  ")
	weirdChips.Visible = #chips > 0
	local g = shift.gizmo
	if g then
		local covering = {}
		if g.order then
			table.insert(covering, "Order")
		end
		if g.fry then
			table.insert(covering, "Fryer & Drinks")
		end
		if g.grill then
			table.insert(covering, "Grill")
		end
		local status = if g.state == "Ghost" then "booped 👻" elseif g.state == "Hiding" then "hiding (badly)" elseif #covering > 0 then "covering " .. table.concat(covering, ", ") else "idle"
		gizmoChip.Text = "🤖 Gizmo: " .. status
	end
	fryChip.Text = ("🍟 Fry bin: %d"):format(shift.fryBin or 0)
	if buttons.UV then
		buttons.UV.Visible = shift.flags and shift.flags.uv and not State.isGhost()
	end
end

local function refreshMode()
	local crew = State.isCrew()
	gui.Enabled = crew
	local ghost = State.isGhost()
	local hidden = State.isHidden()
	if buttons.Point then
		buttons.Point.Visible = ghost
		buttons.Boo.Visible = ghost
		buttons.Crouch.Visible = not ghost
		buttons.Ping.Visible = not ghost
	end
	ProximityPromptService.Enabled = not (crew and (ghost or hidden))
	local text = player:GetAttribute("Holding")
	holding.Text = if text then "HOLDING: " .. tostring(text) else ""
	holding.Visible = text ~= nil
	if buttons.Crouch then
		buttons.Crouch.BackgroundColor3 = if player:GetAttribute("Crouching") then T.mustard else T.panelLight
	end
	if not crew then
		if uvOn then
			uvOn = false
			World.setUV(false)
		end
		chatPopup.Visible = false
	end
end

local function starsFloat(data)
	if not State.isCrew() then
		return
	end
	local delta = data.delta or 0
	local label = Kit.label(root, ("%s%.1f★ %s"):format(if delta >= 0 then "+" else "", delta, data.reason or ""), {
		Size = UDim2.fromOffset(300, 28),
		Position = UDim2.fromOffset(20, 100),
		TextColor3 = if delta >= 0 then T.good else T.bad,
		Font = T.title,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextStrokeTransparency = 0.4,
		MaxText = 22,
	})
	TweenService:Create(label, TweenInfo.new(1.6), { Position = UDim2.fromOffset(20, 60), TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	task.delay(1.7, function()
		label:Destroy()
	end)
end

---------------------------------------------------------------------------

function HUD.init()
	-- always-on layer
	always = Kit.screen("NightShiftToasts", 30, true)
	local aroot = Kit.root(always)
	toastList = Kit.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 96),
		Size = UDim2.fromOffset(520, 200),
		BackgroundTransparency = 1,
		Parent = aroot,
	})
	Kit.list(toastList, Enum.FillDirection.Vertical, 4, Enum.HorizontalAlignment.Center)
	radioBox = Kit.new("Frame", {
		Position = UDim2.new(0, 16, 0.32, 0),
		Size = UDim2.fromOffset(380, 120),
		BackgroundColor3 = T.ink,
		BackgroundTransparency = 0.1,
		Visible = false,
		Parent = aroot,
	})
	Kit.corner(radioBox, 14)
	Kit.stroke(radioBox, T.mustard, 2)
	Kit.label(radioBox, "", { Name = "Who", Size = UDim2.new(1, -20, 0, 26), Position = UDim2.fromOffset(10, 6), Font = T.title, TextColor3 = T.mustard, TextXAlignment = Enum.TextXAlignment.Left, MaxText = 20 })
	Kit.label(radioBox, "", { Name = "Text", Size = UDim2.new(1, -20, 1, -40), Position = UDim2.fromOffset(10, 34), Font = T.bold, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, MaxText = 20 })

	-- shift layer
	gui = Kit.screen("NightShiftHUD", 5, true)
	root = Kit.root(gui)
	local clockBox = Kit.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 8),
		Size = UDim2.fromOffset(300, 78),
		BackgroundColor3 = T.ink,
		BackgroundTransparency = 0.15,
		Parent = root,
	})
	Kit.corner(clockBox, 14)
	Kit.stroke(clockBox, T.ketchup, 2)
	clockLabel = Kit.label(clockBox, "6:00 PM", { Size = UDim2.new(1, 0, 0, 46), Position = UDim2.fromOffset(0, 4), Font = T.mono, TextColor3 = T.crtText, MaxText = 40 })
	nightLabel = Kit.label(clockBox, "", { Size = UDim2.new(1, -12, 0, 22), Position = UDim2.fromOffset(6, 50), Font = T.bold, TextColor3 = T.muted, MaxText = 15 })
	scareLabel = Kit.label(root, "", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 92),
		Size = UDim2.fromOffset(460, 34),
		BackgroundColor3 = T.bad,
		BackgroundTransparency = 0,
		Font = T.title,
		Visible = false,
		MaxText = 24,
	})
	Kit.corner(scareLabel, 10)
	TweenService:Create(scareLabel, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { BackgroundTransparency = 0.5 }):Play()

	local meters = Kit.new("Frame", {
		Position = UDim2.fromOffset(12, 8),
		Size = UDim2.fromOffset(330, 92),
		BackgroundColor3 = T.ink,
		BackgroundTransparency = 0.15,
		Parent = root,
	})
	Kit.corner(meters, 14)
	starsLabel = Kit.label(meters, "★★★☆☆", { Size = UDim2.new(1, -16, 0, 40), Position = UDim2.fromOffset(8, 4), Font = T.title, TextColor3 = T.mustard, TextXAlignment = Enum.TextXAlignment.Left, MaxText = 32 })
	local weirdBack = Kit.new("Frame", { Size = UDim2.new(1, -16, 0, 26), Position = UDim2.fromOffset(8, 52), BackgroundColor3 = T.panelLight, Parent = meters })
	Kit.corner(weirdBack, 8)
	weirdFill = Kit.new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = T.pickle, Parent = weirdBack })
	Kit.corner(weirdFill, 8)
	weirdLabel = Kit.label(weirdBack, "WEIRD 0%", { Size = UDim2.fromScale(1, 1), Font = T.bold, MaxText = 16, ZIndex = 2 })
	weirdChips = Kit.label(root, "", {
		Position = UDim2.fromOffset(12, 104),
		Size = UDim2.fromOffset(330, 26),
		BackgroundColor3 = T.uv,
		BackgroundTransparency = 0.1,
		Font = T.bold,
		Visible = false,
		MaxText = 15,
	})
	Kit.corner(weirdChips, 8)
	gizmoChip = Kit.label(root, "", { Position = UDim2.fromOffset(12, 134), Size = UDim2.fromOffset(330, 22), Font = T.bold, TextColor3 = T.crtText, TextXAlignment = Enum.TextXAlignment.Left, TextStrokeTransparency = 0.5, MaxText = 14 })
	fryChip = Kit.label(root, "", { Position = UDim2.fromOffset(12, 156), Size = UDim2.fromOffset(330, 22), Font = T.bold, TextColor3 = T.bun, TextXAlignment = Enum.TextXAlignment.Left, TextStrokeTransparency = 0.5, MaxText = 14 })

	crewList = Kit.new("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 8),
		Size = UDim2.fromOffset(300, 140),
		BackgroundTransparency = 1,
		Parent = root,
	})
	Kit.list(crewList, Enum.FillDirection.Vertical, 4, Enum.HorizontalAlignment.Right)

	rail = Kit.new("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 12, 1, -8),
		Size = UDim2.new(1, -230, 0, 150),
		BackgroundTransparency = 1,
		Parent = root,
	})
	Kit.list(rail, Enum.FillDirection.Horizontal, 8)
	holding = Kit.label(root, "", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 12, 1, -166),
		Size = UDim2.fromOffset(360, 34),
		BackgroundColor3 = T.mustard,
		BackgroundTransparency = 0,
		TextColor3 = T.ink,
		Font = T.title,
		Visible = false,
		MaxText = 20,
	})
	Kit.corner(holding, 10)

	-- big buttons (right side)
	local column = Kit.new("Frame", {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -12, 1, -12),
		Size = UDim2.fromOffset(200, 360),
		BackgroundTransparency = 1,
		Parent = root,
	})
	local layout = Kit.list(column, Enum.FillDirection.Vertical, 8, Enum.HorizontalAlignment.Right)
	layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	local function bigButton(name: string, text: string, color: Color3, order: number, fn: () -> ())
		local b = Kit.button(column, text, color, fn, { Name = name, Size = UDim2.fromOffset(190, 58), LayoutOrder = order })
		buttons[name] = b
		return b
	end
	bigButton("UV", "UV  (U)", T.panelLight, 1, HUD.toggleUV).Visible = false
	bigButton("Chat", "CHAT  (Q)", T.navy, 2, HUD.toggleChat)
	bigButton("Ping", "PING  (G)", T.panelLight, 3, HUD.ping)
	bigButton("Crouch", "CROUCH  (C)", T.panelLight, 4, HUD.toggleCrouch)
	bigButton("Point", "👉 POINT  (G)", T.navy, 5, HUD.ping).Visible = false
	bigButton("Boo", "👻 BOO!  (B)", T.navy, 6, HUD.boo).Visible = false

	chatPopup = Kit.new("Frame", {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -214, 1, -12),
		Size = UDim2.fromOffset(420, 300),
		BackgroundColor3 = T.ink,
		BackgroundTransparency = 0.05,
		Visible = false,
		Parent = root,
	})
	Kit.corner(chatPopup, 14)
	Kit.padding(chatPopup, 8)
	Kit.new("UIGridLayout", { CellSize = UDim2.fromOffset(196, 48), CellPadding = UDim2.fromOffset(8, 8), Parent = chatPopup })
	for _, entry in QuickChat do
		Kit.button(chatPopup, entry.text, T.panelLight, function()
			chatPopup.Visible = false
			if Effects.flagActive("MandatoryFun") then
				HUD.toast("Mandatory Fun! Only smiling allowed.", "warn")
				return
			end
			State.action("QuickChat", { id = entry.id })
		end)
	end

	-- keyboard
	ContextActionService:BindAction("NS_Crouch", function(_, inputState)
		if inputState == Enum.UserInputState.Begin then
			HUD.toggleCrouch()
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.C, Enum.KeyCode.LeftControl)
	ContextActionService:BindAction("NS_Chat", function(_, inputState)
		if inputState == Enum.UserInputState.Begin and State.isCrew() then
			HUD.toggleChat()
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.Q)
	ContextActionService:BindAction("NS_Ping", function(_, inputState)
		if inputState == Enum.UserInputState.Begin then
			HUD.ping()
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.G)
	ContextActionService:BindAction("NS_UV", function(_, inputState)
		if inputState == Enum.UserInputState.Begin then
			HUD.toggleUV()
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.U)
	ContextActionService:BindAction("NS_Boo", function(_, inputState)
		if inputState == Enum.UserInputState.Begin then
			HUD.boo()
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.B)

	Net.event("Notify").OnClientEvent:Connect(HUD.toast)
	Net.event("Radio").OnClientEvent:Connect(HUD.radio)
	Net.event("Effect").OnClientEvent:Connect(function(name, data)
		if name == "Stars" then
			starsFloat(data)
		end
	end)
	State.ShiftChanged:Connect(render)
	for _, attr in { "Crew", "Ghost", "Hidden", "Holding", "Crouching" } do
		player:GetAttributeChangedSignal(attr):Connect(refreshMode)
	end
	refreshMode()
end

return HUD
