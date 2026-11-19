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
local WorldDesignProfile = require(sharedFolder:WaitForChild("WorldDesignProfile"))

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
local PilotPriorityService = requireService("PilotPriorityService")
local BubbleGunService = requireService("BubbleGunService")
local ServerStorage = game:GetService("ServerStorage")

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

local function makeFakePlayer(name, role)
	local fakeHumanoid = { Health = 100 }
	local fakeCharacter = { Humanoid = fakeHumanoid }
	function fakeCharacter:FindFirstChildOfClass(className)
		return className == "Humanoid" and self.Humanoid or nil
	end
	function fakeCharacter:FindFirstChild()
		return nil
	end
	local fakePlayer = {
		Name = name,
		DisplayName = name,
		Parent = Players,
		attributes = { SkyfallRole = role },
		Character = fakeCharacter,
	}
	function fakePlayer:SetAttribute(attributeName, value)
		self.attributes[attributeName] = value
		local signal = self.attributeSignals and self.attributeSignals[attributeName]
		if signal then
			signal:Fire()
		end
	end
	function fakePlayer:GetAttribute(attributeName)
		return self.attributes[attributeName]
	end
	function fakePlayer:GetAttributeChangedSignal(attributeName)
		self.attributeSignals = self.attributeSignals or {}
		if not self.attributeSignals[attributeName] then
			self.attributeSignals[attributeName] = Instance.new("BindableEvent")
		end
		return self.attributeSignals[attributeName].Event
	end
	return fakePlayer
end

