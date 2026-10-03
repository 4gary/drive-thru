-- Builds the greybox Munchie's #001 (Exit 13, Route 404) plus the parking-lot lobby.
-- Design doc §6.3 layout. Pure Instance code (no services) so it can run at build time in Lune
-- (the result is saved into the place file) or at runtime if the map is missing.

local Layout = require(script.Parent.Layout)
local ModelFactory = require(script.Parent.ModelFactory)

local MapBuilder = {}

local H = Layout.WallHeight
local F = Layout.Floor

local C = {
	ketchup = Color3.fromRGB(215, 38, 61),
	mustard = Color3.fromRGB(244, 180, 0),
	pickle = Color3.fromRGB(106, 153, 78),
	bun = Color3.fromRGB(233, 196, 106),
	navy = Color3.fromRGB(29, 45, 80),
	wall = Color3.fromRGB(240, 230, 210),
	wallOut = Color3.fromRGB(200, 60, 50),
	trim = Color3.fromRGB(244, 180, 0),
	floor = Color3.fromRGB(236, 226, 206),
	hall = Color3.fromRGB(200, 200, 205),
	steel = Color3.fromRGB(190, 192, 196),
	darkSteel = Color3.fromRGB(80, 82, 88),
	laminate = Color3.fromRGB(250, 245, 235),
	counterBody = Color3.fromRGB(196, 60, 50),
	asphalt = Color3.fromRGB(45, 45, 50),
	lot = Color3.fromRGB(55, 55, 60),
	grass = Color3.fromRGB(50, 78, 44),
	corn = Color3.fromRGB(120, 140, 50),
	white = Color3.fromRGB(245, 245, 245),
	black = Color3.fromRGB(25, 25, 28),
	glass = Color3.fromRGB(150, 190, 215),
	warmLight = Color3.fromRGB(255, 240, 210),
	sodium = Color3.fromRGB(255, 165, 80),
	wood = Color3.fromRGB(150, 105, 65),
}
MapBuilder.Colors = C

---------------------------------------------------------------------------
-- helpers
---------------------------------------------------------------------------

local function folder(parent: Instance, name: string): Folder
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

