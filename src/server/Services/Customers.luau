-- The drive-thru lane: spawns cars (normal people, regulars, Late Customers), moves them through
-- the queue slots (speaker -> hold -> window), tracks patience and makes them leave.
-- Design doc §5.1 ("Customer = Base person + Car + Order + Tells") and §7.2.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Layout = require(Shared.Builders.Layout)
local ModelFactory = require(Shared.Builders.ModelFactory)
local Anomalies = require(Shared.Data.Anomalies)
local Regulars = require(Shared.Data.Regulars)
local People = require(Shared.Data.People)
local OrderLogic = require(Shared.OrderLogic)
local ctx = require(script.Parent.Context)

local Customers = {}

Customers.lane = {} :: { any } -- front (window) to back
Customers.cars = {} :: { [number]: any }
local scripted: { string } = {}
local usedLate: { [string]: boolean } = {}
local nextId = 0
local carsFolder: Folder? = nil

local function folder(): Folder
	if not carsFolder or not carsFolder.Parent then
		local f = Instance.new("Folder")
		f.Name = "Cars"
		f.Parent = ctx.map.Dynamic
		carsFolder = f
	end
	return carsFolder :: Folder
end

local function slotCFrame(x: number): CFrame
	return CFrame.new(x, 0, Layout.LaneZ)
end

---------------------------------------------------------------------------
-- Speech bubbles over cars
---------------------------------------------------------------------------

function Customers.say(car, text: string, duration: number?)
	if not car.model or not car.model.Parent then
		return
	end
	local root = car.root :: BasePart
	local old = root:FindFirstChild("Bubble")
	if old then
		old:Destroy()
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "Bubble"
	gui.Size = UDim2.fromOffset(260, 80)
	gui.StudsOffset = Vector3.new(0, 9, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 90
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = Color3.fromRGB(255, 252, 240)
	label.TextColor3 = Color3.fromRGB(30, 30, 30)
	label.TextWrapped = true
	label.TextScaled = true
	label.Font = Enum.Font.FredokaOne
	label.Text = text
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = label
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 8)
	pad.PaddingRight = UDim.new(0, 8)
	pad.PaddingTop = UDim.new(0, 4)
	pad.PaddingBottom = UDim.new(0, 4)
	pad.Parent = label
	label.Parent = gui
	gui.Parent = root
	task.delay(duration or 4, function()
		if gui.Parent then
			gui:Destroy()
		end
	end)
end

---------------------------------------------------------------------------
-- Building a customer record
---------------------------------------------------------------------------

local function merge(base: { [string]: any }, over: { [string]: any }?)
	local out = table.clone(base)
	if over then
		for k, v in over do
			out[k] = v
		end
	end
	return out
end

local function pickDifficulty(s): string
	local weights = s.data.difficulty or { Normal = 1 }
	local roll = s.rng:NextNumber()
	local acc = 0
	for _, name in { "Normal", "Picky", "Custom" } do
		acc += weights[name] or 0
		if roll <= acc then
			return name
		end
	end
	return "Normal"
end

local function baseRecord(kind: string)
	nextId += 1
	return {
		id = nextId,
		kind = kind, -- "Normal" | "Late" | "Regular" | "Special"
		isLate = kind == "Late",
		ordered = false,
		state = "Arriving",
		slot = nil,
		targetSlot = nil,
		tween = nil,
		ticket = nil,
		decided = false,
		patienceBonus = 0,
		modifiers = {},
		captions = {},
	}
end

local function normalRecord(s)
	local car = baseRecord("Normal")
	local person = People.random(s.rng)
	car.person = person
	car.carSpec = person.car
	car.name = person.name
	car.order = OrderLogic.generate(s.rng, pickDifficulty(s))
	local greeting = People.pick(People.Greetings, s.rng)
	car.speaker = { string.format(greeting, OrderLogic.describe(car.order)) }
	if s.rng:NextNumber() < 0.4 then
		table.insert(car.speaker, People.pick(People.Thanks, s.rng))
	end
	car.receipt = { name = string.upper(person.name) }
	return car
end

