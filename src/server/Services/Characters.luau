-- Spawning, crew cosmetics (visor / apron / name tag built from parts), crouching, walk speed
-- modifiers (sticky floors, ear rain) and collision groups (crew don't block each other; ghosts
-- only touch the ghost floor).

local Players = game:GetService("Players")
local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Cosmetics = require(Shared.Data.Cosmetics)
local Layout = require(Shared.Builders.Layout)
local ModelFactory = require(Shared.Builders.ModelFactory)
local ctx = require(script.Parent.Context)

local Characters = {}

local state: { [Player]: { crouch: boolean, stickyUntil: number, baseHip: number } } = {}
Characters.puddles = {} :: { { part: BasePart, expires: number } }

local GROUPS = { "Players", "Ghosts", "GhostFloor", "GhostBounds" }

local function setupCollisionGroups()
	for _, group in GROUPS do
		pcall(function()
			PhysicsService:RegisterCollisionGroup(group)
		end)
	end
	PhysicsService:CollisionGroupSetCollidable("Players", "Players", false)
	PhysicsService:CollisionGroupSetCollidable("Ghosts", "Default", false)
	PhysicsService:CollisionGroupSetCollidable("Ghosts", "Players", false)
	PhysicsService:CollisionGroupSetCollidable("Ghosts", "Ghosts", false)
	PhysicsService:CollisionGroupSetCollidable("GhostFloor", "Default", false)
	PhysicsService:CollisionGroupSetCollidable("GhostFloor", "Players", false)
	PhysicsService:CollisionGroupSetCollidable("GhostBounds", "Default", false)
	PhysicsService:CollisionGroupSetCollidable("GhostBounds", "Players", false)
	PhysicsService:CollisionGroupSetCollidable("Ghosts", "GhostFloor", true)
	PhysicsService:CollisionGroupSetCollidable("Ghosts", "GhostBounds", true)
	-- re-apply in case the map was built before the groups existed
	for _, p in CollectionService:GetTagged("GhostFloor") do
		if p:IsA("BasePart") then
			p.CollisionGroup = "GhostFloor"
		end
	end
	for _, p in CollectionService:GetTagged("GhostBounds") do
		if p:IsA("BasePart") then
			p.CollisionGroup = "GhostBounds"
		end
	end
end

function Characters.setGroup(character: Model, group: string)
	for _, d in character:GetDescendants() do
		if d:IsA("BasePart") then
			d.CollisionGroup = group
		end
	end
end

-- LoadCharacterAsync yields; callers shouldn't have to wait for it.
local function loadCharacter(player: Player)
	task.spawn(function()
		local ok, err = pcall(function()
			player:LoadCharacterAsync()
		end)
		if not ok then
			warn("[Characters] LoadCharacterAsync failed for " .. player.Name .. ": " .. tostring(err))
		end
	end)
end

local function torsoOf(character: Model): BasePart?
	local torso = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
	if torso and torso:IsA("BasePart") then
		return torso
	end
	return nil
end

local function attach(parent: Instance, p: BasePart, to: BasePart, offset: CFrame)
	p.CFrame = to.CFrame * offset
	p.Anchored = false
	p.Massless = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = to
	weld.Part1 = p
	weld.Parent = p
	p.Parent = parent
end

