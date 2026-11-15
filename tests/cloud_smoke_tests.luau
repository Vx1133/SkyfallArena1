-- Headless smoke tests for the exact uploaded Skyfall Arena place version.
-- This validates the DataModel and service logic, not real physics or touch input.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
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
local AdminFlightService = requireService("AdminFlightService")

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

runTest("Arena builds one 15x15 destructible Classic arena for a 30-player experience", function()
	assert(Config.GRID_SIZE == 15, "Expected a 15x15 tile grid")
	assert(Config.MAX_PLAYER_CAPACITY == 30, "Expected capacity for 30 human players")
	assert(Config.MAP_COUNT == 1, "The experience must contain exactly one playable map")
	assert(Config.MAP_NAMES[1] == "SKYFALL CLASSIC ARENA", "The only map should be the Classic arena")
	assert(Config.BOT_COUNT == 10, "Exactly ten AI bots must be configured")
	assert(Config.TILE_GAP == 0, "Destructible floor tiles must have no designed gap")
	assert(Config.ROUND_SECONDS == 180, "Each round must last three minutes")
	assert(Config.HUMAN_STRIKE_COOLDOWN_SECONDS == 3, "Human laser cooldown must be three seconds")
	assert(Config.CONTROLLER_CAMERA_HEIGHT == 145, "Portrait controller camera must stay close to the arena")
	assert(Config.CONTROLLER_CAMERA_BACK == 8, "Portrait controller camera must stay nearly overhead")
	assert(Config.CONTROLLER_CAMERA_FOV == 110, "Portrait controller camera must fit the full arena width")
	assert(Config.CONTROLLER_CAMERA_LANDSCAPE_HEIGHT == 130, "Landscape controller camera height must bring the arena closer")
	assert(Config.CONTROLLER_CAMERA_LANDSCAPE_BACK == 130, "Landscape controller camera must use a balanced overhead angle")
	assert(Config.CONTROLLER_CAMERA_LANDSCAPE_FOV == 44, "Landscape controller camera must keep tiles large and readable")

	arena = ArenaService.new()
	arena:Build()

	local expectedTileCount = Config.GRID_SIZE * Config.GRID_SIZE
	assert(#arena.tilesFolder:GetChildren() == expectedTileCount, "Unexpected tile count")
	assert(#arena:GetSafeTiles() == expectedTileCount, "All tiles should be safe at round start")

	local centerTile = arena:GetTile(8, 8)
	assert(centerTile ~= nil, "Center tile is missing")
	assert(centerTile:FindFirstChild("SquareStud_9"), "Each floor tile should contain a nine-stud classic pattern")
	local stud = centerTile:FindFirstChild("SquareStud_1")
	assert(stud:IsA("BasePart") and stud.Shape == Enum.PartType.Block, "Floor studs must be square blocks")
	assert(math.abs(stud.Size.X - stud.Size.Z) < 0.001, "Floor studs must have square footprints")

	assert(arena.lobbyFolder:FindFirstChild("WaitingPlatform"), "Classic waiting baseplate is missing")
	assert(arena.lobbyFolder:FindFirstChild("LobbyFloorPanel_12_12"), "The connected lobby stud floor is missing")
	local water = arena.lobbyFolder:FindFirstChild("LobbyWater")
	assert(water and water.Material == Enum.Material.Water, "Classic lobby fountain is missing")
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
	assert(arena.mapFolder:FindFirstChild("ClassicArenaNameSign"), "Classic arena name sign is missing")
	assert(arena.lobbyFolder:FindFirstChild("LobbyWelcomeSign"), "Waiting garden sign is missing")
	assert(arena.mapFolder:FindFirstChild("LobbyToArenaWalkway") == nil, "The waiting garden must stay separate from the arena")
	assert(arena.aircraftModel:FindFirstChild("LaserOrigin"), "The golden drone laser origin attachment is missing")
	assert(arena.aircraftModel:FindFirstChild("PilotPlatform") == nil, "A visible pilot platform must not be built")
	assert(Lighting:FindFirstChild("SkyfallSunriseSky") == nil, "Custom skybox must be removed")
	assert(Lighting:FindFirstChild("SkyfallAtmosphere") == nil, "Custom Atmosphere must be removed")
	assert(Lighting:FindFirstChild("SkyfallColorCorrection") == nil, "Custom color correction must be removed")
	assert(Lighting:FindFirstChild("SkyfallBloom") == nil, "Custom Bloom must be removed")
	assert(Lighting:FindFirstChild("SkyfallSunRays") == nil, "Custom SunRays must be removed")
	assert(Workspace.Terrain:FindFirstChild("SkyfallClouds") == nil, "Custom clouds must be removed")
	assert(Lighting.Brightness == 2, "Lighting brightness should be neutral")
	assert(Lighting.ClockTime == 14, "Lighting time should be the neutral daytime default")
	assert(Lighting.Ambient == Color3.fromRGB(0, 0, 0), "Ambient light should be neutral")
	assert(Lighting.OutdoorAmbient == Color3.fromRGB(127, 127, 127), "Outdoor ambient should be neutral")
	assert(Lighting.ExposureCompensation == 0, "Exposure compensation should be neutral")
	assert(Lighting.EnvironmentDiffuseScale == 0 and Lighting.EnvironmentSpecularScale == 0, "Environment reflection boost must be disabled")
	assert(arena.mapDecorBuilt == true, "The single map decoration should be built once")
	local separation = (Config.ARENA_CENTER - Config.LOBBY_CENTER).Magnitude
	assert(separation > Config.ARENA_HALF_WIDTH + Config.LOBBY_SIZE / 2 + 10, "Lobby must be physically separated from the arena")

	arena:CreateStrikeBeam(centerTile)
	local blueOuter = arena.root:FindFirstChild("BlueLaserOuter")
	local blueCore = arena.root:FindFirstChild("BlueLaserCore")
	assert(blueOuter and blueOuter:IsA("Beam"), "The drone must create an outer blue Beam")
	assert(blueCore and blueCore:IsA("Beam"), "The drone must create a blue-white core Beam")
	assert(blueOuter.Attachment0 == arena.laserOrigin, "The visible laser must originate from the golden sphere")

	for index = 1, Config.MAX_PLAYER_CAPACITY do
		local runnerPosition = arena:GetRunnerSpawnCFrame(index, Config.MAX_PLAYER_CAPACITY).Position
		assert(math.abs(runnerPosition.X - Config.ARENA_CENTER.X) < Config.ARENA_HALF_WIDTH, "Runner spawn is outside the arena")
		assert(math.abs(runnerPosition.Z - Config.ARENA_CENTER.Z) < Config.ARENA_HALF_WIDTH, "Runner spawn is outside the arena")

		local lobbyPosition = arena:GetLobbySpawnCFrame(index, Config.MAX_PLAYER_CAPACITY, false).Position
		assert(math.abs(lobbyPosition.X - Config.LOBBY_CENTER.X) < Config.LOBBY_SIZE / 2, "Lobby spawn is outside the waiting platform")
		assert(math.abs(lobbyPosition.Z - Config.LOBBY_CENTER.Z) < Config.LOBBY_SIZE / 2, "Lobby spawn is outside the waiting platform")
	end
end)

runTest("Ten native Roblox bot rigs are created for solo testing", function()
	local botFolder = Workspace:FindFirstChild("SkyfallBots")
	assert(botFolder ~= nil, "The bot folder should be created at server startup")
	assert(#botFolder:GetChildren() == Config.BOT_COUNT, "Exactly ten bot rigs should exist")
	for _, botModel in ipairs(botFolder:GetChildren()) do
		assert(botModel:IsA("Model"), "Every bot entry should be a Model")
		assert(botModel:FindFirstChildOfClass("Humanoid") ~= nil, "Every bot rig should contain a Humanoid")
		assert(botModel:FindFirstChild("HumanoidRootPart") ~= nil, "Every bot rig should contain a root part")
	end
end)

runTest("The Classic arena uses neutral lighting and connected stud geometry", function()
	assert(arena ~= nil, "Arena setup did not complete")
	assert(Config.MAP_COUNT == 1, "Map rotation must be disabled")
	assert(arena:SetMap(1) == "SKYFALL CLASSIC ARENA", "The only playable map should be Classic Arena")
	assert(arena:GetMapName() == "SKYFALL CLASSIC ARENA", "Active map name is incorrect")
	assert(arena:GetTile(8, 8).Material == Enum.Material.Plastic, "Destructible floor must use classic Plastic")
	local leftTile = arena:GetTile(8, 8)
	local rightTile = arena:GetTile(9, 8)
	assert(math.abs((rightTile.Position.X - leftTile.Position.X) - Config.TILE_SIZE) < 0.001, "Neighboring floor tiles must touch with no gap")
	assert(math.abs(leftTile.Size.X - Config.TILE_SIZE) < 0.001, "Tile width must match its grid spacing")
	assert(Lighting.ClockTime >= 10 and Lighting.ClockTime <= 16, "Map lighting is not daytime")
	assert(Lighting:FindFirstChild("SkyfallSunriseSky") == nil, "No custom Sky instance should be retained")
	assert(arena.mapFolder:FindFirstChild("ClassicArenaGate"), "Classic arena gate is missing")
	assert(arena.mapFolder:FindFirstChild("LobbyToArenaWalkway") == nil, "A bridge to the lobby must not exist")

	for _, descendant in ipairs(arena.decorFolder:GetDescendants()) do
		if descendant:IsA("BasePart") then
			assert(descendant.Material ~= Enum.Material.Neon, "Neon material remains in map: " .. descendant:GetFullName())
			assert(not string.find(descendant.Name, "RingSegment"), "Segmented ring barrier remains in the map")
			assert(not string.find(descendant.Name, "ReactorRing"), "Circular reactor barrier remains in the map")
		end
	end

	assert(arena.mapFolder:FindFirstChild("CloudspireSkyPalace") == nil, "Old Cloudspire map remains")
	assert(arena.mapFolder:FindFirstChild("GoldenDunesTemple") == nil, "Old Golden Dunes map remains")
	assert(arena.mapFolder:FindFirstChild("EmeraldGroveSanctuary") == nil, "Old Emerald Grove map remains")
	assert(arena.mapFolder:FindFirstChild("AzureHarborFortress") == nil, "Old Azure Harbor map remains")
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
		assert(tile.Color == Color3.fromRGB(255, 55, 75), "A targeted tile must be marked red")
		assert(tile:FindFirstChild("TargetWarningLight"), "A targeted tile must show a red warning light")
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

runTest("The one map restores the floor only when a new round loads", function()
	assert(arena ~= nil, "Arena setup did not complete")
	local tile = arena:GetTile(8, 8)
	local staleToken = tile:GetAttribute("StrikeToken")
	assert(arena:SetMap(1) == "SKYFALL CLASSIC ARENA", "The single map failed to reload")
	assert(#arena:GetSafeTiles() == Config.GRID_SIZE * Config.GRID_SIZE, "New round did not restore the full grid")
	assert(tile:GetAttribute("IsBroken") == false, "New round did not clear broken state")
	assert(tile.CanCollide == true, "New round did not restore floor collision")
	arena:BreakTile(tile, staleToken)
	assert(tile:GetAttribute("IsBroken") == false, "A stale laser token broke a tile after reset")
end)

runTest("The next-round map remains the one fixed Classic arena", function()
	local harness = setmetatable({
		lastMapId = 1,
		random = Random.new(73421),
	}, RoundService)

	for _ = 1, 100 do
		assert(harness:_chooseNextMapId() == 1, "The only map must always be selected")
	end
end)

runTest("The round state counts down from 180 seconds and reports runner eliminations", function()
	local capturedState = nil
	local harness = setmetatable({
		phase = "Active",
		roundHumanCount = #Players:GetPlayers(),
		readyPlayers = {},
		elapsedSeconds = 75,
		countdownSeconds = 0,
		roundRunnerCount = 4,
		aliveRunners = {},
		controller = nil,
		winner = "",
		roundNumber = 1,
		botService = {
			GetBotCount = function() return Config.BOT_COUNT end,
			GetAliveCount = function() return 0 end,
		},
		arena = {
			GetMapName = function() return "SKYFALL CLASSIC ARENA" end,
		},
		stateRemote = {
			FireAllClients = function(_, state)
				capturedState = state
			end,
		},
	}, RoundService)

	harness:_broadcast()
	assert(capturedState ~= nil, "Round state should be broadcast")
	assert(capturedState.remainingSeconds == 105, "Remaining time should count down from three minutes")
	assert(capturedState.eliminatedPlayers == 4, "Eliminated runner count should be reported")
	assert(capturedState.playerCount == #game:GetService("Players"):GetPlayers() + Config.BOT_COUNT, "Total player count should include all ten bots")
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

runTest("Players remain in the lobby until they request Play", function()
	local harness = setmetatable({
		phase = "Waiting",
		readyPlayers = {},
		aliveRunners = {},
		elapsedSeconds = 0,
		countdownSeconds = 0,
		roundRunnerCount = 0,
		controller = nil,
		winner = "",
		roundNumber = 0,
		arena = {GetMapName = function() return "SKYFALL CLASSIC ARENA" end},
		stateRemote = {FireAllClients = function() end},
	}, RoundService)
	assert(harness:_readyPlayerCount() == 0, "A new server must have no ready players")
	local fakePlayer = {
		Parent = Players,
		attributes = {},
		SetAttribute = function(self, name, value)
			self.attributes[name] = value
		end,
	}
	assert(harness:RequestPlay(fakePlayer) == true, "A waiting player should be able to request Play")
	assert(fakePlayer.attributes.SkyfallReady == true, "The server should record the ready state")
	assert(harness:_readyPlayerCount() == 1, "A Play request should add exactly one ready player")
	harness.phase = "Active"
	local latePlayer = {
		Parent = Players,
		SetAttribute = function() end,
	}
	assert(harness:RequestPlay(latePlayer) == false, "A player must not join after the round starts")
end)

runTest("Creator flight authorization only grants the personal experience owner", function()
	assert(AdminFlightService.IsAuthorizedUserId(12345, Enum.CreatorType.User, 12345), "Personal creator should be authorized")
	assert(not AdminFlightService.IsAuthorizedUserId(54321, Enum.CreatorType.User, 12345), "A different user must not be authorized")
	assert(not AdminFlightService.IsAuthorizedUserId(12345, Enum.CreatorType.Group, 12345), "Group-owned experiences must not implicitly authorize a group member")
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
		roundNumber = 2,
		readyPlayers = {},
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

runTest("The longest-surviving runner is selected as the next controller", function()
	local shortRunner = {
		name = "ShortRunner",
		model = {Parent = Workspace},
	}
	local longRunner = {
		name = "LongRunner",
		model = {Parent = Workspace},
	}
	local shortCandidate = {kind = "Bot", value = shortRunner}
	local longCandidate = {kind = "Bot", value = longRunner}
	local harness = setmetatable({
		roundRunners = {
			[shortRunner] = shortCandidate,
			[longRunner] = longCandidate,
		},
		survivalTimes = {
			[shortRunner] = 42,
			[longRunner] = 137,
		},
		random = Random.new(12345),
	}, RoundService)

	local winner = harness:_getLongestSurvivor()
	assert(winner and winner.value == longRunner, "The runner with the highest survival time should win")
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
