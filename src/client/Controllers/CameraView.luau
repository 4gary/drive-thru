-- A tiny stack of scripted camera views (pickup window, Lane Cam, hiding-spot peephole...).
-- When the stack empties the normal follow camera comes back.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local CameraView = {}

local stack: { { name: string, cframe: CFrame, fov: number } } = {}
local savedFov = 70

local function camera(): Camera
	return workspace.CurrentCamera :: Camera
end

local function apply()
	local cam = camera()
	local top = stack[#stack]
	if top then
		cam.CameraType = Enum.CameraType.Scriptable
		TweenService:Create(cam, TweenInfo.new(0.35, Enum.EasingStyle.Quad), { CFrame = top.cframe, FieldOfView = top.fov }):Play()
	else
		cam.CameraType = Enum.CameraType.Custom
		cam.FieldOfView = savedFov
		local character = Players.LocalPlayer.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			cam.CameraSubject = humanoid
		end
	end
end

function CameraView.push(name: string, cframe: CFrame, fov: number?)
	if #stack == 0 then
		savedFov = camera().FieldOfView
	end
	for i = #stack, 1, -1 do
		if stack[i].name == name then
			table.remove(stack, i)
		end
	end
	table.insert(stack, { name = name, cframe = cframe, fov = fov or 70 })
	apply()
end

function CameraView.pop(name: string)
	local changed = false
	for i = #stack, 1, -1 do
		if stack[i].name == name then
			table.remove(stack, i)
			changed = true
		end
	end
	if changed then
		apply()
	end
end

function CameraView.top(): string?
	local top = stack[#stack]
	return top and top.name
end

function CameraView.clear()
	table.clear(stack)
	apply()
end

function CameraView.init()
	Players.LocalPlayer.CharacterAdded:Connect(function()
		task.defer(function()
			if #stack == 0 then
				apply()
			end
		end)
	end)
end

return CameraView
