# Update #19 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a second Cyberpunk White & Blue map with reliable map-specific geometry and lighting, and make the owner debug-aircraft override strictly follow the server's explicit toggle state through rounds and respawns.

**Architecture:** Keep the shared 15 x 15 grid, aircraft, and existing gameplay services. Make map palettes and decorations theme-aware, rebuild only the active-map folder on an ID change, and alternate map IDs by round number. Centralize the owner debug opt-in predicate in RoundService, guard auto-selection and auto-ready preservation with it, and synchronize the client toggle display from the replicated server attribute.

**Tech Stack:** Roblox Luau, Rojo 7.7.1, Lune 0.11.1, Selene 0.32.0, StyLua 2.6.0, Luau-LSP 1.70.1, Roblox Cloud Luau smoke tests.

**Spec:** `docs/superpowers/specs/2026-11-16-cyberpunk-arena-control-state-design.md`

## Global Constraints

- Preserve `GRID_SIZE = 15`, `TILE_SIZE = 12`, `ROUND_SECONDS = 180`, `BOT_COUNT = 10`, and 30-player capacity.
- Preserve Classic theme behavior, the golden aircraft, lens, laser origin, and all controller/runner spawn calculations.
- No third-party assets or packages; procedural static Parts only.
- Cyberpunk decorative parts must be anchored and non-colliding, non-touching, and non-queryable.
- No more than six PointLights and roughly 60 static map decoration Parts for Cyberpunk.
- Debug takeover requires matching server pointer plus `SkyfallDebugDroneEnabled == true` and readiness.
- Do not publish, push, merge, or change Roblox access settings.
- Do not claim Studio/device/live multiplayer verification from this cloud sandbox.

## Review Focus

- Switching back from Cyberpunk to Classic must remove all neon decoration, Atmosphere, Bloom, and ColorCorrection, restoring neutral Classic values.
- Rebuilding the map repeatedly must not duplicate decorations or lights.
- Tiles in a broken/warning/reset state must recover the active theme's material and surface style.
- A stale debug-player pointer with a false attribute must not force Controller selection or auto-ready state.
- A disabled debug toggle during or before respawn must not keep the character hidden, move it to the drone, or restore stale control after the next round.

---

### Task 1: Add regression tests for map switching and rotation

**Files:**
- Modify: `tests/cloud_smoke_tests.luau`
- Modify: `tools/validate_project.py` only if its source-level assertions encode `MAP_COUNT == 1` or fixed map-only assumptions.

**Interfaces:**
- Consumes: Existing `ArenaService`, `RoundService`, `GameConfig`, and current smoke-test harness.
- Produces: Failing tests for two map definitions, exact 225-tile preservation, map-specific materials/surfaces/decor/lighting, safe map switch/rebuild, and round rotation 1-4.

- [x] Add a focused assertion that `MAP_COUNT == 2` and exact names exist.
- [x] Add a map-switch regression test for 1 -> 2 -> 1 -> 2, checking active theme, tile material/surfaces, decoration ownership, effect cleanup, invalid-ID fallback, and no instance accumulation. Runtime execution remains gated on Roblox Cloud credentials.
- [x] Add a rotation test for round indices 1-4.
- [x] Run the structural validator, Selene, and Luau-LSP to parse and statically inspect the regression suite; record the existing type-diagnostic baseline. Runtime execution requires Roblox Cloud Luau Execution.

### Task 2: Implement theme-aware map configuration and tile surfaces

**Files:**
- Modify: `src/shared/GameConfig.lua`
- Modify: `src/server/Services/ArenaService.lua`
- Test: `tests/cloud_smoke_tests.luau`

**Interfaces:**
- Consumes: Two entries in `Config.MAP_NAMES`, with stable IDs 1 and 2.
- Produces: `ArenaService:SetMap(mapId: number): string` selecting an exact `MAPS[mapId]` entry with a Classic fallback, theme-aware tile colors/material/surface state, and rebuildable active-map geometry.

- [x] Add `CYBERPUNK_MAP_ID = 2`, update `MAP_NAMES`, and set `MAP_COUNT = 2`.
- [x] Add theme fields for tile alternate color, smooth-surface mode, trim colors, and Cyberpunk lighting parameters.
- [x] Replace the one-size-only `setTileStudState` behavior with a theme-aware surface helper that restores Classic Studs only for map 1 and Smooth surfaces for map 2.
- [x] Apply the correct theme material after warning clear, tile break, and round reset.
- [x] Validate invalid map IDs fall back to Classic and do not mutate map identity incorrectly.

### Task 3: Build Cyberpunk geometry and scoped lighting

**Files:**
- Modify: `src/server/Services/ArenaService.lua`
- Test: `tests/cloud_smoke_tests.luau`

**Interfaces:**
- Consumes: `self.mapFolder`, map theme palette, `Config.ARENA_CENTER`, `Config.ARENA_HALF_WIDTH`, and existing `createPart` helper.
- Produces: map-specific `_buildClassicDecoration(theme)` / `_buildCyberpunkDecoration(theme)` or equivalent, and `_setLighting(theme)` that can enter and cleanly exit both visual states.

