local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared", 8):WaitForChild("GameConfig", 8))
local WorldDesignProfile = require(ReplicatedStorage:WaitForChild("Shared", 8):WaitForChild("WorldDesignProfile", 8))
local LaserVFX = require(script.Parent:WaitForChild("LaserVFX", 8))
local MagicCircleVFX = require(script.Parent:WaitForChild("MagicCircleVFX", 8))
local FloorAppearanceService = require(script.Parent:WaitForChild("FloorAppearanceService", 8))
local ElementIntegrationService = require(script.Parent:WaitForChild("ElementIntegrationService", 8))
local SkyGardenMapBuilder = require(script.Parent:WaitForChild("SkyGardenMapBuilder", 8))
local LightingProfileService = require(script.Parent:WaitForChild("LightingProfileService", 8))
local ArenaStartupPolicy = require(ReplicatedStorage:WaitForChild("Shared", 8):WaitForChild("ArenaStartupPolicy", 8))

local ArenaService = {}
ArenaService.__index = ArenaService

local function paletteColor(rgb: { number }): Color3
	return Color3.fromRGB(rgb[1], rgb[2], rgb[3])
end

local MAPS = {
	{
		id = 1,
		name = "SKYFALL SKY GARDEN ARENA",
		tileColor = paletteColor(WorldDesignProfile.SkyGarden.PrimaryTile),
		tileAlternateColor = paletteColor(WorldDesignProfile.SkyGarden.AlternateTile),
		tileMaterial = Enum.Material.Plastic,
		useClassicStuds = true,
		studColor = Color3.fromRGB(112, 204, 83),
		warningColor = Color3.fromRGB(255, 48, 58),
		brokenColor = Color3.fromRGB(66, 76, 82),
		structure = Color3.fromRGB(52, 116, 196),
		roof = Color3.fromRGB(230, 61, 61),
		accent = Color3.fromRGB(255, 207, 56),
		secondary = Color3.fromRGB(64, 166, 220),
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
	part.CanTouch = false
	part.CastShadow = false
	part:SetAttribute("SkyfallGenerated", true)
	part.Parent = parent
	return part
end

local function createFolder(parent, name)
	local folder = Instance.new("Folder")
	folder.Name = name
	folder:SetAttribute("SkyfallGenerated", true)
	folder.Parent = parent
	return folder
end

local function getOrCreateFolder(parent, name)
	local existing = parent:FindFirstChild(name)
	if existing and existing:IsA("Folder") then
		return existing
	end
	if existing then
		warn("Skyfall expected a Folder named " .. name .. " under " .. parent:GetFullName() .. "; replacing the incompatible instance.")
		existing:Destroy()
	end
	return createFolder(parent, name)
end

-- Native Roblox retro surfaces render studs without thousands of child Parts.
-- SurfaceType is deprecated for automatic joining, but its Studs/Inlet visuals remain.
local function applyClassicStudSurface(basePart)
	basePart.TopSurface = Enum.SurfaceType.Studs
	basePart.BottomSurface = Enum.SurfaceType.Inlet
end

local function setTileSurface(tile, theme, hidden)
	local floorProfile = theme.floorAppearanceProfile
	if floorProfile then
		tile.TopSurface = floorProfile.TopSurface
		tile.BottomSurface = floorProfile.BottomSurface
		return
	end
	local useStuds = theme.useClassicStuds == true and not hidden
	tile.TopSurface = useStuds and Enum.SurfaceType.Studs or Enum.SurfaceType.Smooth
	tile.BottomSurface = useStuds and Enum.SurfaceType.Inlet or Enum.SurfaceType.Smooth
end

local function getTileBaseColor(tile, theme)
	-- Material is inherited from the lobby profile, but the map owns its palette.
	-- WaitingPlatform supplies the surface finish, not the Sky Garden color palette.
	local alternateColor = theme.tileAlternateColor
	if alternateColor then
		local gridX = tile:GetAttribute("GridX") or 0
		local gridZ = tile:GetAttribute("GridZ") or 0
		if (gridX + gridZ) % 2 == 1 then
			return alternateColor
		end
	end
	return theme.tileColor
end

local function applyTileBaseAppearance(tile, theme)
	local profile = theme.floorAppearanceProfile
	if profile then
		FloorAppearanceService.ApplySurface(tile, profile)
	else
		tile.Material = theme.tileMaterial
		tile.MaterialVariant = ""
		tile.Reflectance = 0
		setTileSurface(tile, theme, false)
	end

	-- Use the active map's palette even when its material comes from the lobby.
	tile.Color = getTileBaseColor(tile, theme)
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
	self.aircraftModel = nil
	self.aircraftBasePosition = Config.CONTROL_CENTER
	self.aircraftHoverTween = nil
	self.aircraftAnchor = nil
	self.aircraftBodyMotor = nil
	self.aircraftHomeC0 = nil
	self.aircraftAimTween = nil
	self.aircraftAimToken = 0
	self.mapDecorBuilt = false
	self.coreArenaReady = false
	self.laserOrigin = nil
	self.lobbyFloor = nil
	self.mapRootFolder = nil
	self.elementTransitionCount = 0
	return self
end

function ArenaService:_buildLobby()
	local center = Config.LOBBY_CENTER
	local size = Config.LOBBY_SIZE
	local platform = self.lobbyFolder:FindFirstChild("WaitingPlatform")
	if not platform or not platform:IsA("BasePart") then
		if platform then
			warn("Skyfall found an incompatible WaitingPlatform. Replacing only that floor object.")
			platform:Destroy()
		end
		platform = createPart(
			self.lobbyFolder,
			"WaitingPlatform",
			Vector3.new(size, 3, size),
			center,
			Color3.fromRGB(49, 139, 56),
			Enum.Material.Plastic,
			true
		)
		applyClassicStudSurface(platform)
		platform.CanQuery = false
	end
	self.lobbyFloor = platform
end

function ArenaService:_buildAircraft()
	local folder = self.aircraftFolder
	local previousAircraft = folder:FindFirstChild("SkyfallLaserAircraft")
	if previousAircraft then
		previousAircraft:Destroy()
	end
	local model = Instance.new("Model")
	model.Name = "SkyfallLaserAircraft"
	model:SetAttribute("SkyfallGenerated", true)
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
	orb.Reflectance = 0.12
	orb.CustomPhysicalProperties = PhysicalProperties.new(7.85, 0.32, 0.22, 1, 1)
	orb.CastShadow = false
	orb.Anchored = false
	model.PrimaryPart = orb

	-- One hidden anchor drives the complete aircraft assembly.
	local aircraftAnchor = createPart(
		model,
		"AircraftMotionAnchor",
		Vector3.new(0.2, 0.2, 0.2),
		base,
		Color3.new(0, 0, 0),
		Enum.Material.SmoothPlastic,
		false
	)
	aircraftAnchor.Transparency = 1
	aircraftAnchor.CanCollide = false
	aircraftAnchor.CanTouch = false
	aircraftAnchor.CanQuery = false
	aircraftAnchor.Anchored = true
	self.aircraftAnchor = aircraftAnchor

	local bodyMotor = Instance.new("Motor6D")
	bodyMotor.Name = "AircraftBodyJoint"
	bodyMotor.Part0 = aircraftAnchor
	bodyMotor.Part1 = orb
	bodyMotor.C0 = aircraftAnchor.CFrame:ToObjectSpace(orb.CFrame)
	bodyMotor.C1 = CFrame.identity
	bodyMotor.Parent = aircraftAnchor
	self.aircraftBodyMotor = bodyMotor
	self.aircraftHomeC0 = bodyMotor.C0

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

	local lensPosition = lensCenter + lensNormal * 0.95
	local laserOrigin = Instance.new("Attachment")
	laserOrigin.Name = "LaserOrigin"
	laserOrigin.Position = orb.CFrame:PointToObjectSpace(lensPosition + lensNormal * 0.62)
	laserOrigin.Parent = orb
	self.laserOrigin = laserOrigin

	local function lensDisc(name, thickness, diameter, position, color, material)
		local disc =
			createPart(model, name, Vector3.new(thickness, diameter, diameter), position, color, material, false)
		disc.Shape = Enum.PartType.Cylinder
		disc.CFrame = lensFrameAt(position)
		disc.CastShadow = false
		disc.CanQuery = false
		disc.CanTouch = false
		return disc
	end

	local outerCollar =
		lensDisc("ControllerLensOuterCollar", 0.72, 7.5, lensCenter, Color3.fromRGB(223, 174, 74), Enum.Material.Metal)
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
		local detail = createPart(model, name, size, position, color, Enum.Material.SmoothPlastic, false)
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
			local localOffset = Vector3.new(0.34, math.cos(angle) * radius, math.sin(angle) * radius)
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

	lensDetail("LensReticleHorizontal", Vector3.new(0.09, 2.7, 0.1), Vector3.new(0.34, 0, 0), reticleColor)
	lensDetail("LensReticleVertical", Vector3.new(0.09, 0.1, 2.7), Vector3.new(0.34, 0, 0), reticleColor)
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

	-- Every visible part is rigidly joined to the fuselage, including the lens assembly.
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") and descendant ~= orb and descendant ~= aircraftAnchor then
			descendant.Anchored = false
			descendant.Massless = true
			local weld = Instance.new("WeldConstraint")
			weld.Name = "AircraftUnifiedWeld"
			weld.Part0 = orb
			weld.Part1 = descendant
			weld.Parent = orb
		end
	end

	self.aircraftModel = model
	self.aircraftAimToken = 0
	local hoverGoal = aircraftAnchor.Position + Vector3.new(0, 0.42, 0)
	self.aircraftHoverTween = TweenService:Create(
		aircraftAnchor,
		TweenInfo.new(3.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Position = hoverGoal }
	)
	self.aircraftHoverTween:Play()
end

function ArenaService:AimAircraftAt(tile)
	local motor = self.aircraftBodyMotor
	local anchor = self.aircraftAnchor
	local body = self.aircraftModel and self.aircraftModel.PrimaryPart
	if not motor or not motor.Parent or not anchor or not body then
		return nil
	end

	self.aircraftAimToken += 1
	local aimToken = self.aircraftAimToken
	local targetC0 = self.aircraftHomeC0

	if tile and tile.Parent then
		local targetPosition = tile.Position + Vector3.new(0, 0.65, 0)
		local direction = targetPosition - body.Position
		if direction.Magnitude > 0.01 then
			direction = direction.Unit
			-- The optical axis is local -Y: lensFrameAt() uses lensNormal as its local X axis,
			-- and the laser attachment is placed along the same downward local axis.
			-- CFrame.fromMatrix() receives the body's local X, Y and Z axes in world space.
			local opticalUp = -direction
			local referenceBack = Vector3.zAxis
			local back = referenceBack - opticalUp * referenceBack:Dot(opticalUp)
			if back.Magnitude < 0.05 then
				referenceBack = Vector3.xAxis
				back = referenceBack - opticalUp * referenceBack:Dot(opticalUp)
			end
			back = back.Unit
			local right = opticalUp:Cross(back).Unit
			back = right:Cross(opticalUp).Unit
			local aimFrame = CFrame.fromMatrix(anchor.Position, right, opticalUp, back)
			targetC0 = anchor.CFrame:ToObjectSpace(aimFrame)
		end
	end

	if self.aircraftAimTween then
		self.aircraftAimTween:Cancel()
	end
	self.aircraftAimTween = TweenService:Create(
		motor,
		TweenInfo.new(tile and 0.42 or 0.38, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ C0 = targetC0 }
	)
	self.aircraftAimTween:Play()
	return aimToken
end

function ArenaService:ReturnAircraftLensHome(token)
	if token ~= self.aircraftAimToken then
		return false
	end
	self:AimAircraftAt(nil)
	return true
end

function ArenaService:_setLighting()
    LightingProfileService.Apply()

    local clouds = Workspace.Terrain:FindFirstChild("SkyfallClouds")
    if clouds then
        clouds:Destroy()
    end
end

function ArenaService:_buildMapDecoration(theme)
	if not theme.floorAppearanceProfile then
		error("Skyfall cannot build map decoration without the captured lobby surface profile")
	end

	local partCount = SkyGardenMapBuilder.Build(
		self.mapFolder,
		Config.ARENA_CENTER,
		Config.ARENA_HALF_WIDTH,
		theme.floorAppearanceProfile
	)

	self.mapFolder:SetAttribute("SkyfallActiveMapId", theme.id)
	self.mapFolder:SetAttribute("SkyfallGeometryPartCount", partCount)
	return partCount
end

function ArenaService:Build()
	for _, descendant in ipairs(self.root:GetDescendants()) do
		if
			descendant.Name == "BlueLaserImpact"
			or descendant.Name == "ImpactShockwave"
			or descendant.Name == "BlueLaserHalo"
			or descendant.Name == "BlueLaserOuter"
			or descendant.Name == "BlueLaserCore"
			or string.sub(descendant.Name, 1, 13) == "LaserVFXShot_"
		then
			descendant:Destroy()
		end
	end

	-- Keep hand-authored environment content in the parent folders. Only the
	-- generated decoration subfolder is refreshed by this service.
	self.lobbyFolder = getOrCreateFolder(self.decorFolder, "Lobby")
	self.mapRootFolder = getOrCreateFolder(self.decorFolder, "ActiveMap")
	self.mapFolder = getOrCreateFolder(self.mapRootFolder, "GeneratedDecor")
	self.aircraftFolder = getOrCreateFolder(self.decorFolder, "Aircraft")

	for _, child in ipairs(self.mapFolder:GetChildren()) do
		child:Destroy()
	end

	self.tiles = {}
	self.mapDecorBuilt = false
	self.elementTransitionCount = 0

	local halfGrid = (Config.GRID_SIZE - 1) / 2
	local spacing = Config.TILE_SIZE + Config.TILE_GAP

	for gridX = 1, Config.GRID_SIZE do
		for gridZ = 1, Config.GRID_SIZE do
			local offsetX = (gridX - 1 - halfGrid) * spacing
			local offsetZ = (gridZ - 1 - halfGrid) * spacing
			local position = Config.ARENA_CENTER + Vector3.new(offsetX, 0, offsetZ)
			local tileName = "Tile_" .. tostring(gridX) .. "_" .. tostring(gridZ)
			local tile = self.tilesFolder:FindFirstChild(tileName)

			if not tile or not tile:IsA("BasePart") then
				if tile then
					warn("Skyfall found an incompatible tile object: " .. tile:GetFullName())
				end
				tile = createPart(
					self.tilesFolder,
					tileName,
					Vector3.new(Config.TILE_SIZE, 1, Config.TILE_SIZE),
					position,
					MAPS[1].tileColor,
					MAPS[1].tileMaterial
				)
			end

			tile:SetAttribute("SkyfallGenerated", true)
			tile:SetAttribute("SkyfallGeneratedTile", true)
			tile:SetAttribute("GridX", gridX)
			tile:SetAttribute("GridZ", gridZ)
			tile:SetAttribute("IsBroken", false)
			tile:SetAttribute("IsWarning", false)
			tile:SetAttribute("StrikeToken", tile:GetAttribute("StrikeToken") or 0)
			applyClassicStudSurface(tile)
			tile.CanCollide = true
			tile.CanTouch = false
			self.tiles[tileKey(gridX, gridZ)] = tile
		end
	end

	self:_buildLobby()
	self:_buildAircraft()

	local tileCount = 0
	for _ in pairs(self.tiles) do
		tileCount += 1
	end
	self.coreArenaReady = self.lobbyFloor ~= nil
		and self.lobbyFloor.Parent == self.lobbyFolder
		and tileCount == Config.GRID_SIZE * Config.GRID_SIZE
	self.root:SetAttribute("SkyfallCoreArenaReady", self.coreArenaReady)
	self.root:SetAttribute("SkyfallArenaReady", false)
	if not self.coreArenaReady then
		error(string.format(
			"Skyfall core arena build failed: lobbyReady=%s, tiles=%d/%d",
			tostring(self.lobbyFloor ~= nil and self.lobbyFloor.Parent == self.lobbyFolder),
			tileCount,
			Config.GRID_SIZE * Config.GRID_SIZE
		))
	end
	print(string.format("[SkyfallArenaBuild] CORE_READY tiles=%d lobby=%s", tileCount, self.lobbyFloor:GetFullName()))
	self:SetMap(1)
end

local function runOptionalArenaStage(stageName: string, callback: () -> any): (boolean, any)
	local success, result = xpcall(callback, debug.traceback)
	if success then
		print("[SkyfallArenaBuild] OPTIONAL_STAGE_READY " .. stageName)
	else
		warn("[SkyfallArenaBuild] OPTIONAL_STAGE_FAILED " .. stageName .. ": " .. tostring(result))
	end
	return success, result
end

function ArenaService:IsGameplayReady(): boolean
	return self.coreArenaReady == true
		and self.root ~= nil
		and self.root:GetAttribute("SkyfallArenaReady") == true
end

function ArenaService:SetMap(mapId: number): string
	local selected = MAPS[mapId] or MAPS[1]
	local theme = table.clone(selected)
	local lobbyFloor = self.lobbyFloor
	if not lobbyFloor or not lobbyFloor.Parent then
		local candidate = self.lobbyFolder and self.lobbyFolder:FindFirstChild("WaitingPlatform")
		lobbyFloor = candidate and candidate:IsA("BasePart") and candidate or nil
	end

	local profile = FloorAppearanceService.Capture(lobbyFloor)
	if not profile then
		error("Skyfall requires a valid Lobby.WaitingPlatform before selecting a playable map")
	end

	-- The lobby and destructible tile grid are core gameplay. Decoration,
	-- element overlays, audits, and lighting are optional visual enhancements.
	theme.floorAppearanceProfile = profile
	theme.tileMaterial = profile.Material
	self.currentMapId = selected.id
	self.theme = theme

	for _, tile in pairs(self.tiles) do
		local token = (tile:GetAttribute("StrikeToken") or 0) + 1
		tile:SetAttribute("StrikeToken", token)
		tile:SetAttribute("IsBroken", false)
		tile:SetAttribute("IsWarning", false)
		applyTileBaseAppearance(tile, theme)
		tile.CanCollide = true
		tile.Transparency = 0
		local warningLight = tile:FindFirstChild("TargetWarningLight")
		if warningLight then
			warningLight:Destroy()
		end
	end

	self.mapFolder:ClearAllChildren()
	self.mapFolder:SetAttribute("SkyfallMapBuildStatus", "Building")
	self.mapDecorBuilt = false
	self.elementTransitionCount = 0

	local mapSuccess, partCountOrError = runOptionalArenaStage("MapGeometry", function()
		return self:_buildMapDecoration(theme)
	end)
	local partCount = 0
	if mapSuccess then
		partCount = partCountOrError
		self.mapDecorBuilt = true
	else
		-- Discard partial map visuals, but keep the lobby and every collision tile.
		self.mapFolder:ClearAllChildren()
	end

	local elementSuccess, elementCountOrError = false, 0
	if mapSuccess then
		elementSuccess, elementCountOrError = runOptionalArenaStage("ElementTransitions", function()
			return ElementIntegrationService.Build(self.mapFolder, lobbyFloor, theme.tileColor)
		end)
	end
	if elementSuccess then
		self.elementTransitionCount = elementCountOrError
	else
		local transitionFolder = self.mapFolder:FindFirstChild("ElementTransitions")
		if transitionFolder then
			transitionFolder:Destroy()
		end
	end

	local mapAuditSuccess, auditedMapParts = runOptionalArenaStage("MapSurfaceAudit", function()
		return FloorAppearanceService.Audit(self.mapFolder, profile)
	end)
	local tileAuditSuccess, auditedTiles = runOptionalArenaStage("TileSurfaceAudit", function()
		return FloorAppearanceService.Audit(self.tilesFolder, profile)
	end)
	if tileAuditSuccess and auditedTiles ~= Config.GRID_SIZE * Config.GRID_SIZE then
		tileAuditSuccess = false
		warn(string.format(
			"[SkyfallArenaBuild] TILE_AUDIT_COUNT_MISMATCH actual=%d expected=%d",
			auditedTiles,
			Config.GRID_SIZE * Config.GRID_SIZE
		))
	end

	self.mapFolder:SetAttribute("SkyfallGeometryPartCount", partCount)
	self.mapFolder:SetAttribute("SkyfallAuditedSurfaceCount", mapAuditSuccess and auditedMapParts or 0)
	self.mapFolder:SetAttribute("SkyfallMapBuildStatus", mapSuccess and "Ready" or "Fallback")
	self.mapFolder:SetAttribute("SkyfallElementIntegrationStatus", elementSuccess and "Ready" or "Skipped")
	self.tilesFolder:SetAttribute("SkyfallAuditedSurfaceCount", tileAuditSuccess and auditedTiles or 0)

	local lightingSuccess = runOptionalArenaStage("LightingProfile", function()
		return self:_setLighting()
	end)
	self.root:SetAttribute("SkyfallLightingStatus", lightingSuccess and "Ready" or "Fallback")

	local readiness = ArenaStartupPolicy.Resolve(self.coreArenaReady, mapSuccess)
	self.root:SetAttribute("SkyfallArenaReady", readiness.GameplayReady)
	self.root:SetAttribute("SkyfallMapDecorationStatus", readiness.DecorationStatus)
	self.root:SetAttribute("SkyfallArenaMapId", selected.id)
	self.root:SetAttribute("SkyfallSurfaceAuditStatus", mapAuditSuccess and tileAuditSuccess and "Ready" or "Warning")

	if readiness.GameplayReady then
		print(string.format(
			"[SkyfallArenaBuild] ARENA_READY map=%s decoration=%s elements=%s lighting=%s",
			theme.name,
			readiness.DecorationStatus,
			elementSuccess and "Ready" or "Skipped",
			lightingSuccess and "Ready" or "Fallback"
		))
	else
		warn("[SkyfallArenaBuild] CORE_NOT_READY")
	end

	return theme.name
end
function ArenaService:GetMapName()
	return self.theme.name
end

function ArenaService:GetTile(gridX, gridZ)
	return self.tiles[tileKey(gridX, gridZ)]
end

function ArenaService:GetStreamingFocusPart()
	local centerIndex = math.floor((Config.GRID_SIZE + 1) / 2)
	return self:GetTile(centerIndex, centerIndex)
end

function ArenaService:GetSafeTiles()
	local safeTiles = {}
	for _, tile in pairs(self.tiles) do
		if
			tile.Parent == self.tilesFolder
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
	tile.MaterialVariant = ""
	tile.Reflectance = 0

	-- The projected sigil adds a readable, short-lived target lock without changing collision.
	MagicCircleVFX.Create(tile, token)
	return token
end

function ArenaService:IsStrikeCurrent(tile, token)
	return tile and tile.Parent == self.tilesFolder and tile:GetAttribute("StrikeToken") == token
end

function ArenaService:ClearWarning(tile, token)
	if not self:IsStrikeCurrent(tile, token) then
		return
	end
	tile:SetAttribute("IsWarning", false)
	MagicCircleVFX.Destroy(tile)
	local warningLight = tile:FindFirstChild("TargetWarningLight")
	if warningLight then
		warningLight:Destroy()
	end
	applyTileBaseAppearance(tile, self.theme)
end

function ArenaService:CreateStrikeBeam(tile)
	return LaserVFX.Create(self, tile)
end

function ArenaService:BreakTile(tile, token)
	if not self:IsStrikeCurrent(tile, token) then
		return
	end

	tile:SetAttribute("IsWarning", false)
	MagicCircleVFX.Destroy(tile)
	local warningLight = tile:FindFirstChild("TargetWarningLight")
	if warningLight then
		warningLight:Destroy()
	end
	tile:SetAttribute("IsBroken", true)
	tile.Color = self.theme.brokenColor
	tile.Material = Enum.Material.Slate
	tile.MaterialVariant = ""
	tile.Reflectance = 0
	tile.CanCollide = false
	tile.Transparency = 0.84
	setTileSurface(tile, self.theme, true)
end

function ArenaService:ResetTiles()
	-- Cancel in-flight visual shots so delayed callbacks cannot leave effects on a clean round.
	for _, child in ipairs(self.root:GetChildren()) do
		if string.sub(child.Name, 1, 13) == "LaserVFXShot_" then
			child:Destroy()
		end
	end

	local aircraft = self.aircraftFolder and self.aircraftFolder:FindFirstChild("SkyfallLaserAircraft")
	local muzzleAttachment = aircraft and aircraft:FindFirstChild("LaserMuzzleAttachment", true)
	if muzzleAttachment then
		muzzleAttachment:Destroy()
	end

	for _, tile in pairs(self.tiles) do
		MagicCircleVFX.Destroy(tile)
		for _, child in ipairs(tile:GetChildren()) do
			if
				child.Name == "LaserImpactAttachment"
				or child.Name == "LaserImpactSound"
				or child.Name == "TargetWarningLight"
			then
				child:Destroy()
			end
		end

		local token = (tile:GetAttribute("StrikeToken") or 0) + 1
		tile:SetAttribute("StrikeToken", token)
		tile:SetAttribute("IsWarning", false)
		tile:SetAttribute("IsBroken", false)
		applyTileBaseAppearance(tile, self.theme)
		tile.CanCollide = true
		tile.Transparency = 0
	end
end

function ArenaService:GetLobbySpawnCFrame(index, total, isBot)
	local spawnIndex = math.max(1, index or 1)
	local spawnTotal = math.max(1, total or 1)
	local angle = ((spawnIndex - 1) / spawnTotal) * math.pi * 2
	local radius = isBot and Config.LOBBY_BOT_SPAWN_RADIUS or Config.LOBBY_SPAWN_RADIUS
	local position = Config.LOBBY_CENTER + Vector3.new(math.cos(angle) * radius, 5, math.sin(angle) * radius)
	local horizontalViewTarget = Vector3.new(Config.ARENA_CENTER.X, position.Y, Config.ARENA_CENTER.Z)
	return CFrame.lookAt(position, horizontalViewTarget)
end

function ArenaService:GetRunnerSpawnCFrame(index, total)
	local angle = ((index - 1) / math.max(total, 1)) * math.pi * 2
	local radius = Config.RUNNER_SPAWN_RADIUS
	local position = Config.ARENA_CENTER + Vector3.new(math.cos(angle) * radius, 6, math.sin(angle) * radius)
	return CFrame.new(position)
end

function ArenaService:GetControllerSpawnCFrame()
	return CFrame.new(Config.CONTROLLER_HIDDEN_POSITION)
end

return ArenaService
