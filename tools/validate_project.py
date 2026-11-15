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
    "tests/cloud_smoke_tests.luau",
    "docs/CLOUD_PUBLISHING.md",
]
for relative_path in required_files:
    path = ROOT / relative_path
    require(path.is_file(), f"Required project file is missing: {relative_path}")
    require(path.stat().st_size > 0, f"Required project file is empty: {relative_path}")

config_source = (ROOT / "src/shared/GameConfig.lua").read_text(encoding="utf-8")
for setting in (
    "Config.MIN_PLAYERS = 1",
    "Config.BOT_COUNT = 3",
    "Config.GRID_SIZE = 15",
    "Config.MAX_PLAYER_CAPACITY = 30",
    "Config.MAP_COUNT = 1",
    "Config.ROUND_SECONDS = 180",
    "Config.HUMAN_STRIKE_COOLDOWN_SECONDS = 3",
    "Config.CONTROLLER_CAMERA_HEIGHT = 145",
    "Config.CONTROLLER_CAMERA_BACK = 8",
    "Config.CONTROLLER_CAMERA_FOV = 110",
    "Config.CONTROLLER_CAMERA_LANDSCAPE_HEIGHT = 130",
    "Config.CONTROLLER_CAMERA_LANDSCAPE_BACK = 130",
    "Config.CONTROLLER_CAMERA_LANDSCAPE_FOV = 44",
    "Config.RESPAWN_TIME",
):
    require(setting in config_source, f"Required gameplay setting is missing: {setting}")
require("TILE_REPAIR_SECONDS" not in config_source, "Broken floor tiles must not have a repair timer")
require("OVERTIME_" not in config_source, "The three-minute round must not use overtime modifiers")

arena_source = (ROOT / "src/server/Services/ArenaService.lua").read_text(encoding="utf-8")
for map_name in ("SKYFALL SUNSPIRE",):
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
    "LobbyWater",
    "SquareStud_",
):
    require(feature in arena_source, f"Arena feature is missing: {feature}")
require(arena_source.count("tileMaterial = Enum.Material.SmoothPlastic") == 1, "The single destructible floor must use a clean studded plastic material")
for feature in (
    '"ArmorPlate_" .. group.name .. "_"',
    'name = "Upper"',
    'name = "Lower"',
    'addLensReticleRing("LensReticleRing_Outer"',
    'addLensReticleRing("LensReticleRing_Inner"',
):
    require(feature in arena_source, f"Golden sphere detail is missing: {feature}")
