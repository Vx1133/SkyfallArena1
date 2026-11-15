# Skyfall Arena Survivor and Drone Upgrade Implementation Plan

> **For agentic workers:** Execute these steps in order. Tests are updated before the implementation; validate each change before proceeding.

**Goal:** Correct the active survivor count and player respawn flow, reduce the arena foundation, and add low-cost aiming and laser effects to the golden drone.

**Architecture:** The server remains authoritative for round membership, character placement, and elimination. The drone uses one anchored root, welded body parts, a Motor6D lens gimbal, and TweenService-driven hover/aim. Laser effects are short-lived and cleaned by Debris.

**Tech Stack:** Roblox Luau, Roblox services, Rojo 7.7.1, Selene 0.32.0.

**Spec:** `docs/superpowers/specs/2026-11-15-survivor-respawn-drone-design.md`

## Global Constraints
- Preserve Universe ID 7975091208 and Start Place ID 104752078056182.
- Do not publish; keep the experience private.
- Keep the 15x15 arena, ten bots, round length, lobby, and controller camera.
- Use built-in Roblox assets only and keep visual effects brief.

## Review Focus
- A player who dies while serving as Controller must not remain hidden or be counted.
- A respawn callback arriving after a newer character must not move the wrong model.
- A player who falls between periodic checks must be removed from the count after the server detects the fall.
- A bot controller must aim the same lens and produce the same strike effects as a human controller.
- A stale strike must not reset the drone aim or break a tile from a previous round.

---

### Task 1: Survivor count and regression tests

**Files:**
- Modify: `src/server/Services/RoundService.lua`
- Modify: `src/client/HUD.client.lua`
- Test: `tests/cloud_smoke_tests.luau`
- Modify: `tools/validate_project.py`

- [ ] Make active `playerCount` equal the live runner count, which includes alive human runners and BotService's alive non-controller bots.
- [ ] Make the HUD prefer `remainingPlayers` and then `aliveRunners` for the active display.
- [ ] Add a cloud smoke test with two human runners and three living bots, then remove one of each and assert the count drops from 5 to 3.

### Task 2: Deterministic player respawn

**Files:**
- Modify: `src/server/Services/RoundService.lua`
- Test: `tests/cloud_smoke_tests.luau`
- Modify: `tools/validate_project.py`

- [ ] Allow placement helpers to accept the exact Character model being processed.
- [ ] Guard delayed CharacterAdded handling so an older character cannot overwrite a newer character's position.
- [ ] On death, clear role/controller/runner state and replication focus without treating the dead body as the respawned character.
- [ ] If Roblox does not supply a new living character after the configured respawn window, request one with a protected LoadCharacterAsync call.
- [ ] Add a smoke check that explicit-character placement moves the supplied model, not another model held by Player.Character.

### Task 3: Thin foundation and fall handling

**Files:**
- Modify: `src/server/Services/ArenaService.lua`
- Modify: `tests/cloud_smoke_tests.luau`
- Modify: `tools/validate_project.py`

- [ ] Change ClassicArenaSupport to 2 studs thick and non-collidable/non-touchable/non-queryable.
- [ ] Keep OUT_OF_BOUNDS_Y as the authoritative fall threshold and ensure a falling player is removed from the active roster before the next broadcast.

### Task 4: Drone movement, aiming, and laser visuals

**Files:**
- Modify: `src/server/Services/ArenaService.lua`
- Modify: `src/server/Services/StrikeService.lua`
- Modify: `tests/cloud_smoke_tests.luau`
- Modify: `tools/validate_project.py`

- [ ] Weld the drone shell to its anchored root and build a separate lens subassembly on a Motor6D.
- [ ] Move LaserOrigin onto the lens pivot so the beam follows the aiming direction.
- [ ] Add a subtle looping hover tween to the body.
- [ ] Add token-guarded aim and return-home methods for human and bot strikes.
- [ ] Add layered blue laser beams, impact particles, a short shock ring, and a contained light flash. Keep effect lifetime bounded with Debris.
- [ ] Test gimbal existence, target aim, return-home behavior, beam origin, and visual effect creation.

### Task 5: Verification

- [ ] Run the project structural validator.
- [ ] Run Selene over source and tests.
- [ ] Run Rojo build.
- [ ] Review the final diff and PR checks.
- [ ] Report that live Roblox Studio physics/play testing still requires the user's private test upload; do not run publishing automatically.
