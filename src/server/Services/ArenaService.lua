local Workspace = game:GetService("Workspace")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))

local ArenaService = {}
ArenaService.__index = ArenaService

local TILE_COLOR = Color3.fromRGB(35, 58, 83)
local TILE_WARNING_COLOR = Color3.fromRGB(255, 116, 48)
local TILE_BROKEN_COLOR = Color3.fromRGB(91, 29, 42)
local ACCENT_CYAN = Color3.fromRGB(54, 220, 245)
local ACCENT_BLUE = Color3.fromRGB(68, 116, 204)
local ACCENT_PURPLE = Color3.fromRGB(145, 92, 255)

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

local function addNeonBorder(parent, name, size, position, color)
	local border = createPart(
		parent,
		name,
		size,
		position,
		color,
		Enum.Material.Neon,
		false
	)
	border.Transparency = 0.12
	border.CanTouch = false
	border.CanQuery = false
	return border
end

local function addSign(parent, name, position, size, title, subtitle)
	local board = createPart(
		parent,
		name,
		size,
		position,
		Color3.fromRGB(13, 24, 43),
		Enum.Material.Metal,
		false
	)
	board.CanQuery = false

	local gui = Instance.new("SurfaceGui")
	gui.Name = "SignSurface"
	gui.Face = Enum.NormalId.Front
	gui.LightInfluence = 0
	gui.Parent = board

	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Color3.fromRGB(13, 24, 43)
	frame.BackgroundTransparency = 0.1
	frame.BorderSizePixel = 0
	frame.Parent = gui

	local heading = Instance.new("TextLabel")
	heading.Name = "Heading"
	heading.Size = UDim2.new(1, -12, 0.56, 0)
	heading.Position = UDim2.fromOffset(6, 2)
	heading.BackgroundTransparency = 1
	heading.Font = Enum.Font.GothamBlack
	heading.Text = title
	heading.TextColor3 = Color3.fromRGB(231, 244, 255)
	heading.TextScaled = true
	heading.Parent = frame

	local detail = Instance.new("TextLabel")
	detail.Name = "Subtitle"
	detail.Size = UDim2.new(1, -16, 0.34, 0)
	detail.Position = UDim2.new(0, 8, 0.6, 0)
	detail.BackgroundTransparency = 1
	detail.Font = Enum.Font.GothamMedium
	detail.Text = subtitle
	detail.TextColor3 = ACCENT_CYAN
	detail.TextScaled = true
	detail.Parent = frame

	local outline = Instance.new("UIStroke")
	outline.Color = ACCENT_CYAN
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
		self.tilesFolder = Instance.new("Folder")
		self.tilesFolder.Name = "Tiles"
		self.tilesFolder.Parent = self.root
	end

	self.decorFolder = self.root:FindFirstChild("Environment")
	if not self.decorFolder then
		self.decorFolder = Instance.new("Folder")
		self.decorFolder.Name = "Environment"
		self.decorFolder.Parent = self.root
	end

	self.tiles = {}
	return self
end

