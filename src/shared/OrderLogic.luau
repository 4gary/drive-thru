-- Pure order logic (no game services): recipes, mods, matching bags against orders,
-- and turning orders into the words a customer says through the speaker.
--
-- A "line" is one thing on an order:     { item = "munchstack", mods = { "NoPickles", "ExtraSauce" } }
-- An "item" is one physical thing made:  { kind = "Burger", stack = { "BunBottom", ... } } or { kind = "Fries" }

local Menu = require(script.Parent.Data.Menu)

local OrderLogic = {}

export type Line = { item: string, mods: { string }? }
export type Item = { kind: string, stack: { string }?, label: string? }

local MOD_RANK = {}
for i, id in Menu.ModOrder do
	MOD_RANK[id] = i
end

local function contains(list: { string }, value: string): boolean
	return table.find(list, value) ~= nil
end

function OrderLogic.normalizeMods(mods: { string }?): { string }
	local out = {}
	if mods then
		for _, id in mods do
			if Menu.Mods[id] and not contains(out, id) then
				table.insert(out, id)
			end
		end
	end
	table.sort(out, function(a, b)
		return MOD_RANK[a] < MOD_RANK[b]
	end)
	return out
end

function OrderLogic.isBurger(itemId: string): boolean
	local def = Menu.Items[itemId]
	return def ~= nil and def.kind == "Burger"
end

-- Mods that make sense for an item (only burgers take mods; a mod must touch a topping it has).
function OrderLogic.validMods(itemId: string): { string }
	local def = Menu.Items[itemId]
	local out = {}
	if not def or def.kind ~= "Burger" then
		return out
	end
	for _, modId in Menu.ModOrder do
		local mod = Menu.Mods[modId]
		if contains(def.stack, mod.topping) then
			table.insert(out, modId)
		end
	end
	return out
end

function OrderLogic.buildStack(itemId: string, mods: { string }?): { string }
	local def = Menu.Items[itemId]
	assert(def and def.stack, "not a burger: " .. tostring(itemId))
	local stack = table.clone(def.stack)
	local normalized = OrderLogic.normalizeMods(mods)
	for _, modId in normalized do
		local mod = Menu.Mods[modId]
		if mod.kind == "remove" then
			for i = #stack, 1, -1 do
				if stack[i] == mod.topping then
					table.remove(stack, i)
				end
			end
		end
	end
	for _, modId in normalized do
		local mod = Menu.Mods[modId]
		if mod.kind == "extra" then
			for i = #stack, 1, -1 do
				if stack[i] == mod.topping then
					table.insert(stack, i + 1, mod.topping)
					break
				end
			end
		end
	end
	return stack
end

function OrderLogic.stackEquals(a: { string }?, b: { string }?): boolean
	if a == nil or b == nil then
		return false
	end
	if #a ~= #b then
		return false
	end
	for i = 1, #a do
		if a[i] ~= b[i] then
			return false
		end
	end
	return true
end

function OrderLogic.lineKey(line: Line): string
	return line.item .. "|" .. table.concat(OrderLogic.normalizeMods(line.mods), ",")
end

function OrderLogic.lineLabel(line: Line): string
	local def = Menu.Items[line.item]
	local name = if def then def.name else "???"
	local mods = OrderLogic.normalizeMods(line.mods)
	if #mods == 0 then
		return name
	end
	local parts = {}
	for _, modId in mods do
		table.insert(parts, Menu.Mods[modId].label)
	end
	return name .. " (" .. table.concat(parts, ", ") .. ")"
end

function OrderLogic.kindOf(itemId: string): string
	local def = Menu.Items[itemId]
	return if def then def.kind else "?"
end

-- The physical item a line asks for.
function OrderLogic.itemForLine(line: Line): Item
	local kind = OrderLogic.kindOf(line.item)
	if kind == "Burger" then
		return { kind = kind, stack = OrderLogic.buildStack(line.item, line.mods), label = OrderLogic.lineLabel(line) }
	end
	return { kind = kind, label = OrderLogic.lineLabel(line) }
