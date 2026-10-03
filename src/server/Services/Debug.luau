-- Studio-only debug commands (the client shows a small DEBUG panel in Studio).
-- Ignored entirely in a live game.

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local ctx = require(script.Parent.Context)

local Debug = {}

local commands: { [string]: (Player, any) -> () } = {
	skip = function()
		ctx.Shift.debugSkip(60)
	end,
	rush = function()
		ctx.Scares.forceStart("RushHour")
	end,
	beams = function()
		ctx.Scares.forceStart("HighBeams")
	end,
	lightsout = function()
		ctx.Scares.forceStart("LightsOutSafe")
	end,
	late = function(_, arg)
		ctx.Customers.spawnById(if type(arg) == "string" and arg ~= "" then arg else "RandomLate")
	end,
	normal = function()
		ctx.Customers.spawnById("Normal")
	end,
	weird = function()
		ctx.Shift.addWeird(100)
	end,
	starsUp = function()
		ctx.Shift.addStars(1, "Debug")
	end,
	starsDown = function()
		ctx.Shift.addStars(-1, "Debug")
	end,
	win = function()
		ctx.Shift.debugSkip(Config.NightEndMinute)
	end,
	fail = function()
		ctx.Shift.fail("CorporateCalled")
	end,
	boop = function(player)
		ctx.Ghosts.boop(player, "Munch")
	end,
	unlock = function(player)
		ctx.PlayerData.unlockNight(player, 5)
	end,
	pay = function(player)
		ctx.PlayerData.addPaychecks(player, 500)
	end,
	reveal = function()
		ctx.Story.beat("Reveal")
	end,
	uv = function()
		ctx.Story.giveUV()
	end,
	event = function(_, arg)
		if type(arg) == "string" then
			ctx.WeirdEvents.trigger(arg, nil)
		end
	end,
	start = function(player, arg)
		if ctx.Shift.session then
			ctx.Shift.endSession()
			task.wait(0.5)
		end
		ctx.Shift.start({ players = { player }, night = tonumber(arg) or 1, leaderUserId = player.UserId, mode = "InPlace" })
	end,
	endShift = function()
		ctx.Shift.endSession()
	end,
}

function Debug.init()
	ctx.onAction("Debug", function(player, data)
		if not RunService:IsStudio() or not Config.DebugPanelInStudio then
			return
		end
		local command = commands[tostring(data.cmd)]
		if command then
			print(("[Debug] %s ran %s %s"):format(player.Name, tostring(data.cmd), tostring(data.arg or "")))
			command(player, data.arg)
		end
	end)
end

return Debug
