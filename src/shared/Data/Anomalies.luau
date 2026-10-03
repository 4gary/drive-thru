-- Late Customers (anomalies). Design doc §5.1–5.2 and §10.4 (Field Guide cards).
--
-- Each entry is data only; ModelFactory reads `modifiers`, the Window/Mirror/Lane Cam/Receipt/UV
-- views read `mirrorTell`, `receipt`, and the UV/Cam modifiers. Adding an anomaly = adding a row.
--
-- Fields
--   minNight        first night it can show up at random
--   photo           (†) a former employee: their "usual" frees them on Night 5 after the reveal
--   person / car    overrides for the generated person and car
--   modifiers       visual tells built onto the model (see ModelFactory.applyModifiers)
--   mirrorTell      what the convex mirror shows ("LateWave", "MunchReflection", "Crying", ...)
--   speaker         lines heard at the order station; `captions` are background-sound tells
--   order           what they actually order (lines)
--   receipt         receipt overrides (name / total / note)
--   weirdEvent      what happens if you serve them

local Anomalies = {}

Anomalies.List = {
	{
		id = "EarlOfEars",
		number = 1,
		name = "Earl of Ears",
		minNight = 1,
		danger = 0,
		look = "Tall guy in a bowling shirt",
		photo = {
			employee = "Marv",
			year = 1991,
			job = "Night Grill",
			usual = { { item = "munchstack", mods = { "NoPickles", "ExtraSauce" } } },
			usualText = "#4, no pickles, extra sauce.",
		},
		person = {
			skin = Color3.fromRGB(224, 172, 105),
			hairStyle = "Bald",
			shirt = Color3.fromRGB(40, 160, 160),
			name = "Earl",
		},
		car = { kind = "Sedan", color = Color3.fromRGB(110, 90, 160) },
		modifiers = { "ExtraEars", "UVTag:MARV" },
		tells = {
			{ channel = "Window", text = "Three ears. Two on one side." },
			{ channel = "UV", text = "A name tag that says MARV under his coat." },
		},
		speaker = {
			"Good evening. One hamburger per ear, please.",
			"...For balance.",
		},
		captions = {},
		order = { { item = "burger" }, { item = "burger" }, { item = "burger" } },
		receipt = { name = "EARL", note = "3x for balance" },
		refusedLine = "*tips his hat. With an ear.* Very well.",
		servedLine = "Splendid. All three of us thank you.",
		weirdEvent = "EarRain",
		debNote = "Nice guy. Do not serve. Do not count ears out loud.",
		freedLine = "...It's me. Marv. Night grill, '91. Thank you. Tell Deb I said hi.",
	},
	{
		id = "TotallyNormalFamily",
		number = 2,
		name = "The Totally Normal Family",
		minNight = 1,
		danger = 0,
		look = "A trench coat with three heads stacked on top",
		person = { shirt = Color3.fromRGB(120, 100, 70), name = "Dad" },
		car = { kind = "Minivan", color = Color3.fromRGB(150, 140, 120) },
		modifiers = { "TrenchStack" },
		tells = {
			{ channel = "Window", text = "Three faces, stacked. One trench coat." },
			{ channel = "Speaker", text = "Three voices. One of them chitters." },
			{ channel = "LaneCam", text = "On camera it's one very tall guy." },
		},
		speaker = {
			"Four kids' meals for my four normal children. Yes.",
			"(a second, higher voice) We are children.",
			"(a third voice, from lower down) ...chitter.",
		},
		captions = { "[three voices — one is chittering]" },
		order = { { item = "fries" }, { item = "fries" }, { item = "fries" }, { item = "fries" } },
		receipt = { name = "NORMAL FAMILY", note = "4 KIDS (NORMAL)" },
		refusedLine = "*The trench coat falls over. Three raccoons run out.*",
		servedLine = "Thank you. We will eat this. As humans.",
		weirdEvent = "Raccoons",
		debNote = "Not a family. Three raccoons. Don't feed them, they come back.",
	},
	{
		id = "MirrorMandy",
		number = 3,
		name = "Mirror Mandy",
		minNight = 2,
		danger = 1,
		look = "Cheerful woman in a convertible",
		photo = {
			employee = "Mandy",
			year = 1996,
			job = "Window",
			usual = { { item = "cheeseburger", mods = { "ExtraCheese" } }, { item = "shake" } },
			usualText = "#2 with extra cheese and a #6.",
		},
		person = {
			skin = Color3.fromRGB(255, 224, 189),
			hairStyle = "Long",
			hairColor = Color3.fromRGB(196, 156, 82),
			shirt = Color3.fromRGB(240, 130, 170),
			name = "Mandy",
		},
		car = { kind = "Convertible", color = Color3.fromRGB(240, 240, 235) },
		modifiers = {},
		mirrorTell = "LateWave",
		tells = {
			{ channel = "Mirror", text = "Her reflection is waving. She isn't." },
		},
		speaker = {
			"Hiii! I'll have whatever I had last time.",
			"You remember.",
		},
		captions = {},
		order = { { item = "cheeseburger", mods = { "ExtraCheese" } }, { item = "shake" } },
		receipt = { name = "MANDY", note = "\"you remember\"" },
		refusedLine = "Oh. Okay! *Her reflection stays parked after she leaves.*",
		servedLine = "You DID remember!",
		weirdEvent = "MirrorMess",
		debNote = "Always check the mirror. Mandy's reflection runs late.",
		freedLine = "Mandy. Window, '96. ...You really did remember. Thank you.",
	},
	{
		id = "SirFingersALot",
		number = 4,
		name = "Sir Fingers-a-Lot",
		minNight = 2,
		danger = 0,
		look = "A businessman with a briefcase",
		person = {
			hairStyle = "Short",
			shirt = Color3.fromRGB(60, 60, 70),
			name = "Sir",
		},
		car = { kind = "Sedan", color = Color3.fromRGB(40, 40, 45) },
		modifiers = { "SevenFingers" },
		tells = {
			{ channel = "Window", text = "Seven fingers on one hand. The count changes." },
		},
		speaker = {
			"A burger and a drink. I'll pay in... exact change.",
		},
		captions = {},
		order = { { item = "burger" }, { item = "drink" } },
		receipt = { name = "SIR", note = "PAID: 13 PENNIES + 1 TOOTH-SHAPED MINT" },
		refusedLine = "*Waves goodbye. Waves. Waves. Still waving.*",
		servedLine = "*counts out pennies with far too many fingers*",
		weirdEvent = "GrabbyHands",
		debNote = "Count the fingers. Then count them again.",
	},
	{
		id = "UpsideDownOrder",
		number = 5,
		name = "The Upside-Down Order",
		minNight = 2,
		danger = 0,
		look = "A normal teen in a sedan",
		person = {
			hairStyle = "Cap",
			shirt = Color3.fromRGB(70, 150, 90),
			name = "Teen",
		},
		car = { kind = "Hatchback", color = Color3.fromRGB(230, 120, 40) },
		modifiers = { "UpsideDownHat" },
		tells = {
			{ channel = "Speaker", text = "Orders the menu backwards." },
			{ channel = "Window", text = "Their cap is upside down." },
		},
		speaker = {
			"Eno regrub, owt seirf, dna eno knird.",
			"Sknaht!",
		},
		captions = { "[the words sound... backwards]" },
		order = { { item = "burger" }, { item = "fries" }, { item = "fries" }, { item = "drink" } },
		receipt = { name = "NEET", note = "LATOT" },
		refusedLine = "Ko. *The car reverses away. It keeps reversing.*",
		servedLine = "Uoy knaht!",
		weirdEvent = "GravityFries",
		debNote = "If you understood that order, you've been here too long.",
	},
	{
		id = "GrandmaGumdrop",
		number = 6,
		name = "Grandma Gumdrop",
		minNight = 3,
		danger = 0,
		look = "Sweet old lady in a tiny car",
		photo = {
			employee = "Dot",
			year = 1988,
			job = "Fry Cook",
			usual = { { item = "shake" }, { item = "fries" } },
			usualText = "A #6 and a #3. \"A little treat.\"",
		},
		person = {
			skin = Color3.fromRGB(241, 194, 125),
			hairStyle = "Bun",
			hairColor = Color3.fromRGB(215, 215, 215),
			shirt = Color3.fromRGB(130, 90, 170),
			glasses = true,
			name = "Dot",
		},
		car = { kind = "Compact", color = Color3.fromRGB(120, 180, 210) },
		modifiers = { "NoShadowCam", "LipstickHI", "UVHandprints" },
		tells = {
			{ channel = "LaneCam", text = "Every car has a shadow on camera. Hers doesn't." },
			{ channel = "Window", text = "Lipstick on her teeth spells HI." },
			{ channel = "UV", text = "Handprints inside the windshield." },
		},
		speaker = {
			"Is Bartholomew working tonight? Tell him Dot says hello.",
			"And a little shake and some fries, dear.",
		},
		captions = {},
		order = { { item = "shake" }, { item = "fries" } },
		receipt = { name = "DOT", note = "tell bart hello" },
		refusedLine = "Oh. Tell him anyway, dear.",
		servedLine = "Such a nice young person. Bart would be proud.",
		weirdEvent = "Doilies",
		debNote = "Sweetest lady. No shadow. Do not serve.",
		freedLine = "Dot. Fryer, '88. Tell Bart... no. Don't tell Bart anything. Thank you, dear.",
	},
	{
		id = "DriverlessDelivery",
		number = 7,
		name = "The Driver-less Delivery",
		minNight = 3,
		danger = 1,
		look = "A delivery scooter. Nobody on it.",
		person = { name = "Pickup" },
		car = { kind = "Scooter", color = Color3.fromRGB(200, 60, 60) },
		modifiers = { "NoDriver" },
		tells = {
			{ channel = "Window", text = "Nobody's there. The speaker still orders." },
		},
		speaker = {
			"Order for... pickup.",
			"One Munch Stack. For... pickup.",
		},
		captions = { "[no engine sound]" },
		order = { { item = "munchstack" } },
		receipt = { name = "PICKUP", note = "LEAVE AT WINDOW" },
		refusedLine = "*The scooter tips over. Sadly.*",
		servedLine = "*The bag floats up off the window ledge and drives away.*",
		weirdEvent = "GhostRider",
		debNote = "If nobody's driving, nobody's eating. Refuse.",
	},
	{
		id = "SmileySteve",
		number = 8,
		name = "Smiley Steve",
		minNight = 3,
		danger = 1,
		look = "Guy with a huge grin",
		photo = {
			employee = "Steve",
			year = 2003,
			job = "Order Taker",
			usual = { { item = "burger", mods = { "NoLettuce" } }, { item = "drink" } },
			usualText = "#1, no lettuce. And a #5.",
		},
		person = {
			skin = Color3.fromRGB(198, 134, 66),
			hairStyle = "Spiky",
			hairColor = Color3.fromRGB(35, 25, 18),
			shirt = Color3.fromRGB(240, 200, 80),
			name = "Steve",
		},
		car = { kind = "Pickup", color = Color3.fromRGB(210, 170, 60) },
		modifiers = { "NeverBlinks", "GrowingSmile", "CamPaintedFace" },
		tells = {
			{ channel = "Window", text = "Never blinks. The smile gets wider when you look away." },
			{ channel = "LaneCam", text = "On camera his face is painted on, like a mascot." },
		},
		speaker = {
			"Smile! It's mandatory!",
			"Two cheeseburgers! Smile!",
		},
		captions = {},
		order = { { item = "cheeseburger" }, { item = "cheeseburger" } },
		receipt = { name = "STEVE :)", note = "SMILING IS MANDATORY" },
		refusedLine = "*The smile drops to a normal frown.* ...Ok.",
		servedLine = "SMILE!",
		weirdEvent = "MandatoryFun",
		debNote = "Corporate made that poster. Steve took it personally.",
		freedLine = "Steve. Order taker, '03. I can stop smiling now. ...Thanks.",
	},
	{
		id = "StaticStan",
		number = 9,
		name = "Static Stan",
		minNight = 4,
		danger = 0,
		look = "A man made of slightly TV-static skin",
		person = { name = "Stan", shirt = Color3.fromRGB(150, 150, 160), hairStyle = "Short" },
		car = { kind = "Sedan", color = Color3.fromRGB(150, 150, 160) },
		modifiers = { "StaticSkin" },
		tells = {
			{ channel = "Receipt", text = "The receipt prints STAN STAN STAN." },
			{ channel = "Speaker", text = "The speaker crackles every time he talks." },
			{ channel = "Window", text = "His skin is... fuzzy." },
		},
		speaker = {
			"Bzzzt. Large fries. Bzzt.",
		},
		captions = { "[heavy static]" },
		order = { { item = "fries" } },
		receipt = { name = "STAN STAN STAN", note = "STAN STAN STAN STAN" },
		refusedLine = "*He changes channel and becomes a weatherman.* ...Clear skies tonight.",
		servedLine = "Bzzzt. Thank bzzzt you.",
		weirdEvent = "ChannelSurf",
		debNote = "Check receipts. Stan can't help printing himself.",
	},
	{
		id = "MrNotMunch",
		number = 10,
		name = "Mr. Not-Munch",
		minNight = 4,
		danger = 1,
		look = "A guy in a cheap knockoff Mr. Munch costume",
		person = { name = "Mascot", shirt = Color3.fromRGB(200, 40, 40) },
		car = { kind = "Sedan", color = Color3.fromRGB(200, 40, 40) },
		modifiers = { "KnockoffMunch" },
		mirrorTell = "MunchReflection",
		tells = {
			{ channel = "Window", text = "Five-fingered gloves. The real Mr. Munch has four." },
			{ channel = "Mirror", text = "His reflection is the REAL Mr. Munch." },
		},
		speaker = {
			"I am the mascot. I would like a mascot meal.",
			"(A Munch Stack, fries, and a shake. Mascot-style.)",
		},
		captions = {},
		order = { { item = "munchstack" }, { item = "fries" }, { item = "shake" } },
		receipt = { name = "MR MUNCH", note = "OFFICIAL MASCOT (REAL)" },
		refusedLine = "*Takes off the head. It's Trucker Ray?? No... another costume underneath.*",
		servedLine = "The mascot thanks you. Officially.",
		weirdEvent = "MascotMob",
		debNote = "Count the fingers on the gloves. FOUR. Always four.",
	},
	{
		id = "TheTwins",
		number = 11,
		name = "The Twins",
		minNight = 4,
		danger = 1,
		look = "Two identical kids in one booster seat",
		photo = {
			employee = "Jo & Mo",
			year = 2008,
			job = "Baggers",
			usual = { { item = "shake" }, { item = "shake" }, { item = "fries" } },
			usualText = "Two #6s and one #3. We share.",
		},
		person = {
			skin = Color3.fromRGB(161, 102, 50),
			hairStyle = "Curly",
			hairColor = Color3.fromRGB(20, 20, 22),
			shirt = Color3.fromRGB(90, 190, 200),
			name = "Jo",
		},
		car = { kind = "Hatchback", color = Color3.fromRGB(70, 140, 80) },
		modifiers = { "Twins", "UVText:TELL DEB" },
		tells = {
			{ channel = "Speaker", text = "They speak in perfect unison... except once." },
			{ channel = "UV", text = "TELL DEB is written on the car door." },
		},
		speaker = {
			"We want what we wanted.",
			"We want what we wan-ted.",
		},
		captions = { "[two voices in unison — then one is a beat late]" },
		order = { { item = "shake" }, { item = "shake" }, { item = "fries" } },
		receipt = { name = "JO & MO", note = "WE WANT WHAT WE WANTED" },
		refusedLine = "*They both wave. With the same hand.*",
		servedLine = "Thank you. Thank you.",
		weirdEvent = "DoubleTrouble",
		debNote = "Two kids, one booster seat, zero parents. Refuse.",
		freedLine = "Jo and Mo. Baggers, '08. We can go home now. We can go home now.",
	},
}

Anomalies.ById = {}
for _, entry in Anomalies.List do
	Anomalies.ById[entry.id] = entry
end

function Anomalies.photoEmployees()
	local out = {}
	for _, entry in Anomalies.List do
		if entry.photo then
			table.insert(out, entry)
		end
	end
	return out
end

return Anomalies
