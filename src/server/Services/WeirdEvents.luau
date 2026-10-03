-- Weird events (design doc §7.6): the silly, disruptive consequence of serving a Late Customer.
-- "Serve a weird customer -> a funny problem." Never scary on their own.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Layout = require(Shared.Builders.Layout)
local ModelFactory = require(Shared.Builders.ModelFactory)
local Data = require(Shared.Data.WeirdEvents)
local OrderLogic = require(Shared.OrderLogic)
local ctx = require(script.Parent.Context)

local WeirdEvents = {}

local active: { [string]: { ends: number, props: { Instance } } } = {}
local propsFolder: Folder? = nil
local menuBoardText: string? = nil

local function props(): Folder
	if not propsFolder or not propsFolder.Parent then
		local f = Instance.new("Folder")
		f.Name = "WeirdProps"
		f.Parent = ctx.map.Dynamic
		propsFolder = f
	end
	return propsFolder :: Folder
end

function WeirdEvents.isActive(id: string): boolean
	local a = active[id]
	return a ~= nil and (a.ends == 0 or os.clock() < a.ends)
end

function WeirdEvents.snapshot()
	local out = {}
	local now = os.clock()
	for id, a in active do
		table.insert(out, { id = id, name = Data.ById[id].name, remaining = if a.ends == 0 then nil else math.max(0, a.ends - now) })
	end
	return out
end

local function kitchenPoint(rng: Random): Vector3
	return Vector3.new(rng:NextNumber(-50, 50), Layout.Floor, rng:NextNumber(-10, 4))
end

local function menuBoardLabel(): TextLabel?
	local board = ctx.map.Lane:FindFirstChild("MenuBoard")
	local gui = board and board:FindFirstChild("Menu")
	return gui and gui:FindFirstChild("Label") :: TextLabel?
end

local function finish(id: string)
	local a = active[id]
	if not a then
		return
	end
	active[id] = nil
	for _, inst in a.props do
		if inst.Parent then
			inst:Destroy()
		end
	end
	if id == "ChannelSurf" then
		local label = menuBoardLabel()
		if label and menuBoardText then
			label.Text = menuBoardText
		end
	end
	ctx.effect("WeirdEventEnd", { id = id })
end
WeirdEvents.finish = finish

---------------------------------------------------------------------------
-- Raccoons
---------------------------------------------------------------------------

local function spawnRaccoon(record, start: Vector3, target: Vector3)
	local raccoon = ModelFactory.buildRaccoon()
	raccoon:PivotTo(CFrame.lookAt(start, target))
	raccoon.Parent = props()
	table.insert(record.props, raccoon)
	local root = raccoon.PrimaryPart :: BasePart
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Shoo!"
	prompt.ObjectText = "Raccoon"
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.F
	prompt.Exclusivity = Enum.ProximityPromptExclusivity.AlwaysShow
	prompt.Parent = root
	local shooed = false
	prompt.Triggered:Connect(function(player)
		if shooed or not ctx.Shift.canAct(player) then
			return
		end
		shooed = true
		prompt:Destroy()
		ctx.caption("[angry raccoon chittering]", root.Position, 2)
		local exit = Vector3.new(root.Position.X, Layout.Floor, -20)
		local tween = TweenService:Create(root, TweenInfo.new(1.2), { CFrame = CFrame.lookAt(exit, exit + (exit - root.Position)) })
		tween:Play()
		tween.Completed:Wait()
		raccoon:Destroy()
		local remaining = 0
		for _, p in record.props do
			if p.Parent and p:IsA("Model") then
				remaining += 1
			end
		end
		if remaining == 0 then
			finish("Raccoons")
			ctx.notifyCrew("All raccoons shooed!", "good")
		end
	end)
	TweenService:Create(root, TweenInfo.new(2.5, Enum.EasingStyle.Linear), { CFrame = CFrame.lookAt(target, target + (target - start)) }):Play()
	task.spawn(function()
		task.wait(3)
		while raccoon.Parent and WeirdEvents.isActive("Raccoons") do
			local label, number = ctx.Orders.stealFromBag()
			if label then
				ctx.notifyCrew(("A raccoon stole the %s from #%d!"):format(label, number), "bad")
				ctx.caption("[rustling bag]", root.Position, 2)
			end
			task.wait(6)
		end
	end)
end

