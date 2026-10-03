-- Inspection & Decision (design doc §5.1, §7.2, §7.5): the pickup window. Players inspect the car
-- (Window / Mirror / Lane Cam / Receipt / UV), then HAND OUT or REFUSE (slam the shutter).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Layout = require(Shared.Builders.Layout)
local OrderLogic = require(Shared.OrderLogic)
local People = require(Shared.Data.People)
local Util = require(Shared.Util)
local ctx = require(script.Parent.Context)

local Window = {}

local viewers: { [Player]: number } = {} -- player -> carId being inspected
local prompt: ProximityPrompt? = nil
local shutter: BasePart? = nil
local shutterOpen: CFrame? = nil

function Window.inspecting(car): boolean
	for _, carId in viewers do
		if carId == car.id then
			return true
		end
	end
	return false
end

local function slamShutter()
	if not shutter or not shutterOpen then
		return
	end
	local closed = (shutterOpen :: CFrame) * CFrame.new(0, -4.8, 0)
	local down = TweenService:Create(shutter, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { CFrame = closed })
	down:Play()
	ctx.sound("Shutter", Layout.Stations.Window)
	ctx.caption("[SLAM — 'SORRY, WE'RE CLOSED']", Layout.Stations.Window, 2)
	task.delay(2.2, function()
		TweenService:Create(shutter :: BasePart, TweenInfo.new(0.6), { CFrame = shutterOpen :: CFrame }):Play()
	end)
end

function Window.openFor(player: Player)
	if not ctx.Shift.canAct(player) then
		return
	end
	local car = ctx.Customers.windowCar()
	if not car then
		ctx.notify(player, "No car at the window yet.")
		return
	end
	local s = ctx.Shift.session
	viewers[player] = car.id
	local bagStatus = nil
	if car.ticket then
		local result = OrderLogic.compare(car.ticket.lines, car.ticket.bag)
		bagStatus = {
			number = car.ticket.number,
			bagged = #car.ticket.bag,
			ticketLines = #car.ticket.lines,
			ticketMatched = result.matched,
			flagged = car.ticket.flagged,
		}
	end
	ctx.openPanel(player, "Window", {
		carId = car.id,
		car = car.model,
		receipt = if car.ticket then car.ticket.receipt else nil,
		bag = bagStatus,
		mirrorTell = car.mirrorTell or "None",
		uv = s.flags.uv == true,
		night = s.night,
		onFoot = car.skipSpeaker == true,
		revealed = s.flags.revealed == true,
		wantsUsual = car.wantsUsual == true,
		tutorialRefuse = s.night == 1 and car.anomalyId == "EarlOfEars",
	})
	ctx.Bus:fire("WindowOpened", car, player)
end

local function closeViewersOf(car)
	for viewer, carId in viewers do
		if carId == car.id then
			viewers[viewer] = nil
			if viewer.Parent then
				ctx.closePanel(viewer, "Window")
			end
		end
	end
end

local function fieldGuide(car, how: string)
	if not car.anomalyId then
		return
	end
	for _, p in ctx.Shift.crewPlayers() do
		local new = ctx.PlayerData.addFieldGuide(p, car.anomalyId, how)
		if new then
			ctx.effect("FieldGuideCard", { id = car.anomalyId, how = how }, { p })
		end
		local profile = ctx.PlayerData.get(p)
		if profile then
			local n = 0
			for _ in profile.fieldGuide do
				n += 1
			end
			if n >= 10 then
				ctx.Badges.award(p, "field_guide10")
			end
		end
	end
end

