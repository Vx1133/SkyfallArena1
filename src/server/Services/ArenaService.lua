local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))

local ArenaService = {}
ArenaService.__index = ArenaService

local MAPS = {
	{
		id = 1,
		name = "SUNCREST CASTLE",
		tileColor = Color3.fromRGB(224, 216, 197),
		tileMaterial = Enum.Material.SmoothPlastic,
		studColor = Color3.fromRGB(244, 235, 214),
		warningColor = Color3.fromRGB(255, 143, 73),
		brokenColor = Color3.fromRGB(83, 48, 42),
		structure = Color3.fromRGB(238, 230, 211),
		roof = Color3.fromRGB(190, 153, 92),
		accent = Color3.fromRGB(188, 145, 76),
		secondary = Color3.fromRGB(78, 111, 151),
		ambient = Color3.fromRGB(176, 177, 165),
		fogColor = Color3.fromRGB(215, 225, 231),
	},
	{
		id = 2,
		name = "CLOUDSPIRE KINGDOM",
		tileColor = Color3.fromRGB(211, 224, 231),
		tileMaterial = Enum.Material.SmoothPlastic,
		studColor = Color3.fromRGB(242, 247, 248),
		warningColor = Color3.fromRGB(255, 150, 82),
		brokenColor = Color3.fromRGB(65, 82, 103),
		structure = Color3.fromRGB(233, 241, 243),
		roof = Color3.fromRGB(180, 199, 207),
		accent = Color3.fromRGB(191, 158, 91),
		secondary = Color3.fromRGB(104, 153, 188),
		ambient = Color3.fromRGB(190, 204, 211),
		fogColor = Color3.fromRGB(222, 236, 244),
	},
	{
		id = 3,
		name = "GOLDEN DUNES TEMPLE",
		tileColor = Color3.fromRGB(204, 174, 125),
		tileMaterial = Enum.Material.SmoothPlastic,
		studColor = Color3.fromRGB(229, 204, 158),
		warningColor = Color3.fromRGB(255, 119, 61),
		brokenColor = Color3.fromRGB(91, 56, 38),
		structure = Color3.fromRGB(190, 153, 103),
		roof = Color3.fromRGB(151, 107, 68),
		accent = Color3.fromRGB(171, 119, 66),
		secondary = Color3.fromRGB(74, 147, 151),
		ambient = Color3.fromRGB(190, 171, 143),
		fogColor = Color3.fromRGB(235, 216, 184),
	},
	{
		id = 4,
		name = "EMERALD GROVE SANCTUARY",
		tileColor = Color3.fromRGB(195, 205, 186),
		tileMaterial = Enum.Material.SmoothPlastic,
		studColor = Color3.fromRGB(222, 231, 210),
		warningColor = Color3.fromRGB(255, 143, 73),
		brokenColor = Color3.fromRGB(59, 79, 58),
		structure = Color3.fromRGB(164, 181, 153),
		roof = Color3.fromRGB(105, 130, 91),
		accent = Color3.fromRGB(163, 139, 92),
		secondary = Color3.fromRGB(91, 142, 103),
		ambient = Color3.fromRGB(165, 190, 161),
		fogColor = Color3.fromRGB(205, 223, 194),
	},
	{
		id = 5,
		name = "AZURE HARBOR FORTRESS",
		tileColor = Color3.fromRGB(211, 219, 218),
		tileMaterial = Enum.Material.SmoothPlastic,
		studColor = Color3.fromRGB(239, 242, 236),
		warningColor = Color3.fromRGB(255, 145, 76),
		brokenColor = Color3.fromRGB(65, 77, 83),
		structure = Color3.fromRGB(232, 234, 224),
		roof = Color3.fromRGB(105, 136, 157),
		accent = Color3.fromRGB(181, 151, 100),
		secondary = Color3.fromRGB(76, 145, 171),
		ambient = Color3.fromRGB(180, 202, 207),
		fogColor = Color3.fromRGB(214, 231, 235),
	},
}

local function createPart(parent, name, size, position, color, material, canCollide)
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.Position = position
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.CanCollide = canCollide ~= false
	part.Parent = parent
	return part
end

local function createFolder(parent, name)
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	return folder
end

local function addSquareStuds(basePart, color, studWidth, studHeight)
	local width = studWidth or 0.85
	local height = studHeight or 0.24
	local insetX = math.max(0, basePart.Size.X / 2 - width * 1.65)
	local insetZ = math.max(0, basePart.Size.Z / 2 - width * 1.65)
	local offsets = {
		Vector3.new(-insetX, 0, -insetZ),
		Vector3.new(insetX, 0, -insetZ),
		Vector3.new(-insetX, 0, insetZ),
		Vector3.new(insetX, 0, insetZ),
	}

	for index, offset in ipairs(offsets) do
		local stud = createPart(
			basePart,
			"SquareStud_" .. tostring(index),
			Vector3.new(width, height, width),
			basePart.Position + Vector3.new(0, basePart.Size.Y / 2 + height / 2, 0) + offset,
			color,
			Enum.Material.SmoothPlastic,
			false
		)
		stud.CanTouch = false
		stud.CanQuery = false
		stud.CastShadow = false
	end
end

local function setTileStudState(tile, hidden, color)
	for _, child in ipairs(tile:GetChildren()) do
		if string.sub(child.Name, 1, 11) == "SquareStud_" and child:IsA("BasePart") then
			child.Transparency = hidden and 1 or 0
			if color then
				child.Color = color
			end
		end
	end
end

