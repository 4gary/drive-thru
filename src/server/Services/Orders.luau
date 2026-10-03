-- Order & Ticket system (design doc §8.1): the CRT order console, tickets, receipts and bags.
-- Bagging uses a snap assist: an item goes into the bag (nearest the window first) that still
-- needs exactly that item. Hand-out compares the bag against what the customer REALLY said.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Layout = require(Shared.Builders.Layout)
local ModelFactory = require(Shared.Builders.ModelFactory)
local Menu = require(Shared.Data.Menu)
local OrderLogic = require(Shared.OrderLogic)
local Util = require(Shared.Util)
local ctx = require(script.Parent.Context)

local Orders = {}

Orders.tickets = {} :: { any }
local ticketNumber = 100
local bagFolder: Folder? = nil
local consolePrompt: ProximityPrompt? = nil

local function bags(): Folder
	if not bagFolder or not bagFolder.Parent then
		local f = Instance.new("Folder")
		f.Name = "Bags"
		f.Parent = ctx.map.Dynamic
		bagFolder = f
	end
	return bagFolder :: Folder
end

-- Open tickets in bagging priority: the car closest to the window first.
function Orders.sorted(): { any }
	local list = table.clone(Orders.tickets)
	table.sort(list, function(a, b)
		local pa, pb = ctx.Customers.position(a.car), ctx.Customers.position(b.car)
		if pa ~= pb then
			return pa < pb
		end
		return a.number < b.number
	end)
	return list
end

local function lineStatus(ticket)
	local used = {}
	local out = {}
	for _, line in ticket.lines do
		local done = false
		for i, item in ticket.bag do
			if not used[i] and OrderLogic.itemMatchesLine(item, line) then
				used[i] = true
				done = true
				break
			end
		end
		table.insert(out, { label = OrderLogic.lineLabel(line), item = line.item, done = done, stack = if OrderLogic.isBurger(line.item) then OrderLogic.buildStack(line.item, line.mods) else nil })
	end
	local extras = 0
	for i in ticket.bag do
		if not used[i] then
			extras += 1
		end
	end
	return out, extras
end

function Orders.refreshBags()
	local folder = bags()
	folder:ClearAllChildren()
	for i, ticket in Orders.sorted() do
		local spot = Layout.Stations.BagSpots[i]
		if not spot then
			break
		end
		local model = ModelFactory.buildItem("Bag")
		model.Name = "Bag" .. ticket.number
		model:PivotTo(CFrame.new(spot - Vector3.new(0, 0.6, 0)))
		local status, extras = lineStatus(ticket)
		local done = 0
		for _, l in status do
			if l.done then
				done += 1
			end
		end
		local gui = Instance.new("BillboardGui")
		gui.Size = UDim2.fromOffset(90, 44)
		gui.StudsOffset = Vector3.new(0, 2.6, 0)
		gui.MaxDistance = 40
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundColor3 = if done == #status and extras == 0 then Color3.fromRGB(80, 170, 90) else Color3.fromRGB(40, 40, 45)
		label.TextColor3 = Color3.new(1, 1, 1)
		label.TextScaled = true
		label.Font = Enum.Font.GothamBold
		label.Text = ("#%d  %d/%d%s"):format(ticket.number, done, #status, if extras > 0 then ("  +%d?!"):format(extras) else "")
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 8)
		corner.Parent = label
		label.Parent = gui
		gui.Parent = model.PrimaryPart
		model.Parent = folder
	end
end

local function buildReceipt(car, lines, number: number)
	local s = ctx.Shift.session
	local labels = {}
	for _, line in lines do
		table.insert(labels, OrderLogic.lineLabel(line))
	end
	local receipt = car.receipt or {}
	return {
		number = number,
		time = if s then Util.formatClock(s.minutes) else "",
		name = receipt.name or "GUEST",
		lines = labels,
		total = receipt.total or string.format("$%.2f", OrderLogic.price(lines)),
		note = receipt.note,
		warm = car.isLate and s ~= nil and s.night >= 4,
	}
end

