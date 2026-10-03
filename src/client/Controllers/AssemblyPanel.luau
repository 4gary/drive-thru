-- The assembly board (design doc §6.4 "Grill: place on bun -> add toppings in order (ticket shows
-- stack)"). Pick a target from the ticket rail; the next layer you need is highlighted (snap assist).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Layout = require(Shared.Builders.Layout)
local Menu = require(Shared.Data.Menu)
local Kit = require(script.Parent.Parent.UI.Kit)
local State = require(script.Parent.State)
local Panels = require(script.Parent.Panels)

local T = Kit.Theme
local player = Players.LocalPlayer

local AssemblyPanel = {}

local layer: Frame
local targetList: Frame
local targetStack: Frame
local plateStack: Frame
local hint: TextLabel
local buttons: { [string]: TextButton } = {}
local takeButton: TextButton
local data: any = nil
local targetIndex = 1
local lastTargetSig = ""

local OP_FOR = { BunBottom = "Bun", BunTop = "Bun", Patty = "Patty", Cheese = "Cheese", Lettuce = "Lettuce", Pickles = "Pickles", Sauce = "Sauce" }

local function burgerTargets()
	local out = {}
	local shift = State.shift
	if not shift then
		return out
	end
	for _, ticket in shift.tickets or {} do
		for _, line in ticket.lines do
			if line.stack and not line.done then
				table.insert(out, { number = ticket.number, label = line.label, stack = line.stack })
			end
		end
	end
	return out
end

local function drawStack(container: Frame, stack: { string }, highlightIndex: number?)
	Kit.clear(container)
	for i = #stack, 1, -1 do
		local topping = stack[i]
		local info = Menu.Toppings[topping]
		local bar = Kit.label(container, (info and info.label or topping) .. (if i == highlightIndex then "  ◀ NEXT" else ""), {
			Size = UDim2.new(1, 0, 0, 30),
			BackgroundTransparency = 0,
			BackgroundColor3 = if info then info.color else T.panelLight,
			TextColor3 = if topping == "Patty" or topping == "Pickles" then T.white else T.ink,
			Font = T.bold,
			LayoutOrder = #stack - i,
			MaxText = 16,
		})
		Kit.corner(bar, 8)
		if i == highlightIndex then
			Kit.stroke(bar, T.white, 3)
		end
	end
	if #stack == 0 then
		Kit.label(container, "(empty plate)", { Size = UDim2.new(1, 0, 0, 30), TextColor3 = T.muted, MaxText = 16 })
	end
end

