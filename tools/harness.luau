-- Lune harness: loads this project's ModuleScripts outside Roblox.
-- Resolves `script.Parent.X` + `require(...)` against the Rojo layout in default.project.json
-- and provides Roblox datatypes (Instance, Vector3, CFrame, Enum, ...) from @lune/roblox.
--
-- Only modules that don't touch game services can run here (data, OrderLogic, builders).

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")

local Harness = {}

-- Rojo mapping: Roblox path -> folder on disk
local MOUNTS = {
	["ReplicatedStorage/Shared"] = "src/shared",
	["ServerScriptService/Server"] = "src/server",
	["StarterPlayer/StarterPlayerScripts/Client"] = "src/client",
}

-- Minimal Random (deterministic LCG) compatible with Roblox's Random API surface we use.
local RandomShim = {}
RandomShim.__index = RandomShim
function RandomShim.new(seed: number?)
	local self = setmetatable({}, RandomShim)
	self._state = math.floor((seed or os.clock() * 1e6) % 2147483647)
	if self._state <= 0 then
		self._state = 12345
	end
	return self
end
function RandomShim:_next(): number
	self._state = (self._state * 48271) % 2147483647
	return self._state / 2147483647
end
function RandomShim:NextNumber(min: number?, max: number?): number
	local lo, hi = min or 0, max or 1
	return lo + (hi - lo) * self:_next()
end
function RandomShim:NextInteger(min: number, max: number): number
	return math.floor(min + (max - min + 1) * self:_next())
end

local taskShim = require("@lune/task")

local function makeProxy(path: string)
	return setmetatable({ __path = path }, {
		__index = function(_, key)
			if key == "Parent" then
				local parentPath = string.match(path, "^(.*)/[^/]+$") or ""
				return makeProxy(parentPath)
			elseif key == "Name" then
				return string.match(path, "([^/]+)$")
			end
			return makeProxy(path .. "/" .. key)
		end,
		__tostring = function()
			return "ScriptProxy(" .. path .. ")"
		end,
	})
end

local function toDisk(robloxPath: string): string?
	for prefix, disk in MOUNTS do
		if robloxPath == prefix then
			return disk
		elseif string.sub(robloxPath, 1, #prefix + 1) == prefix .. "/" then
			return disk .. string.sub(robloxPath, #prefix + 1)
		end
	end
	return nil
end

local cache = {}
local env

local function load(robloxPath: string)
	if cache[robloxPath] ~= nil then
		return cache[robloxPath]
	end
	local disk = toDisk(robloxPath)
	assert(disk, "cannot map " .. robloxPath)
	local file, scriptPath
	if fs.isFile(disk .. ".luau") then
		file = disk .. ".luau"
		scriptPath = robloxPath
	elseif fs.isFile(disk .. "/init.luau") then
		file = disk .. "/init.luau"
		scriptPath = robloxPath
	else
		error("module not found: " .. robloxPath .. " (" .. disk .. ")")
	end
	local source = fs.readFile(file)
	local moduleEnv = setmetatable({ script = makeProxy(scriptPath) }, { __index = env })
	local chunk = luau.load(source, { debugName = file, environment = moduleEnv, injectGlobals = false })
	local result = chunk()
	cache[robloxPath] = result
	return result
end

env = {
	print = print,
	warn = function(...)
		print("[warn]", ...)
	end,
	error = error,
	assert = assert,
	pcall = pcall,
	xpcall = xpcall,
	select = select,
	type = type,
	typeof = typeof,
	tostring = tostring,
	tonumber = tonumber,
	pairs = pairs,
	ipairs = ipairs,
	next = next,
	rawget = rawget,
	rawset = rawset,
	rawequal = rawequal,
	rawlen = rawlen,
	setmetatable = setmetatable,
	getmetatable = getmetatable,
	unpack = table.unpack,
	math = math,
	string = string,
	table = table,
	os = os,
	utf8 = utf8,
	bit32 = bit32,
	coroutine = coroutine,
	buffer = buffer,
	debug = debug,
	tick = os.clock,
	time = os.clock,
	Instance = roblox.Instance,
	Vector3 = roblox.Vector3,
	Vector2 = roblox.Vector2,
	CFrame = roblox.CFrame,
	Color3 = roblox.Color3,
	Enum = roblox.Enum,
	UDim = roblox.UDim,
	UDim2 = roblox.UDim2,
	NumberRange = roblox.NumberRange,
	NumberSequence = roblox.NumberSequence,
	ColorSequence = roblox.ColorSequence,
	BrickColor = roblox.BrickColor,
	Font = roblox.Font,
	Random = RandomShim,
	task = taskShim,
	require = function(target)
		if type(target) == "table" and rawget(target, "__path") then
			return load(rawget(target, "__path"))
		end
		error("harness require: unsupported target " .. tostring(target))
	end,
}

function Harness.require(robloxPath: string)
	return load(robloxPath)
end

Harness.env = env
Harness.roblox = roblox
Harness.Random = RandomShim

return Harness
