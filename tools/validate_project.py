from __future__ import annotations

import json
import tomllib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"Validation failed: {message}")


project_path = ROOT / "default.project.json"
project = json.loads(project_path.read_text(encoding="utf-8"))
require(project.get("name") == "SkyfallArena", "Rojo project name is missing")

tree = project.get("tree", {})
require(tree.get("$className") == "DataModel", "Rojo DataModel root is missing")
require(tree["ReplicatedStorage"]["Shared"].get("$path") == "src/shared", "Shared source mapping is missing")
require(tree["ServerScriptService"]["SkyfallServer"].get("$path") == "src/server", "Server source mapping is missing")
require(tree["StarterPlayer"]["StarterPlayerScripts"]["SkyfallClient"].get("$path") == "src/client", "Client source mapping is missing")

rokit = tomllib.loads((ROOT / "rokit.toml").read_text(encoding="utf-8"))
tools = rokit.get("tools", {})
require(tools.get("rojo") == "rojo-rbx/rojo@7.7.1", "Rojo must remain pinned to 7.7.1")
require(tools.get("selene") == "Kampfkarren/selene@0.32.0", "Selene must remain pinned to 0.32.0")

required_files = [
    "src/shared/GameConfig.lua",
    "src/shared/MapRotation.lua",
    "src/shared/DebugControllerPolicy.lua",
    "tests/lune/update_019_policy.luau",
    "tests/lune/update_023_control_state.luau",
    "src/server/Bootstrap.server.lua",
    "src/server/Services/ArenaService.lua",
    "src/server/Services/CyberpunkPillarService.lua",
    "src/server/Services/FloorAppearanceService.lua",
    "src/server/Services/ElementIntegrationService.lua",
    "src/server/Services/BotService.lua",
    "src/server/Services/RoundService.lua",
    "src/server/Services/StrikeService.lua",
    "src/server/Services/LaserVFX.lua",
    "src/client/HUD.client.lua",
    "src/client/Audio.client.lua",
    "tests/cloud_smoke_tests.luau",
    "docs/CLOUD_PUBLISHING.md",
    "docs/updates/022-elements-floor-pilot-opt-in.md",
    "docs/handoffs/CODEX_UPDATE_022.md",
    "src/server/Services/AdminFlightService.lua",
    "src/server/Services/BubbleGunService.lua",
    "src/server/Services/PilotPriorityService.lua",
    "src/client/BubbleGun.client.lua",
    "src/client/AdminFlight.client.lua",
]
for relative_path in required_files:
    path = ROOT / relative_path
    require(path.is_file(), f"Required project file is missing: {relative_path}")
    require(path.stat().st_size > 0, f"Required project file is empty: {relative_path}")

config_source = (ROOT / "src/shared/GameConfig.lua").read_text(encoding="utf-8")
for setting in (
    "Config.MIN_PLAYERS = 1",
    "Config.BOT_COUNT = 10",
    "Config.TILE_GAP = 0",
    "Config.LOBBY_SIZE = 144",
    "Config.LOBBY_CENTER = Vector3.new(-250, 70, 0)",
    "Config.ADMIN_FLIGHT_SPEED = 52",
    "Config.HUD_MAX_WIDTH = 224",
    "Config.HUD_HEIGHT = 30",
    "Config.GRID_SIZE = 15",
    "Config.MAX_PLAYER_CAPACITY = 30",
    "Config.MAP_COUNT = 2",
    "Config.ROUND_SECONDS = 180",
    "Config.PILOT_PRIORITY_ELIMINATION_THRESHOLD_SECONDS = Config.ROUND_SECONDS * 0.3",
    'Config.BUBBLE_GUN_TOOL_NAME = "Bubble Blaster"',
    "Config.BUBBLE_GUN_HOLD_SECONDS = 2.5",
    "Config.BUBBLE_GUN_COOLDOWN_SECONDS = 8",
    "Config.BUBBLE_GUN_RANGE = 60",
    "Config.HUMAN_STRIKE_COOLDOWN_SECONDS = 3",
    "Config.LASER_EXTENSION_SECONDS = 0.24",
    "Config.LASER_HOLD_SECONDS = 0.08",
    "Config.LASER_FADE_SECONDS = 0.14",
    "Config.LASER_LAYER_COUNT = 24",
    "Config.CONTROLLER_CAMERA_FOV = 70",
    "Config.CONTROLLER_CAMERA_MARGIN = 8",
    "Config.CONTROLLER_CAMERA_MIN_HEIGHT = 132",
    "Config.CONTROLLER_CAMERA_SMOOTHING = 18",
    "Config.RESPAWN_TIME",
):
    require(setting in config_source, f"Required gameplay setting is missing: {setting}")
require("TILE_REPAIR_SECONDS" not in config_source, "Broken floor tiles must not have a repair timer")
require("OVERTIME_" not in config_source, "The three-minute round must not use overtime modifiers")

arena_source = (ROOT / "src/server/Services/ArenaService.lua").read_text(encoding="utf-8")
for map_name in ("SKYFALL CLASSIC ARENA", "SKYFALL CYBERPUNK WHITE & BLUE ARENA"):
    require(map_name in arena_source, f"Map design is missing: {map_name}")
