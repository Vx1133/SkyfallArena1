# Skyfall Classic Studs and Lobby-First Update Implementation Plan

> **For agentic workers:** Use this plan task-by-task in the current GitHub feature branch. Steps use checkbox syntax.

**Goal:** Rebuild Skyfall Arena in a Classic Roblox stud style, use ten bots, wait for a player Play action, and add creator-only inspection flight.

**Architecture:** Keep the current ArenaService, BotService, RoundService, StrikeService, and HUD boundaries. Add AdminFlightService with server-side creator validation and AdminFlight.client.lua for keyboard/mobile controls. Add PlayRequest to the existing round state flow. Update smoke/structure validation for every contract.

**Tech Stack:** Luau, Roblox Instances, HumanoidDescription, PathfindingService, LinearVelocity, AlignOrientation, RemoteEvents, Rojo, Selene.

**Spec:** docs/superpowers/specs/2026-11-15-classic-studs-lobby-start.md

## Global Constraints
- Preserve Universe ID 7975091208 and Start Place ID 104752078056182.
- Keep the experience Private and do not publish automatically.
- Keep the 15x15 destructible floor, 180-second rounds, 3-second human laser cooldown, blue laser, and longest-survivor controller selection.
- Use exactly 10 bots, one fixed map, zero floor tile gap.
- Do not import third-party model packages or executable scripts.
- Admin flight must be validated by the server against personal CreatorType/UserId.

## Review Focus
- Joining must not mark a player ready or start an intermission.
- Ready players must be the only human participants moved into a round.
- A player leaving during intermission must not leave a stale ready entry.
- Bot controller pilot must remain hidden while the gold orb stays visible.
- A malicious client must not enable or steer admin flight as a non-owner.
- Flight constraints must be removed on toggle-off, character respawn, player removal, and phase change.
- Floor tiles must remain contiguous and broken tiles must not repair until the next round.

---

### Task 1: Configuration, neutral lighting, and classic connected arena

**Files:**
- Modify: `src/shared/GameConfig.lua`
- Modify: `src/server/Services/ArenaService.lua`
- Test: `tests/cloud_smoke_tests.luau`
- Test: `tools/validate_project.py`

- [ ] Set BOT_COUNT=10, TILE_GAP=0, Plastic floor material, 15x15 pattern and compact HUD sizing.
- [ ] Replace custom sky/effects with neutral Lighting values and remove project-created Sky/Atmosphere/Clouds/ColorCorrection/Bloom/SunRays.
- [ ] Rebuild the lobby and map decor as simple Classic Stud geometry with a continuous sub-floor and no bridge.
- [ ] Generate nine evenly aligned studs on each tile so the full 15x15 floor reads as a continuous stud grid.
- [ ] Move the red lens to the orb underside and set its normal to (0,-1,0).
- [ ] Add tests for zero tile gaps, connected support, no custom sky/effects, red underside lens, lobby separation.

### Task 2: Ten built-in Roblox bot rigs

**Files:**
- Modify: `src/server/Services/BotService.lua`
- Modify: `tools/validate_project.py`
- Test: `tests/cloud_smoke_tests.luau`

- [ ] Instantiate exactly Config.BOT_COUNT bots by reusing the three simple movement profiles.
- [ ] Give repeat profiles unique names and retain distinct walk speeds, reaction delays, caution, and pathfinding behavior.
- [ ] Keep Players:CreateHumanoidModelFromDescriptionAsync and remove procedural fallback hair and asset IDs.
- [ ] Add tests for count=10, unique names, and no custom hair/accessory ID imports.

### Task 3: Lobby-first Play request flow

**Files:**
- Modify: `src/server/Bootstrap.server.lua`
- Modify: `src/server/Services/RoundService.lua`
- Modify: `src/client/HUD.client.lua`
- Modify: `tools/validate_project.py`
- Test: `tests/cloud_smoke_tests.luau`

- [ ] Create a PlayRequest RemoteEvent and pass it into RoundService.
- [ ] Add RequestPlay(player), ready-state tracking, and ready player enumeration.
- [ ] Keep all joining players in Waiting; remove automatic start on PlayerAdded.
- [ ] Begin intermission only when at least one valid human opts in.
- [ ] Only ready humans join the next round. Keep all others in the lobby.
- [ ] Clear readiness after a round and when a player leaves.
- [ ] Add a compact translucent PLAY/READY control to the waiting lobby UI.

### Task 4: Creator-only flight inspection

**Files:**
- Create: `src/server/Services/AdminFlightService.lua`
- Create: `src/client/AdminFlight.client.lua`
- Modify: `src/server/Bootstrap.server.lua`
- Modify: `src/server/Services/RoundService.lua`
- Modify: `src/shared/GameConfig.lua`
- Modify: `tools/validate_project.py`
- Test: `tests/cloud_smoke_tests.luau`

- [ ] Add AdminFlight RemoteEvent.
- [ ] Authorize only a personal creator: CreatorType.User and UserId==CreatorId. Do not auto-authorize group members.
- [ ] Support Enable, Disable, and clamped Move commands only in Waiting.
- [ ] Apply LinearVelocity and AlignOrientation on the server, with speed clamp and automatic cleanup.
- [ ] Add a FLY toggle and UP/DOWN touch controls for the authorized owner; use camera-relative movement and keyboard support.
- [ ] Automatically disable flight at intermission, round start, respawn, and player removal.
- [ ] Add allow/deny tests for owner/non-owner/group creator cases.

### Task 5: Compact HUD, documentation, and full verification

**Files:**
- Modify: `src/client/HUD.client.lua`
- Modify: `README.md`
- Modify: `tools/validate_project.py`
- Modify: `tests/cloud_smoke_tests.luau`

- [ ] Keep the round HUD near the top safe area, reduce height/width, and increase translucency.
- [ ] Show timer/participants only while Active. Keep Play/Flight controls confined to Waiting.
- [ ] Update documentation to describe the 10-bot lobby-first flow and owner-only flight.
- [ ] Run structural validation, Selene lint, and Rojo build on the final branch head.
- [ ] Inspect the complete PR diff for old Sunspire sky/effects, fallback hair, automatic PlayerAdded starts, non-owner flight paths, nonzero tile gap, imports, and accidental publication.
- [ ] Mark actual Roblox visual/physics/touch playtesting as unverified until the private place is opened on a device.
