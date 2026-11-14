local Workspace = game:GetService("Workspace")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))

local ArenaService = {}
ArenaService.__index = ArenaService

local TILE_COLOR = Color3.fromRGB(37, 55, 78)
local TILE_WARNING_COLOR = Color3.fromRGB(255, 170, 42)
local TILE_BROKEN_COLOR = Color3.fromRGB(120, 35, 42)

local function createPart(parent, name, size, position, color, material)
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.Position = position
	part.Color = color
	part.Material = material
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
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

	self.tiles = {}
	return self
end

function ArenaService:Build()
	for _, child in ipairs(self.tilesFolder:GetChildren()) do
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

	local lobby = self.root:FindFirstChild("LobbyPlatform")
	if not lobby then
		lobby = createPart(
			self.root,
			"LobbyPlatform",
			Vector3.new(44, 2, 44),
			Config.LOBBY_CENTER,
			Color3.fromRGB(39, 91, 105),
			Enum.Material.Slate
		)
	end
	lobby.CanQuery = false

	local deck = self.root:FindFirstChild("ControllerDeck")
	if not deck then
		deck = createPart(
			self.root,
			"ControllerDeck",
			Vector3.new(20, 2, 20),
			Config.CONTROL_CENTER,
			Color3.fromRGB(48, 52, 77),
			Enum.Material.Metal
		)
	end
	deck.CanQuery = false

	local core = self.root:FindFirstChild("DroneCore")
	if not core then
		core = createPart(
			self.root,
			"DroneCore",
			Vector3.new(9, 6, 9),
			Config.CONTROL_CENTER - Vector3.new(0, 5, 0),
			Color3.fromRGB(102, 80, 190),
			Enum.Material.Neon
		)
		core.Shape = Enum.PartType.Ball
		core.CanCollide = false
	end
	core.CanQuery = false

	for _, side in ipairs({-1, 1}) do
		local wingName = side < 0 and "DroneWingLeft" or "DroneWingRight"
		local wing = self.root:FindFirstChild(wingName)
		if not wing then
			wing = createPart(
				self.root,
				wingName,
				Vector3.new(12, 1.5, 4),
				Config.CONTROL_CENTER + Vector3.new(side * 13, -4, 0),
				Color3.fromRGB(64, 181, 210),
				Enum.Material.Neon
			)
		end
		wing.CanCollide = false
		wing.CanQuery = false
	end

	local oldCourse = self.root:FindFirstChild("ParkourCourse")
	if oldCourse then
		oldCourse:Destroy()
	end

	local courseFolder = Instance.new("Folder")
	courseFolder.Name = "ParkourCourse"
	courseFolder.Parent = self.root

	local courseParts = {
		{
			name = "ParkourStart",
			size = Vector3.new(12, 2, 12),
			position = Vector3.new(-162, 12, 0),
			color = Color3.fromRGB(43, 143, 174),
			material = Enum.Material.Slate,
		},
		{
			name = "ParkourStep_1",
			size = Vector3.new(8, 2, 8),
			position = Vector3.new(-150, 14.5, 0),
			color = Color3.fromRGB(54, 126, 190),
			material = Enum.Material.Metal,
		},
		{
			name = "ParkourStep_2",
			size = Vector3.new(8, 2, 8),
			position = Vector3.new(-138, 17, 2),
			color = Color3.fromRGB(64, 139, 202),
			material = Enum.Material.Metal,
		},
		{
			name = "ParkourStep_3",
			size = Vector3.new(8, 2, 8),
			position = Vector3.new(-126, 19.5, -2),
			color = Color3.fromRGB(75, 151, 210),
			material = Enum.Material.Metal,
		},
		{
			name = "ParkourStep_4",
			size = Vector3.new(8, 2, 8),
			position = Vector3.new(-114, 22, 2),
			color = Color3.fromRGB(89, 164, 215),
			material = Enum.Material.Metal,
		},
		{
			name = "ParkourStep_5",
			size = Vector3.new(8, 2, 8),
			position = Vector3.new(-102, 24.5, 0),
			color = Color3.fromRGB(110, 179, 219),
			material = Enum.Material.Metal,
		},
		{
			name = "ParkourFinish",
			size = Vector3.new(18, 2, 14),
			position = Vector3.new(-84, 24.5, 0),
			color = Color3.fromRGB(63, 190, 145),
			material = Enum.Material.Neon,
		},
	}

	for index, definition in ipairs(courseParts) do
		local platform = createPart(
			courseFolder,
			definition.name,
			definition.size,
			definition.position,
			definition.color,
			definition.material
		)
		platform:SetAttribute("ParkourIndex", index)
	end

	local finishBeacon = createPart(
		courseFolder,
		"ParkourFinishBeacon",
		Vector3.new(3, 10, 3),
		Vector3.new(-84, 30.5, 0),
		Color3.fromRGB(255, 224, 112),
		Enum.Material.Neon
	)
	finishBeacon.CanCollide = false
	finishBeacon.CanQuery = false
end

function ArenaService:GetTile(gridX, gridZ)
	return self.tiles[tileKey(gridX, gridZ)]
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
	local beam = createPart(
		self.root,
		"StrikeBeam",
		Vector3.new(1.6, Config.BEAM_HEIGHT, 1.6),
		tile.Position + Vector3.new(0, Config.BEAM_HEIGHT / 2, 0),
		Color3.fromRGB(255, 82, 45),
		Enum.Material.Neon
	)
	beam.Transparency = 0.15
	beam.CanCollide = false
	beam.CanTouch = false
	beam.CanQuery = false
	Debris:AddItem(beam, 0.3)
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

function ArenaService:GetLobbySpawnCFrame()
	return CFrame.new(Config.LOBBY_CENTER + Vector3.new(0, 5, 0))
end

function ArenaService:GetControllerSpawnCFrame()
	return CFrame.new(Config.CONTROL_CENTER + Vector3.new(0, 6, 0))
end

function ArenaService:GetRunnerSpawnCFrame(index, total)
	local angle = ((index - 1) / math.max(total, 1)) * math.pi * 2
	local radius = 36
	local position = Config.ARENA_CENTER + Vector3.new(
		math.cos(angle) * radius,
		5,
		math.sin(angle) * radius
	)
	return CFrame.new(position)
end

return ArenaService
