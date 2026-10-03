-- Hiding spots (design doc §5.3–5.4): capacity per spot, a peephole view, anti-camping (spots get
-- cold / smelly / loud and pop you out), and Night 4+ "hold your breath" when Mr. Munch knocks.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Layout = require(Shared.Builders.Layout)
local ctx = require(script.Parent.Context)

local Hiding = {}

local occupants: { [string]: { Player } } = {}
local hidden: { [Player]: { spot: string, since: number, warned: boolean, saved: { [Instance]: number } } } = {}
local cooldowns: { [Player]: { spot: string, untilTime: number } } = {}
local breath: { [Player]: boolean? } = {}
local prompts: { [string]: ProximityPrompt } = {}

function Hiding.spotOf(player: Player): string?
	local h = hidden[player]
	return h and h.spot
end

function Hiding.occupants(spotId: string): { Player }
	return occupants[spotId] or {}
end

local function refreshPrompt(spotId: string)
	local prompt = prompts[spotId]
	local spot = Layout.HidingSpots[spotId]
	if prompt then
		local n = #(occupants[spotId] or {})
		prompt.ActionText = ("Hide (%d/%d)"):format(n, spot.capacity)
		prompt.Enabled = n < spot.capacity
	end
end

local function setCharacterHidden(player: Player, on: boolean, saved: { [Instance]: number })
	local character = player.Character
	if not character then
		return
	end
	for _, d in character:GetDescendants() do
		if d:IsA("BasePart") or d:IsA("Decal") then
			if on then
				saved[d] = d.Transparency
				d.Transparency = 1
			elseif saved[d] ~= nil then
				d.Transparency = saved[d]
			end
		elseif d:IsA("SurfaceGui") or d:IsA("BillboardGui") then
			d.Enabled = not on
		end
	end
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root then
		root.Anchored = on
	end
end

function Hiding.hide(player: Player, spotId: string): boolean
	local spot = Layout.HidingSpots[spotId]
	if not spot or hidden[player] then
		return false
	end
	if not ctx.Shift.canAct(player) then
		return false
	end
	local list = occupants[spotId] or {}
	occupants[spotId] = list
	if #list >= spot.capacity then
		ctx.notify(player, spot.label .. " is full!")
		return false
	end
	local cd = cooldowns[player]
	if cd and cd.spot == spotId and os.clock() < cd.untilTime then
		ctx.notify(player, "You just got out of there. Find another spot!")
		return false
	end
	ctx.Stations.dropHeld(player)
	ctx.Characters.setCrouch(player, false)
	local record = { spot = spotId, since = os.clock(), warned = false, saved = {} }
	hidden[player] = record
	table.insert(list, player)
	setCharacterHidden(player, true, record.saved)
	ctx.Characters.moveTo(player, CFrame.new(spot.inside))
	player:SetAttribute("Hidden", spotId)
	local member = ctx.Shift.member(player)
	if member then
		member.hid = true
	end
	refreshPrompt(spotId)
	ctx.notify(player, spot.message or "Hidden.")
	ctx.Bus:fire("Hid", player, spotId)
	return true
end

function Hiding.leave(player: Player, reason: string?)
	local record = hidden[player]
	if not record then
		return
	end
	hidden[player] = nil
	local spot = Layout.HidingSpots[record.spot]
	local list = occupants[record.spot]
	if list then
		local index = table.find(list, player)
		if index then
			table.remove(list, index)
		end
	end
	setCharacterHidden(player, false, record.saved)
	local outward = Vector3.new(spot.peekTo.X - spot.prompt.X, 0, spot.peekTo.Z - spot.prompt.Z)
	local exit = Vector3.new(spot.prompt.X, Layout.Floor + 3, spot.prompt.Z) + (if outward.Magnitude > 0 then outward.Unit * 3 else Vector3.zero)
	ctx.Characters.moveTo(player, CFrame.lookAt(exit, exit + (if outward.Magnitude > 0 then outward.Unit else Vector3.new(0, 0, 1))))
	player:SetAttribute("Hidden", nil)
	cooldowns[player] = { spot = record.spot, untilTime = os.clock() + Config.Hide.RehideCooldown }
	refreshPrompt(record.spot)
	ctx.closePanel(player, "HoldBreath")
	if reason == "camp" then
		ctx.notify(player, ("You got popped out of the %s!"):format(spot.label), "bad")
		ctx.caption(("[%s tumbles out of the %s]"):format(player.DisplayName, spot.label), spot.prompt, 2)
	end
	ctx.Bus:fire("Unhid", player, record.spot)