- [x] Preserve existing Classic geometry under the Classic builder without changing part names used by tests.
- [x] Add Cyberpunk navy foundation and white/silver perimeter plates.
- [x] Add four corner pylons and restrained electric-blue structural ribs.
- [x] Add thin cyan Neon trim lines, not floor-wide Neon surfaces.
- [x] Add up to six localized PointLights with bounded range/brightness and no per-tile dynamic lighting.
- [x] Add a restrained Atmosphere, BloomEffect, and ColorCorrectionEffect for Cyberpunk only.
- [x] Ensure all decorative BaseParts are anchored and explicitly non-colliding, non-touching, and non-queryable.
- [x] Enforce a stable decoration count budget and clear old map decoration before building a different map.
- [x] Add cloud-smoke coverage that repeatedly switches 1 -> 2 -> 1 -> 2 and asserts no duplication, no stale effects, and no change to the 225 tile count.

### Task 4: Add deterministic round map rotation

**Files:**
- Modify: `src/server/Services/RoundService.lua`
- Test: `tests/cloud_smoke_tests.luau`

**Interfaces:**
- Consumes: `Config.MAP_COUNT`, `self.roundNumber`, and `ArenaService:SetMap`.
- Produces: `_chooseNextMapId(): number`, returning `(roundNumber - 1) % MAP_COUNT + 1` for the round number already incremented in `_runRound`.

- [x] Write rotation assertions for rounds 1-4.
- [x] Implement deterministic Classic-first alternation without changing any round-selection logic.
- [x] Confirm map selection runs once at round setup and the broadcast reads the new map name.

### Task 5: Add regression tests for debug-toggle authority and respawn

**Files:**
- Modify: `tests/cloud_smoke_tests.luau`
- Modify: `src/server/Services/RoundService.lua` only after the tests are present.

**Interfaces:**
- Consumes: Existing `RequestDebugController`, `debugControllerPlayer`, `debugAutoReady`, `_clearReadyPlayers`, `_chooseController`, and `_onCharacterAdded` behavior.
- Produces: Tests for explicit active opt-in, disabled stale-pointer rejection, no auto-ready on false, true-state persistence, disable restoration, and disabled/active respawn behavior.

- [x] Add tests where `debugControllerPlayer` matches but `SkyfallDebugDroneEnabled` is false; it must not override Pilot Priority or bot selection.
- [x] Add tests where the pointer and attribute are true and the player is ready; the debug override must remain available.
- [x] Add tests where `_clearReadyPlayers` must not auto-requeue a player after the attribute becomes false.
- [x] Add a spawn test proving a disabled debug player is not re-hidden or given Controller role by stale debug state.
- [x] Add a spawn test proving an explicitly enabled debug player remains Controller only while the server attribute stays true.
- [x] Run static analysis on the debug regression suite and record the existing fake-player type-diagnostic baseline.

### Task 6: Implement server-side debug state guards

**Files:**
- Modify: `src/server/Services/RoundService.lua`
- Test: `tests/cloud_smoke_tests.luau`

**Interfaces:**
- Consumes: `player:GetAttribute("SkyfallDebugDroneEnabled")`, `self.debugControllerPlayer`, and `self.debugAutoReady`.
- Produces: one predicate such as `_isDebugControllerRequested(player): boolean`; consistent guarded selection, ready preservation, and character spawn recovery.

- [x] Add the server predicate requiring matching identity and exact boolean true.
- [x] Use it in `_chooseController` and ignore/clear stale disabled debug state.
- [x] Use it in `_clearReadyPlayers`; clear stale debug-only ready entries and flags when disabled.
- [x] Guard `_onCharacterAdded` so a stale debug override cannot hide or relocate a player after respawn.
- [x] Preserve ordinary selected Controller respawns and all non-debug player routes.
- [x] Keep `RequestDebugController(false)` idempotent and ensure it restores the previous valid candidate and removes only debug-only readiness.

### Task 7: Synchronize client toggle display with server state

**Files:**
- Modify: `src/client/AdminFlight.client.lua`
- Test: `tests/cloud_smoke_tests.luau` for structural/UI state assertions where supported.

**Interfaces:**
- Consumes: replicated `SkyfallDebugDroneEnabled` and `CharacterAdded`.
- Produces: UI state derived from the server attribute after initial load, activation, and every spawn.

- [x] Keep the toggle's desired state sourced from the replicated attribute, not only a local optimistic boolean.
- [x] Re-read the attribute on `CharacterAdded` before updating the label.
- [x] Keep the existing owner-only visibility and remote command checks.
- [x] Do not change the lower-left Pilot Priority readout or rename it to a toggle.

### Task 8: Integration, review, and evidence

**Files:**
- Modify: `docs/updates/019-cyberpunk-arena-control-state-checklist.md`
- Verify: all changed source/test files.

- [x] Run `python3 tools/validate_project.py`.
- [x] Run `selene src tests`.
- [x] Run StyLua on all files changed by Update #19 and confirm they are clean; separately identify full-project drift in untouched files.
- [x] Run `rojo sourcemap default.project.json --output build/sourcemap.json`.
- [x] Run `luau-lsp analyze --platform roblox --definitions @roblox=/home/user/.cache/roblox-toolchain/roblox-api/globalTypes.None.d.luau --sourcemap build/sourcemap.json <all Luau source/test files>` and resolve newly introduced diagnostics. Record any known pre-existing baseline diagnostics separately.
- [x] Run `rojo build default.project.json --output build/SkyfallArena.rbxlx`.
- [x] Run Lune unit checks if any pure-Luau helper tests were added.
- [x] Inspect the final diff and map geometry bounds/counts; no protected behavior changes.
- [x] Request independent review with exact base and head SHAs, then address all critical/important findings.
- [x] Record that live Roblox Studio, device, and multiplayer tests remain pending if the required environment is unavailable.
- [x] Do not push or publish.