local function newPart(name: string, size: Vector3, color: Color3, material: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	return p
end

function Characters.applyCosmetics(player: Player)
	local character = player.Character
	local profile = ctx.PlayerData.get(player)
	if not character or not profile then
		return
	end
	local head = character:FindFirstChild("Head") :: BasePart?
	local torso = torsoOf(character)
	if not head or not torso then
		return
	end
	local old = character:FindFirstChild("CrewCosmetics")
	if old then
		old:Destroy()
	end
	local folder = Instance.new("Model")
	folder.Name = "CrewCosmetics"
	folder.Parent = character
	local equipped = profile.equipped
	local hat = Cosmetics.ById[equipped.Hat or ""] or Cosmetics.ById.hat_visor_red
	local apron = Cosmetics.ById[equipped.Apron or ""] or Cosmetics.ById.apron_red
	local tag = Cosmetics.ById[equipped.Tag or ""] or Cosmetics.ById.tag_white
	local headTop = head.Size.Y / 2
	-- hat
	local style = hat.style
	if style == "Visor" then
		attach(folder, newPart("VisorBand", Vector3.new(head.Size.X + 0.15, 0.35, head.Size.Z + 0.15), hat.color), head, CFrame.new(0, headTop - 0.05, 0))
		attach(folder, newPart("VisorBill", Vector3.new(1.4, 0.1, 0.9), hat.color), head, CFrame.new(0, headTop - 0.15, -head.Size.Z / 2 - 0.4))
	elseif style == "Crown" then
		attach(folder, newPart("Crown", Vector3.new(head.Size.X + 0.1, 0.6, head.Size.Z + 0.1), hat.color), head, CFrame.new(0, headTop + 0.15, 0))
		for i = -1, 1 do
			local point = Instance.new("WedgePart")
			point.Name = "CrownPoint"
			point.Size = Vector3.new(0.4, 0.5, 0.2)
			point.Color = hat.color
			attach(folder, point, head, CFrame.new(i * 0.6, headTop + 0.7, -head.Size.Z / 2))
		end
	elseif style == "Cap" then
		attach(folder, newPart("Cap", Vector3.new(head.Size.X + 0.15, 0.5, head.Size.Z + 0.15), hat.color), head, CFrame.new(0, headTop + 0.05, 0))
		attach(folder, newPart("Brim", Vector3.new(1.3, 0.12, 1), hat.color), head, CFrame.new(0, headTop - 0.1, -head.Size.Z / 2 - 0.45))
	elseif style == "Bun" then
		local bun = newPart("Bun", Vector3.new(1.9, 1.0, 1.9), hat.color)
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = bun
		attach(folder, bun, head, CFrame.new(0, headTop + 0.3, 0))
	elseif style == "TopHat" then
		local brim = newPart("Brim", Vector3.new(0.12, 1.8, 1.8), hat.color)
		brim.Shape = Enum.PartType.Cylinder
		attach(folder, brim, head, CFrame.new(0, headTop + 0.05, 0) * CFrame.Angles(0, 0, math.rad(90)))
		local top = newPart("Top", Vector3.new(1.2, 1.1, 1.1), hat.color)
		top.Shape = Enum.PartType.Cylinder
		attach(folder, top, head, CFrame.new(0, headTop + 0.65, 0) * CFrame.Angles(0, 0, math.rad(90)))
		local monocle = newPart("Monocle", Vector3.new(0.05, 0.45, 0.45), Color3.fromRGB(244, 180, 0), Enum.Material.Metal)
		monocle.Shape = Enum.PartType.Cylinder
		monocle.Transparency = 0.3
		attach(folder, monocle, head, CFrame.new(0.3, 0.15, -head.Size.Z / 2 - 0.05) * CFrame.Angles(0, math.rad(90), 0))
	elseif style == "MunchHead" then
		local munch = ModelFactory.buildMunch({ scale = 0.38 })
		local headPart = munch:FindFirstChild("Head") :: Model
		if headPart then
			for _, d in headPart:GetDescendants() do
				if d:IsA("BasePart") then
					local offset = (munch.PrimaryPart :: BasePart).CFrame:ToObjectSpace(d.CFrame)
					local clone = d:Clone()
					for _, w in clone:GetChildren() do
						if w:IsA("WeldConstraint") then
							w:Destroy()
						end
					end
					attach(folder, clone, head, CFrame.new(0, -2.3, 0) * offset)
				end
			end
		end
		munch:Destroy()
	end
	-- apron
	local apronPart = newPart("Apron", Vector3.new(torso.Size.X * 0.8, torso.Size.Y * 0.95, 0.12), apron.color, if apron.neon then Enum.Material.Neon else Enum.Material.Fabric)
	attach(folder, apronPart, torso, CFrame.new(0, -0.1, -torso.Size.Z / 2 - 0.07))
	-- name tag
	local tagPart = newPart("NameTag", Vector3.new(0.9, 0.32, 0.05), tag.color)
	attach(folder, tagPart, torso, CFrame.new(-0.45, 0.45, -torso.Size.Z / 2 - 0.15))
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 80
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = player.DisplayName
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.fromRGB(30, 30, 30)
	label.Parent = gui
	gui.Parent = tagPart
end

local function onCharacter(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	local root = character:WaitForChild("HumanoidRootPart", 10) :: BasePart?
	if not humanoid or not root then
		return
	end
	state[player] = { crouch = false, stickyUntil = 0, baseHip = humanoid.HipHeight }
	player:SetAttribute("Crouching", false)
	player:SetAttribute("Hidden", nil)
	player:SetAttribute("Ghost", false)
	Characters.setGroup(character, "Players")
	character.DescendantAdded:Connect(function(d)
		if d:IsA("BasePart") and not player:GetAttribute("Ghost") then
			d.CollisionGroup = "Players"
		end
	end)
	Characters.applyCosmetics(player)
	local cf = if ctx.Shift then ctx.Shift.spawnCFrameFor(player) else nil
	if cf then
		task.defer(function()
			if character.Parent then
				character:PivotTo(cf)
			end
		end)
	end
	humanoid.Died:Connect(function()
		if ctx.Stations then
			ctx.Stations.dropHeld(player)
		end
		task.delay(3, function()
			if player.Parent and player.Character == character then
				loadCharacter(player)
			end
		end)
	end)
end

function Characters.respawn(player: Player)
	if player.Parent then
		loadCharacter(player)
	end
end

function Characters.moveTo(player: Player, cf: CFrame)
	local character = player.Character
	if character and character.PrimaryPart then
		character:PivotTo(cf)
	end
end

function Characters.setCrouch(player: Player, on: boolean)
	local s = state[player]
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not s or not humanoid then
		return
	end
	if s.crouch == on then
		return
	end
	s.crouch = on
	player:SetAttribute("Crouching", on)
	player:SetAttribute("CrouchSince", if on then os.clock() else nil)
	if humanoid.RigType == Enum.HumanoidRigType.R15 then
		humanoid.HipHeight = if on then math.max(0.1, s.baseHip - Config.Crouch.HipHeightDrop) else s.baseHip
	else
		-- R6 can't lower its hips; at least drop the camera so crouching feels like crouching
		humanoid.CameraOffset = if on then Vector3.new(0, -1.5, 0) else Vector3.zero
	end
end

function Characters.isCrouching(player: Player): boolean
	local s = state[player]
	return s ~= nil and s.crouch
end

function Characters.addPuddle(position: Vector3)
	local puddle = Instance.new("Part")
	puddle.Name = "StickyPuddle"
	puddle.Shape = Enum.PartType.Cylinder
	puddle.Size = Vector3.new(0.06, 7, 7)
	puddle.CFrame = CFrame.new(position.X, Layout.Floor + 0.04, position.Z) * CFrame.Angles(0, 0, math.rad(90))
	puddle.Color = Color3.fromRGB(110, 60, 30)
	puddle.Material = Enum.Material.Glass
	puddle.Transparency = 0.3
	puddle.Anchored = true
	puddle.CanCollide = false
	puddle.CanQuery = false
	puddle.Parent = ctx.map.Dynamic
	table.insert(Characters.puddles, { part = puddle, expires = os.clock() + 20 })
end

function Characters.clearPuddles()
	for _, p in Characters.puddles do
		p.part:Destroy()
	end
	table.clear(Characters.puddles)
end

local function speedFor(player: Player): number?
	local s = state[player]
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not s or not root then
		return nil
	end
	if player:GetAttribute("Ghost") then
		return Config.Ghost.WalkSpeed
	end
	if player:GetAttribute("Hidden") then
		return 0
	end
	local speed = 16
	if s.crouch then
		speed = Config.Crouch.WalkSpeed
	end
	local now = os.clock()
	for _, puddle in Characters.puddles do
		local offset = root.Position - puddle.part.Position
		if math.abs(offset.X) < 3.5 and math.abs(offset.Z) < 3.5 then
			s.stickyUntil = now + Config.Cook.StickySeconds
		end
	end
	if now < s.stickyUntil then
		speed = math.min(speed, Config.Cook.StickySpeed)
	end
	if ctx.WeirdEvents and ctx.WeirdEvents.isActive("EarRain") and root.Position.Z > Layout.KitchenZ.min then
		speed *= 0.6
	end
	return speed
end

function Characters.init()
	setupCollisionGroups()
	local function setupPlayer(player: Player)
		player.CharacterAdded:Connect(function(character)
			onCharacter(player, character)
		end)
		if player.Character then
			task.spawn(onCharacter, player, player.Character)
		end
		task.spawn(function()
			ctx.PlayerData.waitFor(player)
			if player.Parent and not player.Character then
				loadCharacter(player)
			end
		end)
	end
	Players.PlayerAdded:Connect(setupPlayer)
	for _, player in Players:GetPlayers() do
		setupPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		state[player] = nil
	end)
	ctx.onAction("Crouch", function(player, data)
		Characters.setCrouch(player, data.on == true)
	end)
	task.spawn(function()
		while true do
			task.wait(0.2)
			local now = os.clock()
			for i = #Characters.puddles, 1, -1 do
				local p = Characters.puddles[i]
				if now > p.expires then
					p.part:Destroy()
					table.remove(Characters.puddles, i)
				end
			end
			for _, player in Players:GetPlayers() do
				local speed = speedFor(player)
				local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
				if speed and humanoid and humanoid.WalkSpeed ~= speed then
					humanoid.WalkSpeed = speed
				end
			end
		end
	end)
end

return Characters