end

function Hiding.forget(player: Player)
	local record = hidden[player]
	if record then
		local list = occupants[record.spot]
		if list then
			local index = table.find(list, player)
			if index then
				table.remove(list, index)
			end
		end
		refreshPrompt(record.spot)
	end
	hidden[player] = nil
	cooldowns[player] = nil
	breath[player] = nil
end

-- Mr. Munch knocks: everyone inside plays the hold-your-breath minigame. Returns who failed.
function Hiding.knock(spotId: string): { Player }
	local inside = table.clone(occupants[spotId] or {})
	if #inside == 0 then
		return {}
	end
	local spot = Layout.HidingSpots[spotId]
	ctx.sound("Knock", spot.prompt)
	ctx.caption("[KNOCK. KNOCK.]", spot.prompt, 2)
	for _, p in inside do
		breath[p] = nil
		ctx.openPanel(p, "HoldBreath", { seconds = Config.Hide.HoldBreathWindow, hits = Config.Hide.HoldBreathHits })
	end
	local deadline = os.clock() + Config.Hide.HoldBreathWindow + 1
	while os.clock() < deadline do
		local waiting = false
		for _, p in inside do
			if breath[p] == nil and hidden[p] then
				waiting = true
			end
		end
		if not waiting then
			break
		end
		task.wait(0.1)
	end
	local failed = {}
	for _, p in inside do
		if hidden[p] and hidden[p].spot == spotId then
			if breath[p] == true then
				ctx.Badges.award(p, "held_breath")
				ctx.notify(p, "...He moved on.", "good")
			else
				table.insert(failed, p)
			end
		end
		ctx.closePanel(p, "HoldBreath")
		breath[p] = nil
	end
	return failed
end

function Hiding.stop()
	for player in table.clone(hidden) do
		Hiding.leave(player, "stop")
	end
end

function Hiding.reset()
	Hiding.stop()
	table.clear(cooldowns)
	for spotId in Layout.HidingSpots do
		occupants[spotId] = {}
		refreshPrompt(spotId)
	end
end

function Hiding.init()
	local folder = ctx.map.HidingSpots
	for spotId, spot in Layout.HidingSpots do
		occupants[spotId] = {}
		local part = folder:FindFirstChild(spotId)
		if part then
			local prompt = Instance.new("ProximityPrompt")
			prompt.Name = "HidePrompt"
			prompt.ActionText = "Hide"
			prompt.ObjectText = spot.label
			prompt.KeyboardKeyCode = Enum.KeyCode.F
			prompt.Exclusivity = Enum.ProximityPromptExclusivity.AlwaysShow
			prompt.RequiresLineOfSight = false
			prompt.MaxActivationDistance = 8
			prompt.Parent = part
			prompt:SetAttribute("HidingSpot", spotId)
			prompts[spotId] = prompt
			prompt.Triggered:Connect(function(player)
				Hiding.hide(player, spotId)
			end)
			refreshPrompt(spotId)
		end
	end
	ctx.onAction("LeaveHide", function(player)
		Hiding.leave(player, "manual")
	end)
	ctx.onAction("HoldBreath", function(player, data)
		if hidden[player] then
			breath[player] = data.success == true
		end
	end)
	Players.PlayerRemoving:Connect(Hiding.forget)
	task.spawn(function()
		while true do
			task.wait(0.25)
			local now = os.clock()
			for player, record in table.clone(hidden) do
				local elapsed = now - record.since
				local spot = Layout.HidingSpots[record.spot]
				if not record.warned and elapsed >= Config.Hide.CampWarnSeconds then
					record.warned = true
					ctx.effect("CampWarn", { spot = record.spot, message = spot.campMessage or "It's getting cramped in here...", left = Config.Hide.CampMaxSeconds - elapsed }, { player })
				end
				if elapsed >= Config.Hide.CampMaxSeconds then
					Hiding.leave(player, "camp")
				end
			end
		end
	end)
end

return Hiding
