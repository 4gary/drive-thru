-- Night Shift: Drive-Thru — client entry point. Starts every controller in order.

local Controllers = script.Parent:WaitForChild("Controllers")
local Kit = require(script.Parent:WaitForChild("UI"):WaitForChild("Kit"))

Kit.watchViewport()

local ORDER = {
	"State",
	"Audio",
	"World",
	"CameraView",
	"Effects",
	"HUD",
	"Panels",
	"OrderPanel",
	"AssemblyPanel",
	"WindowPanel",
	"MenuPanels",
	"Lobby",
	"Hide",
	"DebugPanel",
}

for _, name in ORDER do
	local ok, err = pcall(function()
		local controller = require(Controllers:WaitForChild(name)) :: any
		if controller.init then
			controller.init()
		end
	end)
	if not ok then
		warn(("[NightShift] client controller %s failed: %s"):format(name, tostring(err)))
	end
end
