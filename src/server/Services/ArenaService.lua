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
		name = "NEXUS SKYGRID",
		tileColor = Color3.fromRGB(35, 58, 83),
		tileMaterial = Enum.Material.Metal,
		warningColor = Color3.fromRGB(255, 131, 55),
		brokenColor = Color3.fromRGB(85, 30, 48),
		accent = Color3.fromRGB(54, 220, 245),
		accent2 = Color3.fromRGB(68, 116, 204),
		structure = Color3.fromRGB(29, 48, 75),
		clockTime = 20,
		ambient = Color3.fromRGB(44, 63, 92),
		fogColor = Color3.fromRGB(15, 31, 57),
		fogDensity = 0.24,
	},
	{
		id = 2,
		name = "EMBER REACTOR",
		tileColor = Color3.fromRGB(62, 48, 47),
		tileMaterial = Enum.Material.Slate,
		warningColor = Color3.fromRGB(255, 202, 74),
		brokenColor = Color3.fromRGB(96, 30, 24),
		accent = Color3.fromRGB(255, 132, 58),
		accent2 = Color3.fromRGB(226, 74, 48),
		structure = Color3.fromRGB(52, 37, 37),
		clockTime = 18.2,
		ambient = Color3.fromRGB(82, 54, 42),
		fogColor = Color3.fromRGB(63, 29, 26),
		fogDensity = 0.3,
	},
}

local function createPart(parent, name, size, position, color, material, canCollide)
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.Position = position
	part.Color = color
	part.Material = material
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

local function addNeonBar(parent, name, size, position, color, rotation)
	local bar = createPart(
		parent,
		name,
		size,
		position,
		color,
		Enum.Material.Neon,
		false
	)
	if rotation then
		bar.CFrame = CFrame.new(position) * rotation
	end
	bar.Transparency = 0.14
	bar.CanTouch = false
	bar.CanQuery = false
	return bar
end

local function addSign(parent, name, position, size, title, subtitle, facePosition, accent)
	local board = createPart(
		parent,
		name,
		size,
		position,
		Color3.fromRGB(12, 22, 37),
		Enum.Material.Metal,
		false
	)
	if facePosition then
		board.CFrame = CFrame.lookAt(position, facePosition)
	end
	board.CanQuery = false

	local gui = Instance.new("SurfaceGui")
	gui.Name = "SignSurface"
	gui.Face = Enum.NormalId.Front
	gui.LightInfluence = 0
	gui.PixelsPerStud = 45
	gui.Parent = board

	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Color3.fromRGB(12, 22, 37)
	frame.BackgroundTransparency = 0.08
	frame.BorderSizePixel = 0
	frame.Parent = gui

	local heading = Instance.new("TextLabel")
	heading.Name = "Heading"
	heading.Size = UDim2.new(1, -14, 0.58, 0)
	heading.Position = UDim2.fromOffset(7, 2)
	heading.BackgroundTransparency = 1
	heading.Font = Enum.Font.GothamBlack
	heading.Text = title
	heading.TextColor3 = Color3.fromRGB(237, 246, 255)
	heading.TextScaled = true
	heading.Parent = frame

	local detail = Instance.new("TextLabel")
	detail.Name = "Subtitle"
	detail.Size = UDim2.new(1, -16, 0.32, 0)
	detail.Position = UDim2.new(0, 8, 0.62, 0)
	detail.BackgroundTransparency = 1
	detail.Font = Enum.Font.GothamMedium
	detail.Text = subtitle
	detail.TextColor3 = accent
	detail.TextScaled = true
	detail.Parent = frame

	local outline = Instance.new("UIStroke")
	outline.Color = accent
	outline.Thickness = 1.5
	outline.Parent = frame

	return board
end

local function tileKey(gridX, gridZ)
	return tostring(gridX) .. ":" .. tostring(gridZ)
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
	self.rotors = {}
	self.aircraftModel = nil
	self.aircraftBasePosition = Config.CONTROL_CENTER
	return self
end

