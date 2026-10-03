-- The five-night campaign (design doc §3.4 and §10.2). Each night is a timeline the Shift Director
-- plays like a playlist. Times are in-game clock times ("03:00" = 3 AM).
--
-- Event kinds
--   radio     a line on the headset / CB radio      { who, text }
--   customer  a scripted car                         { id }  (anomaly id, regular id, "RandomLate", "Normal")
--   scare     a scare event                          { id, ifWeird? }  ("RushHour", "HighBeams", "LightsOutSafe")
--   beat      a story moment handled by Story        { id, param? }
--   note      a sticky note pops up on screen        { text }

local Nights = {}

Nights.List = {
	{
		number = 1,
		title = "Welcome to the Team!",
		stickyNote = "Fryer is fine.\nTake orders at the CRT.\nREFUSE anyone weird. (Big red button.)\n— Deb",
		intro = {
			"Welcome to Munchie's. I'm Deb, night manager. I'm sorry in advance.",
			"I'll be on your headset. Toby's here too. He's... in training.",
		},
		outro = "Great job. Don't look at the PlayPlace.",
		tutorial = true,
		debOnHeadset = true,
		lateChance = 0.12,
		latePool = { "EarlOfEars", "TotallyNormalFamily" },
		difficulty = { Normal = 0.85, Picky = 0.15, Custom = 0 },
		randomFrom = "20:00",
		scenery = { "Balloons" },
		events = {
			{ t = "18:00", kind = "customer", id = "Tutorial" },
			{ t = "19:30", kind = "customer", id = "EarlOfEars" },
			{ t = "22:00", kind = "radio", who = "Toby", text = "The fryer is hot! ...The fryer is HOT." },
			{ t = "23:00", kind = "customer", id = "Hendersons" },
			{ t = "01:00", kind = "customer", id = "TotallyNormalFamily" },
			{ t = "02:30", kind = "radio", who = "Deb", text = "If the bobblehead moves, it didn't." },
			{ t = "04:44", kind = "beat", id = "Bobblehead", param = "Player" },
		},
	},
	{
		number = 2,
		title = "The Regulars",
		stickyNote = "New: check the side MIRROR on the window screen.\nThe regulars are fine. Mostly.\nThe Hendersons are NORMAL. I checked.\n— Deb",
		intro = {
			"Night two. You came back! Nobody comes back.",
			"Tonight you meet the regulars. Be nice to Gerald.",
		},
		outro = "See? Nothing happened. ...This time. Same time tomorrow.",
		debOnHeadset = true,
		lateChance = 0.18,
		latePool = { "EarlOfEars", "TotallyNormalFamily", "SirFingersALot", "UpsideDownOrder" },
		difficulty = { Normal = 0.7, Picky = 0.3, Custom = 0 },
		randomFrom = "18:30",
		scenery = { "SafetyPoster", "PlayPlaceDark" },
		events = {
			{ t = "19:30", kind = "customer", id = "MirrorMandy" },
			{ t = "21:00", kind = "customer", id = "Gerald" },
			{ t = "23:00", kind = "customer", id = "OfficerBrisket" },
			{ t = "00:30", kind = "customer", id = "Hendersons" },
			{
				t = "02:00",
				kind = "radio",
				who = "Trucker Ray",
				text = "Breaker breaker, Munchie's. Ray here. Y'all know you're sittin' on the Thin Lane, right? Road that ain't quite here.",
			},
			{
				t = "02:05",
				kind = "radio",
				who = "Trucker Ray",
				text = "Some folks pull off it hungry. And the moon? Fake. Bigger than they say. Ray out.",
			},
			{ t = "04:30", kind = "scare", id = "LightsOutSafe" },
		},
	},
	{
		number = 3,
		title = "Mr. Munch Is Here for Inspection",
		stickyNote = "CORPORATE MEMO:\nMr. Munch will be visiting your store.\n\nIf the lights flicker: HIDE.\nFreezer, under the counter, ball pit, closet, bathroom.\n— Deb",
		intro = {
			"Corporate says Mr. Munch is 'visiting' tonight. Probably a guy in a suit. Be nice.",
			"If the lights flicker three times... just hide. Hide now, cry later.",
		},
		outro = "Weird night. Same time tomorrow?",
		debOnHeadset = true,
		lateChance = 0.22,
		latePool = { "EarlOfEars", "TotallyNormalFamily", "SirFingersALot", "UpsideDownOrder", "MirrorMandy", "GrandmaGumdrop", "DriverlessDelivery" },
		difficulty = { Normal = 0.6, Picky = 0.3, Custom = 0.1 },
		randomFrom = "18:30",
		scenery = { "VisitBanner", "GoldStars", "TobyPhoto" },
		events = {
			{ t = "19:00", kind = "customer", id = "SmileySteve" },
			{ t = "21:00", kind = "customer", id = "Gerald" },
			{ t = "22:30", kind = "beat", id = "PlayPlaceLight" },
			{ t = "23:15", kind = "customer", id = "Hendersons" },
			{ t = "00:00", kind = "beat", id = "StatueGone" },
			{ t = "01:00", kind = "customer", id = "RandomLate" },
			{ t = "01:10", kind = "customer", id = "RandomLate" },
			{
				t = "02:00",
				kind = "radio",
				who = "Trucker Ray",
				text = "You got the mascot tonight? Hide in the cold. They don't like the cold.",
			},
			{ t = "03:00", kind = "scare", id = "RushHour" },
			{ t = "04:44", kind = "beat", id = "Bobblehead", param = "Freezer" },
			{ t = "05:00", kind = "scare", id = "RushHour", ifWeird = 60 },
		},
	},
	{
		number = 4,
		title = "Where's Deb?",
		stickyNote = "DON'T REFUSE GERALD.\nTHE PHOTOS.\nFryer is fine??\nKeep heads DOWN if a car has its brights on.",
		intro = {},
		outro = "(A sticky note on the time clock:) If you're reading this, go home. Come back tomorrow. Bring the flashlight. — D",
		debOnHeadset = false,
		lateChance = 0.28,
		latePool = {
			"EarlOfEars",
			"TotallyNormalFamily",
			"SirFingersALot",
			"UpsideDownOrder",
			"MirrorMandy",
			"GrandmaGumdrop",
			"DriverlessDelivery",
			"SmileySteve",
			"StaticStan",
			"MrNotMunch",
		},
		difficulty = { Normal = 0.5, Picky = 0.35, Custom = 0.15 },
		randomFrom = "18:30",
		scenery = { "OfficeEmpty", "StickyNotes", "Fog", "TobyPhoto", "VHS" },
		events = {
			{ t = "18:00", kind = "radio", who = "Headset", text = "[static] ...Deb? ...Deb's headset is just static." },
			{ t = "19:00", kind = "customer", id = "Hendersons" },
			{ t = "20:00", kind = "customer", id = "TheTwins" },
			{ t = "21:00", kind = "customer", id = "Gerald" },
			{ t = "22:00", kind = "customer", id = "StaticStan" },
			{ t = "23:00", kind = "customer", id = "CastGuy" },
			{ t = "00:30", kind = "customer", id = "SpookyPriya" },
			{ t = "01:00", kind = "customer", id = "MrNotMunch" },
			{
				t = "01:50",
				kind = "radio",
				who = "Officer Brisket",
				text = "Dispatch to Munchie's. Car with its brights on, NO driver, headed your way. Keep your heads DOWN, kids.",
			},
			{ t = "02:00", kind = "scare", id = "HighBeams" },
			{ t = "03:30", kind = "scare", id = "RushHour" },
			{ t = "04:00", kind = "radio", who = "Speaker", text = "[whispering, from the drive-thru speaker] Clock out. Clock OUT." },
			{ t = "05:00", kind = "scare", id = "HighBeams", ifWeird = 60 },
		},
	},
	{
		number = 5,
		title = "Closing Time",
		stickyNote = "Serve the ones in the photos.\nThe real order is on the back.\n(UV.)\n— Deb",
		intro = {},
		outro = "",
		debOnHeadset = false,
		finale = true,
		lateChance = 0.3,
		latePool = {
			"TotallyNormalFamily",
			"SirFingersALot",
			"UpsideDownOrder",
			"DriverlessDelivery",
			"StaticStan",
			"MrNotMunch",
		},
		difficulty = { Normal = 0.45, Picky = 0.35, Custom = 0.2 },
		randomFrom = "18:30",
		scenery = { "Rain", "OpenAlways", "DebPhoto", "TobyPhoto", "VHS" },
		events = {
			{ t = "18:00", kind = "radio", who = "Headset", text = "[static]" },
			{ t = "18:30", kind = "customer", id = "Hendersons" },
			{ t = "19:30", kind = "customer", id = "Gerald" },
			{ t = "21:00", kind = "customer", id = "OfficerBrisket" },
			{ t = "22:00", kind = "scare", id = "HighBeams" },
			{ t = "23:00", kind = "scare", id = "RushHour" },
			{
				t = "00:00",
				kind = "radio",
				who = "Trucker Ray",
				text = "Ray here. Lane's real crowded tonight, Munchie's. Real crowded. Good luck, kids.",
			},
			{ t = "01:00", kind = "beat", id = "Reveal" },
			{ t = "01:20", kind = "customer", id = "EarlOfEars" },
			{ t = "01:50", kind = "customer", id = "MirrorMandy" },
			{ t = "02:30", kind = "customer", id = "GrandmaGumdrop" },
			{ t = "03:00", kind = "scare", id = "HighBeams" },
			{ t = "03:15", kind = "customer", id = "SmileySteve" },
			{ t = "04:00", kind = "beat", id = "FinalRush" },
			{ t = "04:10", kind = "customer", id = "TheTwins" },
		},
	},
}

function Nights.get(n: number)
	return Nights.List[math.clamp(n, 1, #Nights.List)]
end

Nights.Count = #Nights.List

return Nights