local function addSign(parent, name, position, size, title, subtitle, facePosition, accent)
	local board = createPart(
		parent,
		name,
		size,
		position,
		Color3.fromRGB(236, 229, 211),
		Enum.Material.Marble,
		false
	)
	if facePosition then
		board.CFrame = CFrame.lookAt(position, facePosition)
	end
	board.CanQuery = false
	board.CanTouch = false

	local gui = Instance.new("SurfaceGui")
	gui.Name = "SignSurface"
	gui.Face = Enum.NormalId.Front
	gui.LightInfluence = 0
	gui.PixelsPerStud = 45
	gui.Parent = board

	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Color3.fromRGB(236, 229, 211)
	frame.BackgroundTransparency = 0.04
	frame.BorderSizePixel = 0
	frame.Parent = gui

	local heading = Instance.new("TextLabel")
	heading.Name = "Heading"
	heading.Size = UDim2.new(1, -14, 0.58, 0)
	heading.Position = UDim2.fromOffset(7, 2)
	heading.BackgroundTransparency = 1
	heading.Font = Enum.Font.GothamBlack
	heading.Text = title
	heading.TextColor3 = Color3.fromRGB(64, 54, 43)
	heading.TextScaled = true
	heading.Parent = frame

	local detail = Instance.new("TextLabel")
	detail.Name = "Subtitle"
	detail.Size = UDim2.new(1, -16, 0.3, 0)
	detail.Position = UDim2.new(0, 8, 0.64, 0)
	detail.BackgroundTransparency = 1
	detail.Font = Enum.Font.GothamMedium
	detail.Text = subtitle
	detail.TextColor3 = accent
	detail.TextScaled = true
	detail.Parent = frame

	local outline = Instance.new("UIStroke")
	outline.Color = accent
	outline.Thickness = 1.4
	outline.Parent = frame
	return board
end

local function tileKey(gridX, gridZ)
	return tostring(gridX) .. ":" .. tostring(gridZ)
end

local function addSquareColumn(parent, name, position, width, height, bodyColor, capColor)
	local body = createPart(
		parent,
		name,
		Vector3.new(width, height, width),
		position + Vector3.new(0, height / 2, 0),
		bodyColor,
		Enum.Material.Marble,
		false
	)
	local base = createPart(
		parent,
		name .. "_Base",
		Vector3.new(width + 2, 1.2, width + 2),
		position + Vector3.new(0, 0.6, 0),
		capColor,
		Enum.Material.SmoothPlastic,
		false
	)
	local cap = createPart(
		parent,
		name .. "_Cap",
		Vector3.new(width + 2.2, 1.2, width + 2.2),
		position + Vector3.new(0, height + 0.6, 0),
		capColor,
		Enum.Material.SmoothPlastic,
		false
	)
	addSquareStuds(cap, bodyColor, 0.72, 0.2)
	body.CanQuery = false
	base.CanQuery = false
	cap.CanQuery = false
	return body
end

local function addTower(parent, name, center, width, height, bodyColor, roofColor)
	local body = createPart(
		parent,
		name,
		Vector3.new(width, height, width),
		center + Vector3.new(0, height / 2, 0),
		bodyColor,
		Enum.Material.Marble,
		false
	)
	local lowerRoof = createPart(
		parent,
		name .. "_RoofBase",
		Vector3.new(width + 5, 2, width + 5),
		center + Vector3.new(0, height + 1, 0),
		roofColor,
		Enum.Material.SmoothPlastic,
		false
	)
	local upperRoof = createPart(
		parent,
		name .. "_RoofTop",
		Vector3.new(width * 0.62, 3, width * 0.62),
		center + Vector3.new(0, height + 3.5, 0),
		roofColor,
		Enum.Material.SmoothPlastic,
		false
	)
	addSquareStuds(lowerRoof, bodyColor, 0.75, 0.22)
	body.CanQuery = false
	lowerRoof.CanQuery = false
	upperRoof.CanQuery = false
end

local function addHall(parent, name, basePosition, width, height, depth, bodyColor, roofColor, accentColor)
	local wall = createPart(
		parent,
		name .. "_MainHall",
		Vector3.new(width, height, depth),
		basePosition + Vector3.new(0, height / 2, 0),
		bodyColor,
		Enum.Material.Marble,
		false
	)
	local roof = createPart(
		parent,
		name .. "_Roof",
		Vector3.new(width + 7, 2.2, depth + 6),
		basePosition + Vector3.new(0, height + 1.1, 0),
		roofColor,
		Enum.Material.SmoothPlastic,
		false
	)
	local upperRoof = createPart(
		parent,
		name .. "_UpperRoof",
		Vector3.new(width * 0.72, 2.2, depth + 3),
		basePosition + Vector3.new(0, height + 3.3, 0),
		accentColor,
		Enum.Material.Marble,
		false
	)
	local frontZ = basePosition.Z + depth / 2 + 0.7
	local doorway = createPart(
		parent,
		name .. "_Doorway",
		Vector3.new(width * 0.2, height * 0.62, 0.7),
		Vector3.new(basePosition.X, basePosition.Y + height * 0.32, frontZ),
		Color3.fromRGB(82, 65, 49),
		Enum.Material.Wood,
		false
	)
	doorway.CanQuery = false

	for side = -1, 1, 2 do
		addSquareColumn(
			parent,
			name .. "_FrontColumn_" .. tostring(side),
			Vector3.new(basePosition.X + side * width * 0.31, basePosition.Y, frontZ + 0.8),
			math.max(3, width * 0.075),
			height * 0.84,
			bodyColor,
			accentColor
		)
		local window = createPart(
			parent,
			name .. "_Window_" .. tostring(side),
			Vector3.new(width * 0.1, height * 0.38, 0.32),
			Vector3.new(basePosition.X + side * width * 0.19, basePosition.Y + height * 0.58, frontZ + 0.24),
			Color3.fromRGB(111, 157, 177),
			Enum.Material.Glass,
			false
		)
		window.Transparency = 0.28
		window.CanQuery = false
	end

	addSquareStuds(roof, accentColor, 0.9, 0.24)
	wall.CanQuery = false
	roof.CanQuery = false
	upperRoof.CanQuery = false
end

local function addTree(parent, name, position, scale, trunkColor, leafColor)
	local trunkHeight = 10 * scale
	local trunk = createPart(
		parent,
		name .. "_Trunk",
		Vector3.new(2.2 * scale, trunkHeight, 2.2 * scale),
		position + Vector3.new(0, trunkHeight / 2, 0),
		trunkColor,
		Enum.Material.Wood,
		false
	)
	trunk.Shape = Enum.PartType.Cylinder
	trunk.CanQuery = false
	trunk.CanTouch = false

	for index = 1, 3 do
		local angle = (index - 1) * math.pi * 2 / 3
		local leaves = createPart(
			parent,
			name .. "_Canopy_" .. tostring(index),
			Vector3.new(9 * scale, 7 * scale, 9 * scale),
			position + Vector3.new(math.cos(angle) * 2.5 * scale, trunkHeight + 1.5 * scale, math.sin(angle) * 2.5 * scale),
			leafColor,
			Enum.Material.Grass,
			false
		)
		leaves.Shape = Enum.PartType.Ball
		leaves.CanQuery = false
		leaves.CanTouch = false
	end