end

function OrderLogic.itemMatchesLine(item: Item, line: Line): boolean
	local kind = OrderLogic.kindOf(line.item)
	if item.kind ~= kind then
		return false
	end
	if kind == "Burger" then
		return OrderLogic.stackEquals(item.stack, OrderLogic.buildStack(line.item, line.mods))
	end
	return true
end

-- Which menu line (if any) a finished burger stack is. Checks up to two mods.
function OrderLogic.identifyBurger(stack: { string }): Line?
	for _, itemId in Menu.Order do
		if OrderLogic.isBurger(itemId) then
			if OrderLogic.stackEquals(stack, OrderLogic.buildStack(itemId, nil)) then
				return { item = itemId, mods = {} }
			end
			local mods = OrderLogic.validMods(itemId)
			for i = 1, #mods do
				if OrderLogic.stackEquals(stack, OrderLogic.buildStack(itemId, { mods[i] })) then
					return { item = itemId, mods = { mods[i] } }
				end
			end
			for i = 1, #mods do
				for j = i + 1, #mods do
					local pair = { mods[i], mods[j] }
					if OrderLogic.stackEquals(stack, OrderLogic.buildStack(itemId, pair)) then
						return { item = itemId, mods = OrderLogic.normalizeMods(pair) }
					end
				end
			end
		end
	end
	return nil
end

function OrderLogic.makeBurgerItem(stack: { string }): Item
	local line = OrderLogic.identifyBurger(stack)
	return {
		kind = "Burger",
		stack = table.clone(stack),
		label = if line then OrderLogic.lineLabel(line) else "Mystery Burger",
	}
end

function OrderLogic.makeSimpleItem(kind: string): Item
	local labels = { Fries = "Fries", Drink = "Drink", Shake = "Shake", Patty = "Patty" }
	return { kind = kind, label = labels[kind] or kind }
end

-- Compare what a customer wanted (lines) with what is in the bag (items).
function OrderLogic.compare(lines: { Line }, items: { Item })
	local used = {}
	local missing = {}
	local matched = 0
	for _, line in lines do
		local found = false
		for i, item in items do
			if not used[i] and OrderLogic.itemMatchesLine(item, line) then
				used[i] = true
				found = true
				break
			end
		end
		if found then
			matched += 1
		else
			table.insert(missing, line)
		end
	end
	local extras = {}
	for i, item in items do
		if not used[i] then
			table.insert(extras, item)
		end
	end
	return {
		matched = matched,
		total = #lines,
		missing = missing,
		extras = extras,
		perfect = matched == #lines and #extras == 0,
	}
end

-- Lines in `lines` not yet covered by `items`.
function OrderLogic.unmetLines(lines: { Line }, items: { Item }): { Line }
	return OrderLogic.compare(lines, items).missing
end

-- Would adding `item` to a bag holding `items` satisfy one more line?
function OrderLogic.bagWants(lines: { Line }, items: { Item }, item: Item): boolean
	for _, line in OrderLogic.unmetLines(lines, items) do
		if OrderLogic.itemMatchesLine(item, line) then
			return true
		end
	end
	return false
end

function OrderLogic.sameOrder(a: { Line }, b: { Line }): boolean
	if #a ~= #b then
		return false
	end
	local keys = {}
	for _, line in a do
		local k = OrderLogic.lineKey(line)
		keys[k] = (keys[k] or 0) + 1
	end
	for _, line in b do
		local k = OrderLogic.lineKey(line)
		if not keys[k] or keys[k] == 0 then
			return false
		end
		keys[k] -= 1
	end
	return true
end

function OrderLogic.price(lines: { Line }): number
	local total = 0
	for _, line in lines do
		local def = Menu.Items[line.item]
		if def then
			total += def.price
		end
	end
	return total
end

---------------------------------------------------------------------------
-- Speech
---------------------------------------------------------------------------

local NUMBER_WORDS = { "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten" }

