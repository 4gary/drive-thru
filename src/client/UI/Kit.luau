-- Tiny UI kit: theme + constructors. Everything is built in code (no assets) and scaled with a
-- UIScale so it reads on phones (design doc §7.8: mobile-first, big tap targets).

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Kit = {}

Kit.Theme = {
	ketchup = Color3.fromRGB(215, 38, 61),
	mustard = Color3.fromRGB(244, 180, 0),
	pickle = Color3.fromRGB(106, 153, 78),
	bun = Color3.fromRGB(233, 196, 106),
	navy = Color3.fromRGB(29, 45, 80),
	ink = Color3.fromRGB(28, 28, 34),
	panel = Color3.fromRGB(36, 36, 46),
	panelLight = Color3.fromRGB(52, 52, 66),
	paper = Color3.fromRGB(255, 250, 236),
	white = Color3.fromRGB(255, 255, 255),
	muted = Color3.fromRGB(170, 170, 185),
	good = Color3.fromRGB(70, 170, 90),
	bad = Color3.fromRGB(210, 55, 55),
	warn = Color3.fromRGB(235, 150, 40),
	uv = Color3.fromRGB(190, 90, 255),
	crt = Color3.fromRGB(16, 32, 20),
	crtText = Color3.fromRGB(110, 255, 140),
	title = Enum.Font.FredokaOne,
	body = Enum.Font.GothamMedium,
	bold = Enum.Font.GothamBold,
	mono = Enum.Font.Arcade,
	hand = Enum.Font.PatrickHand,
}
local T = Kit.Theme

local scales: { { scale: UIScale, gui: ScreenGui } } = {}

-- Everything is laid out on a 1280x720 canvas. The scale fits that canvas into the ScreenGui's
-- actual (safe-area) size, so panels up to ~1060x600 always fit, even on small phones.
local function computeScale(size: Vector2?): number
	local area = size
	if not area or area.X < 10 then
		local camera = workspace.CurrentCamera
		area = if camera then camera.ViewportSize else Vector2.new(1280, 720)
	end
	local fitted = math.min(area.X / 1280, area.Y / 720)
	return math.clamp(fitted, 0.35, 1.35)
end

local function refreshScales()
	for _, entry in scales do
		entry.scale.Scale = computeScale(entry.gui.AbsoluteSize)
	end
end

function Kit.watchViewport()
	local function hook()
		local camera = workspace.CurrentCamera
		if camera then
			camera:GetPropertyChangedSignal("ViewportSize"):Connect(refreshScales)
		end
		refreshScales()
	end
	workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(hook)
	hook()
end

function Kit.new(className: string, props: { [string]: any }?, children: { Instance }?): any
	local inst = Instance.new(className)
	if inst:IsA("GuiObject") then
		(inst :: any).BorderSizePixel = 0
	end
	local parent = nil
	if props then
		for key, value in props do
			if key == "Parent" then
				parent = value
			else
				(inst :: any)[key] = value
			end
		end
	end
	if children then
		for _, child in children do
			child.Parent = inst
		end
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