for feature in (
    "function ArenaService:_buildLobby(",
    "function ArenaService:_buildAircraft(",
    "function ArenaService:_buildMapDecoration(",
    "function ArenaService:SetMap(",
    "function ArenaService:ResetTiles(",
    "function ArenaService:GetControllerSpawnCFrame(",
    "function ArenaService:GetStreamingFocusPart(",
    "SkyfallLaserAircraft",
    "ControllerLens",
    "WaitingPlatform",
    "ClassicArenaSupport",
    "ClassicArenaOuterTrim",
    "ClassicPerimeterNorthSouth_",
    "ClassicPerimeterEastWest_",
    "ClassicPerimeterCornerPost_",
    "Enum.SurfaceType.Studs",
):
    require(feature in arena_source, f"Arena feature is missing: {feature}")
require(arena_source.count("tileMaterial = Enum.Material.Plastic") == 1, "The Classic floor must use Plastic")
for feature in (
    '"ArmorPlate_" .. group.name .. "_"',
    'name = "Upper"',
    'name = "Lower"',
    'addLensReticleRing("LensReticleRing_Outer"',
    'addLensReticleRing("LensReticleRing_Inner"',
):
    require(feature in arena_source, f"Golden sphere detail is missing: {feature}")
for forbidden in (
    "Enum.Material.Water",
    "LobbyWater",
    "LobbyWelcomeSign",
    "LobbyEntranceColumn_",
    "LobbyEntranceHeader",
    "ClassicGatePillar_",
    "ClassicArenaGate",
    "addTree(",
    "addBench(",
    "ClassicArenaTree_",
    "SquareStud_",
    "addNeonBar",
    "NexusRingSegment",
    "ReactorRing",
    "LobbyToArenaWalkway",
    "PilotPlatform",
    "PilotRail",
    "PilotStationSign",
    "CLOUDSPIRE KINGDOM",
    "GOLDEN DUNES TEMPLE",
    "EMERALD GROVE SANCTUARY",
    "AZURE HARBOR FORTRESS",
):
    require(forbidden not in arena_source, f"Forbidden map feature remains: {forbidden}")
lighting_profile_source = (ROOT / "src/shared/LightingProfile.lua").read_text(encoding="utf-8")
lighting_service_source = (ROOT / "src/server/Services/LightingProfileService.lua").read_text(encoding="utf-8")
lighting_test_source = (ROOT / "tests/lune/update_023_lighting_profile.luau").read_text(encoding="utf-8")
require('local LightingProfileService = require(script.Parent:WaitForChild("LightingProfileService"))' in arena_source,
        "ArenaService must use the centralized lighting profile service")
require("LightingProfileService.Apply()" in arena_source, "Every ArenaService map selection must apply the shared lighting profile")
require('local Lighting = game:GetService("Lighting")' not in arena_source, "ArenaService must not write global Lighting directly")
for map_lighting_key in (
    "ambient = Color3.fromRGB",
    "outdoorAmbient = Color3.fromRGB",
    "brightness = ",
    "clockTime = ",
    "exposureCompensation = ",
    "useCyberpunkLighting",
):
    require(map_lighting_key not in arena_source, f"Map-specific global lighting override remains: {map_lighting_key}")
for feature in (
    "Lighting.Brightness = Profile.Brightness",
    "Lighting.ClockTime = Profile.ClockTime",
    "Lighting.ExposureCompensation = Profile.ExposureCompensation",
    "Lighting.Ambient = colorFromRgb(Profile.Ambient)",
    "Lighting.OutdoorAmbient = colorFromRgb(Profile.OutdoorAmbient)",
    "Lighting.ShadowSoftness = Profile.ShadowSoftness",
    "Lighting.LightingStyle = Enum.LightingStyle.Realistic",
    "Lighting.PrioritizeLightingQuality = Profile.PrioritizeLightingQuality",
    'getOrCreateManagedEffect("Atmosphere", "SkyfallAtmosphere")',
    'getOrCreateManagedEffect("SunRaysEffect", "SkyfallSunRays")',
    'getOrCreateManagedEffect("BloomEffect", "SkyfallBloom")',
    'getOrCreateManagedEffect("ColorCorrectionEffect", "SkyfallColorCorrection")',
    'local function removeConflictingPostEffects()',
    'local expectedName = MANAGED_EFFECT_NAMES[child.ClassName]',
    'removeConflictingPostEffects()',
    'Profile.Sky.Name',
):
    require(feature in lighting_service_source, f"Central lighting implementation is missing: {feature}")
for profile_value in (
    "Brightness = 2.15",
    "ExposureCompensation = -0.05",
    "Ambient = { 78, 86, 100 }",
    "OutdoorAmbient = { 122, 133, 149 }",
    'LightingStyle = "Realistic"',
    "PrioritizeLightingQuality = true",
    "Density = 0.07",
    "Glare = 0.035",
    "Intensity = 0.12",
    "Threshold = 1.65",
):
    require(profile_value in lighting_profile_source, f"Shared lighting value is missing: {profile_value}")
require("UPDATE_023_LIGHTING_PROFILE_TESTS_OK" in lighting_test_source, "Update #23 lighting regression test is missing")
require("AmbientOcclusionEffect" not in lighting_service_source, "Do not use a fictitious scriptable AmbientOcclusionEffect")
lighting_write_tokens = (
    "Lighting.Brightness =",
    "Lighting.ClockTime =",
    "Lighting.ExposureCompensation =",
    "Lighting.Ambient =",
    "Lighting.OutdoorAmbient =",
    "Lighting.EnvironmentDiffuseScale =",
    "Lighting.EnvironmentSpecularScale =",
    "Lighting.GlobalShadows =",
    "Lighting.ShadowSoftness =",
    "Lighting.FogColor =",
    "Lighting.FogStart =",
    "Lighting.FogEnd =",
    "Lighting.LightingStyle =",
    "Lighting.PrioritizeLightingQuality =",
)
managed_lighting_path = ROOT / "src/server/Services/LightingProfileService.lua"
for lua_path in (ROOT / "src").rglob("*.lua"):
    if lua_path == managed_lighting_path:
        continue
    source_text = lua_path.read_text(encoding="utf-8")
    for token in lighting_write_tokens:
        require(token not in source_text, f"Global Lighting write outside LightingProfileService: {token} in {lua_path.relative_to(ROOT)}")