runTest("Arena builds the 15x15 Sky Garden in a one-map 30-player experience", function()
	assert(Config.GRID_SIZE == 15, "Expected a 15x15 tile grid")
	assert(Config.MAX_PLAYER_CAPACITY == 30, "Expected capacity for 30 human players")
	assert(Config.MAP_COUNT == 1, "The experience must contain exactly one playable map")
	assert(Config.MAP_NAMES[1] == "SKYFALL SKY GARDEN ARENA", "Map 1 must remain the Classic arena")
	assert(Config.MAP_NAMES[2] == nil, "A second playable map must not be configured")
	assert(Config.BOT_COUNT == 10, "Exactly ten AI bots must be configured")
	assert(Config.TILE_GAP == 0, "Destructible floor tiles must have no designed gap")
	assert(Config.ROUND_SECONDS == 180, "Each round must last three minutes")
	assert(Config.HUMAN_STRIKE_COOLDOWN_SECONDS == 3, "Human laser cooldown must be three seconds")
	assert(Config.CONTROLLER_CAMERA_FOV == 70, "Controller camera should use a wide overhead field of view")
	assert(Config.CONTROLLER_CAMERA_MARGIN == 8, "Controller camera should retain a small margin around the full arena")
	assert(Config.LOBBY_SIZE == 120, "Waiting lobby must use the compact 120-stud platform")
	assert(Config.LOBBY_SPAWN_RADIUS == 42, "Human spawn ring must be resized for the compact lobby")
	assert(Config.LOBBY_BOT_SPAWN_RADIUS == 52, "Ten-bot spawn ring must remain inside the compact lobby")

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
	assert(lobbyPlatform.Size == Vector3.new(120, 3, 120), "Waiting platform must be resized to 120 by 120 studs")
	assert(lobbyPlatform.TopSurface == Enum.SurfaceType.Studs, "Lobby baseplate must use native Classic Studs")
	assert(
		Players.CharacterAutoLoads == false,
		"Automatic character spawning must be disabled until server lobby routing is ready"
	)
	assert(
		Config.LOBBY_CENTER.Y - Config.ARENA_CENTER.Y >= 48,
		"The observation deck must be elevated at least 48 studs above the arena"
	)
	assert(
		lobbyPlatform.Position.Y - arena:GetTile(8, 8).Position.Y >= 48,
		"The waiting platform must be clearly above the arena floor"
	)
	local lobbySpawn = arena:GetLobbySpawnCFrame(1, 1, false)
	local horizontalViewTarget = Vector3.new(Config.ARENA_CENTER.X, lobbySpawn.Position.Y, Config.ARENA_CENTER.Z)
	local viewDirection = (horizontalViewTarget - lobbySpawn.Position).Unit
	assert(
		lobbySpawn.LookVector:Dot(viewDirection) > 0.99,
		"Lobby spawns must face toward the arena without tilting avatars"
	)
	assert(
		arena:GetStreamingFocusPart() == arena:GetTile(8, 8),
		"The arena streaming focus must stay at the center tile"
	)
	assert(arena.lobbyFolder:FindFirstChild("LobbyWater") == nil, "Lobby water surface must be removed")
	assert(arena.lobbyFolder:FindFirstChild("LobbyWelcomeSign") == nil, "Floating lobby welcome board must be removed")
	for _, descendant in ipairs(arena.lobbyFolder:GetDescendants()) do
		local name = string.lower(descendant.Name)
		assert(not string.find(name, "tree"), "All trees must be removed")
		assert(not string.find(name, "bench") and not string.find(name, "chair"), "All seating must be removed")
		assert(
			descendant:IsA("BasePart") == false or descendant.Material ~= Enum.Material.Water,
			"Water surfaces must be removed"
		)
	end
	local natureFolder = arena.mapFolder:FindFirstChild("SkyfallNatureSanctuary")
	assert(natureFolder, "The organic Classic nature sanctuary must be built")
	assert(natureFolder:GetAttribute("SkyfallMapIdentity") == "SkyGarden", "Sky Garden geometry must declare its map identity")
	assert(natureFolder:FindFirstChild("SkyGardenRootArch_01", true), "The natural root arch is missing")
	assert(natureFolder:FindFirstChild("SkyGardenTreeTrunk_01", true), "The first Sky Garden tree trunk is missing")
	assert(natureFolder:FindFirstChild("SkyGardenCanopy_01_1", true), "Layered tree canopies are missing")
	assert(natureFolder:FindFirstChild("SkyGardenFloatingIslet_01", true), "The floating natural islets are missing")
	assert(natureFolder:FindFirstChild("SkyGardenVine_01", true), "Hanging vines are missing")
	assert(natureFolder:GetAttribute("SkyfallGeometryPartCount") <= 55, "Sky Garden geometry exceeded its measured mobile part budget")
	assert(arena.currentMapId == 1, "The only configured map must remain active")
	assert(
		arena.aircraftModel and arena.aircraftModel:FindFirstChild("AircraftFuselage"),
		"Golden controller sphere is missing"
	)
	assert(arena.aircraftModel:FindFirstChild("ControllerLens"), "Red controller lens is missing")
	for index = 1, 5 do
		assert(
			arena.aircraftModel:FindFirstChild("ArmorPlate_Upper_" .. tostring(index)),
			"Upper sphere armor plate is missing"
		)
	end
	for index = 1, 4 do
		assert(
			arena.aircraftModel:FindFirstChild("ArmorPlate_Lower_" .. tostring(index)),
			"Lower sphere armor plate is missing"
		)
	end
	assert(arena.aircraftModel:FindFirstChild("LensReticleRing_Outer_1"), "Outer lens reticle ring is missing")
	assert(arena.aircraftModel:FindFirstChild("LensReticleRing_Inner_1"), "Inner lens reticle ring is missing")
	local lensLight = arena.aircraftModel.ControllerLens:FindFirstChildOfClass("PointLight")
	assert(not lensLight or lensLight.Range <= 5, "Red lens light must remain tightly contained")
	assert(arena.mapFolder:FindFirstChild("ClassicArenaNameSign") == nil, "Old floating arena sign should not remain")
	assert(
		arena.mapFolder:FindFirstChild("LobbyToArenaWalkway") == nil,
		"The waiting garden must stay separate from the arena"
	)
	local aircraftAnchor = arena.aircraftModel:FindFirstChild("AircraftMotionAnchor")
	local fuselage = arena.aircraftModel:FindFirstChild("AircraftFuselage")
	assert(aircraftAnchor and fuselage, "Unified aircraft root and fuselage are required")
	local bodyJoint = aircraftAnchor:FindFirstChild("AircraftBodyJoint")
	assert(bodyJoint and bodyJoint:IsA("Motor6D"), "The complete aircraft must use one body motion joint")
	assert(
		bodyJoint.Part0 == aircraftAnchor and bodyJoint.Part1 == fuselage,
		"The motion joint must connect the hidden anchor to the fuselage"
	)
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
	assert(
		laserOrigin and laserOrigin.Parent == fuselage,
		"Laser origin must be attached directly to the unified fuselage"
	)
	assert(
		arena.aircraftModel:FindFirstChild("ControllerLensGimbal", true) == nil,
		"An independently moving lens gimbal must not remain"
	)
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
		assert(
			opticalAxis:Dot(desiredDirection) > 0.995,
			"The lens optical axis must point at the " .. label .. " target"
		)
		local originOffset = laserOrigin.WorldPosition - fuselage.Position
		assert(
			originOffset.Magnitude > 0.1 and originOffset.Unit:Dot(opticalAxis) > 0.995,
			"The laser origin must remain on the lens optical axis for " .. label
		)
		local beamDirection = targetPosition - laserOrigin.WorldPosition
		assert(
			beamDirection.Magnitude > 0.1 and beamDirection.Unit:Dot(opticalAxis) > 0.995,
			"The emitted beam must travel toward the " .. label .. " target"
		)

		assert(arena:ReturnAircraftLensHome(aimToken), "The aircraft should accept its return-home token")
		task.wait(0.45)
	end

	verifyAimDirection(15, 8, "right")
	verifyAimDirection(1, 8, "left")
	verifyAimDirection(8, 15, "front")
	verifyAimDirection(8, 1, "back")
	assert(
		bodyJoint.C0.RightVector:Dot(homeBodyC0.RightVector) > 0.999
			and bodyJoint.C0.UpVector:Dot(homeBodyC0.UpVector) > 0.999
			and bodyJoint.C0.LookVector:Dot(homeBodyC0.LookVector) > 0.999,
		"The complete aircraft should return to its home orientation after all cardinal aim tests"
	)
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
	assert(
		Workspace.ModelStreamingBehavior == Enum.ModelStreamingBehavior.Improved,
		"Improved model streaming is required"
	)
	assert(Workspace.StreamOutBehavior == Enum.StreamOutBehavior.Opportunistic, "Opportunistic stream out is required")
	assert(
		Workspace.StreamingIntegrityMode == Enum.StreamingIntegrityMode.PauseOutsideLoadedArea,
		"Streaming integrity protection is required"
	)
	assert(Lighting.Brightness == 2, "Lighting brightness should be neutral")
	assert(Lighting.ClockTime == 14, "Lighting time should be the neutral daytime default")
	assert(Lighting.Ambient == Color3.fromRGB(0, 0, 0), "Ambient light should be neutral")
	assert(
		Lighting.OutdoorAmbient == Color3.fromRGB(0, 0, 0),
		"Outdoor ambient should be black for metallic environment reflections"
	)
	assert(Lighting.ExposureCompensation == 0, "Exposure compensation should be neutral")
	assert(
		Lighting.EnvironmentDiffuseScale == 1 and Lighting.EnvironmentSpecularScale == 1,
		"PBR reflection and diffuse environment scales must be enabled"
	)
	assert(arena.mapDecorBuilt == true, "The single map decoration should be built once")
	local separation = (Config.ARENA_CENTER - Config.LOBBY_CENTER).Magnitude
	assert(
		separation > Config.ARENA_HALF_WIDTH + Config.LOBBY_SIZE / 2 + 10,
		"Lobby must be physically separated from the arena"
	)

	assert(arena:CreateStrikeBeam(centerTile), "The procedural laser VFX should accept a valid target")
	task.wait(Config.LASER_EXTENSION_SECONDS + 0.06)
	local vfxFolder
	for _, child in ipairs(arena.root:GetChildren()) do
		if string.sub(child.Name, 1, 13) == "LaserVFXShot_" then
			vfxFolder = child
			break
		end
	end
	assert(vfxFolder, "A short-lived laser VFX container must be created")
	assert(
		vfxFolder:GetAttribute("VisualLayerCount") == Config.LASER_LAYER_COUNT,
		"The visual stack must declare 24 layers"
	)
	assert(vfxFolder:GetAttribute("BeamLayerCount") == 14, "The beam stack must contain fourteen passes")
	assert(vfxFolder:GetAttribute("ParticleLayerCount") == 4, "The effect must contain four manual particle emitters")
	assert(vfxFolder:GetAttribute("LightLayerCount") == 2, "The effect must contain two temporary lights")
	assert(vfxFolder:GetAttribute("PulseLayerCount") == 4, "The effect must contain four pulse spheres")

	local beamCount = 0
	local particleCount = 0
	local pulseCount = 0
	local forwardTextureCount = 0
	for _, descendant in ipairs(vfxFolder:GetDescendants()) do
		if descendant:IsA("Beam") then
			beamCount += 1
			assert(
				descendant.Attachment0 == arena.laserOrigin,
				"Each laser pass must originate from the drone optical axis"
			)
			assert(descendant.Attachment1 ~= nil, "Each laser pass must have an animated endpoint attachment")
			if descendant.Texture ~= "" then
				assert(
					descendant.Texture == "rbxasset://textures/particles/sparkles_main.dds",
					"Only the Roblox built-in beam texture should be used"
				)
				assert(
					descendant.TextureMode == Enum.TextureMode.Wrap and descendant.TextureSpeed > 0,
					"Energy texture must travel from source to target"
				)
				forwardTextureCount += 1
			end
		elseif descendant:IsA("ParticleEmitter") then
			particleCount += 1
			assert(
				descendant.Rate == 0 and descendant.Enabled == false,
				"Particles must be burst-only, never continuously emitted"
			)
		elseif descendant:IsA("BasePart") and string.sub(descendant.Name, 1, 11) == "LaserPulse_" then
			pulseCount += 1
			assert(
				descendant.CanCollide == false and descendant.CanTouch == false and descendant.CanQuery == false,
				"Pulse geometry must not affect gameplay"
			)
		end
	end
	assert(beamCount == 14, "Expected exactly fourteen Beam passes, got " .. tostring(beamCount))
	assert(particleCount == 4, "Expected exactly four controlled particle emitters, got " .. tostring(particleCount))
	assert(pulseCount == 4, "Expected exactly four visual pulse spheres, got " .. tostring(pulseCount))
	assert(forwardTextureCount == 2, "Two animated energy-flow passes should be present")

	local endpoint = vfxFolder:FindFirstChild("LaserBeamEndpoint")
	assert(endpoint and endpoint:IsA("BasePart"), "The moving beam endpoint is missing")
	assert(
		endpoint:GetAttribute("ExtensionDuration") == Config.LASER_EXTENSION_SECONDS,
		"Beam extension must use the configured smooth duration"
	)
	assert(
		endpoint:GetAttribute("StartPosition") ~= nil and endpoint:GetAttribute("TargetPosition") ~= nil,
		"The endpoint must store its source and destination for verification"
	)
	local muzzle = arena.aircraftModel:FindFirstChild("LaserMuzzleAttachment", true)
	local impact = centerTile:FindFirstChild("LaserImpactAttachment")
	assert(muzzle and impact, "Muzzle and impact attachments must be created")
	local muzzleEmitters = 0
	for _, child in ipairs(muzzle:GetChildren()) do
		if child:IsA("ParticleEmitter") then
			muzzleEmitters += 1
		end
	end
	assert(muzzleEmitters == 2, "The muzzle must contain two one-shot particle emitters")
	assert(impact:FindFirstChild("LaserParticles_ImpactSparks"), "Impact spark burst is missing")
	assert(impact:FindFirstChild("LaserParticles_ImpactFragments"), "Impact fragment burst is missing")
	assert(impact:FindFirstChild("LaserImpactLight"), "The impact needs a short local light pulse")
	assert(muzzle:FindFirstChild("LaserMuzzleLight"), "The muzzle needs a short charge flash")
	assert(centerTile:FindFirstChild("LaserImpactSound"), "A spatial laser impact sound should play")
	assert(arena.root:FindFirstChild("BlueLaserImpact") == nil, "Legacy blue impact discs must not be created")
	assert(arena.root:FindFirstChild("ImpactShockwave") == nil, "Legacy blue shockwave rings must not be created")

	for index = 1, Config.MAX_PLAYER_CAPACITY do
		local lobbyPosition = arena:GetLobbySpawnCFrame(index, Config.MAX_PLAYER_CAPACITY, false).Position
		assert(
			(lobbyPosition - Config.LOBBY_CENTER).Magnitude <= Config.LOBBY_SPAWN_RADIUS + 0.01,
			"All human spawn points must use the resized human spawn ring"
		)
		local runnerPosition = arena:GetRunnerSpawnCFrame(index, Config.MAX_PLAYER_CAPACITY).Position
		assert(
			math.abs(runnerPosition.X - Config.ARENA_CENTER.X) < Config.ARENA_HALF_WIDTH,
			"Runner spawn is outside the arena"
		)
		assert(
			math.abs(runnerPosition.Z - Config.ARENA_CENTER.Z) < Config.ARENA_HALF_WIDTH,
			"Runner spawn is outside the arena"
		)

		lobbyPosition = arena:GetLobbySpawnCFrame(index, Config.MAX_PLAYER_CAPACITY, false).Position
		assert(
			math.abs(lobbyPosition.X - Config.LOBBY_CENTER.X) < Config.LOBBY_SIZE / 2,
			"Lobby spawn is outside the waiting platform"
		)
		assert(
			math.abs(lobbyPosition.Z - Config.LOBBY_CENTER.Z) < Config.LOBBY_SIZE / 2,
			"Lobby spawn is outside the waiting platform"
		)
	end

	for index = 1, Config.BOT_COUNT do
		local botPosition = arena:GetLobbySpawnCFrame(index, Config.BOT_COUNT, true).Position
		assert(
			(botPosition - Config.LOBBY_CENTER).Magnitude <= Config.LOBBY_BOT_SPAWN_RADIUS + 0.01,
			"All ten bot spawn points must use the resized bot spawn ring"
		)
		assert(
			math.abs(botPosition.X - Config.LOBBY_CENTER.X) <= lobbyPlatform.Size.X / 2
				and math.abs(botPosition.Z - Config.LOBBY_CENTER.Z) <= lobbyPlatform.Size.Z / 2,
			"Every bot spawn must remain within the compact waiting platform"
		)
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

runTest("The Sky Garden arena uses the lobby finish and connected stud geometry", function()
	assert(arena ~= nil, "Arena setup did not complete")
	assert(Config.MAP_COUNT == 1, "The experience must contain exactly one Sky Garden map")
	assert(arena:SetMap(1) == "SKYFALL SKY GARDEN ARENA", "Map 1 should remain Classic Arena")
	assert(arena:GetMapName() == "SKYFALL SKY GARDEN ARENA", "Active map name is incorrect")
	assert(arena:GetTile(8, 8).Material == Enum.Material.Plastic, "Destructible floor must use classic Plastic")
	local leftTile = arena:GetTile(8, 8)
	local rightTile = arena:GetTile(9, 8)
	assert(
		math.abs((rightTile.Position.X - leftTile.Position.X) - Config.TILE_SIZE) < 0.001,
		"Neighboring floor tiles must touch with no gap"
	)
	assert(math.abs(leftTile.Size.X - Config.TILE_SIZE) < 0.001, "Tile width must match its grid spacing")
	assert(Lighting.ClockTime >= 10 and Lighting.ClockTime <= 16, "Map lighting is not daytime")
	assert(Lighting:FindFirstChild("SkyfallSunriseSky") == nil, "No custom Sky instance should be retained")
	local natureFolder = arena.mapFolder:FindFirstChild("SkyfallNatureSanctuary")
	assert(natureFolder, "Classic nature sanctuary folder is missing")
	assert(natureFolder:GetAttribute("SkyfallGeometrySignature") == "sky-garden-organic-floating-sanctuary-v1",
		"Sky Garden must retain its organic geometry signature")
	assert(natureFolder:FindFirstChild("SkyGardenFloatingIslet_02", true), "Second floating islet is missing")
	assert(natureFolder:FindFirstChild("SkyGardenRootArch_04", true), "Curved root-arch segments are missing")
	assert(arena.currentMapId == 1, "The only configured map must remain active")
	assert(arena:GetTile(8, 8).TopSurface == arena.lobbyFloor.TopSurface, "Classic tiles must use the lobby top surface")
	assert(arena:GetTile(8, 8).BottomSurface == arena.lobbyFloor.BottomSurface, "Classic tiles must use the lobby bottom surface")
	assert(arena.mapFolder:GetAttribute("SkyfallAuditedSurfaceCount") > 0, "Classic map surface audit must run")

	for _, descendant in ipairs(arena.decorFolder:GetDescendants()) do
		if descendant:IsA("BasePart") then
			assert(
				descendant.Material ~= Enum.Material.Neon,
				"Neon material remains in map: " .. descendant:GetFullName()
			)
			assert(not string.find(descendant.Name, "RingSegment"), "Segmented ring barrier remains in the map")
			assert(not string.find(descendant.Name, "ReactorRing"), "Circular reactor barrier remains in the map")
		end
	end

	assert(arena.mapFolder:FindFirstChild("CloudspireSkyPalace") == nil, "Old Cloudspire map remains")
	assert(arena.mapFolder:FindFirstChild("GoldenDunesTemple") == nil, "Old Golden Dunes map remains")
	assert(arena.mapFolder:FindFirstChild("EmeraldGroveSanctuary") == nil, "Old Emerald Grove map remains")
	assert(arena.mapFolder:FindFirstChild("AzureHarborFortress") == nil, "Old Azure Harbor map remains")
end)

runTest("Broken tiles remain broken until round-end cleanup", function()
	assert(arena ~= nil, "Arena setup did not complete")

	local targets = {
		{ 8, 8 },
		{ 7, 8 },
		{ 8, 7 },
		{ 9, 8 },
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

	assert(
		#arena:GetSafeTiles() == Config.GRID_SIZE * Config.GRID_SIZE - 4,
		"Four broken tiles should be excluded from safe tiles"
	)
	task.wait(2.2)

	for _, coordinates in ipairs(targets) do
		local tile = arena:GetTile(coordinates[1], coordinates[2])
		assert(tile:GetAttribute("IsBroken") == true, "A broken tile repaired itself before round-end cleanup")
		assert(tile.CanCollide == false, "A broken tile regained collision before round-end cleanup")
	end
end)

runTest("Round-end cleanup instantly restores every destructible tile", function()
	assert(arena ~= nil, "Arena setup did not complete")
	local targets = { { 8, 8 }, { 7, 8 }, { 8, 7 }, { 9, 8 } }
	local staleTokens = {}

	for _, coordinates in ipairs(targets) do
		local tile = arena:GetTile(coordinates[1], coordinates[2])
		local token = arena:MarkTile(tile)
		assert(token ~= nil, "A clean tile should accept a test warning")
		arena:BreakTile(tile, token)
		assert(tile:GetAttribute("IsBroken") == true, "The test tile should be broken before cleanup")
		staleTokens[tile] = token
	end

	local harness = setmetatable({ arena = arena }, RoundService)
	harness:_resetArenaAfterRound()

	assert(
		#arena:GetSafeTiles() == Config.GRID_SIZE * Config.GRID_SIZE,
		"Round-end cleanup must restore the complete 15x15 floor"
	)
	for tile, staleToken in pairs(staleTokens) do
		assert(tile:GetAttribute("IsBroken") == false, "Round-end cleanup must clear IsBroken")
		assert(tile:GetAttribute("IsWarning") == false, "Round-end cleanup must clear warning state")
		assert(tile.CanCollide == true, "Round-end cleanup must restore floor collision")
		assert(tile.Transparency == 0, "Round-end cleanup must restore tile visibility")
		assert(tile.Color == arena.theme.tileColor, "Round-end cleanup must restore the map tile color")
		assert(tile.Material == arena.theme.tileMaterial, "Round-end cleanup must restore the map material")
		assert(tile.TopSurface == Enum.SurfaceType.Studs, "Round-end cleanup must restore native studs")
		assert(tile.BottomSurface == Enum.SurfaceType.Inlet, "Round-end cleanup must restore native inlets")
		arena:BreakTile(tile, staleToken)
		assert(tile:GetAttribute("IsBroken") == false, "A stale shot must not re-break a tile after round reset")
		assert(
			tile:FindFirstChild("LaserImpactAttachment") == nil,
			"Round-end cleanup must remove lingering impact particles"
		)
		assert(tile:FindFirstChild("LaserImpactSound") == nil, "Round-end cleanup must remove lingering impact sound")
	end

	for _, child in ipairs(arena.root:GetChildren()) do
		assert(
			string.sub(child.Name, 1, 13) ~= "LaserVFXShot_",
			"Round-end cleanup must remove active laser beam containers"
		)
	end
end)

runTest("The single Sky Garden map uses the exact WaitingPlatform surface finish", function()
	assert(arena ~= nil, "Arena setup did not complete")
	assert(Config.MAP_COUNT == 1, "The experience must contain exactly one playable map")
	assert(Config.ACTIVE_MAP_ID == 1, "Sky Garden must be the fixed active map")
	assert(Config.MAP_NAMES[1] == "SKYFALL SKY GARDEN ARENA", "The sole map name must be Sky Garden")
	assert(Config.MAP_NAMES[2] == nil, "A second playable map must not be configured")
	assert(#arena.tilesFolder:GetChildren() == 225, "The single map must retain all 225 destructible tiles")
	local lobbyPlatform = arena.lobbyFolder:FindFirstChild("WaitingPlatform")
	assert(lobbyPlatform, "The lobby surface profile source is missing")

	local function auditFinish(root, label)
		local count = 0
		for _, part in ipairs(root:GetDescendants()) do
			if part:IsA("BasePart") then
				count += 1
				assert(part.Material == lobbyPlatform.Material, label .. " Material mismatch: " .. part.Name)
				assert(part.MaterialVariant == lobbyPlatform.MaterialVariant, label .. " MaterialVariant mismatch: " .. part.Name)
				assert(part.Reflectance == lobbyPlatform.Reflectance, label .. " Reflectance mismatch: " .. part.Name)
				assert(part.TopSurface == lobbyPlatform.TopSurface, label .. " TopSurface mismatch: " .. part.Name)
				assert(part.BottomSurface == lobbyPlatform.BottomSurface, label .. " BottomSurface mismatch: " .. part.Name)
			end
		end
		return count
	end

	assert(arena:SetMap(1) == "SKYFALL SKY GARDEN ARENA", "Sky Garden selection failed")
	local garden = arena.mapFolder:FindFirstChild("SkyfallNatureSanctuary")
	assert(garden, "Sky Garden builder did not produce its nature sanctuary")
	assert(garden:GetAttribute("SkyfallMapIdentity") == "SkyGarden", "Sky Garden identity attribute is missing")
	assert(garden:GetAttribute("SkyfallGeometrySignature") == "sky-garden-organic-floating-sanctuary-v1", "Sky Garden signature is missing")
	assert(garden:FindFirstChild("SkyGardenRootArch_01", true), "Sky Garden root arch is missing")
	assert(garden:FindFirstChild("SkyGardenTreeTrunk_01", true), "Sky Garden tree trunk is missing")
	assert(garden:FindFirstChild("SkyGardenCanopy_01_1", true), "Layered Sky Garden canopy is missing")
	assert(garden:FindFirstChild("SkyGardenFloatingIslet_01", true), "Sky Garden islet is missing")
	assert(garden:FindFirstChild("SkyGardenVine_01", true), "Sky Garden vine is missing")

	local mapPartCount = auditFinish(garden, "Sky Garden")
	assert(mapPartCount == garden:GetAttribute("SkyfallGeometryPartCount"), "Map geometry audit count must match generated parts")
	assert(mapPartCount <= 55, "Sky Garden exceeded its 55-part mobile budget")
	assert(arena.mapFolder:GetAttribute("SkyfallAuditedSurfaceCount") >= mapPartCount, "Map finish audit did not cover every generated part")
	assert(#arena.tilesFolder:GetChildren() == 225, "All 225 destructible tiles must remain")
	for _, tile in pairs(arena.tiles) do
		assert(tile.Material == lobbyPlatform.Material and tile.MaterialVariant == lobbyPlatform.MaterialVariant,
			"Every gameplay tile must share the WaitingPlatform material finish")
		assert(tile.Reflectance == lobbyPlatform.Reflectance and tile.TopSurface == lobbyPlatform.TopSurface
			and tile.BottomSurface == lobbyPlatform.BottomSurface, "Every gameplay tile must share the WaitingPlatform surface properties")
	end

	local expectedColor = Color3.fromRGB(
		WorldDesignProfile.SkyGarden.PrimaryTile[1],
		WorldDesignProfile.SkyGarden.PrimaryTile[2],
		WorldDesignProfile.SkyGarden.PrimaryTile[3]
	)
	assert(arena:GetTile(8, 8).Color == expectedColor, "Sky Garden must keep its own green palette")
	assert(arena:GetTile(8, 8).Color ~= lobbyPlatform.Color, "The map palette must not copy the lobby baseplate Color")
	for _, part in ipairs(garden:GetDescendants()) do
		if part:IsA("BasePart") then
			assert(part.Anchored and not part.CanCollide and not part.CanTouch and not part.CanQuery,
				"Sky Garden decoration must be static and gameplay-inert: " .. part.Name)
			assert(part.Material ~= Enum.Material.Neon, "Map geometry must use the lobby finish, not Neon BaseParts")
		end
	end

	local before = #arena.mapFolder:GetDescendants()
	assert(arena:SetMap(1) == "SKYFALL SKY GARDEN ARENA", "Repeated single-map build failed")
	local rebuilt = arena.mapFolder:FindFirstChild("SkyfallNatureSanctuary")
	assert(rebuilt and rebuilt:GetAttribute("SkyfallGeometryPartCount") == mapPartCount, "Repeated build geometry count changed")
	assert(#arena.mapFolder:GetDescendants() == before, "Repeated build must not accumulate geometry or effects")
	assert(arena:SetMap(2) == "SKYFALL SKY GARDEN ARENA", "Unsupported map IDs must fall back to Sky Garden")
	assert(arena.currentMapId == 1, "Unsupported IDs must not select a second playable map")
	assert(arena:SetMap(999) == "SKYFALL SKY GARDEN ARENA", "Invalid IDs must fall back to Sky Garden")
	assert(arena.currentMapId == 1, "Invalid IDs must not corrupt map identity")
end)

runTest("The active HUD count only includes living arena runners", function()
	local capturedState = nil
	local runnerA = { Parent = Players }
	local runnerB = { Parent = Players }
	local aliveBotCount = 3
	local harness = setmetatable({
		phase = "Active",
		roundHumanCount = 4,
		readyPlayers = {},
		elapsedSeconds = 75,
		countdownSeconds = 0,
		roundRunnerCount = 14,
		aliveRunners = { [runnerA] = true, [runnerB] = true },
		controller = nil,
		winner = "",
		roundNumber = 1,
		botService = {
			GetBotCount = function()
				return Config.BOT_COUNT
			end,
			GetAliveCount = function()
				return aliveBotCount
			end,
		},
		arena = {
			GetMapName = function()
				return "SKYFALL SKY GARDEN ARENA"
			end,
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
		humanoid = { Health = 100 },
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
		bots = { bot },
		arena = arena,
		_playAnimation = function() end,
	}, BotService)
	local roundHarness = RoundService.new(arena, {
		FireAllClients = function(_, state)
			capturedState = state
		end,
	}, botHarness, nil)
	roundHarness.phase = "Active"
	roundHarness.roundRunners[bot] = { kind = "Bot", value = bot }
	roundHarness.roundRunnerCount = 1

	botHarness:EliminateFallenRunners(0)
	assert(bot.alive == false, "Fallen bot must be marked eliminated")
	assert(capturedState ~= nil, "Bot elimination should trigger an immediate round-state broadcast")
	assert(capturedState.playerCount == 0, "The eliminated bot must not remain in the active HUD count")
end)

runTest("Controller drone and arena remain free of neon materials", function()
	assert(arena ~= nil, "Arena setup did not complete")
	for _, root in ipairs({ arena.tilesFolder, arena.decorFolder }) do
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
	local harness = setmetatable({ arena = arena }, RoundService)
	local destination = CFrame.new(-250, 20, 0)
	harness:_placePlayer(fakePlayer, destination, fresh)
	assert(
		(fresh:GetPivot().Position - destination.Position).Magnitude < 0.1,
		"The new character must be placed at the supplied destination"
	)
	assert(
		(decoy:GetPivot().Position - Vector3.new(40, 30, 40)).Magnitude < 0.1,
		"A stale character must not be moved instead of the new one"
	)
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
		arena = {
			GetMapName = function()
				return "SKYFALL SKY GARDEN ARENA"
			end,
		},
		stateRemote = { FireAllClients = function() end },
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

runTest("Lobby streaming focus is added and removed once without changing global radius", function()
	local focusPart = arena:GetStreamingFocusPart()
	local addCount = 0
	local removeCount = 0
	local fakePlayer = { Name = "StreamingFocusTest" }
	function fakePlayer:AddReplicationFocus(part)
		assert(part == focusPart, "Waiting player must stream around the center arena tile")
		addCount += 1
	end
	function fakePlayer:RemoveReplicationFocus(part)
		assert(part == focusPart, "The same arena focus must be removed")
		removeCount += 1
	end

	local harness = setmetatable({
		arena = arena,
		arenaStreamingFocusPlayers = {},
	}, RoundService)
	assert(harness:_setArenaStreamingFocus(fakePlayer, true), "Waiting player should receive an arena streaming focus")
	assert(harness:_setArenaStreamingFocus(fakePlayer, true), "Repeated lobby focus requests should be safe")
	assert(addCount == 1, "The same player must not receive duplicate arena streaming foci")
	assert(harness:_setArenaStreamingFocus(fakePlayer, false), "Arena focus should be removable")
	assert(removeCount == 1, "Arena focus should be removed exactly once")
	assert(
		Workspace.StreamingTargetRadius == 192,
		"Observation support must preserve the bounded mobile streaming radius"
	)
end)

runTest("Late joiners during an active round are routed to the observation lobby", function()
	local character = Instance.new("Model")
	character.Name = "LateJoinTestCharacter"
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(2, 2, 1)
	root.Parent = character
	local humanoid = Instance.new("Humanoid")
	humanoid.Parent = character
	character.PrimaryPart = root
	character:PivotTo(CFrame.new(0, 30, 0))

	local fakePlayer = {
		Name = "LateJoinTest",
		Parent = Players,
		Character = character,
		attributes = {},
		ReplicationFocus = nil,
	}
	function fakePlayer:SetAttribute(name, value)
		self.attributes[name] = value
	end
	function fakePlayer:AddReplicationFocus(part)
		self.arenaStreamingFocus = part
	end
	function fakePlayer:RemoveReplicationFocus(part)
		if self.arenaStreamingFocus == part then
			self.arenaStreamingFocus = nil
		end
	end

	local harness = setmetatable({
		arena = arena,
		phase = "Active",
		controller = nil,
		aliveRunners = {},
		characterSerial = {},
		arenaStreamingFocusPlayers = {},
	}, RoundService)

	local expectedLobbySpawn = arena:GetLobbySpawnCFrame(1, 1, false)
	local placementFinished = false
	task.spawn(function()
		harness:_onCharacterAdded(fakePlayer, character)
		placementFinished = true
	end)
	task.wait(0.05)
	assert(character.Parent == nil, "CharacterAdded test must cover the engine's pre-Workspace stage")
	character.Parent = Workspace
	for _ = 1, 20 do
		if placementFinished then
			break
		end
		task.wait(0.05)
	end
	assert(placementFinished, "Character placement must finish after the model enters Workspace")
	assert(
		fakePlayer.attributes.SkyfallRole == "Spectator",
		"A late joiner must not become a runner during an active round"
	)
	assert(
		(character:GetPivot().Position - expectedLobbySpawn.Position).Magnitude < 0.1,
		"A late joiner must be placed on the lobby deck"
	)
	assert(
		fakePlayer.arenaStreamingFocus == arena:GetStreamingFocusPart(),
		"A lobby spectator must stream the live arena"
	)

	harness:_setArenaStreamingFocus(fakePlayer, false)
	fakePlayer.Parent = nil
	character:Destroy()
end)

runTest("Creator flight authorization only grants the personal experience owner", function()
	assert(
		AdminFlightService.IsAuthorizedUserId(12345, Enum.CreatorType.User, 12345),
		"Personal creator should be authorized"
	)
	assert(
		not AdminFlightService.IsAuthorizedUserId(54321, Enum.CreatorType.User, 12345),
		"A different user must not be authorized"
	)
	assert(
		not AdminFlightService.IsAuthorizedUserId(12345, Enum.CreatorType.Group, 12345),
		"Group-owned experiences must not implicitly authorize a group member"
	)
end)

runTest("Pilot Priority selects only manually opted-in humans and prevents a legacy controller override", function()
	local lowPriority = makeFakePlayer("LowPriority", "Runner")
	local highPriority = makeFakePlayer("HighPriority", "Runner")
	lowPriority:SetAttribute("SkyfallPilotOptIn", true)
	highPriority:SetAttribute("SkyfallPilotOptIn", true)
	local bot = {
		name = "LegacyNextBot",
		model = { Parent = Workspace },
		humanoid = { Health = 100 },
		alive = true,
	}
	local priority = PilotPriorityService.new(Random.new(101))
	priority:Initialize(lowPriority)
	priority:Initialize(highPriority)
	priority.scores[lowPriority] = 12
	priority.scores[highPriority] = 68

	local harness = setmetatable({
		roundNumber = 2,
		readyPlayers = { [lowPriority] = true, [highPriority] = true },
		pilotPriority = priority,
		botService = {
			GetBots = function()
				return { bot }
			end,
		},
		random = Random.new(12345),
		nextController = { kind = "Bot", value = bot },
	}, RoundService)

	local selected = harness:_chooseController({ lowPriority, highPriority })
	assert(
		selected and selected.kind == "Player" and selected.value == highPriority,
		"Highest-priority ready human must override the legacy nextController value"
	)
	assert(priority:GetScore(highPriority) == 0, "Selected human priority must reset to zero")

	lowPriority:SetAttribute("SkyfallPilotOptIn", false)
	local soloHarness = setmetatable({
		roundNumber = 1,
		readyPlayers = {},
		pilotPriority = priority,
		botService = {
			GetBots = function()
				return { bot }
			end,
		},
		random = Random.new(12345),
	}, RoundService)
	local soloController = soloHarness:_chooseController({ lowPriority })
	assert(
		soloController and soloController.kind == "Bot" and soloController.value == bot,
		"The first solo-human round must keep a bot as Controller"
	)

	local fallbackHarness = setmetatable({
		roundNumber = 3,
		readyPlayers = {},
		pilotPriority = priority,
		botService = {
			GetBots = function()
				return { bot }
			end,
		},
		random = Random.new(12345),
	}, RoundService)
	local fallback = fallbackHarness:_chooseController({})
	assert(fallback and fallback.kind == "Bot", "A bot must be used when no ready human exists")
end)

runTest("One human and ten bots default to a bot controller until the human manually opts in", function()
	local mainPlayer = makeFakePlayer("OnlyHumanTester", "Waiting")
	mainPlayer:SetAttribute("SkyfallPilotOptIn", false)
	local bots = {}
	for index = 1, 10 do
		table.insert(bots, {
			name = "IndependentBot" .. tostring(index),
			model = { Parent = Workspace },
			humanoid = { Health = 100 },
			alive = false,
		})
	end

	local harness = setmetatable({
		readyPlayers = { [mainPlayer] = true },
		pilotPriority = nil,
		botService = {
			GetBots = function()
				return bots
			end,
		},
		random = Random.new(19023),
	}, RoundService)

	local automatic = harness:_chooseController({ mainPlayer })
	assert(
		automatic and automatic.kind == "Bot" and table.find(bots, automatic.value) ~= nil,
		"The only human must remain a normal character while a bot controls the aircraft"
	)
	assert(mainPlayer:GetAttribute("SkyfallAircraftControlActive") ~= true, "Automatic selection must not activate aircraft control on the human")

	mainPlayer:SetAttribute("SkyfallPilotOptIn", true)
	local manual = harness:_chooseController({ mainPlayer })
	assert(
		manual and manual.kind == "Player" and manual.value == mainPlayer,
		"Manual aircraft icon opt-in must be the only normal route to human aircraft control"
	)

	mainPlayer:SetAttribute("SkyfallPilotOptIn", false)
	local canceled = harness:_chooseController({ mainPlayer })
	assert(
		canceled and canceled.kind == "Bot",
		"Turning the manual icon off must restore bot controller selection"
	)
end)

runTest("Ten bots remain independently assigned as one Controller and nine Runners", function()
	local bots = {}
	local models = {}
	local spawnCFrames = {}

	for index = 1, 10 do
		local model = Instance.new("Model")
		model.Name = "IndependentRoundBot_" .. tostring(index)

		local root = Instance.new("Part")
		root.Name = "HumanoidRootPart"
		root.Size = Vector3.new(2, 2, 1)
		root.Parent = model

		local humanoid = Instance.new("Humanoid")
		humanoid.Parent = model
		model.PrimaryPart = root
		model.Parent = Workspace
		table.insert(models, model)

		bots[index] = {
			name = model.Name,
			model = model,
			root = root,
			humanoid = humanoid,
			walkSpeed = 16,
			jumpPower = 50,
			alive = false,
			isController = false,
			tracks = {},
			currentAnimation = nil,
		}
		if index > 1 then
			spawnCFrames[index] = CFrame.new(100 + index * 5, 80, 0)
		end
	end

	local harness = setmetatable({
		bots = bots,
		_playAnimation = function() end,
	}, BotService)
	harness:StartRound(spawnCFrames, bots[1])

	assert(#bots == 10, "The full ten-bot roster must be processed")
	assert(
		bots[1].isController == true
			and bots[1].alive == false
			and bots[1].model:GetAttribute("SkyfallRole") == "Controller"
			and bots[1].root.Anchored == true,
		"Exactly the selected bot should occupy the hidden Controller role"
	)

	for index = 2, 10 do
		local bot = bots[index]
		assert(
			bot.isController == false
				and bot.alive == true
				and bot.model:GetAttribute("SkyfallRole") == "Runner",
			"Every non-controller bot must remain an independent Runner"
		)
		assert(
			bot.root.Anchored == false
				and (bot.model:GetPivot().Position - spawnCFrames[index].Position).Magnitude < 0.1,
			"Every non-controller bot must be placed at its own runner spawn"
		)
		assert(
			bot.humanoid.WalkSpeed == bot.walkSpeed
				and bot.humanoid.JumpPower == bot.jumpPower,
			"Runner movement settings must remain independent from controller state"
		)
	end

	for _, model in ipairs(models) do
		model:Destroy()
	end
end)

runTest("Legacy nextController cannot select an unready player", function()
	local previousWinner = makeFakePlayer("PreviousWinner", "Winner")
	local harness = setmetatable({
		roundNumber = 2,
		readyPlayers = {},
		botService = {
			GetBots = function()
				return {}
			end,
		},
		random = Random.new(12345),
		nextController = { kind = "Player", value = previousWinner },
	}, RoundService)

	assert(harness:_chooseController({}) == nil, "An unready legacy nextController must never be selected")
end)

runTest("Pilot Priority rewards use 54-second threshold, one reward per round, and cap at 100", function()
	local early = makeFakePlayer("EarlyElimination", "Runner")
	local late = makeFakePlayer("LateElimination", "Runner")
	local leaver = makeFakePlayer("Leaver", "Runner")
	local priority = PilotPriorityService.new(Random.new(7))
	priority:Initialize(early)
	priority:Initialize(late)
	priority:Initialize(leaver)

	assert(priority:AwardElimination(early, 1, 53) == true, "Early elimination should consume its round reward")
	assert(priority:GetScore(early) == 0, "Elimination before 54 seconds must award zero")
	assert(priority:AwardWinner(early, 1) == false, "A second reward in the same round must be rejected")

	assert(priority:AwardElimination(late, 1, 54) == true, "Elimination at 54 seconds should be accepted")
	assert(priority:GetScore(late) == 5, "Elimination at or after 54 seconds must award five")
	assert(priority:AwardWinner(late, 1) == false, "Elimination and winner rewards must not stack in one round")
	assert(priority:AwardWinner(late, 2) == true, "A new round winner reward should be accepted")
	assert(priority:GetScore(late) == 15, "Winner reward must add ten points")

	for roundNumber = 3, 12 do
		assert(priority:AwardWinner(late, roundNumber), "A fresh round reward should be accepted")
	end
	assert(priority:GetScore(late) == 100, "Pilot Priority must be capped at one hundred")

	leaver.Parent = nil
	assert(priority:AwardWinner(leaver, 1) == false, "A player who left must not receive a winner reward")
end)

runTest("Pilot Priority tie-break favors the player who waited longest and avoids an immediate repeat", function()
	local first = makeFakePlayer("FirstTie", "Runner")
	local second = makeFakePlayer("SecondTie", "Runner")
	local priority = PilotPriorityService.new(Random.new(11))
	priority:Initialize(first)
	priority:Initialize(second)
	priority.scores[first] = 30
	priority.scores[second] = 30
	priority.lastControllerAt[first] = os.clock() - 100
	priority.lastControllerAt[second] = os.clock() - 10

	assert(priority:ChooseController({ first, second }) == first, "The longest-waiting player must win the tie-break")
	assert(priority:GetScore(first) == 0, "Controller selection must reset the selected player's score")

	priority.scores[first] = 30
	priority.scores[second] = 30
	assert(
		priority:ChooseController({ first, second }) == second,
		"A player who controlled moments ago must not repeat while an equal-priority player waits"
	)
end)

runTest("Timeout gives every living human Runner a win and ten Pilot Priority points", function()
	local first = makeFakePlayer("CoWinnerA", "Runner")
	local second = makeFakePlayer("CoWinnerB", "Runner")
	local eliminated = makeFakePlayer("EliminatedRunner", "Spectator")
	local deadRunner = makeFakePlayer("DeadButStaleRunner", "Runner")
	deadRunner.Character.Humanoid.Health = 0
	local botController = {
		name = "RoundController",
		model = { Parent = Workspace },
		humanoid = { Health = 100 },
		alive = false,
	}
	local priority = PilotPriorityService.new(Random.new(19))
	for _, player in ipairs({ first, second, eliminated, deadRunner }) do
		priority:Initialize(player)
	end
	local firstWins = { Value = 0 }
	local secondWins = { Value = 0 }
	local eliminatedWins = { Value = 0 }
	local harness = setmetatable({
		elapsedSeconds = Config.ROUND_SECONDS,
		aliveRunners = { [first] = true, [second] = true, [deadRunner] = true },
		roundRunners = {
			[first] = { kind = "Player", value = first },
			[second] = { kind = "Player", value = second },
			[eliminated] = { kind = "Player", value = eliminated },
			[deadRunner] = { kind = "Player", value = deadRunner },
		},
		survivalTimes = { [first] = 180, [second] = 180, [eliminated] = 100, [deadRunner] = 180 },
		controller = { kind = "Bot", value = botController },
		botService = {
			GetAliveBots = function()
				return {}
			end,
		},
		stats = {
			[first] = { wins = firstWins },
			[second] = { wins = secondWins },
			[eliminated] = { wins = eliminatedWins },
			[deadRunner] = { wins = { Value = 0 } },
		},
		pilotPriority = priority,
		random = Random.new(123),
		winnerCandidates = {},
	}, RoundService)

	local winners = harness:_resolveWinners(2)
	assert(#winners == 2, "Both living human Runners must be co-winners at timeout")
	assert(firstWins.Value == 1 and secondWins.Value == 1, "Every co-winner must receive exactly one win")
	assert(eliminatedWins.Value == 0, "An eliminated player must not receive a win")
	assert(
		priority:GetScore(first) == 10 and priority:GetScore(second) == 10,
		"Every human co-winner must receive ten Pilot Priority points"
	)
	assert(priority:GetScore(eliminated) == 0, "Eliminated players must not receive winner points")
	assert(
		deadRunner.attributes.SkyfallRole == "Runner" and deadRunner.Character.Humanoid.Health == 0,
		"Stale alive roster entries must not count a dead humanoid as a co-winner"
	)
	assert(priority:GetScore(deadRunner) == 0, "Dead stale roster entries must not receive winner priority")
end)

runTest("A single living human Runner wins before timeout even if bots remain", function()
	local survivor = makeFakePlayer("LastHuman", "Runner")
	local botA = {
		name = "BotA",
		model = { Parent = Workspace },
		humanoid = { Health = 100 },
		alive = true,
	}
	local botB = {
		name = "BotB",
		model = { Parent = Workspace },
		humanoid = { Health = 100 },
		alive = true,
	}
	local priority = PilotPriorityService.new(Random.new(23))
	priority:Initialize(survivor)
	local wins = { Value = 0 }
	local harness = setmetatable({
		elapsedSeconds = 45,
		aliveRunners = { [survivor] = true },
		roundRunners = { [survivor] = { kind = "Player", value = survivor } },
		survivalTimes = { [survivor] = 45 },
		controller = { kind = "Bot", value = { name = "Controller" } },
		botService = {
			GetAliveBots = function()
				return { botA, botB }
			end,
		},
		stats = { [survivor] = { wins = wins } },
		pilotPriority = priority,
		random = Random.new(123),
	}, RoundService)

	local winners = harness:_resolveWinners(3)
	assert(
		#winners == 1 and winners[1].value == survivor,
		"The only living human Runner must win without waiting for bot elimination"
	)
	assert(
		wins.Value == 1 and priority:GetScore(survivor) == 10,
		"The sole human winner must receive stats and ten points"
	)
end)

runTest("If no Runner remains, a valid human Controller receives the win and priority reward", function()
	local controller = makeFakePlayer("HumanController", "Controller")
	local priority = PilotPriorityService.new(Random.new(29))
	priority:Initialize(controller)
	local wins = { Value = 0 }
	local harness = setmetatable({
		elapsedSeconds = 80,
		aliveRunners = {},
		roundRunners = {},
		survivalTimes = {},
		controller = { kind = "Player", value = controller },
		botService = {
			GetAliveBots = function()
				return {}
			end,
		},
		stats = { [controller] = { wins = wins } },
		pilotPriority = priority,
		random = Random.new(123),
	}, RoundService)

	local winners = harness:_resolveWinners(0)
	assert(#winners == 1 and winners[1].value == controller, "The current Controller must win when no Runner remains")
	assert(
		wins.Value == 1 and priority:GetScore(controller) == 10,
		"A human Controller winner must receive one win and ten Pilot Priority points"
	)
end)

runTest("Dead stale human Runners cannot win through survivor fallback", function()
	local function checkDeadRunnerFallback(elapsedSeconds)
		local deadRunner = makeFakePlayer("StaleDeadRunner", "Runner")
		deadRunner.Character.Humanoid.Health = 0
		local controller = makeFakePlayer("FallbackController", "Controller")
		local priority = PilotPriorityService.new(Random.new(37))
		priority:Initialize(deadRunner)
		priority:Initialize(controller)
		local deadWins = { Value = 0 }
		local controllerWins = { Value = 0 }
		local harness = setmetatable({
			elapsedSeconds = elapsedSeconds,
			aliveRunners = { [deadRunner] = true },
			roundRunners = { [deadRunner] = { kind = "Player", value = deadRunner } },
			survivalTimes = { [deadRunner] = Config.ROUND_SECONDS },
			controller = { kind = "Player", value = controller },
			botService = {
				GetAliveBots = function()
					return {}
				end,
			},
			stats = {
				[deadRunner] = { wins = deadWins },
				[controller] = { wins = controllerWins },
			},
			pilotPriority = priority,
			random = Random.new(41),
			_placePlayer = function()
				return true
			end,
			_lobbySpawnForPlayer = function()
				return CFrame.new()
			end,
		}, RoundService)

		local winners = harness:_resolveWinners(1)
		assert(
			#winners == 1 and winners[1].value == controller,
			"Only the valid Controller may win when the roster contains no living Runner"
		)
		assert(
			deadWins.Value == 0 and priority:GetScore(deadRunner) == 0,
			"A dead stale Runner must not receive a win or priority points"
		)
		assert(
			controllerWins.Value == 1 and priority:GetScore(controller) == 10,
			"The fallback Controller must receive one win and ten priority points"
		)
	end

	checkDeadRunnerFallback(45)
	checkDeadRunnerFallback(Config.ROUND_SECONDS)
end)

runTest("A winning human Controller is restored from hidden drone state", function()
	local controller = makeFakePlayer("HiddenController", "Controller")
	local priority = PilotPriorityService.new(Random.new(31))
	priority:Initialize(controller)
	local wins = { Value = 0 }
	local placedAtLobby = false
	local harness = setmetatable({
		controller = { kind = "Player", value = controller },
		stats = { [controller] = { wins = wins } },
		pilotPriority = priority,
		_placePlayer = function(_, player, spawnCFrame)
			placedAtLobby = player == controller and spawnCFrame ~= nil
			return true
		end,
		_lobbySpawnForPlayer = function()
			return CFrame.new(0, 75, 0)
		end,
	}, RoundService)
	local winners = { { kind = "Player", value = controller } }
	harness:_awardWinners(winners)
	assert(placedAtLobby, "A winning Controller must be restored to a visible lobby spawn")
	assert(controller.attributes.SkyfallRole == "Winner", "Controller winner must enter the Winner role")
	assert(
		wins.Value == 1 and priority:GetScore(controller) == 10,
		"Controller winner must receive one win and ten Pilot Priority points"
	)
end)

runTest("Winner broadcast contains only safe names and role strings", function()
	local human = makeFakePlayer("SafeWinner", "Runner")
	local bot = { name = "SafeBot", model = { Parent = Workspace }, humanoid = { Health = 100 }, alive = true }
	local controller = { kind = "Bot", value = bot }
	local harness = setmetatable({
		controller = controller,
		winnerCandidates = {
			{ kind = "Player", value = human, winningRole = "Runner" },
			{ kind = "Bot", value = bot, winningRole = "Controller" },
		},
	}, RoundService)
	local details = harness:_getWinnerDetails()
	assert(#details == 2, "All winners must be included in the broadcast")
	assert(
		details[1].name == "SafeWinner" and details[1].role == "Runner",
		"Human winner details must be primitive strings"
	)
	assert(
		details[2].name == "SafeBot" and details[2].role == "Controller",
		"Controller details must preserve the role"
	)
	assert(
		details[1].value == nil and details[2].value == nil,
		"Remote winner payload must not contain Player or Bot instances"
	)
end)

runTest("Bubble Blaster server asset, lobby station, and training target exist", function()
	local template = ServerStorage:FindFirstChild("SkyfallBubbleBlasterTemplate")
	assert(template and template:IsA("Tool"), "Bubble Blaster server Tool template is missing")
	assert(
		template.RequiresHandle and template.CanBeDropped == false,
		"Bubble Blaster must be a real non-droppable Tool"
	)
	assert(template:FindFirstChild("Handle"), "Bubble Blaster Handle is missing")
	local station = arena and arena.lobbyFolder:FindFirstChild("BubbleBlasterTrialStand")
	assert(station, "Persistent Bubble Blaster display station is missing from the lobby")
	local prompt = station:FindFirstChild("BubbleBlasterTryPrompt", true)
	assert(
		prompt and prompt:IsA("ProximityPrompt") and prompt.ActionText == "TRY FOR FREE",
		"The station must expose the cross-platform TRY FOR FREE prompt"
	)
	local target = arena.lobbyFolder:FindFirstChild("BubbleTrainingTarget")
	assert(target and target:FindFirstChild("TargetCore"), "Stationary training target is missing")
	assert(target.Parent == arena.lobbyFolder, "Training target must remain in the lobby folder")
	local spawnPosition = arena:GetLobbySpawnCFrame(1, 1, false).Position
	local standPosition = station:FindFirstChild("DisplayBase").Position
	assert(
		(spawnPosition - standPosition).Magnitude <= 12,
		"TRY FOR FREE prompt station must be reachable from the first lobby spawn"
	)
end)

runTest("Bubble Blaster grants one copy and accepts only the lobby training target while waiting", function()
	local trainingTarget = arena.lobbyFolder:FindFirstChild("BubbleTrainingTarget")
	local targetPart = trainingTarget and trainingTarget:FindFirstChild("TargetCore")
	local backpack = Instance.new("Folder")
	backpack.Name = "Backpack"
	local fakePlayer = makeFakePlayer("TrialPlayer", "Waiting")
	local trialCharacter = Instance.new("Model")
	trialCharacter.Name = "TrialPlayerCharacter"
	local trialRoot = Instance.new("Part")
	trialRoot.Name = "HumanoidRootPart"
	trialRoot.Anchored = true
	trialRoot.Position = Vector3.new(0, 0, 0)
	trialRoot.Parent = trialCharacter
	trialCharacter.Parent = Workspace
	fakePlayer.Character = trialCharacter
	fakePlayer.FindFirstChildOfClass = function(_, className)
		return className == "Backpack" and backpack or nil
	end
	local mockRounds = {
		IsActive = function()
			return false
		end,
		IsAliveRunner = function(_, candidate)
			return candidate:GetAttribute("SkyfallRole") == "Runner"
		end,
	}
	local mockBots = {
		GetAliveBots = function()
			return {}
		end,
	}
	local remote = Instance.new("RemoteEvent")
	local service = BubbleGunService.new(arena, mockRounds, mockBots, remote)
	service.template = ServerStorage:FindFirstChild("SkyfallBubbleBlasterTemplate")
	service.displayStand = arena.lobbyFolder:FindFirstChild("BubbleBlasterTrialStand")
	service.promptPart = service.displayStand:FindFirstChild("Handle", true)
	service.trainingTarget = trainingTarget
	trialRoot.Position = service.promptPart.Position
	assert(service:GrantTrial(fakePlayer), "Waiting player should receive the free trial Tool")
	assert(service:GrantTrial(fakePlayer), "Repeated free trial interaction should remain safe")
	local copies = 0
	for _, child in ipairs(backpack:GetChildren()) do
		if child:IsA("Tool") and child.Name == Config.BUBBLE_GUN_TOOL_NAME then
			copies += 1
		end
	end
	assert(copies == 1, "Repeated prompt interaction must never duplicate the Tool")
	trialRoot.Position += Vector3.new(100, 0, 0)
	assert(
		service:GrantTrial(fakePlayer) == false,
		"Server must reject a spoofed prompt trigger outside ProximityPrompt range"
	)
	trialRoot.Position = service.promptPart.Position
	local target = service:_findTarget(fakePlayer, targetPart)
	assert(target and target.kind == "Training", "Waiting players may target only the dedicated training target")
	service.rounds = {
		IsActive = function()
			return true
		end,
		IsAliveRunner = function()
			return false
		end,
	}
	assert(
		service:_findTarget(fakePlayer, targetPart) == nil,
		"Training target must not be targetable during an active round"
	)
	service.rounds = mockRounds
	fakePlayer:SetAttribute("SkyfallRole", "Controller")
	assert(service:GrantRunner(fakePlayer) == false, "Controller must not receive the Runner loadout")
	remote:Destroy()
	backpack:Destroy()
	trialCharacter:Destroy()
end)

runTest("Bubble Blaster server rejects invalid aim and enforces its cooldown", function()
	local backpack = Instance.new("Folder")
	backpack.Name = "Backpack"
	local fakePlayer = makeFakePlayer("ServerShotTester", "Waiting")
	local character = Instance.new("Model")
	character.Name = "ServerShotCharacter"
	character.Parent = Workspace
	local tool = Instance.new("Tool")
	tool.Name = Config.BUBBLE_GUN_TOOL_NAME
	tool:SetAttribute("SkyfallBubbleTool", true)
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Position = Vector3.new(500, 500, 500)
	handle.Parent = tool
	tool.Parent = character
	fakePlayer.Character = character

	local remote = Instance.new("RemoteEvent")
	local service = BubbleGunService.new(arena, {
		IsActive = function()
			return false
		end,
		IsAliveRunner = function()
			return false
		end,
	}, {
		GetAliveBots = function()
			return {}
		end,
	}, remote)
	service.displayStand = arena.lobbyFolder:FindFirstChild("BubbleBlasterTrialStand")
	service.trainingTarget = arena.lobbyFolder:FindFirstChild("BubbleTrainingTarget")
	service.cooldowns = {}

	assert(
		service:_handleShot(fakePlayer, Vector3.new(math.huge, 0, 0)) == false,
		"Non-finite direction must be rejected before raycasting"
	)
	assert(
		service:_handleShot(fakePlayer, Vector3.new(0, 1, 0)) == true,
		"A valid equipped server-owned Tool should accept one shot"
	)
	assert(
		service:_handleShot(fakePlayer, Vector3.new(0, 1, 0)) == false,
		"A second shot inside the eight-second cooldown must be rejected"
	)
	service:ClearAll()
	character:Destroy()
	backpack:Destroy()
	remote:Destroy()
end)

runTest("Bubble projectile revalidates and hits the training target after travel", function()
	local remote = Instance.new("RemoteEvent")
	local fakePlayer = makeFakePlayer("TrainingProjectileTester", "Waiting")
	local character = Instance.new("Model")
	character.Name = "TrainingProjectileCharacter"
	character.Parent = Workspace
	fakePlayer.Character = character
	local tool = Instance.new("Tool")
	tool.Name = Config.BUBBLE_GUN_TOOL_NAME
	tool:SetAttribute("SkyfallBubbleTool", true)
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Anchored = true
	handle.Position = Vector3.new(800, 500, 800)
	handle.Parent = tool
	tool.Parent = character

	local target = Instance.new("Model")
	target.Name = "IsolatedTrainingProjectileTarget"
	local core = Instance.new("Part")
	core.Name = "TargetCore"
	core.Anchored = true
	core.Size = Vector3.new(3, 3, 3)
	core.Position = Vector3.new(812, 500, 800)
	core.Parent = target
	target.Parent = Workspace

	local service = BubbleGunService.new(arena, {
		IsActive = function()
			return false
		end,
		IsAliveRunner = function()
			return false
		end,
	}, {
		GetAliveBots = function()
			return {}
		end,
	}, remote)
	service.trainingTarget = target
	service.displayStand = nil

	assert(
		service:_handleShot(fakePlayer, Vector3.new(1, 0, 0)),
		"An equipped waiting player must be able to fire toward the training target"
	)
	task.wait(0.16)
	assert(
		Workspace:FindFirstChild("BubbleImpactBurst") ~= nil,
		"Projectile arrival must re-raycast and produce the target hit burst"
	)
	assert(next(service.activeProjectiles) == nil, "Resolved projectile records must be removed")
	service:ClearAll()
	target:Destroy()
	character:Destroy()
	remote:Destroy()
end)

runTest("Bubble hold restores movement and physics state exactly once", function()
	local remote = Instance.new("RemoteEvent")
	local service = BubbleGunService.new(arena, {
		IsActive = function()
			return true
		end,
		IsAliveRunner = function()
			return true
		end,
	}, {
		GetAliveBots = function()
			return {}
		end,
	}, remote)
	local fakeTargetPlayer = makeFakePlayer("HeldRunner", "Runner")
	local model = Instance.new("Model")
	model.Name = "BubbleHoldSmokeTarget"
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Anchored = false
	root.Parent = model
	local humanoid = Instance.new("Humanoid")
	humanoid.WalkSpeed = 18
	humanoid.JumpPower = 52
	humanoid.Parent = model
	model.Parent = Workspace

	assert(
		service:_holdTarget({ kind = "Player", player = fakeTargetPlayer, model = model, humanoid = humanoid }, nil),
		"A live humanoid target should be held"
	)
	local hold = service.holdsByHumanoid[humanoid]
	assert(
		hold and root.Anchored and humanoid.WalkSpeed == 0 and humanoid.PlatformStand,
		"Hold must stop the target's movement and anchor its root"
	)
	assert(service:_releaseHold(hold), "The active hold should release")
	assert(service:_releaseHold(hold) == false, "A hold must not release twice")
	assert(
		root.Anchored == hold.rootAnchored and humanoid.WalkSpeed == 18 and humanoid.JumpPower == 52,
		"Release must restore the saved root and movement properties"
	)

	assert(
		service:_holdTarget({ kind = "Player", player = fakeTargetPlayer, model = model, humanoid = humanoid }, nil),
		"A second hold should start after the first was released"
	)
	local roleHold = service.holdsByHumanoid[humanoid]
	fakeTargetPlayer:SetAttribute("SkyfallRole", "Controller")
	assert(
		roleHold.released and root.Anchored == false and humanoid.WalkSpeed == 18,
		"Changing the target out of Runner role must immediately release the hold"
	)

	fakeTargetPlayer:SetAttribute("SkyfallRole", "Runner")
	assert(
		service:_holdTarget({ kind = "Player", player = fakeTargetPlayer, model = model, humanoid = humanoid }, nil),
		"A new hold should start after the first role-change release"
	)
	local winnerHold = service.holdsByHumanoid[humanoid]
	fakeTargetPlayer:SetAttribute("SkyfallRole", "Winner")
	assert(
		winnerHold.released and root.Anchored == true,
		"Round cleanup must not unanchor a target after it has been declared a winner"
	)

	fakeTargetPlayer:SetAttribute("SkyfallRole", "Runner")
	assert(
		service:_holdTarget({ kind = "Player", player = fakeTargetPlayer, model = model, humanoid = humanoid }, nil),
		"A further hold should start after the winner state is reset"
	)
	local deathHold = service.holdsByHumanoid[humanoid]
	humanoid.Health = 0
	assert(deathHold.released, "A target Humanoid death must immediately release the hold")
	for _, event in pairs(fakeTargetPlayer.attributeSignals or {}) do
		event:Destroy()
	end
	model:Destroy()
	remote:Destroy()
end)

runTest("Sole survivor and grounded checks distinguish air from floor", function()
	local testBot = {
		name = "CloudTestBot",
		model = { Parent = Workspace },
		humanoid = { Health = 100, FloorMaterial = Enum.Material.Metal },
	}
	local testBotService = {
		GetAliveBots = function()
			return { testBot }
		end,
	}
	local harness = setmetatable({
		botService = testBotService,
		aliveRunners = {},
	}, RoundService)

	local survivor = harness:_getSoleSurvivor()
	assert(
		survivor and survivor.kind == "Bot" and survivor.value == testBot,
		"The only living bot should be the sole survivor"
	)
	assert(harness:_isGrounded(survivor) == true, "A survivor touching a floor should be grounded")
	testBot.humanoid.FloorMaterial = Enum.Material.Air
	assert(harness:_isGrounded(survivor) == false, "A survivor in the air must not be treated as grounded")
end)

runTest("Longest-survivor fallback ignores eliminated bots", function()
	local shortRunner = {
		name = "ShortRunner",
		alive = true,
		humanoid = { Health = 100 },
		model = {
			Parent = Workspace,
			GetAttribute = function()
				return "Runner"
			end,
		},
	}
	local longRunner = {
		name = "LongRunner",
		alive = true,
		humanoid = { Health = 100 },
		model = {
			Parent = Workspace,
			GetAttribute = function()
				return "Runner"
			end,
		},
	}
	local shortCandidate = { kind = "Bot", value = shortRunner }
	local longCandidate = { kind = "Bot", value = longRunner }
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

runTest("Owner debug control overrides first-round bot selection and can take over an active round", function()
	local function makePlayer(name)
		local fakePlayer = { Name = name, Parent = Players, attributes = {} }
		function fakePlayer:SetAttribute(attributeName, value)
			self.attributes[attributeName] = value
		end
		function fakePlayer:GetAttribute(attributeName)
			return self.attributes[attributeName]
		end
		return fakePlayer
	end

	local debugPlayer = makePlayer("DebugOwner")
	local testBot = {
		name = "DebugPriorityBot",
		model = { Parent = Workspace },
		humanoid = { Health = 100 },
	}
	local preRoundHarness = setmetatable({
		phase = "Waiting",
		roundNumber = 1,
		readyPlayers = {},
		debugAutoReady = {},
		debugControllerPlayer = nil,
		botService = {
			GetBots = function()
				return { testBot }
			end,
		},
		random = {
			NextInteger = function(_, minimum)
				return minimum
			end,
		},
		_getReadyPlayers = function()
			return { debugPlayer }
		end,
		_broadcast = function() end,
	}, RoundService)

	assert(
		preRoundHarness:RequestDebugController(debugPlayer, true),
		"An owner debug request should be accepted before the round"
	)
	assert(debugPlayer.attributes.SkyfallDebugDroneEnabled == true, "The debug attribute should turn on")
	assert(preRoundHarness.readyPlayers[debugPlayer] == true, "The debug player should be queued for the next round")
	local selected = preRoundHarness:_chooseController()
	assert(
		selected and selected.kind == "Player" and selected.value == debugPlayer,
		"The debug owner must override the normal first-round solo-bot rule"
	)

	assert(preRoundHarness:RequestDebugController(debugPlayer, false), "The owner should be able to disable debug mode")
	assert(debugPlayer.attributes.SkyfallDebugDroneEnabled == false, "The debug attribute should turn off")
	assert(
		preRoundHarness.readyPlayers[debugPlayer] == nil,
		"A debug-only ready request should be removed when disabled"
	)

	local priorController = makePlayer("PriorController")
	local activeHarness = setmetatable({
		phase = "Active",
		readyPlayers = {},
		debugAutoReady = {},
		debugControllerPlayer = nil,
		debugPreviousController = nil,
		controller = { kind = "Player", value = priorController },
		aliveRunners = { [debugPlayer] = true },
		roundRunners = { [debugPlayer] = { kind = "Player", value = debugPlayer } },
		survivalTimes = { [debugPlayer] = 45 },
		roundRunnerCount = 1,
		_broadcast = function() end,
		_movePlayerToSpectator = function(_, player)
			player:SetAttribute("SkyfallRole", "Spectator")
		end,
		_setArenaStreamingFocus = function()
			return true
		end,
		_setPlayerControllerHidden = function(_, player, hidden)
			player.hiddenForController = hidden
		end,
		_recordSurvival = function(self, candidate)
			self.recordedDebugSurvival = candidate.value
		end,
		_isCandidateValid = function(_, candidate)
			return candidate ~= nil and candidate.value.Parent == Players
		end,
	}, RoundService)

	assert(
		activeHarness:RequestDebugController(debugPlayer, true),
		"An owner should be able to take over during an active round"
	)
	assert(
		activeHarness.controller.kind == "Player" and activeHarness.controller.value == debugPlayer,
		"The owner should become the active controller immediately"
	)
	assert(activeHarness.aliveRunners[debugPlayer] == nil, "A debug controller must be removed from the runner roster")
	assert(activeHarness.recordedDebugSurvival == debugPlayer, "Survival time should be recorded before the takeover")
	assert(activeHarness.roundRunners[debugPlayer] == nil, "The debug controller must not remain in the winner pool")
	assert(activeHarness.roundRunnerCount == 0, "The runner count should be reduced when a runner becomes controller")
	assert(
		priorController.attributes.SkyfallRole == "Spectator",
		"The replaced controller should be moved out of the controller role"
	)

	assert(
		activeHarness:RequestDebugController(debugPlayer, false),
		"The owner should be able to release active debug control"
	)
	assert(activeHarness.controller.value == priorController, "The previous valid controller should be restored")
	assert(priorController.attributes.SkyfallRole == "Controller", "The previous controller role should be restored")

	assert(
		AdminFlightService.IsAuthorizedUserId(9001, Enum.CreatorType.User, 9001),
		"The personal experience owner should pass the server authorization check"
	)
	assert(
		not AdminFlightService.IsAuthorizedUserId(9001, Enum.CreatorType.Group, 9001),
		"A group ID match must not authorize a player debug request"
	)
end)

runTest("Aircraft opt-in is available only after PLAY and is reset for every human at round cleanup", function()
	local waitingPlayer = makeFakePlayer("WaitingWithoutPlay", "Waiting")
	waitingPlayer:SetAttribute("SkyfallPilotOptIn", false)
	local waitingHarness = setmetatable({
		phase = "Waiting",
		readyPlayers = {},
	}, RoundService)
	assert(
		waitingHarness:RequestPilotOptIn(waitingPlayer, true) == false,
		"A waiting player who has not pressed PLAY cannot set aircraft opt-in"
	)

	waitingHarness.readyPlayers[waitingPlayer] = true
	assert(
		waitingHarness:RequestPilotOptIn(waitingPlayer, true) == true,
		"A queued player may manually opt in while waiting"
	)
	waitingHarness.phase = "Intermission"
	assert(
		waitingHarness:RequestPilotOptIn(waitingPlayer, false) == true,
		"A queued player may cancel aircraft opt-in during intermission"
	)
	waitingHarness.phase = "Active"
	assert(
		waitingHarness:RequestPilotOptIn(waitingPlayer, true) == false,
		"Aircraft opt-in cannot change after a round becomes active"
	)

	waitingHarness.readyPlayers[waitingPlayer] = true
	waitingPlayer:SetAttribute("SkyfallReady", true)
	waitingPlayer:SetAttribute("SkyfallPilotOptIn", true)
	waitingPlayer:SetAttribute("SkyfallAircraftControlActive", true)
	waitingHarness.phase = "Waiting"
	waitingHarness:_clearReadyPlayers()
	assert(waitingPlayer:GetAttribute("SkyfallReady") == false, "Round cleanup must clear the ready state")
	assert(waitingPlayer:GetAttribute("SkyfallPilotOptIn") == false, "Round cleanup must clear stale manual opt-in")
	assert(waitingPlayer:GetAttribute("SkyfallAircraftControlActive") == false, "Round cleanup must clear aircraft state")
end)

runTest("A stale disabled debug toggle cannot override normal controller selection", function()
	local debugPlayer = makeFakePlayer("StaleDebugOwner", "Runner")
	debugPlayer:SetAttribute("SkyfallDebugDroneEnabled", false)
	local fallbackBot = {
		name = "FallbackControllerBot",
		model = { Parent = Workspace },
		humanoid = { Health = 100 },
	}
	local harness = setmetatable({
		phase = "Waiting",
		roundNumber = 2,
		readyPlayers = { [debugPlayer] = true },
		debugAutoReady = { [debugPlayer] = true },
		debugControllerPlayer = debugPlayer,
		botService = {
			GetBots = function()
				return { fallbackBot }
			end,
		},
		pilotPriority = {
			ChooseController = function()
				return nil
			end,
		},
		random = Random.new(12345),
	}, RoundService)

	local selected = harness:_chooseController({})
	assert(
		selected and selected.kind == "Bot" and selected.value == fallbackBot,
		"A false debug attribute must not bypass normal bot/human selection"
	)
	assert(harness.debugControllerPlayer == nil, "A stale disabled debug player pointer must be cleared")
	assert(harness.debugAutoReady[debugPlayer] == nil, "A stale debug-only auto-ready entry must be cleared")
end)

runTest("Round cleanup does not auto-ready a debug player after the toggle is disabled", function()
	local debugPlayer = makeFakePlayer("DisabledDebugOwner", "Waiting")
	debugPlayer:SetAttribute("SkyfallDebugDroneEnabled", false)
	debugPlayer:SetAttribute("SkyfallReady", true)
	local harness = setmetatable({
		phase = "Waiting",
		readyPlayers = { [debugPlayer] = true },
		debugAutoReady = { [debugPlayer] = true },
		debugControllerPlayer = debugPlayer,
		roundHumanCount = 1,
	}, RoundService)

	harness:_clearReadyPlayers()
	assert(harness.debugControllerPlayer == nil, "Disabled debug state must not persist past round cleanup")
	assert(harness.readyPlayers[debugPlayer] == nil, "A disabled debug owner must not be auto-readied")
	assert(harness.debugAutoReady[debugPlayer] == nil, "Debug auto-ready marker must be removed")
	assert(debugPlayer:GetAttribute("SkyfallReady") == false, "Disabled debug owner must remain not-ready")
end)

runTest("An enabled owner debug override is cleared after one round", function()
	local debugPlayer = makeFakePlayer("OneRoundDebugOwner", "Waiting")
	debugPlayer:SetAttribute("SkyfallDebugDroneEnabled", true)
	debugPlayer:SetAttribute("SkyfallReady", true)
	debugPlayer:SetAttribute("SkyfallPilotOptIn", true)
	debugPlayer:SetAttribute("SkyfallAircraftControlActive", true)
	local harness = setmetatable({
		phase = "Waiting",
		readyPlayers = { [debugPlayer] = true },
		debugAutoReady = { [debugPlayer] = true },
		-- Simulate a stale debug attribute after its owner pointer was lost.
		debugControllerPlayer = nil,
		debugPreviousController = { kind = "Bot", value = {} },
		roundHumanCount = 1,
	}, RoundService)

	harness:_clearReadyPlayers()
	assert(debugPlayer:GetAttribute("SkyfallDebugDroneEnabled") == false, "Debug mode must be disabled after its one manual round")
	assert(debugPlayer:GetAttribute("SkyfallReady") == false, "Debug auto-ready must not survive the round")
	assert(debugPlayer:GetAttribute("SkyfallPilotOptIn") == false, "Aircraft opt-in must be consumed after round cleanup")
	assert(debugPlayer:GetAttribute("SkyfallAircraftControlActive") == false, "Aircraft control state must be cleared after round cleanup")
	assert(harness.debugControllerPlayer == nil, "The owner debug pointer must be cleared")
	assert(harness.debugPreviousController == nil, "The prior controller pointer must be cleared")
	assert(next(harness.debugAutoReady) == nil, "No debug auto-ready marker may survive")

	-- Rejoin the next round normally. The stale debug flag must not select this player.
	harness.readyPlayers[debugPlayer] = true
	debugPlayer:SetAttribute("SkyfallReady", true)
	local nextRoundBot = {
		name = "NextRoundBot",
		model = { Parent = Workspace },
		humanoid = { Health = 100 },
	}
	harness.botService = {
		GetBots = function() return { nextRoundBot } end,
		IsRigReady = function() return true end,
	}
	harness.pilotPriority = nil
	local nextRoundController = harness:_chooseController({ debugPlayer })
	assert(nextRoundController and nextRoundController.kind == "Bot" and nextRoundController.value == nextRoundBot,
		"The owner must not be selected after debug state is cleared")
end)

runTest("A departing debug controller restores its previous live controller", function()
	local previousController = makeFakePlayer("PreviousLiveController", "Spectator")
	local departingDebugPlayer = makeFakePlayer("DepartingDebugController", "Controller")
	local restoredHiddenState = nil
	local previousCandidate = { kind = "Player", value = previousController }
	local harness = setmetatable({
		phase = "Active",
		controller = { kind = "Player", value = departingDebugPlayer },
		debugControllerPlayer = departingDebugPlayer,
		debugPreviousController = previousCandidate,
		readyPlayers = {},
		debugAutoReady = { [departingDebugPlayer] = true },
		_isCandidateValid = function(_, candidate)
			return candidate == previousCandidate
		end,
		_setArenaStreamingFocus = function()
			return true
		end,
		_setPlayerControllerHidden = function(_, player, hidden)
			restoredHiddenState = { player = player, hidden = hidden }
		end,
		botService = {
			SetController = function()
				error("Bot restore should not be used for a human previous controller")
			end,
		},
		_broadcast = function() end,
	}, RoundService)

	assert(
		harness:_restoreAfterDebugControllerLeaves(departingDebugPlayer),
		"The active debug owner removal should be handled"
	)
	assert(harness.controller == previousCandidate, "The previous valid player should regain control")
	assert(
		previousController.attributes.SkyfallRole == "Controller",
		"The previous player role must return to Controller"
	)
	assert(
		restoredHiddenState and restoredHiddenState.player == previousController and restoredHiddenState.hidden == true,
		"The previous player must be returned to the hidden aircraft state"
	)
	assert(
		harness.debugControllerPlayer == nil and harness.debugPreviousController == nil,
		"Departing debug references must be cleared"
	)
	assert(harness.debugAutoReady[departingDebugPlayer] == nil, "Departing debug auto-ready state must be cleared")

	local botController = {
		kind = "Bot",
		value = { name = "PriorBotController" },
	}
	local botRestoreCount = 0
	local botHarness = setmetatable({
		phase = "Active",
		controller = { kind = "Player", value = departingDebugPlayer },
		debugControllerPlayer = departingDebugPlayer,
		debugPreviousController = botController,
		_setArenaStreamingFocus = function()
			return true
		end,
		_setPlayerControllerHidden = function() end,
		_isCandidateValid = function(_, candidate)
			return candidate == botController
		end,
		botService = {
			SetController = function(_, bot, enabled)
				assert(bot == botController.value and enabled == true, "The saved bot must be restored as Controller")
				botRestoreCount += 1
			end,
		},
		_broadcast = function() end,
	}, RoundService)
	assert(
		botHarness:_restoreAfterDebugControllerLeaves(departingDebugPlayer),
		"Debug controller removal with a previous bot must be handled"
	)
	assert(
		botHarness.controller == botController and botRestoreCount == 1,
		"A prior bot Controller must be restored exactly once"
	)
end)

runTest("Debug drone request requires both the matching player and a true server attribute", function()
	local debugPlayer = makeFakePlayer("ExplicitDebugOwner", "Waiting")
	local otherPlayer = makeFakePlayer("OtherPlayer", "Waiting")
	local harness = setmetatable({ debugControllerPlayer = debugPlayer }, RoundService)

	debugPlayer:SetAttribute("SkyfallDebugDroneEnabled", false)
	assert(not harness:_isDebugControllerRequested(debugPlayer), "False toggle must not authorize debug control")
	debugPlayer:SetAttribute("SkyfallDebugDroneEnabled", true)
	assert(
		harness:_isDebugControllerRequested(debugPlayer),
		"Matching player plus true toggle must authorize debug control"
	)
	assert(not harness:_isDebugControllerRequested(otherPlayer), "Another player must not inherit the debug request")
	assert(not harness:_isDebugControllerRequested(nil), "A missing player must not be authorized")
end)

runTest("Spawn restores normal character control when debug drone is off and preserves explicit opt-in", function()
	local function makeCharacter(name)
		local character = Instance.new("Model")
		character.Name = name
		local root = Instance.new("Part")
		root.Name = "HumanoidRootPart"
		root.Size = Vector3.new(2, 2, 1)
		root.Parent = character
		local humanoid = Instance.new("Humanoid")
		humanoid.Parent = character
		character.PrimaryPart = root
		character.Parent = Workspace
		return character
	end

	local function makeHarness(player, bot)
		return setmetatable({
			phase = "Active",
			controller = { kind = "Player", value = player },
			debugControllerPlayer = player,
			debugAutoReady = { [player] = true },
			debugPreviousController = { kind = "Bot", value = bot },
			characterSerial = {},
			aliveRunners = {},
			arena = arena,
			botService = { SetController = function() end },
			_broadcast = function() end,
			_setArenaStreamingFocus = function()
				return true
			end,
			_setPlayerControllerHidden = function(_, targetPlayer, hidden)
				targetPlayer.hiddenForController = hidden
			end,
			_placePlayer = function(_, targetPlayer, _, characterOverride)
				targetPlayer.lastPlacedCharacter = characterOverride or targetPlayer.Character
				return true
			end,
			_lobbySpawnForPlayer = function()
				return CFrame.new(-250, 80, 0)
			end,
		}, RoundService)
	end

	local previousBot = {
		model = { Parent = Workspace },
		humanoid = { Health = 100 },
	}
	local disabledPlayer = makeFakePlayer("DisabledDroneSpawn", "Controller")
	disabledPlayer:SetAttribute("SkyfallDebugDroneEnabled", false)
	local disabledCharacter = makeCharacter("DisabledDroneFreshCharacter")
	disabledPlayer.Character = disabledCharacter
	local disabledHarness = makeHarness(disabledPlayer, previousBot)
	local disabledSpawnFinished = false
	task.spawn(function()
		disabledHarness:_onCharacterAdded(disabledPlayer, disabledCharacter)
		disabledSpawnFinished = true
	end)
	for _ = 1, 20 do
		if disabledSpawnFinished then
			break
		end
		task.wait(0.05)
	end
	assert(disabledSpawnFinished, "Disabled debug Spawn routing should complete")
	assert(
		disabledHarness.controller.kind == "Bot" and disabledHarness.controller.value == previousBot,
		"Disabling debug drone before Spawn must restore the previous controller"
	)
	assert(disabledPlayer.attributes.SkyfallRole == "Spectator", "A disabled debug owner must not Spawn as Controller")
	assert(disabledPlayer.hiddenForController == false, "A disabled debug owner must retain visible character control")
	assert(
		disabledPlayer.lastPlacedCharacter == disabledCharacter,
		"Spawn recovery must place the new character, not an older model"
	)
	assert(disabledHarness.debugControllerPlayer == nil, "Disabled debug request must be cleared on Spawn")
	disabledCharacter:Destroy()

	local enabledPlayer = makeFakePlayer("EnabledDroneSpawn", "Controller")
	enabledPlayer:SetAttribute("SkyfallDebugDroneEnabled", true)
	local enabledCharacter = makeCharacter("EnabledDroneFreshCharacter")
	enabledPlayer.Character = enabledCharacter
	local enabledHarness = makeHarness(enabledPlayer, previousBot)
	local enabledSpawnFinished = false
	task.spawn(function()
		enabledHarness:_onCharacterAdded(enabledPlayer, enabledCharacter)
		enabledSpawnFinished = true
	end)
	for _ = 1, 20 do
		if enabledSpawnFinished then
			break
		end
		task.wait(0.05)
	end
	assert(enabledSpawnFinished, "Enabled debug Spawn routing should complete")
	assert(
		enabledHarness.controller.value == enabledPlayer,
		"An enabled debug owner should remain the active Controller"
	)
	assert(
		enabledPlayer.attributes.SkyfallRole == "Controller",
		"The enabled debug owner should Spawn in Controller role"
	)
	assert(enabledPlayer.hiddenForController == true, "Explicitly enabled drone control should hide the character")
	enabledCharacter:Destroy()
end)

runTest("Bot controller can be hidden and restored after a debug takeover", function()
	local model = Instance.new("Model")
	model.Name = "DebugBotControllerTest"
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(2, 2, 1)
	root.Parent = model
	local humanoid = Instance.new("Humanoid")
	humanoid.Parent = model
	model.PrimaryPart = root
	model.Parent = Workspace

	local bot = {
		model = model,
		root = root,
		humanoid = humanoid,
		alive = false,
		isController = false,
		targetTile = nil,
	}
	local lobbySpawn = CFrame.new(52, 80, 0)
	local harness = setmetatable({
		bots = { bot },
		arena = {
			GetLobbySpawnCFrame = function()
				return lobbySpawn
			end,
		},
	}, BotService)
	harness._setBotHidden = function(_, candidate, hidden)
		candidate.root.Anchored = hidden
		if hidden then
			candidate.model:PivotTo(CFrame.new(Config.CONTROLLER_HIDDEN_POSITION))
		end
	end

	assert(harness:SetController(bot, true), "A valid bot should accept controller mode")
	assert(bot.isController == true and bot.alive == false, "The controller bot must not remain a living runner")
	assert(model:GetAttribute("SkyfallRole") == "Controller", "The bot role must change to Controller")
	assert(root.Anchored == true, "The hidden controller bot should be anchored")

	assert(harness:SetController(bot, false), "The controller bot should be demoted safely")
	assert(bot.isController == false and bot.alive == false, "A demoted bot should remain a spectator")
	assert(model:GetAttribute("SkyfallRole") == "Spectator", "The bot role should return to Spectator")
	assert(root.Anchored == false, "A spectator bot must be unanchored")
	assert(
		(model:GetPivot().Position - lobbySpawn.Position).Magnitude < 0.1,
		"The demoted bot should return to the waiting platform"
	)
	model:Destroy()
end)

runTest("Human laser requests validate the controller, coordinates, phase, and three-second cooldown", function()
	local controller = { UserId = 8675309 }
	local canControl = false
	local isActive = true
	local markCount = 0
	local beamCount = 0
	local breakCount = 0
	local mockTiles = {
		["8:8"] = { token = 0, broken = false },
		["9:8"] = { token = 0, broken = false },
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
		IsHumanController = function(_, candidate)
			return canControl and candidate == controller
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
	strikeService.lastHumanStrikeAt[controller.UserId] = os.clock() - Config.HUMAN_STRIKE_COOLDOWN_SECONDS - 1

	canControl = true
	isActive = false
	strikeService:_handleHumanTarget(controller, 8, 8)
	assert(markCount == 0, "Laser request should be rejected outside an active round")

	isActive = true
	strikeService:_handleHumanTarget({ UserId = 111 }, 8, 8)
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
return { passed = passed, failed = failed }