end

local function addPalm(parent, name, position, scale, trunkColor, leafColor)
	local trunk = createPart(
		parent,
		name .. "_Trunk",
		Vector3.new(1.5 * scale, 13 * scale, 1.5 * scale),
		position + Vector3.new(0, 6.5 * scale, 0),
		trunkColor,
		Enum.Material.Wood,
		false
	)
	trunk.Shape = Enum.PartType.Cylinder
	trunk.CFrame = CFrame.new(trunk.Position) * CFrame.Angles(0, 0, math.rad(-6))
	trunk.CanQuery = false

	for index = 1, 6 do
		local angle = (index - 1) * math.pi / 3
		local leaf = createPart(
			parent,
			name .. "_Leaf_" .. tostring(index),
			Vector3.new(2.2 * scale, 0.5 * scale, 9 * scale),
			position + Vector3.new(math.cos(angle) * 4.2 * scale, 13 * scale, math.sin(angle) * 4.2 * scale),
			leafColor,
			Enum.Material.Grass,
			false
		)
		leaf.CFrame = CFrame.new(leaf.Position) * CFrame.Angles(0, -angle, math.rad(10))
		leaf.CanQuery = false
	end
end

local function addBench(parent, name, position, woodColor, stoneColor)
	local seat = createPart(
		parent,
		name .. "_Seat",
		Vector3.new(10, 0.8, 2.8),
		position + Vector3.new(0, 2.2, 0),
		woodColor,
		Enum.Material.WoodPlanks,
		true
	)
	local back = createPart(
		parent,
		name .. "_Back",
		Vector3.new(10, 2.8, 0.8),
		position + Vector3.new(0, 3.7, 1),
		woodColor,
		Enum.Material.WoodPlanks,
		false
	)
	for side = -1, 1, 2 do
		createPart(
			parent,
			name .. "_Support_" .. tostring(side),
			Vector3.new(1.1, 2.1, 2.1),
			position + Vector3.new(side * 3.8, 1.05, 0),
			stoneColor,
			Enum.Material.Marble,
			false
		)
	end
	seat.CanQuery = false
	back.CanQuery = false
end

local function addPlanter(parent, name, position, stoneColor, leafColor)
	local box = createPart(
		parent,
		name .. "_Box",
		Vector3.new(9, 2, 9),
		position + Vector3.new(0, 1, 0),
		stoneColor,
		Enum.Material.Marble,
		false
	)
	local foliage = createPart(
		parent,
		name .. "_Plant",
		Vector3.new(6, 5, 6),
		position + Vector3.new(0, 4, 0),
		leafColor,
		Enum.Material.Grass,
		false
	)
	foliage.Shape = Enum.PartType.Ball
	box.CanQuery = false
	foliage.CanQuery = false
end

function ArenaService.new()
	local self = setmetatable({}, ArenaService)
	self.root = Workspace:FindFirstChild("SkyfallArena")

	if not self.root then
		self.root = Instance.new("Folder")
		self.root.Name = "SkyfallArena"
		self.root.Parent = Workspace
	end

	self.tilesFolder = self.root:FindFirstChild("Tiles")
	if not self.tilesFolder then
		self.tilesFolder = createFolder(self.root, "Tiles")
	end

	self.decorFolder = self.root:FindFirstChild("Environment")
	if not self.decorFolder then
		self.decorFolder = createFolder(self.root, "Environment")
	end

	self.tiles = {}
	self.currentMapId = 0
	self.theme = MAPS[1]
	self.aircraftModel = nil
	self.aircraftBasePosition = Config.CONTROL_CENTER
	return self
end

function ArenaService:_buildLobby()
	local decor = self.lobbyFolder
	local center = Config.LOBBY_CENTER
	local size = Config.LOBBY_SIZE
	local half = size / 2
	local theme = self.theme

	local platform = createPart(
		decor,
		"WaitingPlatform",
		Vector3.new(size, 3, size),
		center,
		Color3.fromRGB(221, 215, 198),
		Enum.Material.Marble,
		true
	)
	platform.CanQuery = false

	local panelCount = 7
	local panelSize = (size - 12) / panelCount
	local spacing = size / panelCount
	for gridX = 1, panelCount do
		for gridZ = 1, panelCount do
			local offsetX = (gridX - (panelCount + 1) / 2) * spacing
			local offsetZ = (gridZ - (panelCount + 1) / 2) * spacing
			local panel = createPart(
				decor,
				"LobbyFloorPanel_" .. tostring(gridX) .. "_" .. tostring(gridZ),
				Vector3.new(panelSize, 0.2, panelSize),
				center + Vector3.new(offsetX, 1.61, offsetZ),
				gridX % 2 == gridZ % 2 and Color3.fromRGB(232, 225, 207) or Color3.fromRGB(216, 209, 192),
				Enum.Material.Marble,
				false
			)
			addSquareStuds(panel, theme.studColor, 0.8, 0.2)
			panel.CanQuery = false
		end
	end

	local poolCenter = center + Vector3.new(0, 1.76, -1)
	local pool = createPart(
		decor,
		"LobbyWater",
		Vector3.new(22, 0.24, 14),
		poolCenter,
		Color3.fromRGB(72, 157, 177),
		Enum.Material.Water,
		false
	)
	pool.Transparency = 0.12
	pool.CanTouch = false
	pool.CanQuery = false

	local poolRimColor = Color3.fromRGB(196, 185, 160)
	local poolNorth = createPart(decor, "PoolNorthRim", Vector3.new(25, 1.1, 1.2), poolCenter + Vector3.new(0, 0.5, -7.5), poolRimColor, Enum.Material.Marble, false)
	local poolSouth = createPart(decor, "PoolSouthRim", Vector3.new(25, 1.1, 1.2), poolCenter + Vector3.new(0, 0.5, 7.5), poolRimColor, Enum.Material.Marble, false)
	local poolEast = createPart(decor, "PoolEastRim", Vector3.new(1.2, 1.1, 14), poolCenter + Vector3.new(12, 0.5, 0), poolRimColor, Enum.Material.Marble, false)
	local poolWest = createPart(decor, "PoolWestRim", Vector3.new(1.2, 1.1, 14), poolCenter + Vector3.new(-12, 0.5, 0), poolRimColor, Enum.Material.Marble, false)
	for _, rim in ipairs({poolNorth, poolSouth, poolEast, poolWest}) do
		rim.CanQuery = false
	end

	local waterfall = createPart(
		decor,
		"LobbyWaterfall",
		Vector3.new(0.7, 3.2, 9),
		poolCenter + Vector3.new(0, 1.3, -7.2),
		Color3.fromRGB(116, 190, 204),
		Enum.Material.Water,
		false
	)
	waterfall.Transparency = 0.28
	waterfall.CanTouch = false
	waterfall.CanQuery = false

	for xSign = -1, 1, 2 do
		for zSign = -1, 1, 2 do
			local corner = center + Vector3.new(xSign * (half - 12), 0, zSign * (half - 12))
			addBench(decor, "LobbyBench_" .. tostring(xSign) .. "_" .. tostring(zSign), corner, Color3.fromRGB(122, 88, 57), poolRimColor)
			addPlanter(decor, "LobbyPlanter_" .. tostring(xSign) .. "_" .. tostring(zSign), corner + Vector3.new(-xSign * 5, 0, -zSign * 5), poolRimColor, Color3.fromRGB(83, 133, 83))
		end
	end

	local gateX = center.X + half - 8
	for side = -1, 1, 2 do
		addSquareColumn(
			decor,
			"LobbyEntranceColumn_" .. tostring(side),
			Vector3.new(gateX, center.Y + 1.5, center.Z + side * 14),
			4,
			12,
			Color3.fromRGB(217, 207, 184),
			Color3.fromRGB(177, 143, 88)
		)
	end
	local gateTop = createPart(
		decor,
		"LobbyEntranceHeader",
		Vector3.new(5, 2.5, 31),
		Vector3.new(gateX, center.Y + 15, center.Z),
		Color3.fromRGB(177, 143, 88),
		Enum.Material.Marble,
		false
	)
	addSquareStuds(gateTop, Color3.fromRGB(232, 219, 190), 0.8, 0.22)
	gateTop.CanQuery = false

	addSign(
		decor,
		"LobbyWelcomeSign",
		center + Vector3.new(0, 12, -half + 3),
		Vector3.new(32, 7, 1.2),
		"WAITING GARDEN",
		"SKYFALL ARENA",
		center,
		Color3.fromRGB(156, 119, 66)
	)
