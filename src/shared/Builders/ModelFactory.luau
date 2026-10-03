-- Builds every greybox model the game spawns: customers + cars (with their anomaly tells),
-- Mr. Munch, Gizmo, food items, raccoons, Shift Ghost sheets, props.
--
-- Models are built around the origin with an anchored "Root" PrimaryPart. With `anchored = false`
-- (the default for runtime models) every other part is welded to Root and unanchored, so moving
-- Root moves the whole thing. Must not use PivotTo/GetPivot so Lune can run it at build time.
--
-- Channel tags (read by the client's view controller):
--   CollectionService tag "ChannelPart" + attribute Channel = "CamOnly" | "NotOnCam" | "UVOnly"

local ModelFactory = {}

local SMOOTH = Enum.Material.SmoothPlastic
local VERTICAL = CFrame.Angles(0, 0, math.rad(90)) -- turns a cylinder's X axis to Y

local COLORS = {
	white = Color3.fromRGB(245, 245, 245),
	black = Color3.fromRGB(25, 25, 28),
	glass = Color3.fromRGB(160, 200, 220),
	tire = Color3.fromRGB(30, 30, 32),
	chrome = Color3.fromRGB(200, 200, 205),
	headlight = Color3.fromRGB(255, 244, 200),
	taillight = Color3.fromRGB(200, 30, 30),
	bun = Color3.fromRGB(222, 166, 92),
	patty = Color3.fromRGB(105, 60, 34),
	lettuce = Color3.fromRGB(110, 190, 70),
	cheese = Color3.fromRGB(255, 205, 40),
	ketchup = Color3.fromRGB(215, 38, 61),
	mustard = Color3.fromRGB(244, 180, 0),
	uv = Color3.fromRGB(190, 90, 255),
	glove = Color3.fromRGB(250, 250, 250),
	lips = Color3.fromRGB(150, 40, 50),
}
ModelFactory.Colors = COLORS

---------------------------------------------------------------------------
-- Low-level helpers
---------------------------------------------------------------------------

local function part(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?, props: { [string]: any }?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or SMOOTH
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	if props then
		for key, value in props do
			(p :: any)[key] = value
		end
	end
	p.Parent = parent
	return p
end
ModelFactory.part = part

local function cylinder(parent: Instance, name: string, length: number, diameter: number, cf: CFrame, color: Color3, material: Enum.Material?, props: { [string]: any }?): Part
	local p = part(parent, name, Vector3.new(length, diameter, diameter), cf, color, material, props)
	p.Shape = Enum.PartType.Cylinder
	return p
end
ModelFactory.cylinder = cylinder

local function ball(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?): Part
	local p = part(parent, name, size, cf, color, material)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
	return p
end
ModelFactory.ball = ball

local function channel(inst: BasePart, mode: string)
	inst:SetAttribute("Channel", mode)
	inst:AddTag("ChannelPart")
end
ModelFactory.channel = channel

local function newModel(name: string): (Model, Part)
	local model = Instance.new("Model")
	model.Name = name
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.new(1, 1, 1)
	root.CFrame = CFrame.new()
	root.Transparency = 1
	root.Anchored = true
	root.CanCollide = false
	root.CanTouch = false
	root.CanQuery = false
	root.Parent = model
	model.PrimaryPart = root
	return model, root
end
ModelFactory.newModel = newModel

-- Weld everything to Root (unless the model should stay fully anchored).
local function finalize(model: Model, anchored: boolean?)
	local root = model.PrimaryPart :: BasePart
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d ~= root then
			if not anchored then
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = root
				weld.Part1 = d
				weld.Parent = d
				d.Anchored = false
				d.Massless = true
			end
			d.CanCollide = false
			d.CanTouch = false
		end
	end
	return model
end
ModelFactory.finalize = finalize

-- Move a model so its Root lands on `cf` (works without PivotTo).
function ModelFactory.place(model: Model, cf: CFrame)
	local root = model.PrimaryPart :: BasePart
	local inverse = root.CFrame:Inverse()
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.CFrame = cf * (inverse * d.CFrame)
		end
	end
end

local function surfaceText(p: BasePart, face: Enum.NormalId, text: string, color: Color3, font: Enum.Font?, background: Color3?): SurfaceGui
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Text"
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 50
	gui.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = if background then 0 else 1
	label.BackgroundColor3 = background or Color3.new(0, 0, 0)
	label.Text = text
	label.TextColor3 = color
	label.TextScaled = true
	label.TextWrapped = true
	label.Font = font or Enum.Font.FredokaOne
	label.Parent = gui
	gui.Parent = p
	return gui
end
ModelFactory.surfaceText = surfaceText

---------------------------------------------------------------------------
-- Faces (drawn with GUI frames so tells like "never blinks" can be animated)
---------------------------------------------------------------------------

local function frame(parent: Instance, name: string, pos: UDim2, size: UDim2, color: Color3, round: boolean?): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = pos
	f.Size = size
	f.BackgroundColor3 = color
	f.BorderSizePixel = 0
	if round then
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.5, 0)
		corner.Parent = f
	end
	f.Parent = parent
	return f
end

-- Draws a face into `container` (a SurfaceGui or Frame). Returns the canvas frame.
function ModelFactory.drawFace(container: Instance, skin: Color3, opts: { [string]: any }?)
	local o = opts or {}
	local canvas = frame(container, "Face", UDim2.fromScale(0.5, 0.5), UDim2.fromScale(1, 1), skin)
	canvas.BackgroundTransparency = if o.transparentBackground then 1 else 0
	local eyeSize = UDim2.fromScale(0.2, 0.2)
	for _, side in { { "L", 0.32 }, { "R", 0.68 } } do
		local eye = frame(canvas, "Eye" .. side[1], UDim2.fromScale(side[2], 0.4), eyeSize, COLORS.white, true)
		frame(eye, "Pupil", UDim2.fromScale(0.5, 0.55), UDim2.fromScale(0.5, 0.5), o.pupilColor or COLORS.black, true)
		local lid = frame(canvas, "Lid" .. side[1], UDim2.fromScale(side[2], 0.4), UDim2.fromScale(0.24, 0.24), skin, true)
		lid.Visible = false
		lid.ZIndex = 3
	end
	local mouthWidth = o.mouthWidth or 0.36
	local mouth = frame(canvas, "Mouth", UDim2.fromScale(0.5, 0.72), UDim2.fromScale(mouthWidth, 0.16), COLORS.lips, true)
	mouth.ZIndex = 2
	local cover = frame(canvas, "MouthCover", UDim2.fromScale(0.5, 0.66), UDim2.fromScale(mouthWidth + 0.06, 0.12), skin)
	cover.ZIndex = 2
	if o.teethText then
		local teeth = Instance.new("TextLabel")
		teeth.Name = "Teeth"
		teeth.AnchorPoint = Vector2.new(0.5, 0.5)
		teeth.Position = UDim2.fromScale(0.5, 0.74)
		teeth.Size = UDim2.fromScale(0.34, 0.12)
		teeth.BackgroundColor3 = COLORS.white
		teeth.BorderSizePixel = 0
		teeth.Text = o.teethText
		teeth.TextColor3 = COLORS.ketchup
		teeth.TextScaled = true
		teeth.Font = Enum.Font.FredokaOne
		teeth.ZIndex = 4
		teeth.Parent = canvas
	end
	if o.tears then
		frame(canvas, "Tear", UDim2.fromScale(0.3, 0.6), UDim2.fromScale(0.06, 0.14), Color3.fromRGB(90, 160, 255), true).ZIndex = 4
		frame(canvas, "Tear2", UDim2.fromScale(0.7, 0.62), UDim2.fromScale(0.06, 0.14), Color3.fromRGB(90, 160, 255), true).ZIndex = 4
	end
	return canvas
end

local function faceGui(head: BasePart, skin: Color3, opts: { [string]: any }?): SurfaceGui
	local gui = Instance.new("SurfaceGui")
	gui.Name = "FaceGui"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 60
	gui.LightInfluence = 0.6
	ModelFactory.drawFace(gui, skin, opts)
	gui.Parent = head
	return gui
end

---------------------------------------------------------------------------
-- People. Built facing -Z (toward the restaurant window), origin at the seat.
---------------------------------------------------------------------------

local function addHair(model: Model, head: BasePart, style: string, color: Color3)
	local top = head.CFrame * CFrame.new(0, 0.75, 0)
	if style == "Bald" then
		return
	elseif style == "Short" then
		part(model, "Hair", Vector3.new(1.85, 0.35, 1.85), top, color)
	elseif style == "Long" then
		part(model, "Hair", Vector3.new(1.9, 0.4, 1.9), top, color)
		part(model, "HairBack", Vector3.new(1.9, 1.8, 0.4), head.CFrame * CFrame.new(0, -0.1, 0.85), color)
	elseif style == "Bun" then
		part(model, "Hair", Vector3.new(1.85, 0.35, 1.85), top, color)
		ball(model, "Bun", Vector3.new(0.9, 0.9, 0.9), head.CFrame * CFrame.new(0, 1.05, 0.4), color)
	elseif style == "Curly" then
		ball(model, "Hair", Vector3.new(2.2, 1.2, 2.2), head.CFrame * CFrame.new(0, 0.75, 0.1), color)
	elseif style == "Spiky" then
		for i = -1, 1 do
			local spike = Instance.new("WedgePart")
			spike.Name = "Spike"
			spike.Size = Vector3.new(0.5, 0.7, 0.9)
			spike.CFrame = head.CFrame * CFrame.new(i * 0.55, 1.05, 0)
			spike.Color = color
			spike.Material = SMOOTH
			spike.Anchored = true
			spike.CanCollide = false
			spike.Parent = model
		end
		part(model, "Hair", Vector3.new(1.85, 0.3, 1.85), top, color)
	elseif style == "Beanie" then
		ball(model, "Hair", Vector3.new(2, 1.1, 2), head.CFrame * CFrame.new(0, 0.6, 0), color)
	elseif style == "Cap" then
		part(model, "Cap", Vector3.new(1.9, 0.45, 1.9), top, color)
		part(model, "Brim", Vector3.new(1.4, 0.12, 0.9), head.CFrame * CFrame.new(0, 0.6, -1.2), color)
	end
end

-- Waving hand held up out of the car window. digits = number of fingers (thumb included).
local function addHand(model: Model, at: CFrame, skin: Color3, digits: number, opts: { [string]: any }?)
	local o = opts or {}
	local hand = Instance.new("Model")
	hand.Name = "Hand"
	hand.Parent = model
	local handColor = o.glove or skin
	part(hand, "Palm", Vector3.new(1.0, 0.9, 0.3), at, handColor)
	if o.cast then
		part(hand, "Cast", Vector3.new(1.3, 1.9, 0.6), at * CFrame.new(0, 0.4, 0), COLORS.white, Enum.Material.Fabric)
		return hand
	end
	local spread = 1.1
	for i = 1, digits do
		local x = -spread / 2 + (i - 0.5) * spread / digits
		local finger = part(
			hand,
			"Finger" .. i,
			Vector3.new(math.min(0.2, spread / digits * 0.8), 0.75, 0.22),
			at * CFrame.new(x, 0.75, 0),
			handColor
		)
		finger:SetAttribute("Digit", i)
	end
	part(model, "Arm", Vector3.new(0.6, 1.6, 0.6), at * CFrame.new(0.2, -1.1, 0.2), o.sleeve or skin)
	return hand
end

-- spec: { skin, hairColor, hairStyle, shirt, glasses, kid? }
function ModelFactory.addPerson(model: Model, seat: CFrame, spec: { [string]: any }, opts: { [string]: any }?): BasePart
	local o = opts or {}
	local scale = if spec.kid then 0.6 else 1
	local skin = spec.skin or Color3.fromRGB(224, 172, 105)
	part(model, o.prefix and (o.prefix .. "Torso") or "Torso", Vector3.new(2.1, 2, 1.1) * scale, seat * CFrame.new(0, 1.0 * scale, 0), spec.shirt or COLORS.white)
	local head = part(model, o.prefix and (o.prefix .. "Head") or "Head", Vector3.new(1.7, 1.7, 1.7) * scale, seat * CFrame.new(0, 2.85 * scale, 0), skin)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Head
	mesh.Scale = Vector3.new(1.1, 1.1, 1.1)
	mesh.Parent = head
	faceGui(head, skin, o.face)
	if not o.noEars then
		part(model, "EarL", Vector3.new(0.3, 0.6, 0.4) * scale, head.CFrame * CFrame.new(-0.98 * scale, 0, 0), skin)
		part(model, "EarR", Vector3.new(0.3, 0.6, 0.4) * scale, head.CFrame * CFrame.new(0.98 * scale, 0, 0), skin)
	end
	if not spec.kid then
		addHair(model, head, spec.hairStyle or "Short", spec.hairColor or Color3.fromRGB(40, 30, 20))
	elseif spec.hairStyle ~= "Bald" then
		ball(model, "Hair", Vector3.new(1.3, 0.7, 1.3), head.CFrame * CFrame.new(0, 0.5, 0.05), spec.hairColor or Color3.fromRGB(40, 30, 20))
	end
	if spec.glasses then
		part(model, "Glasses", Vector3.new(1.5, 0.35, 0.08) * scale, head.CFrame * CFrame.new(0, 0.2 * scale, -0.95 * scale), COLORS.black)
	end
	return head
end

---------------------------------------------------------------------------
-- Cars. Face +X. Root at ground level, centered. Driver seat on the -Z side.
---------------------------------------------------------------------------

local CAR_SHAPES = {
	Sedan = { length = 12, width = 6, body = 2.2, cabinLen = 6, cabinH = 2.8, roof = true },
	Hatchback = { length = 10.5, width = 5.8, body = 2.2, cabinLen = 6.5, cabinH = 2.8, roof = true, cabinBack = true },
	Compact = { length = 8.5, width = 5.4, body = 2, cabinLen = 5, cabinH = 2.7, roof = true, cabinBack = true },
	Pickup = { length = 13, width = 6.2, body = 2.6, cabinLen = 4.4, cabinH = 2.8, roof = true, bed = true },
	Minivan = { length = 13, width = 6.4, body = 2.4, cabinLen = 10, cabinH = 3.4, roof = true, cabinBack = true },
	Convertible = { length = 12, width = 6, body = 2.1, cabinLen = 5, cabinH = 1.2, roof = false },
	Buick = { length = 14, width = 6.4, body = 2.2, cabinLen = 6.5, cabinH = 2.8, roof = true },
	Police = { length = 12.5, width = 6.2, body = 2.2, cabinLen = 6, cabinH = 2.8, roof = true, police = true },
	Vintage = { length = 13, width = 6.2, body = 2.4, cabinLen = 6, cabinH = 2.9, roof = true, boxy = true },
}

local function buildCarBody(model: Model, kind: string, color: Color3): CFrame
	local shape = CAR_SHAPES[kind] or CAR_SHAPES.Sedan
	local L, W = shape.length, shape.width
	local bodyBottom = 0.9
	local bodyTop = bodyBottom + shape.body
	part(model, "Body", Vector3.new(L, shape.body, W), CFrame.new(0, bodyBottom + shape.body / 2, 0), color, Enum.Material.Metal)
	-- bumpers & lights
	part(model, "BumperF", Vector3.new(0.4, 0.6, W), CFrame.new(L / 2 + 0.1, bodyBottom + 0.3, 0), COLORS.chrome, Enum.Material.Metal)
	part(model, "BumperR", Vector3.new(0.4, 0.6, W), CFrame.new(-L / 2 - 0.1, bodyBottom + 0.3, 0), COLORS.chrome, Enum.Material.Metal)
	for _, z in { -W / 2 + 0.9, W / 2 - 0.9 } do
		local light = part(model, "Headlight", Vector3.new(0.2, 0.6, 1.1), CFrame.new(L / 2 + 0.05, bodyTop - 0.6, z), COLORS.headlight, Enum.Material.Neon)
		local spot = Instance.new("SpotLight")
		spot.Face = Enum.NormalId.Right
		spot.Range = 28
		spot.Angle = 60
		spot.Brightness = 1.5
		spot.Color = COLORS.headlight
		spot.Shadows = false
		spot.Parent = light
		part(model, "Taillight", Vector3.new(0.2, 0.5, 1), CFrame.new(-L / 2 - 0.05, bodyTop - 0.6, z), COLORS.taillight, Enum.Material.Neon)
	end
	-- wheels
	for _, x in { L / 2 - 2.4, -L / 2 + 2.4 } do
		for _, z in { -W / 2 + 0.2, W / 2 - 0.2 } do
			cylinder(model, "Wheel", 0.9, 2.1, CFrame.new(x, 1.05, z) * CFrame.Angles(0, math.rad(90), 0), COLORS.tire)
			cylinder(model, "Hubcap", 0.95, 1.0, CFrame.new(x, 1.05, z) * CFrame.Angles(0, math.rad(90), 0), COLORS.chrome, Enum.Material.Metal)
		end
	end
	-- cabin: pillars, windshield, roof, passenger-side glass. The driver side (-Z) stays open.
	local cabinX = if shape.cabinBack then -L / 2 + shape.cabinLen / 2 + 0.6 else 0
	local cabinTop = bodyTop + shape.cabinH
	local front = cabinX + shape.cabinLen / 2
	local back = cabinX - shape.cabinLen / 2
	if shape.roof then
		part(model, "Roof", Vector3.new(shape.cabinLen, 0.3, W - 0.2), CFrame.new(cabinX, cabinTop, 0), color, Enum.Material.Metal, { Transparency = 0.15 })
		for _, x in { front - 0.2, back + 0.2 } do
			for _, z in { -W / 2 + 0.2, W / 2 - 0.2 } do
				part(model, "Pillar", Vector3.new(0.3, shape.cabinH, 0.3), CFrame.new(x, bodyTop + shape.cabinH / 2, z), color, Enum.Material.Metal)
			end
		end
		part(model, "Windshield", Vector3.new(0.15, shape.cabinH - 0.2, W - 0.6), CFrame.new(front - 0.2, bodyTop + shape.cabinH / 2, 0), COLORS.glass, Enum.Material.Glass, { Transparency = 0.7 })
		part(model, "RearGlass", Vector3.new(0.15, shape.cabinH - 0.2, W - 0.6), CFrame.new(back + 0.2, bodyTop + shape.cabinH / 2, 0), COLORS.glass, Enum.Material.Glass, { Transparency = 0.7 })
		part(model, "SideGlass", Vector3.new(shape.cabinLen - 0.6, shape.cabinH - 0.2, 0.15), CFrame.new(cabinX, bodyTop + shape.cabinH / 2, W / 2 - 0.2), COLORS.glass, Enum.Material.Glass, { Transparency = 0.7 })
		if shape.cabinLen > 6.5 then
			-- rear windows on the driver side for vans (the front seat window stays open)
			part(model, "RearSideGlass", Vector3.new(shape.cabinLen - 4, shape.cabinH - 0.2, 0.15), CFrame.new(back + (shape.cabinLen - 4) / 2 + 0.3, bodyTop + shape.cabinH / 2, -W / 2 + 0.2), COLORS.glass, Enum.Material.Glass, { Transparency = 0.7 })
		end
	else
		part(model, "Windshield", Vector3.new(0.15, 1.2, W - 0.6), CFrame.new(1.8, bodyTop + 0.6, 0), COLORS.glass, Enum.Material.Glass, { Transparency = 0.6 })
	end
	if shape.bed then
		part(model, "BedFloor", Vector3.new(L / 2 - 1, 0.2, W - 0.6), CFrame.new(-L / 4 - 0.5, bodyTop - 0.1, 0), COLORS.black)
	end
	if shape.police then
		part(model, "DoorBlack", Vector3.new(4, shape.body - 0.4, W + 0.05), CFrame.new(0.5, bodyBottom + shape.body / 2, 0), COLORS.black, Enum.Material.Metal)
		part(model, "LightbarR", Vector3.new(0.6, 0.35, 1.6), CFrame.new(cabinX, cabinTop + 0.3, -0.9), Color3.fromRGB(255, 30, 30), Enum.Material.Neon)
		part(model, "LightbarB", Vector3.new(0.6, 0.35, 1.6), CFrame.new(cabinX, cabinTop + 0.3, 0.9), Color3.fromRGB(30, 80, 255), Enum.Material.Neon)
	end
	-- seat (the driver sits here)
	local seatX = if shape.cabinBack then front - 1.6 else 0.9
	part(model, "Seat", Vector3.new(1.6, 0.4, 1.6), CFrame.new(seatX - 0.3, bodyBottom + 0.9, -1.5), COLORS.black)
	-- fake drop shadow that only shows on the Lane Cam (anomalies can lack it)
	local shadow = part(model, "CamShadow", Vector3.new(L + 1, 0.05, W + 1.2), CFrame.new(0, 0.08, 0), Color3.new(0, 0, 0), SMOOTH, { Transparency = 0.45, CastShadow = false })
	channel(shadow, "CamOnly")
	return CFrame.new(seatX, bodyBottom + 0.9, -1.5)
end

local function buildScooter(model: Model, color: Color3): CFrame
	part(model, "Deck", Vector3.new(4, 0.4, 1.2), CFrame.new(0, 1.2, 0), color, Enum.Material.Metal)
	part(model, "Stem", Vector3.new(0.3, 2.6, 0.3), CFrame.new(1.8, 2.6, 0), COLORS.chrome, Enum.Material.Metal)
	part(model, "Handlebar", Vector3.new(0.3, 0.3, 2), CFrame.new(1.8, 3.9, 0), COLORS.black)
	for _, x in { 1.6, -1.6 } do
		cylinder(model, "Wheel", 0.5, 1.4, CFrame.new(x, 0.7, 0) * CFrame.Angles(0, math.rad(90), 0), COLORS.tire)
	end
	part(model, "DeliveryBox", Vector3.new(1.8, 1.8, 1.8), CFrame.new(-1.4, 2.4, 0), color, SMOOTH)
	local box = part(model, "BoxLabel", Vector3.new(1.82, 1.2, 1.82), CFrame.new(-1.4, 2.4, 0), color, SMOOTH, { Transparency = 1 })
	surfaceText(box, Enum.NormalId.Front, "EATS", COLORS.white)
	local light = part(model, "Headlight", Vector3.new(0.3, 0.5, 0.5), CFrame.new(1.95, 3.4, 0), COLORS.headlight, Enum.Material.Neon)
	local spot = Instance.new("SpotLight")
	spot.Face = Enum.NormalId.Right
	spot.Range = 20
	spot.Brightness = 1.2
	spot.Parent = light
	local shadow = part(model, "CamShadow", Vector3.new(5, 0.05, 2.2), CFrame.new(0, 0.08, 0), Color3.new(0, 0, 0), SMOOTH, { Transparency = 0.45, CastShadow = false })
	channel(shadow, "CamOnly")
	return CFrame.new(0, 1.4, -0.4)
end

---------------------------------------------------------------------------
-- Customer (car + driver + tells)
---------------------------------------------------------------------------

local function hasModifier(modifiers: { string }, name: string): (boolean, string?)
	for _, m in modifiers do
		local key, arg = string.match(m, "^([^:]+):(.+)$")
		if m == name or key == name then
			return true, arg
		end
	end
	return false, nil
end
ModelFactory.hasModifier = hasModifier

local function buildMunchHeadInto(model: Model, at: CFrame, scale: number, knockoff: boolean, realMouth: boolean?)
	local s = scale
	local bunColor = if knockoff then Color3.fromRGB(235, 190, 120) else COLORS.bun
	cylinder(model, "BunBottom", 0.6 * s, 3.4 * s, at * CFrame.new(0, 0.3 * s, 0) * VERTICAL, bunColor)
	cylinder(model, "PattyLayer", 0.55 * s, 3.6 * s, at * CFrame.new(0, 0.85 * s, 0) * VERTICAL, COLORS.patty)
	if not knockoff then
		part(model, "CheeseLayer", Vector3.new(3.4 * s, 0.15 * s, 3.4 * s), at * CFrame.new(0, 1.15 * s, 0) * CFrame.Angles(0, math.rad(45), 0), COLORS.cheese)
	end
	cylinder(model, "Lettuce", 0.25 * s, 3.9 * s, at * CFrame.new(0, 1.25 * s, 0) * VERTICAL, COLORS.lettuce)
	local top = ball(model, "BunTop", Vector3.new(3.5 * s, 2.4 * s, 3.5 * s), at * CFrame.new(0, 2.1 * s, 0), bunColor)
	if not knockoff then
		for i = 1, 6 do
			local angle = i * math.pi / 3
			part(model, "Seed", Vector3.new(0.25, 0.1, 0.15) * s, at * CFrame.new(math.cos(angle) * 0.9 * s, 3.2 * s, math.sin(angle) * 0.9 * s), COLORS.white)
		end
	end
	-- face on the front (-Z) of the top bun
	local facePlate = part(model, "FacePlate", Vector3.new(2.6 * s, 1.6 * s, 0.05), at * CFrame.new(0, 2.0 * s, -1.72 * s), bunColor, SMOOTH, { Transparency = 1 })
	local gui = Instance.new("SurfaceGui")
	gui.Name = "MunchFace"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0.3
	gui.Parent = facePlate
	local canvas = ModelFactory.drawFace(gui, bunColor, { transparentBackground = true, mouthWidth = 0.7 })
	if realMouth then
		local mouth = canvas:FindFirstChild("Mouth") :: Frame
		mouth.BackgroundColor3 = Color3.fromRGB(40, 0, 10)
		mouth.Size = UDim2.fromScale(0.75, 0.3)
		for i = 1, 6 do
			frame(canvas, "Tooth" .. i, UDim2.fromScale(0.18 + i * 0.1, 0.63), UDim2.fromScale(0.07, 0.08), COLORS.white).ZIndex = 5
		end
	end
	if not knockoff then
		-- top hat + monocle
		cylinder(model, "HatBrim", 0.12 * s, 2.0 * s, at * CFrame.new(0.4 * s, 3.35 * s, 0) * VERTICAL, COLORS.black)
		cylinder(model, "HatTop", 1.3 * s, 1.3 * s, at * CFrame.new(0.4 * s, 4.0 * s, 0) * VERTICAL, COLORS.black)
		cylinder(model, "HatBand", 0.3 * s, 1.34 * s, at * CFrame.new(0.4 * s, 3.6 * s, 0) * VERTICAL, COLORS.ketchup)
		cylinder(model, "Monocle", 0.08, 0.8 * s, at * CFrame.new(0.55 * s, 2.25 * s, -1.75 * s) * CFrame.Angles(0, math.rad(90), 0), COLORS.mustard, Enum.Material.Metal, { Transparency = 0.2 })
	end
	return top
end

-- data: { person = spec, car = {kind,color}, modifiers = {...}, kidsCount? }
function ModelFactory.buildCustomer(data: { [string]: any }): Model
	local model, root = newModel("Customer")
	local modifiers = data.modifiers or {}
	local spec = data.person or {}
	local carKind = data.car and data.car.kind or "Sedan"
	local carColor = data.car and data.car.color or Color3.fromRGB(150, 150, 160)
	local seat: CFrame
	if carKind == "None" then
		seat = CFrame.new(0, 1.8, -2)
		-- on foot: legs under the torso
		part(model, "Legs", Vector3.new(1.8, 2, 0.9), seat * CFrame.new(0, -0.9, 0), Color3.fromRGB(40, 40, 60))
	elseif carKind == "Scooter" then
		seat = buildScooter(model, carColor)
	else
		seat = buildCarBody(model, carKind, carColor)
	end
	model:SetAttribute("CarKind", carKind)

	if hasModifier(modifiers, "NoShadowCam") then
		local shadow = model:FindFirstChild("CamShadow")
		if shadow then
			shadow:Destroy()
		end
	end

	local noDriver = hasModifier(modifiers, "NoDriver")
	local skin = spec.skin or Color3.fromRGB(224, 172, 105)
	local head: BasePart? = nil

	if not noDriver then
		if hasModifier(modifiers, "TrenchStack") then
			-- Window view: three stacked heads in one trench coat. Lane Cam: one very tall guy.
			local coat = part(model, "Coat", Vector3.new(2.3, 3.2, 1.3), seat * CFrame.new(0, 1.5, 0), Color3.fromRGB(140, 110, 70), Enum.Material.Fabric)
			channel(coat, "NotOnCam")
			local faces = { Color3.fromRGB(150, 150, 150), Color3.fromRGB(130, 130, 135), Color3.fromRGB(110, 110, 115) }
			for i = 1, 3 do
				local h = part(model, "StackHead" .. i, Vector3.new(1.3, 1.1, 1.3), seat * CFrame.new(0, 3.4 + (i - 1) * 1.05, 0), faces[i])
				faceGui(h, faces[i], { pupilColor = Color3.fromRGB(10, 10, 10) })
				part(model, "MaskStripe" .. i, Vector3.new(1.32, 0.3, 1.32), h.CFrame * CFrame.new(0, 0.15, 0), COLORS.black)
				channel(h, "NotOnCam")
				channel(model:FindFirstChild("MaskStripe" .. i) :: BasePart, "NotOnCam")
			end
			local tall = part(model, "TallGuy", Vector3.new(2, 5.5, 1.2), seat * CFrame.new(0, 2.6, 0), Color3.fromRGB(140, 110, 70), Enum.Material.Fabric)
			channel(tall, "CamOnly")
			local tallHead = part(model, "TallHead", Vector3.new(1.4, 1.4, 1.4), seat * CFrame.new(0, 6.1, 0), skin)
			channel(tallHead, "CamOnly")
			addHand(model, seat * CFrame.new(-0.5, 2.6, -1.9), Color3.fromRGB(130, 130, 135), 5)
		elseif hasModifier(modifiers, "Twins") then
			local kid = table.clone(spec)
			kid.kid = true
			ModelFactory.addPerson(model, seat * CFrame.new(-0.45, 0.2, 0), kid, { prefix = "Twin1" })
			ModelFactory.addPerson(model, seat * CFrame.new(0.45, 0.2, 0), kid, { prefix = "Twin2" })
			part(model, "BoosterSeat", Vector3.new(2, 0.6, 1.4), seat * CFrame.new(0, 0, 0), Color3.fromRGB(240, 200, 80))
			head = model:FindFirstChild("Twin1Head") :: BasePart
		elseif hasModifier(modifiers, "KnockoffMunch") then
			part(model, "Torso", Vector3.new(2.3, 2.1, 1.2), seat * CFrame.new(0, 1.05, 0), Color3.fromRGB(200, 40, 40))
			local headModel = Instance.new("Model")
			headModel.Name = "KnockoffHead"
			headModel.Parent = model
			buildMunchHeadInto(headModel, seat * CFrame.new(0, 2.1, 0), 0.6, true)
			addHand(model, seat * CFrame.new(-0.5, 2.4, -1.9), skin, 5, { glove = COLORS.glove, sleeve = Color3.fromRGB(200, 40, 40) })
		elseif hasModifier(modifiers, "Robot") then
			part(model, "Torso", Vector3.new(2.1, 2, 1.1), seat * CFrame.new(0, 1, 0), Color3.fromRGB(170, 170, 180), Enum.Material.Metal)
			local h = part(model, "Head", Vector3.new(1.8, 1.5, 1.5), seat * CFrame.new(0, 2.8, 0), Color3.fromRGB(200, 200, 210), Enum.Material.Metal)
			local gui = surfaceText(h, Enum.NormalId.Front, "◉ ◉\n▬", Color3.fromRGB(80, 255, 140), Enum.Font.Arcade, Color3.fromRGB(20, 30, 30))
			gui.Name = "RobotFace"
			part(model, "Antenna", Vector3.new(0.15, 1, 0.15), seat * CFrame.new(0, 4, 0), COLORS.chrome)
			addHand(model, seat * CFrame.new(-0.5, 2.4, -1.9), Color3.fromRGB(170, 170, 180), 3)
			head = h
		else
			local identical = hasModifier(modifiers, "IdenticalKids")
			local personSpec = table.clone(spec)
			if identical then
				personSpec.kid = true
			end
			local faceOpts = {}
			if hasModifier(modifiers, "LipstickHI") then
				faceOpts.teethText = "HI"
			end
			if hasModifier(modifiers, "GrowingSmile") then
				faceOpts.mouthWidth = 0.5
			end
			head = ModelFactory.addPerson(model, seat, personSpec, { face = faceOpts })
			local digits = 5
			local hasSeven = hasModifier(modifiers, "SevenFingers")
			if hasSeven then
				digits = 7
			end
			local hand = addHand(model, seat * CFrame.new(-0.6, 2.4, -1.9), skin, digits, {
				cast = hasModifier(modifiers, "Cast"),
				sleeve = spec.shirt,
			})
			if hasSeven then
				hand:SetAttribute("FingerCycle", true)
			end
			if hasModifier(modifiers, "ExtraEars") and head then
				part(model, "EarExtra", Vector3.new(0.3, 0.6, 0.4), head.CFrame * CFrame.new(0.98, 0.75, 0), skin)
				part(model, "EarExtra2", Vector3.new(0.3, 0.5, 0.35), head.CFrame * CFrame.new(1.05, -0.6, 0), skin)
			end
			if hasModifier(modifiers, "UpsideDownHat") and head then
				for _, name in { "Cap", "Brim" } do
					local p = model:FindFirstChild(name)
					if p and p:IsA("BasePart") then
						p.CFrame = head.CFrame * CFrame.new(0, 1.2, if name == "Brim" then -0.6 else 0) * CFrame.Angles(math.rad(180), 0, 0)
					end
				end
			end
			if hasModifier(modifiers, "CamPaintedFace") and head then
				local panel = part(model, "PaintedFace", Vector3.new(1.6, 1.6, 0.05), head.CFrame * CFrame.new(0, 0, -0.98), Color3.fromRGB(250, 235, 215), SMOOTH)
				local gui = Instance.new("SurfaceGui")
				gui.Face = Enum.NormalId.Front
				gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
				gui.PixelsPerStud = 60
				gui.LightInfluence = 0
				gui.Parent = panel
				ModelFactory.drawFace(gui, Color3.fromRGB(250, 235, 215), { mouthWidth = 0.8 })
				channel(panel, "CamOnly")
			end
			if hasModifier(modifiers, "StaticSkin") and head then
				head:SetAttribute("Static", true)
			end
		end
	end

	if head then
		head:SetAttribute("IsDriverHead", true)
		if not hasModifier(modifiers, "NeverBlinks") and not hasModifier(modifiers, "Robot") then
			head:SetAttribute("Blinks", true)
		end
		if hasModifier(modifiers, "GrowingSmile") then
			head:SetAttribute("GrowingSmile", true)
		end
	end

	-- Kids in the back of the minivan (the Hendersons)
	local hasKids, kidsArg = hasModifier(modifiers, "Kids")
	local identicalKids, identicalArg = hasModifier(modifiers, "IdenticalKids")
	local kidCount = tonumber(kidsArg or identicalArg or "0") or 0
	if (hasKids or identicalKids) and kidCount > 0 then
		local rng = Random.new(kidCount * 7 + 1)
		local tones = {
			Color3.fromRGB(224, 172, 105),
			Color3.fromRGB(198, 134, 66),
			Color3.fromRGB(255, 224, 189),
			Color3.fromRGB(161, 102, 50),
		}
		for i = 1, kidCount do
			local row = math.floor((i - 1) / 3)
			local col = (i - 1) % 3
			local kidSkin = if identicalKids then skin else tones[rng:NextInteger(1, #tones)]
			local h = part(model, "KidHead" .. i, Vector3.new(1.1, 1.1, 1.1), CFrame.new(-1.2 - row * 1.6, 3.9, -1.6 + col * 1.6), kidSkin)
			local mesh = Instance.new("SpecialMesh")
			mesh.MeshType = Enum.MeshType.Head
			mesh.Parent = h
			faceGui(h, kidSkin, if identicalKids then { mouthWidth = 0.5 } else nil)
		end
	end

	-- UV-only marks
	local hasTag, tagText = hasModifier(modifiers, "UVTag")
	if hasTag and tagText then
		local torso = model:FindFirstChild("Torso") :: BasePart?
		if torso then
			local tag = part(model, "UVTag", Vector3.new(1.4, 0.6, 0.05), torso.CFrame * CFrame.new(0, 0.3, -0.6), COLORS.uv, Enum.Material.Neon, { Transparency = 0.2 })
			surfaceText(tag, Enum.NormalId.Front, tagText, Color3.fromRGB(255, 255, 255), Enum.Font.Arcade)
			channel(tag, "UVOnly")
		end
	end
	local hasText, uvText = hasModifier(modifiers, "UVText")
	if hasText and uvText then
		local shape = CAR_SHAPES[carKind] or CAR_SHAPES.Sedan
		local door = part(model, "UVDoor", Vector3.new(5, 1.6, 0.05), CFrame.new(0, 2.0, -shape.width / 2 - 0.05), COLORS.uv, Enum.Material.Neon, { Transparency = 0.3 })
		surfaceText(door, Enum.NormalId.Front, uvText, Color3.fromRGB(255, 255, 255), Enum.Font.FredokaOne)
		channel(door, "UVOnly")
	end
	if hasModifier(modifiers, "UVHandprints") then
		for i = 1, 4 do
			local print_ = part(model, "UVHandprint", Vector3.new(0.1, 0.7, 0.55), CFrame.new(2.85, 3.6 + (i % 2) * 0.6, -2 + i * 0.9) * CFrame.Angles(0, 0, math.rad(15 * i)), COLORS.uv, Enum.Material.Neon, { Transparency = 0.2 })
			channel(print_, "UVOnly")
		end
	end

	root.Name = "Root"
	return finalize(model, false)
end

---------------------------------------------------------------------------
-- Mr. Munch (also the fiberglass statue, the bobblehead and the knockoffs)
---------------------------------------------------------------------------

-- opts: { anchored, scale, statue, realMouth, knockoff }
function ModelFactory.buildMunch(opts: { [string]: any }?): Model
	local o = opts or {}
	local s = o.scale or 1
	local model = newModel(if o.statue then "MunchStatue" else "MrMunch")
	local tux = if o.statue then Color3.fromRGB(200, 50, 50) else Color3.fromRGB(190, 30, 40)
	local glove = COLORS.glove
	-- shoes (squeak squeak)
	for _, x in { -0.8, 0.8 } do
		part(model, "Shoe", Vector3.new(1.4, 0.9, 2.6) * s, CFrame.new(x * s, 0.45 * s, -0.5 * s), COLORS.ketchup)
		part(model, "ShoeToe", Vector3.new(1.45, 0.5, 0.8) * s, CFrame.new(x * s, 0.6 * s, -1.6 * s), COLORS.white)
		part(model, "Leg", Vector3.new(0.9, 2.4, 0.9) * s, CFrame.new(x * s, 2.1 * s, 0), COLORS.black)
	end
	local torso = part(model, "Torso", Vector3.new(3, 3, 1.8) * s, CFrame.new(0, 4.8 * s, 0), tux)
	part(model, "Shirt", Vector3.new(1, 2.6, 0.1) * s, CFrame.new(0, 4.9 * s, -0.92 * s), COLORS.white)
	part(model, "BowTie", Vector3.new(1.2, 0.5, 0.2) * s, CFrame.new(0, 6.0 * s, -1 * s), COLORS.mustard)
	part(model, "PipingL", Vector3.new(0.15, 3, 0.12) * s, CFrame.new(-0.65 * s, 4.8 * s, -0.94 * s), COLORS.mustard, Enum.Material.Neon)
	part(model, "PipingR", Vector3.new(0.15, 3, 0.12) * s, CFrame.new(0.65 * s, 4.8 * s, -0.94 * s), COLORS.mustard, Enum.Material.Neon)
	for _, x in { -1.9, 1.9 } do
		part(model, "Arm", Vector3.new(0.85, 2.8, 0.85) * s, CFrame.new(x * s, 4.7 * s, 0), tux)
		ball(model, "Glove", Vector3.new(1.2, 1.2, 1.2) * s, CFrame.new(x * s, 3.1 * s, -0.1 * s), glove)
		for f = 1, 4 do
			part(model, "GloveFinger", Vector3.new(0.22, 0.6, 0.22) * s, CFrame.new((x + (f - 2.5) * 0.25) * s, 2.5 * s, -0.25 * s), glove)
		end
	end
	local headModel = Instance.new("Model")
	headModel.Name = "Head"
	headModel.Parent = model
	buildMunchHeadInto(headModel, CFrame.new(0, 6.3 * s, 0), s, o.knockoff == true, o.realMouth)
	model:SetAttribute("Height", 10 * s)
	torso:SetAttribute("IsTorso", true)
	return finalize(model, o.anchored)
end

---------------------------------------------------------------------------
-- Gizmo, the Fry-Bot 3000 (and its tiny fryer-basket ghost)
---------------------------------------------------------------------------

function ModelFactory.buildGizmo(opts: { [string]: any }?): Model
	local o = opts or {}
	local model = newModel("Gizmo")
	cylinder(model, "Base", 0.8, 3.4, CFrame.new(0, 0.4, 0) * VERTICAL, Color3.fromRGB(50, 50, 55))
	part(model, "Body", Vector3.new(2.4, 2.4, 2), CFrame.new(0, 2.0, 0), COLORS.chrome, Enum.Material.DiamondPlate)
	local screen = part(model, "Screen", Vector3.new(1.9, 1.3, 0.1), CFrame.new(0, 2.3, -1.05), Color3.fromRGB(20, 30, 30))
	local gui = surfaceText(screen, Enum.NormalId.Front, ":)", Color3.fromRGB(80, 255, 140), Enum.Font.Arcade, Color3.fromRGB(20, 30, 30))
	gui.Name = "ScreenGui"
	part(model, "Antenna", Vector3.new(0.12, 1.2, 0.12), CFrame.new(0.7, 3.8, 0), COLORS.chrome)
	ball(model, "AntennaTip", Vector3.new(0.4, 0.4, 0.4), CFrame.new(0.7, 4.45, 0), COLORS.ketchup, Enum.Material.Neon)
	part(model, "Arm", Vector3.new(0.3, 0.3, 1.6), CFrame.new(1.35, 2.2, -0.6), COLORS.chrome)
	part(model, "Basket", Vector3.new(1, 0.6, 0.9), CFrame.new(1.35, 2.0, -1.5), Color3.fromRGB(120, 120, 120), Enum.Material.DiamondPlate)
	local tag = part(model, "NameTag", Vector3.new(1.6, 0.4, 0.05), CFrame.new(0, 1.2, -1.03), COLORS.mustard)
	surfaceText(tag, Enum.NormalId.Front, "FRY-BOT 3000", COLORS.black, Enum.Font.GothamBold)
	return finalize(model, o.anchored)
end

function ModelFactory.buildGizmoGhost(): Model
	local model = newModel("GizmoGhost")
	part(model, "Basket", Vector3.new(1.2, 0.7, 1.1), CFrame.new(0, 2.5, 0), Color3.fromRGB(120, 120, 120), Enum.Material.DiamondPlate, { Transparency = 0.4 })
	ball(model, "Sheet", Vector3.new(1.8, 1.6, 1.8), CFrame.new(0, 3.2, 0), COLORS.white, SMOOTH).Transparency = 0.35
	for _, x in { -0.35, 0.35 } do
		part(model, "Eye", Vector3.new(0.18, 0.3, 0.05), CFrame.new(x, 3.35, -0.88), COLORS.black)
	end
	return finalize(model, false)
end

---------------------------------------------------------------------------
-- Shift Ghost sheet (welded over a booped player's body)
---------------------------------------------------------------------------

function ModelFactory.buildGhostSheet(color: Color3, hatColor: Color3?, name: string?): Model
	local model = newModel("ShiftGhost")
	local sheet = ball(model, "Sheet", Vector3.new(3.2, 4.4, 3.2), CFrame.new(0, 0.2, 0), color, SMOOTH)
	sheet.Transparency = 0.3
	cylinder(model, "Hem", 0.4, 3.4, CFrame.new(0, -1.7, 0) * VERTICAL, color, SMOOTH, { Transparency = 0.45 })
	for _, x in { -0.5, 0.5 } do
		local eye = ball(model, "Eye", Vector3.new(0.45, 0.7, 0.2), CFrame.new(x, 0.9, -1.5), COLORS.black)
		eye.Transparency = 0.1
	end
	local visor = part(model, "Visor", Vector3.new(2.6, 0.35, 2.4), CFrame.new(0, 2.25, -0.1), hatColor or COLORS.ketchup)
	visor.Transparency = 0.1
	part(model, "VisorBill", Vector3.new(2, 0.15, 1), CFrame.new(0, 2.15, -1.4), hatColor or COLORS.ketchup)
	if name then
		local tag = part(model, "Tag", Vector3.new(1.4, 0.45, 0.05), CFrame.new(0, -0.2, -1.55), COLORS.white)
		surfaceText(tag, Enum.NormalId.Front, name, COLORS.black, Enum.Font.GothamBold)
	end
	return finalize(model, false)
end

---------------------------------------------------------------------------
-- Food items (carried, bagged, on the grill)
---------------------------------------------------------------------------

function ModelFactory.buildStack(stack: { string }, toppingColors: { [string]: { color: Color3, height: number } }): Model
	local model, root = newModel("Stack")
	local y = 0
	for i, topping in stack do
		local info = toppingColors[topping]
		local height = if info then info.height else 0.2
		local color = if info then info.color else COLORS.white
		local diameter = if topping == "Cheese" then 1.9 elseif topping == "Lettuce" then 2.0 else 1.7
		local layerCf = CFrame.new(0, y + height / 2, 0)
		if topping == "Cheese" then
			part(model, "Layer" .. i, Vector3.new(1.6, height, 1.6), layerCf * CFrame.Angles(0, math.rad(45), 0), color)
		elseif topping == "BunTop" then
			ball(model, "Layer" .. i, Vector3.new(diameter, height * 1.6, diameter), CFrame.new(0, y + height * 0.4, 0), color)
		else
			cylinder(model, "Layer" .. i, height, diameter, layerCf * VERTICAL, color)
		end
		y += height
	end
	root.Size = Vector3.new(1.8, math.max(0.4, y), 1.8)
	root.CFrame = CFrame.new(0, 0, 0)
	return finalize(model, false)
end

function ModelFactory.buildItem(kind: string, data: { [string]: any }?): Model
	local d = data or {}
	local model: Model
	if kind == "Burger" and d.stack and d.toppings then
		model = ModelFactory.buildStack(d.stack, d.toppings)
		model.Name = "Burger"
		return model
	end
	local root
	model, root = newModel(kind)
	if kind == "Patty" then
		cylinder(model, "Patty", 0.4, 1.7, CFrame.new(0, 0.2, 0) * VERTICAL, d.color or COLORS.patty)
	elseif kind == "Fries" then
		part(model, "Carton", Vector3.new(1.1, 1.2, 0.7), CFrame.new(0, 0.6, 0), COLORS.ketchup)
		local label = part(model, "Logo", Vector3.new(0.8, 0.5, 0.05), CFrame.new(0, 0.6, -0.36), COLORS.mustard)
		label.Transparency = 0
		for i = 1, 6 do
			part(model, "Fry", Vector3.new(0.14, 0.9, 0.14), CFrame.new(-0.4 + i * 0.13, 1.4 + (i % 2) * 0.12, (i % 3 - 1) * 0.15), Color3.fromRGB(255, 214, 92))
		end
	elseif kind == "Drink" or kind == "Shake" then
		local cupColor = if kind == "Shake" then Color3.fromRGB(255, 185, 215) else COLORS.white
		cylinder(model, "Cup", 1.5, 0.95, CFrame.new(0, 0.75, 0) * VERTICAL, cupColor)
		cylinder(model, "Band", 0.4, 0.98, CFrame.new(0, 0.85, 0) * VERTICAL, COLORS.ketchup)
		if kind == "Shake" then
			ball(model, "Dome", Vector3.new(1, 0.6, 1), CFrame.new(0, 1.55, 0), Color3.fromRGB(250, 250, 255)).Transparency = 0.3
		else
			cylinder(model, "Lid", 0.1, 1.0, CFrame.new(0, 1.52, 0) * VERTICAL, COLORS.white)
		end
		part(model, "Straw", Vector3.new(0.12, 1.0, 0.12), CFrame.new(0.15, 1.9, 0) * CFrame.Angles(0, 0, math.rad(-10)), COLORS.ketchup)
	elseif kind == "Bag" then
		part(model, "Bag", Vector3.new(1.8, 2.1, 1.1), CFrame.new(0, 1.05, 0), Color3.fromRGB(196, 150, 100), Enum.Material.Cardboard)
		local logo = part(model, "Logo", Vector3.new(1.3, 0.8, 0.05), CFrame.new(0, 1.2, -0.56), COLORS.ketchup)
		surfaceText(logo, Enum.NormalId.Front, "M", COLORS.mustard)
	else
		part(model, "Thing", Vector3.new(1, 1, 1), CFrame.new(0, 0.5, 0), COLORS.white)
	end
	root.CFrame = CFrame.new()
	return finalize(model, false)
end

---------------------------------------------------------------------------
-- Weird-event props
---------------------------------------------------------------------------

function ModelFactory.buildRaccoon(): Model
	local model = newModel("Raccoon")
	part(model, "Body", Vector3.new(1.4, 1, 2.2), CFrame.new(0, 0.6, 0), Color3.fromRGB(120, 120, 125))
	local head = part(model, "Head", Vector3.new(1.1, 0.9, 1), CFrame.new(0, 1.0, -1.3), Color3.fromRGB(140, 140, 145))
	part(model, "Mask", Vector3.new(1.12, 0.3, 1.02), head.CFrame * CFrame.new(0, 0.1, 0), COLORS.black)
	for i = 0, 3 do
		part(model, "Tail", Vector3.new(0.45, 0.45, 0.5), CFrame.new(0, 0.9 + i * 0.1, 1.3 + i * 0.45), if i % 2 == 0 then COLORS.black else Color3.fromRGB(150, 150, 155))
	end
	for _, x in { -0.3, 0.3 } do
		part(model, "Eye", Vector3.new(0.15, 0.15, 0.05), head.CFrame * CFrame.new(x, 0.1, -0.53), COLORS.white, Enum.Material.Neon)
	end
	return finalize(model, false)
end

function ModelFactory.buildEar(): Part
	local p = Instance.new("Part")
	p.Name = "RainEar"
	p.Size = Vector3.new(0.5, 0.9, 0.3)
	p.Color = Color3.fromRGB(241, 194, 125)
	p.Material = SMOOTH
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
	return p
end

function ModelFactory.buildDoily(): Part
	local p = Instance.new("Part")
	p.Name = "Doily"
	p.Shape = Enum.PartType.Cylinder
	p.Size = Vector3.new(0.05, 1.8, 1.8)
	p.Color = Color3.fromRGB(250, 250, 250)
	p.Material = Enum.Material.Fabric
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	return p
end

function ModelFactory.buildStickyNote(text: string): Part
	local p = Instance.new("Part")
	p.Name = "StickyNote"
	p.Size = Vector3.new(1.4, 1.4, 0.05)
	p.Color = Color3.fromRGB(255, 240, 120)
	p.Anchored = true
	p.CanCollide = false
	surfaceText(p, Enum.NormalId.Front, text, Color3.fromRGB(40, 40, 40), Enum.Font.PatrickHand)
	return p
end

function ModelFactory.buildGoldStar(): Part
	local p = Instance.new("Part")
	p.Name = "GoldStar"
	p.Size = Vector3.new(1.2, 1.2, 0.05)
	p.Transparency = 1
	p.Anchored = true
	p.CanCollide = false
	surfaceText(p, Enum.NormalId.Top, "★", COLORS.mustard, Enum.Font.GothamBlack)
	return p
end

return ModelFactory
