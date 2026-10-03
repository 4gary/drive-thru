-- Every world position the game uses, in one place. MapBuilder builds the greybox from these
-- numbers and the server systems (cars, scares, hiding, cameras) read the same numbers.
--
-- Axes: +X runs along the drive-thru lane (entrance -> exit). +Z points from the kitchen out to
-- the lane. The parking-lot lobby is behind the building (-Z). Ground top is y = 0.
--
-- This module must stay dependency-free (it is also loaded by Lune at build time).

local Layout = {}

Layout.Floor = 0.2 -- top of the interior floor tiles
Layout.WallHeight = 16

-- Building interior (kitchen + hallway + back rooms)
Layout.Building = { minX = -56, maxX = 56, minZ = -48, maxZ = 12 }
Layout.KitchenZ = { min = -14, max = 12 }
Layout.HallZ = { min = -22, max = -14 }
Layout.RoomZ = { min = -48, max = -22 }
Layout.KitchenDoorsX = { -40, 0, 40 }
Layout.DoorWidth = 8

Layout.Rooms = {
	Freezer = { minX = -56, maxX = -34 },
	Storage = { minX = -34, maxX = -12 },
	Office = { minX = -12, maxX = 10 },
	BreakRoom = { minX = 10, maxX = 34 },
	Bathroom = { minX = 34, maxX = 56 },
}
Layout.RoomOrder = { "Freezer", "Storage", "Office", "BreakRoom", "Bathroom" }

Layout.PlayPlace = { minX = -96, maxX = -56, minZ = -48, maxZ = 12 }
Layout.PlayPlaceDoorZ = -18

-- Front counter (stations) and back counter
Layout.FrontCounter = { minZ = 6.5, maxZ = 10.5, top = 3.6 }
Layout.BackCounter = { minZ = -13, maxZ = -10, top = 3.6 }

-- Stations (positions of the interactive parts)
Layout.Stations = {
	OrderConsole = Vector3.new(-46, 4.9, 8.5),
	ReceiptPrinter = Vector3.new(-40.5, 4.1, 8.5),
	Grill = Vector3.new(-26, 3.75, 8.5),
	GrillSpots = {
		Vector3.new(-30.5, 3.95, 8.5),
		Vector3.new(-27.5, 3.95, 8.5),
		Vector3.new(-24.5, 3.95, 8.5),
		Vector3.new(-21.5, 3.95, 8.5),
	},
	PattyBox = Vector3.new(-17.5, 4.1, 9),
	AssemblyPlate = Vector3.new(-10, 3.7, 8.2),
	Fryers = { Vector3.new(2.5, 3.9, 8.5), Vector3.new(8, 3.9, 8.5) },
	FryBin = Vector3.new(14, 4, 8.5),
	SodaFountain = Vector3.new(19.5, 4.6, 8.8),
	ShakeMachine = Vector3.new(24.5, 4.6, 8.8),
	BagCounter = Vector3.new(34, 4.0, 8.5),
	BagSpots = {
		Vector3.new(29.5, 4.4, 8.5),
		Vector3.new(32.5, 4.4, 8.5),
		Vector3.new(35.5, 4.4, 8.5),
		Vector3.new(38.5, 4.4, 8.5),
	},
	BagFix = Vector3.new(41.5, 4.0, 8.5),
	Window = Vector3.new(48, 4.6, 9.8),
	Trash = { Vector3.new(-2, 1.6, 3.5), Vector3.new(26.5, 1.6, 3.5) },
	TimeClock = Vector3.new(52, 4.6, -13.3),
	Bobblehead = Vector3.new(50.6, 4.1, 10.2),
	Napkin = Vector3.new(-3.5, 3.9, 9.5),
	Extinguisher = Vector3.new(-0.6, 1.8, 6.2),
}