local function handOut(player: Player, car)
	local s = ctx.Shift.session
	local bag = if car.ticket then car.ticket.bag else {}
	local def = car.def
	if car.kind == "Special" then
		-- SpookyPriya gives the crew her UV flashlight either way.
		ctx.Story.giveUV()
		ctx.Customers.say(car, def.servedLine or "Thanks!")
		return "special"
	end
	if car.isLate then
		if s.flags.revealed and def.photo and car.wantsUsual then
			local result = OrderLogic.compare(def.photo.usual, bag)
			if result.perfect then
				s.stats.freed[def.id] = true
				ctx.Customers.say(car, def.freedLine or "Thank you.", 6)
				ctx.effect("Freed", { carId = car.id, name = def.photo.employee, year = def.photo.year })
				ctx.radio(def.photo.employee, def.freedLine or "Thank you.", 6)
				ctx.Shift.addWeird(-10)
				ctx.Shift.addStars(0.3, "Freed " .. def.photo.employee)
				for _, p in ctx.Shift.crewPlayers() do
					ctx.PlayerData.markFreed(p, def.id)
					ctx.Badges.award(p, "freed")
				end
				ctx.Shift.moment(("%s handed %s their usual. %s drove off into the morning light."):format(player.DisplayName, def.photo.employee, def.photo.employee), 90)
				ctx.Bus:fire("Freed", car, player)
				fieldGuide(car, "caught")
				return "freed"
			end
			ctx.Customers.say(car, "...That's not my usual.", 4)
		else
			ctx.Customers.say(car, def.servedLine or "...Thank you.")
		end
		s.stats.lateServed += 1
		ctx.Shift.addWeird(Config.Weird.ServedLate)
		fieldGuide(car, "seen")
		ctx.Badges.award(player, "served_late")
		ctx.WeirdEvents.trigger(def.weirdEvent, car)
		ctx.Shift.moment(("%s served %s. Then: %s."):format(player.DisplayName, def.name, def.weirdEvent), 40)
		return "servedLate"
	end
	-- normal humans and regulars
	local result = OrderLogic.compare(car.order or {}, bag)
	s.stats.served += 1
	if def and def.alwaysHappy then
		ctx.Shift.addStars(if result.perfect then Config.Stars.Perfect else Config.Stars.Okay, "Gerald")
		ctx.Customers.say(car, def.servedLine)
		if result.perfect then
			s.stats.perfect += 1
			ctx.Badges.award(player, "hold_the_seven")
		end
		return "perfect"
	end
	if result.perfect then
		s.stats.perfect += 1
		ctx.Shift.addStars(Config.Stars.Perfect + ((def and def.bonusStars) or 0), "Perfect order")
		ctx.Badges.award(player, "perfect")
		local line = if def and def.servedLineByNight and def.servedLineByNight[s.night]
			then def.servedLineByNight[s.night]
			elseif def and def.servedLine then def.servedLine
			else People.pick(People.Thanks, s.rng)
		ctx.Customers.say(car, line)
		ctx.sound("Ding", Layout.Stations.Window)
		if def and def.id == "Hendersons" and car.kids and car.kids >= 9 then
			ctx.Badges.awardCrew("hendersons9")
		end
		for _, p in ctx.Shift.crewPlayers() do
			ctx.PlayerData.addStat(p, "perfect", 1)
		end
		return "perfect"
	end
	s.stats.wrong += 1
	local missing = #result.missing
	if result.matched > 0 and missing <= 1 and #result.extras <= 1 then
		ctx.Shift.addStars(Config.Stars.Okay * 0.5, "Close enough")
		ctx.Customers.say(car, if missing > 0 then "Hey, you forgot something... whatever." else "Uh, extra stuff? Okay.")
		return "okay"
	end
	ctx.Shift.addStars(Config.Stars.WrongOrder, "Wrong order")
	ctx.Customers.say(car, if def and def.wrongLine then def.wrongLine else People.pick(People.Complaints, s.rng))
	return "wrong"
end

