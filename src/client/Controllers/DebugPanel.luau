-- Studio-only DEBUG panel for playtesting (never appears in a live game).

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local WeirdEvents = require(Shared.Data.WeirdEvents)
local Kit = require(script.Parent.Parent.UI.Kit)
local State = require(script.Parent.State)

local T = Kit.Theme

local DebugPanel = {}

function DebugPanel.init()
	if not RunService:IsStudio() or not Config.DebugPanelInStudio then
		return
	end
	local gui = Kit.screen("NightShiftDebug", 50, true)
	local root = Kit.root(gui)
	local panel = Kit.new("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 8, 0.6, 0),
		Size = UDim2.fromOffset(240, 420),
		BackgroundColor3 = T.ink,
		BackgroundTransparency = 0.1,
		Visible = false,
		Parent = root,
	})
	Kit.corner(panel, 10)
	local scroll = Kit.scroll(panel, { Size = UDim2.new(1, -8, 1, -8), Position = UDim2.fromOffset(4, 4) })
	Kit.new("UIGridLayout", { CellSize = UDim2.fromOffset(110, 36), CellPadding = UDim2.fromOffset(4, 4), Parent = scroll })
	Kit.button(root, "DEBUG", T.uv, function()
		panel.Visible = not panel.Visible
	end, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 8, 0.6, -240), Size = UDim2.fromOffset(110, 40) })
	local events = {}
	for id in WeirdEvents.ById do
		table.insert(events, id)
	end
	table.sort(events)
	local eventIndex = 0
	local commands = {
		{ "Night 1", "start", 1 },
		{ "Night 2", "start", 2 },
		{ "Night 3", "start", 3 },
		{ "Night 4", "start", 4 },
		{ "Night 5", "start", 5 },
		{ "+1 Hour", "skip" },
		{ "Win Night", "win" },
		{ "Fail Night", "fail" },
		{ "End Shift", "endShift" },
		{ "Rush Hour", "rush" },
		{ "High Beams", "beams" },
		{ "Lights Out", "lightsout" },
		{ "Late Car", "late" },
		{ "Normal Car", "normal" },
		{ "Hendersons", "late", "Hendersons" },
		{ "Gerald", "late", "Gerald" },
		{ "Weird 100%", "weird" },
		{ "Stars +1", "starsUp" },
		{ "Stars -1", "starsDown" },
		{ "Boop Me", "boop" },
		{ "Reveal", "reveal" },
		{ "Give UV", "uv" },
		{ "Unlock All", "unlock" },
		{ "+500 Pay", "pay" },
	}
	for i, c in commands do
		Kit.button(scroll, c[1], T.panelLight, function()
			State.action("Debug", { cmd = c[2], arg = c[3] })
		end, { LayoutOrder = i, Font = T.bold })
	end
	Kit.button(scroll, "Next Weird Event", T.uv, function()
		eventIndex = (eventIndex % #events) + 1
		State.action("Debug", { cmd = "event", arg = events[eventIndex] })
	end, { LayoutOrder = 100, Font = T.bold })
end

return DebugPanel