function ArenaService:_buildLobby()
	local decor = self.lobbyFolder
	local center = Config.LOBBY_CENTER
	local size = Config.LOBBY_SIZE
	local half = size / 2

	local platform = createPart(
		decor,
		"WaitingPlatform",
		Vector3.new(size, 3, size),
		center,
		Color3.fromRGB(25, 40, 60),
		Enum.Material.DiamondPlate
	)
	platform.CanQuery = false

	local trimY = center.Y + 1.8
	addNeonBar(
		decor,
		"LobbyNorthTrim",
		Vector3.new(size, 0.5, 1.2),
		center + Vector3.new(0, trimY - center.Y, -half),
		Color3.fromRGB(64, 211, 239)
	)
	addNeonBar(
		decor,
		"LobbySouthTrim",
		Vector3.new(size, 0.5, 1.2),
		center + Vector3.new(0, trimY - center.Y, half),
		Color3.fromRGB(64, 211, 239)
	)
	addNeonBar(
		decor,
		"LobbyEastTrim",
		Vector3.new(1.2, 0.5, size),
		center + Vector3.new(half, trimY - center.Y, 0),
		Color3.fromRGB(83, 132, 221)
	)
	addNeonBar(
		decor,
		"LobbyWestTrim",
		Vector3.new(1.2, 0.5, size),
		center + Vector3.new(-half, trimY - center.Y, 0),
		Color3.fromRGB(83, 132, 221)
	)

	for xSign = -1, 1, 2 do
		for zSign = -1, 1, 2 do
			local pillarPosition = center + Vector3.new(xSign * (half - 6), 13, zSign * (half - 6))
			local pillar = createPart(
				decor,
				"LobbyPillar_" .. tostring(xSign) .. "_" .. tostring(zSign),
				Vector3.new(3.5, 25, 3.5),
				pillarPosition,
				Color3.fromRGB(37, 57, 83),
				Enum.Material.Metal,
				false
			)
			pillar.CanQuery = false

			local cap = createPart(
				decor,
				"LobbyPillarCap_" .. tostring(xSign) .. "_" .. tostring(zSign),
				Vector3.new(5, 1.2, 5),
				pillarPosition + Vector3.new(0, 13, 0),
				Color3.fromRGB(65, 205, 234),
				Enum.Material.Neon,
				false
			)
			cap.CanTouch = false
			cap.CanQuery = false
		end
	end

	for index = 1, 8 do
		local angle = ((index - 1) / 8) * math.pi * 2
		local offset = Vector3.new(math.cos(angle) * 25, 1.9, math.sin(angle) * 25)
		local pad = createPart(
			decor,
			"PlayerSpawnPad_" .. tostring(index),
			Vector3.new(9, 0.65, 9),
			center + offset,
			Color3.fromRGB(46, 105, 139),
			Enum.Material.Metal,
			false
		)
		pad.Shape = Enum.PartType.Cylinder
		pad.CFrame = CFrame.new(center + offset) * CFrame.Angles(0, 0, math.rad(90))
		pad.CanTouch = false
		pad.CanQuery = false

		local padRing = createPart(
			decor,
			"PlayerSpawnRing_" .. tostring(index),
			Vector3.new(10, 0.22, 10),
			center + offset + Vector3.new(0, 0.42, 0),
			index % 2 == 0 and Color3.fromRGB(78, 143, 238) or Color3.fromRGB(54, 220, 245),
			Enum.Material.Neon,
			false
		)
		padRing.Shape = Enum.PartType.Cylinder
		padRing.CFrame = CFrame.new(center + offset + Vector3.new(0, 0.42, 0))
			* CFrame.Angles(0, 0, math.rad(90))
		padRing.CanTouch = false
		padRing.CanQuery = false
		padRing.Transparency = 0.18
	end

	local centerPad = createPart(
		decor,
		"LobbyCenterPad",
		Vector3.new(25, 1, 25),
		center + Vector3.new(0, 1.95, 0),
		Color3.fromRGB(35, 55, 78),
		Enum.Material.Metal,
		false
	)
	centerPad.Shape = Enum.PartType.Cylinder
	centerPad.CFrame = CFrame.new(center + Vector3.new(0, 1.95, 0))
		* CFrame.Angles(0, 0, math.rad(90))
	centerPad.CanTouch = false
	centerPad.CanQuery = false

	local centerCore = createPart(
		decor,
		"LobbyCore",
		Vector3.new(4, 7, 4),
		center + Vector3.new(0, 6, 0),
		Color3.fromRGB(54, 220, 245),
		Enum.Material.Neon,
		false
	)
	centerCore.CanTouch = false
	centerCore.CanQuery = false

	local coreLight = Instance.new("PointLight")
	coreLight.Color = Color3.fromRGB(54, 220, 245)
	coreLight.Brightness = 1.7
	coreLight.Range = 28
	coreLight.Parent = centerCore

	for side = -1, 1, 2 do
		local gatePillar = createPart(
			decor,
			"LobbyGatePillar_" .. tostring(side),
			Vector3.new(3, 15, 3),
			center + Vector3.new(side * 19, 8.8, half - 8),
			Color3.fromRGB(37, 57, 83),
			Enum.Material.Metal,
			false
		)
		gatePillar.CanQuery = false

		addNeonBar(
			decor,
			"LobbyGateLight_" .. tostring(side),
			Vector3.new(0.6, 13, 0.6),
			gatePillar.Position,
			Color3.fromRGB(54, 220, 245)
		)
	end

	local gateTop = createPart(
		decor,
		"LobbyGateTop",
		Vector3.new(41, 2, 3),
		center + Vector3.new(0, 16.2, half - 8),
		Color3.fromRGB(38, 60, 88),
		Enum.Material.Metal,
		false
	)
	gateTop.CanQuery = false

	addNeonBar(
		decor,
		"LobbyGateTopLight",
		Vector3.new(37, 0.5, 0.5),
		gateTop.Position + Vector3.new(0, 1.1, 0),
		Color3.fromRGB(54, 220, 245)
	)

	addSign(
		decor,
		"LobbyWelcomeSign",
		center + Vector3.new(0, 19, -half + 3),
		Vector3.new(42, 12, 2),
		"WAITING BAY",
		"NEXT ROUND STARTS HERE",
		center,
		Color3.fromRGB(54, 220, 245)
	)

	local floorLine = createPart(
		decor,
		"LobbyCenterLine",
		Vector3.new(1, 0.2, 48),
		center + Vector3.new(0, 1.62, 0),
		Color3.fromRGB(46, 100, 138),
		Enum.Material.Neon,
		false
	)
	floorLine.CanTouch = false
	floorLine.CanQuery = false
