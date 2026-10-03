-- Prebuilds the greybox map into assets/Munchies.rbxmx so it shows up in Studio's edit mode
-- (and Rojo syncs it). Run from the repo root:  lune run tools/build-map
local fs = require("@lune/fs")
local Harness = require("./harness")

local MapBuilder = Harness.require("ReplicatedStorage/Shared/Builders/MapBuilder")
local roblox = Harness.roblox

local holder = roblox.Instance.new("Folder")
local map = MapBuilder.build(holder)

local count = 0
for _, d in map:GetDescendants() do
	if d:IsA("BasePart") then
		count += 1
	end
end
print(("Built map with %d parts"):format(count))

fs.writeFile("assets/Munchies.rbxmx", roblox.serializeModel({ map }, true))
print("Wrote assets/Munchies.rbxmx")
