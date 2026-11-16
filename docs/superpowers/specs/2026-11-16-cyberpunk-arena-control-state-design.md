# Update #19 Design: Cyberpunk Arena and Explicit Drone Control State

**Status:** Approved for implementation by the user's explicit `OK go`.

## Intent

Add a second, studio-grade Cyberpunk White & Blue arena while preserving the existing Classic map and its gameplay scale. Fix the owner-only debug drone toggle so server-side selection, readiness persistence, and character respawns never treat a disabled toggle as permission to take over the golden aircraft.

## Goals

- Keep the common destructible grid at 15 x 15, 12-stud tiles, the existing runner spawn layout, the current golden aircraft, and the 180-second round.
- Add a second selectable map with white/silver architecture, navy depth, electric-blue structure accents, restrained cyan Neon details, and controlled Atmosphere/Bloom/ColorCorrection.
- Rotate the two maps deterministically, beginning with Classic in round 1 and Cyberpunk in round 2.
- Rebuild only the active map's decoration when the map ID changes, preventing stale decorations and instance accumulation.
- Treat the existing owner-only `DebugDroneToggle` (`DRONE` / `TEST ON` in `AdminFlight.client.lua`) as the explicit debug takeover toggle. The `DRONE NN%` lower-left HUD label is a Pilot Priority readout, not a toggle, and must remain informational.
- Require both the active server-side debug-player identity and `SkyfallDebugDroneEnabled == true` before debug auto-selection, auto-ready persistence, or debug-control restoration after respawn.
- Keep the server authoritative. The UI displays the replicated attribute state, not an independent local guess.
- Add regression coverage for map selection, map switching, tile invariants, lighting reset, explicit debug opt-in, debug opt-out, and respawn state.

## Non-goals

- Do not change ordinary Pilot Priority selection rules, the first solo-round bot exception, round length, scoring, laser behavior, bubble weapon behavior, or the golden aircraft model.
- Do not replace the arena tile grid, lobby, player capacity, or bot service.
- Do not add third-party assets, packages, DataStores, or external model downloads.
- Do not publish the place, merge the branch, or change the Roblox experience access setting.
- Do not claim Roblox Studio, phone-device, or multiplayer runtime verification where Studio and the live cloud test credentials are unavailable.

## Current findings and root cause

- `GameConfig.lua` currently exposes only `SKYFALL CLASSIC ARENA` and `MAP_COUNT = 1`.
- `ArenaService:SetMap()` always selects `MAPS[1]`; it builds the decoration only once, so later map IDs cannot change the geometry.
- `_setLighting()` always removes all custom post-processing, so a map-specific lighting preset cannot currently be retained.
- Every tile receives native Classic Stud surfaces at creation and reset, which is correct for Classic but unsuitable for the smooth Cyberpunk deck.
- `RoundService:_chooseNextMapId()` always returns 1.
- The debug toggle is the owner-only `DebugDroneToggle` in `AdminFlight.client.lua`. The lower-left `DRONE NN%` label in `HUD.client.lua` shows Pilot Priority and has no activation handler.
- `RoundService:_chooseController()` currently trusts `debugControllerPlayer` plus readiness without also checking the replicated opt-in attribute. `_clearReadyPlayers()` likewise re-queues a stored debug player without verifying the toggle. `_onCharacterAdded()` reapplies Controller role from `self.controller` alone.
- The fix must guard every server path that can preserve or reapply the debug override. Normal round controller selection remains a separate game rule.

## Approaches considered

1. **Retheme the existing Classic map.** Rejected: this removes the Classic aesthetic and breaks the existing theme-specific acceptance tests.
2. **Add a second map using the shared destructible grid and a map-owned decoration folder.** Selected: it preserves gameplay dimensions, reuses existing services, supports round rotation, and keeps all extra geometry and lighting scoped to the selected theme.
3. **Import a large external Cyberpunk model pack.** Rejected: it adds asset trust, network, licensing, collision, streaming, and performance risks without being necessary for a strong procedural result.

## Selected implementation

### Map architecture