end

function ArenaService:_buildAircraft()
	local folder = self.aircraftFolder
	local model = Instance.new("Model")
	model.Name = "SkyfallLaserAircraft"
	model.Parent = folder

	local base = Config.CONTROL_CENTER
	self.aircraftBasePosition = base
	self.rotors = {}

	local function part(name, size, offset, color, material, shape)
		local item = createPart(
			model,
			name,
			size,
			base + offset,
			color,
			material,
			false
		)
		if shape then
			item.Shape = shape
		end
		item.CanTouch = false
		item.CanQuery = false
		return item
	end

	local fuselage = part(
		"AircraftFuselage",
		Vector3.new(8, 3.6, 21),
		Vector3.new(0, -1, 0),
		Color3.fromRGB(48, 68, 96),
		Enum.Material.Metal
	)
	model.PrimaryPart = fuselage

	part(
		"AircraftNose",
		Vector3.new(6, 2.6, 7),
		Vector3.new(0, -0.7, -13),
		Color3.fromRGB(78, 104, 137),
		Enum.Material.Metal,
		Enum.PartType.Ball
	)

	local cockpit = part(
		"AircraftCockpit",
		Vector3.new(5.4, 2.2, 5.5),
		Vector3.new(0, 1.6, -4.5),
		Color3.fromRGB(77, 190, 222),
		Enum.Material.Glass,
		Enum.PartType.Ball
	)
	cockpit.Transparency = 0.2

	part(
		"AircraftWings",
		Vector3.new(32, 1.5, 7),
		Vector3.new(0, -0.8, 1),
		Color3.fromRGB(38, 54, 82),
		Enum.Material.Metal
	)

	part(
		"AircraftWingLeftLight",
		Vector3.new(0.55, 0.5, 5.2),
		Vector3.new(-15.3, 0.05, 1),
		Color3.fromRGB(54, 220, 245),
		Enum.Material.Neon
	)
	part(
		"AircraftWingRightLight",
		Vector3.new(0.55, 0.5, 5.2),
		Vector3.new(15.3, 0.05, 1),
		Color3.fromRGB(255, 92, 88),
		Enum.Material.Neon
	)

	part(
		"AircraftTailWing",
		Vector3.new(12, 1.2, 3.5),
		Vector3.new(0, 0.2, 11.2),
		Color3.fromRGB(38, 54, 82),
		Enum.Material.Metal
	)
	part(
		"AircraftTailFin",
		Vector3.new(1.2, 5.5, 4),
		Vector3.new(0, 2.5, 11.2),
		Color3.fromRGB(65, 93, 128),
		Enum.Material.Metal
	)

	for side = -1, 1, 2 do
		local engineOffset = Vector3.new(side * 12, -0.9, 2)
		local engine = part(
			"AircraftEngine_" .. tostring(side),
			Vector3.new(3.5, 3.5, 9),
			engineOffset,
			Color3.fromRGB(30, 45, 70),
			Enum.Material.Metal,
			Enum.PartType.Cylinder
		)
		engine.CFrame = CFrame.new(base + engineOffset) * CFrame.Angles(math.rad(90), 0, 0)

		local engineGlow = part(
			"AircraftEngineGlow_" .. tostring(side),
			Vector3.new(2.1, 2.1, 1),
			engineOffset + Vector3.new(0, 0, 4.5),
			Color3.fromRGB(54, 220, 245),
			Enum.Material.Neon,
			Enum.PartType.Ball
		)
		local engineLight = Instance.new("PointLight")
		engineLight.Color = Color3.fromRGB(54, 220, 245)
		engineLight.Brightness = 1.3
		engineLight.Range = 16
		engineLight.Parent = engineGlow

		local rotorCenter = base + engineOffset + Vector3.new(0, 2.5, -0.2)
		local bladeA = part(
			"AircraftRotorA_" .. tostring(side),
			Vector3.new(0.4, 0.18, 6),
			engineOffset + Vector3.new(0, 2.5, -0.2),
			Color3.fromRGB(174, 198, 222),
			Enum.Material.Metal
		)
		local bladeB = part(
			"AircraftRotorB_" .. tostring(side),
			Vector3.new(0.4, 0.18, 6),
			engineOffset + Vector3.new(0, 2.5, -0.2),
			Color3.fromRGB(174, 198, 222),
			Enum.Material.Metal
		)
		table.insert(self.rotors, {
			center = rotorCenter,
			bladeA = bladeA,
			bladeB = bladeB,
		})
	end

	local laserPod = part(
		"AircraftLaserPod",
		Vector3.new(3.2, 2.5, 5),
		Vector3.new(0, -3.3, -2),
		Color3.fromRGB(32, 44, 68),
		Enum.Material.Metal
	)
	laserPod.CanCollide = false

	local emitter = part(
		"AircraftLaserEmitter",
		Vector3.new(2.2, 2.2, 2.2),
		Vector3.new(0, -4.6, -2),
		Color3.fromRGB(255, 64, 76),
		Enum.Material.Neon,
		Enum.PartType.Ball
	)
	local emitterLight = Instance.new("PointLight")
	emitterLight.Color = Color3.fromRGB(255, 64, 76)
	emitterLight.Brightness = 2.8
	emitterLight.Range = 38
	emitterLight.Parent = emitter

	local pilotPlatform = createPart(
		folder,
		"PilotPlatform",
		Vector3.new(25, 2, 24),
		base + Vector3.new(0, -17, 18),
		Color3.fromRGB(28, 44, 69),
		Enum.Material.DiamondPlate,
		true
	)
	pilotPlatform.CanQuery = false

	for side = -1, 1, 2 do
		createPart(
			folder,
			"PilotRail_" .. tostring(side),
			Vector3.new(1, 5, 22),
			pilotPlatform.Position + Vector3.new(side * 12, 3, 0),
			Color3.fromRGB(63, 104, 145),
			Enum.Material.Metal,
			true
		)
		addNeonBar(
			folder,
			"PilotRailLight_" .. tostring(side),
			Vector3.new(0.2, 0.25, 20),
			pilotPlatform.Position + Vector3.new(side * 12, 5.6, 0),
			Color3.fromRGB(54, 220, 245)
		)
	end

	addSign(
		folder,
		"PilotStationSign",
		pilotPlatform.Position + Vector3.new(0, 8, 11),
		Vector3.new(18, 5, 1),
		"LASER PILOT",
		"SELECT A FLOOR TILE",
		pilotPlatform.Position,
		Color3.fromRGB(255, 92, 88)
	)

	self.aircraftModel = model

	task.spawn(function()
		local angle = 0
		while model.Parent do
			angle = (angle + 0.32) % (math.pi * 2)
			for _, rotor in ipairs(self.rotors) do
				rotor.bladeA.CFrame = CFrame.new(rotor.center) * CFrame.Angles(0, angle, 0)
				rotor.bladeB.CFrame = CFrame.new(rotor.center) * CFrame.Angles(0, angle + math.pi / 2, 0)
			end
			task.wait(0.04)
		end
	end)
