local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")
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
	part.CanTouch = false
	part.CastShadow = false
	part.Parent = parent
	return part
end

local function createFolder(parent, name)
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	return folder
end

-- Native Roblox retro surfaces render studs without thousands of child Parts.
-- SurfaceType is deprecated for automatic joining, but its Studs/Inlet visuals remain.
local function applyClassicStudSurface(basePart)
	basePart.TopSurface = Enum.SurfaceType.Studs
	basePart.BottomSurface = Enum.SurfaceType.Inlet
end

local function setTileStudState(tile, hidden)
	tile.TopSurface = hidden and Enum.SurfaceType.Smooth or Enum.SurfaceType.Studs
	tile.BottomSurface = hidden and Enum.SurfaceType.Smooth or Enum.SurfaceType.Inlet
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
	self.laserOrigin = nil
	return self
end

function ArenaService:_buildLobby()
	local center = Config.LOBBY_CENTER
	local size = Config.LOBBY_SIZE
	local platform = createPart(
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

	-- Every visible part is rigidly joined to the fuselage, including the lens assembly.
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart")
			and descendant ~= orb
			and descendant ~= aircraftAnchor
		then
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
		{Position = hoverGoal}
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
			-- The lens optical axis is local +X (the right vector of lensFrameAt).
			-- Aim that same axis toward the selected tile so the body and emitter agree.
			local right = direction
			local referenceUp = Vector3.new(0, 0, -1)
			local up = referenceUp - right * referenceUp:Dot(right)
			if up.Magnitude < 0.05 then
				referenceUp = Vector3.yAxis
				up = referenceUp - right * referenceUp:Dot(right)
			end
			up = up.Unit
			local back = right:Cross(up).Unit
			local aimFrame = CFrame.fromMatrix(anchor.Position, right, up, back)
			targetC0 = anchor.CFrame:ToObjectSpace(aimFrame)
		end
	end

	if self.aircraftAimTween then
		self.aircraftAimTween:Cancel()
	end
	self.aircraftAimTween = TweenService:Create(
		motor,
		TweenInfo.new(tile and 0.42 or 0.38, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{C0 = targetC0}
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

function ArenaService:_setLighting(_theme)
	-- Return to neutral Roblox daytime lighting without custom sky or post-processing.
	Lighting.Brightness = 2
	Lighting.ClockTime = 14
	Lighting.Ambient = Color3.fromRGB(0, 0, 0)
	Lighting.OutdoorAmbient = Color3.fromRGB(0, 0, 0)
	Lighting.ExposureCompensation = 0
	Lighting.EnvironmentDiffuseScale = 1
	Lighting.EnvironmentSpecularScale = 1
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

	-- A thin visual foundation cannot catch a runner who falls through the arena.
	local support = createPart(
		folder,
		"ClassicArenaSupport",
		Vector3.new(width + 26, 2, width + 26),
		center + Vector3.new(0, -60, 0),
		Color3.fromRGB(82, 68, 52),
		Enum.Material.Plastic,
		false
	)
	support.CanCollide = false
	support.CanTouch = false
	support.CanQuery = false

	-- The trim touches the tile grid underside but remains non-collidable.
	local trim = createPart(
		folder,
		"ClassicArenaOuterTrim",
		Vector3.new(width + 6, 1, width + 6),
		center + Vector3.new(0, -1, 0),
		Color3.fromRGB(49, 103, 54),
		Enum.Material.Plastic,
		false
	)
	trim.CanQuery = false

	-- Edge beams overlap at all corners and meet the outer tile edges.
	local frameY = center.Y + 0.65
	for _, side in ipairs({-1, 1}) do
		local northSouth = createPart(
			folder,
			"ClassicPerimeterNorthSouth_" .. tostring(side),
			Vector3.new(width + 4, 2.3, 3),
			Vector3.new(center.X, frameY, center.Z + side * (half + 1)),
			theme.tileColor:Lerp(Color3.fromRGB(30, 80, 40), 0.45),
			Enum.Material.Plastic,
			false
		)
		applyClassicStudSurface(northSouth)
		northSouth.CanQuery = false

		local eastWest = createPart(
			folder,
			"ClassicPerimeterEastWest_" .. tostring(side),
			Vector3.new(3, 2.3, width + 4),
			Vector3.new(center.X + side * (half + 1), frameY, center.Z),
			theme.tileColor:Lerp(Color3.fromRGB(30, 80, 40), 0.45),
			Enum.Material.Plastic,
			false
		)
		applyClassicStudSurface(eastWest)
		eastWest.CanQuery = false
	end

	-- Corner supports overlap both edge beams, making one connected perimeter frame.
	for sideX = -1, 1, 2 do
		for sideZ = -1, 1, 2 do
			local post = createPart(
				folder,
				"ClassicPerimeterCornerPost_" .. tostring(sideX) .. "_" .. tostring(sideZ),
				Vector3.new(4, 9, 4),
				center + Vector3.new(
					sideX * (half + 1),
					4.5,
					sideZ * (half + 1)
				),
				Color3.fromRGB(60, 112, 61),
				Enum.Material.Plastic,
				false
			)
			applyClassicStudSurface(post)
			post.CanQuery = false
		end
	end
end

function ArenaService:Build()
	for _, descendant in ipairs(self.root:GetDescendants()) do
		if descendant.Name == "BlueLaserImpact"
			or descendant.Name == "ImpactShockwave"
			or descendant.Name == "BlueLaserHalo"
			or descendant.Name == "BlueLaserOuter"
			or descendant.Name == "BlueLaserCore"
		then
			descendant:Destroy()
		end
	end

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
			applyClassicStudSurface(tile)
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
		setTileStudState(tile, false)
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

	-- The red tile itself communicates the warning without a per-tile dynamic light.
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
	tile.Material = self.theme.tileMaterial
end

function ArenaService:CreateStrikeBeam(tile)
	if not self.laserOrigin or not self.laserOrigin.Parent or not tile or not tile.Parent then
		return
	end

	local target = Instance.new("Attachment")
	target.Name = "LaserImpactAttachment"
	target.Position = Vector3.new(0, 0.65, 0)
	target.Parent = tile

	local function createLaserPass(name, width0, width1, color, transparency, emission)
		local beam = Instance.new("Beam")
		beam.Name = name
		beam.Attachment0 = self.laserOrigin
		beam.Attachment1 = target
		beam.FaceCamera = true
		beam.Width0 = width0
		beam.Width1 = width1
		beam.Segments = 10
		beam.LightEmission = emission
		beam.LightInfluence = 0
		beam.Color = color
		beam.Transparency = transparency
		beam.Parent = self.root
		Debris:AddItem(beam, 0.52)
		return beam
	end

	-- Four layered passes create a bright core with a soft energy envelope.
	createLaserPass(
		"LaserAtmosphereGlow",
		4.8,
		3.4,
		ColorSequence.new(Color3.fromRGB(31, 115, 255), Color3.fromRGB(76, 209, 255)),
		NumberSequence.new(0.82),
		0.72
	)
	createLaserPass(
		"LaserEnergyShell",
		1.9,
		1.25,
		ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(44, 139, 255)),
			ColorSequenceKeypoint.new(0.55, Color3.fromRGB(71, 198, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(142, 235, 255)),
		}),
		NumberSequence.new(0.24),
		0.94
	)
	createLaserPass(
		"LaserHotCore",
		0.62,
		0.4,
		ColorSequence.new(Color3.fromRGB(221, 248, 255), Color3.fromRGB(255, 255, 255)),
		NumberSequence.new(0.035),
		1
	)
	createLaserPass(
		"LaserFilament",
		0.12,
		0.08,
		ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(187, 238, 255)),
		NumberSequence.new(0.08),
		1
	)

	local impactLight = Instance.new("PointLight")
	impactLight.Name = "LaserImpactFlash"
	impactLight.Color = Color3.fromRGB(121, 216, 255)
	impactLight.Brightness = 3
	impactLight.Range = 14
	impactLight.Shadows = false
	impactLight.Parent = target
	TweenService:Create(
		impactLight,
		TweenInfo.new(0.24, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{Brightness = 0}
	):Play()

	local impactParticles = Instance.new("ParticleEmitter")
	impactParticles.Name = "LaserImpactParticles"
	impactParticles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	impactParticles.Rate = 0
	impactParticles.Lifetime = NumberRange.new(0.16, 0.38)
	impactParticles.Speed = NumberRange.new(13, 22)
	impactParticles.Drag = 6
	impactParticles.SpreadAngle = Vector2.new(180, 180)
	impactParticles.Rotation = NumberRange.new(0, 360)
	impactParticles.RotSpeed = NumberRange.new(-135, 135)
	impactParticles.LightEmission = 0.9
	impactParticles.LightInfluence = 0
	impactParticles.Color = ColorSequence.new(
		Color3.fromRGB(154, 227, 255),
		Color3.fromRGB(255, 255, 255)
	)
	impactParticles.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.42),
		NumberSequenceKeypoint.new(0.3, 0.22),
		NumberSequenceKeypoint.new(1, 0),
	})
	impactParticles.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.02),
		NumberSequenceKeypoint.new(1, 1),
	})
	impactParticles.Parent = target
	impactParticles:Emit(22)

	local impactSound = Instance.new("Sound")
	impactSound.Name = "LaserImpactSound"
	impactSound.SoundId = "rbxassetid://" .. Config.LASER_SOUND_ID
	impactSound.Volume = Config.AUDIO_LASER_VOLUME
	impactSound.RollOffMode = Enum.RollOffMode.Linear
	impactSound.RollOffMinDistance = 10
	impactSound.RollOffMaxDistance = 180
	impactSound.EmitterSize = 8
	impactSound.Parent = tile
	impactSound:Play()

	-- No persistent cylinder or expanding ring is spawned at the impact point.
	Debris:AddItem(target, 0.9)
	Debris:AddItem(impactSound, 3)
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
		setTileStudState(tile, false)
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