end

function ArenaService:_buildAircraft()
	local folder = self.aircraftFolder
	local model = Instance.new("Model")
	model.Name = "SkyfallLaserAircraft"
	model.Parent = folder

	local base = Config.CONTROL_CENTER
	self.aircraftBasePosition = base

	local orb = createPart(
		model,
		"AircraftFuselage",
		Vector3.new(16, 16, 16),
		base,
		Color3.fromRGB(211, 160, 61),
		Enum.Material.Metal,
		false
	)
	orb.Shape = Enum.PartType.Ball
	orb.Reflectance = 0.08
	orb.CastShadow = false
	model.PrimaryPart = orb

	local armorGroups = {
		{
			name = "Upper",
			normals = {
				Vector3.new(-0.66, 0.48, -0.58),
				Vector3.new(-0.34, 0.76, -0.55),
				Vector3.new(0, 0.86, -0.50),
				Vector3.new(0.34, 0.76, -0.55),
				Vector3.new(0.66, 0.48, -0.58),
			},
		},
		{
			name = "Lower",
			normals = {
				Vector3.new(-0.67, -0.36, -0.65),
				Vector3.new(-0.24, -0.68, -0.66),
				Vector3.new(0.24, -0.68, -0.66),
				Vector3.new(0.67, -0.36, -0.65),
			},
		},
	}

	for _, group in ipairs(armorGroups) do
		for index, rawNormal in ipairs(group.normals) do
			local normal = rawNormal.Unit
			local panelPosition = base + normal * 7.76
			local upVector = math.abs(normal.Y) > 0.88 and Vector3.new(0, 0, -1) or Vector3.yAxis
			local plate = createPart(
				model,
				"ArmorPlate_" .. group.name .. "_" .. tostring(index),
				Vector3.new(4.15, 2.55, 0.68),
				panelPosition,
				index % 2 == 0 and Color3.fromRGB(235, 195, 105) or Color3.fromRGB(194, 140, 48),
				Enum.Material.Metal,
				false
			)
			plate.Shape = Enum.PartType.Ball
			plate.CFrame = CFrame.lookAt(panelPosition, panelPosition + normal, upVector)
			plate.Reflectance = 0.04
			plate.CastShadow = false
			plate.CanQuery = false
			plate.CanTouch = false
		end
	end

	-- A close-spaced segmented band follows the sphere's equator, with a bright lip and bronze lower seam.
	for index = 1, 12 do
		local angle = (index - 1) * math.pi / 6
		local radial = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local tangent = Vector3.new(-math.sin(angle), 0, math.cos(angle))
		local bandPosition = base + radial * 7.56
		local band = createPart(
			model,
			"EquatorialBandSegment_" .. tostring(index),
			Vector3.new(3.92, 0.62, 0.72),
			bandPosition,
			Color3.fromRGB(232, 187, 91),
			Enum.Material.Metal,
			false
		)
		band.CFrame = CFrame.fromMatrix(bandPosition, tangent, Vector3.yAxis, -radial)
		band.Reflectance = 0.06
		band.CastShadow = false
		band.CanQuery = false
		band.CanTouch = false

		local upperLip = createPart(
			model,
			"EquatorialBandUpperLip_" .. tostring(index),
			Vector3.new(3.62, 0.11, 0.76),
			bandPosition,
			Color3.fromRGB(250, 218, 142),
			Enum.Material.Metal,
			false
		)
		upperLip.CFrame = band.CFrame * CFrame.new(0, 0.24, 0)
		upperLip.CastShadow = false
		upperLip.CanQuery = false
		upperLip.CanTouch = false

		local lowerSeam = createPart(
			model,
			"EquatorialBronzeSeam_" .. tostring(index),
			Vector3.new(3.74, 0.12, 0.76),
			bandPosition,
			Color3.fromRGB(103, 65, 35),
			Enum.Material.Metal,
			false
		)
		lowerSeam.CFrame = band.CFrame * CFrame.new(0, -0.25, 0)
		lowerSeam.CanQuery = false
		lowerSeam.CanTouch = false
		lowerSeam.CastShadow = false
	end

	-- The lens sits slightly left of center on the sphere's equator and faces the arena.
	local lensCenter = base + Vector3.new(-1.1, 0, -7.05)
	local lensNormal = Vector3.new(0, -0.08, -0.997).Unit
	local function lensFrameAt(position)
		return CFrame.lookAt(position, position + lensNormal) * CFrame.Angles(0, math.rad(90), 0)
	end

	local function lensDisc(name, thickness, diameter, position, color, material)
		local disc = createPart(
			model,
			name,
			Vector3.new(thickness, diameter, diameter),
			position,
			color,
			material,
			false
		)
		disc.Shape = Enum.PartType.Cylinder
		disc.CFrame = lensFrameAt(position)
		disc.CastShadow = false
		disc.CanQuery = false
		disc.CanTouch = false
		return disc
	end

	local outerCollar = lensDisc(
		"ControllerLensOuterCollar",
		0.72,
		7.5,
		lensCenter,
		Color3.fromRGB(223, 174, 74),
		Enum.Material.Metal
	)
	outerCollar.Reflectance = 0.12

	lensDisc(
		"ControllerLensBronzeGroove",
		0.28,
		6.45,
		lensCenter + lensNormal * 0.5,
		Color3.fromRGB(92, 50, 33),
		Enum.Material.Metal
	)

	lensDisc(
		"ControllerLensInnerRing",
		0.26,
		5.65,
		lensCenter + lensNormal * 0.76,
		Color3.fromRGB(236, 190, 96),
		Enum.Material.Metal
	)

	local lensPosition = lensCenter + lensNormal * 0.95
	local lens = createPart(
		model,
		"ControllerLens",
		Vector3.new(0.5, 4.95, 4.95),
		lensPosition,
		Color3.fromRGB(209, 32, 47),
		Enum.Material.Glass,
		false
	)
	lens.Shape = Enum.PartType.Ball
	lens.CFrame = lensFrameAt(lensPosition)
	lens.Transparency = 0.08
	lens.Reflectance = 0.16
	lens.CastShadow = false
	lens.CanQuery = false
	lens.CanTouch = false

	local lensLight = Instance.new("PointLight")
	lensLight.Color = Color3.fromRGB(255, 69, 72)
	lensLight.Brightness = 0.35
	lensLight.Range = 4.5
	lensLight.Parent = lens

	local function lensDetail(name, size, localOffset, color)
		local position = lensPosition + lensFrameAt(lensPosition):VectorToWorldSpace(localOffset)
		local detail = createPart(
			model,
			name,
			size,
			position,
			color,
			Enum.Material.SmoothPlastic,
			false
		)
		detail.CFrame = lensFrameAt(lensPosition) * CFrame.new(localOffset)
		detail.CanQuery = false
		detail.CanTouch = false
		detail.CastShadow = false
		return detail
	end

	local reticleColor = Color3.fromRGB(255, 113, 111)

	local function addLensReticleRing(name, radius, segmentCount)
		local frame = lensFrameAt(lensPosition)
		local segmentLength = (2 * math.pi * radius / segmentCount) * 0.86
		for index = 1, segmentCount do
			local angle = (index - 1) * (2 * math.pi / segmentCount)
			local localOffset = Vector3.new(
				-0.34,
				math.cos(angle) * radius,
				math.sin(angle) * radius
			)
			local segment = lensDetail(
				name .. "_" .. tostring(index),
				Vector3.new(0.07, 0.09, segmentLength),
				localOffset,
				reticleColor
			)
			segment.CFrame = frame * CFrame.new(localOffset) * CFrame.Angles(angle + math.pi / 2, 0, 0)
		end
	end

	addLensReticleRing("LensReticleRing_Outer", 1.82, 12)
	addLensReticleRing("LensReticleRing_Inner", 1.12, 12)

	lensDetail(
		"LensReticleHorizontal",
		Vector3.new(0.09, 2.7, 0.1),
		Vector3.new(-0.34, 0, 0),
		reticleColor
	)
	lensDetail(
		"LensReticleVertical",
		Vector3.new(0.09, 0.1, 2.7),
		Vector3.new(-0.34, 0, 0),
		reticleColor
	)
	lensDetail(
		"LensReticleCenter",
		Vector3.new(0.12, 0.34, 0.34),
		Vector3.new(-0.38, 0, 0),
		Color3.fromRGB(255, 179, 162)
	)
	local highlightA = lensDetail(
		"LensWhiteHighlightA",
		Vector3.new(0.12, 0.82, 0.36),
		Vector3.new(-0.4, -0.78, 0.48),
		Color3.fromRGB(255, 255, 246)
	)
	highlightA.Shape = Enum.PartType.Ball

	local highlightB = lensDetail(
		"LensWhiteHighlightB",
		Vector3.new(0.1, 0.46, 0.18),
		Vector3.new(-0.4, 0.72, -0.68),
		Color3.fromRGB(255, 255, 255)
	)
	highlightB.Shape = Enum.PartType.Ball

	-- Small rectangular slots give the equatorial band a restrained mechanical finish.
	for index = 1, 4 do
		local angle = (index - 1) * math.pi / 2
		local slotPosition = base + Vector3.new(math.cos(angle) * 7.9, 0, math.sin(angle) * 7.9)
		local slot = createPart(
			model,
			"EquatorialSlot_" .. tostring(index),
			Vector3.new(0.24, 0.18, 0.72),
			slotPosition,
			Color3.fromRGB(92, 62, 38),
			Enum.Material.Metal,
			false
		)
		slot.CFrame = CFrame.new(slotPosition) * CFrame.Angles(0, -angle, 0)
		slot.CanQuery = false
		slot.CanTouch = false
	end

	local pilotPlatform = createPart(
		folder,
		"PilotPlatform",
		Vector3.new(27, 2, 25),
		base + Vector3.new(0, -17, 18),
		Color3.fromRGB(218, 211, 194),
		Enum.Material.Marble,
		true
	)
	pilotPlatform.CanQuery = false
	addSquareStuds(pilotPlatform, Color3.fromRGB(238, 229, 206), 0.9, 0.22)

	for side = -1, 1, 2 do
		local rail = createPart(
			folder,
			"PilotRail_" .. tostring(side),
			Vector3.new(1, 4, 21),
			pilotPlatform.Position + Vector3.new(side * 13, 3, 0),
			Color3.fromRGB(178, 150, 101),
			Enum.Material.Marble,
			true
		)
		rail.CanQuery = false
	end

	addSign(
		folder,
		"PilotStationSign",
		pilotPlatform.Position + Vector3.new(0, 7, 11),
		Vector3.new(15, 4.5, 1),
		"LASER CONTROL",
		"SKYFALL ARENA",
		pilotPlatform.Position,
		Color3.fromRGB(154, 103, 61)
	)

	self.aircraftModel = model
