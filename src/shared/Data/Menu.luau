-- The Munchie's menu. Six items, numbered #1–#6 (there is no #7, no matter what Gerald says).
-- Burgers are physical stacks built bottom-to-top at the assembly board.

local Menu = {}

Menu.Items = {
	burger = {
		id = "burger",
		number = 1,
		name = "Munch Burger",
		short = "Burger",
		singular = "burger",
		plural = "burgers",
		kind = "Burger",
		price = 3.49,
		stack = { "BunBottom", "Patty", "Lettuce", "BunTop" },
		color = Color3.fromRGB(214, 140, 69),
	},
	cheeseburger = {
		id = "cheeseburger",
		number = 2,
		name = "Cheeseburger",
		short = "Cheese",
		singular = "cheeseburger",
		plural = "cheeseburgers",
		kind = "Burger",
		price = 3.99,
		stack = { "BunBottom", "Patty", "Cheese", "BunTop" },
		color = Color3.fromRGB(245, 196, 66),
	},
	fries = {
		id = "fries",
		number = 3,
		name = "Fries",
		short = "Fries",
		singular = "fries",
		plural = "fries",
		kind = "Fries",
		price = 1.99,
		color = Color3.fromRGB(255, 214, 92),
	},
	munchstack = {
		id = "munchstack",
		number = 4,
		name = "Munch Stack",
		short = "Stack",
		singular = "Munch Stack",
		plural = "Munch Stacks",
		kind = "Burger",
		price = 5.99,
		stack = { "BunBottom", "Patty", "Cheese", "Patty", "Pickles", "Sauce", "BunTop" },
		color = Color3.fromRGB(201, 64, 52),
	},
	drink = {
		id = "drink",
		number = 5,
		name = "Drink",
		short = "Drink",
		singular = "drink",
		plural = "drinks",
		kind = "Drink",
		price = 1.49,
		color = Color3.fromRGB(77, 160, 230),
	},
	shake = {
		id = "shake",
		number = 6,
		name = "Shake",
		short = "Shake",
		singular = "shake",
		plural = "shakes",
		kind = "Shake",
		price = 2.99,
		color = Color3.fromRGB(240, 150, 190),
	},
}

Menu.Order = { "burger", "cheeseburger", "fries", "munchstack", "drink", "shake" }

Menu.Toppings = {
	BunBottom = { label = "Bottom Bun", color = Color3.fromRGB(222, 170, 98), height = 0.45 },
	BunTop = { label = "Top Bun", color = Color3.fromRGB(230, 176, 100), height = 0.7 },
	Patty = { label = "Patty", color = Color3.fromRGB(110, 62, 35), height = 0.4 },
	Cheese = { label = "Cheese", color = Color3.fromRGB(255, 205, 40), height = 0.12 },
	Lettuce = { label = "Lettuce", color = Color3.fromRGB(110, 190, 70), height = 0.15 },
	Pickles = { label = "Pickles", color = Color3.fromRGB(80, 130, 50), height = 0.12 },
	Sauce = { label = "Sauce", color = Color3.fromRGB(220, 50, 40), height = 0.08 },
}

-- Buttons shown at the assembly board, in order.
Menu.ToppingButtons = { "Bun", "Patty", "Cheese", "Lettuce", "Pickles", "Sauce" }

Menu.Mods = {
	NoCheese = { label = "No Cheese", spoken = "no cheese", kind = "remove", topping = "Cheese" },
	NoLettuce = { label = "No Lettuce", spoken = "no lettuce", kind = "remove", topping = "Lettuce" },
	NoPickles = { label = "No Pickles", spoken = "no pickles", kind = "remove", topping = "Pickles" },
	NoSauce = { label = "No Sauce", spoken = "no sauce", kind = "remove", topping = "Sauce" },
	ExtraCheese = { label = "Extra Cheese", spoken = "extra cheese", kind = "extra", topping = "Cheese" },
	ExtraLettuce = { label = "Extra Lettuce", spoken = "extra lettuce", kind = "extra", topping = "Lettuce" },
	ExtraPickles = { label = "Extra Pickles", spoken = "extra pickles", kind = "extra", topping = "Pickles" },
	ExtraSauce = { label = "Extra Sauce", spoken = "extra sauce", kind = "extra", topping = "Sauce" },
}

-- Canonical order mods are applied / listed in.
Menu.ModOrder = {
	"NoCheese",
	"NoLettuce",
	"NoPickles",
	"NoSauce",
	"ExtraCheese",
	"ExtraLettuce",
	"ExtraPickles",
	"ExtraSauce",
}

return Menu
