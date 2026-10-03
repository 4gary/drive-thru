-- Recurring regulars and special customers (design doc §4.3). These are NOT Late Customers:
-- refusing them costs stars. (The Hendersons are the decoy everyone wants to refuse.)

local Regulars = {}

Regulars.ById = {
	Tutorial = {
		id = "Tutorial",
		name = "First Customer",
		person = {
			skin = Color3.fromRGB(241, 194, 125),
			hairStyle = "Short",
			hairColor = Color3.fromRGB(90, 58, 30),
			shirt = Color3.fromRGB(52, 101, 164),
			name = "Jamie",
		},
		car = { kind = "Hatchback", color = Color3.fromRGB(40, 80, 160) },
		speaker = { "Hi, uh, can I get a cheeseburger, fries, and a drink?", "Thanks! First night?" },
		order = { { item = "cheeseburger" }, { item = "fries" }, { item = "drink" } },
		patienceBonus = 600,
		servedLine = "Perfect! Have a good shift!",
		refusedLine = "...Rude.",
	},
	Gerald = {
		id = "Gerald",
		name = "Gerald Puddingston",
		person = {
			skin = Color3.fromRGB(255, 224, 189),
			hairStyle = "Bald",
			shirt = Color3.fromRGB(180, 160, 120),
			glasses = true,
			name = "Gerald",
		},
		car = { kind = "Buick", color = Color3.fromRGB(214, 196, 150) },
		speaker = {
			"Evening, young person. Number Seven, hold the seven.",
			"You know, Doris and I used to come here when it opened. 1987. She said the fries tasted like forever.",
		},
		speakerByNight = {
			[5] = {
				".neves eht dloh ,neveS rebmuN .nosrep gnuoy ,gninevE",
				".reverof ekil detsat seirf eht dias ehS .7891 .denepo ti nehw ereh emoc ot desu I dna siroD ,wonk uoY",
			},
		},
		captions = {},
		order = {}, -- there is no #7. An empty bag is exactly what he wants.
		alwaysHappy = true,
		receipt = { name = "GERALD", note = "#7 (HOLD THE 7)" },
		servedLine = "Perfect. Just how Doris liked it.",
		refusedLine = "Oh. Well. Same time tomorrow, then.",
	},
	OfficerBrisket = {
		id = "OfficerBrisket",
		name = "Officer Linda Brisket",
		person = {
			skin = Color3.fromRGB(120, 74, 40),
			hairStyle = "Bun",
			hairColor = Color3.fromRGB(20, 20, 22),
			shirt = Color3.fromRGB(30, 40, 80),
			name = "Linda",
		},
		car = { kind = "Police", color = Color3.fromRGB(240, 240, 240) },
		speaker = {
			"Black coffee. And one for my partner.",
			"Hey, kid. If a car comes through with no driver? Don't. Let. It. In.",
		},
		speakerByNight = {
			[4] = { "Two coffees. Me and my partner.", "Keep your heads down tonight, kids. I mean it." },
			[5] = { "Two coffees.", "...They're all lined up out there tonight. All of 'em. Stay inside." },
		},
		captions = { "[the passenger seat is empty]" },
		order = { { item = "drink" }, { item = "drink" } },
		receipt = { name = "OFC BRISKET", note = "1 FOR PARTNER" },
		servedLine = "Thanks, kid. Stay sharp.",
		refusedLine = "...Refusing a cop coffee? Bold.",
	},
	Hendersons = {
		id = "Hendersons",
		name = "The Hendersons",
		person = {
			skin = Color3.fromRGB(224, 172, 105),
			hairStyle = "Long",
			hairColor = Color3.fromRGB(150, 50, 30),
			shirt = Color3.fromRGB(70, 150, 90),
			name = "Mrs. Henderson",
		},
		car = { kind = "Minivan", color = Color3.fromRGB(70, 110, 160) },
		kidsByNight = { 3, 4, 6, 9, 9 },
		decoy = true,
		patienceBonus = 30,
		captions = { "[a LOT of kids in the background]" },
		receipt = { name = "HENDERSON", note = "KIDS MEALS" },
		servedLine = "Say thank you, kids! (THANK YOUUU)",
		servedLineByNight = { [5] = "(every kid, in perfect unison) THANK. YOU." },
		refusedLine = "*Mrs. Henderson leaves a 1-star review. Out loud.* ONE. STAR.",
	},
	KarenBot = {
		id = "KarenBot",
		name = "Karen-Bot",
		person = { name = "K-4R3N", shirt = Color3.fromRGB(150, 150, 160) },
		car = { kind = "Sedan", color = Color3.fromRGB(200, 200, 210) },
		modifiers = { "Robot" },
		difficulty = "Custom",
		bonusStars = 0.3,
		speakerPrefix = "MYSTERY SHOPPER UNIT K-4R3N. I WILL RATE YOUR SERVICE. I REQUIRE: ",
		captions = { "[servo noises]" },
		receipt = { name = "K-4R3N", note = "MYSTERY SHOPPER" },
		servedLine = "SERVICE RATING: FIVE STARS. TIP DISPENSED.",
		wrongLine = "SERVICE RATING: UNACCEPTABLE. I WILL BE SPEAKING TO A MANAGER.",
		refusedLine = "REFUSAL LOGGED. MANAGER NOTIFIED. HAVE A PLEASANT NIGHT.",
		gizmoLine = "GIZMO: ...she's here. act natural. ACT NATURAL.",
	},
	CastGuy = {
		id = "CastGuy",
		name = "Guy With a Cast",
		person = { hairStyle = "Short", shirt = Color3.fromRGB(230, 130, 60), name = "Dale" },
		car = { kind = "Pickup", color = Color3.fromRGB(70, 140, 80) },
		modifiers = { "Cast" },
		decoy = true,
		speaker = { "Uh, a cheeseburger and a drink. Sorry, hand's in a cast. Skateboarding." },
		captions = {},
		order = { { item = "cheeseburger" }, { item = "drink" } },
		receipt = { name = "DALE", note = "" },
		servedLine = "Thanks. Don't skateboard, kids.",
		refusedLine = "Because of the CAST?",
	},
	SpookyPriya = {
		id = "SpookyPriya",
		name = "SpookyPriya",
		onFoot = true,
		special = true,
		person = {
			skin = Color3.fromRGB(161, 102, 50),
			hairStyle = "Long",
			hairColor = Color3.fromRGB(20, 20, 22),
			shirt = Color3.fromRGB(110, 80, 150),
			name = "Priya",
		},
		car = { kind = "None" },
		speaker = {},
		order = {},
		windowLines = {
			"Hi!! I'm Priya, I'm LIVE right now, say hi chat!",
			"Can I use your bathroom? No? Okay. Here — you need this more than me.",
			"(She hands over a UV flashlight.) Point it at anything weird. Chat, this guy's SO bad at fries.",
		},
		servedLine = "Stay spooky!",
		refusedLine = "Fine, keep the flashlight anyway. Stay spooky!",
	},
}

function Regulars.hendersonKids(night: number): number
	local list = Regulars.ById.Hendersons.kidsByNight
	return list[math.clamp(night, 1, #list)]
end

return Regulars
