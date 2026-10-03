-- Latest server snapshots for the UI: the shift HUD state, the saved profile and the lobby.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local Signal = require(Shared.Signal)

local State = {}

State.shift = nil :: any
State.profile = nil :: any
State.lobby = nil :: any
State.ShiftChanged = Signal.new()
State.ProfileChanged = Signal.new()
State.LobbyChanged = Signal.new()
State.flags = {} :: { [string]: any } -- client-side effect flags (ChannelSurf, MascotMob, ...)

local player = Players.LocalPlayer

function State.isCrew(): boolean
	return player:GetAttribute("Crew") ~= nil
end

function State.isGhost(): boolean
	return player:GetAttribute("Ghost") == true
end

function State.isHidden(): boolean
	return player:GetAttribute("Hidden") ~= nil
end

function State.setting(name: string): any
	local profile = State.profile
	if profile and profile.settings then
		return profile.settings[name]
	end
	if name == "captions" then
		return true
	end
	return false
end

function State.action(name: string, data: any?)
	Net.event("Action"):FireServer(name, data or {})
end

function State.request(name: string, data: any?): any
	local ok, result = pcall(function()
		return Net.func("Request"):InvokeServer(name, data or {})
	end)
	if ok then
		return result or {}
	end
	return { ok = false, message = "Couldn't reach the server." }
end

function State.init()
	Net.event("State").OnClientEvent:Connect(function(snapshot)
		State.shift = snapshot
		State.ShiftChanged:Fire(snapshot)
	end)
	Net.event("Profile").OnClientEvent:Connect(function(profile)
		State.profile = profile
		State.ProfileChanged:Fire(profile)
	end)
	Net.event("LobbyState").OnClientEvent:Connect(function(lobby)
		State.lobby = lobby
		State.LobbyChanged:Fire(lobby)
	end)
	task.spawn(function()
		local profile = State.request("GetProfile")
		if profile and profile.paychecks ~= nil then
			State.profile = profile
			State.ProfileChanged:Fire(profile)
		end
	end)
end

return State
