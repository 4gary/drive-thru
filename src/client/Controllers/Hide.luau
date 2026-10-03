-- Hiding-spot view (design doc §5.4): a peephole camera while hidden, the kitchen keeps going
-- without you, a LEAVE button (F), and a "getting cramped" meter for anti-camping.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Layout = require(Shared.Builders.Layout)
local Kit = require(script.Parent.Parent.UI.Kit)
local State = require(script.Parent.State)
local CameraView = require(script.Parent.CameraView)
local Effects = require(script.Parent.Effects)

local T = Kit.Theme
local player = Players.LocalPlayer

local Hide = {}

local gui: ScreenGui
local meterFill: Frame
local title: TextLabel
local hiddenSince = 0

local function leave()
	if State.isHidden() then
		State.action("LeaveHide")
	end
end

local function refresh()
	local spotId = player:GetAttribute("Hidden")
	if spotId and Layout.HidingSpots[spotId] then
		local spot = Layout.HidingSpots[spotId]
		hiddenSince = os.clock()
		CameraView.push("Hide", CFrame.lookAt(spot.peekFrom, spot.peekTo), 75)
		title.Text = ("HIDING: %s"):format(string.upper(spot.label))
		gui.Enabled = true
		ContextActionService:BindAction("NS_LeaveHide", function(_, inputState)
			if inputState == Enum.UserInputState.Begin then
				leave()
			end
			return Enum.ContextActionResult.Sink
		end, false, Enum.KeyCode.F)
	else
		CameraView.pop("Hide")
		gui.Enabled = false
		ContextActionService:UnbindAction("NS_LeaveHide")
		Effects.vignette(nil, false)
	end
end

function Hide.init()
	gui = Kit.screen("NightShiftHide", 8)
	gui.Enabled = false
	local root = Kit.root(gui)
	-- peephole: dark bars around a slot
	local shade = Color3.fromRGB(8, 8, 10)
	Kit.new("Frame", { Size = UDim2.fromScale(1, 0.3), BackgroundColor3 = shade, BackgroundTransparency = 0.05, Parent = root })
	Kit.new("Frame", { Position = UDim2.fromScale(0, 0.7), Size = UDim2.fromScale(1, 0.3), BackgroundColor3 = shade, BackgroundTransparency = 0.05, Parent = root })
	Kit.new("Frame", { Position = UDim2.fromScale(0, 0.3), Size = UDim2.fromScale(0.12, 0.4), BackgroundColor3 = shade, BackgroundTransparency = 0.2, Parent = root })
	Kit.new("Frame", { Position = UDim2.fromScale(0.88, 0.3), Size = UDim2.fromScale(0.12, 0.4), BackgroundColor3 = shade, BackgroundTransparency = 0.2, Parent = root })
	title = Kit.label(root, "HIDING", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 24), Size = UDim2.fromOffset(600, 40), Font = T.title, TextColor3 = T.mustard, MaxText = 32 })
	Kit.label(root, "Every second hidden is a second not cooking. Stay too long and you'll get popped out.", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 68),
		Size = UDim2.fromOffset(760, 28),
		TextColor3 = T.muted,
		MaxText = 16,
	})
	local meter = Kit.new("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -110), Size = UDim2.fromOffset(420, 22), BackgroundColor3 = T.panelLight, Parent = root })
	Kit.corner(meter, 8)
	meterFill = Kit.new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = T.warn, Parent = meter })
	Kit.corner(meterFill, 8)
	Kit.label(meter, "CRAMPED", { Size = UDim2.fromScale(1, 1), Font = T.bold, MaxText = 14 })
	Kit.button(root, "LEAVE (F)", T.ketchup, leave, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -24), Size = UDim2.fromOffset(280, 72) })

	player:GetAttributeChangedSignal("Hidden"):Connect(refresh)
	task.spawn(function()
		while true do
			task.wait(0.1)
			if gui.Enabled then
				local alpha = math.clamp((os.clock() - hiddenSince) / Config.Hide.CampMaxSeconds, 0, 1)
				meterFill.Size = UDim2.fromScale(alpha, 1)
				meterFill.BackgroundColor3 = T.good:Lerp(T.bad, alpha)
			end
		end
	end)
	refresh()
end

return Hide
