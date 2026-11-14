-- Runs against one exact uploaded place version through Roblox Open Cloud Luau Execution.
-- This is a headless DataModel/module test. It does not simulate physics or player input.

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

local arena = nil

runTest("Arena builds a complete 9x9 tile grid and required structures", function()
	assert(Config.GRID_SIZE == 9, "Expected the configured 9x9 arena")
	arena = ArenaService.new()
	arena:Build()

	assert(#arena.tilesFolder:GetChildren() == Config.GRID_SIZE * Config.GRID_SIZE, "Unexpected tile count")
	assert(#arena:GetSafeTiles() == 81, "All 81 tiles should be safe at round start")
	assert(arena:GetTile(1, 1) ~= nil, "Top-left grid tile is missing")
	assert(arena:GetTile(9, 9) ~= nil, "Bottom-right grid tile is missing")
	assert(arena.lobbyFolder:FindFirstChild("WaitingPlatform"), "Waiting platform is missing")
	assert(arena.aircraftModel and arena.aircraftModel:FindFirstChild("AircraftFuselage"), "Aircraft fuselage is missing")
	assert(arena.mapFolder:FindFirstChild("MapNameSign"), "Map name sign is missing")
end)

runTest("Damaged tiles stay broken until the next map begins", function()
	assert(arena ~= nil, "Arena setup did not complete")

	local targets = {
		{5, 5},
		{4, 5},
		{5, 4},
		{6, 5},
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
	end

	assert(#arena:GetSafeTiles() == 77, "Four broken tiles should leave 77 safe tiles")
	task.wait(2.2)

	for _, coordinates in ipairs(targets) do
		local tile = arena:GetTile(coordinates[1], coordinates[2])
		assert(tile:GetAttribute("IsBroken") == true, "A broken tile repaired itself before the next round")
		assert(tile.CanCollide == false, "A broken tile regained collision before the next round")
	end
	assert(#arena:GetSafeTiles() == 77, "Safe tile count changed before a new map started")
end)

runTest("A new map restores the full floor and invalidates old laser tokens", function()
	assert(arena ~= nil, "Arena setup did not complete")
	local tile = arena:GetTile(5, 5)
	local staleToken = tile:GetAttribute("StrikeToken")

	assert(arena:SetMap(2) == "EMBER REACTOR", "Map 2 did not activate")
	assert(arena:GetMapName() == "EMBER REACTOR", "Map 2 name is incorrect")
	assert(#arena:GetSafeTiles() == 81, "Map 2 must restore all 81 tiles")
	assert(tile:GetAttribute("IsBroken") == false, "Map 2 did not clear broken state")
	assert(tile.CanCollide == true, "Map 2 did not restore floor collision")

	arena:BreakTile(tile, staleToken)
	assert(tile:GetAttribute("IsBroken") == false, "A stale laser token damaged a tile after map reset")

	assert(arena:SetMap(1) == "NEXUS SKYGRID", "Map 1 did not activate")
	assert(arena:GetMapName() == "NEXUS SKYGRID", "Map 1 name is incorrect")
	assert(#arena:GetSafeTiles() == 81, "Map 1 must also have a complete floor")
end)

runTest("Round selection accepts a first controller and prioritizes the previous survivor", function()
	local testBot = {
		name = "CloudTestBot",
		model = {Parent = Workspace},
		humanoid = {
			Health = 100,
			FloorMaterial = Enum.Material.Metal,
		},
	}

	local testBotService = {
		GetBots = function()
			return {testBot}
		end,
		GetAliveBots = function()
			return {testBot}
		end,
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
	assert(nextController ~= nil, "Previous survivor should be selected next")
	assert(nextController.kind == "Bot", "Previous survivor kind should be retained")
	assert(nextController.value == testBot, "Previous survivor should be the next controller")
end)

runTest("Sole survivor and grounded checks distinguish air from floor", function()
	local testBot = {
		name = "CloudTestBot",
		model = {Parent = Workspace},
		humanoid = {
			Health = 100,
			FloorMaterial = Enum.Material.Metal,
		},
	}
	local testBotService = {
		GetAliveBots = function()
			return {testBot}
		end,
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

runTest("Human laser requests validate role, coordinates, active phase, and cooldown", function()
	local controller = {UserId = 8675309}
	local canControl = false
	local isActive = true
	local markCount = 0
	local beamCount = 0
	local breakCount = 0

	local mockTiles = {
		["5:5"] = {token = 0, broken = false},
		["6:5"] = {token = 0, broken = false},
	}

	local mockArena = {
		GetTile = function(_, gridX, gridZ)
			return mockTiles[tostring(gridX) .. ":" .. tostring(gridZ)]
		end,
		MarkTile = function(_, tile)
			if tile.broken then
				return nil
			end
			markCount += 1
			tile.token += 1
			tile.warning = true
			return tile.token
		end,
		IsStrikeCurrent = function(_, tile, token)
			return tile.token == token
		end,
		CreateStrikeBeam = function()
			beamCount += 1
		end,
		BreakTile = function(_, tile, token)
			if tile.token == token then
				tile.warning = false
				tile.broken = true
				breakCount += 1
			end
		end,
		ClearWarning = function(_, tile)
			tile.warning = false
		end,
	}

	local mockRounds = {
		IsHumanController = function(_, player)
			return canControl and player == controller
		end,
		IsActive = function()
			return isActive
		end,
		GetAlivePositions = function()
			return {}
		end,
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
	strikeService:_handleHumanTarget(controller, 5, 5)
	assert(markCount == 0, "Laser request should be rejected outside an active round")

	isActive = true
	strikeService:_handleHumanTarget({UserId = 111}, 5, 5)
	strikeService:_handleHumanTarget(controller, 0, 5)
	strikeService:_handleHumanTarget(controller, 5.5, 5)
	strikeService:_handleHumanTarget(controller, 5, 5.5)
	assert(markCount == 0, "Invalid controller or grid coordinates must not mark a tile")

	strikeService:_handleHumanTarget(controller, 5, 5)
	assert(markCount == 1, "A valid controller target should mark exactly one tile")
	strikeService:_handleHumanTarget(controller, 6, 5)
	assert(markCount == 1, "A second request inside the cooldown should be rejected")

	task.wait(Config.WARNING_SECONDS + 0.25)
	assert(beamCount == 1, "A valid strike should create one laser beam")
	assert(breakCount == 1, "A valid strike should break one tile")
	assert(mockTiles["5:5"].broken == true, "The targeted tile should be broken")
	assert(mockTiles["6:5"].broken == false, "A cooldown-rejected tile must remain intact")
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
return {
	passed = passed,
	failed = failed,
}
