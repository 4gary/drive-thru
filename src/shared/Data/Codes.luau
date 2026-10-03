-- Fax machine codes (design doc §11.4). Codes are case-insensitive.
-- reward: { paychecks = n } and/or { cosmetic = "id" }. expires: optional os.time() cutoff.
-- Live-ops can add more without an update via the "LiveCodes" DataStore key (see Codes service).

return {
	OPENLATE = { reward = { paychecks = 100 }, message = "Welcome to Munchie's! +100 Paychecks" },
	OPENALWAYS = { reward = { paychecks = 50 }, message = "Open late. Open always. +50 Paychecks" },
	HOLDTHESEVEN = { reward = { cosmetic = "hat_paper_crown" }, message = "Gerald says hi. Paper Crown unlocked!" },
	FRYCOUNT = { reward = { paychecks = 75 }, message = "He only takes one. +75 Paychecks" },
}