end

function ArenaService:_setLighting(theme)
	Lighting.ClockTime = 13.5
	Lighting.Brightness = 3
	Lighting.Ambient = theme.ambient
	Lighting.OutdoorAmbient = theme.ambient:Lerp(Color3.fromRGB(235, 235, 225), 0.42)
	Lighting.FogColor = theme.fogColor
	Lighting.FogStart = 450
	Lighting.FogEnd = 100000
	Lighting.GlobalShadows = true
	Lighting.EnvironmentDiffuseScale = 0.72
	Lighting.EnvironmentSpecularScale = 0.58

	local atmosphere = Lighting:FindFirstChild("SkyfallAtmosphere")
	if not atmosphere then
		atmosphere = Instance.new("Atmosphere")
		atmosphere.Name = "SkyfallAtmosphere"
		atmosphere.Parent = Lighting
	end
	atmosphere.Color = theme.fogColor:Lerp(Color3.fromRGB(235, 238, 235), 0.58)
	atmosphere.Decay = theme.fogColor
	atmosphere.Density = 0.08
	atmosphere.Glare = 0.08
	atmosphere.Haze = 0.35
	atmosphere.Offset = 0.1

	local colorCorrection = Lighting:FindFirstChild("SkyfallColorCorrection")
	if not colorCorrection then
		colorCorrection = Instance.new("ColorCorrectionEffect")
		colorCorrection.Name = "SkyfallColorCorrection"
		colorCorrection.Parent = Lighting
	end
	colorCorrection.Brightness = 0.015
	colorCorrection.Contrast = 0.04
	colorCorrection.Saturation = 0.035
	colorCorrection.TintColor = Color3.fromRGB(255, 250, 239)

	local bloom = Lighting:FindFirstChild("SkyfallBloom")
	if not bloom then
		bloom = Instance.new("BloomEffect")
		bloom.Name = "SkyfallBloom"
		bloom.Parent = Lighting
	end
	bloom.Intensity = 0.08
	bloom.Size = 12
	bloom.Threshold = 1.8
