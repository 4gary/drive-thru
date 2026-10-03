-- Awards in-game badges (always saved) and, when configured, real Roblox badges.

local BadgeService = game:GetService("BadgeService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local BadgeData = require(Shared.Data.Badges)
local ctx = require(script.Parent.Context)

local Badges = {}

function Badges.award(player: Player, badgeId: string)
	if not BadgeData.ById[badgeId] then
		warn("[Badges] unknown badge " .. badgeId)
		return
	end
	if not ctx.PlayerData.markBadge(player, badgeId) then
		return
	end
	local badge = BadgeData.ById[badgeId]
	ctx.Remotes.Notify:FireClient(player, "🏅 Badge: " .. badge.name, "badge")
	local robloxId = Config.RobloxBadgeIds[badgeId]
	if robloxId and robloxId ~= 0 then
		task.spawn(function()
			pcall(function()
				BadgeService:AwardBadge(player.UserId, robloxId)
			end)
		end)
	end
end

function Badges.awardCrew(badgeId: string)
	for _, p in ctx.Shift.crewPlayers() do
		Badges.award(p, badgeId)
	end
end

function Badges.init() end

return Badges