require('Instance.new("Clouds")' not in arena_source, "Unsupported global Clouds effect must remain absent")
require("function ArenaService:_buildMapDecoration(theme)" in arena_source, "Classic arena decoration builder is missing")
require("Vector3.new(width + 26, 2, width + 26)" in arena_source, "The arena foundation must be thin")
require("support.CanCollide = false" in arena_source, "The foundation must not catch falling players")
require("AircraftMotionAnchor" in arena_source and "AircraftBodyJoint" in arena_source, "The aircraft needs one central body-motion joint")
require("AircraftUnifiedWeld" in arena_source, "All aircraft parts must be welded to the fuselage")
require("ControllerLensGimbal" not in arena_source, "An independently moving lens gimbal must not remain")
require("function ArenaService:AimAircraftAt(tile)" in arena_source, "Whole-aircraft aiming method is missing")
require("local opticalUp = -direction" in arena_source, "Aircraft aiming must align the lens local -Y optical axis with the target")
require("local right = opticalUp:Cross(back).Unit" in arena_source, "Aircraft aim basis must remain orthonormal for all cardinal directions")
require("function ArenaService:ReturnAircraftLensHome(token)" in arena_source, "Whole-aircraft return-home method is missing")
require("TweenService:Create" in arena_source and "aircraftHoverTween" in arena_source, "Drone body hover animation is missing")
require("ImpactShockwave" in arena_source, "Legacy impact-ring cleanup is missing")
require("function ArenaService:CreateStrikeBeam(tile)" in arena_source, "ArenaService must expose the procedural laser adapter")
require("LaserVFX.Create(self, tile)" in arena_source, "ArenaService must delegate laser rendering to LaserVFX")
laser_vfx_source = (ROOT / "src/server/Services/LaserVFX.lua").read_text(encoding="utf-8")
for feature in (
    "local LAYER_COUNT = 24",
    "LaserOuterAtmosphere",
    "LaserCyanEnvelope",
    "LaserHotCore",
    "LaserEnergyFlowPrimary",
    "LaserEnergyFlowSecondary",
    "LaserRefractionArcA",
    "LaserRefractionArcD",
    "LaserBeamEndpoint",
    "Config.LASER_EXTENSION_SECONDS",
    "Config.LASER_HOLD_SECONDS",
    "Config.LASER_FADE_SECONDS",
    "local FLOW_TEXTURE_SPEED = 3.2",
    "LaserParticles_MuzzleSparks",
    "LaserParticles_MuzzleMist",
    "LaserParticles_ImpactSparks",
    "LaserParticles_ImpactFragments",
    "LaserMuzzleLight",
    "LaserImpactLight",
    "LaserPulse_Muzzle",
    "LaserPulse_Impact",
    "LaserPulse_WaveA",
    "LaserPulse_WaveB",
    "Debris:AddItem",
):
    require(feature in laser_vfx_source, f"Procedural laser VFX component is missing: {feature}")
require("TextureSpeed = -5.5" not in laser_vfx_source, "Energy texture must move from source to target")
require("function ArenaService:RepairTile(" not in arena_source, "Tiles should only be restored by the next round")
map_set_body = arena_source.split("function ArenaService:SetMap(", 1)[1].split("function ArenaService:GetMapName(", 1)[0]
require('tile:SetAttribute("IsBroken", false)' in map_set_body, "The next map must restore broken state")
require("tile.CanCollide = true" in map_set_body, "The next map must restore floor collision")

bot_source = (ROOT / "src/server/Services/BotService.lua").read_text(encoding="utf-8")
for bot_name in ("Atlas", "Nova", "Rook"):
    require(f'name = "{bot_name}"' in bot_source, f"AI bot profile is missing: {bot_name}")
require("for botIndex = 1, Config.BOT_COUNT do" in bot_source, "BotService must construct all configured NPCs")
require("Players:CreateHumanoidModelFromDescriptionAsync" in bot_source, "Bot NPCs must use Roblox's built-in HumanoidDescription rig generator")
require("createFallbackHair" not in bot_source, "Procedural custom bot hair must not be used")
for feature in ("function BotService:_setBotHidden(", "function BotService:SetController(", 'description.HairAccessory = ""', "if self.onBotDied then", "self.onBotDied(bot)"):
    require(feature in bot_source, f"Bot visibility or safe procedural appearance feature is missing: {feature}")
require("Config.LOBBY_BOT_SPAWN_RADIUS = 66" in config_source, "Ten bots need the expanded lobby spawn radius")
fallen_bot_body = bot_source.split("function BotService:EliminateFallenRunners", 1)[1].split("function BotService:SendToLobby", 1)[0]
require(fallen_bot_body.find("bot.alive = false") < fallen_bot_body.find("self.onBotDied(bot)"), "Bot elimination must update alive state before the round broadcasts")
require("function BotService:_collectWarningTiles()" in bot_source, "Bot warning grid should be snapshotted once per decision")
require("self:_warningDistance(gridX, gridZ, warningTiles)" in bot_source, "Bot target selection should use cached warning coordinates")
require("math.clamp(" in bot_source, "Nearest tile lookup should be constant-time")
require("descendant.CastShadow = false" in bot_source, "NPC shadows should be disabled for mobile rendering")
fall_check = bot_source.split("function BotService:EliminateFallenRunners(", 1)[1].split("function BotService:", 1)[0]
require("self.onBotDied(bot)" in fall_check, "A bot falling out of the arena must record its survival time")
for forbidden in ("hairId", "BillboardGui", "BotNameplate", "InsertService", "MarketplaceService"):
    require(forbidden not in bot_source, f"Unwanted external asset or bot label code remains: {forbidden}")

