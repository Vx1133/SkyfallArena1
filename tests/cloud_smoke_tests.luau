-- Headless smoke tests for the exact uploaded Skyfall Arena place version.
-- This validates the DataModel and service logic, not real physics or touch input.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local sharedFolder = ReplicatedStorage:FindFirstChild("Shared")
assert(sharedFolder, "ReplicatedStorage.Shared is missing")
local configModule = sharedFolder:FindFirstChild("GameConfig")
assert(configModule and configModule:IsA("ModuleScript"), "GameConfig ModuleScript is missing")
local Config = require(configModule)

local serverRoot = ServerScriptService:FindFirstChild("SkyfallServer")
assert(serverRoot, "ServerScriptService.SkyfallServer is missing")
local servicesFolder = serverRoot:FindFirstChild("Services")
assert(servicesFolder, "SkyfallServer.Services is missing")

local function requireService(name)
	local moduleScript = servicesFolder:FindFirstChild(name)
	assert(moduleScript and moduleScript:IsA("ModuleScript"), name .. " ModuleScript is missing")
	return require(moduleScript)
end

local ArenaService = requireService("ArenaService")
local RoundService = requireService("RoundService")
local StrikeService = requireService("StrikeService")

local passed = 0
local failed = 0
local failureMessages = {}

local function runTest(name, callback)
	local ok, result = pcall(callback)
	if ok then
		passed += 1
		print("PASS | " .. name)
	else
		failed += 1
		local message = name .. ": " .. tostring(result)
		table.insert(failureMessages, message)
		warn("FAIL | " .. message)
	end
end

local arena

