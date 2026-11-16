# Update #19: Cyberpunk White & Blue Arena and Drone Control State

**Date:** 2026-11-16
**Branch:** `feat/019-cyberpunk-arena-control-state`
**Base:** `685c1f4` (`main`)
**Status:** Implemented in the local feature branch. Not committed, pushed, merged, or published.

## Delivered

### Map architecture and visuals

- Added map ID 2, `SKYFALL CYBERPUNK WHITE & BLUE ARENA`, while preserving map ID 1 `SKYFALL CLASSIC ARENA`.
- Round rotation is deterministic: Classic, Cyberpunk, Classic, Cyberpunk.
- The shared gameplay floor remains 15 x 15, 225 destructible tiles, 12 studs per tile. Existing runner/controller spawn calculations, aircraft, laser origin, 180-second rounds, bot count, and Pilot Priority rules remain unchanged.
- Cyberpunk uses pure white (`255,255,255`) and pearl white (`244,247,251`) alternating smooth tiles, a deep navy (`10,17,40`) foundation, electric-blue (`0,119,255`) metal pylons and structural ribs, and cyan (`0,240,255`) Neon edge channels/pylon accents.
- Cyberpunk decoration is built into the active map folder only, with static anchored parts, no collisions/touch/query, disabled cast shadows, and four localized PointLights. The runtime smoke test enforces a 60-part decoration cap, a 4-12 Neon-part range, and a six-light cap.
- Cyberpunk Lighting uses Atmosphere, Bloom, and ColorCorrection with restrained values. Switching back to Classic removes these effects and restores neutral daytime lighting.
- Map changes clear/rebuild only map decoration. Repeated switching cannot accumulate old map parts. Tiles restore their theme-specific colors, surfaces, and materials after reset.

### Drone control state

- The explicit control switch is the existing owner-only `DebugDroneToggle` (`DRONE` / `TEST ON`) in `AdminFlight.client.lua`.
- The bottom-left `DRONE NN%` display remains the informational Pilot Priority value, not a control toggle.
- Client display state now comes from the replicated server `SkyfallDebugDroneEnabled` attribute after initial load, activation, and CharacterAdded. The client shows a short `SYNC...` pending state while awaiting server replication.
- Server debug-controller selection and debug auto-ready persistence require both the stored owner identity and `SkyfallDebugDroneEnabled == true`.
- Disabled or stale debug state is cleared from selection, round cleanup, and character respawn handling. Normal game controller selection remains separate and unchanged.
- When an owner using debug takeover leaves mid-round, a valid saved player or bot controller is restored. If the saved candidate is no longer valid, the controller reference is cleared safely.

## Verification evidence

| Check | Result |
|---|---|
| `python3 tools/validate_project.py` | PASS, structural and gameplay source checks |
| `selene src tests` | PASS, 0 errors, 0 warnings, 0 parse errors |
| StyLua on all Luau files modified by Update #19 | PASS |
| `rojo sourcemap default.project.json` | PASS, includes `MapRotation` and `DebugControllerPolicy` |
| `lune run tests/lune/update_019_policy.luau` | PASS, `UPDATE_019_POLICY_TESTS_OK` |
| `rojo build default.project.json` | PASS, generates `build/SkyfallArena.rbxlx` |
| GitHub Actions PR validation (run #398) | PASS, repository validation, Selene, Rojo build, and artifact upload |
| Codex MCP source review | PASS, no important P1/P2 findings in the final focused review |

### Known baseline/static limitations

- Luau-LSP still reports 12 existing TypeErrors: 3 in the HUD `remainingSeconds` state typing and 9 in existing smoke-test fake-player/table typing. No new Update #19 TypeError or multiline-statement diagnostic remains after the final source correction.
- Full-repository `stylua --check src tests` continues to show formatting drift in untouched files: `BubbleGun.client.lua`, `HUD.client.lua`, `AdminFlightService.lua`, `BotService.lua`, `BubbleGunService.lua`, `LaserVFX.lua`, `PilotPriorityService.lua`, and `StrikeService.lua`. These files were not reformatted as part of #19. Every Luau file changed by #19 passes the targeted StyLua check.
- The Roblox headless cloud smoke-test script has been extended with actual runtime map-switching, lighting, decoration-budget, controller toggle, respawn, and departure tests. It was not executed because `ROBLOX_LUAU_TEST_API_KEY` is not configured.
- Roblox Studio is not available in this phone-only workflow. Visual inspection, real physics, touch interaction, device performance profiling, and multiplayer playtesting remain release gates.

## Release boundary

- The generated `.rbxlx` is a Rojo build artifact, not a proof of a successful Studio runtime or a Roblox upload.
- The feature branch was pushed to GitHub and Pull Request #19 was opened against `main`. No merge, Roblox Open Cloud upload, place publish, or experience visibility change was performed.
- The feature branch is ready for review/integration subject to the pending Roblox runtime/device validation above.
