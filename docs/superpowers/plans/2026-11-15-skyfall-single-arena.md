# Skyfall Single-Arena Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox syntax for tracking.

**Goal:** Replace the rotating maps with one polished Sunspire arena and a separate waiting garden, while preserving the three bots and refined golden drone.

**Architecture:** Keep the current ArenaService, RoundService, BotService, StrikeService, and HUD boundaries. Make ArenaService generate one static environment, let RoundService own 180-second countdown and survivor tracking, use BotService for the three existing NPCs, and render the blue drone-to-tile Beam from server-created attachments.

**Tech Stack:** Luau, Roblox Instances, PathfindingService, Rojo, Selene, GitHub Actions.

**Spec:** docs/superpowers/specs/2026-11-15-skyfall-single-arena-design.md

## Global Constraints
- Keep Universe ID 7975091208 and Start Place ID 104752078056182.
- Keep the experience Private and do not create a new place.
- Do not publish automatically.
- Keep exactly three AI bots and a 15x15 floor.
- Active round duration is 180 seconds, with a three-second human laser cooldown.
- No unverified third-party model imports or executable scripts.

## Review Focus
- A solo human should enter as a runner while a bot controls the first round.
- Hidden controller avatars must be restored when the round ends or their role changes.
- Eliminated bot survival time must be recorded before it is sent to the lobby.
- Destroyed floor tiles must stay broken until the next round.
- The lobby must remain reachable while the arena has no bridge or open connector.

---

### Task 1: Gameplay configuration and regression checks

**Files:**
- Modify: `src/shared/GameConfig.lua`
- Modify: `tools/validate_project.py`
- Test: `tests/cloud_smoke_tests.luau`

- [ ] Assert one map, three bots, and a 180-second round.
- [ ] Assert four HUD metrics and a top safe-area panel.
- [ ] Assert the custom Sky, independent lobby, red marker, blue Beam, and hidden controller design.
- [ ] Replace all five-map smoke checks with single-map checks.

### Task 2: One arena and separate waiting garden

**Files:**
- Modify: `src/server/Services/ArenaService.lua`

- [ ] Keep the current 15x15 tile floor and one Sunspire theme.
- [ ] Replace five-map decoration logic with one coherent daytime environment.
- [ ] Remove the lobby-to-arena bridge and keep lobby geometry separate.
- [ ] Add the six-face skybox using the official Roblox documentation's sample texture IDs.
- [ ] Keep the golden sphere geometry, remove the visible pilot platform.
- [ ] Add a short-lived blue/cyan Beam from the sphere underside to the tile. Keep the target marker red.
- [ ] Preserve broken-tile persistence and reset only on the next round.

### Task 3: Three bots and controller visibility

**Files:**
- Modify: `src/server/Services/BotService.lua`
- Modify: `src/server/Services/RoundService.lua`

- [ ] Keep the existing three PathfindingService bots and their different survival profiles.
- [ ] Remove floating bot nameplates and unverified hair accessory imports; retain procedural hair.
- [ ] Hide the controller model away from the active arena and restore it in the waiting garden.
- [ ] On the first round with one human, select a bot as controller.
- [ ] Track each runner's survival seconds, including runners eliminated between loop ticks.
- [ ] Select the longest-surviving runner as next round's controller.

### Task 4: Three-minute round and mobile HUD

**Files:**
- Modify: `src/server/Services/RoundService.lua`
- Modify: `src/client/HUD.client.lua`

- [ ] Start the active timer at 180 and count down to zero.
- [ ] End early if exactly one runner remains.
- [ ] At timeout, select the runner with the highest recorded survival duration.
- [ ] Display TIME, PLAYERS, LEFT, and OUT only during an active round.
- [ ] Keep the four-cell panel compact at the top, within the device safe area.

### Task 5: Documentation and verification

**Files:**
- Modify: `README.md`
- Modify: `tools/validate_project.py`
- Modify: `tests/cloud_smoke_tests.luau`

- [ ] Update documentation to describe the one-map match flow.
- [ ] Run Python structure validation, Selene lint, and Rojo build in GitHub Actions.
- [ ] Review the full PR diff for old map references, scripts/assets, pilot platform, bridge, and broken-tile repair paths.
- [ ] Record that actual Roblox mobile visuals, physics, camera, and NPC navigation still require an in-game playtest.