end

function ArenaService:_buildMapDecoration(theme)
	local folder = self.mapFolder
	local half = Config.ARENA_HALF_WIDTH
	local lobbyEast = Config.LOBBY_CENTER.X + Config.LOBBY_SIZE / 2
	local arenaWest = Config.ARENA_CENTER.X - half
	local bridgeLength = arenaWest - lobbyEast
	local bridgeCenterX = (lobbyEast + arenaWest) / 2

	local bridge = createPart(
		folder,
		"LobbyToArenaWalkway",
		Vector3.new(bridgeLength + 1, 1, 14),
		Vector3.new(bridgeCenterX, Config.ARENA_CENTER.Y - 0.5, Config.ARENA_CENTER.Z),
		theme.structure,
		Enum.Material.Marble,
		true
	)
	addSquareStuds(bridge, theme.studColor, 0.9, 0.2)
	bridge.CanQuery = false

	for side = -1, 1, 2 do
		local curb = createPart(
			folder,
			"WalkwayCurb_" .. tostring(side),
			Vector3.new(bridgeLength, 1.4, 0.8),
			Vector3.new(bridgeCenterX, Config.ARENA_CENTER.Y + 0.2, side * 7),
			theme.roof,
			Enum.Material.Marble,
			true
		)
		curb.CanQuery = false
	end

	local facadeZ = Config.ARENA_CENTER.Z - half - 34
	local facadeBase = Vector3.new(Config.ARENA_CENTER.X, Config.ARENA_CENTER.Y - 1, facadeZ)

	if theme.id == 1 then
		addHall(folder, "SuncrestRoyalHall", facadeBase, 74, 27, 15, theme.structure, theme.roof, theme.accent)
		addTower(folder, "SuncrestWestTower", facadeBase + Vector3.new(-46, 0, 0), 11, 39, theme.structure, theme.roof)
		addTower(folder, "SuncrestEastTower", facadeBase + Vector3.new(46, 0, 0), 11, 39, theme.structure, theme.roof)
		for side = -1, 1, 2 do
			local banner = createPart(
				folder,
				"SuncrestRoyalBanner_" .. tostring(side),
				Vector3.new(3, 11, 0.35),
				facadeBase + Vector3.new(side * 27, 18, 8.2),
				theme.secondary,
				Enum.Material.Fabric,
				false
			)
			banner.CanQuery = false
		end
		addPlanter(folder, "SuncrestGardenWest", Config.ARENA_CENTER + Vector3.new(-half - 22, -1, 52), theme.structure, Color3.fromRGB(83, 142, 81))
		addPlanter(folder, "SuncrestGardenEast", Config.ARENA_CENTER + Vector3.new(half + 22, -1, 52), theme.structure, Color3.fromRGB(83, 142, 81))
	elseif theme.id == 2 then
		addHall(folder, "CloudspireSkyPalace", facadeBase, 70, 31, 17, theme.structure, theme.roof, theme.accent)
		addTower(folder, "CloudspireWestSpire", facadeBase + Vector3.new(-43, 0, -2), 10, 47, theme.structure, theme.accent)
		addTower(folder, "CloudspireEastSpire", facadeBase + Vector3.new(43, 0, -2), 10, 47, theme.structure, theme.accent)
		for index = 1, 5 do
			local cloudPosition = Config.ARENA_CENTER + Vector3.new(
				(index % 2 == 0 and 1 or -1) * (half + 38 + index * 3),
				-3 + (index % 3) * 4,
				-70 + index * 30
			)
			local cloud = createPart(
				folder,
				"CloudspireDistantCloud_" .. tostring(index),
				Vector3.new(25 + index * 3, 8, 20 + index * 2),
				cloudPosition,
				Color3.fromRGB(239, 245, 246),
				Enum.Material.SmoothPlastic,
				false
			)
			cloud.Shape = Enum.PartType.Ball
			cloud.Transparency = 0.16
			cloud.CanQuery = false
		end
		for side = -1, 1, 2 do
			addSquareColumn(
				folder,
				"CloudspireOuterPillar_" .. tostring(side),
				Config.ARENA_CENTER + Vector3.new(side * (half + 19), -1, -42),
				5,
				20,
				theme.structure,
				theme.accent
			)
		end
	elseif theme.id == 3 then
		addHall(folder, "GoldenDunesTemple", facadeBase, 72, 24, 18, theme.structure, theme.roof, theme.accent)
		for side = -1, 1, 2 do
			for index = 1, 2 do
				addSquareColumn(
					folder,
					"GoldenTempleColumn_" .. tostring(side) .. "_" .. tostring(index),
					facadeBase + Vector3.new(side * (33 + index * 9), 0, index * 4),
					4.5,
					18,
					theme.structure,
					theme.accent
				)
			end
			addPalm(
				folder,
				"GoldenDunesPalm_" .. tostring(side),
				Config.ARENA_CENTER + Vector3.new(side * (half + 27), -1, 66),
				1.1,
				Color3.fromRGB(119, 89, 59),
				Color3.fromRGB(105, 137, 79)
			)
		end
		for side = -1, 1, 2 do
			local dune = createPart(
				folder,
				"GoldenDunesOuterDune_" .. tostring(side),
				Vector3.new(38, 10, 25),
				Config.ARENA_CENTER + Vector3.new(side * (half + 39), 1, -65),
				Color3.fromRGB(198, 164, 113),
				Enum.Material.Sand,
				false
			)
			dune.Shape = Enum.PartType.Ball
			dune.CanQuery = false
		end
	elseif theme.id == 4 then
		addHall(folder, "EmeraldGroveSanctuary", facadeBase, 66, 25, 17, theme.structure, theme.roof, theme.accent)
		addTower(folder, "EmeraldGroveWestPavilion", facadeBase + Vector3.new(-42, 0, 1), 9, 34, theme.structure, theme.roof)
		addTower(folder, "EmeraldGroveEastPavilion", facadeBase + Vector3.new(42, 0, 1), 9, 34, theme.structure, theme.roof)
		local treePositions = {
			Vector3.new(-half - 31, -1, -85),
			Vector3.new(half + 31, -1, -85),
			Vector3.new(-half - 32, -1, 34),
			Vector3.new(half + 32, -1, 35),
		}
		for index, offset in ipairs(treePositions) do
			addTree(
				folder,
				"EmeraldGroveTree_" .. tostring(index),
				Config.ARENA_CENTER + offset,
				index % 2 == 0 and 1.2 or 1,
				Color3.fromRGB(111, 82, 55),
				index % 2 == 0 and Color3.fromRGB(67, 124, 71) or Color3.fromRGB(81, 143, 77)
			)
		end
		addPlanter(folder, "EmeraldGroveOuterGardenWest", Config.ARENA_CENTER + Vector3.new(-half - 19, -1, 68), theme.structure, theme.secondary)
		addPlanter(folder, "EmeraldGroveOuterGardenEast", Config.ARENA_CENTER + Vector3.new(half + 19, -1, 68), theme.structure, theme.secondary)
	elseif theme.id == 5 then
		addHall(folder, "AzureHarborFortress", facadeBase, 74, 27, 17, theme.structure, theme.roof, theme.accent)
		addTower(folder, "AzureHarborWestTower", facadeBase + Vector3.new(-46, 0, 0), 10, 40, theme.structure, theme.roof)
		addTower(folder, "AzureHarborEastTower", facadeBase + Vector3.new(46, 0, 0), 10, 40, theme.structure, theme.roof)
		addTower(
			folder,
			"AzureHarborLighthouse",
			Config.ARENA_CENTER + Vector3.new(half + 28, -1, -105),
			12,
			43,
			theme.structure,
			theme.accent
		)
		local sea = createPart(
			folder,
			"AzureHarborSea",
			Vector3.new(470, 1, 390),
			Config.ARENA_CENTER + Vector3.new(0, -20, 0),
			Color3.fromRGB(58, 145, 169),
			Enum.Material.Water,
			false
		)
		sea.Transparency = 0.2
		sea.CanQuery = false
		sea.CanTouch = false
	end

	addSign(
		folder,
		"MapNameSign",
		facadeBase + Vector3.new(0, 34, 9.5),
		Vector3.new(36, 7, 1.2),
		theme.name,
		"SKYFALL ARENA",
		Config.ARENA_CENTER,
		theme.accent
	)