bootstrap_source = (ROOT / "src/server/Bootstrap.server.lua").read_text(encoding="utf-8")
for feature in (
    'getOrCreateRemote(remotesFolder, "BubbleShot")',
    'WaitForChild("PilotPriorityService")',
    'WaitForChild("BubbleGunService")',
    "BubbleGunService.new(",
    "bubbleGun:Start()",
):
    require(feature in bootstrap_source, f"Bootstrap Bubble Blaster integration is missing: {feature}")

pilot_source = (ROOT / "src/server/Services/PilotPriorityService.lua").read_text(encoding="utf-8")
for feature in (
    "function PilotPriorityService:AwardElimination(",
    "function PilotPriorityService:AwardWinner(",
    "function PilotPriorityService:ChooseController(",
    "function PilotPriorityService:RecordController(",
    "math.clamp((self.scores[player] or 0) + amount, 0, 100)",
    '"SkyfallPilotPriority"',
):
    require(feature in pilot_source, f"Pilot Priority service is missing: {feature}")
require("DataStoreService" not in pilot_source, "Pilot Priority must remain session-only")
require("function PilotPriorityService:Remove(" in pilot_source,
        "Pilot Priority session state must be cleared when a player leaves")

bubble_source = (ROOT / "src/server/Services/BubbleGunService.lua").read_text(encoding="utf-8")
for feature in (
    "function BubbleGunService:_buildLobbyStation(",
    'prompt.ActionText = "TRY FOR FREE"',
    "function BubbleGunService:GrantTrial(",
    "function BubbleGunService:GrantRunner(",
    "function BubbleGunService:_findTarget(",
    "function BubbleGunService:_holdTarget(",
    "function BubbleGunService:_releaseHold(",
    "function BubbleGunService:_handleShot(",
    "function BubbleGunService:_isValidShooter(",
    "function BubbleGunService:_cancelProjectilesForPlayer(",
    "Config.BUBBLE_GUN_RANGE",
    "Config.BUBBLE_GUN_COOLDOWN_SECONDS",
):
    require(feature in bubble_source, f"Bubble Blaster server implementation is missing: {feature}")
for forbidden in ("MarketplaceService", "InsertService", "DataStoreService"):
    require(forbidden not in bubble_source, f"Bubble Blaster must not use external assets or purchases: {forbidden}")
require("self.lifecycleToken" in bubble_source and "activeProjectiles" in bubble_source,
        "Bubble shots must be invalidated on round cleanup")

duplicate_cleanup = bubble_source.split("function BubbleGunService:_removeDuplicateTools(player, keep)", 1)[1].split("function BubbleGunService:_grant(player)", 1)[0]
require(sum(line.strip() == "end" for line in duplicate_cleanup.splitlines()) == 6,
        "Duplicate Tool cleanup must close each conditional, loop, and function exactly once")
require("record.direction * Config.BUBBLE_GUN_RANGE" in bubble_source,
        "Bubble target must be re-raycast for range and line-of-sight at impact")
require('targetPlayer:GetAttribute("SkyfallRole") == "Runner"' in bubble_source,
        "Human bubble targets must still be Runner role")
require("bot.humanoid.Health > 0" in bubble_source, "Bot targets must have a living Humanoid")
require("TakeDamage" not in bubble_source, "Bubble Blaster must not deal direct damage")
require("self.promptPart = displayHandle" in bubble_source,
        "Trial prompt must have a server-side distance reference")
require('(root.Position - self.promptPart.Position).Magnitude > maxDistance' in bubble_source,
        "Trial prompt spoofing must be rejected by server-side distance checks")
require('target.player:GetAttributeChangedSignal("SkyfallRole")' in bubble_source,
        "A target changing out of Runner role must release its bubble hold")
require('local isWinner = targetRole == "Winner"' in bubble_source,
        "Bubble cleanup must preserve winner anchoring")


round_source = (ROOT / "src/server/Services/RoundService.lua").read_text(encoding="utf-8")
for feature in (
    "function RoundService:_chooseController(",
    "function RoundService:RequestPlay(",
    "function RoundService:_readyPlayerCount(",
    "self.playRemote.OnServerEvent",
    "function RoundService:_getReadyPlayers(",
    "function RoundService:_chooseNextMapId(",
    "function RoundService:_getSoleSurvivor(",
    "function RoundService:_getLongestSurvivor(",
    "function RoundService:RequestDebugController(",
    "function RoundService:_activateDebugController(",
    "function RoundService:_restoreDebugController(",
    "self.debugControllerPlayer",
    "function RoundService:_recordSurvival(",
    "function RoundService:_isGrounded(",
    "function RoundService:IsHumanController(",
    "function RoundService:IsBotController(",
    "function RoundService:_setPlayerControllerHidden(",
    "player.ReplicationFocus = focusPart",
    "player.ReplicationFocus = nil",
    "local readyPlayers = readyPlayerOverride or self:_getReadyPlayers()",
    "function RoundService:IsWaiting()",
    "self.botService.onBotDied = function(diedBot)",
    "function RoundService:_getLivingHumanRunners(",
    "function RoundService:_resolveWinners(",
    "function RoundService:_getWinnerDetails(",
    "function RoundService:_moveEliminatedPlayerToLobby(player)",
    "function RoundService:_setArenaStreamingFocus(",
    "function RoundService:_resetArenaAfterRound(",
    "AddReplicationFocus",
    "RemoveReplicationFocus",
    "remainingPlayers = remainingPlayers",
    "remainingSeconds = remainingSeconds",
    "eliminatedPlayers = math.max(0, self.roundRunnerCount - remainingPlayers)",
):
    require(feature in round_source, f"Round feature is missing: {feature}")