function Kit.screen(name: string, order: number?, safeArea: boolean?): ScreenGui
	local gui = Kit.new("ScreenGui", {
		Name = name,
		ResetOnSpawn = false,
		IgnoreGuiInset = not safeArea,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = order or 1,
	})
	if safeArea then
		gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	end
	local root = Kit.new("Frame", {
		Name = "Root",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	local scale = Kit.new("UIScale", { Parent = root })
	table.insert(scales, { scale = scale, gui = gui })
	scale.Scale = computeScale(nil)
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		scale.Scale = computeScale(gui.AbsoluteSize)
	end)
	-- the scaled root is sized so that children laid out at 1280x720 fit any screen
	local function fit()
		local s = scale.Scale
		root.Size = UDim2.fromScale(1 / s, 1 / s)
	end
	scale:GetPropertyChangedSignal("Scale"):Connect(fit)
	fit()
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	return gui
end

function Kit.root(gui: ScreenGui): Frame
	return gui:FindFirstChild("Root") :: Frame
end

function Kit.corner(parent: Instance, radius: number?)
	return Kit.new("UICorner", { CornerRadius = UDim.new(0, radius or 12), Parent = parent })
end

function Kit.stroke(parent: Instance, color: Color3?, thickness: number?)
	return Kit.new("UIStroke", {
		Color = color or T.ink,
		Thickness = thickness or 2,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = parent,
	})
end

function Kit.padding(parent: Instance, px: number)
	return Kit.new("UIPadding", {
		PaddingLeft = UDim.new(0, px),
		PaddingRight = UDim.new(0, px),
		PaddingTop = UDim.new(0, px),
		PaddingBottom = UDim.new(0, px),
		Parent = parent,
	})
end

function Kit.list(parent: Instance, direction: Enum.FillDirection?, spacing: number?, align: Enum.HorizontalAlignment?)
	return Kit.new("UIListLayout", {
		FillDirection = direction or Enum.FillDirection.Vertical,
		Padding = UDim.new(0, spacing or 8),
		HorizontalAlignment = align or Enum.HorizontalAlignment.Left,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = parent,
	})
end

function Kit.label(parent: Instance?, text: string, props: { [string]: any }?): TextLabel
	local label = Kit.new("TextLabel", {
		BackgroundTransparency = 1,
		Text = text,
		TextColor3 = T.white,
		Font = T.body,
		TextScaled = true,
		TextWrapped = true,
		Size = UDim2.new(1, 0, 0, 28),
	})
	local maxSize = 0
	if props then
		for key, value in props do
			if key == "MaxText" then
				maxSize = value
			else
				(label :: any)[key] = value
			end
		end
	end
	if label.TextScaled then
		Kit.new("UITextSizeConstraint", { MaxTextSize = if maxSize > 0 then maxSize else 36, MinTextSize = 8, Parent = label })
	end
	if parent then
		label.Parent = parent
	end
	return label
end

function Kit.button(parent: Instance?, text: string, color: Color3?, onClick: (() -> ())?, props: { [string]: any }?): TextButton
	local button = Kit.new("TextButton", {
		Text = text,
		BackgroundColor3 = color or T.panelLight,
		TextColor3 = T.white,
		Font = T.title,
		TextScaled = true,
		AutoButtonColor = true,
		Size = UDim2.fromOffset(160, 56),
	})
	Kit.corner(button, 12)
	Kit.new("UITextSizeConstraint", { MaxTextSize = 30, MinTextSize = 10, Parent = button })
	Kit.new("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4), Parent = button })
	if props then
		for key, value in props do
			(button :: any)[key] = value
		end
	end
	if onClick then
		button.Activated:Connect(function()
			local scale = button:FindFirstChildOfClass("UIScale") or Kit.new("UIScale", { Parent = button })
			scale.Scale = 0.92
			TweenService:Create(scale, TweenInfo.new(0.12), { Scale = 1 }):Play()
			onClick()
		end)
	end
	if parent then
		button.Parent = parent
	end
	return button
end

-- A centered card with a title bar. Returns (frame, content, closeButton).
function Kit.panel(parent: Instance, title: string, size: UDim2, onClose: (() -> ())?): (Frame, Frame, TextButton?)
	local frame = Kit.new("Frame", {
		Name = "Panel",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = size,
		BackgroundColor3 = T.panel,
		Parent = parent,
	})
	Kit.corner(frame, 18)
	Kit.stroke(frame, T.mustard, 3)
	local bar = Kit.new("Frame", {
		Name = "TitleBar",
		Size = UDim2.new(1, 0, 0, 52),
		BackgroundColor3 = T.ketchup,
		Parent = frame,
	})
	Kit.corner(bar, 18)
	Kit.new("Frame", { Size = UDim2.new(1, 0, 0, 18), Position = UDim2.new(0, 0, 1, -18), BackgroundColor3 = T.ketchup, Parent = bar })
	Kit.label(bar, title, {
		Name = "Title",
		Size = UDim2.new(1, -120, 1, -8),
		Position = UDim2.fromOffset(18, 4),
		Font = T.title,
		TextColor3 = T.mustard,
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxText = 32,
	})
	local close = nil
	if onClose then
		close = Kit.button(bar, "✕", T.ink, onClose, {
			Name = "Close",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -10, 0.5, 0),
			Size = UDim2.fromOffset(44, 40),
		})
	end
	local content = Kit.new("Frame", {
		Name = "Content",
		Size = UDim2.new(1, -24, 1, -68),
		Position = UDim2.fromOffset(12, 60),
		BackgroundTransparency = 1,
		Parent = frame,
	})
	return frame, content, close
end

function Kit.scroll(parent: Instance, props: { [string]: any }?): ScrollingFrame
	local frame = Kit.new("ScrollingFrame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ScrollBarThickness = 8,
		ScrollBarImageColor3 = T.mustard,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
	})
	if props then
		for key, value in props do
			(frame :: any)[key] = value
		end
	end
	frame.Parent = parent
	return frame
end

function Kit.clear(container: Instance)
	for _, child in container:GetChildren() do
		if not child:IsA("UIListLayout") and not child:IsA("UIGridLayout") and not child:IsA("UIPadding") and not child:IsA("UICorner") and not child:IsA("UIStroke") then
			child:Destroy()
		end
	end
end

function Kit.fade(gui: GuiObject, to: number, time: number?)
	local props = { BackgroundTransparency = to }
	if gui:IsA("TextLabel") or gui:IsA("TextButton") then
		(props :: any).TextTransparency = to
	end
	TweenService:Create(gui, TweenInfo.new(time or 0.3), props):Play()
end

return Kit
