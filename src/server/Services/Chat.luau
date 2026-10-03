-- Callouts without voice (design doc §7.3): the quick-chat wheel and ping-on-object.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local QuickChat = require(Shared.Data.QuickChat)
local ctx = require(script.Parent.Context)

local Chat = {}

local lastChat: { [Player]: number } = {}
local lastPing: { [Player]: number } = {}

local byId = {}
for _, entry in QuickChat do
	byId[entry.id] = entry
end

local function sameRoom(player: Player): { Player }
	if ctx.Shift.isCrew(player) then
		return ctx.Shift.crewPlayers()
	end
	local out = {}
	for _, p in Players:GetPlayers() do
		if not ctx.Shift.isCrew(p) then
			table.insert(out, p)
		end
	end
	return out
end

function Chat.init()
	ctx.onAction("QuickChat", function(player, data)
		local entry = byId[tostring(data.id)]
		if not entry then
			return
		end
		local now = os.clock()
		if (lastChat[player] or 0) + 1.2 > now then
			return
		end
		lastChat[player] = now
		if ctx.Shift.isCrew(player) and ctx.WeirdEvents.isActive("MandatoryFun") then
			ctx.notify(player, "Mandatory Fun! No talking. Only smiling.", "warn")
			return
		end
		for _, p in sameRoom(player) do
			ctx.Remotes.Bubble:FireClient(p, player.UserId, entry.text)
		end
	end)
	ctx.onAction("Ping", function(player, data)
		if not ctx.Shift.canAct(player) or typeof(data.position) ~= "Vector3" then
			return
		end
		local now = os.clock()
		if (lastPing[player] or 0) + 2 > now then
			return
		end
		lastPing[player] = now
		for _, p in ctx.Shift.crewPlayers() do
			ctx.Remotes.Ping:FireClient(p, { position = data.position, name = player.DisplayName, ghost = false, duration = 3 })
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastChat[player] = nil
		lastPing[player] = nil
	end)
end

return Chat