for forbidden in (
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
for sky_face in (
    'sky.SkyboxBk = "rbxassetid://162001887"',
    'sky.SkyboxDn = "rbxassetid://161998893"',
    'sky.SkyboxFt = "rbxassetid://162001897"',
    'sky.SkyboxLf = "rbxassetid://162001904"',
    'sky.SkyboxRt = "rbxassetid://162001919"',
    'sky.SkyboxUp = "rbxassetid://162001926"',
):
    require(sky_face in arena_source, f"Custom six-face skybox setting is missing: {sky_face}")
require('outerBeam.Name = "BlueLaserOuter"' in arena_source, "The drone blue beam is missing")
require('innerBeam.Name = "BlueLaserCore"' in arena_source, "The drone blue-white core beam is missing")
require('tile.Color = Color3.fromRGB(255, 55, 75)' in arena_source, "Targeted tiles must be marked red")
require("function ArenaService:_buildMapDecoration(theme)" in arena_source, "Sunspire map decoration builder is missing")
require("function ArenaService:RepairTile(" not in arena_source, "Tiles should only be restored by the next round")
map_set_body = arena_source.split("function ArenaService:SetMap(", 1)[1].split("function ArenaService:GetMapName(", 1)[0]
require('tile:SetAttribute("IsBroken", false)' in map_set_body, "The next map must restore broken state")
require("tile.CanCollide = true" in map_set_body, "The next map must restore floor collision")

bot_source = (ROOT / "src/server/Services/BotService.lua").read_text(encoding="utf-8")
for bot_name in ("Atlas", "Nova", "Rook"):
    require(f'name = "{bot_name}"' in bot_source, f"AI bot profile is missing: {bot_name}")
for feature in ("function BotService:_setBotHidden(", 'description.HairAccessory = ""'):
    require(feature in bot_source, f"Bot visibility or safe procedural appearance feature is missing: {feature}")
for forbidden in ("hairId", "BillboardGui", "BotNameplate", "InsertService", "MarketplaceService"):
    require(forbidden not in bot_source, f"Unwanted external asset or bot label code remains: {forbidden}")

round_source = (ROOT / "src/server/Services/RoundService.lua").read_text(encoding="utf-8")
for feature in (
    "function RoundService:_chooseController(",
    "function RoundService:_chooseNextMapId(",
    "function RoundService:_getSoleSurvivor(",
    "function RoundService:_getLongestSurvivor(",
    "function RoundService:_recordSurvival(",
    "function RoundService:_isGrounded(",
    "function RoundService:IsHumanController(",
    "function RoundService:IsBotController(",
    "function RoundService:_setPlayerControllerHidden(",
    "self.roundNumber == 1 and #Players:GetPlayers() == 1",
    "self.nextController = self.winnerCandidate",
    "self:_moveEliminatedPlayerToLobby(player)",
    "remainingPlayers = remainingPlayers",
    "remainingSeconds = remainingSeconds",
    "eliminatedPlayers = math.max(0, self.roundRunnerCount - remainingPlayers)",
):
    require(feature in round_source, f"Round feature is missing: {feature}")

laser_source = (ROOT / "src/server/Services/StrikeService.lua").read_text(encoding="utf-8")
for feature in (
    "function StrikeService:_handleHumanTarget(",
    "function StrikeService:_runBotController(",
    "self.targetRemote.OnServerEvent",
    "self.arena:BreakTile(tile, token)",
):
    require(feature in laser_source, f"Laser feature is missing: {feature}")
require("RepairTile" not in laser_source, "The laser must not repair damaged tiles")

hud_source = (ROOT / "src/client/HUD.client.lua").read_text(encoding="utf-8")
for feature in (
    "TimeLabel",
    "PlayersLabel",
    "RemainingLabel",
    "EliminatedLabel",
    "OUT\\n",
    "state.remainingSeconds",
    "panel.Visible = active",
    "Config.CONTROLLER_CAMERA_HEIGHT",
    "Config.CONTROLLER_CAMERA_FOV",
    "camera.ViewportSize.X < camera.ViewportSize.Y",
    "camera.CFrame = CFrame.lookAt(",
    "camera.Focus = CFrame.new(Config.ARENA_CENTER)",
    "camera.FieldOfView = cameraFov",
    "previousFieldOfView = camera.FieldOfView",
    "camera.FieldOfView = previousFieldOfView",
    "targetRemote:FireServer(gridX, gridZ)",
):
    require(feature in hud_source, f"Mobile HUD or controller camera feature is missing: {feature}")
for forbidden in ('"Title"', '"Role"', '"Hint"', '"Status"'):
    require(forbidden not in hud_source, f"Unwanted HUD label remains: {forbidden}")

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
    "Arena builds one 15x15 destructible Sunspire map",
    "The single Sunspire map uses daytime lighting",
    "Broken tiles remain broken",
    "The one map restores the floor only when a new round loads",
    "The next-round map remains the one fixed Sunspire arena",
    "The round state counts down from 180 seconds",
    "The longest-surviving runner is selected as the next controller",
    "three-second cooldown",
    "SKYFALL_CLOUD_TESTS_OK",
):
    require(feature in cloud_tests, f"Cloud smoke test is missing: {feature}")

print("Skyfall Arena structural and gameplay validation passed.")