local function spokenItem(itemId: string, count: number): string
	local def = Menu.Items[itemId]
	if not def then
		return "something"
	end
	if count == 1 then
		if itemId == "fries" then
			return "fries"
		end
		return "a " .. def.singular
	end
	return (NUMBER_WORDS[count] or tostring(count)) .. " " .. def.plural
end

local function joinWords(parts: { string }): string
	if #parts == 0 then
		return "nothing"
	elseif #parts == 1 then
		return parts[1]
	elseif #parts == 2 then
		return parts[1] .. " and " .. parts[2]
	end
	return table.concat(parts, ", ", 1, #parts - 1) .. ", and " .. parts[#parts]
end

function OrderLogic.describe(lines: { Line }): string
	local groups = {}
	local orderKeys = {}
	for _, line in lines do
		local key = OrderLogic.lineKey(line)
		if not groups[key] then
			groups[key] = { line = line, count = 0 }
			table.insert(orderKeys, key)
		end
		groups[key].count += 1
	end
	local parts = {}
	for _, key in orderKeys do
		local group = groups[key]
		local phrase = spokenItem(group.line.item, group.count)
		local mods = OrderLogic.normalizeMods(group.line.mods)
		if #mods > 0 then
			local spoken = {}
			for _, modId in mods do
				table.insert(spoken, Menu.Mods[modId].spoken)
			end
			phrase ..= " with " .. joinWords(spoken)
		end
		table.insert(parts, phrase)
	end
	return joinWords(parts)
end

---------------------------------------------------------------------------
-- Random orders
---------------------------------------------------------------------------

local WEIGHTS = { burger = 3, cheeseburger = 3, munchstack = 2, fries = 4, drink = 3, shake = 2 }

local function weightedItem(rng): string
	local total = 0
	for _, w in WEIGHTS do
		total += w
	end
	local roll = rng:NextNumber() * total
	for _, itemId in Menu.Order do
		roll -= WEIGHTS[itemId]
		if roll <= 0 then
			return itemId
		end
	end
	return "fries"
end

local function randomBurgerId(rng): string
	local burgers = { "burger", "cheeseburger", "munchstack" }
	return burgers[rng:NextInteger(1, #burgers)]
end

-- difficulty: "Normal" | "Picky" | "Custom"
function OrderLogic.generate(rng, difficulty: string?): { Line }
	difficulty = difficulty or "Normal"
	local count
	if difficulty == "Custom" then
		count = rng:NextInteger(3, 4)
	elseif difficulty == "Picky" then
		count = rng:NextInteger(2, 3)
	else
		count = rng:NextInteger(1, 3)
	end
	local lines: { Line } = {}
	-- Most people want a burger.
	if rng:NextNumber() < 0.8 then
		table.insert(lines, { item = randomBurgerId(rng), mods = {} })
	end
	while #lines < count do
		table.insert(lines, { item = weightedItem(rng), mods = {} })
	end
	local modsWanted = if difficulty == "Custom" then 2 elseif difficulty == "Picky" then 1 else 0
	local guard = 0
	while modsWanted > 0 and guard < 20 do
		guard += 1
		local burgerLines = {}
		for _, line in lines do
			if OrderLogic.isBurger(line.item) then
				table.insert(burgerLines, line)
			end
		end
		if #burgerLines == 0 then
			table.insert(lines, { item = randomBurgerId(rng), mods = {} })
			continue
		end
		local line = burgerLines[rng:NextInteger(1, #burgerLines)]
		local options = OrderLogic.validMods(line.item)
		local modId = options[rng:NextInteger(1, #options)]
		local mods = line.mods or {}
		local conflicting = false
		for _, existing in mods do
			if Menu.Mods[existing].topping == Menu.Mods[modId].topping then
				conflicting = true
			end
		end
		if not conflicting and #mods < 2 then
			table.insert(mods, modId)
			line.mods = OrderLogic.normalizeMods(mods)
			modsWanted -= 1
		end
	end
	return lines
end

return OrderLogic