-- Pickup window opening in the front wall
Layout.PickupWindow = { minX = 45, maxX = 51, minY = 3.4, maxY = 8.2 }
-- Front glass windows (High Beams shine through these). Bottom edge = the "window line".
Layout.FrontWindows = { minY = 4.4, maxY = 10 }

-- Respawn & spawn points
Layout.RespawnPoint = Vector3.new(52, Layout.Floor + 3, -9)
Layout.KitchenSpawns = {
	Vector3.new(-40, Layout.Floor + 3, 2),
	Vector3.new(-20, Layout.Floor + 3, 2),
	Vector3.new(6, Layout.Floor + 3, 2),
	Vector3.new(34, Layout.Floor + 3, 2),
}
Layout.LobbySpawn = Vector3.new(0, 3, -100)
Layout.GizmoHome = Vector3.new(6, Layout.Floor, -6)
Layout.GizmoNapkin = Vector3.new(-3.5, Layout.Floor, 4.5)

-- Drive-thru lane
Layout.LaneZ = 19.5
Layout.LaneStartX = -170
Layout.LaneEndX = 190
Layout.Slots = {
	{ name = "Window", x = 47 },
	{ name = "Hold1", x = 31 },
	{ name = "Hold2", x = 15 },
	{ name = "Hold3", x = -1 },
	{ name = "Speaker", x = -25 },
	{ name = "Queue1", x = -42 },
	{ name = "Queue2", x = -59 },
}
Layout.WindowSlot = 1
Layout.SpeakerSlot = 5
Layout.DriverOffset = Vector3.new(0.9, 0, -1.5) -- driver seat relative to the car root
Layout.SpeakerPost = Vector3.new(-24, 0, 15.2)
Layout.MenuBoard = Vector3.new(-31.5, 0, 15.6)

-- Cameras (CFrame.lookAt(from, to))
Layout.Cameras = {
	Window = { from = Vector3.new(48, 5.6, 8.6), to = Vector3.new(48.5, 4.6, 18.5), fov = 55 },
	LaneCam = { from = Vector3.new(22, 16, 33), to = Vector3.new(42, 2.5, 19), fov = 60 },
	Mirror = { from = Vector3.new(56, 8.5, 14.2), to = Vector3.new(47.5, 4.2, 18.6), fov = 50 },
	Order = { from = Vector3.new(-46, 6.5, 2.5), to = Vector3.new(-46, 4.6, 9), fov = 60 },
}
Layout.LaneCamPole = Vector3.new(22, 0, 34)
Layout.MirrorPole = Vector3.new(56, 0, 14.2)

-- Hiding spots: prompt = where the HIDE prompt is, inside = where the hidden player is parked,
-- peekFrom/peekTo = the peephole camera.
Layout.HidingSpots = {
	UnderCounter = {
		label = "Under the Counter",
		capacity = 1,
		prompt = Vector3.new(-14.5, 1.7, 6.2),
		inside = Vector3.new(-14.5, 1.4, 8.5),
		peekFrom = Vector3.new(-14.5, 1.9, 6.0),
		peekTo = Vector3.new(-14.5, 3.2, -6),
		message = "Your knees are not happy about this.",
	},
	Freezer = {
		label = "Walk-in Freezer",
		capacity = 2,
		prompt = Vector3.new(-45, 4, -21.4),
		inside = Vector3.new(-45, 3.2, -36),
		peekFrom = Vector3.new(-45, 5.6, -22.6),
		peekTo = Vector3.new(-45, 4.2, -10),
		message = "Brr. They don't like the cold.",
		campMessage = "Frost is creeping over the glass...",
	},
	CostumeCloset = {
		label = "Costume Closet",
		capacity = 1,
		prompt = Vector3.new(-29, 4, -44.2),
		inside = Vector3.new(-29, 3.2, -46.6),
		peekFrom = Vector3.new(-29, 5.2, -44.6),
		peekTo = Vector3.new(-23, 4, -24),
		message = "It smells like a mascot in here.",
		campMessage = "The Mr. Munch costume is... breathing?",
	},
	BathroomStall = {
		label = "Bathroom Stall",
		capacity = 1,
		prompt = Vector3.new(50, 4, -38.4),
		inside = Vector3.new(50, 3.2, -43),
		peekFrom = Vector3.new(50, 5.2, -38.8),
		peekTo = Vector3.new(45, 4, -22),
		message = "Occupied.",
		campMessage = "The Air-Freshener-Bot is warming up...",
	},
	BallPit = {
		label = "Ball Pit",
		capacity = 3,
		prompt = Vector3.new(-80, 2.6, -21.6),
		inside = Vector3.new(-80, 0.8, -30),
		peekFrom = Vector3.new(-80, 2.3, -29),
		peekTo = Vector3.new(-70, 4, -5),
		message = "You sink into the balls. It's fine. It's fine.",
		campMessage = "The ball pit is eating your shoe.",
	},
}
Layout.HidingOrder = { "UnderCounter", "Freezer", "CostumeCloset", "BathroomStall", "BallPit" }

