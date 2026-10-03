-- Small helpers shared by server and client.

local Util = {}

-- Create an instance, apply properties, then parent it last (cheaper replication).
function Util.make(className: string, props: { [string]: any }?, children: { Instance }?): any
	local inst = Instance.new(className)
	local parent = nil
	if props then
		for key, value in props do
			if key == "Parent" then
				parent = value
			else
				(inst :: any)[key] = value
			end
		end
	end
	if children then
		for _, child in children do
			child.Parent = inst
		end
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

function Util.weld(a: BasePart, b: BasePart): WeldConstraint
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = a
	weld.Part1 = b
	weld.Parent = a
	return weld
end

function Util.clamp(x: number, lo: number, hi: number): number
	if x < lo then
		return lo
	elseif x > hi then
		return hi
	end
	return x
end

function Util.lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

function Util.shuffle<T>(list: { T }, rng: Random?): { T }
	local r = rng or Random.new()
	for i = #list, 2, -1 do
		local j = r:NextInteger(1, i)
		list[i], list[j] = list[j], list[i]
	end
	return list
end

function Util.pick<T>(list: { T }, rng: Random?): T
	local r = rng or Random.new()
	return list[r:NextInteger(1, #list)]
end

function Util.deepCopy(value: any): any
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for k, v in value do
		copy[Util.deepCopy(k)] = Util.deepCopy(v)
	end
	return copy
end

function Util.count(t: { [any]: any }): number
	local n = 0
	for _ in t do
		n += 1
	end
	return n
end

-- "03:00" -> minutes after 6:00 PM (540). Times before 18:00 belong to the next morning.
function Util.parseClock(text: string): number
	local hText, mText = string.match(text, "^(%d+):(%d+)$")
	local h, m = tonumber(hText), tonumber(mText)
	assert(h and m, "bad clock string " .. tostring(text))
	local total = h * 60 + m
	if h < 18 then
		total += 24 * 60
	end
	return total - 18 * 60
end

-- Minutes after 6:00 PM -> "3:14 AM"
function Util.formatClock(minutesAfterSix: number): string
	local total = 18 * 60 + math.floor(minutesAfterSix)
	local h = math.floor(total / 60) % 24
	local m = total % 60
	local h12 = h % 12
	if h12 == 0 then
		h12 = 12
	end
	return string.format("%d:%02d %s", h12, m, if h < 12 then "AM" else "PM")
end

function Util.formatSeconds(seconds: number): string
	seconds = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", math.floor(seconds / 60), seconds % 60)
end

function Util.numberWord(n: number): string
	local words = { "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten" }
	return words[n] or tostring(n)
end

return Util
