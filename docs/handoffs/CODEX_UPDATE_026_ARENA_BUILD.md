# Engineering Handoff: Update #26 Arena Build Fail-Safe

**Repository:** `Vx1133/SkyfallArena1`  
**Base:** `main` after Update #25  
**Target branch:** `fix/026-arena-build-fail-safe-main`  
**Task:** Stop optional map decoration, element transitions, strict audits, or lighting failures from aborting the core arena/player startup.

## Historical evidence to preserve

- PR #21 is Update #23 and merged as `2d2e12d12dcb0feade58c3e013a418cb3dd53320`.
- Roblox place upload version 20 was built from that commit.
- Upload version 21 was built from the Update #24 merged commit `c65e40d0f136edc06abd99140e9c528c5a41134c`.
- Upload version 22 was built from the Update #25 merge commit `0d28c5fb99b1d67c54e2d77408f8e88eda258ebb`.
- PR #23 was never merged; it did not create a published place version.
- Roblox headless Luau tests were skipped for these successful uploads because the `ROBLOX_LUAU_TEST_API_KEY` secret was absent.

## Confirmed Update #23 regression path

Update #23 changed previously non-fatal decoration and element integration failures into errors inside `ArenaService:SetMap()`. That method runs from `ArenaService:Build()` before Bootstrap creates and starts RoundService. The strict map/tile audits also throw on mismatch. Any such exception can stop Bootstrap before PlayerAdded/CharacterAdded binding and PlayRequest handling.

Do not report a particular audit mismatch as the proven incident without the actual Roblox Output line. The source-level fail-fast path is proven; the exact triggering error still requires Output.

## Implementation invariants

1. `SkyfallCoreArenaReady` is true only when the live WaitingPlatform exists and all configured gameplay tiles exist.
2. `SkyfallArenaReady` reflects core arena readiness, not successful decoration, element overlays, audits, or lighting.
3. Map builder exceptions clear partial decoration and fall back to the built lobby and tiles.
4. Element transition exceptions remove only their own partial overlay and do not clear the map geometry.
5. Surface audit failures emit exact diagnostics and update an audit status attribute. They do not stop the round service.
6. Lighting application failures emit diagnostics and do not stop character startup.
7. Core lobby/tile creation failures remain fatal and must never be reported as gameplay-ready.
8. Existing two map designs, tile collision/position/palette, bot roster, aircraft and round logic remain unchanged.

## Validation

- Run all existing Lune policy tests.
- Run `lune run tests/lune/update_026_arena_bootstrap_guard.luau`.
- Run `python tools/validate_project.py`.
- Run `selene src tests`.
- Build with `rojo build default.project.json --output build/SkyfallArena.rbxlx`.
- Confirm CI contains CORE_READY, OPTIONAL_STAGE_FAILED handling, ARENA_READY, and that no optional decoration/audit failure is rethrown from `SetMap`.

## Studio runtime validation after private upload

1. Start a fresh Roblox server after upload, not an already-running server.
2. Inspect Server Output for CORE_READY with 225 tiles and the lobby platform path.
3. Inspect OPTIONAL_STAGE_READY or OPTIONAL_STAGE_FAILED for MapGeometry, ElementTransitions, MapSurfaceAudit, TileSurfaceAudit, and LightingProfile.
4. Confirm ARENA_READY and GAME_READY appear.
5. Confirm the player character appears at the lobby before PLAY becomes available.
6. Press PLAY, complete a round, rotate both maps, and complete a second round.
7. If an optional stage fails, confirm the lobby/grid/gameplay still works. Use the full warning text to identify the optional visual issue.
8. If CORE_READY is absent, the remaining failure is in core lobby/tile/aircraft construction, not the optional map builder; use the actual Output error to isolate the next repair.

CI and Rojo build do not prove a live runtime fix. Do not claim Studio verification unless actually performed.
