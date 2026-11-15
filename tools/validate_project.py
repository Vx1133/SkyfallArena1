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
    "src/server/Bootstrap.server.lua",
    "src/server/Services/ArenaService.lua",
    "src/server/Services/BotService.lua",
    "src/server/Services/RoundService.lua",
    "src/server/Services/StrikeService.lua",
    "src/client/HUD.client.lua",
    "src/client/Audio.client.lua",
    "tests/cloud_smoke_tests.luau",
    "docs/CLOUD_PUBLISHING.md",
    "src/server/Services/AdminFlightService.lua",
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
    "Config.ADMIN_FLIGHT_SPEED = 52",
    "Config.HUD_MAX_WIDTH = 224",
    "Config.HUD_HEIGHT = 30",
    "Config.GRID_SIZE = 15",
    "Config.MAX_PLAYER_CAPACITY = 30",
    "Config.MAP_COUNT = 1",
    "Config.ROUND_SECONDS = 180",
    "Config.HUMAN_STRIKE_COOLDOWN_SECONDS = 3",
    "Config.CONTROLLER_CAMERA_FOV = 70",
    "Config.CONTROLLER_CAMERA_MARGIN = 8",
    "Config.CONTROLLER_CAMERA_MIN_HEIGHT = 132",
    "Config.RESPAWN_TIME",
):
    require(setting in config_source, f"Required gameplay setting is missing: {setting}")
require("TILE_REPAIR_SECONDS" not in config_source, "Broken floor tiles must not have a repair timer")
require("OVERTIME_" not in config_source, "The three-minute round must not use overtime modifiers")

arena_source = (ROOT / "src/server/Services/ArenaService.lua").read_text(encoding="utf-8")
for map_name in ("SKYFALL CLASSIC ARENA",):
    require(map_name in arena_source, f"Map design is missing: {map_name}")
for feature in (
    "function ArenaService:_buildLobby(",
    "function ArenaService:_buildAircraft(",
    "function ArenaService:_buildMapDecoration(",
    "function ArenaService:SetMap(",
    "function ArenaService:ResetTiles(",
    "function ArenaService:GetControllerSpawnCFrame(",
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
    "Enum.Material.Neon",
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
for forbidden_lighting in (
    'Instance.new("Sky")',
    'Instance.new("Atmosphere")',
    'Instance.new("BloomEffect")',
    'Instance.new("ColorCorrectionEffect")',
    'Instance.new("SunRaysEffect")',
    'Instance.new("Clouds")',
):
    require(forbidden_lighting not in arena_source, f"Custom lighting effect must be removed: {forbidden_lighting}")
require("basePart.TopSurface = Enum.SurfaceType.Studs" in arena_source, "Native Classic stud surfaces are missing")
require("tile.TopSurface = hidden and Enum.SurfaceType.Smooth or Enum.SurfaceType.Studs" in arena_source, "Broken tile surface reset is missing")
require("part.CastShadow = false" in arena_source, "Static map part shadows should be disabled")
require("warningLight.Brightness" not in arena_source, "Per-target dynamic warning lights should be removed")
for neutral_setting in (
    "Lighting.Brightness = 2",
    "Lighting.ClockTime = 14",
    "Lighting.Ambient = Color3.fromRGB(0, 0, 0)",
    "Lighting.OutdoorAmbient = Color3.fromRGB(127, 127, 127)",
    "Lighting.ExposureCompensation = 0",
    "Lighting.EnvironmentDiffuseScale = 0",
    "Lighting.EnvironmentSpecularScale = 0",
):
    require(neutral_setting in arena_source, f"Neutral lighting setting is missing: {neutral_setting}")
require('outerBeam.Name = "BlueLaserOuter"' in arena_source, "The drone blue beam is missing")
require('innerBeam.Name = "BlueLaserCore"' in arena_source, "The drone blue-white core beam is missing")
require('tile.Color = Color3.fromRGB(255, 55, 75)' in arena_source, "Targeted tiles must be marked red")
require("local lensNormal = Vector3.new(0, -1, 0)" in arena_source, "Drone lens normal must point vertically down")
require("\t\t\t\t0.34," in arena_source, "Drone reticle must be placed on the outward underside of the lens")
require("\t\t\t\t-0.34," not in arena_source, "Drone reticle must not be hidden inside the sphere")
require("function ArenaService:_buildMapDecoration(theme)" in arena_source, "Classic arena decoration builder is missing")
require("Vector3.new(width + 26, 2, width + 26)" in arena_source, "The arena foundation must be thin")
require("support.CanCollide = false" in arena_source, "The foundation must not catch falling players")
require("ControllerLensGimbal" in arena_source and "Motor6D" in arena_source, "Drone lens needs a motorized aiming joint")
require("function ArenaService:AimAircraftAt(tile)" in arena_source, "Drone lens aiming method is missing")
require("function ArenaService:ReturnAircraftLensHome(token)" in arena_source, "Drone lens return-home method is missing")
require("TweenService:Create" in arena_source and "aircraftHoverTween" in arena_source, "Drone body hover animation is missing")
require("ParticleEmitter" in arena_source and "ImpactShockwave" in arena_source, "Laser impact particle and shockwave effects are missing")
require("BlueLaserHalo" in arena_source, "Layered laser outer glow is missing")
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
for feature in ("function BotService:_setBotHidden(", 'description.HairAccessory = ""', "if self.onBotDied then", "self.onBotDied(bot)"):
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
    "function RoundService:_recordSurvival(",
    "function RoundService:_isGrounded(",
    "function RoundService:IsHumanController(",
    "function RoundService:IsBotController(",
    "function RoundService:_setPlayerControllerHidden(",
    "player.ReplicationFocus = focusPart",
    "player.ReplicationFocus = nil",
    "self.roundNumber == 1 and #self:_getReadyPlayers() == 1",
    "function RoundService:IsWaiting()",
    "self.botService.onBotDied = function(diedBot)",
    "self.nextController = self.winnerCandidate",
    "self:_moveEliminatedPlayerToLobby(player)",
    "remainingPlayers = remainingPlayers",
    "remainingSeconds = remainingSeconds",
    "eliminatedPlayers = math.max(0, self.roundRunnerCount - remainingPlayers)",
):
    require(feature in round_source, f"Round feature is missing: {feature}")
