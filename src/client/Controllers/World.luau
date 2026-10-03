-- Client-side world visuals:
--  * channel visibility: parts tagged "ChannelPart" only show in the right inspection channel
--    (CamOnly on the Lane Cam, NotOnCam everywhere except the Lane Cam, UVOnly under UV light)
--  * the UV flashlight
--  * little animations that make tells readable: blinking, finger counts that change,
--    TV-static skin, a smile that grows when you look away, blinking traffic light.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local World = {}

local player = Players.LocalPlayer
World.mode = "Normal" -- "Normal" | "LaneCam"
World.uv = false

local function setGuiEnabled(part: Instance, enabled: boolean)
	for _, d in part:GetDescendants() do
		if d:IsA("SurfaceGui") or d:IsA("BillboardGui") then
			d.Enabled = enabled
		end
	end
end

local function applyChannel(part: Instance)
	if not part:IsA("BasePart") then
		return
	end
	local mode = part:GetAttribute("Channel")
	local visible = true
	if mode == "CamOnly" then
		visible = World.mode == "LaneCam"
	elseif mode == "NotOnCam" then
		visible = World.mode ~= "LaneCam"
	elseif mode == "UVOnly" then
		visible = World.uv
	end
	part.LocalTransparencyModifier = if visible then 0 else 1
	setGuiEnabled(part, visible)
end

function World.refreshChannels()
	for _, part in CollectionService:GetTagged("ChannelPart") do
		applyChannel(part)
	end
end

function World.setMode(mode: string)
	World.mode = mode
	World.refreshChannels()
end

local uvLight: SpotLight? = nil
function World.setUV(on: boolean)
	World.uv = on
	World.refreshChannels()
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	if on and head then
		if not uvLight or not uvLight.Parent then
			local light = Instance.new("SpotLight")
			light.Name = "UVLight"
			light.Color = Color3.fromRGB(170, 70, 255)
			light.Brightness = 4
			light.Range = 40
			light.Angle = 50
			light.Face = Enum.NormalId.Front
			light.Parent = head
			uvLight = light
		end
	elseif uvLight then
		uvLight:Destroy()
		uvLight = nil
	end
end

---------------------------------------------------------------------------
-- Tell animations
---------------------------------------------------------------------------

local blinkAt: { [Instance]: number } = {}
local fingerAt: { [Instance]: number } = {}
local smiles: { [Instance]: number } = {}

local function faceOf(head: Instance): Frame?
	local gui = head:FindFirstChild("FaceGui")
	return gui and gui:FindFirstChild("Face") :: Frame?
end

local function animateCars(now: number)
	local map = workspace:FindFirstChild("Munchies")
	local dynamic = map and map:FindFirstChild("Dynamic")
	local cars = dynamic and dynamic:FindFirstChild("Cars")
	if not cars then
		return
	end
	local camera = workspace.CurrentCamera
	for _, car in cars:GetChildren() do
		for _, d in car:GetChildren() do
			if d:IsA("BasePart") and d:GetAttribute("IsDriverHead") then
				local face = faceOf(d)
				if face and d:GetAttribute("Blinks") then
					local nextBlink = blinkAt[d] or (now + math.random() * 3)
					local closed = now >= nextBlink and now < nextBlink + 0.14
					for _, lid in { "LidL", "LidR" } do
						local f = face:FindFirstChild(lid) :: Frame?
						if f then
							f.Visible = closed
						end
					end
					if now >= nextBlink + 0.14 then
						blinkAt[d] = now + 2 + math.random() * 3
					elseif not blinkAt[d] then
						blinkAt[d] = nextBlink
					end
				end
				if face and d:GetAttribute("GrowingSmile") and camera then
					local toHead = (d.Position - camera.CFrame.Position).Unit
					local looking = camera.CFrame.LookVector:Dot(toHead) > 0.93
					local width = smiles[d] or 0.5
					if not looking then
						width = math.min(0.95, width + 0.004)
					end
					smiles[d] = width
					local mouth = face:FindFirstChild("Mouth") :: Frame?
					local cover = face:FindFirstChild("MouthCover") :: Frame?
					if mouth and cover then
						mouth.Size = UDim2.fromScale(width, 0.16)
						cover.Size = UDim2.fromScale(width + 0.06, 0.12)
					end
				end
				if d:GetAttribute("Static") then
					local g = 0.4 + math.random() * 0.5
					d.Color = Color3.new(g, g, g)
				end
			elseif d:IsA("Model") and d.Name == "Hand" and d:GetAttribute("FingerCycle") then
				local nextCycle = fingerAt[d] or 0
				if now >= nextCycle then
					fingerAt[d] = now + 0.9
					local show = math.random(6, 7)
					for _, finger in d:GetChildren() do
						local digit = finger:GetAttribute("Digit")
						if digit and finger:IsA("BasePart") then
							finger.LocalTransparencyModifier = if digit <= show then 0 else 1
						end
					end
				end
			end
		end
	end
end

local function blinkTrafficLight(now: number)
	local on = math.floor(now * 1.2) % 2 == 0
	for _, part in CollectionService:GetTagged("BlinkLight") do
		if part:IsA("BasePart") then
			part.LocalTransparencyModifier = if on then 0 else 0.85
			local light = part:FindFirstChildOfClass("PointLight")
			if light then
				light.Enabled = on
			end
		end
	end
end

function World.init()
	CollectionService:GetInstanceAddedSignal("ChannelPart"):Connect(function(part)
		task.defer(applyChannel, part)
	end)
	World.refreshChannels()
	player.CharacterAdded:Connect(function()
		uvLight = nil
		if World.uv then
			task.wait(0.5)
			World.setUV(true)
		end
	end)
	local accumulator = 0
	RunService.RenderStepped:Connect(function(dt)
		accumulator += dt
		if accumulator < 1 / 30 then
			return
		end
		accumulator = 0
		local now = os.clock()
		animateCars(now)
		blinkTrafficLight(now)
	end)
	-- forget destroyed heads
	task.spawn(function()
		while true do
			task.wait(10)
			for head in blinkAt do
				if not head.Parent then
					blinkAt[head] = nil
					smiles[head] = nil
				end
			end
			for hand in fingerAt do
				if not hand.Parent then
					fingerAt[hand] = nil
				end
			end
		end
	end)
end

return World
