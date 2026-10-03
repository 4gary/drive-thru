-- Creates (server) or finds (client) every RemoteEvent / RemoteFunction the game uses.
--
-- Server -> Client events:
--   Notify(text, kind)            toast message
--   Radio(data)                   headset / CB radio line {who, text, duration}
--   Caption(data)                 captioned audio cue {text, pos?, duration?}
--   State(snapshot)               shift HUD snapshot
--   Effect(name, data)            client-side effect (lights, sounds, weird events, boop flash...)
--   OpenPanel(name, data)         open a UI panel
--   ClosePanel(name)              close a UI panel
--   Profile(summary)              saved progress summary for menus
--   Bubble(userId, text)          quick-chat bubble over a player
--   Ping(data)                    ping / ghost-point marker
--   LobbyState(data)              clock-in booths, rejoin info, lobby TV
-- Client -> Server events:
--   Action(name, data)            every gameplay input
-- Remote functions:
--   Request(name, data) -> result shop, codes, settings, rejoin, leaderboard

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local EVENTS = {
	"Notify",
	"Radio",
	"Caption",
	"State",
	"Effect",
	"OpenPanel",
	"ClosePanel",
	"Profile",
	"Bubble",
	"Ping",
	"LobbyState",
	"Action",
}
local FUNCTIONS = { "Request" }

local Net = {}

local folder: Folder
if RunService:IsServer() then
	local existing = ReplicatedStorage:FindFirstChild("Remotes")
	if existing and existing:IsA("Folder") then
		folder = existing
	else
		folder = Instance.new("Folder")
		folder.Name = "Remotes"
		folder.Parent = ReplicatedStorage
	end
	for _, name in EVENTS do
		if not folder:FindFirstChild(name) then
			local remote = Instance.new("RemoteEvent")
			remote.Name = name
			remote.Parent = folder
		end
	end
	for _, name in FUNCTIONS do
		if not folder:FindFirstChild(name) then
			local remote = Instance.new("RemoteFunction")
			remote.Name = name
			remote.Parent = folder
		end
	end
else
	folder = ReplicatedStorage:WaitForChild("Remotes") :: Folder
end

function Net.event(name: string): RemoteEvent
	return folder:WaitForChild(name) :: RemoteEvent
end

function Net.func(name: string): RemoteFunction
	return folder:WaitForChild(name) :: RemoteFunction
end

return Net