end

function ArenaService:_setLighting(theme)
	Lighting.ClockTime = theme.clockTime
	Lighting.Brightness = 2
	Lighting.Ambient = theme.ambient
	Lighting.OutdoorAmbient = theme.ambient:Lerp(Color3.new(0, 0, 0), 0.25)
	Lighting.FogColor = theme.fogColor
	Lighting.FogStart = 95
	Lighting.FogEnd = 360
	Lighting.GlobalShadows = true
	Lighting.EnvironmentDiffuseScale = 0.55
	Lighting.EnvironmentSpecularScale = 0.65

	local atmosphere = Lighting:FindFirstChild("SkyfallAtmosphere")
	if not atmosphere then
		atmosphere = Instance.new("Atmosphere")
		atmosphere.Name = "SkyfallAtmosphere"
		atmosphere.Parent = Lighting
	end
	atmosphere.Color = theme.fogColor:Lerp(Color3.fromRGB(180, 198, 220), 0.35)
	atmosphere.Decay = theme.fogColor
	atmosphere.Density = theme.fogDensity
	atmosphere.Glare = 0.12
	atmosphere.Haze = 1.2
	atmosphere.Offset = 0.15

	local colorCorrection = Lighting:FindFirstChild("SkyfallColorCorrection")
	if not colorCorrection then
		colorCorrection = Instance.new("ColorCorrectionEffect")
		colorCorrection.Name = "SkyfallColorCorrection"
		colorCorrection.Parent = Lighting
	end
	colorCorrection.Brightness = -0.02
	colorCorrection.Contrast = 0.12
	colorCorrection.Saturation = -0.04
	colorCorrection.TintColor = theme.accent:Lerp(Color3.new(1, 1, 1), 0.8)

	local bloom = Lighting:FindFirstChild("SkyfallBloom")
	if not bloom then
		bloom = Instance.new("BloomEffect")
		bloom.Name = "SkyfallBloom"
		bloom.Parent = Lighting
	end
	bloom.Intensity = 0.25
	bloom.Size = 20
	bloom.Threshold = 1.4
