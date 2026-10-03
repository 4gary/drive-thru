-- Night Shift: Drive-Thru — tuning knobs.
-- Everything a designer might want to tweak lives here. Values are in real seconds unless noted.

local Config = {}

---------------------------------------------------------------------------
-- Pacing profile
---------------------------------------------------------------------------
-- "Test"   = short nights (~6 real minutes) for quick playtesting.
-- "Design" = the design doc's target (~15 real minutes per night).
Config.Profile = "Test"

local SECONDS_PER_GAME_HOUR = { Test = 30, Design = 75 }
Config.SecondsPerGameHour = SECONDS_PER_GAME_HOUR[Config.Profile] or 30
-- Ratio vs. design length. Used to shrink "macro" timers (ghost respawn, scare spacing).
Config.TimeScale = Config.SecondsPerGameHour / 75

Config.NightStartMinute = 0 -- 6:00 PM
Config.NightEndMinute = 12 * 60 -- 6:00 AM (minutes after 6 PM)

Config.PreShiftSeconds = 25
Config.ReportSeconds = 60
Config.MaxCrew = 4

---------------------------------------------------------------------------
-- Hosting: "Auto" uses reserved shift servers when published, and runs the
-- shift in the same server (in-place) in Studio or when teleport fails.
---------------------------------------------------------------------------
Config.HostingMode = "Auto" -- "Auto" | "InPlace" | "Reserved"
Config.BoothCountdown = 15
Config.ReservedWaitForCrew = 20 -- seconds a shift server waits for the crew to arrive
Config.RejoinWindowSeconds = 30 * 60

---------------------------------------------------------------------------
-- Customers & lane
---------------------------------------------------------------------------
Config.CarSpeed = 16
Config.MaxCarsInLane = 6
Config.Patience = {
	Speaker = 45, -- waiting for someone to take the order
	Window = 75, -- waiting at the window for food
}
-- Seconds between car arrivals for a solo crew; divided by a crew-size factor.
Config.CarInterval = { 30, 27, 25, 23, 20 }
Config.RushMultiplier = 0.6 -- interval multiplier during rush hours
Config.CrewIntervalFactor = 0.3 -- each extra crew member speeds arrivals by 30%

---------------------------------------------------------------------------
-- Cooking
---------------------------------------------------------------------------
Config.Cook = {
	PattySideA = 4, -- seconds until "FLIP!"
	FlipWindow = 4, -- seconds to flip before it burns
	PattySideB = 3.5,
	DoneWindow = 7, -- seconds to take it before it burns
	GrillSpots = 4,

	FryTime = 6,
	FryDoneWindow = 7,
	FryFireAfter = 6, -- seconds after burning before a (comedic) fry fire
	FryPortions = 4,

	DrinkFillSeconds = 2.5,
	ShakeFillSeconds = 3.5,
	PerfectFillMin = 0.8,
	StickySeconds = 8,
	StickySpeed = 7,
}

---------------------------------------------------------------------------
-- Scoring
---------------------------------------------------------------------------
Config.Stars = {
	Start = 3,
	Max = 5,
	Perfect = 0.3,
	Okay = 0.1,
	WrongOrder = -0.4,
	RefusedNormal = -0.75,
	LeftAngry = -0.5,
	CaughtLate = 0.2,
}
Config.Weird = {
	ServedLate = 20,
	LateLeft = 5,
	OverflowResetTo = 50,
	WeirdLightsAt = 50,
	-- Passive growth over a full night, by night number.
	PassivePerNight = { 10, 15, 20, 25, 30 },
}

---------------------------------------------------------------------------
-- Scares
---------------------------------------------------------------------------
Config.GhostRespawnDesign = { 90, 90, 90, 75, 60 } -- design-length seconds, by night
Config.MinGhostRespawn = 15

Config.Scare = {
	WarningSeconds = { 5, 5, 5, 4, 3 },
	RushHourActive = 24, -- seconds Mr. Munch takes to walk his loop (Nights 3-4)
	RushHourActiveNight5 = 18,
	MinGapDesign = { 90, 90, 90, 90, 45 },
	MinGapFloor = 25,
	NoScareFirstDesign = 240,
	MaxPerNight = { 0, 0, 2, 3, 5 },
}

