-- Lobby menus: Locker (cosmetics shop), Fax (codes), Field Guide (anomaly trading cards, badges,
-- endings) and Settings (reduced flashing, captions, Fast Start).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Cosmetics = require(Shared.Data.Cosmetics)
local Anomalies = require(Shared.Data.Anomalies)
local BadgeData = require(Shared.Data.Badges)
local WeirdEvents = require(Shared.Data.WeirdEvents)
local StoryData = require(Shared.Data.Story)
local Kit = require(script.Parent.Parent.UI.Kit)
local State = require(script.Parent.State)
local Panels = require(script.Parent.Panels)

local T = Kit.Theme

local MenuPanels = {}

local function toast(text: string, kind: string?)
	local HUD = require(script.Parent.HUD) :: any
	HUD.toast(text, kind)
end

---------------------------------------------------------------------------
-- Locker
---------------------------------------------------------------------------

local Locker = {}
do
	local layer: Frame
	local grid: ScrollingFrame
	local balance: TextLabel
	local slot = "Hat"
	local tabs: { [string]: TextButton } = {}

	local function render()
		local profile = State.profile
		if not layer or not layer.Visible or not profile then
			return
		end
		balance.Text = ("💵 %d Paychecks"):format(profile.paychecks or 0)
		for name, button in tabs do
			button.BackgroundColor3 = if name == slot then T.ketchup else T.panelLight
		end
		Kit.clear(grid)
		for i, item in Cosmetics.List do
			if item.slot ~= slot then
				continue
			end
			local owned = profile.owned and profile.owned[item.id]
			local equipped = profile.equipped and profile.equipped[item.slot] == item.id
			local card = Kit.new("Frame", { BackgroundColor3 = T.panelLight, LayoutOrder = i, Parent = grid })
			Kit.corner(card, 12)
			if item.color then
				local swatch = Kit.new("Frame", { Position = UDim2.fromOffset(10, 10), Size = UDim2.new(1, -20, 0, 50), BackgroundColor3 = item.color, Parent = card })
				Kit.corner(swatch, 10)
			end
			Kit.label(card, item.name, { Position = UDim2.fromOffset(8, 66), Size = UDim2.new(1, -16, 0, 40), Font = T.bold, MaxText = 18 })
			local text, color, enabled
			if equipped then
				text, color, enabled = "EQUIPPED", T.good, false
			elseif owned then
				text, color, enabled = "EQUIP", T.navy, true
			elseif item.price then
				text, color, enabled = ("BUY  💵%d"):format(item.price), T.mustard, true
			elseif item.robux then
				text, color, enabled = "BUY (Robux)", T.ketchup, true
			else
				text, color, enabled = item.hint or "LOCKED", T.ink, false
			end
			Kit.button(card, text, color, function()
				if not enabled then
					return
				end
				local result
				if owned then
					result = State.request("Equip", { id = item.id })
				else
					result = State.request("BuyCosmetic", { id = item.id })
					if result.ok and not result.prompted then
						State.request("Equip", { id = item.id })
					end
				end
				if result.message then
					toast(result.message, if result.ok then "good" else "bad")
				end
			end, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -8), Size = UDim2.new(1, -16, 0, 44), TextColor3 = if color == T.mustard then T.ink else T.white })
		end
	end

	function Locker.open()
		if not layer then
			local created = Panels.layer("Locker", 0.4)
			layer = created
			local _, content = Kit.panel(created, "LOCKER ROOM", UDim2.fromOffset(980, 580), function()
				Panels.close("Locker")
			end)
			balance = Kit.label(content, "", { Size = UDim2.new(1, 0, 0, 34), Font = T.title, TextColor3 = T.good, TextXAlignment = Enum.TextXAlignment.Left, MaxText = 24 })
			local tabRow = Kit.new("Frame", { Position = UDim2.fromOffset(0, 40), Size = UDim2.new(1, 0, 0, 48), BackgroundTransparency = 1, Parent = content })
			Kit.list(tabRow, Enum.FillDirection.Horizontal, 8)
			local labels = { Hat = "HATS", Apron = "APRONS", Ghost = "GHOST SKINS", Tag = "NAME TAGS", Trail = "TRAILS" }
			for i, name in Cosmetics.Slots do
				tabs[name] = Kit.button(tabRow, labels[name] or name, T.panelLight, function()
					slot = name
					render()
				end, { Size = UDim2.fromOffset(170, 46), LayoutOrder = i })
			end
			grid = Kit.scroll(content, { Position = UDim2.fromOffset(0, 96), Size = UDim2.new(1, 0, 1, -160) })
			Kit.new("UIGridLayout", { CellSize = UDim2.fromOffset(220, 170), CellPadding = UDim2.fromOffset(10, 10), Parent = grid })
			Kit.button(content, "⭐ SUPPORTER PASS (golden name tag)", T.mustard, function()
				local result = State.request("BuySupporter")
				if result.message then
					toast(result.message, if result.ok then "good" else "bad")
				end
			end, { AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.fromOffset(420, 54), TextColor3 = T.ink })
			Kit.label(content, "Cosmetic only. Never revives, never stats, never mid-shift.", { AnchorPoint = Vector2.new(1, 1), Position = UDim2.fromScale(1, 1), Size = UDim2.fromOffset(480, 54), TextColor3 = T.muted, MaxText = 15 })
			State.ProfileChanged:Connect(render)
		end
		layer.Visible = true
		render()
	end
	function Locker.close()
		if layer then
			layer.Visible = false
		end
	end