end

function ArenaService:_buildMapDecoration(theme)
	local folder = self.mapFolder
	local gridHalf = ((Config.GRID_SIZE - 1) * (Config.TILE_SIZE + Config.TILE_GAP)) / 2
	local edge = gridHalf + 8
	local y = Config.ARENA_CENTER.Y - 0.12

	addNeonBar(
		folder,
		"MapNorthBorder",
		Vector3.new(edge * 2, 0.8, 1.1),
		Config.ARENA_CENTER + Vector3.new(0, y - Config.ARENA_CENTER.Y, -edge),
		theme.accent
	)
	addNeonBar(
		folder,
		"MapSouthBorder",
		Vector3.new(edge * 2, 0.8, 1.1),
		Config.ARENA_CENTER + Vector3.new(0, y - Config.ARENA_CENTER.Y, edge),
		theme.accent
	)
	addNeonBar(
		folder,
		"MapEastBorder",
		Vector3.new(1.1, 0.8, edge * 2),
		Config.ARENA_CENTER + Vector3.new(edge, y - Config.ARENA_CENTER.Y, 0),
		theme.accent2
	)
	addNeonBar(
		folder,
		"MapWestBorder",
		Vector3.new(1.1, 0.8, edge * 2),
		Config.ARENA_CENTER + Vector3.new(-edge, y - Config.ARENA_CENTER.Y, 0),
		theme.accent2
	)

	for xSign = -1, 1, 2 do
		for zSign = -1, 1, 2 do
			local position = Config.ARENA_CENTER + Vector3.new(
				xSign * (edge + 7),
				15,
				zSign * (edge + 7)
			)
			local tower = createPart(
				folder,
				"MapTower_" .. tostring(xSign) .. "_" .. tostring(zSign),
				Vector3.new(5, 27, 5),
				position,
				theme.structure,
				Enum.Material.Metal,
				false
			)
			tower.CanQuery = false

			local crown = createPart(
				folder,
				"MapTowerCrown_" .. tostring(xSign) .. "_" .. tostring(zSign),
				Vector3.new(8, 1.2, 8),
				position + Vector3.new(0, 14, 0),
				theme.accent,
				Enum.Material.Neon,
				false
			)
			crown.CanTouch = false
			crown.CanQuery = false

			local light = Instance.new("PointLight")
			light.Color = theme.accent
			light.Brightness = 1
			light.Range = 18
			light.Parent = crown
		end
	end

	if theme.id == 1 then
		for ringIndex = 1, 2 do
			local radius = edge + 17 + ringIndex * 5
			for index = 1, 16 do
				local angle = ((index - 1) / 16) * math.pi * 2
				local position = Config.ARENA_CENTER + Vector3.new(
					math.cos(angle) * radius,
					7 + ringIndex * 2,
					math.sin(angle) * radius
				)
				local segment = createPart(
					folder,
					"NexusRingSegment_" .. tostring(ringIndex) .. "_" .. tostring(index),
					Vector3.new(2.4, 1.1, 7),
					position,
					ringIndex == 1 and theme.accent or theme.accent2,
					Enum.Material.Neon,
					false
				)
				segment.CFrame = CFrame.lookAt(position, Config.ARENA_CENTER)
				segment.CanTouch = false
				segment.CanQuery = false
				segment.Transparency = 0.18
			end
		end

		addSign(
			folder,
			"MapNameSign",
			Config.ARENA_CENTER + Vector3.new(0, 28, -edge - 12),
			Vector3.new(34, 8, 1.5),
			"NEXUS SKYGRID",
			"SECTOR 01",
			Config.ARENA_CENTER,
			theme.accent
		)
	else
		local reactorCenter = Config.ARENA_CENTER + Vector3.new(0, 3, 0)
		for ringIndex = 1, 3 do
			local radius = edge + 10 + ringIndex * 4
			local ring = createPart(
				folder,
				"ReactorRing_" .. tostring(ringIndex),
				Vector3.new(1.2, radius * 2, radius * 2),
				reactorCenter + Vector3.new(0, ringIndex * 1.3, 0),
				ringIndex == 2 and theme.accent2 or theme.accent,
				Enum.Material.Neon,
				false
			)
			ring.Shape = Enum.PartType.Cylinder
			ring.CFrame = CFrame.new(reactorCenter + Vector3.new(0, ringIndex * 1.3, 0))
				* CFrame.Angles(0, 0, math.rad(90))
			ring.Transparency = 0.62 + ringIndex * 0.06
			ring.CanTouch = false
			ring.CanQuery = false
		end

		for index = 1, 6 do
			local angle = ((index - 1) / 6) * math.pi * 2
			local position = Config.ARENA_CENTER + Vector3.new(
				math.cos(angle) * (edge + 22),
				8,
				math.sin(angle) * (edge + 22)
			)
			local vent = createPart(
				folder,
				"ReactorVent_" .. tostring(index),
				Vector3.new(10, 1.2, 5),
				position,
				theme.structure,
				Enum.Material.DiamondPlate,
				false
			)
			vent.CFrame = CFrame.lookAt(position, Config.ARENA_CENTER)
			vent.CanTouch = false
			vent.CanQuery = false

			local ventLight = createPart(
				folder,
				"ReactorVentLight_" .. tostring(index),
				Vector3.new(7, 0.25, 1),
				position + Vector3.new(0, 0.75, 0),
				theme.accent,
				Enum.Material.Neon,
				false
			)
			ventLight.CFrame = vent.CFrame * CFrame.new(0, 0.75, 0)
			ventLight.CanTouch = false
			ventLight.CanQuery = false
		end

		addSign(
			folder,
			"MapNameSign",
			Config.ARENA_CENTER + Vector3.new(0, 28, -edge - 12),
			Vector3.new(34, 8, 1.5),
			"EMBER REACTOR",
			"SECTOR 02",
			Config.ARENA_CENTER,
			theme.accent
		)
	end