local function block(parent: Instance, name: string, minV: Vector3, maxV: Vector3, color: Color3, material: Enum.Material?, props: { [string]: any }?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = Vector3.new(math.abs(maxV.X - minV.X), math.abs(maxV.Y - minV.Y), math.abs(maxV.Z - minV.Z))
	p.CFrame = CFrame.new((minV + maxV) / 2)
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if props then
		for key, value in props do
			(p :: any)[key] = value
		end
	end
	p.Parent = parent
	return p
end

local function at(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?, props: { [string]: any }?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if props then
		for key, value in props do
			(p :: any)[key] = value
		end
	end
	p.Parent = parent
	return p
end

local function cyl(parent: Instance, name: string, length: number, diameter: number, cf: CFrame, color: Color3, material: Enum.Material?): Part
	local p = at(parent, name, Vector3.new(length, diameter, diameter), cf, color, material)
	p.Shape = Enum.PartType.Cylinder
	return p
end

local UPRIGHT = CFrame.Angles(0, 0, math.rad(90))

local function sign(p: BasePart, face: Enum.NormalId, text: string, opts: { [string]: any }?): SurfaceGui
	local o = opts or {}
	local gui = Instance.new("SurfaceGui")
	gui.Name = o.name or "Sign"
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = o.ppu or 30
	gui.LightInfluence = o.lightInfluence or 0
	gui.Brightness = o.brightness or 1
	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = if o.background then 0 else 1
	label.BackgroundColor3 = o.background or Color3.new(0, 0, 0)
	label.Text = text
	label.TextColor3 = o.color or C.white
	label.TextScaled = true
	label.TextWrapped = true
	label.Font = o.font or Enum.Font.FredokaOne
	label.TextXAlignment = o.align or Enum.TextXAlignment.Center
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0.04, 0)
	pad.PaddingRight = UDim.new(0.04, 0)
	pad.PaddingTop = UDim.new(0.04, 0)
	pad.PaddingBottom = UDim.new(0.04, 0)
	pad.Parent = label
	label.Parent = gui
	gui.Parent = p
	return gui
end

local function pointLight(p: BasePart, color: Color3, range: number, brightness: number, enabled: boolean?): PointLight
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = range
	light.Brightness = brightness
	light.Shadows = false
	light.Enabled = if enabled == nil then true else enabled
	light.Parent = p
	return light
end

-- Wall along X (fixed Z band [z0,z1]) from x0 to x1 with rectangular holes {x0,x1,y0,y1}.
local function wallX(parent: Instance, name: string, z0: number, z1: number, x0: number, x1: number, holes: { { number } }, color: Color3, material: Enum.Material?, height: number?)
	local h = height or H
	local cuts = { x0, x1 }
	for _, hole in holes do
		table.insert(cuts, hole[1])
		table.insert(cuts, hole[2])
	end
	table.sort(cuts)
	for i = 1, #cuts - 1 do
		local a, b = cuts[i], cuts[i + 1]
		if b - a > 0.01 then
			local mid = (a + b) / 2
			local covering = nil
			for _, hole in holes do
				if mid > hole[1] and mid < hole[2] then
					covering = hole
				end
			end
			if not covering then
				block(parent, name, Vector3.new(a, 0, z0), Vector3.new(b, h, z1), color, material)
			else
				if covering[3] > 0.01 then
					block(parent, name, Vector3.new(a, 0, z0), Vector3.new(b, covering[3], z1), color, material)
				end
				if covering[4] < h - 0.01 then
					block(parent, name, Vector3.new(a, covering[4], z0), Vector3.new(b, h, z1), color, material)
				end
			end
		end
	end
end

-- Wall along Z (fixed X band [x0,x1]) from z0 to z1 with holes {z0,z1,y0,y1}.
local function wallZ(parent: Instance, name: string, x0: number, x1: number, z0: number, z1: number, holes: { { number } }, color: Color3, material: Enum.Material?, height: number?)
	local h = height or H
	local cuts = { z0, z1 }
	for _, hole in holes do
		table.insert(cuts, hole[1])
		table.insert(cuts, hole[2])
	end
	table.sort(cuts)
	for i = 1, #cuts - 1 do
		local a, b = cuts[i], cuts[i + 1]
		if b - a > 0.01 then
			local mid = (a + b) / 2
			local covering = nil
			for _, hole in holes do
				if mid > hole[1] and mid < hole[2] then
					covering = hole
				end
			end
			if not covering then
				block(parent, name, Vector3.new(x0, 0, a), Vector3.new(x1, h, b), color, material)
			else
				if covering[3] > 0.01 then
					block(parent, name, Vector3.new(x0, 0, a), Vector3.new(x1, covering[3], b), color, material)
				end
				if covering[4] < h - 0.01 then
					block(parent, name, Vector3.new(x0, covering[4], a), Vector3.new(x1, h, b), color, material)
				end
			end
		end
	end
end

local function counter(parent: Instance, name: string, x0: number, x1: number, z0: number, z1: number, top: Color3, body: Color3, topMaterial: Enum.Material?)
	block(parent, name .. "Body", Vector3.new(x0, F, z0 + 0.3), Vector3.new(x1, Layout.FrontCounter.top - 0.2, z1), body)
	return block(parent, name .. "Top", Vector3.new(x0 - 0.1, Layout.FrontCounter.top - 0.2, z0), Vector3.new(x1 + 0.1, Layout.FrontCounter.top, z1 + 0.1), top, topMaterial)
end

local function lamp(parent: Instance, position: Vector3, height: number?)
	local h = height or 18
	at(parent, "LampPole", Vector3.new(0.6, h, 0.6), CFrame.new(position + Vector3.new(0, h / 2, 0)), C.darkSteel, Enum.Material.Metal)
	local head = at(parent, "LampHead", Vector3.new(2.4, 0.6, 1.2), CFrame.new(position + Vector3.new(0, h, 0)), C.sodium, Enum.Material.Neon)
	head:AddTag("ExteriorLight")
	pointLight(head, C.sodium, 50, 1.6)
end

---------------------------------------------------------------------------
-- sections
---------------------------------------------------------------------------

local function buildGround(root: Instance)
	local g = folder(root, "Ground")
	block(g, "Grass", Vector3.new(-600, -2, -600), Vector3.new(600, 0, 600), C.grass, Enum.Material.Grass)
	-- drive-thru lane
	local laneMin = Layout.LaneZ - 6
	local laneMax = Layout.LaneZ + 6
	block(g, "Lane", Vector3.new(Layout.LaneStartX - 10, 0, laneMin), Vector3.new(Layout.LaneEndX + 10, 0.06, laneMax), C.asphalt, Enum.Material.Asphalt)
	block(g, "LaneCurb", Vector3.new(Layout.LaneStartX - 10, 0, laneMax), Vector3.new(Layout.LaneEndX + 10, 0.5, laneMax + 0.8), C.mustard, Enum.Material.Concrete)
	for x = Layout.LaneStartX, Layout.LaneEndX, 30 do
		local arrow = at(g, "LaneArrow", Vector3.new(5, 0.08, 3), CFrame.new(x, 0.07, Layout.LaneZ), C.white, Enum.Material.SmoothPlastic, { Transparency = 1 })
		sign(arrow, Enum.NormalId.Top, "→", { color = Color3.fromRGB(230, 230, 230), ppu = 20 })
	end
	-- lane entrance / exit to Route 404
	block(g, "LaneEntry", Vector3.new(Layout.LaneStartX - 20, 0, laneMin), Vector3.new(Layout.LaneStartX - 6, 0.06, Layout.RoadZ - 8), C.asphalt, Enum.Material.Asphalt)
	block(g, "LaneExit", Vector3.new(Layout.LaneEndX + 6, 0, laneMin), Vector3.new(Layout.LaneEndX + 20, 0.06, Layout.RoadZ - 8), C.asphalt, Enum.Material.Asphalt)
	-- Route 404
	block(g, "Route404", Vector3.new(-600, 0, Layout.RoadZ - 10), Vector3.new(600, 0.06, Layout.RoadZ + 10), C.asphalt, Enum.Material.Asphalt)
	for x = -590, 590, 24 do
		at(g, "Dash", Vector3.new(10, 0.08, 0.5), CFrame.new(x, 0.08, Layout.RoadZ), C.mustard, Enum.Material.SmoothPlastic)
	end
	local routeSign = at(g, "RouteSign", Vector3.new(6, 4, 0.3), CFrame.new(-150, 9, Layout.RoadZ - 13), Color3.fromRGB(30, 110, 60))
	at(g, "RouteSignPole", Vector3.new(0.4, 9, 0.4), CFrame.new(-150, 4.5, Layout.RoadZ - 13), C.darkSteel, Enum.Material.Metal)
	sign(routeSign, Enum.NormalId.Back, "ROUTE 404\nEXIT 13", { color = C.white })
	sign(routeSign, Enum.NormalId.Front, "LOWER DIMMSWORTH\n3 mi", { color = C.white })
	-- cornfield
	for i = 0, 11 do
		local z = Layout.RoadZ + 18 + i * 7
		block(g, "CornRow", Vector3.new(-600, 0, z), Vector3.new(600, 7 + (i % 3), z + 3), C.corn, Enum.Material.Grass)
	end
	-- blinking yellow traffic light
	at(g, "TrafficPole", Vector3.new(0.6, 16, 0.6), CFrame.new(-120, 8, Layout.RoadZ - 11), C.darkSteel, Enum.Material.Metal)
	at(g, "TrafficArm", Vector3.new(0.4, 0.4, 11), CFrame.new(-120, 16, Layout.RoadZ - 5.5), C.darkSteel, Enum.Material.Metal)
	local blink = at(g, "BlinkLight", Vector3.new(1.4, 1.4, 1.4), CFrame.new(-120, 15, Layout.RoadZ), C.mustard, Enum.Material.Neon)
	blink:AddTag("BlinkLight")
	pointLight(blink, C.mustard, 20, 2)
	-- water tower
	local wt = folder(g, "WaterTower")
	for _, offset in { Vector3.new(-5, 0, -5), Vector3.new(5, 0, -5), Vector3.new(-5, 0, 5), Vector3.new(5, 0, 5) } do
		at(wt, "Leg", Vector3.new(1, 40, 1), CFrame.new(Layout.WaterTower + offset + Vector3.new(0, 20, 0)), C.steel, Enum.Material.Metal)
	end
	local tank = cyl(wt, "Tank", 14, 18, CFrame.new(Layout.WaterTower + Vector3.new(0, 46, 0)) * UPRIGHT, Color3.fromRGB(170, 190, 200), Enum.Material.Metal)
	tank.Name = "Tank"
	local banner = at(wt, "Banner", Vector3.new(16, 5, 0.2), CFrame.new(Layout.WaterTower + Vector3.new(0, 46, -9.2)), Color3.fromRGB(170, 190, 200), Enum.Material.Metal, { Transparency = 1 })
	sign(banner, Enum.NormalId.Front, "LOWER DIMMSWORTH: WE'RE STILL HERE", { color = C.navy })
end

local function buildShell(root: Instance)
	local b = folder(root, "Building")
	local B = Layout.Building
	-- floors
	block(b, "KitchenFloor", Vector3.new(B.minX, 0, Layout.KitchenZ.min), Vector3.new(B.maxX, F, B.maxZ), C.floor, Enum.Material.CeramicTiles)
	block(b, "HallFloor", Vector3.new(B.minX, 0, Layout.HallZ.min), Vector3.new(B.maxX, F, Layout.HallZ.max), C.hall, Enum.Material.CeramicTiles)
	local roomFloors = {
		Freezer = { Color3.fromRGB(200, 225, 235), Enum.Material.DiamondPlate },
		Storage = { Color3.fromRGB(150, 150, 150), Enum.Material.Concrete },
		Office = { Color3.fromRGB(120, 85, 60), Enum.Material.Carpet },
		BreakRoom = { Color3.fromRGB(170, 120, 75), Enum.Material.WoodPlanks },
		Bathroom = { Color3.fromRGB(190, 220, 230), Enum.Material.CeramicTiles },
	}
	for roomName, room in Layout.Rooms do
		local look = roomFloors[roomName]
		block(b, roomName .. "Floor", Vector3.new(room.minX, 0, B.minZ), Vector3.new(room.maxX, F, Layout.RoomZ.max), look[1], look[2])
	end
	local P = Layout.PlayPlace
	block(b, "PlayPlaceFloor", Vector3.new(P.minX, 0, P.minZ), Vector3.new(P.maxX, F, P.maxZ), Color3.fromRGB(90, 60, 140), Enum.Material.Carpet)

	-- outer walls
	local W = Layout.FrontWindows
	local PW = Layout.PickupWindow
	wallX(b, "FrontWall", B.maxZ, B.maxZ + 1, B.minX - 1, B.maxX + 1, {
		{ -50, 40, W.minY, W.maxY },
		{ PW.minX, PW.maxX, PW.minY, PW.maxY },
	}, C.wallOut, Enum.Material.Brick)
	block(b, "FrontGlass", Vector3.new(-50, W.minY, B.maxZ + 0.4), Vector3.new(40, W.maxY, B.maxZ + 0.6), C.glass, Enum.Material.Glass, { Transparency = 0.75, CastShadow = false })
	block(b, "WindowSill", Vector3.new(-50.2, W.minY - 0.3, B.maxZ - 0.3), Vector3.new(40.2, W.minY, B.maxZ + 1.3), C.trim)
	-- invisible barrier in the pickup window opening (players can't climb out; raycasts pass)
	block(b, "PickupBarrier", Vector3.new(PW.minX, PW.minY, B.maxZ + 0.3), Vector3.new(PW.maxX, PW.maxY, B.maxZ + 0.7), C.glass, Enum.Material.Glass, { Transparency = 1, CanQuery = false, CastShadow = false })
	wallX(b, "BackWall", B.minZ - 1, B.minZ, B.minX - 1, B.maxX + 1, {}, C.wallOut, Enum.Material.Brick)
	wallZ(b, "LeftWall", B.minX - 1, B.minX, B.minZ, B.maxZ, {
		{ Layout.HallZ.min, Layout.HallZ.max, 0, 9 },
	}, C.wall, Enum.Material.Plaster)
	wallZ(b, "RightWall", B.maxX, B.maxX + 1, B.minZ, B.maxZ, {}, C.wallOut, Enum.Material.Brick)

	-- inner walls
	local doorHoles = {}
	for _, x in Layout.KitchenDoorsX do
		table.insert(doorHoles, { x - Layout.DoorWidth / 2, x + Layout.DoorWidth / 2, 0, 9 })
	end
	wallX(b, "KitchenBackWall", Layout.KitchenZ.min - 0.5, Layout.KitchenZ.min + 0.5, B.minX, B.maxX, doorHoles, C.wall, Enum.Material.Plaster)
	local roomDoors = {}
	for _, roomName in Layout.RoomOrder do
		local room = Layout.Rooms[roomName]
		local cx = (room.minX + room.maxX) / 2
		if roomName ~= "Freezer" then
			table.insert(roomDoors, { cx - 3, cx + 3, 0, 9 })
		end
	end
	wallX(b, "HallBackWall", Layout.HallZ.min - 0.5, Layout.HallZ.min + 0.5, B.minX, B.maxX, roomDoors, C.wall, Enum.Material.Plaster)
	for _, x in { -34, -12, 10, 34 } do
		wallZ(b, "RoomWall", x - 0.5, x + 0.5, B.minZ, Layout.RoomZ.max - 0.5, {}, C.wall, Enum.Material.Plaster)
	end

	-- PlayPlace wing
	wallX(b, "PlayFront", P.maxZ, P.maxZ + 1, P.minX - 1, P.maxX, { { P.minX + 4, P.maxX - 4, 3, 13 } }, C.wallOut, Enum.Material.Brick)
	block(b, "PlayFrontGlass", Vector3.new(P.minX + 4, 3, P.maxZ + 0.4), Vector3.new(P.maxX - 4, 13, P.maxZ + 0.6), C.glass, Enum.Material.Glass, { Transparency = 0.7 })
	wallX(b, "PlayBack", P.minZ - 1, P.minZ, P.minX - 1, P.maxX, {}, C.wallOut, Enum.Material.Brick)
	wallZ(b, "PlaySide", P.minX - 1, P.minX, P.minZ, P.maxZ, { { -40, 4, 3, 13 } }, C.wallOut, Enum.Material.Brick)
	block(b, "PlaySideGlass", Vector3.new(P.minX - 0.6, 3, -40), Vector3.new(P.minX - 0.4, 13, 4), C.glass, Enum.Material.Glass, { Transparency = 0.7 })

	-- ceilings + roof
	block(b, "Ceiling", Vector3.new(B.minX - 1, H, B.minZ - 1), Vector3.new(B.maxX + 1, H + 1, B.maxZ + 1), Color3.fromRGB(235, 235, 230))
	block(b, "PlayCeiling", Vector3.new(P.minX - 1, H, P.minZ - 1), Vector3.new(P.maxX, H + 1, P.maxZ + 1), Color3.fromRGB(60, 40, 90))
	block(b, "RoofTrim", Vector3.new(P.minX - 1.5, H + 1, B.maxZ + 0.5), Vector3.new(B.maxX + 1.5, H + 2.5, B.maxZ + 1.5), C.mustard)
	local roofSign = at(b, "RoofSign", Vector3.new(44, 7, 1), CFrame.new(0, H + 6, B.maxZ + 0.5), C.ketchup, Enum.Material.SmoothPlastic)
	sign(roofSign, Enum.NormalId.Back, "MUNCHIE'S", { color = C.mustard, ppu = 12 })
	pointLight(roofSign, C.ketchup, 30, 1)
	local backSign = at(b, "BackSign", Vector3.new(36, 6, 1), CFrame.new(0, H - 4, B.minZ - 1.6), C.ketchup)
	sign(backSign, Enum.NormalId.Front, "MUNCHIE'S #001 — CREW ENTRANCE", { color = C.mustard, ppu = 12 })
	-- awning over the pickup window
	at(b, "Awning", Vector3.new(10, 0.4, 4), CFrame.new(48, 9.5, B.maxZ + 3) * CFrame.Angles(math.rad(-12), 0, 0), C.ketchup)
	local pickupSign = at(b, "PickupSign", Vector3.new(8, 1.6, 0.3), CFrame.new(48, 11, B.maxZ + 1.2), C.mustard)
	sign(pickupSign, Enum.NormalId.Back, "PICK UP HERE", { color = C.ketchup })
end

local function buildLights(root: Instance)
	local lights = folder(root, "Lights")
	local function fixture(position: Vector3, zone: string, range: number?)
		local p = at(lights, "CeilingLight", Vector3.new(6, 0.3, 2), CFrame.new(position), C.warmLight, Enum.Material.Neon)
		p:AddTag("InteriorLight")
		p:SetAttribute("Zone", zone)
		pointLight(p, C.warmLight, range or 24, 1.15)
	end
	for _, x in { -48, -32, -16, 0, 16, 32, 48 } do
		fixture(Vector3.new(x, H - 0.3, -5), "Kitchen")
		fixture(Vector3.new(x, H - 0.3, 6), "Kitchen")
	end
	for _, x in { -42, -14, 14, 42 } do
		fixture(Vector3.new(x, H - 0.3, -18), "Hall", 18)
	end
	for roomName, room in Layout.Rooms do
		if roomName ~= "Freezer" then
			fixture(Vector3.new((room.minX + room.maxX) / 2, H - 0.3, -35), roomName, 22)
		end
	end
	-- the PlayPlace is dark (one dim night light) until Night 3's "the light is on. It shouldn't be."
	local night = at(lights, "PlayNightLight", Vector3.new(1, 0.4, 1), CFrame.new(-76, H - 0.3, -20), Color3.fromRGB(120, 100, 200), Enum.Material.Neon)
	pointLight(night, Color3.fromRGB(110, 90, 200), 30, 0.5)
	local playLight = at(lights, "PlayPlaceLight", Vector3.new(6, 0.3, 2), CFrame.new(-76, H - 0.3, -5), C.warmLight, Enum.Material.SmoothPlastic)
	pointLight(playLight, C.warmLight, 40, 1.4, false)
end

local function buildKitchen(root: Instance)
	local k = folder(root, "Kitchen")
	local FC = Layout.FrontCounter
	local S = Layout.Stations
	local z0, z1 = FC.minZ, FC.maxZ

	-- front counter run
	counter(k, "OrderCounter", -55.5, -36, z0, z1, C.laminate, C.counterBody)
	counter(k, "GrillCounter", -35, -18.6, z0, z1, C.steel, C.darkSteel, Enum.Material.DiamondPlate)
	counter(k, "AssemblyCounter", -18.4, 0, z0, z1, C.laminate, C.counterBody)
	counter(k, "FryBinCounter", 10.6, 17, z0, z1, C.steel, C.darkSteel, Enum.Material.DiamondPlate)
	counter(k, "DrinkCounter", 17.2, 27.6, z0, z1, C.laminate, C.counterBody)
	counter(k, "BagCounterRun", 27.8, 43.8, z0, z1, C.laminate, C.counterBody)
	counter(k, "WindowLedgeRun", 44, 52.6, z0, z1 + 1, C.laminate, C.counterBody)
	counter(k, "EndCounter", 52.8, 55.5, z0, z1, C.laminate, C.counterBody)
	-- back counter (prep / supplies)
	for _, range in { { -34, -6 }, { 6, 34 } } do
		block(k, "BackCounterBody", Vector3.new(range[1], F, Layout.BackCounter.minZ), Vector3.new(range[2], 3.4, Layout.BackCounter.maxZ), C.darkSteel)
		block(k, "BackCounterTop", Vector3.new(range[1] - 0.1, 3.4, Layout.BackCounter.minZ), Vector3.new(range[2] + 0.1, 3.6, Layout.BackCounter.maxZ + 0.1), C.steel, Enum.Material.DiamondPlate)
		for x = range[1] + 3, range[2] - 3, 6 do
			at(k, "SupplyBox", Vector3.new(2.4, 1.8, 2), CFrame.new(x, 4.5, Layout.BackCounter.minZ + 1.5), Color3.fromRGB(196, 150, 100), Enum.Material.Cardboard)
		end
	end

	-- ORDER STATION: CRT + headset + receipt printer
	at(k, "OrderConsole", Vector3.new(3.4, 2.6, 2.6), CFrame.new(S.OrderConsole), Color3.fromRGB(225, 215, 190))
	local screen = at(k, "OrderScreen", Vector3.new(2.6, 1.9, 0.1), CFrame.new(S.OrderConsole + Vector3.new(0, 0.1, -1.32)), Color3.fromRGB(20, 40, 25), Enum.Material.Neon)
	sign(screen, Enum.NormalId.Front, "MUNCHIE'S POS v1.987\n> TAKE ORDER_", { color = Color3.fromRGB(90, 255, 120), font = Enum.Font.Arcade, ppu = 60, name = "Screen" })
	at(k, "Headset", Vector3.new(1.2, 0.3, 1), CFrame.new(-43, 3.75, 8.2), C.black)
	at(k, "ReceiptPrinter", Vector3.new(1.6, 0.9, 1.6), CFrame.new(S.ReceiptPrinter), Color3.fromRGB(60, 60, 65))
	at(k, "ReceiptPaper", Vector3.new(1, 0.05, 1.4), CFrame.new(S.ReceiptPrinter + Vector3.new(0, 0.3, -1.2)), C.white)
	local orderSign = at(k, "OrderSign", Vector3.new(6, 1.2, 0.2), CFrame.new(-46, 8.2, 11.6), C.mustard)
	sign(orderSign, Enum.NormalId.Front, "ORDER STATION", { color = C.ketchup })

	-- GRILL LINE
	at(k, "Grill", Vector3.new(12, 0.3, 3.4), CFrame.new(S.Grill), Color3.fromRGB(40, 40, 42), Enum.Material.DiamondPlate)
	at(k, "GrillHood", Vector3.new(13, 2, 4), CFrame.new(S.Grill + Vector3.new(0, 7.2, 0.6)), C.steel, Enum.Material.Metal)
	local pattyBox = at(k, "PattyBox", Vector3.new(2.2, 1, 1.8), CFrame.new(S.PattyBox), Color3.fromRGB(196, 150, 100), Enum.Material.Cardboard)
	sign(pattyBox, Enum.NormalId.Front, "PATTIES", { color = C.ketchup, ppu = 40 })
	local grillSign = at(k, "GrillSign", Vector3.new(5, 1.2, 0.2), CFrame.new(-26, 9.8, 10.6), C.mustard)
	sign(grillSign, Enum.NormalId.Front, "GRILL", { color = C.ketchup })

	-- ASSEMBLY BOARD
	at(k, "CuttingBoard", Vector3.new(5, 0.15, 3.2), CFrame.new(-10, FC.top + 0.07, 8.4), Color3.fromRGB(230, 200, 150), Enum.Material.Wood)
	local plate = at(k, "AssemblyPlate", Vector3.new(0.15, 2.4, 2.4), CFrame.new(S.AssemblyPlate) * UPRIGHT, C.white)
	plate.Shape = Enum.PartType.Cylinder
	local bins = {
		{ "Bun", Color3.fromRGB(222, 170, 98) },
		{ "Cheese", Color3.fromRGB(255, 205, 40) },
		{ "Lettuce", Color3.fromRGB(110, 190, 70) },
		{ "Pickles", Color3.fromRGB(80, 130, 50) },
		{ "Sauce", Color3.fromRGB(220, 50, 40) },
	}
	for i, bin in bins do
		local x = -15 + (i - 1) * 1.9
		at(k, "Bin" .. bin[1], Vector3.new(1.6, 0.5, 1.2), CFrame.new(x, FC.top + 0.25, 10), C.steel, Enum.Material.Metal)
		at(k, "BinFill", Vector3.new(1.4, 0.2, 1.0), CFrame.new(x, FC.top + 0.45, 10), bin[2])
		local tag = at(k, "BinTag", Vector3.new(1.6, 0.5, 0.05), CFrame.new(x, FC.top + 0.25, 9.37), C.white)
		sign(tag, Enum.NormalId.Front, string.upper(bin[1]), { color = C.black, font = Enum.Font.GothamBold, ppu = 60 })
	end
	at(k, "UnderCounterDoor", Vector3.new(3, 2.6, 0.15), CFrame.new(-14.5, 1.65, z0 + 0.22), Color3.fromRGB(170, 45, 40))
	at(k, "CabinetHandle", Vector3.new(0.8, 0.15, 0.15), CFrame.new(-14.5, 2.5, z0 + 0.1), C.steel, Enum.Material.Metal)
	at(k, "Napkin", Vector3.new(1, 1.2, 0.8), CFrame.new(S.Napkin), C.white)
	local assemblySign = at(k, "AssemblySign", Vector3.new(6, 1.2, 0.2), CFrame.new(-10, 9.8, 10.6), C.mustard)
	sign(assemblySign, Enum.NormalId.Front, "BUILD BURGERS", { color = C.ketchup })

	-- FRYERS + fry bin
	for i, pos in S.Fryers do
		block(k, "Fryer" .. i, Vector3.new(pos.X - 2.2, F, z0 + 0.3), Vector3.new(pos.X + 2.2, FC.top, z1), C.steel, Enum.Material.Metal)
		at(k, "FryerOil" .. i, Vector3.new(3.6, 0.1, 3), CFrame.new(pos.X, FC.top + 0.02, 8.5), Color3.fromRGB(200, 160, 40), Enum.Material.Glass, { Transparency = 0.2 })
		at(k, "FryerBasket" .. i, Vector3.new(2.6, 0.8, 2.2), CFrame.new(pos.X, FC.top + 0.9, 8.5), Color3.fromRGB(120, 120, 120), Enum.Material.DiamondPlate)
		local label = at(k, "FryerLabel" .. i, Vector3.new(3, 0.8, 0.05), CFrame.new(pos.X, 2.4, z0 + 0.27), C.mustard)
		sign(label, Enum.NormalId.Front, "FRYER " .. i, { color = C.black, font = Enum.Font.GothamBold, ppu = 40 })
	end
	at(k, "FryBin", Vector3.new(4, 0.8, 3), CFrame.new(S.FryBin), C.steel, Enum.Material.Metal)
	local heatLamp = at(k, "HeatLamp", Vector3.new(4, 0.5, 1.5), CFrame.new(S.FryBin + Vector3.new(0, 4, 0.5)), Color3.fromRGB(255, 80, 40), Enum.Material.Neon)
	pointLight(heatLamp, Color3.fromRGB(255, 120, 60), 8, 0.8)
	cyl(k, "Extinguisher", 1.8, 0.7, CFrame.new(S.Extinguisher) * UPRIGHT, C.ketchup, Enum.Material.Metal)
	local frySign = at(k, "FrySign", Vector3.new(7, 1.2, 0.2), CFrame.new(8, 9.8, 10.6), C.mustard)
	sign(frySign, Enum.NormalId.Front, "FRIES", { color = C.ketchup })

	-- DRINKS
	local soda = at(k, "SodaFountain", Vector3.new(3.4, 3, 2.4), CFrame.new(S.SodaFountain + Vector3.new(0, 0.5, 0)), Color3.fromRGB(70, 120, 200))
	sign(soda, Enum.NormalId.Front, "SODA", { color = C.white })
	local shake = at(k, "ShakeMachine", Vector3.new(3.4, 3.4, 2.4), CFrame.new(S.ShakeMachine + Vector3.new(0, 0.7, 0)), Color3.fromRGB(240, 150, 190))
	sign(shake, Enum.NormalId.Front, "SHAKES", { color = C.white })

	-- BAG & WINDOW
	at(k, "BagCounter", Vector3.new(12, 0.2, 3.4), CFrame.new(S.BagCounter + Vector3.new(0, -0.3, 0)), Color3.fromRGB(255, 250, 240))
	local bagSign = at(k, "BagSign", Vector3.new(8, 1.2, 0.2), CFrame.new(34, 9.8, 10.6), C.mustard)
	sign(bagSign, Enum.NormalId.Front, "BAG IT", { color = C.ketchup })
	local fix = at(k, "BagFix", Vector3.new(1.6, 1.2, 1.6), CFrame.new(S.BagFix), Color3.fromRGB(70, 70, 75))
	sign(fix, Enum.NormalId.Front, "FIX BAGS", { color = C.white, ppu = 40 })
	at(k, "WindowStation", Vector3.new(4, 0.4, 1.2), CFrame.new(S.Window), C.mustard)
	local shutter = at(k, "WindowShutter", Vector3.new(6.6, 5.2, 0.3), CFrame.new(48, Layout.PickupWindow.maxY + 2.4, Layout.Building.maxZ - 0.3), C.steel, Enum.Material.Metal)
	sign(shutter, Enum.NormalId.Back, "SORRY, WE'RE CLOSED", { color = C.ketchup, background = C.white })
	local windowSign = at(k, "WindowSign", Vector3.new(6, 1.2, 0.2), CFrame.new(48, 9.8, 10.6), C.mustard)
	sign(windowSign, Enum.NormalId.Front, "WINDOW", { color = C.ketchup })

	-- trash + time clock
	for i, pos in S.Trash do
		cyl(k, "Trash" .. i, 3, 2.2, CFrame.new(pos) * UPRIGHT, Color3.fromRGB(60, 60, 64), Enum.Material.Metal)
	end
	local clock = at(k, "TimeClock", Vector3.new(2, 2.6, 0.8), CFrame.new(S.TimeClock), Color3.fromRGB(110, 110, 115), Enum.Material.Metal)
	sign(clock, Enum.NormalId.Back, "TIME CLOCK", { color = C.white, ppu = 40 })
	local wallClock = at(k, "WallClock", Vector3.new(3, 3, 0.2), CFrame.new(0, 12, -13.3), C.white)
	sign(wallClock, Enum.NormalId.Back, "6:00", { color = C.black, font = Enum.Font.Arcade, name = "ClockFace" })

	-- posters (text swaps after the reveal)
	local posters = folder(k, "Posters")
	local posterTexts = { "SMILING IS MANDATORY", "THE FREEZER IS NOT A NAP ROOM", "WASH HANDS. WASH THEM AGAIN." }
	for i, text in posterTexts do
		local p = at(posters, "Poster" .. i, Vector3.new(5, 6, 0.1), CFrame.new(-26 + (i - 1) * 26, 9, -13.4), C.white)
		sign(p, Enum.NormalId.Back, text, { color = C.ketchup, background = Color3.fromRGB(255, 250, 235), name = "Text" })
	end

	-- bobblehead on the window ledge
	local bobble = ModelFactory.buildMunch({ scale = 0.16, anchored = true })
	bobble.Name = "Bobblehead"
	ModelFactory.place(bobble, CFrame.new(S.Bobblehead))
	bobble.Parent = k
end

local function buildRooms(root: Instance)
	local r = folder(root, "Rooms")
	-- Freezer door (closed, metal, little frosted window)
	local freezerDoor = at(r, "FreezerDoor", Vector3.new(6, 8.6, 0.6), CFrame.new(-45, F + 4.3, Layout.HallZ.min), Color3.fromRGB(200, 215, 225), Enum.Material.DiamondPlate)
	sign(freezerDoor, Enum.NormalId.Back, "WALK-IN FREEZER\n(NOT A NAP ROOM)", { color = C.navy, ppu = 30 })
	at(r, "FreezerWindow", Vector3.new(1.6, 1.2, 0.7), CFrame.new(-45, F + 5.5, Layout.HallZ.min), Color3.fromRGB(220, 240, 255), Enum.Material.Ice, { Transparency = 0.3 })

	-- Storage: shelves, costume closet, Mr. Munch costume
	local st = Layout.Rooms.Storage
	for i = 0, 2 do
		block(r, "Shelf", Vector3.new(st.minX + 1, F, -40 + i * 6), Vector3.new(st.minX + 3, 9, -37 + i * 6), C.wood, Enum.Material.WoodPlanks)
	end
	block(r, "CostumeClosetBox", Vector3.new(-32, F, -48), Vector3.new(-26, 10, -45), Color3.fromRGB(120, 80, 50), Enum.Material.WoodPlanks)
	local closetDoor = at(r, "CostumeClosetDoor", Vector3.new(5.6, 9, 0.2), CFrame.new(-29, F + 4.7, -44.9), Color3.fromRGB(140, 95, 60), Enum.Material.WoodPlanks)
	sign(closetDoor, Enum.NormalId.Back, "COSTUMES", { color = C.mustard, ppu = 20 })
	local costume = ModelFactory.buildMunch({ scale = 0.62, anchored = true })
	costume.Name = "MunchCostume"
	ModelFactory.place(costume, CFrame.new(-21, F, -46.5))
	costume.Parent = r

	-- Office: Deb's desk, coffee, TV + VHS
	block(r, "DebDesk", Vector3.new(-6, F, -42), Vector3.new(4, 3.4, -38), C.wood, Enum.Material.Wood)
	at(r, "DebCoffee", Vector3.new(0.6, 0.8, 0.6), CFrame.new(1, 3.8, -40), C.white)
	local tv = at(r, "OfficeTV", Vector3.new(3.4, 2.6, 2.2), CFrame.new(-6, 4.7, -44), Color3.fromRGB(40, 40, 45))
	sign(tv, Enum.NormalId.Back, "", { name = "Screen", background = Color3.fromRGB(20, 20, 30), color = C.white, font = Enum.Font.Arcade })
	at(r, "VHSTape", Vector3.new(1.4, 0.4, 0.8), CFrame.new(Layout.VHS + Vector3.new(2.5, -0.6, 2)), C.black)
	at(r, "OfficeChair", Vector3.new(2, 2.4, 2), CFrame.new(-1, F + 1.2, -36), Color3.fromRGB(40, 40, 50))
	local cork = at(r, "Corkboard", Vector3.new(6, 4, 0.2), CFrame.new(-1, 8, -47.6), Color3.fromRGB(190, 150, 100))
	sign(cork, Enum.NormalId.Back, "LATE CUSTOMER POLICY:\nThey are not dangerous.\nDo not serve them.\nIf you serve them, they will become Regulars.\nWe do not want more Regulars.", { color = C.black, font = Enum.Font.PatrickHand, ppu = 30 })

	-- Break room: Employee of the Month wall
	local wall = folder(r, "EmployeeWall")
	local EW = Layout.EmployeeWall
	local header = at(wall, "Header", Vector3.new(14, 1.4, 0.1), CFrame.new(EW.centerX, EW.y + 3.4, EW.z), C.mustard)
	sign(header, Enum.NormalId.Back, "EMPLOYEE OF THE MONTH", { color = C.ketchup })
	for i = 1, 13 do
		local col = (i - 1) % 7
		local row = math.floor((i - 1) / 7)
		local x = EW.centerX + (col - 3) * EW.spacing * 1.15
		local y = EW.y + 1.2 - row * 2.6
		local photo = at(wall, "Photo" .. i, Vector3.new(1.7, 2.2, 0.1), CFrame.new(x, y, EW.z), Color3.fromRGB(120, 90, 50), Enum.Material.Wood)
		photo:SetAttribute("Index", i)
		local uv = at(wall, "PhotoUV" .. i, Vector3.new(1.6, 2.0, 0.05), CFrame.new(x, y, EW.z + 0.1), Color3.fromRGB(190, 90, 255), Enum.Material.Neon, { Transparency = 0.6 })
		uv:SetAttribute("Index", i)
	end
	block(r, "BreakTable", Vector3.new(16, F, -38), Vector3.new(28, 3.2, -33), Color3.fromRGB(240, 240, 235))
	for i = 0, 4 do
		block(r, "Locker", Vector3.new(11 + i * 2.2, F, -32), Vector3.new(13 + i * 2.2, 9, -30), Color3.fromRGB(80, 110, 160), Enum.Material.Metal)
	end

	-- Bathroom stall
	local bath = Layout.Rooms.Bathroom
	block(r, "StallWalls", Vector3.new(46, F, -48), Vector3.new(46.3, 8, -39), Color3.fromRGB(150, 180, 200))
	block(r, "StallWalls", Vector3.new(53.7, F, -48), Vector3.new(54, 8, -39), Color3.fromRGB(150, 180, 200))
	local stallDoor = at(r, "StallDoor", Vector3.new(7.4, 7, 0.2), CFrame.new(50, F + 4, -39), Color3.fromRGB(150, 180, 200))
	sign(stallDoor, Enum.NormalId.Back, "OCCUPIED?", { color = C.navy, ppu = 20 })
	block(r, "Sink", Vector3.new(bath.minX + 1, 3, -30), Vector3.new(bath.minX + 4, 3.6, -26), C.white)

	-- PlayPlace: ball pit, slide, statue
	local P = Layout.PlayPlace
	local pitCenter = Vector3.new(-80, 0, -30)
	block(r, "BallPitWall", pitCenter + Vector3.new(-7, F, -7), pitCenter + Vector3.new(7, 2.4, -6.5), C.mustard)
	block(r, "BallPitWall", pitCenter + Vector3.new(-7, F, 6.5), pitCenter + Vector3.new(7, 2.4, 7), C.mustard)
	block(r, "BallPitWall", pitCenter + Vector3.new(-7, F, -7), pitCenter + Vector3.new(-6.5, 2.4, 7), C.mustard)
	block(r, "BallPitWall", pitCenter + Vector3.new(6.5, F, -7), pitCenter + Vector3.new(7, 2.4, 7), C.mustard)
	local ballColors = { C.ketchup, C.mustard, C.pickle, Color3.fromRGB(60, 120, 220), Color3.fromRGB(240, 120, 200) }
	local rng = Random.new(13)
	local balls = folder(r, "BallPitBalls")
	for i = 1, 70 do
		local p = at(balls, "Ball", Vector3.new(1.1, 1.1, 1.1), CFrame.new(pitCenter + Vector3.new(rng:NextNumber(-6, 6), 1.1 + rng:NextNumber(0, 0.9), rng:NextNumber(-6, 6))), ballColors[(i % #ballColors) + 1])
		p.Shape = Enum.PartType.Ball
		p.CanCollide = false
	end
	local slide = Instance.new("WedgePart")
	slide.Name = "Slide"
	slide.Size = Vector3.new(4, 7, 12)
	slide.CFrame = CFrame.new(-88, F + 3.5, -2)
	slide.Color = Color3.fromRGB(60, 120, 220)
	slide.Anchored = true
	slide.Parent = r
	block(r, "SlideTower", Vector3.new(-91, F, -12), Vector3.new(-85, 7, -8), C.ketchup)
	local statue = ModelFactory.buildMunch({ statue = true, anchored = true, scale = 0.85 })
	ModelFactory.place(statue, CFrame.lookAt(Layout.StatuePosition, Layout.StatueFacing))
	statue.Parent = r
	local playSign = at(r, "PlayPlaceSign", Vector3.new(10, 2, 0.2), CFrame.new(-76, 12, P.minZ + 0.2), C.mustard)
	sign(playSign, Enum.NormalId.Back, "MR. MUNCH'S PLAYPLACE", { color = C.ketchup })
end

local function buildHidingSpots(root: Instance)
	local h = folder(root, "HidingSpots")
	for _, id in Layout.HidingOrder do
		local spot = Layout.HidingSpots[id]
		local p = at(h, id, Vector3.new(2, 2, 0.5), CFrame.new(spot.prompt), C.white, Enum.Material.SmoothPlastic, {
			Transparency = 1,
			CanCollide = false,
			CanQuery = false,
		})
		p:SetAttribute("Capacity", spot.capacity)
		p:SetAttribute("Label", spot.label)
	end
end

local function buildLane(root: Instance)
	local l = folder(root, "Lane")
	-- speaker post
	local post = Layout.SpeakerPost
	at(l, "SpeakerPole", Vector3.new(0.6, 4, 0.6), CFrame.new(post + Vector3.new(0, 2, 0)), C.darkSteel, Enum.Material.Metal)
	local speaker = at(l, "SpeakerPost", Vector3.new(1.6, 2.2, 1.2), CFrame.new(post + Vector3.new(0, 4.6, 0)), C.ketchup)
	sign(speaker, Enum.NormalId.Back, "ORDER HERE", { color = C.mustard, ppu = 40 })
	at(l, "SpeakerLight", Vector3.new(0.4, 0.4, 0.2), CFrame.new(post + Vector3.new(0, 5.4, 0.62)), Color3.fromRGB(80, 255, 120), Enum.Material.Neon)
	-- menu board
	local mb = Layout.MenuBoard
	at(l, "MenuLegL", Vector3.new(0.5, 3, 0.5), CFrame.new(mb + Vector3.new(-3, 1.5, 0)), C.darkSteel, Enum.Material.Metal)
	at(l, "MenuLegR", Vector3.new(0.5, 3, 0.5), CFrame.new(mb + Vector3.new(3, 1.5, 0)), C.darkSteel, Enum.Material.Metal)
	local board = at(l, "MenuBoard", Vector3.new(8, 5, 0.5), CFrame.new(mb + Vector3.new(0, 5.5, 0)), Color3.fromRGB(30, 30, 35))
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Menu"
	gui.Face = Enum.NormalId.Back
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0
	gui.Parent = board
	local list = Instance.new("TextLabel")
	list.Name = "Label"
	list.Size = UDim2.fromScale(1, 1)
	list.BackgroundColor3 = Color3.fromRGB(30, 20, 20)
	list.TextColor3 = C.mustard
	list.Font = Enum.Font.FredokaOne
	list.TextScaled = true
	list.TextXAlignment = Enum.TextXAlignment.Left
	list.Text = "  MUNCHIE'S\n  #1 Munch Burger   3.49\n  #2 Cheeseburger    3.99\n  #3 Fries                1.99\n  #4 Munch Stack      5.99\n  #5 Drink                1.49\n  #6 Shake               2.99"
	list.Parent = gui
	pointLight(board, Color3.fromRGB(255, 220, 160), 14, 1)
	-- lane camera on a pole across the lane
	local pole = Layout.LaneCamPole
	at(l, "LaneCamPole", Vector3.new(0.6, 16, 0.6), CFrame.new(pole + Vector3.new(0, 8, 0)), C.darkSteel, Enum.Material.Metal)
	local cam = Layout.Cameras.LaneCam
	at(l, "LaneCam", Vector3.new(1, 1, 2), CFrame.lookAt(cam.from, cam.to), Color3.fromRGB(230, 230, 230))
	at(l, "LaneCamLight", Vector3.new(0.3, 0.3, 0.3), CFrame.lookAt(cam.from, cam.to) * CFrame.new(0.3, 0.4, -0.9), Color3.fromRGB(255, 30, 30), Enum.Material.Neon)
	-- convex safety mirror
	local mp = Layout.MirrorPole
	at(l, "MirrorPole", Vector3.new(0.4, 8.5, 0.4), CFrame.new(mp + Vector3.new(0, 4.25, 0)), C.darkSteel, Enum.Material.Metal)
	local mirrorCam = Layout.Cameras.Mirror
	local mirror = at(l, "ConvexMirror", Vector3.new(0.4, 2.6, 2.6), CFrame.lookAt(mirrorCam.from, mirrorCam.to) * CFrame.Angles(0, math.rad(90), 0), C.steel, Enum.Material.Foil)
	mirror.Shape = Enum.PartType.Cylinder
	-- lane lights
	for _, x in { -120, -60, 0, 60, 120 } do
		lamp(l, Vector3.new(x, 0, Layout.LaneZ + 9))
	end
	-- the big pole sign
	local sp = Layout.SignPole
	at(l, "SignPole", Vector3.new(1.4, 34, 1.4), CFrame.new(sp + Vector3.new(0, 17, 0)), C.darkSteel, Enum.Material.Metal)
	local bigSign = at(l, "BigSign", Vector3.new(18, 8, 2), CFrame.new(sp + Vector3.new(0, 36, 0)), C.ketchup)
	sign(bigSign, Enum.NormalId.Back, "MUNCHIE'S", { color = C.mustard, ppu = 12 })
	sign(bigSign, Enum.NormalId.Front, "MUNCHIE'S", { color = C.mustard, ppu = 12 })
	pointLight(bigSign, C.ketchup, 40, 1.2)
	local openSign = at(l, "OpenSign", Vector3.new(16, 3, 1), CFrame.new(sp + Vector3.new(0, 30, 0)), Color3.fromRGB(20, 20, 25))
	sign(openSign, Enum.NormalId.Back, "OPEN LATE. OPEN ALWAYS.", { color = Color3.fromRGB(255, 80, 120), ppu = 20, name = "OpenText" })
	sign(openSign, Enum.NormalId.Front, "OPEN LATE. OPEN ALWAYS.", { color = Color3.fromRGB(255, 80, 120), ppu = 20, name = "OpenTextBack" })
	-- decorations that come and go by night
	local scenery = folder(root, "Scenery")
	local balloons = folder(scenery, "Balloons")
	for i, x in { -48, -30, 30, 54 } do
		local color = ({ C.ketchup, C.mustard, C.pickle, Color3.fromRGB(60, 120, 220) })[i]
		at(balloons, "String", Vector3.new(0.05, 6, 0.05), CFrame.new(x, 3, 13.6), C.white)
		local balloon = at(balloons, "Balloon", Vector3.new(2, 2.4, 2), CFrame.new(x, 7, 13.6), color)
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = balloon
	end
	local grand = at(balloons, "GrandBanner", Vector3.new(20, 2, 0.2), CFrame.new(-5, 12.5, 13.6), C.white)
	sign(grand, Enum.NormalId.Back, "GRAND RE-OPENING!", { color = C.ketchup })
	local safety = at(scenery, "SafetyPoster", Vector3.new(5, 6, 0.1), CFrame.new(22, 8.5, -29.9), C.white)
	sign(safety, Enum.NormalId.Back, "EMPLOYEE SAFETY:\nIf the lights flicker,\nHIDE.\nThis is a normal part of 24-hour service.", { color = C.navy, background = Color3.fromRGB(255, 250, 230), name = "Text" })
	local visit = at(scenery, "VisitBanner", Vector3.new(26, 2.4, 0.2), CFrame.new(0, 13.5, -13.4), C.mustard)
	sign(visit, Enum.NormalId.Back, "MR. MUNCH VISITING! SMILE!", { color = C.ketchup })
	local rain = at(scenery, "Rain", Vector3.new(400, 1, 120), CFrame.new(0, 60, 0), C.white, Enum.Material.SmoothPlastic, { Transparency = 1, CanCollide = false, CanQuery = false })
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "RainEmitter"
	emitter.Enabled = false
	emitter.Rate = 600
	emitter.Lifetime = NumberRange.new(1.2, 1.6)
	emitter.Speed = NumberRange.new(60, 70)
	emitter.EmissionDirection = Enum.NormalId.Bottom
	emitter.Size = NumberSequence.new(0.15)
	emitter.Transparency = NumberSequence.new(0.4)
	emitter.Color = ColorSequence.new(Color3.fromRGB(180, 200, 230))
	emitter.LightEmission = 0.2
	emitter.Parent = rain
end

local function buildLobby(root: Instance)
	local lobby = folder(root, "Lobby")
	local L = Layout.Lobby
	block(lobby, "ParkingLot", Vector3.new(L.minX, 0, L.minZ), Vector3.new(L.maxX, 0.06, L.maxZ), C.lot, Enum.Material.Asphalt)
	-- path from the lot to the crew door
	for x = L.minX + 8, L.maxX - 8, 10 do
		at(lobby, "ParkingLine", Vector3.new(0.3, 0.08, 10), CFrame.new(x, 0.08, -132), C.white)
		at(lobby, "ParkingLine", Vector3.new(0.3, 0.08, 10), CFrame.new(x, 0.08, -120), C.white)
	end
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "LobbySpawn"
	spawn.Size = Vector3.new(10, 0.4, 10)
	spawn.CFrame = CFrame.new(Layout.LobbySpawn.X, 0.2, Layout.LobbySpawn.Z)
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Color = C.mustard
	spawn.Material = Enum.Material.SmoothPlastic
	spawn.TopSurface = Enum.SurfaceType.Smooth
	spawn.Parent = lobby
	for _, booth in L.Booths do
		local p = booth.position
		local pad = at(lobby, "Booth" .. booth.id, Vector3.new(L.BoothSize, 0.3, L.BoothSize), CFrame.new(p + Vector3.new(0, 0.15, 0)), C.ketchup, Enum.Material.Neon, { Transparency = 0.4 })
		pad:SetAttribute("BoothId", booth.id)
		at(lobby, "BoothClockPost", Vector3.new(0.5, 6, 0.5), CFrame.new(p + Vector3.new(0, 3, L.BoothSize / 2 + 1)), C.darkSteel, Enum.Material.Metal)
		local display = at(lobby, "Booth" .. booth.id .. "Display", Vector3.new(7, 4.5, 0.4), CFrame.new(p + Vector3.new(0, 7.5, L.BoothSize / 2 + 1)), Color3.fromRGB(30, 30, 35))
		sign(display, Enum.NormalId.Front, "CLOCK IN " .. booth.id .. "\nStep on the pad to start a shift", { color = C.mustard, name = "Display", ppu = 30 })
	end
	local welcome = at(lobby, "WelcomeSign", Vector3.new(30, 5, 0.5), CFrame.new(0, 12, -60), C.ketchup)
	sign(welcome, Enum.NormalId.Front, "MUNCHIE'S CREW PARKING — STEP ON A CLOCK-IN PAD TO START YOUR SHIFT", { color = C.mustard })
	at(lobby, "WelcomePoleL", Vector3.new(0.6, 12, 0.6), CFrame.new(-14, 6, -60), C.darkSteel)
	at(lobby, "WelcomePoleR", Vector3.new(0.6, 12, 0.6), CFrame.new(14, 6, -60), C.darkSteel)
	-- locker room shed
	local lp = L.Locker
	block(lobby, "LockerShed", lp + Vector3.new(-8, 0, -6), lp + Vector3.new(8, 10, 6), Color3.fromRGB(80, 110, 160), Enum.Material.Metal)
	local locker = at(lobby, "Locker", Vector3.new(6, 7, 0.5), CFrame.new(lp + Vector3.new(0, 3.5, 6.3)), Color3.fromRGB(60, 90, 140), Enum.Material.Metal)
	sign(locker, Enum.NormalId.Back, "LOCKER ROOM\n(cosmetics)", { color = C.white })
	-- fax machine for codes
	local fp = L.Fax
	block(lobby, "FaxTable", fp + Vector3.new(-3, 0, -2), fp + Vector3.new(3, 3.2, 2), C.wood, Enum.Material.Wood)
	at(lobby, "Fax", Vector3.new(2.6, 1.2, 2), CFrame.new(fp + Vector3.new(0, 3.8, 0)), Color3.fromRGB(225, 215, 190))
	local faxSign = at(lobby, "FaxSign", Vector3.new(6, 2, 0.2), CFrame.new(fp + Vector3.new(0, 7, 2)), C.mustard)
	sign(faxSign, Enum.NormalId.Back, "CORPORATE FAX\n(enter codes)", { color = C.ketchup })
	-- field guide kiosk
	local fg = L.FieldGuide
	local kiosk = at(lobby, "FieldGuideKiosk", Vector3.new(4, 6, 2), CFrame.new(fg + Vector3.new(0, 3, 0)), C.pickle)
	sign(kiosk, Enum.NormalId.Back, "FIELD GUIDE\n& BADGES", { color = C.white })
	-- leaderboard + lobby TV
	local board = at(lobby, "Leaderboard", Vector3.new(18, 12, 0.6), CFrame.new(L.Leaderboard + Vector3.new(0, 9, 0)), Color3.fromRGB(25, 25, 30))
	sign(board, Enum.NormalId.Back, "TOP LATE-CUSTOMER CATCHERS\n(loading...)", { color = C.mustard, name = "Board", font = Enum.Font.GothamBold, ppu = 20 })
	at(lobby, "LeaderboardLegs", Vector3.new(16, 3, 0.4), CFrame.new(L.Leaderboard + Vector3.new(0, 1.5, 0)), C.darkSteel)
	local tv = at(lobby, "LobbyTV", Vector3.new(16, 10, 0.8), CFrame.new(L.LobbyTV + Vector3.new(0, 8, 0)), Color3.fromRGB(20, 20, 25))
	sign(tv, Enum.NormalId.Back, "MUNCHIE'S TV\nNext shift: Night 1", { color = Color3.fromRGB(140, 220, 255), name = "Screen", font = Enum.Font.Arcade, ppu = 20 })
	at(lobby, "TVLegs", Vector3.new(14, 3, 0.4), CFrame.new(L.LobbyTV + Vector3.new(0, 1.5, 0)), C.darkSteel)
	local credits = at(lobby, "CreditsWall", Vector3.new(14, 8, 0.6), CFrame.new(L.CreditsWall + Vector3.new(0, 5, 0)), Color3.fromRGB(240, 235, 220))
	sign(credits, Enum.NormalId.Back, "THANK YOU, SUPPORTERS!", { color = C.ketchup, name = "Credits", ppu = 20 })
	-- employee-of-the-month teaser on the lot
	local teaser = at(lobby, "EmployeeTeaser", Vector3.new(12, 4, 0.4), CFrame.new(L.EmployeeSign + Vector3.new(30, 8, 0)), C.mustard)
	sign(teaser, Enum.NormalId.Front, "EMPLOYEE OF THE MONTH:\nYOU?", { color = C.ketchup })
	for _, x in { -60, 0, 60 } do
		for _, z in { -80, -130 } do
			lamp(lobby, Vector3.new(x, 0, z), 16)
		end
	end
end

local function buildGhostCollision(root: Instance)
	local g = folder(root, "GhostCollision")
	local minX, maxX = Layout.PlayPlace.minX - 1, Layout.Building.maxX + 1
	local minZ, maxZ = Layout.Building.minZ - 1, Layout.Building.maxZ + 1
	local floor = block(g, "GhostFloor", Vector3.new(minX, -0.4, minZ), Vector3.new(maxX, F, maxZ), C.white, Enum.Material.SmoothPlastic, {
		Transparency = 1,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
		CollisionGroup = "GhostFloor",
	})
	floor:AddTag("GhostFloor")
	local walls = {
		{ Vector3.new(minX - 1, 0, minZ - 1), Vector3.new(maxX + 1, 30, minZ) },
		{ Vector3.new(minX - 1, 0, maxZ), Vector3.new(maxX + 1, 30, maxZ + 1) },
		{ Vector3.new(minX - 1, 0, minZ), Vector3.new(minX, 30, maxZ) },
		{ Vector3.new(maxX, 0, minZ), Vector3.new(maxX + 1, 30, maxZ) },
		{ Vector3.new(minX, 18, minZ), Vector3.new(maxX, 19, maxZ) },
	}
	for _, w in walls do
		local p = block(g, "GhostBounds", w[1], w[2], C.white, Enum.Material.SmoothPlastic, {
			Transparency = 1,
			CanQuery = false,
			CanTouch = false,
			CastShadow = false,
			CollisionGroup = "GhostBounds",
		})
		p:AddTag("GhostBounds")
	end
end

---------------------------------------------------------------------------

function MapBuilder.build(parent: Instance): Folder
	local root = Instance.new("Folder")
	root.Name = "Munchies"
	buildGround(root)
	buildShell(root)
	buildLights(root)
	buildKitchen(root)
	buildRooms(root)
	buildHidingSpots(root)
	buildLane(root)
	buildLobby(root)
	buildGhostCollision(root)
	folder(root, "Dynamic")
	root:SetAttribute("BuiltBy", "MapBuilder")
	root.Parent = parent
	return root
end

return MapBuilder
