-- Panel manager (server opens/closes panels by name) + the smaller shift panels:
-- PreShift (role pick + Deb's sticky note), HoldBreath, Report (the corporate report card),
-- Ending, VHS.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local Kit = require(script.Parent.Parent.UI.Kit)
local State = require(script.Parent.State)
local Audio = require(script.Parent.Audio)

local T = Kit.Theme
local player = Players.LocalPlayer

local Panels = {}

local registry: { [string]: any } = {}
local isOpen: { [string]: boolean } = {}
local gui: ScreenGui
Panels.root = (nil :: any) :: Frame

function Panels.register(name: string, module: any)
	registry[name] = module
end

function Panels.open(name: string, data: any)
	local module = registry[name]
	if not module then
		warn("[Panels] no panel named " .. tostring(name))
		return
	end
	isOpen[name] = true
	module.open(data or {})
end

function Panels.close(name: string)
	if name == "All" then
		for openName in table.clone(isOpen) do
			Panels.close(openName)
		end
		return
	end
	local module = registry[name]
	if module and isOpen[name] then
		isOpen[name] = nil
		module.close()
	end
end

function Panels.markClosed(name: string)
	isOpen[name] = nil
end

function Panels.isOpen(name: string): boolean
	return isOpen[name] == true
end

-- A dimmed full-screen container for one panel.
-- Panels that must sit on top of others regardless of creation order.
local LAYER_Z = { Ending = 20, HoldBreath = 15, Report = 10 }

function Panels.layer(name: string, dim: number?): Frame
	local layer = Kit.new("Frame", {
		Name = name,
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = dim or 0.45,
		Visible = false,
		ZIndex = LAYER_Z[name] or 1,
		Parent = Panels.root,
	})
	return layer
end

---------------------------------------------------------------------------
-- PreShift
---------------------------------------------------------------------------

local ROLE_INFO = {
	Order = "EARS — take orders at the CRT. Flag weird voices.",
	Grill = "HANDS — patties on the grill, build burgers on the plate.",
	Fry = "HANDS — fries, drinks & shakes. (Gizmo covers it if nobody does.)",
	Window = "DETECTIVE — bag it, inspect the car, HAND OUT or REFUSE.",
}

local PreShift = {}
do
	local layer: Frame
	local content: Frame
	local timerLabel: TextLabel
	local timerToken = 0
	local endsAt = 0
	function PreShift.open(data)
		if not layer then
			local created = Panels.layer("PreShift", 0.35)
			layer = created
			local _, c = Kit.panel(created, "CLOCKING IN", UDim2.fromOffset(940, 560))
			content = c
		end
		layer.Visible = true
		Kit.clear(content)
		endsAt = os.clock() + (data.endsIn or 20)
		Kit.label(content, ("NIGHT %d: %s"):format(data.night, data.title), { Size = UDim2.new(1, 0, 0, 44), Font = T.title, TextColor3 = T.mustard, MaxText = 36 })
		local note = Kit.label(content, data.note or "", {
			Size = UDim2.fromOffset(380, 300),
			Position = UDim2.fromOffset(0, 56),
			BackgroundTransparency = 0,
			BackgroundColor3 = Color3.fromRGB(255, 240, 120),
			TextColor3 = T.ink,
			Font = T.hand,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			MaxText = 26,
		})
		Kit.padding(note, 14)
		note.Rotation = -2
		local right = Kit.new("Frame", { Size = UDim2.new(1, -410, 1, -60), Position = UDim2.fromOffset(410, 56), BackgroundTransparency = 1, Parent = content })
		Kit.list(right, Enum.FillDirection.Vertical, 6)
		Kit.label(right, "PICK A STATION (you can still do anything)", { Size = UDim2.new(1, 0, 0, 24), Font = T.bold, TextColor3 = T.muted, MaxText = 16 })
		local myRole = nil
		for _, r in data.roles do
			if r.userId == player.UserId then
				myRole = r.role
			end
		end
		for i, role in data.allRoles do
			local taken = {}
			for _, r in data.roles do
				if r.role == role then
					table.insert(taken, r.name .. (if r.ready then " ✓" else ""))
				end
			end
			Kit.button(right, ("%s%s\n%s"):format(role, if #taken > 0 then "  (" .. table.concat(taken, ", ") .. ")" else "", ROLE_INFO[role] or ""), if role == myRole then T.ketchup else T.panelLight, function()
				State.action("PickRole", { role = role })
			end, { Size = UDim2.new(1, 0, 0, 70), LayoutOrder = i, Font = T.bold, TextXAlignment = Enum.TextXAlignment.Left })
		end
		Kit.button(content, "READY!", T.good, function()
			State.action("Ready")
		end, { AnchorPoint = Vector2.new(1, 1), Position = UDim2.fromScale(1, 1), Size = UDim2.fromOffset(220, 60) })
		timerLabel = Kit.label(content, "", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.fromOffset(380, 40), Font = T.bold, TextColor3 = T.muted, MaxText = 20 })
		timerToken += 1
		local myToken = timerToken
		task.spawn(function()
			while myToken == timerToken and layer.Visible and Panels.isOpen("PreShift") do
				timerLabel.Text = ("Shift starts in %d..."):format(math.max(0, math.ceil(endsAt - os.clock())))
				task.wait(0.25)
			end
		end)
	end
	function PreShift.close()
		if layer then
			layer.Visible = false
		end
	end
end

---------------------------------------------------------------------------
-- HoldBreath (Night 4+: Mr. Munch knocks on your hiding spot)
---------------------------------------------------------------------------

local HoldBreath = {}
do
	local layer: Frame
	local token = 0
	function HoldBreath.open(data)
		if not layer then
			layer = Panels.layer("HoldBreath", 0.55)
		end
		token += 1
		local myToken = token
		Kit.clear(layer)
		layer.Visible = true
		Audio.play("Knock")
		Kit.label(layer, "KNOCK. KNOCK.\nHOLD YOUR BREATH!", { Size = UDim2.new(1, 0, 0, 110), Position = UDim2.fromScale(0, 0.18), Font = T.title, TextColor3 = T.bad, MaxText = 52 })
		local bar = Kit.new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.52), Size = UDim2.fromOffset(560, 54), BackgroundColor3 = T.ink, Parent = layer })
		Kit.corner(bar, 12)
		Kit.stroke(bar, T.white, 2)
		local zone = Kit.new("Frame", { Size = UDim2.fromScale(0.22, 1), BackgroundColor3 = T.good, Parent = bar })
		local marker = Kit.new("Frame", { Size = UDim2.new(0, 10, 1, 10), Position = UDim2.new(0, 0, 0, -5), BackgroundColor3 = T.white, Parent = bar })
		local status = Kit.label(layer, "", { Size = UDim2.new(1, 0, 0, 40), Position = UDim2.fromScale(0, 0.6), Font = T.bold, MaxText = 26 })
		local hits, misses = 0, 0
		local need = data.hits or 3
		local done = false
		local function placeZone()
			zone.Position = UDim2.fromScale(math.random() * 0.7 + 0.04, 0)
		end
		placeZone()
		local function finish(success: boolean)
			if done then
				return
			end
			done = true
			State.action("HoldBreath", { success = success })
			status.Text = if success then "...he moves on." else "*GASP*"
			task.delay(0.8, function()
				if token == myToken then
					layer.Visible = false
					Panels.markClosed("HoldBreath")
				end
			end)
		end
		local function tap()
			if done then
				return
			end
			local x = marker.Position.X.Scale
			local z0 = zone.Position.X.Scale
			if x >= z0 - 0.01 and x <= z0 + zone.Size.X.Scale + 0.01 then
				hits += 1
				Audio.play("Click")
				placeZone()
				if hits >= need then
					finish(true)
				end
			else
				misses += 1
				if misses > 1 then
					finish(false)
				end
			end
			status.Text = ("%d / %d"):format(hits, need) .. (if misses > 0 then "  (careful!)" else "")
		end
		Kit.button(layer, "HOLD (Space)", T.navy, tap, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.68), Size = UDim2.fromOffset(300, 90) })
		ContextActionService:BindAction("NS_Breath", function(_, inputState)
			if inputState == Enum.UserInputState.Begin then
				tap()
			end
			return Enum.ContextActionResult.Sink
		end, false, Enum.KeyCode.Space)
		local start = os.clock()
		task.spawn(function()
			while not done and token == myToken do
				local t = os.clock() - start
				local speed = 1.1 + hits * 0.25
				marker.Position = UDim2.new((math.sin(t * speed * 2.4) + 1) / 2 * 0.98, 0, 0, -5)
				if t > (data.seconds or 6) then
					finish(hits >= need)
				end
				RunService.RenderStepped:Wait()
			end
			ContextActionService:UnbindAction("NS_Breath")
		end)
	end
	function HoldBreath.close()
		token += 1
		ContextActionService:UnbindAction("NS_Breath")
		if layer then
			layer.Visible = false
		end
	end