function WeirdEvents.raccoonsFlee(car)
	if not car.root then
		return
	end
	local start = car.root.Position
	for i = 1, 3 do
		local raccoon = ModelFactory.buildRaccoon()
		local from = start + Vector3.new(i - 2, 0, -3)
		local to = from + Vector3.new(40 + i * 6, 0, 8)
		raccoon:PivotTo(CFrame.lookAt(from, to))
		raccoon.Parent = props()
		local tween = TweenService:Create(raccoon.PrimaryPart :: BasePart, TweenInfo.new(2.2, Enum.EasingStyle.Linear), { CFrame = CFrame.lookAt(to, to + (to - from)) })
		tween:Play()
		task.delay(2.3, function()
			raccoon:Destroy()
		end)
	end
end

---------------------------------------------------------------------------
-- Handlers
---------------------------------------------------------------------------

local handlers = {}

handlers.EarRain = function(record)
	local rng = Random.new()
	for _ = 1, 40 do
		local ear = ModelFactory.buildEar()
		local landing = kitchenPoint(rng)
		ear.CFrame = CFrame.new(landing.X, 15, landing.Z) * CFrame.Angles(rng:NextNumber(0, 6), rng:NextNumber(0, 6), 0)
		ear.Anchored = true
		ear.Parent = props()
		table.insert(record.props, ear)
		TweenService:Create(ear, TweenInfo.new(rng:NextNumber(0.8, 2.5), Enum.EasingStyle.Bounce), {
			CFrame = CFrame.new(landing.X, Layout.Floor + 0.3, landing.Z) * CFrame.Angles(math.rad(90), rng:NextNumber(0, 6), 0),
		}):Play()
	end
	ctx.caption("[it is raining... ears]", nil, 3)
end

handlers.Raccoons = function(record)
	for i = 1, 3 do
		local start = Vector3.new(36 + i * 2, Layout.Floor, -16)
		local target = Vector3.new(28 + i * 4, Layout.Floor, 4.5)
		spawnRaccoon(record, start, target)
	end
	ctx.caption("[chittering from the hallway]", Vector3.new(40, 3, -16), 3)
end

handlers.GrabbyHands = function(record)
	local kitchen = ctx.map.Kitchen
	for i = 1, 5 do
		local hand = Instance.new("Part")
		hand.Name = "GrabbyHand"
		hand.Size = Vector3.new(0.6, 0.8, 0.5)
		hand.Color = Color3.fromRGB(241, 194, 125)
		hand.CFrame = CFrame.new(-15 + (i - 1) * 1.9, Layout.FrontCounter.top + 0.9, 10)
		hand.Anchored = true
		hand.CanCollide = false
		hand.Parent = props()
		table.insert(record.props, hand)
	end
	local board = kitchen:FindFirstChild("CuttingBoard") :: BasePart
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Shoo the Hands"
	prompt.ObjectText = "Grabby Hands"
	prompt.KeyboardKeyCode = Enum.KeyCode.F
	prompt.Exclusivity = Enum.ProximityPromptExclusivity.AlwaysShow
	prompt.HoldDuration = 1
	prompt.RequiresLineOfSight = false
	prompt.MaxActivationDistance = 9
	prompt.Parent = board
	table.insert(record.props, prompt)
	prompt.Triggered:Connect(function(player)
		if ctx.Shift.canAct(player) then
			finish("GrabbyHands")
			ctx.notifyCrew(player.DisplayName .. " shooed the grabby hands!", "good")
		end
	end)
end

handlers.GravityFries = function(record)
	local lost = ctx.Stations.removePortions(999)
	local dropped = ctx.Stations.dropHeldOfKind("Fries")
	local rng = Random.new()
	for _ = 1, 24 do
		local fry = Instance.new("Part")
		fry.Name = "FloatingFry"
		fry.Size = Vector3.new(0.2, 1.1, 0.2)
		fry.Color = Color3.fromRGB(255, 214, 92)
		fry.Anchored = true
		fry.CanCollide = false
		local start = Layout.Stations.FryBin + Vector3.new(rng:NextNumber(-2, 2), 0.5, rng:NextNumber(-1, 1))
		fry.CFrame = CFrame.new(start)
		fry.Parent = props()
		table.insert(record.props, fry)
		TweenService:Create(fry, TweenInfo.new(rng:NextNumber(2, 4), Enum.EasingStyle.Sine), {
			CFrame = CFrame.new(start.X + rng:NextNumber(-10, 10), 15.6, start.Z + rng:NextNumber(-6, 4)) * CFrame.Angles(0, 0, math.rad(90)),
		}):Play()
	end
	ctx.notifyCrew(("The fries floated to the ceiling! (-%d fries)"):format(lost + dropped), "bad")
end