local function lateRecord(s, def)
	local car = baseRecord("Late")
	car.def = def
	car.anomalyId = def.id
	local person = merge(People.random(s.rng), def.person)
	car.person = person
	car.carSpec = def.car or person.car
	car.name = def.name
	car.modifiers = table.clone(def.modifiers or {})
	car.captions = table.clone(def.captions or {})
	car.mirrorTell = def.mirrorTell
	car.order = table.clone(def.order or {})
	car.speaker = table.clone(def.speaker or {})
	car.receipt = table.clone(def.receipt or {})
	if s.night >= 4 and not car.receipt.total then
		car.receipt.total = "$13.13"
	end
	if s.flags.revealed and def.photo then
		-- Night 5, after the reveal: the photo-employees just want "the usual".
		car.wantsUsual = true
		car.order = table.clone(def.photo.usual)
		car.speaker = { "...", "Please. Just make me the usual." }
		if def.id == "EarlOfEars" then
			car.speaker = { "...It's me. Marv. Night grill, '91.", "Please. Just make me the usual." }
		end
		car.patienceBonus = 45
	end
	if s.night >= 5 and def.id == "MirrorMandy" then
		car.mirrorTell = "Crying"
	end
	return car
end

local function regularRecord(s, def)
	local car = baseRecord(if def.special then "Special" else "Regular")
	car.def = def
	car.regularId = def.id
	car.isDecoy = def.decoy == true
	local person = merge(People.random(s.rng), def.person)
	car.person = person
	car.carSpec = def.car or person.car
	car.name = def.name
	car.modifiers = table.clone(def.modifiers or {})
	car.captions = table.clone(def.captions or {})
	car.patienceBonus = def.patienceBonus or 0
	car.receipt = table.clone(def.receipt or { name = string.upper(person.name or "GUEST") })
	car.skipSpeaker = def.onFoot == true
	local speaker = (def.speakerByNight and def.speakerByNight[s.night]) or def.speaker or {}
	car.speaker = table.clone(speaker)
	if def.id == "Hendersons" then
		local kids = Regulars.hendersonKids(s.night)
		car.kids = kids
		car.order = {}
		for _ = 1, kids do
			table.insert(car.order, { item = "fries" })
		end
		table.insert(car.order, { item = "drink" })
		local words = { "one", "two", "three", "four" }
		local counting = table.concat(words, ", ", 1, math.min(kids, 4))
		car.speaker = {
			"Kids' meals for... (counting) " .. counting .. (if kids > 4 then "... uh... " .. kids .. "?!" else "."),
			("Kids' meals are fries, right? So %d fries. And a drink for me."):format(kids),
		}
		if s.night >= 5 then
			table.insert(car.modifiers, "IdenticalKids:" .. kids)
			car.speaker = { "Kids' meals for... nine.", "(nine identical voices) NINE FRIES. AND A DRINK. THANK. YOU." }
		else
			table.insert(car.modifiers, "Kids:" .. kids)
		end
	elseif def.id == "KarenBot" then
		car.order = OrderLogic.generate(s.rng, "Custom")
		car.speaker = { def.speakerPrefix .. string.upper(OrderLogic.describe(car.order)) .. "." }
	else
		car.order = table.clone(def.order or {})
	end
	return car
end