end

---------------------------------------------------------------------------
-- Fax (codes)
---------------------------------------------------------------------------

local Fax = {}
do
	local layer: Frame
	local box: TextBox
	local result: TextLabel
	function Fax.open()
		if not layer then
			local created = Panels.layer("Fax", 0.4)
			layer = created
			local _, content = Kit.panel(created, "CORPORATE FAX — ENTER CODE", UDim2.fromOffset(620, 320), function()
				Panels.close("Fax")
			end)
			box = Kit.new("TextBox", {
				Size = UDim2.new(1, 0, 0, 64),
				BackgroundColor3 = T.paper,
				TextColor3 = T.ink,
				PlaceholderText = "TYPE A CODE",
				Font = T.mono,
				TextScaled = true,
				ClearTextOnFocus = false,
				Text = "",
				Parent = content,
			})
			Kit.corner(box, 10)
			result = Kit.label(content, "", { Position = UDim2.fromOffset(0, 74), Size = UDim2.new(1, 0, 0, 50), Font = T.bold, MaxText = 20 })
			Kit.button(content, "SEND FAX 📠", T.good, function()
				local response = State.request("RedeemCode", { code = box.Text })
				result.Text = response.message or ""
				result.TextColor3 = if response.ok then T.good else T.bad
			end, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 1), Size = UDim2.fromOffset(260, 60) })
		end
		box.Text = ""
		result.Text = "Codes come in updates, on the group page... and sometimes on sticky notes."
		result.TextColor3 = T.muted
		layer.Visible = true
	end
	function Fax.close()
		if layer then
			layer.Visible = false
		end
	end
end

---------------------------------------------------------------------------
-- Field Guide (+ badges + endings)
---------------------------------------------------------------------------

