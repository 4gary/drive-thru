-- In-game badges (design doc §7.7: "Badges: 60+ at launch"; MVP target 30).
-- These are always tracked in the player's save. Map an id to a real Roblox badge in
-- Config.RobloxBadgeIds to also award it through BadgeService.

local Badges = {}

Badges.List = {
	{ id = "clocked_in", name = "Clocked In", desc = "Start your first shift." },
	{ id = "night1", name = "Welcome to the Team", desc = "Survive Night 1." },
	{ id = "night2", name = "A Regular", desc = "Survive Night 2." },
	{ id = "night3", name = "Passed Inspection", desc = "Survive Night 3." },
	{ id = "night4", name = "Where's Deb?", desc = "Survive Night 4." },
	{ id = "night5", name = "Closing Time", desc = "Finish Night 5." },
	{ id = "gotcha", name = "GOTCHA!", desc = "Refuse your first Late Customer." },
	{ id = "refused_raccoon", name = "Refused a Raccoon", desc = "Refuse the Totally Normal Family." },
	{ id = "served_late", name = "The Customer Is Always Right?", desc = "Serve a Late Customer." },
	{ id = "booped", name = "Booped by Mr. Munch", desc = "Get booped by Mr. Munch." },
	{ id = "deer", name = "Deer in Headlights", desc = "Get caught by the High Beams." },
	{ id = "untouchable", name = "Never Hid, Never Booped", desc = "Finish Night 3+ without hiding or getting booped." },
	{ id = "hendersons9", name = "Nine Kids' Meals", desc = "Serve the Hendersons all 9 kids' meals." },
	{ id = "not_anomalies", name = "NOT Anomalies!", desc = "Refuse the Hendersons. (They were normal.)" },
	{ id = "hold_the_seven", name = "Number Seven, Hold the Seven", desc = "Serve Gerald exactly what he ordered." },
	{ id = "perfect", name = "Order Up!", desc = "Serve a perfect order." },
	{ id = "perfect10", name = "Short-Order Legend", desc = "10 perfect orders in one night." },
	{ id = "gold", name = "Employee Badge: Gold", desc = "Earn a Gold badge on any night." },
	{ id = "all_gold", name = "Golden Visor", desc = "Earn Gold on all five nights." },
	{ id = "ghost_point", name = "Helpful Haunt", desc = "Ghost Point at something." },
	{ id = "ghost_boo", name = "oooOOOooo", desc = "Boo! as a Shift Ghost." },
	{ id = "spook_gizmo", name = "Spooked the Robot", desc = "Boo! near Gizmo." },
	{ id = "held_breath", name = "Hold Your Breath", desc = "Pass Mr. Munch's hiding-spot check." },
	{ id = "freezer", name = "They Don't Like the Cold", desc = "Hide in the freezer during Rush Hour." },
	{ id = "uv", name = "Black Light", desc = "Use the UV flashlight." },
	{ id = "vhs", name = "Be Kind, Rewind", desc = "Watch a VHS training tape." },
	{ id = "freed", name = "Last Call", desc = "Free a photo-employee with their usual." },
	{ id = "ending_company", name = "Employee of the Month", desc = "See the Company ending." },
	{ id = "ending_freed", name = "Clocked Out", desc = "See the Last Call ending." },
	{ id = "ending_fired", name = "Fired!", desc = "Get fired on Night 5." },
	{ id = "secret_mascot", name = "The Mascot", desc = "???" },
	{ id = "ghost_town", name = "Ghost Town", desc = "The whole crew got booped at once." },
	{ id = "field_guide10", name = "Field Researcher", desc = "Collect 10 Field Guide cards." },
	{ id = "well_done", name = "Well Done. Too Well.", desc = "Burn 3 patties in one night." },
	{ id = "this_is_fine", name = "This Is Fine", desc = "Put out a fry fire." },
	{ id = "sticky", name = "Sticky Situation", desc = "Overflow a drink." },
	{ id = "fax", name = "Fax Machine Operator", desc = "Redeem a code." },
	{ id = "peak_weird", name = "Peak Weird", desc = "The Weird Meter hit 100%." },
	{ id = "perfect_raccoon", name = "Perfect Burger for a Raccoon", desc = "Make a perfect order for a Late Customer, then refuse them." },
}

Badges.ById = {}
for _, badge in Badges.List do
	Badges.ById[badge.id] = badge
end

return Badges
