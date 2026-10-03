-- The parking-lot lobby HUD: Paychecks, menu buttons, the clock-in booth card (pick night,
-- Solo / Friends / Public, start), first-play Quick Start, and Rejoin after a crash (§7.1, §7.9).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Nights = require(Shared.Data.Nights)
local Kit = require(script.Parent.Parent.UI.Kit)
local State = require(script.Parent.State)
local Panels = require(script.Parent.Panels)

local T = Kit.Theme
local player = Players.LocalPlayer

local Lobby = {}

local gui: ScreenGui
local root: Frame
local money: TextLabel
local boothCard: Frame
local boothBody: Frame
local startCard: Frame
local notice: TextLabel
local lastBoothSig = ""
local quickStartBusy = false

local function toast(text: string, kind: string?)
	local HUD = require(script.Parent.HUD) :: any
	HUD.toast(text, kind)
end

local function renderBooth(lobby)
	local booth = nil
	for _, b in lobby.booths or {} do
		if b.isMember then
			booth = b
		end
	end
	if not booth then
		boothCard.Visible = false
		lastBoothSig = ""
		return
	end
	boothCard.Visible = true
	local sig = ("%s:%d:%s:%s:%s:%d"):format(booth.id, booth.night, booth.privacy, tostring(booth.isLeader), table.concat(booth.members, ","), math.ceil(booth.countdown or 0))
	if sig == lastBoothSig then
		return
	end
	lastBoothSig = sig
	Kit.clear(boothBody)
	Kit.label(boothBody, ("CLOCK-IN %s"):format(booth.id), { Size = UDim2.new(1, 0, 0, 30), Font = T.title, TextColor3 = T.mustard, LayoutOrder = 1 })
	Kit.label(boothBody, ("NIGHT %d: %s"):format(booth.night, Nights.get(booth.night).title), { Size = UDim2.new(1, 0, 0, 28), Font = T.bold, LayoutOrder = 2, MaxText = 20 })
	Kit.label(boothBody, ("Crew (%d/4): %s"):format(#booth.members, table.concat(booth.members, ", ")), { Size = UDim2.new(1, 0, 0, 26), TextColor3 = T.muted, LayoutOrder = 3, MaxText = 16 })
	Kit.label(boothBody, ("Clocking in: %ds"):format(math.ceil(booth.countdown or 0)), { Size = UDim2.new(1, 0, 0, 26), Font = T.bold, TextColor3 = T.good, LayoutOrder = 4, MaxText = 18 })
	if booth.isLeader then
		local nightRow = Kit.new("Frame", { Size = UDim2.new(1, 0, 0, 50), BackgroundTransparency = 1, LayoutOrder = 5, Parent = boothBody })
		Kit.list(nightRow, Enum.FillDirection.Horizontal, 6, Enum.HorizontalAlignment.Center)
		local unlocked = lobby.unlocked or 1
		for n = 1, Nights.Count do
			local locked = n > unlocked
			Kit.button(nightRow, if locked then "🔒" else tostring(n), if n == booth.night then T.ketchup elseif locked then T.ink else T.panelLight, function()
				if not locked then
					State.action("Booth", { op = "night", value = n })
				else
					toast("Finish the previous night to unlock this one.")
				end
			end, { Size = UDim2.fromOffset(58, 48), LayoutOrder = n })
		end
		local privacyRow = Kit.new("Frame", { Size = UDim2.new(1, 0, 0, 50), BackgroundTransparency = 1, LayoutOrder = 6, Parent = boothBody })
		Kit.list(privacyRow, Enum.FillDirection.Horizontal, 6, Enum.HorizontalAlignment.Center)
		for i, mode in { "Solo", "Friends", "Public" } do
			Kit.button(privacyRow, string.upper(mode), if mode == booth.privacy then T.navy else T.panelLight, function()
				State.action("Booth", { op = "privacy", value = mode })
			end, { Size = UDim2.fromOffset(110, 48), LayoutOrder = i })
		end
		Kit.button(boothBody, "CLOCK IN NOW ▶", T.good, function()
			State.action("Booth", { op = "start" })
		end, { Size = UDim2.new(1, 0, 0, 56), LayoutOrder = 7 })
	else
		Kit.label(boothBody, ("Leader: %s (%s)"):format(booth.leader or "?", booth.privacy), { Size = UDim2.new(1, 0, 0, 26), TextColor3 = T.muted, LayoutOrder = 5, MaxText = 16 })
	end
	Kit.label(boothBody, "Step off the pad to leave.", { Size = UDim2.new(1, 0, 0, 22), TextColor3 = T.muted, LayoutOrder = 9, MaxText = 14 })
end

local function render()
	local crew = State.isCrew()
	gui.Enabled = not crew
	if crew then
		return
	end
	local profile = State.profile
	money.Text = ("💵 %d Paychecks"):format(if profile then profile.paychecks or 0 else 0)
	local lobby = State.lobby
	if not lobby then
		return
	end
	renderBooth(lobby)
	local notes = {}
	if lobby.waitingForCrew then
		table.insert(notes, "Waiting for your crew to arrive...")
	end
	if lobby.kitchenBusy then
		table.insert(notes, "A crew is on shift in this server's kitchen (watch the lobby TV). In Studio only one shift runs at a time.")
	end
	if profile and profile.memoryOnly then
		table.insert(notes, "⚠ Saves are off in this session (Studio without API access).")
	end
	notice.Text = table.concat(notes, "\n")
	notice.Visible = #notes > 0
	local showStart = not boothCard.Visible and not lobby.shiftServer
	startCard.Visible = showStart
	if showStart then
		local first = startCard:FindFirstChild("First") :: TextButton
		local rejoin = startCard:FindFirstChild("Rejoin") :: TextButton
		local quick = startCard:FindFirstChild("Quick") :: TextButton
		first.Visible = lobby.firstJoin == true
		quick.Visible = lobby.firstJoin ~= true
		quick.Text = ("QUICK SOLO SHIFT — NIGHT %d"):format(math.clamp(lobby.unlocked or 1, 1, 5))
		rejoin.Visible = lobby.rejoin ~= nil
		if lobby.rejoin then
			rejoin.Text = ("REJOIN YOUR SHIFT (NIGHT %d)"):format(lobby.rejoin.night or 1)
		end
	end
end

local function quickStart(night: number?)
	if quickStartBusy then
		return
	end
	quickStartBusy = true
	local result = State.request("QuickStart", { night = night })
	if not result.ok and result.message then
		toast(result.message, "warn")
	end
	task.delay(2, function()
		quickStartBusy = false
	end)
end

function Lobby.init()
	gui = Kit.screen("NightShiftLobby", 4, true)
	root = Kit.root(gui)
	local top = Kit.new("Frame", { Position = UDim2.fromOffset(12, 8), Size = UDim2.fromOffset(560, 56), BackgroundTransparency = 1, Parent = root })
	Kit.list(top, Enum.FillDirection.Horizontal, 8)
	money = Kit.label(top, "💵 0 Paychecks", { Size = UDim2.fromOffset(220, 52), BackgroundTransparency = 0.15, BackgroundColor3 = T.ink, Font = T.title, TextColor3 = T.good, LayoutOrder = 1 })
	Kit.corner(money, 12)
	Kit.button(top, "📘 FIELD GUIDE", T.pickle, function()
		Panels.open("FieldGuide", State.profile)
	end, { Size = UDim2.fromOffset(170, 52), LayoutOrder = 2 })
	Kit.button(top, "⚙", T.panelLight, function()
		Panels.open("Settings", State.profile)
	end, { Size = UDim2.fromOffset(60, 52), LayoutOrder = 3 })
	Kit.button(top, "👕", T.navy, function()
		Panels.open("Locker", State.profile)
	end, { Size = UDim2.fromOffset(60, 52), LayoutOrder = 4 })

	notice = Kit.label(root, "", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 70),
		Size = UDim2.fromOffset(720, 60),
		BackgroundTransparency = 0.2,
		BackgroundColor3 = T.ink,
		Font = T.bold,
		Visible = false,
		MaxText = 18,
	})
	Kit.corner(notice, 10)

	boothCard = Kit.new("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -16, 0.5, 0),
		Size = UDim2.fromOffset(400, 470),
		BackgroundColor3 = T.panel,
		BackgroundTransparency = 0.05,
		Visible = false,
		Parent = root,
	})
	Kit.corner(boothCard, 16)
	Kit.stroke(boothCard, T.mustard, 3)
	boothBody = Kit.new("Frame", { Size = UDim2.new(1, -24, 1, -24), Position = UDim2.fromOffset(12, 12), BackgroundTransparency = 1, Parent = boothCard })
	Kit.list(boothBody, Enum.FillDirection.Vertical, 8, Enum.HorizontalAlignment.Center)

	startCard = Kit.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -24),
		Size = UDim2.fromOffset(560, 200),
		BackgroundTransparency = 1,
		Parent = root,
	})
	Kit.list(startCard, Enum.FillDirection.Vertical, 8, Enum.HorizontalAlignment.Center).VerticalAlignment = Enum.VerticalAlignment.Bottom
	Kit.button(startCard, "REJOIN YOUR SHIFT", T.warn, function()
		local result = State.request("Rejoin")
		if not result.ok and result.message then
			toast(result.message, "bad")
		end
	end, { Name = "Rejoin", Size = UDim2.fromOffset(520, 60), Visible = false, LayoutOrder = 1 })
	Kit.button(startCard, "START YOUR FIRST SHIFT ▶", T.ketchup, function()
		quickStart(1)
	end, { Name = "First", Size = UDim2.fromOffset(520, 76), Visible = false, LayoutOrder = 2 })
	Kit.button(startCard, "QUICK SOLO SHIFT", T.panelLight, function()
		quickStart(nil)
	end, { Name = "Quick", Size = UDim2.fromOffset(520, 56), LayoutOrder = 3 })
	Kit.label(startCard, "...or step on a CLOCK-IN pad with friends (1–4 crew).", { Size = UDim2.fromOffset(520, 26), TextStrokeTransparency = 0.4, Font = T.bold, LayoutOrder = 4, MaxText = 16 })

	State.LobbyChanged:Connect(render)
	State.ProfileChanged:Connect(render)
	player:GetAttributeChangedSignal("Crew"):Connect(render)
	render()
end

return Lobby
