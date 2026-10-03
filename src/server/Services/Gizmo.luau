-- Gizmo, the Fry-Bot 3000 (design doc §4.1): fills empty stations. Solo it covers the fryer and
-- drinks at ~60%; in co-op it covers the Fry station if nobody has it, and any booped teammate's
-- station at ~30%. Hides badly (behind a napkin), always gets booped, narrates its failures.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Layout = require(Shared.Builders.Layout)
local ModelFactory = require(Shared.Builders.ModelFactory)
local Menu = require(Shared.Data.Menu)
local OrderLogic = require(Shared.OrderLogic)
local ctx = require(script.Parent.Context)

local Gizmo = {}
Gizmo.boops = 0

local model: Model? = nil
local root: BasePart? = nil
local ghostModel: Model? = nil
local state: string = "Off" -- Off | Idle | Working | Hiding | Ghost
local ghostUntil = 0
local carried: Model? = nil
local covering = { fry = nil :: number?, grill = nil :: number?, order = nil :: number? }
local generation = 0

local FAILS = {
	"FRY ERROR. I HAVE MADE A SOUP.",
	"OOPS. I BAGGED MY OWN HAND.",
	"ERROR 404: FRIES NOT FOUND.",
	"I DROPPED IT. IT IS THE FLOOR'S NOW.",
}

