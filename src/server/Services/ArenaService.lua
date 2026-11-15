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
		name = "SKYFALL CLASSIC ARENA",
		tileColor = Color3.fromRGB(79, 170, 66),
		tileMaterial = Enum.Material.Plastic,
		studColor = Color3.fromRGB(112, 204, 83),
		warningColor = Color3.fromRGB(255, 48, 58),
		brokenColor = Color3.fromRGB(66, 76, 82),
		structure = Color3.fromRGB(52, 116, 196),
		roof = Color3.fromRGB(230, 61, 61),
		accent = Color3.fromRGB(255, 207, 56),
		secondary = Color3.fromRGB(64, 166, 220),
		ambient = Color3.fromRGB(0, 0, 0),
		fogColor = Color3.fromRGB(192, 192, 192),
	},
}

local function createPart(parent, name, size, position, color, material, canCollide)
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.Position = position
	part.Color = color
	part.Material = material or Enum.Material.Plastic
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
	local width = studWidth or 1.2
	local height = studHeight or 0.28
	local xSpacing = basePart.Size.X / 3
	local zSpacing = basePart.Size.Z / 3
	local index = 0

	for row = -1, 1 do
		for column = -1, 1 do
			index += 1
			local offset = Vector3.new(column * xSpacing, 0, row * zSpacing)
			local stud = createPart(
				basePart,
				"SquareStud_" .. tostring(index),
				Vector3.new(width, height, width),
				basePart.Position + Vector3.new(0, basePart.Size.Y / 2 + height / 2, 0) + offset,
				color,
				Enum.Material.Plastic,
				false
			)
			stud.CanTouch = false
			stud.CanQuery = false
			stud.CastShadow = false
		end
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
		Enum.Material.Plastic,
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
		Enum.Material.Plastic,
		false
	)
	local base = createPart(
		parent,
		name .. "_Base",
		Vector3.new(width + 2, 1.2, width + 2),
		position + Vector3.new(0, 0.6, 0),
		capColor,
		Enum.Material.Plastic,
		false
	)
	local cap = createPart(
		parent,
		name .. "_Cap",
		Vector3.new(width + 2.2, 1.2, width + 2.2),
		position + Vector3.new(0, height + 0.6, 0),
		capColor,
		Enum.Material.Plastic,
		false
	)
	addSquareStuds(cap, bodyColor, 0.72, 0.2)
	body.CanQuery = false
	base.CanQuery = false
	cap.CanQuery = false
	return body
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
	local lowerLeaves = createPart(
		parent,
		name .. "_LowerLeaves",
		Vector3.new(8 * scale, 5 * scale, 8 * scale),
		position + Vector3.new(0, trunkHeight + 1.8 * scale, 0),
		leafColor,
		Enum.Material.Plastic,
		false
	)
	local upperLeaves = createPart(
		parent,
		name .. "_UpperLeaves",
		Vector3.new(5.5 * scale, 5 * scale, 5.5 * scale),
		position + Vector3.new(0, trunkHeight + 5.2 * scale, 0),
		leafColor:Lerp(Color3.new(1, 1, 1), 0.08),
		Enum.Material.Plastic,
		false
	)
	for _, part in ipairs({trunk, lowerLeaves, upperLeaves}) do
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
	end
end


