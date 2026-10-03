-- Kitchen stations (design doc §6.4) with "carry & snap" cooking:
--   Grill:     place patty -> FLIP! at the sizzle -> take it when DONE (or it burns)
--   Assembly:  build the burger bottom-to-top on the plate (snap stacking), carry it away
--   Fryers:    drop basket -> pull at the DING -> fry bin -> scoop a carton
--   Drinks:    HOLD to pour, release in the green zone (overflow = sticky floor)
-- Players carry one item at a time to the bag counter. Gizmo uses the same API.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Layout = require(Shared.Builders.Layout)
local ModelFactory = require(Shared.Builders.ModelFactory)
local Menu = require(Shared.Data.Menu)
local OrderLogic = require(Shared.OrderLogic)
local ctx = require(script.Parent.Context)

local Stations = {}

local Cook = Config.Cook
local held: { [Player]: any } = {}
local grill = {} :: { any }
local plate = { stack = {} :: { string }, finished = false, model = nil :: Model? }
local fryers = {} :: { any }
local fryPortions = 0
local pours = {} :: { [string]: any }
local assemblyViewers: { [Player]: boolean } = {}
local dynamic: Folder? = nil
local prompts: { [string]: ProximityPrompt } = {}

local function folder(): Folder
	if not dynamic or not dynamic.Parent then
		local f = Instance.new("Folder")
		f.Name = "Stations"
		f.Parent = ctx.map.Dynamic
		dynamic = f
	end
	return dynamic :: Folder
end

local function makePrompt(parent: Instance, name: string, action: string, object: string, props: { [string]: any }?): ProximityPrompt
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = name
	prompt.ActionText = action
	prompt.ObjectText = object
	prompt.MaxActivationDistance = 8
	prompt.RequiresLineOfSight = false
	if props then
		for k, v in props do
			(prompt :: any)[k] = v
		end
	end
	prompt.Parent = parent
	prompts[name] = prompt
	return prompt
end