- Extend the existing `MAPS` data with map ID 2 and update `MAP_NAMES` / `MAP_COUNT`.
- Keep tile dimensions, grid coordinates, and spawn math shared.
- Add an alternate smooth tile palette for Cyberpunk; keep native Studs/Inlet surfaces only for Classic. Warning, broken, and reset states must always use the active map's correct base material and surface treatment.
- Separate `_buildClassicDecoration(theme)` and `_buildCyberpunkDecoration(theme)` or equivalent focused helpers. All map decoration belongs under `ActiveMap` and must be cleared before another map is built.
- Cyberpunk design: pearl-white and brushed-silver perimeter plating, dark-navy foundation, electric-blue corner pylons and structural ribs, thin cyan Neon edge channels and inset accent lines, and a small number of localized PointLights. Decorative parts are anchored and explicitly non-colliding, non-touching, and non-queryable.
- Target roughly 60 or fewer static decorative Parts and no more than six localized lights. Do not add per-tile lights or continuously emitting particles.
- Classic map keeps its current green stud geometry and neutral daytime Lighting.
- Cyberpunk Lighting uses a restrained night/cool preset with an Atmosphere, a subtle BloomEffect (Intensity 0.55-0.7, Size 20-26, Threshold around 1.1), and a mild ColorCorrectionEffect. Clear custom effects when switching back to Classic.
- Alternate map selection based on the current round index: Classic on round 1, Cyberpunk on round 2, then repeat. `SetMap()` validates IDs and safely falls back to Classic for invalid values.

### Drone control state

- The opt-in state is the replicated server-owned `SkyfallDebugDroneEnabled` attribute.
- Create one helper/predicate for an active debug request: stored debug player identity matches the player and the player's attribute is exactly `true`.
- `_chooseController()` may prioritize the debug player only when this predicate and readiness are both true.
- `_clearReadyPlayers()` preserves debug auto-ready only while the predicate remains true; otherwise it clears the stale debug request and any debug-only readiness.
- When the owner disables the toggle, clear the pointer and auto-ready state, restore the previous valid controller when applicable, and allow normal character control/normal round selection otherwise.
- `_onCharacterAdded()` may reapply debug Controller role only when the explicit debug request is still active. A disabled or stale debug request must never hide or move a newly spawned character into the golden aircraft state.
- `AdminFlight.client.lua` must derive the displayed state from `SkyfallDebugDroneEnabled`, including after `CharacterAdded`, rather than trusting only an optimistic local boolean.
- Keep normal randomly/priority-selected Controllers unchanged. The debug toggle controls only the owner debug override, not the ordinary round's controller-selection mechanic.

## Acceptance criteria

1. `Config.MAP_COUNT == 2`, with exact names for Classic and Cyberpunk.
2. `SetMap(1)` and `SetMap(2)` switch theme, tile material/surface, decoration, and Lighting correctly. Switching back leaves no Cyberpunk-only decoration or post-processing.
3. Both maps retain exactly 225 destructible tiles, 12-stud spacing, existing spawn bounds, and the same golden aircraft and laser origin.
4. Cyberpunk has white/light-silver floor tiles, dark-navy base, electric-blue structures, cyan accents, bounded neon/light counts, and no decorative collisions or queries.
5. Round map rotation yields Classic, Cyberpunk, Classic, Cyberpunk for rounds 1-4.
6. A false debug attribute prevents a stale pointer from being selected or automatically re-queued.
7. A true debug attribute plus matching debug player identity and readiness enables the explicit debug override.
8. Turning the toggle off removes debug-only readiness and restores valid previous control; no stale debug state survives subsequent rounds.
9. Respawning with the toggle off restores normal character control. Respawning with the toggle on preserves the explicit debug takeover only while the server-side request remains true.
10. Existing Classic, bot, bubble, Pilot Priority, scoring, laser, winner, and respawn tests remain valid.

## Verification boundaries

- Run project structure validation, Selene, StyLua check, Luau-LSP, Rojo sourcemap, Rojo build, and any runnable Lune unit tests.
- The existing Roblox cloud smoke script is Studio/DataModel-dependent and cannot be executed until the separate Roblox Luau Execution key is configured and a private test upload is explicitly approved.
- In-Studio visual review, mobile frame profiling, touch input, and real multiplayer verification remain required before release.