runTest("Arena builds a 15x15 destructible grid for a 30-participant match", function()
	assert(Config.GRID_SIZE == 15, "Expected a 15x15 tile grid")
	assert(Config.MAX_PLAYER_CAPACITY == 30, "Expected capacity for 30 human players")
	assert(Config.MAP_COUNT == 5, "Expected five original map layouts")
	assert(Config.HUMAN_STRIKE_COOLDOWN_SECONDS == 3, "Human laser cooldown must be three seconds")
	assert(Config.CONTROLLER_CAMERA_HEIGHT == 170, "Portrait controller camera height must fit the arena")
	assert(Config.CONTROLLER_CAMERA_BACK == 24, "Portrait controller camera must use a small rear offset")
	assert(Config.CONTROLLER_CAMERA_FOV == 96, "Portrait controller camera must frame the arena")
	assert(Config.CONTROLLER_CAMERA_LANDSCAPE_HEIGHT == 140, "Landscape controller camera height must bring the arena closer")
	assert(Config.CONTROLLER_CAMERA_LANDSCAPE_BACK == 110, "Landscape controller camera must use an angled overhead view")
	assert(Config.CONTROLLER_CAMERA_LANDSCAPE_FOV == 52, "Landscape controller camera must avoid the extreme wide view")

	arena = ArenaService.new()
	arena:Build()

	local expectedTileCount = Config.GRID_SIZE * Config.GRID_SIZE
	assert(#arena.tilesFolder:GetChildren() == expectedTileCount, "Unexpected tile count")
	assert(#arena:GetSafeTiles() == expectedTileCount, "All tiles should be safe at round start")

	local centerTile = arena:GetTile(8, 8)
	assert(centerTile ~= nil, "Center tile is missing")
	assert(centerTile:FindFirstChild("SquareStud_1"), "Square stud details are missing from floor tiles")
	local stud = centerTile:FindFirstChild("SquareStud_1")
	assert(stud:IsA("BasePart") and stud.Shape == Enum.PartType.Block, "Floor studs must be square blocks")
	assert(math.abs(stud.Size.X - stud.Size.Z) < 0.001, "Floor studs must have square footprints")

	assert(arena.lobbyFolder:FindFirstChild("WaitingPlatform"), "Waiting platform is missing")
	local water = arena.lobbyFolder:FindFirstChild("LobbyWater")
	assert(water and water.Material == Enum.Material.Water, "Medium lobby water feature is missing")
	assert(arena.aircraftModel and arena.aircraftModel:FindFirstChild("AircraftFuselage"), "Golden controller sphere is missing")
	assert(arena.aircraftModel:FindFirstChild("ControllerLens"), "Red controller lens is missing")
	for index = 1, 5 do
		assert(arena.aircraftModel:FindFirstChild("ArmorPlate_Upper_" .. tostring(index)), "Upper sphere armor plate is missing")
	end
	for index = 1, 4 do
		assert(arena.aircraftModel:FindFirstChild("ArmorPlate_Lower_" .. tostring(index)), "Lower sphere armor plate is missing")
	end
	assert(arena.aircraftModel:FindFirstChild("LensReticleRing_Outer_1"), "Outer lens reticle ring is missing")
	assert(arena.aircraftModel:FindFirstChild("LensReticleRing_Inner_1"), "Inner lens reticle ring is missing")
	local lensLight = arena.aircraftModel.ControllerLens:FindFirstChildOfClass("PointLight")
	assert(not lensLight or lensLight.Range <= 5, "Red lens light must remain tightly contained")
	assert(arena.mapFolder:FindFirstChild("MapNameSign"), "Map name sign is missing")

	for index = 1, Config.MAX_PLAYER_CAPACITY do
		local runnerPosition = arena:GetRunnerSpawnCFrame(index, Config.MAX_PLAYER_CAPACITY).Position
		assert(math.abs(runnerPosition.X - Config.ARENA_CENTER.X) < Config.ARENA_HALF_WIDTH, "Runner spawn is outside the arena")
		assert(math.abs(runnerPosition.Z - Config.ARENA_CENTER.Z) < Config.ARENA_HALF_WIDTH, "Runner spawn is outside the arena")

		local lobbyPosition = arena:GetLobbySpawnCFrame(index, Config.MAX_PLAYER_CAPACITY, false).Position
		assert(math.abs(lobbyPosition.X - Config.LOBBY_CENTER.X) < Config.LOBBY_SIZE / 2, "Lobby spawn is outside the waiting platform")
		assert(math.abs(lobbyPosition.Z - Config.LOBBY_CENTER.Z) < Config.LOBBY_SIZE / 2, "Lobby spawn is outside the waiting platform")
	end
end)

runTest("All five maps are daytime, have no neon decoration, and contain no arena rings", function()
	assert(arena ~= nil, "Arena setup did not complete")

	for mapId, expectedName in ipairs(Config.MAP_NAMES) do
		assert(arena:SetMap(mapId) == expectedName, "Map name does not match map " .. tostring(mapId))
		assert(arena:GetMapName() == expectedName, "Active map name is incorrect")
		assert(arena:GetTile(8, 8).Material == Enum.Material.SmoothPlastic, "Destructible floor must use a clean studded plastic surface")
		assert(Lighting.ClockTime >= 10 and Lighting.ClockTime <= 16, "Map lighting is not daytime")

		for _, descendant in ipairs(arena.decorFolder:GetDescendants()) do
			if descendant:IsA("BasePart") then
				assert(descendant.Material ~= Enum.Material.Neon, "Neon material remains in map: " .. descendant:GetFullName())
				assert(not string.find(descendant.Name, "RingSegment"), "Segmented ring barrier remains in the map")
				assert(not string.find(descendant.Name, "ReactorRing"), "Circular reactor barrier remains in the map")
			end
		end
	end
end)

runTest("Broken tiles remain broken until a new map is loaded", function()
	assert(arena ~= nil, "Arena setup did not complete")

	local targets = {
		{8, 8},
		{7, 8},
		{8, 7},
		{9, 8},
	}

	for _, coordinates in ipairs(targets) do
		local tile = arena:GetTile(coordinates[1], coordinates[2])
		assert(tile ~= nil, "Test tile is missing")
		local token = arena:MarkTile(tile)
		assert(token ~= nil, "A fresh tile should accept a laser warning")
		assert(arena:MarkTile(tile) == nil, "A tile already under warning must reject another strike")
		arena:BreakTile(tile, token)
		assert(tile:GetAttribute("IsBroken") == true, "Tile must be marked broken")
		assert(tile.CanCollide == false, "Broken tile must not collide")
		for _, child in ipairs(tile:GetChildren()) do
			if child.Name == "SquareStud_1" or string.match(child.Name, "^SquareStud_") then
				assert(child.Transparency == 1, "Square studs on a broken tile must be hidden")
			end
		end
	end

	assert(#arena:GetSafeTiles() == Config.GRID_SIZE * Config.GRID_SIZE - 4, "Four broken tiles should be excluded from safe tiles")
	task.wait(2.2)

	for _, coordinates in ipairs(targets) do
		local tile = arena:GetTile(coordinates[1], coordinates[2])
		assert(tile:GetAttribute("IsBroken") == true, "A broken tile repaired itself before the next map")
		assert(tile.CanCollide == false, "A broken tile regained collision before the next map")
	end
end)

runTest("Every new map restores the floor and invalidates stale laser tokens", function()
	assert(arena ~= nil, "Arena setup did not complete")
	local tile = arena:GetTile(8, 8)
	local staleToken = tile:GetAttribute("StrikeToken")

	for mapId, expectedName in ipairs(Config.MAP_NAMES) do
		assert(arena:SetMap(mapId) == expectedName, "Map rotation failed at map " .. tostring(mapId))
		assert(#arena:GetSafeTiles() == Config.GRID_SIZE * Config.GRID_SIZE, "New map did not restore the full grid")
		assert(tile:GetAttribute("IsBroken") == false, "New map did not clear broken state")
		assert(tile.CanCollide == true, "New map did not restore floor collision")
		arena:BreakTile(tile, staleToken)
		assert(tile:GetAttribute("IsBroken") == false, "A stale laser token broke a tile after map reset")
	end
end)

runTest("Random map selection never repeats the previous map", function()
	local harness = setmetatable({
		lastMapId = 0,
		random = Random.new(73421),
	}, RoundService)

	for _ = 1, 100 do
		local nextMapId = harness:_chooseNextMapId()
		assert(nextMapId >= 1 and nextMapId <= Config.MAP_COUNT, "Selected map ID is outside the five-map range")
		assert(nextMapId ~= harness.lastMapId, "The same map repeated in consecutive rounds")
		harness.lastMapId = nextMapId
	end
end)

runTest("Controller drone and arena remain free of neon materials", function()
	assert(arena ~= nil, "Arena setup did not complete")
	for _, root in ipairs({arena.tilesFolder, arena.decorFolder}) do
		for _, descendant in ipairs(root:GetDescendants()) do
			if descendant:IsA("BasePart") then
				assert(descendant.Material ~= Enum.Material.Neon, "Neon material found in the game map")
			end
		end
	end
end)

runTest("Controller selection accepts a first controller and prioritizes the previous survivor", function()
	local testBot = {
		name = "CloudTestBot",
		model = {Parent = Workspace},
		humanoid = {Health = 100, FloorMaterial = Enum.Material.Metal},
	}
	local testBotService = {
		GetBots = function() return {testBot} end,
		GetAliveBots = function() return {testBot} end,
	}
	local harness = setmetatable({
		botService = testBotService,
		random = Random.new(12345),
		nextController = nil,
		aliveRunners = {},
	}, RoundService)

	local firstController = harness:_chooseController()
	assert(firstController ~= nil, "First round should select an available player or bot")
	assert(harness:_isCandidateValid(firstController), "First-round controller must be valid")

	harness.nextController = {kind = "Bot", value = testBot}
	local nextController = harness:_chooseController()
	assert(nextController and nextController.kind == "Bot", "Previous survivor kind should be retained")
	assert(nextController.value == testBot, "Previous survivor should be the next controller")
end)

runTest("Sole survivor and grounded checks distinguish air from floor", function()
	local testBot = {
		name = "CloudTestBot",
		model = {Parent = Workspace},
		humanoid = {Health = 100, FloorMaterial = Enum.Material.Metal},
	}
	local testBotService = {
		GetAliveBots = function() return {testBot} end,
	}
	local harness = setmetatable({
		botService = testBotService,
		aliveRunners = {},
	}, RoundService)

	local survivor = harness:_getSoleSurvivor()
	assert(survivor and survivor.kind == "Bot" and survivor.value == testBot, "The only living bot should be the sole survivor")
	assert(harness:_isGrounded(survivor) == true, "A survivor touching a floor should be grounded")
	testBot.humanoid.FloorMaterial = Enum.Material.Air
	assert(harness:_isGrounded(survivor) == false, "A survivor in the air must not be treated as grounded")
end)

runTest("Human laser requests validate the controller, coordinates, phase, and three-second cooldown", function()
	local controller = {UserId = 8675309}
	local canControl = false
	local isActive = true
	local markCount = 0
	local beamCount = 0
	local breakCount = 0
	local mockTiles = {
		["8:8"] = {token = 0, broken = false},
		["9:8"] = {token = 0, broken = false},
	}

	local mockArena = {
		GetTile = function(_, gridX, gridZ) return mockTiles[tostring(gridX) .. ":" .. tostring(gridZ)] end,
		MarkTile = function(_, tile)
			if tile.broken then return nil end
			markCount += 1
			tile.token += 1
			tile.warning = true
			return tile.token
		end,
		IsStrikeCurrent = function(_, tile, token) return tile.token == token end,
		CreateStrikeBeam = function() beamCount += 1 end,
		BreakTile = function(_, tile, token)
			if tile.token == token then
				tile.warning = false
				tile.broken = true
				breakCount += 1
			end
		end,
		ClearWarning = function(_, tile) tile.warning = false end,
	}
	local mockRounds = {
		IsHumanController = function(_, candidate) return canControl and candidate == controller end,
		IsActive = function() return isActive end,
		GetAlivePositions = function() return {} end,
	}
	local mockBotService = {
	GetAlivePositions = function()
		return {}
	end,
}
	local strikeService = StrikeService.new(mockArena, mockRounds, mockBotService, {})
	strikeService.lastHumanStrikeAt[controller.UserId] =
		os.clock() - Config.HUMAN_STRIKE_COOLDOWN_SECONDS - 1

	canControl = true
	isActive = false
	strikeService:_handleHumanTarget(controller, 8, 8)
	assert(markCount == 0, "Laser request should be rejected outside an active round")

	isActive = true
	strikeService:_handleHumanTarget({UserId = 111}, 8, 8)
	strikeService:_handleHumanTarget(controller, 0, 8)
	strikeService:_handleHumanTarget(controller, 8.5, 8)
	strikeService:_handleHumanTarget(controller, 8, 8.5)
	assert(markCount == 0, "Invalid controller or grid coordinates must not mark a tile")

	strikeService:_handleHumanTarget(controller, 8, 8)
	assert(markCount == 1, "A valid controller target should mark exactly one tile")
	strikeService:_handleHumanTarget(controller, 9, 8)
	assert(markCount == 1, "A second request inside the cooldown should be rejected")

	task.wait(Config.WARNING_SECONDS + 0.25)
	assert(beamCount == 1, "A valid strike should create one laser beam")
	assert(breakCount == 1, "A valid strike should break one tile")
	assert(mockTiles["8:8"].broken == true, "The targeted tile should be broken")
	assert(mockTiles["9:8"].broken == false, "A cooldown-rejected tile must remain intact")

	task.wait(Config.HUMAN_STRIKE_COOLDOWN_SECONDS - Config.WARNING_SECONDS + 0.15)
	strikeService:_handleHumanTarget(controller, 9, 8)
	assert(markCount == 2, "A new laser strike should be accepted after three seconds")
	task.wait(Config.WARNING_SECONDS + 0.25)
	assert(beamCount == 2 and breakCount == 2, "The second allowed strike should resolve normally")
	assert(mockTiles["9:8"].broken == true, "The second allowed target should be destroyed")
end)

if arena and arena.aircraftModel then
	arena.aircraftModel:Destroy()
end
if arena and arena.root then
	arena.root:Destroy()
end

print("SKYFALL_CLOUD_TESTS_SUMMARY | passed=" .. tostring(passed) .. " | failed=" .. tostring(failed))
if failed > 0 then
	error("Skyfall cloud smoke tests failed: " .. table.concat(failureMessages, " || "))
end

print("SKYFALL_CLOUD_TESTS_OK")
return {passed = passed, failed = failed}