sole_survivor_body = round_source.split("function RoundService:_getSoleSurvivor()", 1)[1].split("function RoundService:_isGrounded(", 1)[0]
require("self:_getLivingHumanRunners()" in sole_survivor_body,
        "Sole-survivor selection must use the same living-human filter as timeout winners")
longest_survivor_body = round_source.split("function RoundService:_getLongestSurvivor()", 1)[1].split("function RoundService:_getTimeoutWinners()", 1)[0]
require('value:GetAttribute("SkyfallRole") == "Runner"' in longest_survivor_body
        and "humanoid.Health > 0" in longest_survivor_body,
        "Longest-survivor fallback must reject dead or non-Runner human entries")
require("self.nextController" not in round_source, "Legacy nextController must not bypass Pilot Priority")
require('winners = self:_getWinnerDetails()' in round_source, "Round broadcasts must send safe winner name/role data only")
require('winner = table.concat(winnerNames, ", ")' in round_source, "All winner names must be represented in results")
require('local isAlive = isRunner and character ~= nil and humanoid ~= nil and humanoid.Health > 0' in round_source,
        "Only present, living human Runners may be co-winners")
require('self:_placePlayer(player, self:_lobbySpawnForPlayer(player))' in round_source,
        "A human Controller who wins must be restored from the hidden drone position")
require('self.elapsedSeconds >= Config.ROUND_SECONDS' in round_source, "The configured round timeout must remain active")
require('playerCount = self.phase == "Active" and remainingPlayers or allHumanCount + botCount' in round_source, "Active HUD count must use living arena runners only")
require("characterOverride or player.Character" in round_source, "Character placement must use the exact respawning character")
require("LoadCharacterAsync" in round_source, "Player respawn recovery must request a fresh character when Roblox respawn is missing")
require('if self.phase ~= "Active" then\n\t\tself:_scheduleRespawnRecovery(player, deadCharacter or player.Character)' in round_source, "Players also need respawn recovery while in the waiting lobby")
require("characterSerial" in round_source, "CharacterAdded placement must ignore stale character callbacks")
require("local parentDeadline = os.clock() + 10" in round_source, "CharacterAdded placement must wait for the model to enter Workspace")
round_run_body = round_source.split("function RoundService:_runRound()", 1)[1].split("function RoundService:_runLoop()", 1)[0]
phase_end_index = round_run_body.find('self.phase = canceled and "Waiting" or "Results"')
reset_end_index = round_run_body.find("self:_resetArenaAfterRound()")
results_countdown_index = round_run_body.find("for seconds = Config.RESULTS_SECONDS")
require(phase_end_index >= 0 and phase_end_index < reset_end_index < results_countdown_index, "Round-end map reset must run before the Results countdown")
bootstrap_source = (ROOT / "src/server/Bootstrap.server.lua").read_text(encoding="utf-8")
require("Players.CharacterAutoLoads = false" in bootstrap_source, "Automatic spawning must be disabled before round services initialize")
bind_player_body = round_source.split("function RoundService:_bindPlayer(player)", 1)[1].split("function RoundService:_readyPlayerCount()", 1)[0]
require(bind_player_body.find("player.CharacterAdded:Connect") < bind_player_body.find("player:LoadCharacterAsync()"), "Initial character loading must happen only after lobby placement is connected")
require("task.delay(Config.RESPAWN_TIME, function()" in round_source, "Manual respawn timing must use the configured delay")

admin_source = (ROOT / "src/server/Services/AdminFlightService.lua").read_text(encoding="utf-8")
for feature in (
    "function AdminFlightService.IsAuthorizedUserId(",
    "Enum.CreatorType.User",
    "AdminFlightService.IsAuthorizedUserId(player.UserId, self.creatorType, self.creatorId)",
    "and userId == creatorId",
    "LinearVelocity",
    "AlignOrientation",
    "Config.ADMIN_FLIGHT_SPEED",
):
    require(feature in admin_source, f"Admin flight feature is missing: {feature}")
for forbidden in ("MarketplaceService", "InsertService"):
    require(forbidden not in admin_source, f"Admin flight must not import external assets: {forbidden}")

laser_source = (ROOT / "src/server/Services/StrikeService.lua").read_text(encoding="utf-8")
for feature in (
    "function StrikeService:_handleHumanTarget(",
    "function StrikeService:_runBotController(",
    "AimAircraftAt(tile)",
    "ReturnAircraftLensHome(aimToken)",
    "self.targetRemote.OnServerEvent",
    "self.arena:BreakTile(tile, token)",
):
    require(feature in laser_source, f"Laser feature is missing: {feature}")
require("RepairTile" not in laser_source, "The laser must not repair damaged tiles")
require('"SkyfallLaserReadyAt"' in laser_source and "workspace:GetServerTimeNow() + Config.HUMAN_STRIKE_COOLDOWN_SECONDS" in laser_source, "Accepted human shots must publish a synchronized ready timestamp")
require("Config.LASER_EXTENSION_SECONDS + Config.LASER_HOLD_SECONDS" in laser_source, "Tile damage must wait for beam extension and impact hold")