end

---------------------------------------------------------------------------
-- Report (6 AM Shift Report)
---------------------------------------------------------------------------

local REASONS = {
	CorporateCalled = "CORPORATE CALLED. (Stars hit zero.)",
	GhostTown = "GHOST TOWN: STORE CLOSED EARLY.",
}

local Report = {}
do
	local layer: Frame
	function Report.open(data)
		if not layer then
			layer = Panels.layer("Report", 0.4)
		end
		Kit.clear(layer)
		layer.Visible = true
		local _, content = Kit.panel(layer, "MUNCH HOLDINGS LLC — SHIFT REPORT", UDim2.fromOffset(960, 580))
		local gradeColor = ({ Gold = T.mustard, Silver = Color3.fromRGB(200, 200, 210), Bronze = Color3.fromRGB(200, 130, 70) })[data.grade] or T.bad
		Kit.label(content, ("NIGHT %d: %s"):format(data.night, data.title), { Size = UDim2.new(1, 0, 0, 36), Font = T.title, TextColor3 = T.white, MaxText = 30 })
		local headline = if data.success then ("EMPLOYEE BADGE: %s"):format(string.upper(data.grade)) else (REASONS[data.reason] or "SHIFT FAILED")
		local badge = Kit.label(content, headline, { Position = UDim2.fromOffset(0, 40), Size = UDim2.new(1, 0, 0, 46), BackgroundTransparency = 0, BackgroundColor3 = gradeColor, TextColor3 = T.ink, Font = T.title, MaxText = 32 })
		Kit.corner(badge, 10)
		local left = Kit.new("Frame", { Position = UDim2.fromOffset(0, 96), Size = UDim2.new(0.5, -8, 1, -170), BackgroundTransparency = 1, Parent = content })
		Kit.list(left, Enum.FillDirection.Vertical, 2)
		local s = data.stats or {}
		local rows = {
			("Stars: %.1f / 5"):format(data.stars or 0),
			("Orders served: %d  (perfect: %d)"):format(s.served or 0, s.perfect or 0),
			("Late Customers caught: %d"):format(s.caught or 0),
			("Late Customers served (oops): %d"):format(s.lateServed or 0),
			("Late Customers who drove off: %d"):format(s.lateMissed or 0),
			("Normal customers refused: %d"):format(s.refusedNormal or 0),
			("Customers who left angry: %d"):format(s.leftAngry or 0),
		}
		if (s.freed or 0) > 0 then
			table.insert(rows, ("Photo-employees freed: %d"):format(s.freed))
		end
		for _, row in rows do
			Kit.label(left, row, { Size = UDim2.new(1, 0, 0, 26), Font = T.bold, TextXAlignment = Enum.TextXAlignment.Left, MaxText = 18 })
		end
		local right = Kit.new("Frame", { Position = UDim2.new(0.5, 8, 0, 96), Size = UDim2.new(0.5, -8, 1, -170), BackgroundTransparency = 1, Parent = content })
		Kit.list(right, Enum.FillDirection.Vertical, 4)
		for _, title in data.titles or {} do
			Kit.label(right, "🏆 " .. title, { Size = UDim2.new(1, 0, 0, 26), Font = T.bold, TextColor3 = T.mustard, TextXAlignment = Enum.TextXAlignment.Left, MaxText = 18 })
		end
		if data.bestCatch then
			Kit.label(right, "Best catch: " .. data.bestCatch, { Size = UDim2.new(1, 0, 0, 44), Font = T.body, TextXAlignment = Enum.TextXAlignment.Left, MaxText = 16 })
		end
		if data.moment then
			Kit.label(right, "📼 Moment of the Night: " .. data.moment, { Size = UDim2.new(1, 0, 0, 66), Font = T.body, TextColor3 = T.paper, TextXAlignment = Enum.TextXAlignment.Left, MaxText = 16 })
		end
		Kit.label(right, ("💵 Paycheck: +%d"):format(data.paychecks or 0), { Size = UDim2.new(1, 0, 0, 34), Font = T.title, TextColor3 = T.good, TextXAlignment = Enum.TextXAlignment.Left, MaxText = 24 })
		local bar = Kit.new("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 60), BackgroundTransparency = 1, Parent = content })
		Kit.list(bar, Enum.FillDirection.Horizontal, 10, Enum.HorizontalAlignment.Right)
		if not data.isLeader then
			Kit.label(bar, "The shift leader picks what's next.", { Size = UDim2.fromOffset(220, 56), TextColor3 = T.muted, MaxText = 16, LayoutOrder = 0 })
		end
		if data.canNext then
			Kit.button(bar, "NEXT NIGHT ▶", T.good, function()
				State.action("Choose", { choice = "next" })
			end, { Size = UDim2.fromOffset(210, 56), LayoutOrder = 1 })
		end
		Kit.button(bar, "RETRY NIGHT", T.warn, function()
			State.action("Choose", { choice = "retry" })
		end, { Size = UDim2.fromOffset(190, 56), LayoutOrder = 2 })
		Kit.button(bar, "BACK TO THE LOT", T.panelLight, function()
			State.action("Choose", { choice = "lobby" })
		end, { Size = UDim2.fromOffset(220, 56), LayoutOrder = 3 })
	end
	function Report.close()
		if layer then
			layer.Visible = false
		end
	end
end

---------------------------------------------------------------------------
-- Ending
---------------------------------------------------------------------------

local Ending = {}
do
	local layer: Frame
	local token = 0
	function Ending.open(data)
		if not layer then
			layer = Panels.layer("Ending", 0)
		end
		token += 1
		local myToken = token
		Kit.clear(layer)
		layer.Visible = true
		layer.BackgroundTransparency = 1
		TweenService:Create(layer, TweenInfo.new(1.5), { BackgroundTransparency = 0 }):Play()
		local title = Kit.label(layer, data.title or "", { Size = UDim2.new(1, 0, 0, 90), Position = UDim2.fromScale(0, 0.12), Font = T.title, TextColor3 = T.mustard, TextTransparency = 1, MaxText = 70 })
		TweenService:Create(title, TweenInfo.new(2), { TextTransparency = 0 }):Play()
		local list = Kit.scroll(layer, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.26), Size = UDim2.fromOffset(860, 440) })
		Kit.list(list, Enum.FillDirection.Vertical, 4, Enum.HorizontalAlignment.Center)
		Audio.jingle(if data.id == "Freed" then "normal" else "slow")
		task.spawn(function()
			task.wait(2)
			for i, line in data.lines or {} do
				if token ~= myToken then
					return
				end
				local label = Kit.label(list, line, { Size = UDim2.new(1, -16, 0, 28), Font = T.bold, TextColor3 = T.paper, TextTransparency = 1, LayoutOrder = i, MaxText = 22 })
				list.CanvasPosition = Vector2.new(0, math.huge)
				TweenService:Create(label, TweenInfo.new(1), { TextTransparency = 0 }):Play()
				task.wait(if line == "" then 0.6 else 1.6)
			end
			for i, line in data.credits or {} do
				if token ~= myToken then
					return
				end
				Kit.label(list, line, { Size = UDim2.new(1, 0, 0, 22), Font = T.body, TextColor3 = T.muted, LayoutOrder = 100 + i, MaxText = 18 })
				task.wait(0.4)
			end
		end)
		Kit.button(layer, "CONTINUE", T.panelLight, function()
			Panels.close("Ending")
		end, { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -20, 1, -20), Size = UDim2.fromOffset(200, 56) })
	end
	function Ending.close()
		token += 1
		if layer then
			layer.Visible = false
		end
	end
