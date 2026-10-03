-- The order station CRT (design doc §6.4 "Order (speaker)"): the customer's words come through the
-- headset (with speaker-channel tells: static, backwards words, unison voices, pitch shifts) and you
-- tap the menu to enter the order. Flag SUSPICIOUS to warn the crew.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Menu = require(Shared.Data.Menu)
local OrderLogic = require(Shared.OrderLogic)
local Kit = require(script.Parent.Parent.UI.Kit)
local State = require(script.Parent.State)
local Audio = require(script.Parent.Audio)
local Panels = require(script.Parent.Panels)
local Effects = require(script.Parent.Effects)

local T = Kit.Theme
local player = Players.LocalPlayer

local OrderPanel = {}

local layer: Frame
local speakerBox: ScrollingFrame
local orderList: ScrollingFrame
local flagButton: TextButton
local current: any = nil
local lines: { { item: string, mods: { string } } } = {}
local flagged = false
local typeToken = 0

local GLITCH = { "▒", "#", "%", "?", "@", "~" }

local function glitch(text: string): string
	local out = {}
	for i = 1, #text do
		local c = string.sub(text, i, i)
		if c ~= " " and math.random() < 0.18 then
			c = GLITCH[math.random(1, #GLITCH)]
		end
		table.insert(out, c)
	end
	return table.concat(out)
end

local function renderOrder()
	Kit.clear(orderList)
	if #lines == 0 then
		Kit.label(orderList, "(empty — tap the menu to add items)", { Size = UDim2.new(1, -10, 0, 30), TextColor3 = T.muted, MaxText = 16 })
	end
	for i, line in lines do
		local row = Kit.new("Frame", { Size = UDim2.new(1, -10, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = T.panelLight, LayoutOrder = i, Parent = orderList })
		Kit.corner(row, 8)
		Kit.padding(row, 6)
		local def = Menu.Items[line.item]
		Kit.label(row, ("#%d %s"):format(def.number, OrderLogic.lineLabel(line)), { Size = UDim2.new(1, -60, 0, 28), Font = T.bold, TextXAlignment = Enum.TextXAlignment.Left, MaxText = 18 })
		Kit.button(row, "✕", T.bad, function()
			table.remove(lines, i)
			renderOrder()
		end, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.fromOffset(44, 30) })
		local valid = OrderLogic.validMods(line.item)
		if #valid > 0 then
			local chips = Kit.new("Frame", { Position = UDim2.fromOffset(0, 32), Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Parent = row })
			Kit.new("UIGridLayout", { CellSize = UDim2.fromOffset(118, 30), CellPadding = UDim2.fromOffset(4, 4), Parent = chips })
			for j, modId in valid do
				local on = table.find(line.mods, modId) ~= nil
				Kit.button(chips, Menu.Mods[modId].label, if on then T.mustard else T.ink, function()
					local index = table.find(line.mods, modId)
					if index then
						table.remove(line.mods, index)
					else
						-- one mod per topping (can't have "No Cheese" and "Extra Cheese")
						for k = #line.mods, 1, -1 do
							if Menu.Mods[line.mods[k]].topping == Menu.Mods[modId].topping then
								table.remove(line.mods, k)
							end
						end
						table.insert(line.mods, modId)
					end
					renderOrder()
				end, { LayoutOrder = j, Font = T.bold, TextColor3 = if on then T.ink else T.white })
			end
		end
	end
end

local function typeSpeaker(data)
	typeToken += 1
	local token = typeToken
	Kit.clear(speakerBox)
	local surf = Effects.flagActive("ChannelSurf")
	task.spawn(function()
		for i, text in data.lines or {} do
			if token ~= typeToken then
				return
			end
			local shown = text
			if data.reversed then
				shown = text .. "  [the words sound... backwards]"
			end
			local label = Kit.label(speakerBox, "", {
				Size = UDim2.new(1, -8, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				TextScaled = false,
				TextSize = 22,
				Font = T.mono,
				TextColor3 = if data.unison then Color3.fromRGB(200, 255, 200) else T.crtText,
				TextXAlignment = Enum.TextXAlignment.Left,
				LayoutOrder = i,
			})
			for c = 1, #shown do
				if token ~= typeToken then
					return
				end
				local partial = string.sub(shown, 1, c)
				if data.static or surf then
					partial = glitch(partial)
				end
				label.Text = "🔊 " .. partial
				if c % 2 == 0 then
					Audio.blip(data.voiceSeed or 3, data.static or data.reversed)
				end
				task.wait(0.022)
			end
			if data.static then
				label.Text = "🔊 " .. glitch(shown)
			end
			task.wait(0.35)
		end
		for j, caption in data.captions or {} do
			Kit.label(speakerBox, caption, {
				Size = UDim2.new(1, -8, 0, 26),
				Font = T.bold,
				TextColor3 = T.muted,
				TextXAlignment = Enum.TextXAlignment.Left,
				LayoutOrder = 100 + j,
				MaxText = 18,
			})
		end
		if data.wantsUsual then
			Kit.label(speakerBox, "(The usual? Check the back of their Employee of the Month photo — with UV.)", {
				Size = UDim2.new(1, -8, 0, 44),
				Font = T.bold,
				TextColor3 = T.uv,
				TextXAlignment = Enum.TextXAlignment.Left,
				LayoutOrder = 200,
				MaxText = 16,
			})
		end
	end)
end

local function build()
	layer = Panels.layer("Order", 0.35)
	local _, content = Kit.panel(layer, "MUNCHIE'S POS v1.987 — TAKE ORDER", UDim2.fromOffset(1060, 600), function()
		OrderPanel.cancel()
	end)
	-- speaker side
	local crt = Kit.new("Frame", { Size = UDim2.new(0.42, -8, 1, -70), BackgroundColor3 = T.crt, Parent = content })
	Kit.corner(crt, 12)
	Kit.stroke(crt, Color3.fromRGB(60, 90, 60), 3)
	Kit.label(crt, "🎧 HEADSET", { Size = UDim2.new(1, -16, 0, 28), Position = UDim2.fromOffset(8, 6), Font = T.mono, TextColor3 = T.crtText, TextXAlignment = Enum.TextXAlignment.Left, MaxText = 20 })
	speakerBox = Kit.scroll(crt, { Size = UDim2.new(1, -16, 1, -80), Position = UDim2.fromOffset(8, 38) })
	Kit.list(speakerBox, Enum.FillDirection.Vertical, 8)
	Kit.button(crt, "▶ REPLAY", Color3.fromRGB(30, 60, 35), function()
		if current then
			typeSpeaker(current)
		end
	end, { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 8, 1, -8), Size = UDim2.fromOffset(150, 40) })
	-- menu side
	local right = Kit.new("Frame", { Position = UDim2.new(0.42, 8, 0, 0), Size = UDim2.new(0.58, -8, 1, -70), BackgroundTransparency = 1, Parent = content })
	local menu = Kit.new("Frame", { Size = UDim2.new(1, 0, 0, 150), BackgroundTransparency = 1, Parent = right })
	Kit.new("UIGridLayout", { CellSize = UDim2.new(1 / 3, -6, 0, 70), CellPadding = UDim2.fromOffset(8, 8), Parent = menu })
	for i, itemId in Menu.Order do
		local def = Menu.Items[itemId]
		Kit.button(menu, ("#%d %s"):format(def.number, def.name), def.color, function()
			table.insert(lines, { item = itemId, mods = {} })
			renderOrder()
		end, { LayoutOrder = i, TextColor3 = T.ink })
	end
	Kit.label(right, "Gerald's #7? There is no #7. Send an empty order.", { Position = UDim2.fromOffset(0, 154), Size = UDim2.new(1, 0, 0, 20), TextColor3 = T.muted, MaxText = 13 })
	orderList = Kit.scroll(right, { Position = UDim2.fromOffset(0, 178), Size = UDim2.new(1, 0, 1, -178) })
	Kit.list(orderList, Enum.FillDirection.Vertical, 6)
	-- bottom bar
	local bar = Kit.new("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 60), BackgroundTransparency = 1, Parent = content })
	flagButton = Kit.button(bar, "⚠ FLAG SUSPICIOUS", T.panelLight, function()
		flagged = not flagged
		flagButton.BackgroundColor3 = if flagged then T.warn else T.panelLight
	end, { Size = UDim2.fromOffset(300, 56) })
	Kit.button(bar, "CLEAR", T.panelLight, function()
		table.clear(lines)
		renderOrder()
	end, { Position = UDim2.fromOffset(312, 0), Size = UDim2.fromOffset(140, 56) })
	Kit.button(bar, "SEND TO KITCHEN ▶", T.good, function()
		if not current then
			return
		end
		local payload = {}
		for _, line in lines do
			table.insert(payload, { item = line.item, mods = line.mods })
		end
		State.action("SubmitOrder", { carId = current.carId, lines = payload, flagged = flagged })
	end, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.fromOffset(320, 56) })
end

function OrderPanel.open(data)
	if not layer then
		build()
	end
	current = data
	table.clear(lines)
	flagged = false
	flagButton.BackgroundColor3 = T.panelLight
	layer.Visible = true
	renderOrder()
	typeSpeaker(data)
end

function OrderPanel.close()
	typeToken += 1
	current = nil
	if layer then
		layer.Visible = false
	end
end

function OrderPanel.cancel()
	if current then
		State.action("CancelOrder", { carId = current.carId })
	end
	Panels.close("Order")
end

function OrderPanel.init()
	Panels.register("Order", OrderPanel)
	-- walking away from the console closes it
	task.spawn(function()
		while true do
			task.wait(0.5)
			if current and layer and layer.Visible then
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
				local map = workspace:FindFirstChild("Munchies")
				local console = map and map:FindFirstChild("Kitchen") and map.Kitchen:FindFirstChild("OrderConsole") :: BasePart?
				if root and console and (root.Position - console.Position).Magnitude > 16 then
					OrderPanel.cancel()
				end
			end
		end
	end)
end

return OrderPanel