local function refuse(player: Player, car)
	local s = ctx.Shift.session
	local def = car.def
	slamShutter()
	if car.kind == "Special" then
		ctx.Story.giveUV()
		ctx.Customers.say(car, def.refusedLine or "Okay!")
		return "special"
	end
	if car.isLate then
		s.stats.caught += 1
		if not s.stats.firstCatch then
			s.stats.firstCatch = ("%s refused %s at %s"):format(player.DisplayName, def.name, Util.formatClock(s.minutes))
		end
		if s.flags.revealed then
			s.stats.companyRefusals += 1
		end
		ctx.Shift.addStars(Config.Stars.CaughtLate, "GOTCHA!")
		ctx.effect("Gotcha", { name = def.name })
		ctx.sound("Gotcha", Layout.Stations.Window)
		ctx.Customers.say(car, def.refusedLine or "...")
		ctx.Badges.award(player, "gotcha")
		if def.id == "TotallyNormalFamily" then
			ctx.Badges.awardCrew("refused_raccoon")
			ctx.WeirdEvents.raccoonsFlee(car)
		end
		if car.ticket and OrderLogic.compare(car.order or {}, car.ticket.bag).perfect and #car.ticket.bag > 0 then
			ctx.Badges.award(player, "perfect_raccoon")
		end
		for _, p in ctx.Shift.crewPlayers() do
			ctx.PlayerData.addStat(p, "lateCaught", 1)
		end
		fieldGuide(car, "caught")
		ctx.Shift.moment(("%s caught %s at the window. GOTCHA!"):format(player.DisplayName, def.name), 30)
		return "caught"
	end
	s.stats.refusedNormal += 1
	ctx.Shift.addStars(Config.Stars.RefusedNormal, "Refused a normal customer")
	ctx.Customers.say(car, (def and def.refusedLine) or "What?! I didn't do anything!")
	if def and def.id == "Hendersons" then
		ctx.Badges.award(player, "not_anomalies")
		ctx.Shift.moment(("%s refused the Hendersons. They were normal."):format(player.DisplayName), 50)
	end
	return "refusedNormal"
end

function Window.decide(player: Player, carId: number, decision: string)
	if not ctx.Shift.canAct(player) then
		return
	end
	local car = ctx.Customers.get(carId)
	if not car or car.decided or car.state ~= "AtWindow" then
		ctx.closePanel(player, "Window")
		return
	end
	car.decided = true
	local result
	if decision == "handout" then
		result = handOut(player, car)
	else
		result = refuse(player, car)
	end
	closeViewersOf(car)
	ctx.Bus:fire("Decision", car, decision, result, player)
	task.delay(if decision == "refuse" then 1.4 else 0.6, function()
		ctx.Customers.leave(car)
	end)
end

function Window.reset()
	table.clear(viewers)
end

function Window.init()
	local kitchen = ctx.map.Kitchen
	shutter = kitchen:FindFirstChild("WindowShutter") :: BasePart?
	if shutter then
		shutterOpen = shutter.CFrame
	end
	local p = Instance.new("ProximityPrompt")
	p.Name = "WindowPrompt"
	p.ActionText = "Inspect Car"
	p.ObjectText = "Pickup Window"
	p.MaxActivationDistance = 9
	p.RequiresLineOfSight = false
	p.Enabled = false
	p.Parent = kitchen.WindowStation
	prompt = p
	p.Triggered:Connect(Window.openFor)
	ctx.onAction("Decide", function(player, data)
		Window.decide(player, tonumber(data.carId) or -1, if data.decision == "handout" then "handout" else "refuse")
	end)
	ctx.onAction("CloseWindow", function(player)
		viewers[player] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(0.25)
			local car = if ctx.Shift.isRunning() then ctx.Customers.windowCar() else nil
			local enabled = car ~= nil and not car.decided
			if prompt and prompt.Enabled ~= enabled then
				prompt.Enabled = enabled
			end
			for viewer, carId in viewers do
				local viewed = ctx.Customers.get(carId)
				if not viewer.Parent or not viewed or viewed.state ~= "AtWindow" then
					viewers[viewer] = nil
					if viewer.Parent then
						ctx.closePanel(viewer, "Window")
					end
				end
			end
		end
	end)
end

return Window
