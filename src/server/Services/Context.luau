-- Shared server context. Every service registers itself here (ctx.Shift, ctx.Stations, ...) so
-- services can call each other at runtime without circular requires.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local Signal = require(Shared.Signal)

local ctx: { [string]: any } = {}

ctx.Bus = Signal.bus()
ctx.Remotes = {
	Notify = Net.event("Notify"),
	Radio = Net.event("Radio"),
	Caption = Net.event("Caption"),
	State = Net.event("State"),
	Effect = Net.event("Effect"),
	OpenPanel = Net.event("OpenPanel"),
	ClosePanel = Net.event("ClosePanel"),
	Profile = Net.event("Profile"),
	Bubble = Net.event("Bubble"),
	Ping = Net.event("Ping"),
	LobbyState = Net.event("LobbyState"),
	Action = Net.event("Action"),
	Request = Net.func("Request"),
}

---------------------------------------------------------------------------
-- Client -> server dispatch with a simple per-player rate limit
---------------------------------------------------------------------------

local actionHandlers: { [string]: (Player, any) -> () } = {}
local requestHandlers: { [string]: (Player, any) -> any } = {}
local budget: { [Player]: { tokens: number, last: number } } = {}

local function allow(player: Player): boolean
	local now = os.clock()
	local b = budget[player]
	if not b then
		b = { tokens = 30, last = now }
		budget[player] = b
	end
	b.tokens = math.min(30, b.tokens + (now - b.last) * 15)
	b.last = now
	if b.tokens < 1 then
		return false
	end
	b.tokens -= 1
	return true
end

function ctx.onAction(name: string, handler: (Player, any) -> ())
	assert(not actionHandlers[name], "duplicate action " .. name)
	actionHandlers[name] = handler
end

function ctx.onRequest(name: string, handler: (Player, any) -> any)
	assert(not requestHandlers[name], "duplicate request " .. name)
	requestHandlers[name] = handler
end

ctx.Remotes.Action.OnServerEvent:Connect(function(player: Player, name: any, data: any)
	if type(name) ~= "string" or not allow(player) then
		return
	end
	local handler = actionHandlers[name]
	if handler then
		local ok, err = pcall(handler, player, if type(data) == "table" then data else {})
		if not ok then
			warn(("[Action %s] %s"):format(name, tostring(err)))
		end
	end
end)

ctx.Remotes.Request.OnServerInvoke = function(player: Player, name: any, data: any)
	if type(name) ~= "string" or not allow(player) then
		return { ok = false, message = "Slow down!" }
	end
	local handler = requestHandlers[name]
	if not handler then
		return { ok = false, message = "Unknown request" }
	end
	local ok, result = pcall(handler, player, if type(data) == "table" then data else {})
	if not ok then
		warn(("[Request %s] %s"):format(name, tostring(result)))
		return { ok = false, message = "Something went wrong." }
	end
	return result
end

Players.PlayerRemoving:Connect(function(player)
	budget[player] = nil
end)

---------------------------------------------------------------------------
-- Broadcast helpers
---------------------------------------------------------------------------

-- Players who should receive shift events (the crew), or everyone if no shift is running.
function ctx.audience(): { Player }
	if ctx.Shift and ctx.Shift.session then
		return ctx.Shift.crewPlayers()
	end
	return Players:GetPlayers()
end

local function each(players: { Player }?, fn: (Player) -> ())
	for _, p in players or ctx.audience() do
		if p.Parent == Players then
			fn(p)
		end
	end
end
ctx.each = each

function ctx.notify(player: Player, text: string, kind: string?)
	ctx.Remotes.Notify:FireClient(player, text, kind or "info")
end

function ctx.notifyCrew(text: string, kind: string?)
	each(nil, function(p)
		ctx.Remotes.Notify:FireClient(p, text, kind or "info")
	end)
end

-- Headset / CB radio line.
function ctx.radio(who: string, text: string, duration: number?)
	each(nil, function(p)
		ctx.Remotes.Radio:FireClient(p, { who = who, text = text, duration = duration or math.clamp(#text / 14, 3, 9) })
	end)
end

-- Captioned audio cue; `pos` lets clients show a direction ("— left").
function ctx.caption(text: string, pos: Vector3?, duration: number?)
	each(nil, function(p)
		ctx.Remotes.Caption:FireClient(p, { text = text, pos = pos, duration = duration or 3 })
	end)
end

function ctx.effect(name: string, data: any?, players: { Player }?)
	each(players, function(p)
		ctx.Remotes.Effect:FireClient(p, name, data or {})
	end)
end

function ctx.openPanel(player: Player, name: string, data: any?)
	ctx.Remotes.OpenPanel:FireClient(player, name, data or {})
end

function ctx.closePanel(player: Player, name: string)
	ctx.Remotes.ClosePanel:FireClient(player, name)
end

function ctx.sound(name: string, pos: Vector3?, players: { Player }?)
	ctx.effect("Sound", { name = name, pos = pos }, players)
end

function ctx.now(): number
	return os.clock()
end

return ctx