local function pickLateId(s): string?
	local pool = s.data.latePool or {}
	local fresh = {}
	for _, id in pool do
		if not usedLate[id] then
			table.insert(fresh, id)
		end
	end
	local list = if #fresh > 0 then fresh else pool
	if #list == 0 then
		return nil
	end
	return list[s.rng:NextInteger(1, #list)]
end

local function recordFor(s, id: string)
	if id == "RandomLate" then
		local lateId = pickLateId(s)
		if not lateId then
			return normalRecord(s)
		end
		id = lateId
	end
	if id == "Normal" then
		return normalRecord(s)
	end
	local anomaly = Anomalies.ById[id]
	if anomaly then
		usedLate[id] = true
		return lateRecord(s, anomaly)
	end
	local regular = Regulars.ById[id]
	if regular then
		return regularRecord(s, regular)
	end
	warn("[Customers] unknown customer id " .. id)
	return normalRecord(s)
end

local function randomRecord(s)
	local roll = s.rng:NextNumber()
	if roll < (s.data.lateChance or 0.15) then
		return recordFor(s, "RandomLate")
	end
	if s.night >= 2 and roll < (s.data.lateChance or 0.15) + 0.06 then
		return recordFor(s, "KarenBot")
	end
	if s.night >= 4 and roll < (s.data.lateChance or 0.15) + 0.1 then
		return recordFor(s, "CastGuy")
	end
	return normalRecord(s)
end

---------------------------------------------------------------------------
-- Lane movement
---------------------------------------------------------------------------

-- opts.z: drive along a different line (pulling out of the lane); opts.linear: constant speed
local function moveCar(car, x: number, speedMultiplier: number, onArrive: (() -> ())?, opts: { z: number?, linear: boolean? }?)
	if car.tween then
		car.tween:Cancel()
		car.tween = nil
	end
	local root = car.root :: BasePart
	local z = if opts and opts.z then opts.z else Layout.LaneZ
	local target = CFrame.new(x, 0, z)
	local distance = (root.Position - target.Position).Magnitude
	if distance < 0.05 then
		if onArrive then
			task.defer(onArrive)
		end
		return
	end
	local duration = distance / (Config.CarSpeed * speedMultiplier)
	local style = if opts and opts.linear then Enum.EasingStyle.Linear else Enum.EasingStyle.Quad
	local tween = TweenService:Create(root, TweenInfo.new(duration, style, Enum.EasingDirection.Out), {
		CFrame = target, -- cars always face down the lane (+X)
	})
	car.tween = tween
	tween.Completed:Connect(function(state)
		if state == Enum.PlaybackState.Completed and car.tween == tween then
			car.tween = nil
			if onArrive then
				onArrive()
			end
		end
	end)
	tween:Play()
end

local function arrive(car, slotIndex: number)
	if car.state == "Leaving" then
		return
	end
	car.slot = slotIndex
	local now = os.clock()
	if slotIndex == Layout.SpeakerSlot and not car.ordered and not car.skipSpeaker then
		car.state = "AtSpeaker"
		car.speakerDeadline = now + Config.Patience.Speaker + car.patienceBonus
		ctx.sound("Ding", Layout.SpeakerPost)
		ctx.caption("[drive-thru bell: ding-dong]", Layout.SpeakerPost, 2)
		ctx.Bus:fire("CarAtSpeaker", car)
	elseif slotIndex == Layout.WindowSlot then
		car.state = "AtWindow"
		car.windowDeadline = now + Config.Patience.Window + car.patienceBonus
		ctx.Bus:fire("CarAtWindow", car)
	end
end

function Customers.updateQueue()
	local prev = 0
	for _, car in Customers.lane do
		local minSlot = prev + 1
		local desired
		if car.ordered or car.skipSpeaker then
			desired = minSlot
		else
			desired = math.max(minSlot, Layout.SpeakerSlot)
		end
		desired = math.min(desired, #Layout.Slots)
		if car.targetSlot ~= desired then
			car.targetSlot = desired
			if car.state == "AtSpeaker" and desired ~= Layout.SpeakerSlot then
				car.state = "Ordered"
			end
			moveCar(car, Layout.Slots[desired].x, 1, function()
				arrive(car, desired)
			end)
		end
		prev = desired
	end
end

---------------------------------------------------------------------------
-- Spawning
---------------------------------------------------------------------------

function Customers.canSpawn(): boolean
	if #Customers.lane >= Config.MaxCarsInLane then
		return false
	end
	local back = Customers.lane[#Customers.lane]
	if back and (back.targetSlot or #Layout.Slots) >= #Layout.Slots then
		return false
	end
	return true
end

function Customers.hasScripted(): boolean
	return #scripted > 0
end

function Customers.enqueueScripted(id: string)
	table.insert(scripted, id)
end

local function spawnRecord(car)
	local s = ctx.Shift.session
	local model = ModelFactory.buildCustomer({ person = car.person, car = car.carSpec, modifiers = car.modifiers })
	model.Name = "Car" .. car.id
	model:SetAttribute("CarId", car.id)
	model:SetAttribute("MirrorTell", car.mirrorTell or "None")
	model:SetAttribute("CustomerName", car.name or "")
	car.model = model
	car.root = model.PrimaryPart
	model:PivotTo(slotCFrame(Layout.LaneStartX))
	model.Parent = folder()
	Customers.cars[car.id] = car
	table.insert(Customers.lane, car)
	car.spawnedAt = os.clock()
	car.night = if s then s.night else 1
	Customers.updateQueue()
	return car
end

function Customers.spawnNext(scriptedOnly: boolean?): boolean
	local s = ctx.Shift.session
	if not s or s.phase ~= "Running" or not Customers.canSpawn() then
		return false
	end
	local car
	if #scripted > 0 then
		car = recordFor(s, table.remove(scripted, 1) :: string)
	elseif scriptedOnly then
		return false
	else
		car = randomRecord(s)
	end
	spawnRecord(car)
	return true
end

function Customers.spawnById(id: string)
	local s = ctx.Shift.session
	if not s then
		return nil
	end
	return spawnRecord(recordFor(s, id))
end

---------------------------------------------------------------------------
-- Leaving
---------------------------------------------------------------------------

function Customers.leave(car, speedMultiplier: number?)
	if car.state == "Leaving" then
		return
	end
	car.state = "Leaving"
	local index = table.find(Customers.lane, car)
	if index then
		table.remove(Customers.lane, index)
	end
	if ctx.Orders then
		ctx.Orders.closeTicketFor(car)
	end
	ctx.Bus:fire("CarLeaving", car)
	Customers.updateQueue()
	if not car.root or not car.root.Parent then
		Customers.cars[car.id] = nil
		return
	end
	local function gone()
		if car.model then
			car.model:Destroy()
		end
		Customers.cars[car.id] = nil
	end
	local speed = speedMultiplier or 1.6
	if index == 1 or not index then
		moveCar(car, Layout.LaneEndX, speed, gone, { linear = true })
	else
		-- not at the front: pull out of the lane first instead of driving through the queue
		local exitZ = Layout.LaneZ + 11
		moveCar(car, car.root.Position.X, speed, function()
			moveCar(car, Layout.LaneEndX, speed, gone, { z = exitZ, linear = true })
		end, { z = exitZ })
	end
end

function Customers.leaveAngry(car, where: string)
	local s = ctx.Shift.session
	if not s or car.state == "Leaving" then
		return
	end
	if car.isLate then
		s.stats.lateMissed += 1
		ctx.Shift.addWeird(Config.Weird.LateLeft)
		Customers.say(car, "...")
		ctx.caption("[a car drives off. Its headlights stay behind for a second.]", car.root.Position, 3)
	elseif car.kind ~= "Special" then
		s.stats.leftAngry += 1
		ctx.Shift.addStars(Config.Stars.LeftAngry, "Customer left")
		Customers.say(car, if where == "speaker" then "Hello?? Is anyone there?!" else "Forget it! I'm leaving!")
		ctx.notifyCrew(("A customer left angry (%s)."):format(if where == "speaker" then "nobody took the order" else "food took too long"), "bad")
	end
	Customers.leave(car)
end

---------------------------------------------------------------------------
-- Queries
---------------------------------------------------------------------------

function Customers.get(id: number)
	return Customers.cars[id]
end

function Customers.speakerCar()
	for _, car in Customers.lane do
		if car.state == "AtSpeaker" then
			return car
		end
	end
	return nil
end

function Customers.windowCar()
	local front = Customers.lane[1]
	if front and front.state == "AtWindow" then
		return front
	end
	return nil
end

function Customers.snapshot()
	local out = {}
	for _, car in Customers.lane do
		table.insert(out, {
			id = car.id,
			slot = car.slot,
			state = car.state,
			ticket = if car.ticket then car.ticket.number else nil,
		})
	end
	return out
end

-- Cars ordered front-to-back (used for bagging priority).
function Customers.position(car): number
	return table.find(Customers.lane, car) or 999
end

---------------------------------------------------------------------------
-- Lifecycle
---------------------------------------------------------------------------

function Customers.reset()
	Customers.cleanup()
	table.clear(scripted)
	table.clear(usedLate)
end

function Customers.stop()
	table.clear(scripted)
	for _, car in table.clone(Customers.lane) do
		Customers.leave(car, 2.2)
	end
end

function Customers.cleanup()
	for _, car in Customers.cars do
		if car.tween then
			car.tween:Cancel()
		end
		if car.model then
			car.model:Destroy()
		end
	end
	table.clear(Customers.cars)
	table.clear(Customers.lane)
	if carsFolder then
		carsFolder:ClearAllChildren()
	end
end

function Customers.init()
	task.spawn(function()
		while true do
			task.wait(0.5)
			local s = ctx.Shift.session
			if s and s.phase == "Running" then
				local now = os.clock()
				for _, car in table.clone(Customers.lane) do
					if car.state == "AtSpeaker" and not ctx.Orders.activeTaker(car) and car.speakerDeadline and now > car.speakerDeadline then
						Customers.leaveAngry(car, "speaker")
					elseif car.state == "AtWindow" and not car.decided and car.windowDeadline and now > car.windowDeadline then
						if ctx.Window.inspecting(car) and now < car.windowDeadline + 20 then
							continue -- someone is looking right at them; give a little grace
						end
						Customers.leaveAngry(car, "window")
					end
				end
			end
		end
	end)
end

return Customers