require('playerCount = self.phase == "Active" and remainingPlayers or allHumanCount + botCount' in round_source, "Active HUD count must use living arena runners only")
require("characterOverride or player.Character" in round_source, "Character placement must use the exact respawning character")
require("LoadCharacterAsync" in round_source, "Player respawn recovery must request a fresh character when Roblox respawn is missing")
require("characterSerial" in round_source, "CharacterAdded placement must ignore stale character callbacks")

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

round_source = (ROOT / "src/server/Services/RoundService.lua").read_text(encoding="utf-8")
for feature in (
    "root.Anchored = false",
    "root:SetNetworkOwner(player)",
    "humanoid.PlatformStand = false",
    "humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)",
):
    require(feature in round_source, f"Player movement recovery is missing: {feature}")

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
    "cachedControllerCameraHeight",
    "setControllerDroneHidden(true)",
    "LocalTransparencyModifier = hidden and 1 or 0",
    "camera.FieldOfViewMode = Enum.FieldOfViewMode.Vertical",
    "camera.CFrame = CFrame.lookAt(",
    "Vector3.new(0, 0, -1)",
    "camera.Focus = CFrame.new(Config.ARENA_CENTER)",
    "camera.FieldOfView = Config.CONTROLLER_CAMERA_FOV",
    "previousFieldOfView = camera.FieldOfView",
    "previousFieldOfViewMode = camera.FieldOfViewMode",
    "camera.FieldOfView = previousFieldOfView",
    "targetRemote:FireServer(gridX, gridZ)",
):
    require(feature in hud_source, f"Overhead two-stat HUD feature is missing: {feature}")
for forbidden in ("RemainingLabel", "EliminatedLabel", "LEFT\\n", "OUT\\n", "cameraBack", "isPortrait"):
    require(forbidden not in hud_source, f"Unwanted HUD statistic or angled-camera code remains: {forbidden}")
require('remotes:WaitForChild("PlayRequest")' in hud_source, "Lobby Play remote is missing from mobile HUD")
require('playButton.Name = "PlayButton"' in hud_source, "Lobby Play button is missing")
require("playRemote:FireServer()" in hud_source, "Lobby Play button does not request a round")
require("panel.BackgroundTransparency = 0.46" in hud_source, "Mobile HUD must remain translucent")

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
    'player:GetAttribute("SkyfallIsAdmin") == true',
    'state.phase == "Waiting"',
):
    require(feature in admin_client_source, f"Admin mobile flight control is missing: {feature}")

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
    "Arena builds one 15x15 destructible Classic arena",
    "The Classic arena uses neutral lighting and connected stud geometry",
    "Players remain in the lobby until they request Play",
    "Creator flight authorization only grants the personal experience owner",
    "Broken tiles remain broken",
    "The one map restores the floor only when a new round loads",
    "The next-round map remains the one fixed Classic arena",
    "The active HUD count only includes living arena runners",
    "A fallen bot is removed before the round broadcasts its survivor count",
    "The longest-surviving runner is selected as the next controller",
    "three-second cooldown",
    "SKYFALL_CLOUD_TESTS_OK",
):
    require(feature in cloud_tests, f"Cloud smoke test is missing: {feature}")

print("Skyfall Arena structural and gameplay validation passed.")