local function addBench(parent, name, position, woodColor, stoneColor)
	local seat = createPart(
		parent,
		name .. "_Seat",
		Vector3.new(10, 0.8, 2.8),
		position + Vector3.new(0, 2.2, 0),
		woodColor,
		Enum.Material.Wood,
		true
	)
	local back = createPart(
		parent,
		name .. "_Back",
		Vector3.new(10, 2.8, 0.8),
		position + Vector3.new(0, 3.7, 1),
		woodColor,
		Enum.Material.Wood,
		false
	)
	for side = -1, 1, 2 do
		createPart(
			parent,
			name .. "_Support_" .. tostring(side),
			Vector3.new(1.1, 2.1, 2.1),
			position + Vector3.new(side * 3.8, 1.05, 0),
			stoneColor,
			Enum.Material.Plastic,
			false
		)
	end
	seat.CanQuery = false
	back.CanQuery = false
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
	self.mapDecorBuilt = false
	self.laserOrigin = nil
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
		Color3.fromRGB(49, 139, 56),
		Enum.Material.Plastic,
		true
	)
	platform.CanQuery = false

	-- The twelve-by-twelve panels meet edge-to-edge to form one connected baseplate.
	local panelCount = 12
	local panelSize = size / panelCount
	for gridX = 1, panelCount do
		for gridZ = 1, panelCount do
			local offsetX = (gridX - (panelCount + 1) / 2) * panelSize
			local offsetZ = (gridZ - (panelCount + 1) / 2) * panelSize
			local panel = createPart(
				decor,
				"LobbyFloorPanel_" .. tostring(gridX) .. "_" .. tostring(gridZ),
				Vector3.new(panelSize, 0.2, panelSize),
				center + Vector3.new(offsetX, 1.61, offsetZ),
				(gridX + gridZ) % 2 == 0 and Color3.fromRGB(73, 160, 65) or Color3.fromRGB(64, 148, 58),
				Enum.Material.Plastic,
				false
			)
			addSquareStuds(panel, Color3.fromRGB(112, 204, 83), 1.15, 0.26)
			panel.CanQuery = false
		end
	end

	local poolCenter = center + Vector3.new(0, 1.76, 0)
	local pool = createPart(
		decor,
		"LobbyWater",
		Vector3.new(18, 0.24, 12),
		poolCenter,
		Color3.fromRGB(44, 145, 220),
		Enum.Material.Water,
		false
	)
	pool.Transparency = 0.08
	pool.CanTouch = false
	pool.CanQuery = false

	local poolRimColor = Color3.fromRGB(185, 185, 185)
	local poolNorth = createPart(decor, "PoolNorthRim", Vector3.new(21, 1.2, 1.2), poolCenter + Vector3.new(0, 0.55, -6.6), poolRimColor, Enum.Material.Plastic, false)
	local poolSouth = createPart(decor, "PoolSouthRim", Vector3.new(21, 1.2, 1.2), poolCenter + Vector3.new(0, 0.55, 6.6), poolRimColor, Enum.Material.Plastic, false)
	local poolEast = createPart(decor, "PoolEastRim", Vector3.new(1.2, 1.2, 12), poolCenter + Vector3.new(9.6, 0.55, 0), poolRimColor, Enum.Material.Plastic, false)
	local poolWest = createPart(decor, "PoolWestRim", Vector3.new(1.2, 1.2, 12), poolCenter + Vector3.new(-9.6, 0.55, 0), poolRimColor, Enum.Material.Plastic, false)
	for _, rim in ipairs({poolNorth, poolSouth, poolEast, poolWest}) do
		rim.CanQuery = false
		rim.CanTouch = false
	end

	for side = -1, 1, 2 do
		addBench(
			decor,
			"LobbyBench_" .. tostring(side),
			center + Vector3.new(side * (half - 17), 0, half - 20),
			Color3.fromRGB(124, 82, 43),
			poolRimColor
		)
		addTree(
			decor,
			"LobbyTree_" .. tostring(side),
			center + Vector3.new(side * (half - 17), 0, -half + 20),
			0.85,
			Color3.fromRGB(111, 72, 41),
			Color3.fromRGB(42, 153, 58)
		)
	end

	local gateZ = center.Z - half + 3
	for side = -1, 1, 2 do
		addSquareColumn(
			decor,
			"LobbyEntranceColumn_" .. tostring(side),
			Vector3.new(center.X + side * 16, center.Y + 1.5, gateZ),
			5,
			13,
			Color3.fromRGB(54, 115, 203),
			Color3.fromRGB(255, 207, 56)
		)
	end
	local gateTop = createPart(
		decor,
		"LobbyEntranceHeader",
		Vector3.new(38, 4, 5),
		Vector3.new(center.X, center.Y + 18, gateZ),
		Color3.fromRGB(232, 60, 60),
		Enum.Material.Plastic,
		false
	)
	addSquareStuds(gateTop, Color3.fromRGB(255, 207, 56), 1.1, 0.25)
	gateTop.CanQuery = false

	addSign(
		decor,
		"LobbyWelcomeSign",
		center + Vector3.new(0, 10, half - 2),
		Vector3.new(30, 7, 1.2),
		"WAITING LOBBY",
		"PRESS PLAY WHEN READY",
		center,
		Color3.fromRGB(47, 105, 190)
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
	orb.Reflectance = 0
	orb.CastShadow = false
	model.PrimaryPart = orb

	local laserOrigin = Instance.new("Attachment")
	laserOrigin.Name = "LaserOrigin"
	laserOrigin.Position = Vector3.new(0, -7.65, 0)
	laserOrigin.Parent = orb
	self.laserOrigin = laserOrigin

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

	-- The red lens is mounted under the sphere and its reticle faces straight down.
	local lensNormal = Vector3.new(0, -1, 0)
	local lensCenter = base + lensNormal * 7.05
	local function lensFrameAt(position)
		return CFrame.fromMatrix(position, lensNormal, Vector3.new(0, 0, -1), Vector3.new(1, 0, 0))
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
	lens.Reflectance = 0
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
				0.34,
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
		Vector3.new(0.34, 0, 0),
		reticleColor
	)
	lensDetail(
		"LensReticleVertical",
		Vector3.new(0.09, 0.1, 2.7),
		Vector3.new(0.34, 0, 0),
		reticleColor
	)
	lensDetail(
		"LensReticleCenter",
		Vector3.new(0.12, 0.34, 0.34),
		Vector3.new(0.38, 0, 0),
		Color3.fromRGB(255, 179, 162)
	)
	local highlightA = lensDetail(
		"LensWhiteHighlightA",
		Vector3.new(0.12, 0.82, 0.36),
		Vector3.new(0.4, -0.78, 0.48),
		Color3.fromRGB(255, 255, 246)
	)
	highlightA.Shape = Enum.PartType.Ball

	local highlightB = lensDetail(
		"LensWhiteHighlightB",
		Vector3.new(0.1, 0.46, 0.18),
		Vector3.new(0.4, 0.72, -0.68),
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

	self.aircraftModel = model
end

function ArenaService:_setLighting(_theme)
	-- Return to neutral Roblox daytime lighting without custom sky or post-processing.
	Lighting.Brightness = 2
	Lighting.ClockTime = 14
	Lighting.Ambient = Color3.fromRGB(0, 0, 0)
	Lighting.OutdoorAmbient = Color3.fromRGB(127, 127, 127)
	Lighting.ExposureCompensation = 0
	Lighting.EnvironmentDiffuseScale = 0
	Lighting.EnvironmentSpecularScale = 0
	Lighting.GlobalShadows = true
	Lighting.FogColor = Color3.fromRGB(192, 192, 192)
	Lighting.FogStart = 0
	Lighting.FogEnd = 100000

	for _, name in ipairs({
		"SkyfallSunriseSky",
		"SkyfallAtmosphere",
		"SkyfallColorCorrection",
		"SkyfallBloom",
		"SkyfallSunRays",
	}) do
		local effect = Lighting:FindFirstChild(name)
		if effect then
			effect:Destroy()
		end
	end

	local clouds = Workspace.Terrain:FindFirstChild("SkyfallClouds")
	if clouds then
		clouds:Destroy()
	end
end

function ArenaService:_buildMapDecoration(theme)
	local folder = self.mapFolder
	local center = Config.ARENA_CENTER
	local half = Config.ARENA_HALF_WIDTH
	local width = Config.ARENA_WIDTH

	-- The island support is well below the out-of-bounds line, so it never rescues falling players.
	local support = createPart(
		folder,
		"ClassicArenaSupport",
		Vector3.new(width + 26, 20, width + 26),
		center + Vector3.new(0, -60, 0),
		Color3.fromRGB(93, 74, 54),
		Enum.Material.Plastic,
		true
	)
	addSquareStuds(support, Color3.fromRGB(119, 91, 62), 1.35, 0.3)
	support.CanQuery = false

	local trim = createPart(
		folder,
		"ClassicArenaOuterTrim",
		Vector3.new(width + 18, 2, width + 18),
		center + Vector3.new(0, -1.8, 0),
		Color3.fromRGB(55, 105, 182),
		Enum.Material.Plastic,
		false
	)
	trim.CanQuery = false
	trim.CanTouch = false

	-- Four block towers frame the play area, without creating holes or gaps in the tiles.
	for sideX = -1, 1, 2 do
		for sideZ = -1, 1, 2 do
			addSquareColumn(
				folder,
				"ClassicCornerTower_" .. tostring(sideX) .. "_" .. tostring(sideZ),
				center + Vector3.new(sideX * (half + 12), -1, sideZ * (half + 12)),
				7,
				26,
				sideX == sideZ and theme.structure or theme.secondary,
				theme.accent
			)
		end
	end

	local gateZ = center.Z - half - 7
	for side = -1, 1, 2 do
		addSquareColumn(
			folder,
			"ClassicGatePillar_" .. tostring(side),
			Vector3.new(center.X + side * 18, center.Y - 1, gateZ),
			6,
			21,
			theme.structure,
			theme.accent
		)
	end
	local gateHeader = createPart(
		folder,
		"ClassicArenaGate",
		Vector3.new(42, 4, 5),
		Vector3.new(center.X, center.Y + 22, gateZ),
		theme.roof,
		Enum.Material.Plastic,
		false
	)
	addSquareStuds(gateHeader, theme.accent, 1.2, 0.28)
	gateHeader.CanQuery = false

	for side = -1, 1, 2 do
		addTree(
			folder,
			"ClassicArenaTree_" .. tostring(side),
			center + Vector3.new(side * (half + 14), -1, 22),
			1.05,
			Color3.fromRGB(111, 72, 41),
			side < 0 and Color3.fromRGB(46, 158, 62) or Color3.fromRGB(59, 174, 70)
		)
	end

	addSign(
		folder,
		"ClassicArenaNameSign",
		gateHeader.Position + Vector3.new(0, 11, 3.4),
		Vector3.new(38, 7, 1.2),
		"SKYFALL CLASSIC ARENA",
		"LAST RUNNER STANDING",
		center,
		theme.structure
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
	self.mapDecorBuilt = false

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

function ArenaService:SetMap(_mapId)
	local selected = MAPS[1]
	self.currentMapId = selected.id
	self.theme = selected

	for _, tile in pairs(self.tiles) do
		local token = (tile:GetAttribute("StrikeToken") or 0) + 1
		tile:SetAttribute("StrikeToken", token)
		tile:SetAttribute("IsBroken", false)
		tile:SetAttribute("IsWarning", false)
		tile.Color = selected.tileColor
		tile.Material = selected.tileMaterial
		tile.CanCollide = true
		tile.Transparency = 0
		local warningLight = tile:FindFirstChild("TargetWarningLight")
		if warningLight then
			warningLight:Destroy()
		end
		setTileStudState(tile, false, selected.studColor)
	end

	if not self.mapDecorBuilt then
		self:_buildMapDecoration(selected)
		self.mapDecorBuilt = true
	end
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
	tile.Color = Color3.fromRGB(255, 55, 75)
	tile.Material = Enum.Material.SmoothPlastic

	local warningLight = Instance.new("PointLight")
	warningLight.Name = "TargetWarningLight"
	warningLight.Color = Color3.fromRGB(255, 52, 72)
	warningLight.Brightness = 1.25
	warningLight.Range = 10
	warningLight.Parent = tile
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
	tile:SetAttribute("IsWarning", false)
	local warningLight = tile:FindFirstChild("TargetWarningLight")
	if warningLight then
		warningLight:Destroy()
	end
	tile.Color = self.theme.tileColor
end

function ArenaService:CreateStrikeBeam(tile)
	if not self.laserOrigin or not self.laserOrigin.Parent or not tile or not tile.Parent then
		return
	end

	local target = Instance.new("Attachment")
	target.Name = "LaserImpactAttachment"
	target.Position = Vector3.new(0, 0.65, 0)
	target.Parent = tile

	local outerBeam = Instance.new("Beam")
	outerBeam.Name = "BlueLaserOuter"
	outerBeam.Attachment0 = self.laserOrigin
	outerBeam.Attachment1 = target
	outerBeam.FaceCamera = true
	outerBeam.Width0 = 3.2
	outerBeam.Width1 = 2.4
	outerBeam.Segments = 1
	outerBeam.LightEmission = 0.9
	outerBeam.LightInfluence = 0
	outerBeam.Color = ColorSequence.new(
		Color3.fromRGB(44, 117, 255),
		Color3.fromRGB(54, 195, 255)
	)
	outerBeam.Transparency = NumberSequence.new(0.24)
	outerBeam.Parent = self.root

	local innerBeam = Instance.new("Beam")
	innerBeam.Name = "BlueLaserCore"
	innerBeam.Attachment0 = self.laserOrigin
	innerBeam.Attachment1 = target
	innerBeam.FaceCamera = true
	innerBeam.Width0 = 0.95
	innerBeam.Width1 = 0.72
	innerBeam.Segments = 1
	innerBeam.LightEmission = 1
	innerBeam.LightInfluence = 0
	innerBeam.Color = ColorSequence.new(
		Color3.fromRGB(198, 239, 255),
		Color3.fromRGB(255, 255, 255)
	)
	innerBeam.Transparency = NumberSequence.new(0.08)
	innerBeam.Parent = self.root

	local impact = createPart(
		self.root,
		"BlueLaserImpact",
		Vector3.new(0.22, 6.2, 6.2),
		tile.Position + Vector3.new(0, 0.78, 0),
		Color3.fromRGB(77, 190, 255),
		Enum.Material.Glass,
		false
	)
	impact.Shape = Enum.PartType.Cylinder
	impact.CFrame = CFrame.new(impact.Position) * CFrame.Angles(0, 0, math.rad(90))
	impact.Transparency = 0.28
	impact.CanTouch = false
	impact.CanQuery = false

	local beamLight = Instance.new("PointLight")
	beamLight.Color = Color3.fromRGB(64, 168, 255)
	beamLight.Brightness = 2
	beamLight.Range = 18
	beamLight.Parent = impact

	Debris:AddItem(outerBeam, 0.48)
	Debris:AddItem(innerBeam, 0.48)
	Debris:AddItem(target, 0.48)
	Debris:AddItem(impact, 0.32)
end

function ArenaService:BreakTile(tile, token)
	if not self:IsStrikeCurrent(tile, token) then
		return
	end

	tile:SetAttribute("IsWarning", false)
	local warningLight = tile:FindFirstChild("TargetWarningLight")
	if warningLight then
		warningLight:Destroy()
	end
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
	return CFrame.new(Config.CONTROLLER_HIDDEN_POSITION)
end

return ArenaService