Config.Munch = {
	WalkSpeed = 9,
	ChaseSpeed = 19,
	Night5SpeedMultiplier = 1.35,
	ViewRange = 55,
	ViewAngle = 120, -- degrees, full cone
	HearRange = 7, -- sees you at any angle this close
	BoopDistance = 4.5,
	LoseSightSeconds = 1.5,
	KnockCheckRange = 11, -- Night 4+: checks hiding spots this close to his path (horizontal)
	KnockChance = 0.6,
}

Config.HighBeams = {
	SweepSeconds = 4.5,
	BeamWidth = 7,
	WindowLine = 4.4, -- head height (studs above floor) that the beam catches
	CrouchCampSeconds = 15,
}

Config.Hide = {
	CampWarnSeconds = 20,
	CampMaxSeconds = 32, -- long enough to hide through a whole Rush Hour, not a whole night
	RehideCooldown = 4,
	HoldBreathWindow = 6,
	HoldBreathHits = 3,
}

Config.Crouch = {
	HipHeightDrop = 1.6,
	WalkSpeed = 7,
}

---------------------------------------------------------------------------
-- Ghosts & Gizmo
---------------------------------------------------------------------------
Config.Ghost = {
	WalkSpeed = 20,
	PointCooldown = 8,
	PointDuration = 3,
	BooCooldown = 4,
}

Config.Gizmo = {
	SoloEfficiency = 0.6,
	CoverEfficiency = 0.3,
	MistakeChance = 0.08,
	MoveSpeed = 14,
}

---------------------------------------------------------------------------
-- Rewards
---------------------------------------------------------------------------
Config.Pay = {
	Base = 20,
	PerStar = 10,
	PerCatch = 5,
	PerPerfect = 2,
	GoldBonus = 25,
}

---------------------------------------------------------------------------
-- Persistence
---------------------------------------------------------------------------
Config.DataStoreName = "NightShift_v1"
Config.LeaderboardStoreName = "NightShift_LateCaught_v1"
Config.AutosaveSeconds = 120

---------------------------------------------------------------------------
-- Monetization (cosmetic only — see design doc §11.3). 0 = not configured.
-- Create the developer products / game pass on the Creator Dashboard and paste the IDs here.
---------------------------------------------------------------------------
Config.DevProducts = {
	hat_bun = 0,
	hat_tophat = 0,
	apron_neon = 0,
	ghost_gold = 0,
	ghost_ketchup = 0,
	trail_sparkle = 0,
}
Config.SupporterPassId = 0

-- Internal badge id -> Roblox BadgeService id. 0 = internal only (still tracked & shown in-game).
Config.RobloxBadgeIds = {}

---------------------------------------------------------------------------
-- Debug
---------------------------------------------------------------------------
-- The debug panel only ever appears in Studio.
Config.DebugPanelInStudio = true

---------------------------------------------------------------------------
-- Audio. Built-in Studio sounds are used as placeholders; swap in Creator Store
-- asset ids ("rbxassetid://123") for the real jingle, squeaks, sizzles, etc.
---------------------------------------------------------------------------
Config.Sounds = {
	Ding = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.5 },
	Note = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.35 },
	Squeak = { id = "rbxasset://sounds/action_footsteps_plastic.mp3", volume = 0.9, speed = 1.7 },
	Boop = { id = "rbxasset://sounds/action_jump.mp3", volume = 0.8, speed = 1.6 },
	Pwoomp = { id = "rbxasset://sounds/action_falling.mp3", volume = 0.5, speed = 1.4 },
	KaChunk = { id = "rbxasset://sounds/action_jump_land.mp3", volume = 0.9, speed = 0.8 },
	Shutter = { id = "rbxasset://sounds/action_jump_land.mp3", volume = 1, speed = 0.5 },
	Gotcha = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.6, speed = 0.5 },
	Sizzle = { id = "rbxasset://sounds/action_swim.mp3", volume = 0.25, speed = 2 },
	Splash = { id = "rbxasset://sounds/impact_water.mp3", volume = 0.5 },
	Engine = { id = "rbxasset://sounds/action_falling.mp3", volume = 0.7, speed = 0.4 },
	Knock = { id = "rbxasset://sounds/action_jump_land.mp3", volume = 1, speed = 1.2 },
	Click = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.2, speed = 2 },
}

return Config