function Orders.createTicket(car, lines, flagged: boolean, byPlayer: Player?)
	ticketNumber += 1
	local ticket = {
		id = ticketNumber,
		number = ticketNumber,
		car = car,
		carId = car.id,
		lines = lines,
		flagged = flagged,
		createdAt = os.clock(),
		bag = {},
		closed = false,
	}
	ticket.receipt = buildReceipt(car, lines, ticket.number)
	car.ticket = ticket
	car.orderTaker = nil
	car.ordered = true
	car.state = "Ordered"
	table.insert(Orders.tickets, ticket)
	ctx.Customers.updateQueue()
	ctx.sound("Click", Layout.Stations.ReceiptPrinter)
	if flagged then
		ctx.notifyCrew(("Ticket #%d flagged SUSPICIOUS ⚠"):format(ticket.number), "warn")
	end
	ctx.Bus:fire("OrderTaken", ticket, byPlayer)
	Orders.refreshBags()
	return ticket
end

function Orders.closeTicketFor(car)
	local ticket = car.ticket
	if not ticket or ticket.closed then
		return
	end
	ticket.closed = true
	local index = table.find(Orders.tickets, ticket)
	if index then
		table.remove(Orders.tickets, index)
	end
	Orders.refreshBags()
end

function Orders.findTicketFor(item)
	for _, ticket in Orders.sorted() do
		if OrderLogic.bagWants(ticket.lines, ticket.bag, item) then
			return ticket
		end
	end
	return nil
end

function Orders.addToBag(ticket, item, by: any?)
	table.insert(ticket.bag, item)
	if ctx.WeirdEvents.isActive("DoubleTrouble") then
		table.insert(ticket.bag, table.clone(item))
		ctx.notifyCrew(("Double Trouble! #%d got TWO %s."):format(ticket.number, item.label or item.kind), "warn")
	end
	Orders.refreshBags()
	ctx.Bus:fire("ItemBagged", ticket, item, by)
end