round_source = (ROOT / "src/server/Services/RoundService.lua").read_text(encoding="utf-8")
for feature in (
    "root.Anchored = false",
    "root:SetNetworkOwner(player)",
    "humanoid.PlatformStand = false",
    "humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)",
):
    require(feature in round_source, f"Player movement recovery is missing: {feature}")

bubble_client_source = (ROOT / "src/client/BubbleGun.client.lua").read_text(encoding="utf-8")
for feature in (
    'WaitForChild("BubbleShot")',
    "instance.Activated:Connect(function()",
    "camera.CFrame.LookVector",
    'reticleGui.Name = "SkyfallBubbleReticle"',
):
    require(feature in bubble_client_source, f"Bubble Blaster mobile/desktop input is missing: {feature}")

hud_source = (ROOT / "src/client/HUD.client.lua").read_text(encoding="utf-8")
for feature in (
    "TimeLabel",
    "PlayersLabel",
    "ROUND\\n",
    "PLAYERS\\n",
    "panel.Visible = active",
    "screenGui.IgnoreGuiInset = true",
    "panel.Position = UDim2.new(0.5, 0, 0, 6)",
    "panel.Size = UDim2.new(0.72, 0, 0, Config.HUD_HEIGHT)",
    "camera.CameraType = Enum.CameraType.Custom",
    "camera.CameraSubject = humanoid",
    "Config.CONTROLLER_CAMERA_FOV",
    "Config.CONTROLLER_CAMERA_MARGIN",
    "Config.CONTROLLER_CAMERA_MIN_HEIGHT",
    "Config.CONTROLLER_CAMERA_SMOOTHING",
    "getControllerDronePosition",
    "RunService:BindToRenderStep",
    "SkyfallDroneCamera",
    "camera.Focus = CFrame.new(dronePosition)",
    "controllerCameraCFrame:Lerp(desiredCFrame, alpha)",
    "cachedControllerCameraHeight",
    "setControllerDroneHidden(true)",
    "LocalTransparencyModifier = hidden and 1 or 0",
    "camera.FieldOfViewMode = Enum.FieldOfViewMode.Vertical",
    "camera.CFrame = controllerCameraCFrame",
    "local desiredCFrame = CFrame.lookAt(",
    "Vector3.new(0, 0, -1)",
    "camera.Focus = CFrame.new(dronePosition)",
    "RunService:BindToRenderStep",
    "getControllerDronePosition",
    "controllerCameraCFrame:Lerp(desiredCFrame, alpha)",
    "camera.FieldOfView = Config.CONTROLLER_CAMERA_FOV",
    "previousFieldOfView = camera.FieldOfView",
    "previousFieldOfViewMode = camera.FieldOfViewMode",
    "camera.FieldOfView = previousFieldOfView",
    "targetRemote:FireServer(gridX, gridZ)",
    "LaserCooldownPanel",
    "LaserCooldownFill",
    "SkyfallLaserReadyAt",
    "GetServerTimeNow",
    "LASER READY",
):
    require(feature in hud_source, f"Overhead two-stat HUD feature is missing: {feature}")
for forbidden in ("RemainingLabel", "EliminatedLabel", "LEFT\\n", "OUT\\n", "cameraBack", "isPortrait"):
    require(forbidden not in hud_source, f"Unwanted HUD statistic or angled-camera code remains: {forbidden}")
require('remotes:WaitForChild("PlayRequest")' in hud_source, "Lobby Play remote is missing from mobile HUD")
require('playButton.Name = "PlayButton"' in hud_source, "Lobby Play button is missing")
require("playRemote:FireServer()" in hud_source, "Lobby Play button does not request a round")
require("panel.BackgroundTransparency = 0.46" in hud_source, "Mobile HUD must remain translucent")
for forbidden in (
    'PILOT: OFF',
    'PILOT: ON',
    'DRONE ',
    'PilotOptInButton',
    'SkyfallPilotPriorityHUD',
    'PilotPriorityLabel',
    'SkyfallPilotPriority',
    'updatePilotButton',
    'updatePilotPriority',
):
    require(forbidden not in hud_source, f"Removed pilot/drone HUD element is still present: {forbidden}")

audio_source = (ROOT / "src/client/Audio.client.lua").read_text(encoding="utf-8")
for feature in (
    "SoundService",
    "SkyfallBackgroundMusic",
    "Config.BACKGROUND_MUSIC_ID",
    "Config.ROUND_START_SOUND_ID",
    "playButton.Activated",
    'newState.phase == "Active"',
):
    require(feature in audio_source, f"Audio feature is missing: {feature}")
for audio_setting in (
    'Config.BACKGROUND_MUSIC_ID = "1841461968"',
    'Config.ROUND_START_SOUND_ID = "9119144736"',
    'Config.LASER_SOUND_ID = "9119772752"',
    "Config.AUDIO_MUSIC_VOLUME = 0.12",
    "Config.AUDIO_UI_VOLUME = 0.10",
    "Config.AUDIO_LASER_VOLUME = 0.14",
):
    require(audio_setting in config_source, f"Audio configuration is missing: {audio_setting}")

workspace_properties = tree.get("Workspace", {}).get("$properties", {})
require(workspace_properties.get("StreamingEnabled") is True, "Workspace instance streaming must be enabled")
require(workspace_properties.get("StreamingMinRadius") == 64, "Streaming minimum radius must remain conservative")
require(workspace_properties.get("StreamingTargetRadius") == 192, "Streaming target radius must be bounded for mobile")
require(workspace_properties.get("ModelStreamingBehavior") == "Improved", "Improved model streaming is required")
require(workspace_properties.get("StreamOutBehavior") == "Opportunistic", "Opportunistic stream-out is required")
require(workspace_properties.get("StreamingIntegrityMode") == "PauseOutsideLoadedArea", "Streaming integrity mode is required")
require(workspace_properties.get("StreamingIntegrityMode") == "PauseOutsideLoadedArea", "Streaming integrity protection is required")



