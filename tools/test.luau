-- Offline tests (run from the repo root):  lune run tools/test
-- Covers pure logic + data integrity, and builds every model so Roblox property/enum mistakes
-- show up here instead of in Studio.

local Harness = require("./harness")
local fs = require("@lune/fs")
local roblox = Harness.roblox

local passed, failed = 0, 0
local function test(name: string, fn: () -> ())
	local ok, err = pcall(fn)
	if ok then
		passed += 1
	else
		failed += 1
		print("FAIL  " .. name .. "\n      " .. tostring(err))
	end
end
local function eq(a, b, msg: string?)
	if a ~= b then
		error((msg or "values differ") .. ": expected " .. tostring(b) .. ", got " .. tostring(a), 2)
	end
end

local OrderLogic = Harness.require("ReplicatedStorage/Shared/OrderLogic")
local Menu = Harness.require("ReplicatedStorage/Shared/Data/Menu")
local Anomalies = Harness.require("ReplicatedStorage/Shared/Data/Anomalies")
local Regulars = Harness.require("ReplicatedStorage/Shared/Data/Regulars")
local Nights = Harness.require("ReplicatedStorage/Shared/Data/Nights")
local WeirdEvents = Harness.require("ReplicatedStorage/Shared/Data/WeirdEvents")
local Cosmetics = Harness.require("ReplicatedStorage/Shared/Data/Cosmetics")
local Badges = Harness.require("ReplicatedStorage/Shared/Data/Badges")
local Codes = Harness.require("ReplicatedStorage/Shared/Data/Codes")
local StoryData = Harness.require("ReplicatedStorage/Shared/Data/Story")
local People = Harness.require("ReplicatedStorage/Shared/Data/People")
local Config = Harness.require("ReplicatedStorage/Shared/Config")
local Util = Harness.require("ReplicatedStorage/Shared/Util")
local Layout = Harness.require("ReplicatedStorage/Shared/Builders/Layout")
local ModelFactory = Harness.require("ReplicatedStorage/Shared/Builders/ModelFactory")
local MapBuilder = Harness.require("ReplicatedStorage/Shared/Builders/MapBuilder")

---------------------------------------------------------------------------
-- OrderLogic
---------------------------------------------------------------------------

test("buildStack: Munch Stack, no pickles, extra sauce (Marv's usual)", function()
	local stack = OrderLogic.buildStack("munchstack", { "NoPickles", "ExtraSauce" })
	eq(table.concat(stack, ","), "BunBottom,Patty,Cheese,Patty,Sauce,Sauce,BunTop")
end)

test("buildStack: extra cheese on a cheeseburger", function()
	eq(table.concat(OrderLogic.buildStack("cheeseburger", { "ExtraCheese" }), ","), "BunBottom,Patty,Cheese,Cheese,BunTop")
end)

test("identifyBurger finds every single-mod burger", function()
	for _, itemId in Menu.Order do
		if OrderLogic.isBurger(itemId) then
			for _, mod in OrderLogic.validMods(itemId) do
				local line = OrderLogic.identifyBurger(OrderLogic.buildStack(itemId, { mod }))
				assert(line, "no match for " .. itemId .. " + " .. mod)
				assert(OrderLogic.itemMatchesLine(OrderLogic.makeBurgerItem(OrderLogic.buildStack(itemId, { mod })), { item = itemId, mods = { mod } }))
			end
		end
	end
end)

