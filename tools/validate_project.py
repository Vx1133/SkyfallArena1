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
require(
    tree["StarterPlayer"]["StarterPlayerScripts"]["SkyfallClient"].get("$path") == "src/client",
    "Client source mapping is missing",
)

rokit = tomllib.loads((ROOT / "rokit.toml").read_text(encoding="utf-8"))
tools = rokit.get("tools", {})
require(tools.get("rojo") == "rojo-rbx/rojo@7.7.1", "Rojo must remain pinned to 7.7.1")
require(tools.get("selene") == "Kampfkarren/selene@0.32.0", "Selene must remain pinned to 0.32.0")

required_files = [
    "src/shared/GameConfig.lua",
    "src/server/Bootstrap.server.lua",
    "src/server/Services/ArenaService.lua",
    "src/server/Services/RoundService.lua",
    "src/server/Services/StrikeService.lua",
    "src/server/Services/SpeedBoostService.lua",
    "src/client/HUD.client.lua",
    "docs/CLOUD_PUBLISHING.md",
]

for relative_path in required_files:
    path = ROOT / relative_path
    require(path.is_file(), f"Required project file is missing: {relative_path}")
    require(path.stat().st_size > 0, f"Required project file is empty: {relative_path}")

speed_service = (ROOT / "src/server/Services/SpeedBoostService.lua").read_text(encoding="utf-8")
arena_service = (ROOT / "src/server/Services/ArenaService.lua").read_text(encoding="utf-8")
hud_source = (ROOT / "src/client/HUD.client.lua").read_text(encoding="utf-8")
require("OnServerEvent" in speed_service, "Server-side speed boost handler is missing")
require("SPEED_BOOST_DURATION" in speed_service, "Speed boost duration setting is missing")
require("ParkourCourse" in arena_service, "Parkour course generation is missing")
require("SpeedBoostButton" in hud_source, "Speed boost button is missing")
require("TweenService" in hud_source, "Animated speed icon is missing")

workflow = (ROOT / ".github/workflows/validate.yml").read_text(encoding="utf-8")
require("pull_request:" in workflow, "Pull request validation trigger is missing")
require("selene src" in workflow, "Luau lint step is missing")
require("rojo build default.project.json" in workflow, "Rojo build step is missing")
require("upload-artifact" in workflow, "Build artifact upload step is missing")
require("ROBLOX_API_KEY" not in workflow, "Publishing secret must not be used by validation workflow")

print("Skyfall Arena structural validation passed.")