function ArenaService:_buildLobby()
	local decor = self.decorFolder
	local center = Config.LOBBY_CENTER
	local size = Config.LOBBY_SIZE
	local half = size / 2

	local platform = createPart(
		decor,
		"LobbyPlatform",
		Vector3.new(size, 3, size),
		center,
		Color3.fromRGB(28, 47, 68),
		Enum.Material.DiamondPlate
	)
	platform.CanQuery = false

	local trimY = center.Y + 1.65
	addNeonBorder(decor, "LobbyTrimNorth", center + Vector3.new(0, trimY - center.Y, -half), Vector3.new(size, 0.45, 1.2), 0, 0, ACCENT_CYAN)
	addNeonBorder(decor, "LobbyTrimSouth", center + Vector3.new(0, trimY - center.Y, half), Vector3.new(size, 0.45, 1.2), 0, 0, ACCENT_CYAN)
	addNeonBorder(decor, "LobbyTrimEast", center + Vector3.new(half, trimY - center.Y, 0), Vector3.new(1.2, 0.45, size), 0, 0, ACCENT_BLUE)
	addNeonBorder(decor, "LobbyTrimWest", center + Vector3.new(-half, trimY - center.Y, 0), Vector3.new(1.2, 0.45, size), 0, 0, ACCENT_BLUE)

	for xSign = -1, 1, 2 do
		for zSign = -1, 1, 2 do
			local pillarPosition = center + Vector3.new(xSign * (half - 5), 13, zSign * (half - 5))
			local pillar = createPart(
				decor,
				"LobbyPillar_" .. tostring(xSign) .. "_" .. tostring(zSign),
				Vector3.new(3, 25, 3),
				pillarPosition,
				Color3.fromRGB(39, 66, 99),
				Enum.Material.Metal
			)
			pillar.CanQuery = false

			local cap = createPart(
				decor,
				"LobbyPillarCap_" .. tostring(xSign) .. "_" .. tostring(zSign),
				Vector3.new(4.5, 1.2, 4.5),
				pillarPosition + Vector3.new(0, 13, 0),
				ACCENT_CYAN,
				Enum.Material.Neon,
				false
			)
			cap.CanTouch = false
			cap.CanQuery = false
		end
	end

	for index = 1, 8 do
		local angle = ((index - 1) / 8) * math.pi * 2
		local offset = Vector3.new(math.cos(angle) * 25, 1.85, math.sin(angle) * 25)
		local pad = createPart(
			decor,
			"LobbySpawnPad_" .. tostring(index),
			Vector3.new(1, 9, 9),
			center + offset,
			index % 2 == 0 and ACCENT_BLUE or ACCENT_CYAN,
			Enum.Material.Neon,
			false
		)
		pad.Shape = Enum.PartType.Cylinder
		pad.CFrame = CFrame.new(center + offset) * CFrame.Angles(0, 0, math.rad(90))
		pad.Transparency = 0.22
		pad.CanTouch = false
		pad.CanQuery = false
	end

	local centerRing = createPart(
		decor,
		"LobbyCenterRing",
		Vector3.new(1, 27, 27),
		center + Vector3.new(0, 1.9, 0),
		ACCENT_PURPLE,
		Enum.Material.Neon,
		false
	)
	centerRing.Shape = Enum.PartType.Cylinder
	centerRing.CFrame = CFrame.new(center + Vector3.new(0, 1.9, 0)) * CFrame.Angles(0, 0, math.rad(90))
	centerRing.Transparency = 0.62
	centerRing.CanTouch = false
	centerRing.CanQuery = false

	local beacon = createPart(
		decor,
		"LobbyBeacon",
		Vector3.new(3, 12, 3),
		center + Vector3.new(0, 8, 0),
		ACCENT_CYAN,
		Enum.Material.Neon,
		false
	)
	beacon.CanTouch = false
	beacon.CanQuery = false

	local light = Instance.new("PointLight")
	light.Color = ACCENT_CYAN
	light.Brightness = 2
	light.Range = 32
	light.Parent = beacon

	addSign(
		decor,
		"LobbyWelcomeSign",
		center + Vector3.new(0, 17, -half + 3),
		Vector3.new(38, 12, 2),
		"SKYFALL ARENA",
		"STAY MOVING  •  LAST SURVIVOR WINS"
	)
end

function ArenaService:_buildArenaFrame()
	local decor = self.decorFolder
	local half = ((Config.GRID_SIZE - 1) * (Config.TILE_SIZE + Config.TILE_GAP)) / 2
	local edge = half + 8
	local y = Config.ARENA_CENTER.Y - 0.1

	addNeonBorder(
		decor,
		"ArenaBorderNorth",
		Config.ARENA_CENTER + Vector3.new(0, y - Config.ARENA_CENTER.Y, -edge),
		Vector3.new(edge * 2, 0.8, 1.1),
		0,
		0,
		ACCENT_CYAN
	)
	addNeonBorder(
		decor,
		"ArenaBorderSouth",
		Config.ARENA_CENTER + Vector3.new(0, y - Config.ARENA_CENTER.Y, edge),
		Vector3.new(edge * 2, 0.8, 1.1),
		0,
		0,
		ACCENT_CYAN
	)
	addNeonBorder(
		decor,
		"ArenaBorderEast",
		Config.ARENA_CENTER + Vector3.new(edge, y - Config.ARENA_CENTER.Y, 0),
		Vector3.new(1.1, 0.8, edge * 2),
		0,
		0,
		ACCENT_BLUE
	)
	addNeonBorder(
		decor,
		"ArenaBorderWest",
		Config.ARENA_CENTER + Vector3.new(-edge, y - Config.ARENA_CENTER.Y, 0),
		Vector3.new(1.1, 0.8, edge * 2),
		0,
		0,
		ACCENT_BLUE
	)

	for xSign = -1, 1, 2 do
		for zSign = -1, 1, 2 do
			local position = Config.ARENA_CENTER + Vector3.new(xSign * (edge + 2), 16, zSign * (edge + 2))
			local pylon = createPart(
				decor,
				"ArenaPylon_" .. tostring(xSign) .. "_" .. tostring(zSign),
				Vector3.new(3, 32, 3),
				position,
				Color3.fromRGB(31, 50, 82),
				Enum.Material.Metal,
				false
			)
			pylon.CanQuery = false

			local lamp = createPart(
				decor,
				"ArenaPylonLight_" .. tostring(xSign) .. "_" .. tostring(zSign),
				Vector3.new(4, 1.5, 4),
				position + Vector3.new(0, 17, 0),
				ACCENT_BLUE,
				Enum.Material.Neon,
				false
			)
			lamp.CanTouch = false
			lamp.CanQuery = false
		end
	end

	local towerBase = createPart(
		decor,
		"LaserTowerBase",
		Vector3.new(16, 3, 16),
		Config.CONTROL_CENTER + Vector3.new(0, -11, 0),
		Color3.fromRGB(31, 45, 73),
		Enum.Material.Metal,
		false
	)
	towerBase.CanTouch = false
	towerBase.CanQuery = false

	local shell = createPart(
		decor,
		"DroneShell",
		Vector3.new(13, 8, 13),
		Config.CONTROL_CENTER + Vector3.new(0, -3, 0),
		Color3.fromRGB(38, 54, 86),
		Enum.Material.Metal,
		false
	)
	shell.Shape = Enum.PartType.Ball
	shell.CanTouch = false
	shell.CanQuery = false

	local core = createPart(
		decor,
		"DroneCore",
		Vector3.new(6, 6, 6),
		Config.CONTROL_CENTER + Vector3.new(0, -7, 0),
		Color3.fromRGB(255, 67, 83),
		Enum.Material.Neon,
		false
	)
	core.Shape = Enum.PartType.Ball
	core.CanTouch = false
	core.CanQuery = false

	local coreLight = Instance.new("PointLight")
	coreLight.Color = Color3.fromRGB(255, 58, 84)
	coreLight.Brightness = 3
	coreLight.Range = 55
	coreLight.Parent = core

	for index = 1, 4 do
		local angle = (index - 1) * math.pi / 2
		local armPosition = Config.CONTROL_CENTER
			+ Vector3.new(math.cos(angle) * 12, -4, math.sin(angle) * 12)
		local arm = createPart(
			decor,
			"DroneArm_" .. tostring(index),
			Vector3.new(9, 1.8, 3),
			armPosition,
			ACCENT_CYAN,
			Enum.Material.Neon,
			false
		)
		arm.CFrame = CFrame.new(armPosition) * CFrame.Angles(0, -angle, 0)
		arm.CanTouch = false
		arm.CanQuery = false
	end