local function render()
	if not data then
		return
	end
	local targets = burgerTargets()
	targetIndex = math.clamp(targetIndex, 1, math.max(1, #targets))
	-- only rebuild the target buttons when they actually change (never under the player's finger)
	local sigParts = { tostring(targetIndex) }
	for i, t in targets do
		if i <= 5 then
			table.insert(sigParts, t.number .. t.label)
		end
	end
	local sig = table.concat(sigParts, "|")
	if sig ~= lastTargetSig then
		lastTargetSig = sig
		Kit.clear(targetList)
		for i, t in targets do
			if i > 5 then
				break
			end
			Kit.button(targetList, ("#%d %s"):format(t.number, t.label), if i == targetIndex then T.ketchup else T.panelLight, function()
				targetIndex = i
				render()
			end, { Size = UDim2.new(1, 0, 0, 40), LayoutOrder = i, Font = T.bold })
		end
		if #targets == 0 then
			Kit.label(targetList, "No burgers on the tickets.", { Size = UDim2.new(1, 0, 0, 30), TextColor3 = T.muted, MaxText = 16 })
		end
	end
	local target = targets[targetIndex]
	local plate = data.stack or {}
	local nextIndex = nil
	local nextLayer = nil
	if target then
		local matches = #plate <= #target.stack
		for i, layerName in plate do
			if target.stack[i] ~= layerName then
				matches = false
			end
		end
		if matches and #plate < #target.stack then
			nextIndex = #plate + 1
			nextLayer = target.stack[nextIndex]
		end
		drawStack(targetStack, target.stack, nextIndex)
		if not matches then
			hint.Text = "⚠ The plate doesn't match this ticket. CLEAR it or pick another target."
			hint.TextColor3 = T.bad
		elseif nextLayer then
			hint.Text = "NEXT: " .. (Menu.Toppings[nextLayer] and Menu.Toppings[nextLayer].label or nextLayer)
			hint.TextColor3 = T.mustard
		else
			hint.Text = "Done! TAKE BURGER and bag it."
			hint.TextColor3 = T.good
		end
	else
		Kit.clear(targetStack)
		hint.Text = if data.finished then "Finished: " .. tostring(data.label) else "Build whatever you like."
		hint.TextColor3 = T.muted
	end
	if data.grabby then
		hint.Text = "✋ GRABBY HANDS are holding the topping bins! Shoo them (F at the board)."
		hint.TextColor3 = T.bad
	end
	drawStack(plateStack, plate, nil)
	local holdingPatty = player:GetAttribute("Holding") == "Cooked Patty"
	for op, button in buttons do
		local isNext = nextLayer ~= nil and OP_FOR[nextLayer] == op
		local enabled = not data.finished
		if op == "Patty" then
			enabled = enabled and holdingPatty
		elseif op ~= "Bun" then
			enabled = enabled and not data.grabby and #plate > 0
		end
		button.Active = enabled
		button.AutoButtonColor = enabled
		button.BackgroundColor3 = if not enabled then T.ink elseif isNext then T.mustard else T.panelLight
		button.TextColor3 = if isNext then T.ink else (if enabled then T.white else T.muted)
	end
	takeButton.Visible = data.finished == true
end

local function build()
	layer = Panels.layer("Assembly", 0.25)
	local _, content = Kit.panel(layer, "ASSEMBLY BOARD", UDim2.fromOffset(980, 560), function()
		State.action("Assembly", { op = "Close" })
		Panels.close("Assembly")
	end)
	local col1 = Kit.new("Frame", { Size = UDim2.new(0.3, -8, 1, 0), BackgroundTransparency = 1, Parent = content })
	Kit.label(col1, "TARGET TICKET", { Size = UDim2.new(1, 0, 0, 26), Font = T.title, TextColor3 = T.mustard, MaxText = 20 })
	targetList = Kit.new("Frame", { Position = UDim2.fromOffset(0, 30), Size = UDim2.new(1, 0, 0, 220), BackgroundTransparency = 1, Parent = col1 })
	Kit.list(targetList, Enum.FillDirection.Vertical, 6)
	Kit.label(col1, "RECIPE (top → bottom)", { Position = UDim2.fromOffset(0, 254), Size = UDim2.new(1, 0, 0, 22), Font = T.bold, TextColor3 = T.muted, MaxText = 15 })
	targetStack = Kit.new("Frame", { Position = UDim2.fromOffset(0, 280), Size = UDim2.new(1, 0, 1, -280), BackgroundTransparency = 1, Parent = col1 })
	Kit.list(targetStack, Enum.FillDirection.Vertical, 3)

	local col2 = Kit.new("Frame", { Position = UDim2.new(0.3, 8, 0, 0), Size = UDim2.new(0.3, -8, 1, 0), BackgroundTransparency = 1, Parent = content })
	Kit.label(col2, "ON THE PLATE", { Size = UDim2.new(1, 0, 0, 26), Font = T.title, TextColor3 = T.mustard, MaxText = 20 })
	plateStack = Kit.new("Frame", { Position = UDim2.fromOffset(0, 30), Size = UDim2.new(1, 0, 1, -30), BackgroundTransparency = 1, Parent = col2 })
	Kit.list(plateStack, Enum.FillDirection.Vertical, 3)

	local col3 = Kit.new("Frame", { Position = UDim2.new(0.6, 8, 0, 0), Size = UDim2.new(0.4, -8, 1, 0), BackgroundTransparency = 1, Parent = content })
	hint = Kit.label(col3, "", { Size = UDim2.new(1, 0, 0, 56), Font = T.title, TextColor3 = T.mustard, MaxText = 22 })
	local grid = Kit.new("Frame", { Position = UDim2.fromOffset(0, 62), Size = UDim2.new(1, 0, 0, 250), BackgroundTransparency = 1, Parent = col3 })
	Kit.new("UIGridLayout", { CellSize = UDim2.new(0.5, -6, 0, 74), CellPadding = UDim2.fromOffset(8, 8), Parent = grid })
	for i, op in Menu.ToppingButtons do
		buttons[op] = Kit.button(grid, string.upper(op), T.panelLight, function()
			State.action("Assembly", { op = op })
		end, { LayoutOrder = i })
	end
	takeButton = Kit.button(col3, "TAKE BURGER", T.good, function()
		State.action("Assembly", { op = "Take" })
	end, { Position = UDim2.fromOffset(0, 330), Size = UDim2.new(1, 0, 0, 70), Visible = false })
	Kit.button(col3, "CLEAR PLATE", T.bad, function()
		State.action("Assembly", { op = "Clear" })
	end, { AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 56) })
end

function AssemblyPanel.open(d)
	if not layer then
		build()
	end
	if not data then
		lastTargetSig = ""
	end
	data = d
	layer.Visible = true
	render()
end

function AssemblyPanel.close()
	data = nil
	if layer then
		layer.Visible = false
	end
end

function AssemblyPanel.init()
	Panels.register("Assembly", AssemblyPanel)
	State.ShiftChanged:Connect(function()
		if data and layer and layer.Visible then
			render()
		end
	end)
	player:GetAttributeChangedSignal("Holding"):Connect(function()
		if data and layer and layer.Visible then
			render()
		end
	end)
	task.spawn(function()
		while true do
			task.wait(0.5)
			if data and layer and layer.Visible then
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
				if root and (root.Position - Layout.Stations.AssemblyPlate).Magnitude > 14 then
					State.action("Assembly", { op = "Close" })
					Panels.close("Assembly")
				end
			end
		end
	end)
end

return AssemblyPanel
