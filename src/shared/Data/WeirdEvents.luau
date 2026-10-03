-- Weird events: the silly, disruptive (never scary) consequence of serving a Late Customer.
-- Design doc §7.6. "Serve a weird customer -> a funny problem."

local WeirdEvents = {}

WeirdEvents.ById = {
	EarRain = {
		name = "Ear Rain",
		duration = 25,
		banner = "EAR RAIN",
		description = "It's raining ears. Everyone wades through them slowly.",
	},
	Raccoons = {
		name = "Raccoon Infestation",
		duration = 40,
		banner = "RACCOONS!",
		description = "Raccoons are stealing food from the bags. Shoo them!",
	},
	MirrorMess = {
		name = "Mirror Mess",
		duration = 25,
		banner = "MIRROR MESS",
		description = "Left is right. Right is left. Good luck.",
	},
	GrabbyHands = {
		name = "Grabby Hands",
		duration = 25,
		banner = "GRABBY HANDS",
		description = "Tiny hands grabbed the topping bins. Shoo them off the board!",
	},
	GravityFries = {
		name = "Gravity Fries",
		duration = 12,
		banner = "GRAVITY FRIES",
		description = "All the fries float up to the ceiling. Make more.",
	},
	Doilies = {
		name = "Doilies",
		duration = 0, -- lasts the rest of the night, harmless
		banner = "DOILIES",
		description = "Everything gets a doily. Even the stars meter. Harmless. Deeply weird.",
	},
	GhostRider = {
		name = "Ghost Rider",
		duration = 30,
		banner = "GHOST RIDER",
		description = "An invisible 'helper' keeps bagging the wrong things.",
	},
	MandatoryFun = {
		name = "Mandatory Fun",
		duration = 15,
		banner = "SMILE! IT'S MANDATORY",
		description = "Everyone smiles. Everyone dances. Quick-chat is disabled.",
	},
	ChannelSurf = {
		name = "Channel Surf",
		duration = 30,
		banner = "CHANNEL SURF",
		description = "Tickets and the order screen turn to static.",
	},
	MascotMob = {
		name = "Mascot Mob",
		duration = 40,
		banner = "MASCOT MOB",
		description = "Knockoff Munches dance in the lane. The Lane Cam is useless.",
	},
	DoubleTrouble = {
		name = "Double Trouble",
		duration = 25,
		banner = "DOUBLE TROUBLE",
		description = "Everything you bag gets bagged twice. Bags overflow.",
	},
}

return WeirdEvents