handlers.Doilies = function()
	local s = ctx.Shift.session
	if s then
		s.flags.doilies = true
	end
	local spots = {
		Vector3.new(-50, 0, 8.5),
		Vector3.new(-38, 0, 8.5),
		Vector3.new(-17, 0, 9.5),
		Vector3.new(-5, 0, 8),
		Vector3.new(15, 0, 9.8),
		Vector3.new(30, 0, 8),
		Vector3.new(42, 0, 8),
		Vector3.new(54, 0, 8.5),
		Vector3.new(-20, 0, -11.5),
		Vector3.new(20, 0, -11.5),
	}
	for _, spot in spots do
		local doily = ModelFactory.buildDoily()
		doily.CFrame = CFrame.new(spot.X, Layout.FrontCounter.top + 0.04, spot.Z) * CFrame.Angles(0, 0, math.rad(90))
		doily.Parent = props()
	end
	-- doilies stay for the rest of the night (cleaned up on reset)
end

handlers.GhostRider = function(record)
	task.spawn(function()
		while WeirdEvents.isActive("GhostRider") and active.GhostRider == record do
			task.wait(7)
			if not WeirdEvents.isActive("GhostRider") or active.GhostRider ~= record or not ctx.Shift.isRunning() then
				break
			end
			local tickets = ctx.Orders.tickets
			if #tickets > 0 then
				local ticket = tickets[math.random(1, #tickets)]
				local kinds = { "Drink", "Shake", "Fries" }
				local item = OrderLogic.makeSimpleItem(kinds[math.random(1, #kinds)])
				table.insert(ticket.bag, item)
				ctx.Orders.refreshBags()
				ctx.notifyCrew(("An invisible helper bagged a %s into #%d. Use Fix Bags!"):format(item.label, ticket.number), "bad")
			end
		end
	end)
end

handlers.ChannelSurf = function()
	local label = menuBoardLabel()
	if label then
		menuBoardText = menuBoardText or label.Text
		label.Text = "▒▓░ CH 3 ░▓▒\n▓░ SATURDAY ░▓\n░▒ CARTOONS ▒░"
	end
end

handlers.MascotMob = function(record)
	for i = 1, 4 do
		local mob = ModelFactory.buildMunch({ scale = 0.55, anchored = true, knockoff = true })
		local pos = Vector3.new(10 + i * 7, 0, Layout.LaneZ + 8)
		mob:PivotTo(CFrame.lookAt(pos, pos - Vector3.new(0, 0, 10)))
		mob.Parent = props()
		table.insert(record.props, mob)
	end
	task.spawn(function()
		local t = 0
		while active.MascotMob == record do
			t += 0.15
			for i, m in record.props do
				if m:IsA("Model") and m.Parent then
					local base = Vector3.new(10 + i * 7, math.abs(math.sin(t * 4 + i)) * 1.5, Layout.LaneZ + 8)
					m:PivotTo(CFrame.new(base) * CFrame.Angles(0, t * 3 + i, 0))
				end
			end
			task.wait(0.15)
		end
	end)
end

---------------------------------------------------------------------------

function WeirdEvents.trigger(id: string, _car: any?)
	local def = Data.ById[id]
	if not def then
		warn("[WeirdEvents] unknown event " .. tostring(id))
		return
	end
	if active[id] then
		finish(id)
	end
	local record = { ends = if def.duration > 0 then os.clock() + def.duration else 0, props = {} }
	active[id] = record
	ctx.effect("WeirdEvent", { id = id, name = def.name, banner = def.banner, description = def.description, duration = def.duration })
	ctx.Bus:fire("WeirdEvent", id)
	local handler = handlers[id]
	if handler then
		local ok, err = pcall(handler, record)
		if not ok then
			warn("[WeirdEvents] " .. id .. ": " .. tostring(err))
		end
	end
end

function WeirdEvents.stop()
	for id in table.clone(active) do
		finish(id)
	end
	if propsFolder then
		propsFolder:ClearAllChildren() -- doilies, fleeing raccoons, floating fries...
	end
end

function WeirdEvents.reset()
	WeirdEvents.stop()
	if propsFolder then
		propsFolder:ClearAllChildren()
	end
	local label = menuBoardLabel()
	if label and menuBoardText then
		label.Text = menuBoardText
	end
end

function WeirdEvents.init()
	task.spawn(function()
		while true do
			task.wait(0.25)
			local now = os.clock()
			for id, a in table.clone(active) do
				if a.ends ~= 0 and now >= a.ends then
					finish(id)
				end
			end
		end
	end)
end

return WeirdEvents