-- Mr. Munch
Layout.StatuePosition = Vector3.new(-76, Layout.Floor, -2)
Layout.StatueFacing = Vector3.new(-56, Layout.Floor, -2)
Layout.MunchPath = {
	Vector3.new(-76, Layout.Floor, -2),
	Vector3.new(-72, Layout.Floor, -18),
	Vector3.new(-56, Layout.Floor, -18),
	Vector3.new(-40, Layout.Floor, -18),
	Vector3.new(-40, Layout.Floor, -10),
	Vector3.new(-36, Layout.Floor, 1),
	Vector3.new(-18, Layout.Floor, 2),
	Vector3.new(0, Layout.Floor, 1),
	Vector3.new(18, Layout.Floor, 2),
	Vector3.new(38, Layout.Floor, 1),
	Vector3.new(46, Layout.Floor, 3),
	Vector3.new(40, Layout.Floor, -8),
	Vector3.new(40, Layout.Floor, -18),
	Vector3.new(22, Layout.Floor, -18),
	Vector3.new(0, Layout.Floor, -18),
	Vector3.new(-23, Layout.Floor, -18),
	Vector3.new(-45, Layout.Floor, -18),
	Vector3.new(-60, Layout.Floor, -18),
	Vector3.new(-72, Layout.Floor, -10),
	Vector3.new(-76, Layout.Floor, -2),
}
-- Night 5 reveal: the statue appears outside the pickup window.
Layout.StatueAtWindow = Vector3.new(48, 0, 15.5)

-- High Beams sweep through the kitchen along X
Layout.HighBeams = { fromX = -60, toX = 60 }

-- Break room: Employee of the Month wall (13 frames on the back wall)
Layout.EmployeeWall = { centerX = 22, z = -47.4, y = 7.5, spacing = 1.75 }
Layout.VHS = Vector3.new(-6, 4.2, -44)
Layout.DebDesk = Vector3.new(-1, 0, -40)

-- Lobby (parking lot behind the building)
Layout.Lobby = {
	minX = -80,
	maxX = 80,
	minZ = -155,
	maxZ = -58,
	Booths = {
		{ id = "A", position = Vector3.new(-22, 0, -82) },
		{ id = "B", position = Vector3.new(22, 0, -82) },
	},
	BoothSize = 12,
	Locker = Vector3.new(-55, 0, -115),
	Fax = Vector3.new(55, 0, -112),
	Leaderboard = Vector3.new(-18, 0, -146),
	LobbyTV = Vector3.new(18, 0, -146),
	CreditsWall = Vector3.new(62, 0, -140),
	EmployeeSign = Vector3.new(0, 0, -64),
	FieldGuide = Vector3.new(-55, 0, -85),
}

-- Road & scenery
Layout.RoadZ = 70
Layout.SignPole = Vector3.new(80, 0, 40)
Layout.WaterTower = Vector3.new(170, 0, 170)

return Layout
