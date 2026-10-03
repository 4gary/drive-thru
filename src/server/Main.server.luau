-- Night Shift: Drive-Thru — server entry point.
-- Makes sure the map exists, then loads and starts every service (see Services/).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MapBuilder = require(Shared.Builders.MapBuilder)
local Services = script.Parent:WaitForChild("Services")
local ctx = require(Services.Context)

local map = workspace:FindFirstChild("Munchies")
if not map or not map:FindFirstChild("Kitchen") then
	if map then
		map:Destroy()
	end
	map = MapBuilder.build(workspace)
	print("[NightShift] Built the greybox map at runtime.")
end
if not map:FindFirstChild("Dynamic") then
	local dynamic = Instance.new("Folder")
	dynamic.Name = "Dynamic"
	dynamic.Parent = map
end
ctx.map = map

local ORDER = {
	"PlayerData",
	"Badges",
	"Characters",
	"Shift",
	"Customers",
	"Orders",
	"Stations",
	"Window",
	"WeirdEvents",
	"Scares",
	"Hiding",
	"Ghosts",
	"Gizmo",
	"Story",
	"Lobby",
	"Shop",
	"Codes",
	"Chat",
	"Debug",
}

for _, name in ORDER do
	ctx[name] = require(Services:WaitForChild(name))
end
for _, name in ORDER do
	local service = ctx[name]
	if service.init then
		local ok, err = pcall(service.init)
		if not ok then
			warn(("[NightShift] %s failed to start: %s"):format(name, tostring(err)))
		end
	end
end

print("[NightShift] Munchie's is open. Open late. Open always.")