local FieldGuide = {}
do
	local layer: Frame
	local body: ScrollingFrame
	local mode = "Cards"
	local tabs: { [string]: TextButton } = {}
	local CHANNEL_ICONS = { Window = "🪟", Mirror = "🪞", LaneCam = "📹", Receipt = "🧾", Speaker = "🔊", UV = "🔦" }

	local function renderCards(profile)
		local guide = profile.fieldGuide or {}
		local anyEnding = next(profile.endings or {}) ~= nil
		for i, entry in Anomalies.List do
			local status = guide[entry.id]
			local card = Kit.new("Frame", { Size = UDim2.new(1, -12, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = if status then T.paper else T.panelLight, LayoutOrder = i, Parent = body })
			Kit.corner(card, 12)
			Kit.padding(card, 10)
			Kit.list(card, Enum.FillDirection.Vertical, 2)
			if not status then
				Kit.label(card, ("#%03d — ??? (not yet encountered)"):format(entry.number), { Size = UDim2.new(1, 0, 0, 28), Font = T.title, TextColor3 = T.muted, TextXAlignment = Enum.TextXAlignment.Left })
				continue
			end
			local danger = string.rep("★", entry.danger or 0) .. string.rep("☆", 5 - (entry.danger or 0))
			Kit.label(card, ("#%03d — %s  %s"):format(entry.number, string.upper(entry.name), if status == "caught" then "✅ CAUGHT" else "👀 SEEN"), { Size = UDim2.new(1, 0, 0, 30), Font = T.title, TextColor3 = T.ketchup, TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = 1 })
			Kit.label(card, ("Late Customer • Danger: %s • %s"):format(danger, entry.look or ""), { Size = UDim2.new(1, 0, 0, 22), TextColor3 = T.ink, TextXAlignment = Enum.TextXAlignment.Left, MaxText = 16, LayoutOrder = 2 })
			for j, tell in entry.tells or {} do
				Kit.label(card, ("%s %s: %s"):format(CHANNEL_ICONS[tell.channel] or "•", string.upper(tell.channel), tell.text), { Size = UDim2.new(1, 0, 0, 22), TextColor3 = T.ink, Font = T.bold, TextXAlignment = Enum.TextXAlignment.Left, MaxText = 16, LayoutOrder = 2 + j })
			end
			Kit.label(card, ("Says: \"%s\""):format(entry.speaker and entry.speaker[1] or ""), { Size = UDim2.new(1, 0, 0, 22), TextColor3 = T.navy, TextXAlignment = Enum.TextXAlignment.Left, MaxText = 16, LayoutOrder = 10 })
			local event = WeirdEvents.ById[entry.weirdEvent]
			if event then
				Kit.label(card, ("If served: %s — %s"):format(event.name, event.description), { Size = UDim2.new(1, 0, 0, 22), TextColor3 = T.uv, TextXAlignment = Enum.TextXAlignment.Left, MaxText = 15, LayoutOrder = 11 })
			end
			Kit.label(card, "Notes from Deb: \"" .. (entry.debNote or "") .. "\"", { Size = UDim2.new(1, 0, 0, 22), Font = T.hand, TextColor3 = T.ink, TextXAlignment = Enum.TextXAlignment.Left, MaxText = 18, LayoutOrder = 12 })
			if entry.photo and (anyEnding or (profile.freed and profile.freed[entry.id])) then
				Kit.label(card, ("🔦 %s, %s, %d. \"The usual\": %s"):format(entry.photo.employee, entry.photo.job, entry.photo.year, entry.photo.usualText), { Size = UDim2.new(1, 0, 0, 22), Font = T.bold, TextColor3 = Color3.fromRGB(120, 60, 180), TextXAlignment = Enum.TextXAlignment.Left, MaxText = 16, LayoutOrder = 13 })
			end
		end
	end

	local function renderBadges(profile)
		local earned = profile.badges or {}
		local count = 0
		for _ in earned do
			count += 1
		end
		Kit.label(body, ("%d / %d badges"):format(count, #BadgeData.List), { Size = UDim2.new(1, -12, 0, 30), Font = T.title, TextColor3 = T.mustard, LayoutOrder = 0 })
		for i, badge in BadgeData.List do
			local has = earned[badge.id] ~= nil
			local row = Kit.label(body, ("%s  %s — %s"):format(if has then "🏅" else "🔒", badge.name, if has or badge.desc ~= "???" then badge.desc else "???"), {
				Size = UDim2.new(1, -12, 0, 30),
				BackgroundTransparency = 0,
				BackgroundColor3 = if has then T.panelLight else T.ink,
				TextColor3 = if has then T.white else T.muted,
				Font = T.bold,
				TextXAlignment = Enum.TextXAlignment.Left,
				LayoutOrder = i,
				MaxText = 16,
			})
			Kit.corner(row, 8)
			Kit.padding(row, 4)
		end
	end

	local function renderEndings(profile)
		local seen = profile.endings or {}
		local order = { "Company", "Freed", "Fired", "Mascot" }
		for i, id in order do
			local ending = StoryData.Endings[id]
			local has = seen[id] ~= nil
			local row = Kit.label(body, if has then ("✅ %s"):format(ending.title) else "🔒 ???", {
				Size = UDim2.new(1, -12, 0, 40),
				BackgroundTransparency = 0,
				BackgroundColor3 = if has then T.panelLight else T.ink,
				Font = T.title,
				LayoutOrder = i,
			})
			Kit.corner(row, 8)
		end
		local nights = profile.nightResults or {}
		for n = 1, 5 do
			local r = nights[tostring(n)]
			Kit.label(body, ("Night %d: %s"):format(n, if r then ("%s badge (%.1f★)"):format(r.grade, r.stars) else if n <= (profile.nightsUnlocked or 1) then "unlocked" else "locked"), {
				Size = UDim2.new(1, -12, 0, 26),
				TextColor3 = T.muted,
				LayoutOrder = 10 + n,
				MaxText = 16,
			})
		end
	end

	local function render()
		local profile = State.profile
		if not layer or not layer.Visible or not profile then
			return
		end
		for name, button in tabs do
			button.BackgroundColor3 = if name == mode then T.ketchup else T.panelLight
		end
		Kit.clear(body)
		if mode == "Cards" then
			renderCards(profile)
		elseif mode == "Badges" then
			renderBadges(profile)
		else
			renderEndings(profile)
		end
	end

	function FieldGuide.open()
		if not layer then
			local created = Panels.layer("FieldGuide", 0.4)
			layer = created
			local _, content = Kit.panel(created, "FIELD GUIDE", UDim2.fromOffset(1000, 600), function()
				Panels.close("FieldGuide")
			end)
			local tabRow = Kit.new("Frame", { Size = UDim2.new(1, 0, 0, 48), BackgroundTransparency = 1, Parent = content })
			Kit.list(tabRow, Enum.FillDirection.Horizontal, 8)
			for i, name in { "Cards", "Badges", "Endings" } do
				tabs[name] = Kit.button(tabRow, string.upper(name), T.panelLight, function()
					mode = name
					render()
				end, { Size = UDim2.fromOffset(180, 46), LayoutOrder = i })
			end
			body = Kit.scroll(content, { Position = UDim2.fromOffset(0, 56), Size = UDim2.new(1, 0, 1, -56) })
			Kit.list(body, Enum.FillDirection.Vertical, 8)
			State.ProfileChanged:Connect(render)
		end
		layer.Visible = true
		render()
	end
	function FieldGuide.close()
		if layer then
			layer.Visible = false
		end
	end
end

---------------------------------------------------------------------------
-- Settings
---------------------------------------------------------------------------

local Settings = {}
do
	local layer: Frame
	local list: Frame
	local OPTIONS = {
		{ key = "reducedFlashing", label = "Reduced flashing lights", desc = "Lights dim instead of strobing during scares." },
		{ key = "captions", label = "Captions for sounds", desc = "[squeak... squeak... — left] style captions for every audio cue." },
		{ key = "fastStart", label = "Fast Start", desc = "Skip the guided first shift and shorten pre-shift." },
	}
	local function render()
		if not layer or not layer.Visible then
			return
		end
		Kit.clear(list)
		for i, option in OPTIONS do
			local on = State.setting(option.key) == true
			local row = Kit.new("Frame", { Size = UDim2.new(1, 0, 0, 76), BackgroundColor3 = T.panelLight, LayoutOrder = i, Parent = list })
			Kit.corner(row, 10)
			Kit.label(row, option.label, { Position = UDim2.fromOffset(12, 6), Size = UDim2.new(1, -170, 0, 32), Font = T.bold, TextXAlignment = Enum.TextXAlignment.Left, MaxText = 22 })
			Kit.label(row, option.desc, { Position = UDim2.fromOffset(12, 40), Size = UDim2.new(1, -170, 0, 28), TextColor3 = T.muted, TextXAlignment = Enum.TextXAlignment.Left, MaxText = 15 })
			Kit.button(row, if on then "ON" else "OFF", if on then T.good else T.ink, function()
				State.request("SetSetting", { key = option.key, value = not on })
			end, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(130, 52) })
		end
	end
	function Settings.open()
		if not layer then
			local created = Panels.layer("Settings", 0.4)
			layer = created
			local _, content = Kit.panel(created, "SETTINGS", UDim2.fromOffset(720, 400), function()
				Panels.close("Settings")
			end)
			list = Kit.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = content })
			Kit.list(list, Enum.FillDirection.Vertical, 10)
			State.ProfileChanged:Connect(render)
		end
		layer.Visible = true
		render()
	end
	function Settings.close()
		if layer then
			layer.Visible = false
		end
	end
end

function MenuPanels.init()
	Panels.register("Locker", Locker)
	Panels.register("Fax", Fax)
	Panels.register("FieldGuide", FieldGuide)
	Panels.register("Settings", Settings)
end

return MenuPanels
