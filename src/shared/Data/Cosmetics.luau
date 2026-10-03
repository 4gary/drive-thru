-- Locker room cosmetics (design doc §7.7, §11.3). Cosmetic only — never stats, never revives.
-- price  = Paychecks (soft currency). robux = sold as a developer product (ids in Config.DevProducts).
-- default = everyone owns it. secret = unlocked by an ending / pass, not for sale.

local Cosmetics = {}

Cosmetics.Slots = { "Hat", "Apron", "Ghost", "Tag", "Trail" }

Cosmetics.List = {
	-- Hats
	{ id = "hat_visor_red", slot = "Hat", name = "Ketchup Visor", default = true, color = Color3.fromRGB(215, 38, 61), style = "Visor" },
	{ id = "hat_visor_mustard", slot = "Hat", name = "Mustard Visor", price = 50, color = Color3.fromRGB(244, 180, 0), style = "Visor" },
	{ id = "hat_visor_pickle", slot = "Hat", name = "Pickle Visor", price = 50, color = Color3.fromRGB(106, 153, 78), style = "Visor" },
	{ id = "hat_paper_crown", slot = "Hat", name = "Paper Crown", price = 120, color = Color3.fromRGB(255, 214, 92), style = "Crown" },
	{ id = "hat_trucker", slot = "Hat", name = "Ray's Trucker Cap", price = 150, color = Color3.fromRGB(40, 80, 160), style = "Cap" },
	{ id = "hat_bun", slot = "Hat", name = "Burger Bun Hat", robux = "hat_bun", color = Color3.fromRGB(222, 170, 98), style = "Bun" },
	{ id = "hat_tophat", slot = "Hat", name = "Tiny Top Hat & Monocle", robux = "hat_tophat", color = Color3.fromRGB(25, 25, 25), style = "TopHat" },
	{ id = "hat_munch", slot = "Hat", name = "Mr. Munch Head", secret = true, hint = "Find 'The Mascot' secret ending.", color = Color3.fromRGB(214, 140, 69), style = "MunchHead" },
	-- Aprons (uniform)
	{ id = "apron_red", slot = "Apron", name = "Classic Apron", default = true, color = Color3.fromRGB(215, 38, 61) },
	{ id = "apron_mustard", slot = "Apron", name = "Mustard Apron", price = 80, color = Color3.fromRGB(244, 180, 0) },
	{ id = "apron_pickle", slot = "Apron", name = "Pickle Apron", price = 80, color = Color3.fromRGB(106, 153, 78) },
	{ id = "apron_midnight", slot = "Apron", name = "Midnight Apron", price = 150, color = Color3.fromRGB(29, 45, 80) },
	{ id = "apron_neon", slot = "Apron", name = "Neon Sign Apron", robux = "apron_neon", color = Color3.fromRGB(255, 60, 200), neon = true },
	-- Shift Ghost skins
	{ id = "ghost_white", slot = "Ghost", name = "Plain Sheet", default = true, color = Color3.fromRGB(245, 245, 255) },
	{ id = "ghost_mint", slot = "Ghost", name = "Mint Sheet", price = 100, color = Color3.fromRGB(170, 240, 210) },
	{ id = "ghost_pink", slot = "Ghost", name = "Strawberry Sheet", price = 100, color = Color3.fromRGB(255, 185, 215) },
	{ id = "ghost_midnight", slot = "Ghost", name = "Midnight Sheet", price = 150, color = Color3.fromRGB(70, 80, 140) },
	{ id = "ghost_gold", slot = "Ghost", name = "Gold Foil Sheet", robux = "ghost_gold", color = Color3.fromRGB(255, 200, 60) },
	{ id = "ghost_ketchup", slot = "Ghost", name = "Ketchup Packet", robux = "ghost_ketchup", color = Color3.fromRGB(215, 38, 61) },
	-- Name tags
	{ id = "tag_white", slot = "Tag", name = "Name Tag", default = true, color = Color3.fromRGB(245, 245, 245) },
	{ id = "tag_gold", slot = "Tag", name = "Golden Name Tag", secret = true, hint = "Supporter Pass.", color = Color3.fromRGB(255, 200, 60) },
	-- Ghost trails
	{ id = "trail_none", slot = "Trail", name = "No Trail", default = true },
	{ id = "trail_sparkle", slot = "Trail", name = "Sparkle Trail", robux = "trail_sparkle", color = Color3.fromRGB(255, 240, 150) },
}

Cosmetics.ById = {}
for _, item in Cosmetics.List do
	Cosmetics.ById[item.id] = item
end

function Cosmetics.defaults(): { [string]: string }
	local equipped = {}
	for _, item in Cosmetics.List do
		if item.default and not equipped[item.slot] then
			equipped[item.slot] = item.id
		end
	end
	return equipped
end

return Cosmetics