end

---------------------------------------------------------------------------
-- VHS training tape
---------------------------------------------------------------------------

local VHS = {}
do
	local layer: Frame
	local token = 0
	function VHS.open(data)
		if not layer then
			layer = Panels.layer("VHS", 0.3)
		end
		token += 1
		local myToken = token
		Kit.clear(layer)
		layer.Visible = true
		local _, content = Kit.panel(layer, "▶ PLAY — " .. (data.title or "VHS"), UDim2.fromOffset(820, 500), function()
			Panels.close("VHS")
		end)
		local screen = Kit.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(15, 18, 30), Parent = content })
		Kit.corner(screen, 12)
		Kit.padding(screen, 16)
		Kit.list(screen, Enum.FillDirection.Vertical, 6)
		task.spawn(function()
			for i, line in data.lines or {} do
				if token ~= myToken then
					return
				end
				local label = Kit.label(screen, "", { Size = UDim2.new(1, 0, 0, 40), Font = T.mono, TextColor3 = Color3.fromRGB(190, 220, 255), TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = i, MaxText = 18 })
				for c = 1, #line do
					if token ~= myToken then
						return
					end
					label.Text = string.sub(line, 1, c)
					if c % 3 == 0 then
						Audio.blip(7)
					end
					task.wait(0.025)
				end
				task.wait(0.6)
			end
		end)
	end
	function VHS.close()
		token += 1
		if layer then
			layer.Visible = false
		end
	end
end

---------------------------------------------------------------------------

function Panels.init()
	gui = Kit.screen("NightShiftPanels", 10)
	Panels.root = Kit.root(gui)
	Panels.register("PreShift", PreShift)
	Panels.register("HoldBreath", HoldBreath)
	Panels.register("Report", Report)
	Panels.register("Ending", Ending)
	Panels.register("VHS", VHS)
	Net.event("OpenPanel").OnClientEvent:Connect(function(name, data)
		local ok, err = pcall(Panels.open, name, data)
		if not ok then
			warn("[Panels] open " .. tostring(name) .. ": " .. tostring(err))
		end
	end)
	Net.event("ClosePanel").OnClientEvent:Connect(function(name)
		local ok, err = pcall(Panels.close, name)
		if not ok then
			warn("[Panels] close " .. tostring(name) .. ": " .. tostring(err))
		end
	end)
	player:GetAttributeChangedSignal("Crew"):Connect(function()
		if not State.isCrew() then
			for _, name in { "PreShift", "HoldBreath", "Order", "Assembly", "Window" } do
				Panels.close(name)
			end
		end
	end)
end

return Panels
