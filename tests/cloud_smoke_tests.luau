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
local BotService = requireService("BotService")
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
	assert(Config.CONTROLLER_CAMERA_FOV == 70, "Controller camera should use a wide overhead field of view")
	assert(Config.CONTROLLER_CAMERA_MARGIN == 8, "Controller camera should retain a small margin around the full arena")

	arena = ArenaService.new()
	arena:Build()

	local expectedTileCount = Config.GRID_SIZE * Config.GRID_SIZE
	assert(#arena.tilesFolder:GetChildren() == expectedTileCount, "Unexpected tile count")
	assert(#arena:GetSafeTiles() == expectedTileCount, "All tiles should be safe at round start")

	local centerTile = arena:GetTile(8, 8)
	assert(centerTile ~= nil, "Center tile is missing")
	assert(centerTile.TopSurface == Enum.SurfaceType.Studs, "Tile tops should use Roblox native Classic Stud surfaces")
	assert(centerTile.BottomSurface == Enum.SurfaceType.Inlet, "Tile undersides should use native Inlet surfaces")
	assert(#centerTile:GetChildren() == 0, "Native Stud surfaces must not generate extra child Parts")

	local lobbyPlatform = arena.lobbyFolder:FindFirstChild("WaitingPlatform")
	assert(lobbyPlatform, "Classic waiting baseplate is missing")
	assert(lobbyPlatform.TopSurface == Enum.SurfaceType.Studs, "Lobby baseplate must use native Classic Studs")
	assert(arena.lobbyFolder:FindFirstChild("LobbyWater") == nil, "Lobby water surface must be removed")
	assert(arena.lobbyFolder:FindFirstChild("LobbyWelcomeSign") == nil, "Floating lobby welcome board must be removed")
	for _, descendant in ipairs(arena.decorFolder:GetDescendants()) do
		local name = string.lower(descendant.Name)
		assert(not string.find(name, "tree"), "All trees must be removed")
		assert(not string.find(name, "bench") and not string.find(name, "chair"), "All seating must be removed")
		assert(descendant:IsA("BasePart") == false or descendant.Material ~= Enum.Material.Water, "Water surfaces must be removed")
	end
	local support = arena.mapFolder:FindFirstChild("ClassicArenaSupport")
	assert(support, "Arena support foundation is missing")
	assert(support.Size.Y <= 2.1, "Arena support foundation must be thin")
	assert(support.CanCollide == false, "Arena support foundation must not catch falling players")
	assert(support.CanTouch == false, "Arena support foundation must not receive touch events")
	assert(arena.mapFolder:FindFirstChild("ClassicPerimeterNorthSouth_-1"), "Continuous perimeter beams are missing")
	assert(arena.mapFolder:FindFirstChild("ClassicPerimeterEastWest_1"), "Perpendicular edge beams are missing")
	assert(arena.mapFolder:FindFirstChild("ClassicPerimeterCornerPost_1_1"), "Integrated corner supports are missing")
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
	assert(arena.mapFolder:FindFirstChild("ClassicArenaNameSign") == nil, "Old floating arena sign should not remain")
	assert(arena.mapFolder:FindFirstChild("LobbyToArenaWalkway") == nil, "The waiting garden must stay separate from the arena")
	local aircraftAnchor = arena.aircraftModel:FindFirstChild("AircraftMotionAnchor")
	local fuselage = arena.aircraftModel:FindFirstChild("AircraftFuselage")
	assert(aircraftAnchor and fuselage, "Unified aircraft root and fuselage are required")
	local bodyJoint = aircraftAnchor:FindFirstChild("AircraftBodyJoint")
	assert(bodyJoint and bodyJoint:IsA("Motor6D"), "The complete aircraft must use one body motion joint")
	assert(bodyJoint.Part0 == aircraftAnchor and bodyJoint.Part1 == fuselage, "The motion joint must connect the hidden anchor to the fuselage")
	assert(fuselage.Material == Enum.Material.Metal, "The golden fuselage must use Roblox's PBR Metal material")
	assert(fuselage.Reflectance >= 0.08, "The golden fuselage needs a controlled metallic reflection")
	local lens = arena.aircraftModel:FindFirstChild("ControllerLens")
	local lensWeld = nil
	for _, joint in ipairs(fuselage:GetChildren()) do
		if joint:IsA("WeldConstraint") and joint.Part1 == lens then
			lensWeld = joint
			break
		end
	end
	assert(lensWeld and lens.Anchored == false, "The red lens must be rigidly welded to the fuselage")
	local laserOrigin = arena.aircraftModel:FindFirstChild("LaserOrigin", true)
	assert(laserOrigin and laserOrigin.Parent == fuselage, "Laser origin must be attached directly to the unified fuselage")
	assert(arena.aircraftModel:FindFirstChild("ControllerLensGimbal", true) == nil, "An independently moving lens gimbal must not remain")
	local homeBodyC0 = bodyJoint.C0
	-- Four-cardinal lens aim tests catch sign and axis mismatches that a single target misses.
	local function verifyAimDirection(gridX, gridZ, label)
		local tile = arena:GetTile(gridX, gridZ)
		assert(tile, "Missing " .. label .. " aim-test tile")
		local targetPosition = tile.Position + Vector3.new(0, 0.65, 0)
		local aimToken = arena:AimAircraftAt(tile)
		assert(typeof(aimToken) == "number", "A valid " .. label .. " target must start a tokenized aim")
		task.wait(0.5)

		local desiredDirection = (targetPosition - fuselage.Position).Unit
		local opticalAxis = -fuselage.CFrame.UpVector
		assert(opticalAxis:Dot(desiredDirection) > 0.995,
			"The lens optical axis must point at the " .. label .. " target")
		local originOffset = laserOrigin.WorldPosition - fuselage.Position
		assert(originOffset.Magnitude > 0.1 and originOffset.Unit:Dot(opticalAxis) > 0.995,
			"The laser origin must remain on the lens optical axis for " .. label)
		local beamDirection = targetPosition - laserOrigin.WorldPosition
		assert(beamDirection.Magnitude > 0.1 and beamDirection.Unit:Dot(opticalAxis) > 0.995,
			"The emitted beam must travel toward the " .. label .. " target")

		assert(arena:ReturnAircraftLensHome(aimToken), "The aircraft should accept its return-home token")
		task.wait(0.45)
	end

	verifyAimDirection(15, 8, "right")
	verifyAimDirection(1, 8, "left")
	verifyAimDirection(8, 15, "front")
	verifyAimDirection(8, 1, "back")
	assert(bodyJoint.C0.RightVector:Dot(homeBodyC0.RightVector) > 0.999,
		"The complete aircraft should return to its home orientation after all cardinal aim tests")
	assert(arena.aircraftModel:FindFirstChild("PilotPlatform") == nil, "A visible pilot platform must not be built")
	assert(Lighting:FindFirstChild("SkyfallSunriseSky") == nil, "Custom skybox must be removed")
	assert(Lighting:FindFirstChild("SkyfallAtmosphere") == nil, "Custom Atmosphere must be removed")
	assert(Lighting:FindFirstChild("SkyfallColorCorrection") == nil, "Custom color correction must be removed")
	assert(Lighting:FindFirstChild("SkyfallBloom") == nil, "Custom Bloom must be removed")
	assert(Lighting:FindFirstChild("SkyfallSunRays") == nil, "Custom SunRays must be removed")
	assert(Workspace.Terrain:FindFirstChild("SkyfallClouds") == nil, "Custom clouds must be removed")
	assert(Workspace.StreamingEnabled == true, "Workspace streaming must be enabled")
	assert(Workspace.StreamingMinRadius == 64, "Streaming minimum radius should remain conservative")
	assert(Workspace.StreamingTargetRadius == 192, "Streaming target radius should be bounded for mobile")
	assert(Workspace.ModelStreamingBehavior == Enum.ModelStreamingBehavior.Improved, "Improved model streaming is required")
	assert(Workspace.StreamOutBehavior == Enum.StreamOutBehavior.Opportunistic, "Opportunistic stream out is required")
	assert(Workspace.StreamingIntegrityMode == Enum.StreamingIntegrityMode.PauseOutsideLoadedArea, "Streaming integrity protection is required")
	assert(Lighting.Brightness == 2, "Lighting brightness should be neutral")
	assert(Lighting.ClockTime == 14, "Lighting time should be the neutral daytime default")
	assert(Lighting.Ambient == Color3.fromRGB(0, 0, 0), "Ambient light should be neutral")
	assert(Lighting.OutdoorAmbient == Color3.fromRGB(0, 0, 0), "Outdoor ambient should be black for metallic environment reflections")
	assert(Lighting.ExposureCompensation == 0, "Exposure compensation should be neutral")
	assert(Lighting.EnvironmentDiffuseScale == 1 and Lighting.EnvironmentSpecularScale == 1, "PBR reflection and diffuse environment scales must be enabled")
	assert(arena.mapDecorBuilt == true, "The single map decoration should be built once")
	local separation = (Config.ARENA_CENTER - Config.LOBBY_CENTER).Magnitude
	assert(separation > Config.ARENA_HALF_WIDTH + Config.LOBBY_SIZE / 2 + 10, "Lobby must be physically separated from the arena")

	arena:CreateStrikeBeam(centerTile)
	local atmosphereGlow = arena.root:FindFirstChild("LaserAtmosphereGlow")
	local energyShell = arena.root:FindFirstChild("LaserEnergyShell")
	local hotCore = arena.root:FindFirstChild("LaserHotCore")
	local filament = arena.root:FindFirstChild("LaserFilament")
	local energyFlow = arena.root:FindFirstChild("LaserEnergyFlow")
	assert(atmosphereGlow and atmosphereGlow:IsA("Beam"), "The soft laser atmosphere pass is missing")
	assert(energyShell and energyShell:IsA("Beam"), "The main laser energy shell is missing")
	assert(hotCore and hotCore:IsA("Beam"), "The bright laser core is missing")
	assert(filament and filament:IsA("Beam"), "The fine laser filament is missing")
	assert(energyFlow and energyFlow:IsA("Beam"), "The animated energy texture pass is missing")
	assert(energyFlow.Texture == "rbxasset://textures/particles/sparkles_main.dds", "The laser must use the built-in moving beam texture")
	assert(energyFlow.TextureMode == Enum.TextureMode.Wrap and energyFlow.TextureSpeed < 0, "The energy texture must wrap and travel toward the target")
	assert(energyShell.Attachment0 == arena.laserOrigin, "The laser must originate from the golden fuselage")
	local impact = centerTile:FindFirstChild("LaserImpactAttachment")
	assert(impact and impact:FindFirstChild("LaserImpactParticles"), "The hit should use a short spark burst, not a solid impact disc")
	assert(impact:FindFirstChild("LaserImpactFlash"), "The hit should include a brief local light pulse")
	assert(centerTile:FindFirstChild("LaserImpactSound"), "A spatial laser impact sound should play")
	assert(arena.root:FindFirstChild("BlueLaserImpact") == nil, "Legacy blue impact discs must not be created")
	assert(arena.root:FindFirstChild("ImpactShockwave") == nil, "Legacy blue shockwave rings must not be created")

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
	assert(arena.mapFolder:FindFirstChild("ClassicPerimeterNorthSouth_-1"), "Classic arena perimeter frame is missing")
	assert(arena.mapFolder:FindFirstChild("ClassicArenaGate") == nil, "Separate gate pillars and red header should be removed")
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
		assert(tile:GetAttribute("IsWarning") == true, "A targeted tile must report its warning state")
		assert(arena:MarkTile(tile) == nil, "A tile already under warning must reject another strike")
		arena:BreakTile(tile, token)
		assert(tile:GetAttribute("IsBroken") == true, "Tile must be marked broken")
		assert(tile.CanCollide == false, "Broken tile must not collide")
		assert(tile.TopSurface == Enum.SurfaceType.Smooth, "Broken tile must hide native studs")
		assert(tile.BottomSurface == Enum.SurfaceType.Smooth, "Broken tile must hide native inlets")
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
	assert(tile.TopSurface == Enum.SurfaceType.Studs, "New round did not restore native Stud surfaces")
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

runTest("The active HUD count only includes living arena runners", function()
	local capturedState = nil
	local runnerA = {Parent = Players}
	local runnerB = {Parent = Players}
	local aliveBotCount = 3
	local harness = setmetatable({
		phase = "Active",
		roundHumanCount = 4,
		readyPlayers = {},
		elapsedSeconds = 75,
		countdownSeconds = 0,
		roundRunnerCount = 14,
		aliveRunners = {[runnerA] = true, [runnerB] = true},
		controller = nil,
		winner = "",
		roundNumber = 1,
		botService = {
			GetBotCount = function() return Config.BOT_COUNT end,
			GetAliveCount = function() return aliveBotCount end,
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
	assert(capturedState.playerCount == 5, "HUD must count only two living human runners and three living bots")
	assert(capturedState.eliminatedPlayers == 9, "Eliminated runner count should reflect the round roster")
	harness.aliveRunners[runnerB] = nil
	aliveBotCount = 2
	harness:_broadcast()
	assert(capturedState.playerCount == 3, "HUD count must drop immediately when a human and bot are eliminated")
end)

runTest("A fallen bot is removed before the round broadcasts its survivor count", function()
	local capturedState = nil
	local bot = {
		name = "FallenTestBot",
		alive = true,
		isController = false,
		humanoid = {Health = 100},
		root = {
			Parent = Workspace,
			Position = Vector3.new(0, -10, 0),
		},
		model = {
			Parent = Workspace,
			SetAttribute = function() end,
			PivotTo = function() end,
		},
	}
	local botHarness = setmetatable({
		bots = {bot},
		arena = arena,
		_playAnimation = function() end,
	}, BotService)
	local roundHarness = RoundService.new(arena, {
		FireAllClients = function(_, state)
			capturedState = state
		end,
	}, botHarness, nil)
	roundHarness.phase = "Active"
	roundHarness.roundRunners[bot] = {kind = "Bot", value = bot}
	roundHarness.roundRunnerCount = 1

	botHarness:EliminateFallenRunners(0)
	assert(bot.alive == false, "Fallen bot must be marked eliminated")
	assert(capturedState ~= nil, "Bot elimination should trigger an immediate round-state broadcast")
	assert(capturedState.playerCount == 0, "The eliminated bot must not remain in the active HUD count")
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

runTest("Placement uses the exact fresh character supplied by CharacterAdded", function()
	local function makeCharacter(name, position)
		local character = Instance.new("Model")
		character.Name = name
		local root = Instance.new("Part")
		root.Name = "HumanoidRootPart"
		root.Size = Vector3.new(2, 2, 1)
		root.Anchored = false
		root.Parent = character
		local humanoid = Instance.new("Humanoid")
		humanoid.Parent = character
		character.PrimaryPart = root
		character.Parent = Workspace
		character:PivotTo(CFrame.new(position))
		return character
	end
	local decoy = makeCharacter("OldCharacter", Vector3.new(40, 30, 40))
	local fresh = makeCharacter("FreshCharacter", Vector3.new(70, 30, 70))
	local fakePlayer = {
		Character = decoy,
		SetAttribute = function() end,
	}
	local harness = setmetatable({arena = arena}, RoundService)
	local destination = CFrame.new(-250, 20, 0)
	harness:_placePlayer(fakePlayer, destination, fresh)
	assert((fresh:GetPivot().Position - destination.Position).Magnitude < 0.1, "The new character must be placed at the supplied destination")
	assert((decoy:GetPivot().Position - Vector3.new(40, 30, 40)).Magnitude < 0.1, "A stale character must not be moved instead of the new one")
	decoy:Destroy()
	fresh:Destroy()
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

runTest("Previous human controller must press Play before being reused", function()
	local previousWinner = {
		Parent = Players,
	}
	local harness = setmetatable({
		phase = "Waiting",
		roundNumber = 2,
		nextController = {kind = "Player", value = previousWinner},
		readyPlayers = {},
		botService = {
			GetBots = function() return {} end,
		},
		random = Random.new(12345),
	}, RoundService)

	assert(harness:_chooseController() == nil, "An unready previous winner must not control a new round")
	assert(harness.nextController == nil, "The unready previous winner must be cleared")
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