test("compare: perfect, missing, extras", function()
	local lines = { { item = "cheeseburger" }, { item = "fries" }, { item = "drink" } }
	local bag = {
		OrderLogic.makeBurgerItem(OrderLogic.buildStack("cheeseburger")),
		OrderLogic.makeSimpleItem("Fries"),
		OrderLogic.makeSimpleItem("Drink"),
	}
	assert(OrderLogic.compare(lines, bag).perfect, "should be perfect")
	table.remove(bag, 3)
	local r = OrderLogic.compare(lines, bag)
	eq(r.perfect, false)
	eq(#r.missing, 1)
	table.insert(bag, OrderLogic.makeSimpleItem("Shake"))
	r = OrderLogic.compare(lines, bag)
	eq(#r.extras, 1)
end)

test("wrong burger stack doesn't match the ticket", function()
	local lines = { { item = "munchstack", mods = { "NoPickles", "ExtraSauce" } } }
	local plain = OrderLogic.makeBurgerItem(OrderLogic.buildStack("munchstack"))
	eq(OrderLogic.bagWants(lines, {}, plain), false)
	local usual = OrderLogic.makeBurgerItem(OrderLogic.buildStack("munchstack", { "ExtraSauce", "NoPickles" }))
	eq(OrderLogic.bagWants(lines, {}, usual), true)
end)

test("Gerald: empty order + empty bag is perfect", function()
	assert(OrderLogic.compare({}, {}).perfect, "empty order + empty bag should be perfect")
end)

test("describe reads naturally", function()
	eq(OrderLogic.describe({ { item = "cheeseburger" }, { item = "cheeseburger" }, { item = "fries" } }), "two cheeseburgers and fries")
	eq(OrderLogic.describe({ { item = "munchstack", mods = { "NoPickles" } } }), "a Munch Stack with no pickles")
end)

test("generate produces valid orders for every difficulty", function()
	local rng = Harness.Random.new(42)
	for _, difficulty in { "Normal", "Picky", "Custom" } do
		for _ = 1, 200 do
			local lines = OrderLogic.generate(rng, difficulty)
			assert(#lines >= 1 and #lines <= 6, "bad length")
			for _, line in lines do
				assert(Menu.Items[line.item], "bad item " .. tostring(line.item))
				for _, mod in line.mods or {} do
					assert(table.find(OrderLogic.validMods(line.item), mod), "bad mod " .. mod .. " on " .. line.item)
				end
				if OrderLogic.isBurger(line.item) then
					-- whatever the mods, the stack must be buildable and identifiable
					assert(OrderLogic.identifyBurger(OrderLogic.buildStack(line.item, line.mods)), "unidentifiable " .. OrderLogic.lineLabel(line))
				end
			end
		end
	end
end)

---------------------------------------------------------------------------
-- Util
---------------------------------------------------------------------------

test("clock parsing/formatting", function()
	eq(Util.parseClock("18:00"), 0)
	eq(Util.parseClock("03:00"), 540)
	eq(Util.parseClock("06:00"), 720)
	eq(Util.formatClock(0), "6:00 PM")
	eq(Util.formatClock(644), "4:44 AM")
	eq(Util.formatClock(360), "12:00 AM")
end)

---------------------------------------------------------------------------
-- Data integrity
---------------------------------------------------------------------------

local function validLines(lines, where)
	for _, line in lines do
		assert(Menu.Items[line.item], where .. ": bad item " .. tostring(line.item))
		for _, mod in line.mods or {} do
			assert(table.find(OrderLogic.validMods(line.item), mod), where .. ": bad mod " .. mod)
		end
	end
end

test("anomalies: orders, usuals, weird events, channels", function()
	local channels = { Window = true, Mirror = true, LaneCam = true, Receipt = true, Speaker = true, UV = true }
	local photoCount = 0
	for _, a in Anomalies.List do
		validLines(a.order, a.id)
		assert(WeirdEvents.ById[a.weirdEvent], a.id .. ": unknown weird event " .. tostring(a.weirdEvent))
		for _, tell in a.tells do
			assert(channels[tell.channel], a.id .. ": bad channel " .. tostring(tell.channel))
		end
		if a.photo then
			photoCount += 1
			validLines(a.photo.usual, a.id .. " usual")
			assert(a.freedLine, a.id .. " needs a freedLine")
		end
	end
	eq(photoCount, 5, "Night 5 needs five photo-employees")
end)

test("nights: every event references something real", function()
	local beats = { Bobblehead = true, StatueGone = true, PlayPlaceLight = true, Reveal = true, FinalRush = true }
	local scares = { RushHour = true, HighBeams = true, LightsOutSafe = true }
	eq(#Nights.List, 5)
	for _, night in Nights.List do
		for _, id in night.latePool do
			assert(Anomalies.ById[id], ("night %d: bad latePool id %s"):format(night.number, id))
		end
		for _, e in night.events do
			Util.parseClock(e.t)
			if e.kind == "customer" then
				assert(e.id == "RandomLate" or e.id == "Normal" or Anomalies.ById[e.id] or Regulars.ById[e.id], ("night %d: unknown customer %s"):format(night.number, e.id))
			elseif e.kind == "scare" then
				assert(scares[e.id], "unknown scare " .. e.id)
			elseif e.kind == "beat" then
				assert(beats[e.id], "unknown beat " .. e.id)
			else
				assert(e.kind == "radio" or e.kind == "note", "unknown event kind " .. tostring(e.kind))
			end
		end
	end
end)

test("regulars: orders valid", function()
	for id, r in Regulars.ById do
		if r.order then
			validLines(r.order, id)
		end
	end
end)

test("cosmetics: robux keys exist in Config.DevProducts, defaults per slot", function()
	local defaults = {}
	for _, item in Cosmetics.List do
		if item.robux then
			assert(Config.DevProducts[item.robux] ~= nil, item.id .. ": missing Config.DevProducts." .. item.robux)
		end
		if item.default then
			defaults[item.slot] = true
		end
	end
	for _, slot in Cosmetics.Slots do
		assert(defaults[slot], "no default cosmetic for slot " .. slot)
	end
end)

test("codes reference real cosmetics", function()
	for code, entry in Codes do
		if entry.reward.cosmetic then
			assert(Cosmetics.ById[entry.reward.cosmetic], code .. ": bad cosmetic")
		end
	end
end)

test("every awarded badge exists", function()
	local ids = {}
	for _, dir in { "src/server/Services" } do
		for _, file in fs.readDir(dir) do
			local source = fs.readFile(dir .. "/" .. file)
			for id in string.gmatch(source, 'award%(%w+, "([%w_]+)"%)') do
				ids[id] = file
			end
			for id in string.gmatch(source, 'awardCrew%("([%w_]+)"%)') do
				ids[id] = file
			end
		end
	end
	for n = 1, 5 do
		ids["night" .. n] = "Shift"
	end
	for _, ending in StoryData.Endings do
		ids[ending.badge] = "Story"
	end
	for id, file in ids do
		assert(Badges.ById[id], ("badge %s awarded in %s doesn't exist"):format(id, file))
	end
	assert(#Badges.List >= 30, "MVP wants 30 badges")
end)

test("wall photos reference real anomalies", function()
	eq(#StoryData.WallPhotos, 13)
	for _, photo in StoryData.WallPhotos do
		if photo.anomaly then
			assert(Anomalies.ById[photo.anomaly], "bad photo anomaly " .. photo.anomaly)
		end
	end
end)

test("layout: slots are ordered front (window) to back", function()
	for i = 2, #Layout.Slots do
		assert(Layout.Slots[i].x < Layout.Slots[i - 1].x, "slot order")
	end
	eq(Layout.Slots[Layout.SpeakerSlot].name, "Speaker")
	eq(Layout.Slots[Layout.WindowSlot].name, "Window")
end)

---------------------------------------------------------------------------
-- Models (validates every Roblox property/enum we set)
---------------------------------------------------------------------------

test("build every Late Customer", function()
	local rng = Harness.Random.new(7)
	for _, a in Anomalies.List do
		local person = People.random(rng)
		for k, v in a.person or {} do
			person[k] = v
		end
		local model = ModelFactory.buildCustomer({ person = person, car = a.car, modifiers = a.modifiers })
		assert(model.PrimaryPart, a.id .. ": no PrimaryPart")
	end
end)

test("build every regular + kids + special modifiers", function()
	local rng = Harness.Random.new(9)
	for id, r in Regulars.ById do
		local person = People.random(rng)
		for k, v in r.person or {} do
			person[k] = v
		end
		local mods = table.clone(r.modifiers or {})
		if id == "Hendersons" then
			table.insert(mods, "Kids:9")
		end
		ModelFactory.buildCustomer({ person = person, car = r.car, modifiers = mods })
	end
	ModelFactory.buildCustomer({ person = People.random(rng), car = { kind = "Minivan" }, modifiers = { "IdenticalKids:9" } })
	ModelFactory.buildCustomer({ person = {}, car = { kind = "Vintage", color = roblox.Color3.new(0, 0, 0) }, modifiers = { "NoDriver" } })
end)

test("build every car kind with random people", function()
	local rng = Harness.Random.new(3)
	for _, kind in { "Sedan", "Hatchback", "Compact", "Pickup", "Minivan", "Convertible", "Buick", "Police", "Vintage", "Scooter", "None" } do
		for _ = 1, 3 do
			ModelFactory.buildCustomer({ person = People.random(rng), car = { kind = kind, color = People.pick(People.CarColors, rng) }, modifiers = {} })
		end
	end
end)

test("build Mr. Munch variants, Gizmo, ghosts, items, props", function()
	ModelFactory.buildMunch({})
	ModelFactory.buildMunch({ realMouth = true })
	ModelFactory.buildMunch({ statue = true, anchored = true, scale = 0.85 })
	ModelFactory.buildMunch({ knockoff = true, scale = 0.55, anchored = true })
	ModelFactory.buildGizmo()
	ModelFactory.buildGizmoGhost()
	ModelFactory.buildGhostSheet(roblox.Color3.new(1, 1, 1), roblox.Color3.new(1, 0, 0), "Gary")
	for _, kind in { "Patty", "Fries", "Drink", "Shake", "Bag", "Other" } do
		ModelFactory.buildItem(kind)
	end
	ModelFactory.buildItem("Burger", { stack = OrderLogic.buildStack("munchstack"), toppings = Menu.Toppings })
	ModelFactory.buildRaccoon()
	ModelFactory.buildEar()
	ModelFactory.buildDoily()
	ModelFactory.buildStickyNote("DON'T LOOK AT FRYER")
	ModelFactory.buildGoldStar()
end)

test("map builds and has every part the server looks up", function()
	local holder = roblox.Instance.new("Folder")
	local map = MapBuilder.build(holder)
	local required = {
		"Kitchen.OrderConsole",
		"Kitchen.Grill",
		"Kitchen.AssemblyPlate",
		"Kitchen.CuttingBoard",
		"Kitchen.Fryer1",
		"Kitchen.Fryer2",
		"Kitchen.FryerBasket1",
		"Kitchen.FryerBasket2",
		"Kitchen.FryBin",
		"Kitchen.SodaFountain",
		"Kitchen.ShakeMachine",
		"Kitchen.BagCounter",
		"Kitchen.BagFix",
		"Kitchen.WindowStation",
		"Kitchen.WindowShutter",
		"Kitchen.Trash1",
		"Kitchen.Trash2",
		"Kitchen.Bobblehead",
		"Kitchen.Posters.Poster1",
		"Rooms.MunchStatue",
		"Rooms.VHSTape",
		"Rooms.DebCoffee",
		"Rooms.EmployeeWall.Photo13",
		"Rooms.EmployeeWall.PhotoUV13",
		"Lane.MenuBoard",
		"Lane.OpenSign",
		"Lobby.Locker",
		"Lobby.Fax",
		"Lobby.FieldGuideKiosk",
		"Lobby.Leaderboard",
		"Lobby.LobbyTV",
		"Lobby.CreditsWall",
		"Lobby.BoothADisplay",
		"Lobby.BoothBDisplay",
		"Lights.PlayPlaceLight",
		"Scenery.Balloons",
		"Scenery.SafetyPoster",
		"Scenery.VisitBanner",
		"Scenery.Rain",
		"Dynamic",
	}
	for _, spot in Layout.HidingOrder do
		table.insert(required, "HidingSpots." .. spot)
	end
	for _, path in required do
		local node = map
		for name in string.gmatch(path, "[^%.]+") do
			node = node:FindFirstChild(name)
			assert(node, "missing " .. path)
		end
	end
end)

print(("\n%d passed, %d failed"):format(passed, failed))
if failed > 0 then
	error("tests failed")
end
