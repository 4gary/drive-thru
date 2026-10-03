-- Getting booped -> Shift Ghost (design doc §7.4). A booped crew member floats around as a cute
-- sheet ghost with a visible respawn timer, can Ghost Point and Boo!, and can't touch anything.
-- Respawn can never be bought or skipped. If the whole crew is ghosts at once: "Ghost Town".

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Cosmetics = require(Shared.Data.Cosmetics)
local Layout = require(Shared.Builders.Layout)
local ModelFactory = require(Shared.Builders.ModelFactory)
local Util = require(Shared.Util)
local ctx = require(script.Parent.Context)

local Ghosts = {}

local pointCooldown: { [Player]: number } = {}
local booCooldown: { [Player]: number } = {}

function Ghosts.respawnSeconds(night: number): number
	local design = Config.GhostRespawnDesign[night] or 90
	return math.max(Config.MinGhostRespawn, design * Config.TimeScale)
end

local function makeGhost(player: Player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not character or not humanoid or not root or not player:GetAttribute("Ghost") then
		return
	end
	humanoid.PlatformStand = false
	for _, d in character:GetDescendants() do
		if d:IsA("BasePart") then
			d.Transparency = 1
			d.CollisionGroup = "Ghosts"
		elseif d:IsA("Decal") then
			d.Transparency = 1
		elseif d:IsA("SurfaceGui") then
			d.Enabled = false
		end
	end
	local profile = ctx.PlayerData.get(player)
	local equipped = profile and profile.equipped or {}
	local skin = Cosmetics.ById[equipped.Ghost or ""] or Cosmetics.ById.ghost_white
	local hat = Cosmetics.ById[equipped.Hat or ""] or Cosmetics.ById.hat_visor_red
	local sheet = ModelFactory.buildGhostSheet(skin.color, hat.color, player.DisplayName)
	local sheetRoot = sheet.PrimaryPart :: BasePart
	for _, d in sheet:GetDescendants() do
		if d:IsA("BasePart") then
			d.CollisionGroup = "Ghosts"
			d.Massless = true
		end
	end
	sheet:PivotTo(root.CFrame * CFrame.new(0, 0.3, 0))
	sheetRoot.Anchored = false
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = sheetRoot
	weld.Parent = sheetRoot
	if equipped.Trail == "trail_sparkle" then
		local sparkle = Instance.new("ParticleEmitter")
		sparkle.Rate = 15
		sparkle.Lifetime = NumberRange.new(0.6, 1)
		sparkle.Speed = NumberRange.new(0.5, 1.5)
		sparkle.Size = NumberSequence.new(0.25)
		sparkle.LightEmission = 1
		sparkle.Color = ColorSequence.new(Color3.fromRGB(255, 240, 150))
		sparkle.Parent = sheetRoot
	end
	sheet.Parent = character
	humanoid.HipHeight += 1.2
	humanoid.JumpPower = 0
	local gui = Instance.new("BillboardGui")
	gui.Name = "GhostTimer"
	gui.Size = UDim2.fromOffset(150, 40)
	gui.StudsOffset = Vector3.new(0, 4.2, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 120
	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = Color3.fromRGB(40, 40, 70)
	label.BackgroundTransparency = 0.2
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.Text = "BACK IN --"
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = label
	label.Parent = gui
	gui.Parent = root
	character:PivotTo(root.CFrame + Vector3.new(0, 1.5, 0))
end

function Ghosts.boop(player: Player, source: string)
	local s = ctx.Shift.session
	local member = ctx.Shift.member(player)
	if not s or not member or member.ghost or s.phase ~= "Running" then
		return
	end
	if player:GetAttribute("Hidden") then
		ctx.Hiding.leave(player, "boop")
	end
	ctx.Stations.dropHeld(player)
	ctx.Stations.forgetViewer(player)
	ctx.Orders.releaseTaker(player)
	ctx.Characters.setCrouch(player, false)
	local seconds = Ghosts.respawnSeconds(s.night)
	member.ghost = true
	member.boops += 1
	member.respawnAt = os.clock() + 1.2 + seconds
	player:SetAttribute("Ghost", true)
	player:SetAttribute("RespawnAt", workspace:GetServerTimeNow() + 1.2 + seconds)
	ctx.PlayerData.addStat(player, "boops", 1)
	if source == "Munch" then
		ctx.Badges.award(player, "booped")
	elseif source == "HighBeams" then
		ctx.Badges.award(player, "deer")
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local pos = if root then root.Position else Layout.RespawnPoint
	ctx.effect("Booped", { source = source, seconds = seconds }, { player })
	ctx.effect("CrewBooped", { name = player.DisplayName, userId = player.UserId, source = source, pos = pos })
	ctx.Shift.moment(("%s got booped by %s at %s."):format(player.DisplayName, if source == "Munch" then "Mr. Munch" else "the High Beams", Util.formatClock(s.minutes)), 60)
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.PlatformStand = true
	end
	task.delay(1.2, makeGhost, player)
	ctx.Bus:fire("Booped", player, source)
	-- Ghost Town only applies to a real crew; solo, Gizmo keeps the lights on while you're a ghost.
	if #ctx.Shift.activeMembers() > 1 and #ctx.Shift.livingMembers() == 0 then
		task.delay(1.5, function()
			if ctx.Shift.session == s and #ctx.Shift.activeMembers() > 1 and #ctx.Shift.livingMembers() == 0 then
				ctx.Shift.fail("GhostTown")
			end
		end)
	end
end

function Ghosts.respawn(member)
	local player = member.player
	member.ghost = false
	member.respawnAt = nil
	member.respawning = true
	player:SetAttribute("Ghost", false)
	player:SetAttribute("RespawnAt", nil)
	ctx.Characters.respawn(player)
	ctx.sound("KaChunk", Layout.Stations.TimeClock)
	ctx.caption(("[ka-chunk — %s clocked back in]"):format(player.DisplayName), Layout.Stations.TimeClock, 3)
	ctx.Bus:fire("Respawned", player)
end

-- Bring every ghost back (end of night). With skipRespawn the caller reloads characters itself.
function Ghosts.stop(_session: any?, skipRespawn: boolean?)
	for _, member in ctx.Shift.activeMembers() do
		if member.ghost then
			if skipRespawn then
				member.ghost = false
				member.respawnAt = nil
				member.player:SetAttribute("Ghost", false)
				member.player:SetAttribute("RespawnAt", nil)
			else
				Ghosts.respawn(member)
			end
		end
	end
end

function Ghosts.reset()
	table.clear(pointCooldown)
	table.clear(booCooldown)
end

local function isGhost(player: Player): boolean
	local member = ctx.Shift.member(player)
	return member ~= nil and member.ghost
end

function Ghosts.init()
	ctx.onAction("GhostPoint", function(player, data)
		if not isGhost(player) then
			return
		end
		local now = os.clock()
		if (pointCooldown[player] or 0) > now then
			return
		end
		local pos = data.position
		if typeof(pos) ~= "Vector3" then
			return
		end
		if pos.X < Layout.PlayPlace.minX - 5 or pos.X > Layout.Building.maxX + 30 or pos.Z < Layout.Building.minZ - 5 or pos.Z > Layout.LaneZ + 15 then
			return
		end
		pointCooldown[player] = now + Config.Ghost.PointCooldown
		for _, p in ctx.Shift.crewPlayers() do
			ctx.Remotes.Ping:FireClient(p, { position = pos, name = player.DisplayName, ghost = true, duration = Config.Ghost.PointDuration })
		end
		ctx.Badges.award(player, "ghost_point")
	end)
	ctx.onAction("GhostBoo", function(player)
		if not isGhost(player) then
			return
		end
		local now = os.clock()
		if (booCooldown[player] or 0) > now then
			return
		end
		booCooldown[player] = now + Config.Ghost.BooCooldown
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not root then
			return
		end
		ctx.effect("Boo", { pos = root.Position, name = player.DisplayName })
		ctx.Badges.award(player, "ghost_boo")
		if ctx.Gizmo.spook(root.Position) then
			ctx.Badges.award(player, "spook_gizmo")
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		pointCooldown[player] = nil
		booCooldown[player] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(0.25)
			local s = ctx.Shift.session
			if s and s.phase == "Running" then
				local now = os.clock()
				for _, member in ctx.Shift.activeMembers() do
					if member.ghost and member.respawnAt then
						local character = member.player.Character
						local root = character and character:FindFirstChild("HumanoidRootPart")
						local gui = root and root:FindFirstChild("GhostTimer")
						local label = gui and gui:FindFirstChild("Label") :: TextLabel?
						if label then
							label.Text = "BACK IN " .. Util.formatSeconds(member.respawnAt - now)
						end
						if now >= member.respawnAt then
							Ghosts.respawn(member)
						end
					end
				end
			end
		end
	end)
end

return Ghosts