end

function ArenaService:Build()
	for _, child in ipairs(self.tilesFolder:GetChildren()) do
		child:Destroy()
	end
	for _, child in ipairs(self.decorFolder:GetChildren()) do
		child:Destroy()
	end

	self.lobbyFolder = createFolder(self.decorFolder, "Lobby")
	self.mapFolder = createFolder(self.decorFolder, "ActiveMap")
	self.aircraftFolder = createFolder(self.decorFolder, "Aircraft")
	self.tiles = {}

	local halfGrid = (Config.GRID_SIZE - 1) / 2
	local spacing = Config.TILE_SIZE + Config.TILE_GAP

	for gridX = 1, Config.GRID_SIZE do
		for gridZ = 1, Config.GRID_SIZE do
			local offsetX = (gridX - 1 - halfGrid) * spacing
			local offsetZ = (gridZ - 1 - halfGrid) * spacing
			local position = Config.ARENA_CENTER + Vector3.new(offsetX, 0, offsetZ)
			local tile = createPart(
				self.tilesFolder,
				"Tile_" .. tostring(gridX) .. "_" .. tostring(gridZ),
				Vector3.new(Config.TILE_SIZE, 1, Config.TILE_SIZE),
				position,
				MAPS[1].tileColor,
				MAPS[1].tileMaterial
			)

			tile:SetAttribute("GridX", gridX)
			tile:SetAttribute("GridZ", gridZ)
			tile:SetAttribute("IsBroken", false)
			tile:SetAttribute("IsWarning", false)
			tile:SetAttribute("StrikeToken", 0)
			addSquareStuds(tile, MAPS[1].studColor, 0.86, 0.24)
			self.tiles[tileKey(gridX, gridZ)] = tile
		end
	end

	self:_buildLobby()
	self:_buildAircraft()
	self:SetMap(1)
end

