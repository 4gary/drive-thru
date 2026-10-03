-- Palettes for building normal-looking customers procedurally (design doc §5.1: "Base person" + "Car").

local People = {}

People.SkinTones = {
	Color3.fromRGB(255, 224, 189),
	Color3.fromRGB(241, 194, 125),
	Color3.fromRGB(224, 172, 105),
	Color3.fromRGB(198, 134, 66),
	Color3.fromRGB(161, 102, 50),
	Color3.fromRGB(120, 74, 40),
	Color3.fromRGB(92, 58, 34),
	Color3.fromRGB(255, 205, 160),
}

People.HairColors = {
	Color3.fromRGB(35, 25, 18),
	Color3.fromRGB(90, 58, 30),
	Color3.fromRGB(196, 156, 82),
	Color3.fromRGB(20, 20, 22),
	Color3.fromRGB(150, 50, 30),
	Color3.fromRGB(215, 215, 215),
	Color3.fromRGB(110, 80, 150),
}

People.HairStyles = { "Short", "Long", "Bun", "Bald", "Cap", "Curly", "Spiky", "Beanie" }

People.ShirtColors = {
	Color3.fromRGB(52, 101, 164),
	Color3.fromRGB(200, 60, 60),
	Color3.fromRGB(70, 150, 90),
	Color3.fromRGB(240, 200, 80),
	Color3.fromRGB(130, 90, 170),
	Color3.fromRGB(60, 60, 70),
	Color3.fromRGB(240, 240, 240),
	Color3.fromRGB(230, 130, 60),
	Color3.fromRGB(90, 190, 200),
	Color3.fromRGB(180, 120, 90),
}

People.CarKinds = { "Sedan", "Hatchback", "Pickup", "Minivan", "Convertible", "Compact" }

People.CarColors = {
	Color3.fromRGB(180, 40, 40),
	Color3.fromRGB(40, 80, 160),
	Color3.fromRGB(230, 230, 230),
	Color3.fromRGB(40, 40, 45),
	Color3.fromRGB(70, 140, 80),
	Color3.fromRGB(210, 170, 60),
	Color3.fromRGB(150, 150, 160),
	Color3.fromRGB(120, 60, 140),
	Color3.fromRGB(230, 120, 40),
	Color3.fromRGB(120, 180, 210),
}

People.FirstNames = {
	"Alex", "Jordan", "Sam", "Priya", "Marcus", "Lena", "Diego", "Aisha", "Ben", "Chloe",
	"Hiro", "Maya", "Omar", "Rosa", "Tyler", "Nina", "Kwame", "Ivy", "Luis", "Grace",
	"Theo", "Zoe", "Ravi", "Hana", "Caleb", "Sofia", "Malik", "Ella", "Jin", "Ruby",
	"Andre", "Mei", "Felix", "Tara", "Noah", "Leah", "Owen", "Amara", "Eli", "Jade",
}

People.Greetings = {
	"Hi! Can I get %s?",
	"Hey, uh, I'll have %s.",
	"Hello! Could I get %s, please?",
	"Yeah, hi. %s. That's it.",
	"Hiii. Lemme get %s.",
	"Good evening! %s, please.",
	"Okay okay okay. Um. %s?",
	"Can I just get %s? Thanks.",
}

People.Thanks = {
	"Thanks!",
	"You're a lifesaver.",
	"Smells amazing.",
	"Have a good night!",
	"Cool, thanks.",
	"Perfect. Bye!",
}

People.Complaints = {
	"This isn't what I ordered...",
	"Uh. Where's the rest of it?",
	"I'm leaving a review. A long one.",
	"Seriously?",
}

local function pick(list, rng)
	return list[rng:NextInteger(1, #list)]
end

-- A random normal-looking person + car.
function People.random(rng)
	return {
		skin = pick(People.SkinTones, rng),
		hairColor = pick(People.HairColors, rng),
		hairStyle = pick(People.HairStyles, rng),
		shirt = pick(People.ShirtColors, rng),
		glasses = rng:NextNumber() < 0.25,
		name = pick(People.FirstNames, rng),
		car = { kind = pick(People.CarKinds, rng), color = pick(People.CarColors, rng) },
	}
end

People.pick = pick

return People