admin_client_source = (ROOT / "src/client/AdminFlight.client.lua").read_text(encoding="utf-8")
for feature in (
    'remotes:WaitForChild("AdminFlight")',
    'flightRemote:FireServer("Enable")',
    'flightRemote:FireServer("Disable")',
    'flightRemote:FireServer("Move", direction, camera.CFrame.LookVector)',
    'flightRemote:FireServer("DebugController", desiredState)',
    '"DebugDroneToggle"',
    'player:GetAttribute("SkyfallIsAdmin") == true',
    'state.phase == "Waiting"',
):
    require(feature in admin_client_source, f"Admin mobile flight control is missing: {feature}")


map_rotation_source = (ROOT / "src/shared/MapRotation.lua").read_text(encoding="utf-8")
require("function MapRotation.GetMapId(roundNumber: number, mapCount: number): number" in map_rotation_source, "Pure map rotation policy is missing")
debug_policy_source = (ROOT / "src/shared/DebugControllerPolicy.lua").read_text(encoding="utf-8")
require("enabledAttribute == true" in debug_policy_source, "Debug controller must require an explicit true opt-in")
round_source = (ROOT / "src/server/Services/RoundService.lua").read_text(encoding="utf-8")
require("function RoundService:_isDebugControllerRequested(player)" in round_source, "RoundService debug opt-in predicate is missing")
require("self:_isDebugControllerRequested(debugPlayer)" in round_source, "RoundService selection must validate explicit debug opt-in")

workflow = (ROOT / ".github/workflows/validate.yml").read_text(encoding="utf-8")
require("pull_request:" in workflow, "Pull request validation trigger is missing")
require("selene src tests" in workflow, "Luau source and cloud test lint step is missing")
require("rojo build default.project.json" in workflow, "Rojo build step is missing")
require("upload-artifact" in workflow, "Build artifact upload step is missing")
require("ROBLOX_API_KEY" not in workflow, "Publishing secret must not be used by validation workflow")

upload_workflow = (ROOT / ".github/workflows/upload-private-test.yml").read_text(encoding="utf-8")
require('"7975091208"' in upload_workflow, "The original Universe ID must be preserved")
require('"104752078056182"' in upload_workflow, "The original Start Place ID must be preserved")
require("ROBLOX_API_KEY" in upload_workflow, "The private upload must use the existing publishing key")
require("ROBLOX_LUAU_TEST_API_KEY" in upload_workflow, "Cloud smoke tests must use a separate test key")

cloud_tests = (ROOT / "tests/cloud_smoke_tests.luau").read_text(encoding="utf-8")
for feature in (
    "Arena builds the 15x15 Classic starting arena in a two-map 30-player experience",
    "The Classic arena uses neutral lighting and connected stud geometry",
    "Players remain in the lobby until they request Play",
    "Creator flight authorization only grants the personal experience owner",
    "Owner debug control overrides first-round bot selection and can take over an active round",
    "Bot controller can be hidden and restored after a debug takeover",
    "Broken tiles remain broken",
    "Round-end cleanup instantly restores every destructible tile",
    "Lobby streaming focus is added and removed once without changing global radius",
    "Late joiners during an active round are routed to the observation lobby",
    "Round map rotation alternates Classic and Cyberpunk deterministically",
    "Cyberpunk map switches cleanly without changing the destructible grid",
    "A stale disabled debug toggle cannot override normal controller selection",
    "Round cleanup does not auto-ready a debug player after the toggle is disabled",
    "Debug drone request requires both the matching player and a true server attribute",
    "A departing debug controller restores its previous live controller",
    "The active HUD count only includes living arena runners",
    "A fallen bot is removed before the round broadcasts its survivor count",
    "Pilot Priority selects only manually opted-in humans and prevents a legacy controller override",
    "Legacy nextController cannot select an unready player",
    "Pilot Priority rewards use 54-second threshold, one reward per round, and cap at 100",
    "Pilot Priority tie-break favors the player who waited longest and avoids an immediate repeat",
    "Timeout gives every living human Runner a win and ten Pilot Priority points",
    "A single living human Runner wins before timeout even if bots remain",
    "If no Runner remains, a valid human Controller receives the win and priority reward",
    "Dead stale human Runners cannot win through survivor fallback",
    "Winner broadcast contains only safe names and role strings",
    "A winning human Controller is restored from hidden drone state",
    "Bubble Blaster server asset, lobby station, and training target exist",
    "Bubble Blaster grants one copy and accepts only the lobby training target while waiting",
    "Bubble Blaster server rejects invalid aim and enforces its cooldown",
    "Bubble projectile revalidates and hits the training target after travel",
    "Bubble hold restores movement and physics state exactly once",
    "three-second cooldown",
    "Four-cardinal lens aim tests",
    "The visual stack must declare 24 layers",
    "SKYFALL_CLOUD_TESTS_OK",
):
    require(feature in cloud_tests, f"Cloud smoke test is missing: {feature}")

floor_appearance_source = (ROOT / "src/server/Services/FloorAppearanceService.lua").read_text(encoding="utf-8")
for feature in ("function FloorAppearanceService.Capture(", "source.MaterialVariant", "source.Color", "source.Reflectance", "function FloorAppearanceService.Apply(", "profile.TopSurface", "profile.BottomSurface"):
    require(feature in floor_appearance_source, f"Lobby floor appearance transfer is missing: {feature}")