end

function ArenaService:Build()
	for _, child in ipairs(self.tilesFolder:GetChildren()) do
		child:Destroy()
	end
	for _, child in ipairs(self.decorFolder:GetChildren()) do
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
	tile.Material = Enum.Material.Neon
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
		"LaserBeamGlow",
		Vector3.new(5, Config.BEAM_HEIGHT, 5),
		beamPosition,
		Color3.fromRGB(255, 45, 78),
		Enum.Material.Neon,
		false
	)
	outerBeam.Transparency = 0.58
	outerBeam.CanTouch = false
	outerBeam.CanQuery = false

	local innerBeam = createPart(
		self.root,
		"LaserBeamCore",
		Vector3.new(1.6, Config.BEAM_HEIGHT, 1.6),
		beamPosition,
		Color3.fromRGB(255, 235, 235),
		Enum.Material.Neon,
		false
	)
	innerBeam.Transparency = 0.08
	innerBeam.CanTouch = false
	innerBeam.CanQuery = false

	local beamLight = Instance.new("PointLight")
	beamLight.Color = Color3.fromRGB(255, 57, 78)
	beamLight.Brightness = 4
	beamLight.Range = 34
	beamLight.Parent = innerBeam

	local impact = createPart(
		self.root,
		"LaserImpact",
		Vector3.new(7, 2, 7),
		tile.Position + Vector3.new(0, 1.1, 0),
		self.theme.warningColor,
		Enum.Material.Neon,
		false
	)
	impact.Shape = Enum.PartType.Ball
	impact.Transparency = 0.35
	impact.CanTouch = false
	impact.CanQuery = false

	Debris:AddItem(outerBeam, 0.45)
	Debris:AddItem(innerBeam, 0.45)
	Debris:AddItem(impact, 0.35)
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
	tile.Transparency = 0.82
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
	end
end

function ArenaService:GetLobbySpawnCFrame(index, total, isBot)
	local spawnIndex = math.max(1, index or 1)
	local spawnTotal = math.max(1, total or 1)
	local angle = ((spawnIndex - 1) / spawnTotal) * math.pi * 2
	local radius = isBot and 36 or 24
	local position = Config.LOBBY_CENTER + Vector3.new(
		math.cos(angle) * radius,
		5,
		math.sin(angle) * radius
	)
	return CFrame.new(position)
end

function ArenaService:GetRunnerSpawnCFrame(index, total)
	local angle = ((index - 1) / math.max(total, 1)) * math.pi * 2
	local radius = 38
	local position = Config.ARENA_CENTER + Vector3.new(
		math.cos(angle) * radius,
		5,
		math.sin(angle) * radius
	)
	return CFrame.new(position)
end

function ArenaService:GetControllerSpawnCFrame()
	return CFrame.new(Config.CONTROL_CENTER + Vector3.new(0, -10, 18))
end

return ArenaService