function ArenaService:SetMap(mapId)
	local selected = MAPS[mapId] or MAPS[1]
	self.currentMapId = selected.id
	self.theme = selected

	for _, child in ipairs(self.mapFolder:GetChildren()) do
		child:Destroy()
	end

	for _, tile in pairs(self.tiles) do
		local token = (tile:GetAttribute("StrikeToken") or 0) + 1
		tile:SetAttribute("StrikeToken", token)
		tile:SetAttribute("IsBroken", false)
		tile:SetAttribute("IsWarning", false)
		tile.Color = selected.tileColor
		tile.Material = selected.tileMaterial
		tile.CanCollide = true
		tile.Transparency = 0
		setTileStudState(tile, false, selected.studColor)
	end

	for _, child in ipairs(self.lobbyFolder:GetChildren()) do
		if child.Name == "LobbyWelcomeSign" then
			child:Destroy()
		end
	end
	self:_buildMapDecoration(selected)
	self:_setLighting(selected)
	return selected.name
end

function ArenaService:GetMapName()
	return self.theme.name
end

function ArenaService:GetTile(gridX, gridZ)
	return self.tiles[tileKey(gridX, gridZ)]
end

function ArenaService:GetSafeTiles()
	local safeTiles = {}
	for _, tile in pairs(self.tiles) do
		if tile.Parent == self.tilesFolder
			and tile.CanCollide
			and not tile:GetAttribute("IsBroken")
			and not tile:GetAttribute("IsWarning")
		then
			table.insert(safeTiles, tile)
		end
	end
	return safeTiles
end

function ArenaService:MarkTile(tile)
	if not tile or tile.Parent ~= self.tilesFolder then
		return nil
	end
	if tile:GetAttribute("IsBroken") or tile:GetAttribute("IsWarning") then
		return nil
	end

	local token = (tile:GetAttribute("StrikeToken") or 0) + 1
	tile:SetAttribute("StrikeToken", token)
	tile:SetAttribute("IsWarning", true)
	tile.Color = self.theme.warningColor
	tile.Material = Enum.Material.SmoothPlastic
	return token
end

function ArenaService:IsStrikeCurrent(tile, token)
	return tile
		and tile.Parent == self.tilesFolder
		and tile:GetAttribute("StrikeToken") == token
end

function ArenaService:ClearWarning(tile, token)
	if not self:IsStrikeCurrent(tile, token) then
		return
	end

	if tile:GetAttribute("IsWarning") and not tile:GetAttribute("IsBroken") then
		tile:SetAttribute("IsWarning", false)
		tile.Color = self.theme.tileColor
		tile.Material = self.theme.tileMaterial
	end
end

function ArenaService:CreateStrikeBeam(tile)
	local beamPosition = tile.Position + Vector3.new(0, Config.BEAM_HEIGHT / 2, 0)
	local outerBeam = createPart(
		self.root,
		"LaserBeamOuter",
		Vector3.new(4.4, Config.BEAM_HEIGHT, 4.4),
		beamPosition,
		Color3.fromRGB(202, 34, 52),
		Enum.Material.SmoothPlastic,
		false
	)
	outerBeam.Transparency = 0.55
	outerBeam.CanTouch = false
	outerBeam.CanQuery = false

	local innerBeam = createPart(
		self.root,
		"LaserBeamCore",
		Vector3.new(1.2, Config.BEAM_HEIGHT, 1.2),
		beamPosition,
		Color3.fromRGB(255, 224, 216),
		Enum.Material.SmoothPlastic,
		false
	)
	innerBeam.Transparency = 0.08
	innerBeam.CanTouch = false
	innerBeam.CanQuery = false

	local beamLight = Instance.new("PointLight")
	beamLight.Color = Color3.fromRGB(255, 57, 78)
	beamLight.Brightness = 3
	beamLight.Range = 26
	beamLight.Parent = innerBeam

	local impact = createPart(
		self.root,
		"LaserImpact",
		Vector3.new(6.2, 0.28, 6.2),
		tile.Position + Vector3.new(0, 0.72, 0),
		self.theme.warningColor,
		Enum.Material.Glass,
		false
	)
	impact.Transparency = 0.24
	impact.CanTouch = false
	impact.CanQuery = false

	Debris:AddItem(outerBeam, 0.45)
	Debris:AddItem(innerBeam, 0.45)
	Debris:AddItem(impact, 0.3)
end

function ArenaService:BreakTile(tile, token)
	if not self:IsStrikeCurrent(tile, token) then
		return
	end

	tile:SetAttribute("IsWarning", false)
	tile:SetAttribute("IsBroken", true)
	tile.Color = self.theme.brokenColor
	tile.Material = Enum.Material.Slate
	tile.CanCollide = false
	tile.Transparency = 0.84
	setTileStudState(tile, true)
end

function ArenaService:ResetTiles()
	for _, tile in pairs(self.tiles) do
		local token = (tile:GetAttribute("StrikeToken") or 0) + 1
		tile:SetAttribute("StrikeToken", token)
		tile:SetAttribute("IsWarning", false)
		tile:SetAttribute("IsBroken", false)
		tile.Color = self.theme.tileColor
		tile.Material = self.theme.tileMaterial
		tile.CanCollide = true
		tile.Transparency = 0
		setTileStudState(tile, false, self.theme.studColor)
	end
end

function ArenaService:GetLobbySpawnCFrame(index, total, isBot)
	local spawnIndex = math.max(1, index or 1)
	local spawnTotal = math.max(1, total or 1)
	local angle = ((spawnIndex - 1) / spawnTotal) * math.pi * 2
	local radius = isBot and Config.LOBBY_BOT_SPAWN_RADIUS or Config.LOBBY_SPAWN_RADIUS
	local position = Config.LOBBY_CENTER + Vector3.new(
		math.cos(angle) * radius,
		5,
		math.sin(angle) * radius
	)
	return CFrame.new(position)
end

function ArenaService:GetRunnerSpawnCFrame(index, total)
	local angle = ((index - 1) / math.max(total, 1)) * math.pi * 2
	local radius = Config.RUNNER_SPAWN_RADIUS
	local position = Config.ARENA_CENTER + Vector3.new(
		math.cos(angle) * radius,
		6,
		math.sin(angle) * radius
	)
	return CFrame.new(position)
end

function ArenaService:GetControllerSpawnCFrame()
	return CFrame.new(Config.CONTROL_CENTER + Vector3.new(0, -10, 18))
end

return ArenaService