element_integration_source = (ROOT / "src/server/Services/ElementIntegrationService.lua").read_text(encoding="utf-8")
for feature in ("CollectionService:GetTagged(\"SkyfallElement\")", "SkyfallElementType", "Fire", "Water", "Earth", "Air", "TweenService:Create", "CanCollide = false", "CanQuery = false"):
    require(feature in element_integration_source, f"Four-element visual integration is missing: {feature}")

pilot_policy_source = (ROOT / "src/shared/PilotOptInPolicy.lua").read_text(encoding="utf-8")
control_policy_test = (ROOT / "tests/lune/update_023_control_state.luau").read_text(encoding="utf-8")
require("function PilotOptInPolicy.Filter(" in pilot_policy_source, "Explicit human pilot opt-in policy is missing")
require("function PilotOptInPolicy.ResolveCandidates(" in pilot_policy_source, "Manual-human/bot candidate resolver is missing")
require("UPDATE_023_CONTROL_STATE_TESTS_OK" in control_policy_test, "Update #23 control-state Lune test is missing")
require('player:SetAttribute("SkyfallPilotOptIn", false)' in round_source, "Players must default to no pilot opt-in")
require('function RoundService:RequestPilotOptIn(' in round_source, "Server pilot opt-in handler is missing")
require('candidate:GetAttribute("SkyfallPilotOptIn") == true' in round_source, "Only opted-in human players may be selected as controller")
require("PilotOptInPolicy.ResolveCandidates(" in round_source, "Controller selection must resolve manual humans separately from bot fallback")
require('local ready = self.readyPlayers[player] == true' in round_source, "Human aircraft opt-in must be limited to players who joined the round")
require('player:SetAttribute("SkyfallPilotOptIn", false)' in round_source, "A new Play request must clear stale aircraft selection")
require('player:SetAttribute("SkyfallPilotOptIn", false)' in round_source.split("function RoundService:_clearReadyPlayers()", 1)[1], "Round cleanup must clear manual aircraft choice")
require('player:SetAttribute("SkyfallAircraftControlActive", false)' in round_source, "Player aircraft control state must default to off")
require('player:SetAttribute("SkyfallAircraftControlActive", hidden == true)' in round_source, "Server must own the aircraft-control active state")
require('player:GetAttribute("SkyfallAircraftControlActive") == true' in hud_source, "The client camera must require explicit server aircraft-control state")
clear_ready_source = round_source.split("function RoundService:_clearReadyPlayers()", 1)[1].split(
    "function RoundService:_setPlayerControllerHidden", 1
)[0]
require('debugPlayer:SetAttribute("SkyfallDebugDroneEnabled", false)' in clear_ready_source, "Owner debug mode must reset at round cleanup")
require("self.readyPlayers[debugPlayer] = true" not in clear_ready_source, "Owner debug mode must not auto-ready across rounds")
require("self.debugControllerPlayer = nil" in clear_ready_source, "Owner debug pointer must clear at round cleanup")
require("SkyfallPilotOptIn" in clear_ready_source, "Manual aircraft opt-in must be cleared at round cleanup")
require('Name = "AircraftModeIcon"' in hud_source, "A compact manual aircraft mode icon is missing")
require('aircraftModeButton.Text = "✈"' in hud_source, "Manual aircraft control must be selected from an icon, not the removed text status")
require('local shouldUseControllerCamera = isAircraftController()' in hud_source, "The aircraft camera must use the explicit control-state guard")
require('lune = "lune-org/lune@0.11.1"' in (ROOT / "rokit.toml").read_text(encoding="utf-8"), "Lune must be pinned in Rokit")
require("lune run tests/lune/update_022_policy.luau" in (ROOT / ".github/workflows/validate.yml").read_text(encoding="utf-8"), "CI must run Update #22 policy tests")

cyberpunk_pillar_source = (ROOT / "src/server/Services/CyberpunkPillarService.lua").read_text(encoding="utf-8")
for feature in (
    "function CyberpunkPillarService.Build(",
    "PylonFoundation_",
    "PylonFootBridgeX_",
    "PylonFootBridgeZ_",
    "PylonPerimeterJoint_",
    "PylonCrownBase_",
    "PylonCrownCap_",
    "PylonLightSpine_",
    "FloorAppearanceService.ApplySurface(part, profile)",
    "for sideX = -1, 1, 2 do",
    "for sideZ = -1, 1, 2 do",
):
    require(feature in cyberpunk_pillar_source, f"Integrated four-pillar system is missing: {feature}")

require("CyberpunkPillarService.Build(folder, theme, center, half, theme.floorAppearanceProfile)" in arena_source, "Arena must build the four integrated corner pillars")
for feature in (
    'FloorAppearanceService.ApplySurface(part, theme.floorAppearanceProfile)',
):
    require(feature in arena_source, f"Cyberpunk architecture surface profile is missing: {feature}")
for feature in (
    'ClockTime = 14',
    'Name = "SkyfallGlobalDaySky"',
    'StarCount = 0',
    'MoonAngularSize = 0',
    'Density = 0.07',
    'Haze = 0.42',
    'Glare = 0.035',
):
    require(feature in lighting_profile_source, f"Shared daylight profile is missing: {feature}")
require("function FloorAppearanceService.ApplySurface(" in floor_appearance_source, "Surface-only lobby material profile application is missing")

print("Skyfall Arena structural and gameplay validation passed.")