end

function ArenaService:Build()
	for _, child in ipairs(self.tilesFolder:GetChildren()) do
		child:Destroy()
	end
	for _, child in ipairs(self.decorFolder:GetChildren()) do
		child:Destroy()
	end

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
				TILE_COLOR,
				Enum.Material.Metal
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
	self:_buildArenaFrame()
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
	if not tile or tile:GetAttribute("IsBroken") or tile:GetAttribute("IsWarning") then
		return nil
	end

	local token = (tile:GetAttribute("StrikeToken") or 0) + 1
	tile:SetAttribute("StrikeToken", token)
	tile:SetAttribute("IsWarning", true)
	tile.Color = TILE_WARNING_COLOR
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

	if tile:GetAttribute("IsWarning") then
		tile:SetAttribute("IsWarning", false)
		tile.Color = TILE_COLOR
		tile.Material = Enum.Material.Metal
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
		Color3.fromRGB(255, 82, 68),
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
	tile.Color = TILE_BROKEN_COLOR
	tile.Material = Enum.Material.Slate
	tile.CanCollide = false
	tile.Transparency = 0.78
end

function ArenaService:RepairTile(tile, token)
	if not self:IsStrikeCurrent(tile, token) then
		return
	end

	tile:SetAttribute("IsWarning", false)
	tile:SetAttribute("IsBroken", false)
	tile.Color = TILE_COLOR
	tile.Material = Enum.Material.Metal
	tile.CanCollide = true
	tile.Transparency = 0
end

function ArenaService:ResetTiles()
	for _, tile in pairs(self.tiles) do
		local token = (tile:GetAttribute("StrikeToken") or 0) + 1
		tile:SetAttribute("StrikeToken", token)
		tile:SetAttribute("IsWarning", false)
		tile:SetAttribute("IsBroken", false)
		tile.Color = TILE_COLOR
		tile.Material = Enum.Material.Metal
		tile.CanCollide = true
		tile.Transparency = 0
	end
end

function ArenaService:GetLobbySpawnCFrame(index, total)
	local spawnIndex = math.max(1, index or 1)
	local spawnTotal = math.max(1, total or 1)
	local angle = ((spawnIndex - 1) / spawnTotal) * math.pi * 2
	local radius = math.min(25, 10 + spawnTotal * 1.4)
	local position = Config.LOBBY_CENTER + Vector3.new(
		math.cos(angle) * radius,
		5,
		math.sin(angle) * radius
	)
	return CFrame.new(position)
end

function ArenaService:GetRunnerSpawnCFrame(index, total)
	local angle = ((index - 1) / math.max(total, 1)) * math.pi * 2
	local radius = 34
	local position = Config.ARENA_CENTER + Vector3.new(
		math.cos(angle) * radius,
		5,
		math.sin(angle) * radius
	)
	return CFrame.new(position)
end

return ArenaService