local function billboard(part: BasePart, text: string, color: Color3): BillboardGui
	local gui = Instance.new("BillboardGui")
	gui.Name = "Status"
	gui.Size = UDim2.fromOffset(110, 34)
	gui.StudsOffset = Vector3.new(0, 1.6, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 45
	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = color
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.Text = text
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = label
	label.Parent = gui
	gui.Parent = part
	return gui
end

local function setStatus(part: BasePart?, text: string?, color: Color3?)
	if not part then
		return
	end
	local gui = part:FindFirstChild("Status") :: BillboardGui?
	if not text then
		if gui then
			gui:Destroy()
		end
		return
	end
	if not gui then
		gui = billboard(part, text, color or Color3.fromRGB(40, 40, 45))
	end
	local label = (gui :: BillboardGui):FindFirstChild("Label") :: TextLabel
	label.Text = text
	label.BackgroundColor3 = color or Color3.fromRGB(40, 40, 45)
end

local function smoke(part: BasePart, on: boolean)
	local existing = part:FindFirstChild("Smoke")
	if on and not existing then
		local s = Instance.new("Smoke")
		s.Color = Color3.fromRGB(60, 60, 60)
		s.Size = 2
		s.RiseVelocity = 4
		s.Opacity = 0.4
		s.Parent = part
	elseif not on and existing then
		existing:Destroy()
	end
end

---------------------------------------------------------------------------
-- Held items
---------------------------------------------------------------------------

function Stations.held(player: Player)
	return held[player]
end

local function attachModel(player: Player, item)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	local model = ModelFactory.buildItem(item.kind, { stack = item.stack, toppings = Menu.Toppings })
	model.Name = "HeldItem"
	local itemRoot = model.PrimaryPart :: BasePart
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Massless = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
		end
	end
	model:PivotTo(root.CFrame * CFrame.new(0, -0.1, -1.7))
	itemRoot.Anchored = false
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = itemRoot
	weld.Parent = itemRoot
	model.Parent = character
	item.model = model
end

function Stations.give(player: Player, item): boolean
	if held[player] then
		return false
	end
	held[player] = item
	attachModel(player, item)
	player:SetAttribute("Holding", item.label or item.kind)
	return true
end

function Stations.takeHeld(player: Player)
	local item = held[player]
	if not item then
		return nil
	end
	held[player] = nil
	if item.model then
		item.model:Destroy()
		item.model = nil
	end
	player:SetAttribute("Holding", nil)
	return item
end

function Stations.dropHeld(player: Player)
	local item = Stations.takeHeld(player)
	if item and player.Parent then
		ctx.notify(player, ("You dropped the %s."):format(item.label or item.kind), "bad")
	end
end

-- Weird events can make specific held things vanish (Gravity Fries).
function Stations.dropHeldOfKind(kind: string): number
	local n = 0
	for player, item in held do
		if item.kind == kind then
			Stations.takeHeld(player)
			n += 1
		end
	end
	return n
end

local function handsFree(player: Player): boolean
	if held[player] then
		ctx.notify(player, ("Your hands are full (%s). Bag it or trash it."):format(held[player].label or "item"))
		return false
	end
	return true
end

---------------------------------------------------------------------------
-- Grill
---------------------------------------------------------------------------

local PATTY_COLORS = {
	SideA = Color3.fromRGB(225, 120, 120),
	Flip = Color3.fromRGB(200, 105, 95),
	SideB = Color3.fromRGB(140, 80, 50),
	Done = Color3.fromRGB(105, 60, 34),
	Burnt = Color3.fromRGB(30, 25, 22),
}

local function setPatty(spot, state: string)
	spot.state = state
	spot.t0 = os.clock()
	if state == "Empty" then
		if spot.part then
			spot.part:Destroy()
			spot.part = nil
		end
		return
	end
	if not spot.part then
		local p = Instance.new("Part")
		p.Name = "GrillPatty"
		p.Shape = Enum.PartType.Cylinder
		p.Size = Vector3.new(0.4, 1.8, 1.8)
		p.CFrame = CFrame.new(spot.position) * CFrame.Angles(0, 0, math.rad(90))
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.Parent = folder()
		spot.part = p
	end
	spot.part.Color = PATTY_COLORS[state] or PATTY_COLORS.Done
	smoke(spot.part, state == "Burnt")
	if state == "Flip" then
		setStatus(spot.part, "FLIP!", Color3.fromRGB(230, 120, 30))
	elseif state == "Done" then
		setStatus(spot.part, "DONE!", Color3.fromRGB(70, 160, 80))
	elseif state == "Burnt" then
		setStatus(spot.part, "BURNT", Color3.fromRGB(60, 60, 60))
	else
		setStatus(spot.part, nil)
	end
end

function Stations.grillPlace(by: any): boolean
	for _, spot in grill do
		if spot.state == "Empty" then
			setPatty(spot, "SideA")
			spot.bonus = if typeof(by) == "Instance" and by:GetAttribute("Role") == "Grill" then 1.5 else 0
			ctx.sound("Sizzle", spot.position)
			ctx.Bus:fire("PattyPlaced", by)
			return true
		end
	end
	return false
end

function Stations.grillFlipAny(by: any): boolean
	for _, spot in grill do
		if spot.state == "Flip" then
			setPatty(spot, "SideB")
			ctx.sound("Sizzle", spot.position)
			ctx.Bus:fire("PattyFlipped", by)
			return true
		end
	end
	return false
end

function Stations.grillTakeAny(by: any)
	for _, spot in grill do
		if spot.state == "Done" then
			setPatty(spot, "Empty")
			ctx.Bus:fire("PattyTaken", by)
			return { kind = "Patty", label = "Cooked Patty" }
		end
	end
	return nil
end

function Stations.grillScrapeAny(): boolean
	for _, spot in grill do
		if spot.state == "Burnt" then
			setPatty(spot, "Empty")
			return true
		end
	end
	return false
end

function Stations.grillSummary()
	local summary = { Empty = 0, SideA = 0, Flip = 0, SideB = 0, Done = 0, Burnt = 0 }
	for _, spot in grill do
		summary[spot.state] += 1
	end
	return summary
end

local function grillAction(): string?
	local sum = Stations.grillSummary()
	if sum.Flip > 0 then
		return "Flip"
	elseif sum.Done > 0 then
		return "Take"
	elseif sum.Burnt > 0 then
		return "Scrape"
	elseif sum.Empty > 0 then
		return "Place"
	end
	return nil
end

local function onGrill(player: Player)
	if not ctx.Shift.canAct(player) then
		return
	end
	local action = grillAction()
	if action == "Flip" then
		Stations.grillFlipAny(player)
	elseif action == "Take" then
		if handsFree(player) then
			local item = Stations.grillTakeAny(player)
			if item then
				Stations.give(player, item)
			end
		end
	elseif action == "Scrape" then
		Stations.grillScrapeAny()
		ctx.notify(player, "Scraped a burnt patty into the trash.")
	elseif action == "Place" then
		Stations.grillPlace(player)
	end
end

local function updateGrill(now: number)
	local s = ctx.Shift.session
	for _, spot in grill do
		local elapsed = now - spot.t0
		if spot.state == "SideA" and elapsed >= Cook.PattySideA then
			setPatty(spot, "Flip")
			ctx.caption("[sizzle — FLIP!]", spot.position, 1.5)
		elseif spot.state == "SideB" and elapsed >= Cook.PattySideB then
			setPatty(spot, "Done")
		elseif
			(spot.state == "Flip" and elapsed >= Cook.FlipWindow + (spot.bonus or 0))
			or (spot.state == "Done" and elapsed >= Cook.DoneWindow)
		then
			setPatty(spot, "Burnt")
			if s then
				s.stats.burnt += 1
			end
			ctx.Bus:fire("PattyBurnt")
		end
	end
	local prompt = prompts.Grill
	if prompt then
		local action = grillAction()
		local texts = { Flip = "Flip Patty", Take = "Take Patty", Scrape = "Scrape Burnt", Place = "Place Patty" }
		prompt.ActionText = if action then texts[action] else "Grill Full"
		prompt.Enabled = action ~= nil
	end
end

---------------------------------------------------------------------------
-- Assembly plate
---------------------------------------------------------------------------

local function rebuildPlate()
	if plate.model then
		plate.model:Destroy()
		plate.model = nil
	end
	if #plate.stack > 0 then
		local model = ModelFactory.buildStack(plate.stack, Menu.Toppings)
		model.Name = "PlateStack"
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") then
				d.Anchored = true
			end
		end
		model:PivotTo(CFrame.new(Layout.Stations.AssemblyPlate + Vector3.new(0, 0.1, 0)))
		model.Parent = folder()
		plate.model = model
	end
	local prompt = prompts.Assembly
	if prompt then
		prompt.ActionText = if plate.finished then "Take Burger" else "Build Burger"
	end
end

function Stations.plateData(player: Player?)
	local line = if #plate.stack > 0 then OrderLogic.identifyBurger(plate.stack) else nil
	return {
		stack = plate.stack,
		finished = plate.finished,
		label = if line then OrderLogic.lineLabel(line) elseif plate.finished then "Mystery Burger" else nil,
		holdingPatty = player ~= nil and held[player] ~= nil and held[player].kind == "Patty",
		grabby = ctx.WeirdEvents.isActive("GrabbyHands"),
	}
end

local function pushAssembly()
	for viewer in assemblyViewers do
		if viewer.Parent then
			ctx.Remotes.OpenPanel:FireClient(viewer, "Assembly", Stations.plateData(viewer))
		else
			assemblyViewers[viewer] = nil
		end
	end
end

function Stations.plateStack(): { string }
	return plate.stack
end

function Stations.plateFinished(): boolean
	return plate.finished
end

-- Adds a layer. Returns ok, message.
function Stations.plateAdd(op: string, by: any): (boolean, string?)
	if plate.finished then
		return false, "This burger is finished — take it first."
	end
	if op == "Bun" then
		if #plate.stack == 0 then
			table.insert(plate.stack, "BunBottom")
		else
			table.insert(plate.stack, "BunTop")
			plate.finished = true
		end
	elseif op == "Patty" then
		if #plate.stack == 0 then
			return false, "Start with a bottom bun."
		end
		table.insert(plate.stack, "Patty")
	elseif op == "Cheese" or op == "Lettuce" or op == "Pickles" or op == "Sauce" then
		if #plate.stack == 0 then
			return false, "Start with a bottom bun."
		end
		if ctx.WeirdEvents.isActive("GrabbyHands") then
			return false, "Tiny hands are holding the topping bins! Shoo them!"
		end
		table.insert(plate.stack, op)
	else
		return false, nil
	end
	rebuildPlate()
	pushAssembly()
	if plate.finished then
		ctx.Bus:fire("BurgerBuilt", plate.stack, by)
	end
	return true, nil
end

function Stations.plateTake()
	if not plate.finished then
		return nil
	end
	local item = OrderLogic.makeBurgerItem(plate.stack)
	plate.stack = {}
	plate.finished = false
	rebuildPlate()
	pushAssembly()
	return item
end

function Stations.plateClear()
	plate.stack = {}
	plate.finished = false
	rebuildPlate()
	pushAssembly()
end

local function onAssemblyAction(player: Player, data)
	if not ctx.Shift.canAct(player) then
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root or (root.Position - Layout.Stations.AssemblyPlate).Magnitude > 14 then
		ctx.closePanel(player, "Assembly")
		assemblyViewers[player] = nil
		return
	end
	local op = tostring(data.op)
	if op == "Patty" then
		local item = held[player]
		if not item or item.kind ~= "Patty" then
			ctx.notify(player, "Grab a cooked patty from the grill first.")
			return
		end
		if #plate.stack == 0 then
			ctx.notify(player, "Start with a bottom bun.")
			return
		end
		Stations.takeHeld(player)
		Stations.plateAdd("Patty", player)
	elseif op == "Take" then
		if not plate.finished then
			ctx.notify(player, "Finish it with a top bun first.")
			return
		end
		if handsFree(player) then
			local item = Stations.plateTake()
			if item then
				Stations.give(player, item)
				ctx.closePanel(player, "Assembly")
				assemblyViewers[player] = nil
			end
		end
	elseif op == "Clear" then
		Stations.plateClear()
	elseif op == "Close" then
		assemblyViewers[player] = nil
	else
		local ok, message = Stations.plateAdd(op, player)
		if not ok and message then
			ctx.notify(player, message)
		end
	end
	pushAssembly()
end

---------------------------------------------------------------------------
-- Fryers + fry bin
---------------------------------------------------------------------------

local function fryerPart(i: number): BasePart
	return ctx.map.Kitchen:FindFirstChild("FryerBasket" .. i) :: BasePart
end

local function setFryer(i: number, state: string)
	local f = fryers[i]
	f.state = state
	f.t0 = os.clock()
	local basket = fryerPart(i)
	local fire = basket:FindFirstChild("FryFire")
	if state == "Fire" and not fire then
		local flames = Instance.new("Fire")
		flames.Name = "FryFire"
		flames.Size = 6
		flames.Heat = 9
		flames.Parent = basket
	elseif state ~= "Fire" and fire then
		fire:Destroy()
	end
	smoke(basket, state == "Burnt")
	basket.CFrame = CFrame.new(Layout.Stations.Fryers[i] + Vector3.new(0, if state == "Cooking" then -0.4 else 0.4, 0))
	if state == "Cooking" then
		setStatus(basket, "Frying...", Color3.fromRGB(200, 150, 40))
	elseif state == "Done" then
		setStatus(basket, "DING! Pull!", Color3.fromRGB(70, 160, 80))
	elseif state == "Burnt" then
		setStatus(basket, "BURNT", Color3.fromRGB(60, 60, 60))
	elseif state == "Fire" then
		setStatus(basket, "FIRE!", Color3.fromRGB(220, 60, 30))
	else
		setStatus(basket, nil)
	end
end

function Stations.fryerState(i: number): string
	return fryers[i].state
end

function Stations.fryerDrop(i: number, by: any): boolean
	if fryers[i].state ~= "Empty" then
		return false
	end
	setFryer(i, "Cooking")
	ctx.sound("Sizzle", Layout.Stations.Fryers[i])
	ctx.Bus:fire("FriesDropped", by)
	return true
end

function Stations.fryerPull(i: number, by: any): boolean
	local state = fryers[i].state
	if state == "Done" then
		fryPortions += Cook.FryPortions
		setFryer(i, "Empty")
		ctx.Bus:fire("FriesPulled", by)
		return true
	elseif state == "Burnt" then
		setFryer(i, "Empty")
		return true
	end
	return false
end

function Stations.fryerExtinguish(i: number, by: any): boolean
	if fryers[i].state ~= "Fire" then
		return false
	end
	setFryer(i, "Empty")
	ctx.caption("[fwoosh — fire's out]", Layout.Stations.Fryers[i], 2)
	if typeof(by) == "Instance" and by:IsA("Player") then
		ctx.Badges.award(by, "this_is_fine")
	end
	ctx.Bus:fire("FireOut", by)
	return true
end

function Stations.fryPortions(): number
	return fryPortions
end

function Stations.removePortions(n: number): number
	local removed = math.min(fryPortions, n)
	fryPortions -= removed
	return removed
end

function Stations.scoopFries(): any
	if fryPortions <= 0 then
		return nil
	end
	fryPortions -= 1
	return OrderLogic.makeSimpleItem("Fries")
end

local function onFryer(i: number, player: Player)
	if not ctx.Shift.canAct(player) then
		return
	end
	local state = fryers[i].state
	if state == "Empty" then
		Stations.fryerDrop(i, player)
	elseif state == "Done" then
		Stations.fryerPull(i, player)
		ctx.notify(player, ("+%d fries in the fry bin."):format(Cook.FryPortions), "good")
	elseif state == "Burnt" then
		Stations.fryerPull(i, player)
		ctx.notify(player, "Dumped burnt fries.", "bad")
	elseif state == "Fire" then
		Stations.fryerExtinguish(i, player)
	end
end

local function updateFryers(now: number)
	local s = ctx.Shift.session
	for i, f in fryers do
		local elapsed = now - f.t0
		if f.state == "Cooking" and elapsed >= Cook.FryTime then
			setFryer(i, "Done")
			ctx.sound("Ding", Layout.Stations.Fryers[i])
			ctx.caption("[fryer: DING!]", Layout.Stations.Fryers[i], 2)
		elseif f.state == "Done" and elapsed >= Cook.FryDoneWindow then
			setFryer(i, "Burnt")
			if s then
				s.stats.friesBurnt += 1
			end
			ctx.Bus:fire("FriesBurnt")
		elseif f.state == "Burnt" and elapsed >= Cook.FryFireAfter then
			setFryer(i, "Fire")
			if s then
				s.stats.fires += 1
			end
			ctx.caption("[FRY FIRE!]", Layout.Stations.Fryers[i], 3)
			ctx.Shift.addStars(-0.2, "Fry fire!")
			ctx.Bus:fire("FryFire")
		end
		local prompt = prompts["Fryer" .. i]
		if prompt then
			local texts = { Empty = "Drop Basket", Cooking = "Frying...", Done = "Pull Fries", Burnt = "Dump Burnt Fries", Fire = "Put Out Fire" }
			prompt.ActionText = texts[f.state]
			prompt.Enabled = f.state ~= "Cooking"
			prompt.HoldDuration = if f.state == "Fire" then 1.5 else 0
		end
	end
	local binPrompt = prompts.FryBin
	if binPrompt then
		binPrompt.ActionText = ("Scoop Fries (%d)"):format(fryPortions)
		binPrompt.Enabled = fryPortions > 0
	end
end

---------------------------------------------------------------------------
-- Drinks & shakes: hold to pour
---------------------------------------------------------------------------

local function fillSeconds(kind: string): number
	return if kind == "Shake" then Cook.ShakeFillSeconds else Cook.DrinkFillSeconds
end

function Stations.instantPour(kind: string)
	return OrderLogic.makeSimpleItem(kind)
end

local function setupPour(kind: string, part: BasePart)
	local station = { fill = 0, holder = nil :: Player?, start = 0, overflowed = false }
	pours[kind] = station
	local seconds = fillSeconds(kind)
	local prompt = makePrompt(part, kind, "Hold to Pour", if kind == "Shake" then "Shake Machine" else "Soda Fountain", {
		HoldDuration = seconds * 1.3,
	})
	prompt.PromptButtonHoldBegan:Connect(function(player)
		if not ctx.Shift.canAct(player) or held[player] then
			if held[player] then
				ctx.notify(player, "Your hands are full.")
			end
			return
		end
		station.holder = player
		station.start = os.clock()
		station.overflowed = false
		ctx.effect("Pour", { kind = kind, fill = station.fill, seconds = seconds, perfect = Cook.PerfectFillMin }, { player })
	end)
	prompt.PromptButtonHoldEnded:Connect(function(player)
		if station.holder ~= player or station.overflowed then
			return
		end
		station.holder = nil
		ctx.effect("PourEnd", { kind = kind }, { player })
		local fill = station.fill + (os.clock() - station.start) / seconds
		if fill >= Cook.PerfectFillMin then
			station.fill = 0
			Stations.give(player, OrderLogic.makeSimpleItem(kind))
			ctx.notify(player, ("Perfect pour! (%d%%)"):format(math.floor(math.min(fill, 1) * 100)), "good")
			ctx.Bus:fire("DrinkPoured", player, kind, false)
		else
			station.fill = fill
			ctx.notify(player, ("Keep pouring... %d%% full"):format(math.floor(fill * 100)))
		end
	end)
	prompt.Triggered:Connect(function(player)
		if station.holder ~= player then
			return
		end
		station.overflowed = true
		station.holder = nil
		station.fill = 0
		ctx.effect("PourEnd", { kind = kind }, { player })
		Stations.give(player, OrderLogic.makeSimpleItem(kind))
		ctx.Characters.addPuddle(part.Position + Vector3.new(0, 0, -5.5))
		ctx.notify(player, "OVERFLOW! The floor is sticky now.", "bad")
		ctx.caption("[splorsh — sticky floor]", part.Position, 2)
		ctx.Badges.award(player, "sticky")
		ctx.Bus:fire("DrinkPoured", player, kind, true)
	end)
end

---------------------------------------------------------------------------
-- Lifecycle
---------------------------------------------------------------------------

function Stations.reset()
	Stations.cleanup()
end

function Stations.cleanup()
	for player in held do
		Stations.takeHeld(player)
	end
	for _, spot in grill do
		setPatty(spot, "Empty")
	end
	plate.stack = {}
	plate.finished = false
	rebuildPlate()
	for i in fryers do
		setFryer(i, "Empty")
	end
	fryPortions = 0
	for _, station in pours do
		station.fill = 0
		station.holder = nil
	end
	table.clear(assemblyViewers)
	if dynamic then
		dynamic:ClearAllChildren()
	end
	ctx.Characters.clearPuddles()
end

function Stations.init()
	local kitchen = ctx.map.Kitchen
	for i, pos in Layout.Stations.GrillSpots do
		grill[i] = { position = pos, state = "Empty", t0 = 0, part = nil, bonus = 0 }
	end
	local grillPrompt = makePrompt(kitchen.Grill, "Grill", "Place Patty", "Grill", { MaxActivationDistance = 9 })
	grillPrompt.Triggered:Connect(onGrill)

	local assembly = makePrompt(kitchen.AssemblyPlate, "Assembly", "Build Burger", "Assembly Board")
	assembly.Triggered:Connect(function(player)
		if not ctx.Shift.canAct(player) then
			return
		end
		if plate.finished and not held[player] then
			local item = Stations.plateTake()
			if item then
				Stations.give(player, item)
				return
			end
		end
		assemblyViewers[player] = true
		ctx.openPanel(player, "Assembly", Stations.plateData(player))
	end)
	ctx.onAction("Assembly", onAssemblyAction)

	for i in Layout.Stations.Fryers do
		fryers[i] = { state = "Empty", t0 = 0 }
		local prompt = makePrompt(kitchen:FindFirstChild("Fryer" .. i), "Fryer" .. i, "Drop Basket", "Fryer " .. i)
		prompt.Triggered:Connect(function(player)
			onFryer(i, player)
		end)
	end
	local bin = makePrompt(kitchen.FryBin, "FryBin", "Scoop Fries", "Fry Bin")
	bin.Triggered:Connect(function(player)
		if not ctx.Shift.canAct(player) or not handsFree(player) then
			return
		end
		local item = Stations.scoopFries()
		if item then
			Stations.give(player, item)
		end
	end)

	setupPour("Drink", kitchen.SodaFountain)
	setupPour("Shake", kitchen.ShakeMachine)

	for i in Layout.Stations.Trash do
		local trash = makePrompt(kitchen:FindFirstChild("Trash" .. i), "Trash" .. i, "Trash Item", "Trash", { MaxActivationDistance = 7 })
		trash.Triggered:Connect(function(player)
			local item = Stations.takeHeld(player)
			if item then
				ctx.notify(player, ("Trashed the %s."):format(item.label or item.kind))
			end
		end)
	end

	Players.PlayerRemoving:Connect(function(player)
		held[player] = nil
		assemblyViewers[player] = nil
	end)

	task.spawn(function()
		while true do
			task.wait(0.1)
			local now = os.clock()
			if ctx.Shift.isRunning() then
				local ok, err = pcall(function()
					updateGrill(now)
					updateFryers(now)
				end)
				if not ok then
					warn("[Stations] " .. tostring(err))
				end
			end
		end
	end)
end

return Stations
