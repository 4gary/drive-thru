-- Story text: the Employee of the Month wall, VHS tapes, endings, posters (design doc §3).

local Story = {}

-- Thirteen frames, 1987 to now. Photo-employees have a UV-only usual on the back.
Story.WallPhotos = {
	{ name = "Bart M.", year = 1987, job = "Founder", note = "Gerald is in the background." },
	{ name = "Dot", year = 1988, job = "Fry Cook", anomaly = "GrandmaGumdrop" },
	{ name = "Marv", year = 1991, job = "Night Grill", anomaly = "EarlOfEars" },
	{ name = "Lou", year = 1993, job = "Window" },
	{ name = "Mandy", year = 1996, job = "Window", anomaly = "MirrorMandy" },
	{ name = "Ray Jr.", year = 1999, job = "Lot" },
	{ name = "Steve", year = 2003, job = "Order Taker", anomaly = "SmileySteve" },
	{ name = "Jo & Mo", year = 2008, job = "Baggers", anomaly = "TheTwins" },
	{ name = "Kelly", year = 2012, job = "Shakes" },
	{ name = "Dev", year = 2017, job = "Fryer" },
	{ name = "Toby", year = 2026, job = "Trainee", showFromNight = 3 },
	{ name = "Deb", year = 2026, job = "Night Manager", showFromNight = 5 },
	{ name = "YOU?", year = nil, job = "", empty = true },
}

Story.VHSTapes = {
	{
		title = "TRAINING TAPE #1 — THE ALWAYS OPEN PROMISE (1987)",
		lines = {
			"[A man in a red tuxedo smiles too hard at the camera.]",
			"BART: Welcome to the Munchie's family! I'm Bart Munch.",
			"BART: Back in '87, this store was about to close. Then a very special customer pulled up to the speaker.",
			"BART: We made a deal. This store will never go out of business...",
			"BART: ...as long as it never, ever closes.",
			"BART: That's the Always Open Promise! Smile! It's mandatory!",
			"[The tape skips. For one frame, Bart is not smiling.]",
		},
	},
}

Story.Posters = {
	Normal = { "SMILING IS MANDATORY", "THE FREEZER IS NOT A NAP ROOM", "WASH HANDS. WASH THEM AGAIN." },
	Revealed = { "STAYING IS MANDATORY", "THE FREEZER IS NOT AN EXIT", "CLOCK IN. NEVER OUT." },
}

Story.Reveal = {
	"The power dies. Emergency lights only.",
	"The Munchie's jingle plays from every speaker at once. Slightly out of sync.",
	"Use the UV flashlight on the Employee of the Month wall. There's writing on the back of the photos.",
}

Story.Endings = {
	Company = {
		title = "EMPLOYEE OF THE MONTH",
		badge = "ending_company",
		lines = {
			"You refused them all. Just like the binder said.",
			"At 6 AM a laminated envelope slides out of the fax machine.",
			"Inside: shiny gold name tags. One for each of you.",
			"Mr. Munch gives everyone a hug. His gloves are very, very cold.",
			"On the Employee of the Month wall, four new photos. Smiling.",
			"",
			"The sign flickers: OPEN ALWAYS.",
		},
	},
	Freed = {
		title = "LAST CALL",
		badge = "ending_freed",
		lines = {
			"Dawn breaks over Exit 13.",
			"One by one, the cars in the lane turn back into ordinary old cars.",
			"Marv waves. Mandy waves. Her reflection waves too — on time.",
			"On the wall, the photos are just photos now.",
			"All except one.",
			"DEB: I'll hold the door. Come back for me.",
			"",
			"SECOND SHIFT — coming soon.",
		},
	},
	Fired = {
		title = "FIRED!",
		badge = "ending_fired",
		lines = {
			"The corporate hotline finally picks up.",
			"[smooth jazz]",
			"You are handed a cardboard box with your stuff in it,",
			"and a gift card for 1 (one) free small fry.",
			"",
			"Try Night 5 again?",
		},
	},
	Mascot = {
		title = "THE MASCOT",
		badge = "secret_mascot",
		lines = {
			"You hid inside the Mr. Munch costume during the Final Rush.",
			"It fits. It fits perfectly.",
			"For the rest of the night, the customers wave at you.",
			"Unlocked: Mr. Munch Head (cosmetic).",
		},
	},
}

Story.Credits = {
	"NIGHT SHIFT: DRIVE-THRU",
	"Design: Gary",
	"Greybox build: Claude Code",
	"Thank you for working the night shift.",
	"Open late. Open always.",
}

return Story