local function say(text: string, face: string?)
	if not root then
		return
	end
	local old = root:FindFirstChild("Bubble")
	if old then
		old:Destroy()
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "Bubble"
	gui.Size = UDim2.fromOffset(220, 56)
	gui.StudsOffset = Vector3.new(0, 6, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 70
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = Color3.fromRGB(20, 30, 30)
	label.TextColor3 = Color3.fromRGB(80, 255, 140)
	label.Font = Enum.Font.Arcade
	label.TextScaled = true
	label.TextWrapped = true
	label.Text = text
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = label
	label.Parent = gui
	gui.Parent = root
	task.delay(3.5, function()
		if gui.Parent then
			gui:Destroy()
		end
	end)
	if face and model then
		local screen = model:FindFirstChild("Screen")
		local screenGui = screen and screen:FindFirstChild("ScreenGui")
		local faceLabel = screenGui and screenGui:FindFirstChild("Label") :: TextLabel?
		if faceLabel then
			faceLabel.Text = face
		end
	end
end
Gizmo.say = say

local function setVisible(visible: boolean)
	if not model then
		return
	end
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d.Name ~= "Root" then
			d.Transparency = if visible then 0 else 1
		elseif d:IsA("SurfaceGui") then
			d.Enabled = visible
		end
	end
end

local function moveTo(target: Vector3, gen: number): boolean
	if not root then
		return false
	end
	local from = root.Position
	local goal = Vector3.new(target.X, Layout.Floor, target.Z)
	local distance = (goal - from).Magnitude
	if distance < 0.3 then
		return true
	end
	local facing = goal + (goal - from).Unit
	local tween = TweenService:Create(root, TweenInfo.new(distance / Config.Gizmo.MoveSpeed, Enum.EasingStyle.Linear), {
		CFrame = CFrame.lookAt(goal, Vector3.new(facing.X, Layout.Floor, facing.Z)),
	})
	tween:Play()
	while tween.PlaybackState == Enum.PlaybackState.Playing do
		task.wait(0.05)
		if generation ~= gen or state ~= "Working" then
			tween:Cancel()
			return false
		end
	end
	return true
end

local function faceKitchenFront()
	if root then
		local p = root.Position
		root.CFrame = CFrame.lookAt(p, p + Vector3.new(0, 0, 1))
	end
end

local function work(seconds: number, efficiency: number, gen: number): boolean
	local finish = os.clock() + seconds / math.max(0.1, efficiency)
	while os.clock() < finish do
		task.wait(0.1)
		if generation ~= gen or state ~= "Working" then
			return false
		end
	end
	return true
end

local function carry(kind: string?, data: any?)
	if carried then
		carried:Destroy()
		carried = nil
	end
	if kind and root then
		local item = ModelFactory.buildItem(kind, data)
		item:PivotTo(root.CFrame * CFrame.new(1.4, 2.2, -1.2))
		local itemRoot = item.PrimaryPart :: BasePart
		itemRoot.Anchored = false
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = itemRoot
		weld.Parent = itemRoot
		item.Parent = model
		carried = item
	end
end

local function front(pos: Vector3): Vector3
	return Vector3.new(pos.X, Layout.Floor, 4.6)
end

local function mistake(): boolean
	if math.random() < Config.Gizmo.MistakeChance then
		say(FAILS[math.random(1, #FAILS)], "X_X")
		carry(nil)
		return true
	end
	return false
end

-- Count unmet ticket lines by item kind.
local function needed()
	local counts = { Fries = 0, Drink = 0, Shake = 0, Burger = 0 }
	local burgerLines = {}
	for _, entry in ctx.Orders.neededLines() do
		local kind = OrderLogic.kindOf(entry.line.item)
		counts[kind] = (counts[kind] or 0) + 1
		if kind == "Burger" then
			table.insert(burgerLines, entry)
		end
	end
	return counts, burgerLines
end

local function bagItem(item, gen: number, efficiency: number): boolean
	if not moveTo(front(Layout.Stations.BagCounter), gen) then
		return false
	end
	if not work(0.6, efficiency, gen) then
		return false
	end
	local ticket = ctx.Orders.findTicketFor(item)
	carry(nil)
	if ticket then
		ctx.Orders.addToBag(ticket, item, "Gizmo")
		return true
	end
	say("NOBODY WANTS THIS. I WILL KEEP IT IN MY HEART.", ":|")
	return false
end

---------------------------------------------------------------------------
-- Jobs
---------------------------------------------------------------------------

local function fryJob(eff: number, gen: number): boolean
	local counts = needed()
	for i, pos in Layout.Stations.Fryers do
		local fs = ctx.Stations.fryerState(i)
		if fs == "Fire" then
			if moveTo(front(pos), gen) and work(2, eff, gen) then
				ctx.Stations.fryerExtinguish(i, "Gizmo")
				say("FIRE EXTINGUISHED. I AM A HERO.", ":D")
			end
			return true
		elseif fs == "Done" or fs == "Burnt" then
			if moveTo(front(pos), gen) and work(0.8, eff, gen) then
				if ctx.Stations.fryerState(i) == "Burnt" then
					say("THESE FRIES ARE... CRISPY.", ":S")
				end
				ctx.Stations.fryerPull(i, "Gizmo")
			end
			return true
		end
	end
	if counts.Fries > 0 and ctx.Stations.fryPortions() > 0 then
		if moveTo(front(Layout.Stations.FryBin), gen) and work(0.8, eff, gen) then
			local item = ctx.Stations.scoopFries()
			if item then
				carry("Fries")
				if not mistake() then
					bagItem(item, gen, eff)
				end
			end
		end
		return true
	end
	local cooking = 0
	for i in Layout.Stations.Fryers do
		if ctx.Stations.fryerState(i) == "Cooking" then
			cooking += 1
		end
	end
	if counts.Fries > ctx.Stations.fryPortions() + cooking * Config.Cook.FryPortions then
		for i, pos in Layout.Stations.Fryers do
			if ctx.Stations.fryerState(i) == "Empty" then
				if moveTo(front(pos), gen) and work(0.6, eff, gen) then
					ctx.Stations.fryerDrop(i, "Gizmo")
				end
				return true
			end
		end
	end
	for _, kind in { "Drink", "Shake" } do
		if counts[kind] > 0 then
			local pos = if kind == "Drink" then Layout.Stations.SodaFountain else Layout.Stations.ShakeMachine
			local seconds = if kind == "Shake" then Config.Cook.ShakeFillSeconds else Config.Cook.DrinkFillSeconds
			if moveTo(front(pos), gen) and work(seconds, eff, gen) then
				carry(kind)
				if not mistake() then
					bagItem(ctx.Stations.instantPour(kind), gen, eff)
				end
			end
			return true
		end
	end
	return false
end

local TOPPING_OPS = { BunBottom = "Bun", BunTop = "Bun", Patty = "Patty", Cheese = "Cheese", Lettuce = "Lettuce", Pickles = "Pickles", Sauce = "Sauce" }

local function grillJob(eff: number, gen: number): boolean
	local _, burgerLines = needed()
	local grillState = ctx.Stations.grillSummary()
	if grillState.Flip > 0 then
		if moveTo(front(Layout.Stations.Grill), gen) and work(0.5, eff, gen) then
			ctx.Stations.grillFlipAny("Gizmo")
		end
		return true
	end
	if grillState.Burnt > 0 then
		if moveTo(front(Layout.Stations.Grill), gen) and work(0.8, eff, gen) then
			ctx.Stations.grillScrapeAny()
		end
		return true
	end
	if #burgerLines == 0 then
		return false
	end
	local pattiesNeeded = 0
	for _, entry in burgerLines do
		for _, layer in OrderLogic.buildStack(entry.line.item, entry.line.mods) do
			if layer == "Patty" then
				pattiesNeeded += 1
			end
		end
	end
	local cookingPatties = grillState.SideA + grillState.SideB + grillState.Flip
	if grillState.Done == 0 and cookingPatties < math.min(pattiesNeeded, 2) and grillState.Empty > 0 then
		if moveTo(front(Layout.Stations.Grill), gen) and work(0.5, eff, gen) then
			ctx.Stations.grillPlace("Gizmo")
		end
		return true
	end
	-- assemble the first burger that needs making (only on an empty plate)
	if #ctx.Stations.plateStack() > 0 or grillState.Done == 0 then
		return false
	end
	local entry = burgerLines[1]
	local stack = OrderLogic.buildStack(entry.line.item, entry.line.mods)
	local pattyCount = 0
	for _, layer in stack do
		if layer == "Patty" then
			pattyCount += 1
		end
	end
	if grillState.Done < pattyCount then
		return false
	end
	if not moveTo(front(Layout.Stations.Grill), gen) or not work(0.5, eff, gen) then
		return true
	end
	for _ = 1, pattyCount do
		ctx.Stations.grillTakeAny("Gizmo")
	end
	carry("Patty")
	if not moveTo(front(Layout.Stations.AssemblyPlate), gen) then
		return true
	end
	carry(nil)
	for _, layer in stack do
		if not work(0.45, eff, gen) then
			return true
		end
		ctx.Stations.plateAdd(TOPPING_OPS[layer], "Gizmo")
	end
	local item = ctx.Stations.plateTake()
	if item then
		carry("Burger", { stack = item.stack, toppings = Menu.Toppings })
		if not mistake() then
			bagItem(item, gen, eff)
		end
	end
	return true
end

local function orderJob(eff: number, gen: number): boolean
	local car = ctx.Customers.speakerCar()
	if not car or ctx.Orders.activeTaker(car) then
		return false
	end
	if not moveTo(front(Layout.Stations.OrderConsole), gen) or not work(3, eff, gen) then
		return true
	end
	car = ctx.Customers.speakerCar()
	if not car or ctx.Orders.activeTaker(car) then
		return true
	end
	local lines = table.clone(car.order or {})
	if #lines > 0 and math.random() < Config.Gizmo.MistakeChance * 2 then
		lines[math.random(1, #lines)] = { item = Menu.Order[math.random(1, #Menu.Order)], mods = {} }
		say("ORDER TAKEN. PROBABLY.", ":)")
	else
		say("ORDER TAKEN. BEEP.", ":)")
	end
	ctx.Orders.createTicket(car, lines, false, nil)
	return true
end

local function updateCoverage()
	local members = ctx.Shift.activeMembers()
	covering.fry, covering.grill, covering.order = nil, nil, nil
	if #members <= 1 then
		covering.fry = Config.Gizmo.SoloEfficiency
	else
		local fryHolder = ctx.Shift.roleHolder("Fry")
		if not fryHolder then
			covering.fry = Config.Gizmo.SoloEfficiency
		elseif fryHolder.ghost then
			covering.fry = Config.Gizmo.CoverEfficiency
		end
	end
	local grillHolder = ctx.Shift.roleHolder("Grill")
	if grillHolder and grillHolder.ghost then
		covering.grill = Config.Gizmo.CoverEfficiency
	end
	local orderHolder = ctx.Shift.roleHolder("Order")
	if orderHolder and orderHolder.ghost then
		covering.order = Config.Gizmo.CoverEfficiency
	end
end

local function brain(gen: number)
	while generation == gen do
		task.wait(0.3)
		if not ctx.Shift.isRunning() then
			continue
		end
		local now = os.clock()
		if state == "Ghost" and now >= ghostUntil then
			if ghostModel then
				ghostModel:Destroy()
				ghostModel = nil
			end
			setVisible(true)
			if root then
				root.CFrame = CFrame.new(Layout.GizmoHome)
			end
			state = "Idle"
			say("REBOOTED. I AM FINE. EVERYTHING IS FINE.", ":)")
		end
		if state ~= "Idle" or ctx.Scares.active() then
			continue
		end
		updateCoverage()
		state = "Working"
		local did = false
		local ok, err = pcall(function()
			if covering.order then
				did = orderJob(covering.order, gen)
			end
			if not did and covering.fry then
				did = fryJob(covering.fry, gen)
			end
			if not did and covering.grill then
				did = grillJob(covering.grill, gen)
			end
		end)
		if not ok then
			warn("[Gizmo] " .. tostring(err))
		end
		if Gizmo.state() == "Working" then
			state = "Idle"
			carry(nil)
			if not did and root and (root.Position - Layout.GizmoHome).Magnitude > 2 then
				state = "Working"
				moveTo(Layout.GizmoHome, gen)
				if Gizmo.state() == "Working" then
					state = "Idle"
				end
				faceKitchenFront()
			end
		end
	end
end

---------------------------------------------------------------------------
-- Scares
---------------------------------------------------------------------------

function Gizmo.isHidingNear(pos: Vector3, range: number): boolean
	return state == "Hiding" and root ~= nil and (Vector3.new(root.Position.X, 0, root.Position.Z) - Vector3.new(pos.X, 0, pos.Z)).Magnitude < range
end

function Gizmo.boop(_source: string)
	if state == "Ghost" or state == "Off" or not root then
		return
	end
	state = "Ghost"
	carry(nil)
	Gizmo.boops += 1
	local s = ctx.Shift.session
	ghostUntil = os.clock() + ctx.Ghosts.respawnSeconds(if s then s.night else 3)
	local pos = root.Position
	say("GIZMO.EXE HAS STOPPED WORKING", "X_X")
	setVisible(false)
	ctx.caption("[sad beeping — Gizmo got booped]", pos, 3)
	local ghost = ModelFactory.buildGizmoGhost()
	ghost:PivotTo(CFrame.new(pos))
	ghost.Parent = ctx.map.Dynamic
	ghostModel = ghost
	local ghostRoot = ghost.PrimaryPart :: BasePart
	TweenService:Create(ghostRoot, TweenInfo.new(1.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
		CFrame = CFrame.new(pos + Vector3.new(0, 1.2, 0)),
	}):Play()
end

function Gizmo.spook(pos: Vector3): boolean
	if not root or state == "Ghost" or state == "Off" then
		return false
	end
	if (root.Position - pos).Magnitude > 14 then
		return false
	end
	say("EEP!", ":O")
	if carried then
		carry(nil)
		say("EEP! I DROPPED A FRY. A GHOST DID IT.", ":O")
	end
	local start = root.CFrame
	local up = TweenService:Create(root, TweenInfo.new(0.15), { CFrame = start + Vector3.new(0, 1.5, 0) })
	up:Play()
	up.Completed:Connect(function()
		if root then
			TweenService:Create(root, TweenInfo.new(0.2), { CFrame = start }):Play()
		end
	end)
	return true
end

function Gizmo.state(): string
	return state
end

function Gizmo.snapshot()
	return {
		state = state,
		fry = covering.fry ~= nil,
		grill = covering.grill ~= nil,
		order = covering.order ~= nil,
	}
end

---------------------------------------------------------------------------
-- Lifecycle
---------------------------------------------------------------------------

function Gizmo.cleanup()
	generation += 1
	state = "Off"
	carry(nil)
	if model then
		model:Destroy()
		model = nil
		root = nil
	end
	if ghostModel then
		ghostModel:Destroy()
		ghostModel = nil
	end
end

function Gizmo.reset()
	Gizmo.cleanup()
	Gizmo.boops = 0
	local built = ModelFactory.buildGizmo()
	built:PivotTo(CFrame.lookAt(Layout.GizmoHome, Layout.GizmoHome + Vector3.new(0, 0, 1)))
	built.Parent = ctx.map.Dynamic
	model = built
	root = built.PrimaryPart
	state = "Idle"
	generation += 1
	task.spawn(brain, generation)
end

function Gizmo.stop()
	if state == "Off" then
		return
	end
	carry(nil)
	if ghostModel then
		ghostModel:Destroy()
		ghostModel = nil
	end
	setVisible(true)
	if root then
		root.CFrame = CFrame.lookAt(Layout.GizmoHome, Layout.GizmoHome + Vector3.new(0, 0, 1))
	end
	state = "Idle"
end

function Gizmo.init()
	ctx.Bus:on("ScareWarning", function(kind)
		if state == "Ghost" or state == "Off" then
			return
		end
		state = "Hiding"
		carry(nil)
		if root then
			local spot = Layout.GizmoNapkin
			TweenService:Create(root, TweenInfo.new(1), { CFrame = CFrame.lookAt(spot, spot + Vector3.new(0, 0, 1)) }):Play()
		end
		say(if kind == "LightsOutSafe" then "HIDING. I AM A NAPKIN." else "HIDING BEHIND THIS NAPKIN. I AM INVISIBLE.", ":|")
	end)
	ctx.Bus:on("ScareEnded", function(kind)
		if state == "Hiding" then
			if kind ~= "LightsOutSafe" then
				Gizmo.boop(kind)
			else
				state = "Idle"
				say("THE NAPKIN WORKED.", ":D")
			end
		end
	end)
	ctx.Bus:on("WeirdEvent", function(id)
		if id == "Raccoons" then
			say("RACCOONS. MY NATURAL ENEMY.", ">:(")
		end
	end)
	ctx.Bus:on("CarAtSpeaker", function(car)
		if car.regularId == "KarenBot" then
			say("...SHE'S HERE. ACT NATURAL. ACT NATURAL.", "<3")
		end
	end)
end

return Gizmo