-- Remove one random item from a random bag (raccoons!). Returns the label or nil.
function Orders.stealFromBag(): (string?, number?)
	local candidates = {}
	for _, ticket in Orders.tickets do
		if #ticket.bag > 0 then
			table.insert(candidates, ticket)
		end
	end
	if #candidates == 0 then
		return nil, nil
	end
	local ticket = candidates[math.random(1, #candidates)]
	local item = table.remove(ticket.bag, math.random(1, #ticket.bag))
	Orders.refreshBags()
	return item.label or item.kind, ticket.number
end

function Orders.fixBags(): number
	local removed = 0
	for _, ticket in Orders.tickets do
		local result = OrderLogic.compare(ticket.lines, ticket.bag)
		for _, extra in result.extras do
			local index = table.find(ticket.bag, extra)
			if index then
				table.remove(ticket.bag, index)
				removed += 1
			end
		end
	end
	if removed > 0 then
		Orders.refreshBags()
	end
	return removed
end

-- Unmet ticket lines, highest priority first: { { ticket, line } }
function Orders.neededLines()
	local out = {}
	for _, ticket in Orders.sorted() do
		for _, line in OrderLogic.unmetLines(ticket.lines, ticket.bag) do
			table.insert(out, { ticket = ticket, line = line })
		end
	end
	return out
end

function Orders.snapshot()
	local out = {}
	local now = os.clock()
	for _, ticket in Orders.sorted() do
		local status, extras = lineStatus(ticket)
		table.insert(out, {
			number = ticket.number,
			carId = ticket.carId,
			flagged = ticket.flagged,
			age = now - ticket.createdAt,
			lines = status,
			extras = extras,
			atWindow = ticket.car.state == "AtWindow",
		})
	end
	return out
end

---------------------------------------------------------------------------
-- Order console
---------------------------------------------------------------------------

function Orders.openOrder(player: Player)
	if not ctx.Shift.canAct(player) then
		return
	end
	local car = ctx.Customers.speakerCar()
	if not car then
		ctx.notify(player, "No car at the speaker yet.")
		return
	end
	if car.orderTaker and car.orderTaker ~= player and car.orderTaker.Parent then
		ctx.notify(player, car.orderTaker.DisplayName .. " is already taking this order.")
		return
	end
	car.orderTaker = player
	local s = ctx.Shift.session
	ctx.openPanel(player, "Order", {
		carId = car.id,
		lines = car.speaker,
		captions = car.captions,
		night = s.night,
		voiceSeed = car.id * 37 % 100,
		static = car.anomalyId == "StaticStan",
		reversed = car.anomalyId == "UpsideDownOrder",
		unison = car.anomalyId == "TheTwins",
		wantsUsual = car.wantsUsual == true,
	})
	ctx.Bus:fire("OrderOpened", car, player)
end

local function sanitizeLines(raw: any): { any }?
	if type(raw) ~= "table" or #raw > 14 then
		return nil
	end
	local lines = {}
	for _, entry in raw do
		if type(entry) ~= "table" or type(entry.item) ~= "string" or not Menu.Items[entry.item] then
			return nil
		end
		local mods = {}
		if type(entry.mods) == "table" then
			local valid = OrderLogic.validMods(entry.item)
			for _, m in entry.mods do
				if type(m) == "string" and table.find(valid, m) then
					table.insert(mods, m)
				end
			end
		end
		table.insert(lines, { item = entry.item, mods = OrderLogic.normalizeMods(mods) })
	end
	return lines
end

function Orders.reset()
	Orders.cleanup()
	ticketNumber = 100
end

function Orders.cleanup()
	table.clear(Orders.tickets)
	if bagFolder then
		bagFolder:ClearAllChildren()
	end
end

function Orders.init()
	local kitchen = ctx.map.Kitchen
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "OrderPrompt"
	prompt.ActionText = "Take Order"
	prompt.ObjectText = "Order Station"
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Enabled = false
	prompt.Parent = kitchen.OrderConsole
	consolePrompt = prompt
	prompt.Triggered:Connect(Orders.openOrder)

	local bagPrompt = Instance.new("ProximityPrompt")
	bagPrompt.Name = "BagPrompt"
	bagPrompt.ActionText = "Bag Item"
	bagPrompt.ObjectText = "Bag Counter"
	bagPrompt.MaxActivationDistance = 9
	bagPrompt.RequiresLineOfSight = false
	bagPrompt.Parent = kitchen.BagCounter
	bagPrompt.Triggered:Connect(function(player)
		if not ctx.Shift.canAct(player) then
			return
		end
		local held = ctx.Stations.held(player)
		if not held then
			ctx.notify(player, "Bring food here to bag it.")
			return
		end
		if held.kind == "Patty" then
			ctx.notify(player, "A plain patty? Build it into a burger first.")
			return
		end
		local ticket = Orders.findTicketFor(held)
		if not ticket then
			if held.kind == "Burger" then
				ctx.notify(player, ("No ticket needs a %s. Check the stack on the ticket!"):format(held.label or "burger"), "bad")
			else
				ctx.notify(player, ("No order needs %s right now."):format(held.label or held.kind), "bad")
			end
			return
		end
		local item = ctx.Stations.takeHeld(player)
		Orders.addToBag(ticket, item, player)
		ctx.notify(player, ("Bagged %s → #%d"):format(item.label or item.kind, ticket.number), "good")
	end)

	local fixPrompt = Instance.new("ProximityPrompt")
	fixPrompt.Name = "FixPrompt"
	fixPrompt.ActionText = "Remove Extras"
	fixPrompt.ObjectText = "Fix Bags"
	fixPrompt.HoldDuration = 0.6
	fixPrompt.MaxActivationDistance = 7
	fixPrompt.RequiresLineOfSight = false
	fixPrompt.Parent = kitchen.BagFix
	fixPrompt.Triggered:Connect(function(player)
		if not ctx.Shift.canAct(player) then
			return
		end
		local removed = Orders.fixBags()
		ctx.notify(player, if removed > 0 then ("Removed %d extra item(s) from the bags."):format(removed) else "The bags look right.")
	end)

	ctx.onAction("SubmitOrder", function(player, data)
		local car = ctx.Customers.get(tonumber(data.carId) or -1)
		if not car or car.state ~= "AtSpeaker" or not ctx.Shift.canAct(player) then
			return
		end
		if car.orderTaker and car.orderTaker ~= player then
			return
		end
		local lines = sanitizeLines(data.lines)
		if not lines then
			return
		end
		Orders.createTicket(car, lines, data.flagged == true, player)
		ctx.closePanel(player, "Order")
	end)
	ctx.onAction("CancelOrder", function(player, data)
		local car = ctx.Customers.get(tonumber(data.carId) or -1)
		if car and car.orderTaker == player then
			car.orderTaker = nil
		end
	end)

	task.spawn(function()
		while true do
			task.wait(0.25)
			local car = if ctx.Shift.isRunning() then ctx.Customers.speakerCar() else nil
			local enabled = car ~= nil and (car.orderTaker == nil or car.orderTaker.Parent == nil)
			if consolePrompt and consolePrompt.Enabled ~= enabled then
				consolePrompt.Enabled = enabled
			end
		end
	end)
end

return Orders
