# Update 018: Bubble Blaster + Pilot Priority + Multiple Winners

 > Status: Implementation in progress. A checkbox may be marked complete only after the named test or direct evidence is recorded below.
> Branch: `feat/018-bubble-blaster-pilot-priority`
> Base: `main`

## 1. Repository review and implementation plan
- [x] Read current GameConfig, Bootstrap, RoundService, StrikeService, BotService, HUD, Audio, Rojo project mapping, and cloud smoke tests. Evidence: fetched all requested files from `main`; RoundService (1,229 lines), BotService (808 lines), and cloud smoke tests (981 lines) reviewed in sections.
- [x] Confirm lobby spawn geometry and available bot target interfaces. Evidence: lobby platform is `ArenaService.lobbyFolder/WaitingPlatform`, spawn radius is 49 studs, and `BotService:GetAliveBots()` exposes live Runner bot models and Humanoids.
- [x] Record implementation plan and exact files to change. Plan: isolate session scoring in `PilotPriorityService`; isolate Tool, lobby station, projectile, target validation, and hold cleanup in `BubbleGunService`; wire lifecycle callbacks through `RoundService`; keep input/reticle in a client script; keep HUD changes isolated to `HUD.client.lua`.
- [x] Confirm protected systems: golden drone model, lens, laser visuals, map count, round duration, and publishing workflow remain unchanged. Evidence: branch comparison lists only the 10 planned Update #18 files; protected services/workflows and `default.project.json` are absent from the diff. `ROUND_SECONDS = 180` and `MAP_COUNT = 1` remain unchanged.

## 2. Bubble Blaster asset and free trial station
- [ ] Add configurable bubble weapon settings: 2.5s hold, 8s cooldown, 60-stud range.
- [ ] Build a native Roblox Tool and polished Classic Roblox turquoise, pearl-white, and subtle-gold model using trusted Parts only.
- [ ] Add a persistent lobby display stand near spawn without obstructing PLAY.
- [ ] Add a cross-platform ProximityPrompt labelled "TRY FOR FREE".
- [ ] Give each player at most one owned copy when interacting.
- [ ] Add an isolated stationary training target beside the stand.
- [ ] Keep the stand and target available after any player takes a tool.
- [ ] Centralize free trial and runner loadout grants behind one ownership/grant API.
- [ ] Grant one copy to each human Runner at round start, never to the Controller.
- [ ] Prevent duplicate tools on respawn, repeated prompt use, and round transitions.

## 3. Bubble Blaster firing and server authority
- [ ] Add a client tool script for equipped reticle, camera-directed aim, and standard Tool.Activated input.
- [ ] Add a server BubbleGunService and RemoteEvent wired from Bootstrap.
- [ ] Validate server-side tool ownership, equipped state, role, living Runner status, and phase.
- [ ] Validate finite aim direction, range, line of sight, and target eligibility on the server.
- [ ] Enforce server cooldown and one-target-per-shot.
- [ ] Prevent self-hit, duplicate simultaneous holds, Controller hits, Spectator hits, and out-of-round hits.
- [ ] Allow lobby shots only against the dedicated training target.
- [ ] Support valid live human Runners and BotService Runner NPCs without rebuilding BotService.
- [ ] Add a clear moving bubble projectile and lightweight impact/burst visuals.
- [ ] Apply a transparent 2.5-second bubble hold with no direct damage.
- [ ] Snapshot and restore movement/physics state after release, death, player removal, and round end.
- [ ] Ensure a runner on a destroyed tile falls and is eliminated by the existing round logic after release.
- [ ] Ensure an intact tile allows the Runner to continue normally.

## 4. Pilot Priority score and rewards
- [ ] Add session-only per-human Pilot Priority state, clamped to 0..100, exposed as a percentage attribute/state.
- [ ] Award +0 for elimination before 30% elapsed (54 seconds of a 180-second round).
- [ ] Award +5 for elimination at/after 54 seconds before winning.
- [ ] Award +10 instead of +5 to every human winner, including all co-winners.
- [ ] Do not award both elimination and winner rewards in one round.
- [ ] Never award bots Pilot Priority.
- [ ] Prevent duplicate rewards per player per round.
- [ ] Do not award a completion reward to a player who left before the round ended.
- [ ] Keep scores in server memory only, with no DataStore.

## 5. Controller selection
- [ ] Select the highest Pilot Priority among ready human players.
- [ ] Break ties by longest time since the player last controlled the drone.
- [ ] Randomize only among players still tied after the previous criteria.
- [ ] Reset the selected human's score to zero when selected as Controller.
- [ ] Prevent immediate repeat control when another player has equal priority.
- [ ] Preserve the first-round solo-human rule: a bot controls while the only human plays Runner.
- [ ] Prefer ready humans over bots after the first-round solo exception.
- [ ] Use a bot only when no eligible ready human exists.
- [ ] Remove/neutralize legacy nextController overrides so they cannot bypass priority.

## 6. Multiple winners and round results
- [ ] At the 180-second timeout, award every living human Runner as a co-winner.
- [ ] Award +10 Pilot Priority and one win to every human co-winner.
- [ ] Award a sole surviving human Runner as winner.
- [ ] Preserve the existing Controller victory rule when no Runner remains.
- [ ] Remove random single-winner selection from the timeout path.
- [ ] Update winner names, roles, win statistics, result broadcast, and next-round state consistently.
- [ ] Preserve round timing, tile reset, and existing map rebuild behavior.

## 7. Pilot Priority HUD
- [ ] Add a compact white "DRONE NN%" indicator near/below the mobile movement thumbstick without covering controls.
- [ ] Respect safe-area insets and screen-size scaling.
- [ ] Show in Waiting and Runner roles.
- [ ] Hide while the local player is Controller.
- [ ] Update only when the server-side score changes.
- [ ] Preserve the existing top round bar and laser controller HUD.

## 8. Tests and validation
- [ ] Add structural tests for lobby stand, prompt, training target, Tool, and centralized grants.
- [ ] Add tests for unique grants and no duplicate tool on respawn/round start.
- [ ] Add server validation tests for owner/equipped/role/phase/range/line-of-sight/cooldown/target rules.
- [ ] Add tests for human and bot Runner targeting, one target per shot, no self-hit, no Controller/Spectator hits.
- [ ] Add tests for bubble hold, restoration, death/removal/round cleanup, and falling after tile break.
- [ ] Add Pilot Priority tests for 0, +5, +10, cap 100, bot exclusion, leaver exclusion, and duplicate prevention.
- [ ] Add controller selection tests for priority, tie-break, random final tie, score reset, no immediate repeat, solo first round, and bot fallback.
- [ ] Add multiple-winner tests for 0, 1, and multiple human survivors at timeout, including stats and reward correctness.
- [ ] Add HUD structural checks for visibility, text, update behavior, and safe-area anchoring.
- [ ] Run cloud smoke tests (private Roblox upload and live execution still pending).\n- [x] Run project structural validation. Evidence: GitHub Actions run `43887761737`, commit `7e32919de1b3406bd33b273e3fed292922e4cd2d`, step `Validate repository structure` passed.
- [x] Run Selene on `src` and `tests`. Evidence: GitHub Actions run `43887761737`, Selene completed with 0 errors, 0 warnings, and 0 parse errors.
- [x] Run `rojo build default.project.json`. Evidence: GitHub Actions run `43887761737`, Rojo build completed successfully and produced the `SkyfallArena-place` artifact.
- [x] Review diff for protected drone, lens, laser, map, round duration, and publish workflow changes. Evidence: base-to-branch comparison lists only the 10 intended Update #18 files; protected modules, project mapping, and upload workflow are unchanged.
- [ ] Record each test result and any untestable device/runtime behavior below.
- [ ] Verify Device Simulator and a real phone for touch, Safe Area, Tool equip/fire, and thumbstick overlap (mark unverified if unavailable).
- [ ] Verify multiplayer behavior with at least two real clients when available (mark unverified if unavailable).

## 9. Review and delivery
- [x] Perform an independent code review or documented self-review if no reviewer agent is available. Evidence: self-review found and fixed a dead stale human Runner fallback issue, plus two CI blockers (an extra `end` and seven Luau style warnings); see latest recovery checkpoint.
- [x] Resolve all critical and important findings found in the self-review. Runtime/device findings remain unverified, not assumed clear.
- [x] Create Pull Request #18 against `main` as a draft, not merged: https://github.com/Vx1133/SkyfallArena1/pull/18
- [x] Confirm CI results for structural validation, Selene, and Rojo build. Evidence: GitHub Actions run `43887761737` succeeded on commit `7e32919de1b3406bd33b273e3fed292922e4cd2d`.
- [ ] Do not merge or publish this update.

## Evidence log
| Item | Evidence / command / result |
|---|---|
| Repository baseline | Existing files read from `main`; current service interfaces inspected |
| Checklist created | `9d7244e0bbefd289f4304221a72211b46860f51f`, plan update `566ead38d40be670eed813294a08ab782e0dfdf9` |
| Tests | Pending |
| Device / multiplayer runtime | Pending |
| Review | Pending |

## Implementation plan (approved scope from the supplied specification)
- `src/shared/GameConfig.lua`: add only bubble and Pilot Priority constants, preserving `ROUND_SECONDS = 180` and all laser/drone values.
- `src/server/Bootstrap.server.lua`: create the BubbleShot remote, require/start the two new services, and connect RoundService lifecycle callbacks.
- `src/server/Services/PilotPriorityService.lua` (new): own in-memory per-human scores, one-reward-per-round guard, tie-breaking timestamps, and selection.
- `src/server/Services/BubbleGunService.lua` (new): build the trusted native Tool and lobby station, centralize grants, validate shots on the server, create projectile/bubble visuals, and restore held targets on every cleanup path.
- `src/server/Services/RoundService.lua`: delegate score/selection, grant the Tool to Runners only, remove nextController bypass, reward eliminations/winners, and broadcast all human co-winners.
- `src/client/BubbleGun.client.lua` (new): connect standard Tool equip/Activated input, camera aim, and a compact equipped reticle.
- `src/client/HUD.client.lua`: add only the small DRONE percentage text, update on the score attribute, and keep it away from thumbstick/safe-area edges.
- `tests/cloud_smoke_tests.luau` and `tools/validate_project.py`: add regression and structural checks.
- Reviewed but planned unchanged: `StrikeService.lua`, `BotService.lua`, `Audio.client.lua`, `default.project.json`, and `ArenaService.lua`. Their current interfaces already support the requested integration. No external models, DataStore, map edits, laser edits, or publishing workflow changes.


## Recovery checkpoint (2026-11-16)
All work below is committed to `feat/018-bubble-blaster-pilot-priority`. The previous tool interruption did not discard these files.

### Persisted files
| File | Current blob SHA | State |
|---|---|---|
| `src/shared/GameConfig.lua` | `2dbba5161a3f4be69dd4649dbed222dcecbf7742` | Implemented draft, not yet runtime-verified |
| `src/server/Bootstrap.server.lua` | `72b318835fc8b0e6360c1a06339d1d1f28e9228c` | Implemented draft, not yet runtime-verified |
| `src/server/Services/RoundService.lua` | `aa635b8c8419c6ff19d3f46e536a1403ae5498ec` | Implemented draft, not yet runtime-verified |
| `src/server/Services/BubbleGunService.lua` | `f385475eee57dac6d6cf0298c1b28a82fa82fd61` | Implemented draft, not yet runtime-verified |
| `src/server/Services/PilotPriorityService.lua` | `60ce6b524e56b2b2e01c81d0682981f6454b28b6` | Implemented draft, not yet runtime-verified |
| `src/client/BubbleGun.client.lua` | `427241b3020ab7ce921a163398cca3495eaf6210` | Implemented draft, not yet runtime-verified |

### Exact resume point
- [ ] Finish Pilot Priority lifecycle and multiple-winner integration in RoundService, then inspect it for edge cases.
- [ ] Finish the compact Pilot Priority HUD in `src/client/HUD.client.lua`.
- [ ] Review and repair BubbleGunService security, ownership, prompt, projectile, hold restoration, and lifecycle cleanup.
- [ ] Expand `tests/cloud_smoke_tests.luau` for Bubble Blaster, Pilot Priority selection/rewards, and multiple human winners.
- [ ] Update `tools/validate_project.py` to assert new modules, remotes, configuration, and protected systems.
- [ ] Run structural validation, Selene, and Rojo build with fresh output.
- [ ] Review full diff and create PR only after checks are green.

### Known verification status at checkpoint
- Checklist and implementation plan: committed.
- New BubbleGunService, PilotPriorityService, BubbleGun client, config constants, Bootstrap wiring, and RoundService draft: committed.
- Automated tests, Selene, Rojo build, phone simulator, real-phone input, and real multiplayer: not yet run for Update #18.
- Pull Request: not created.
- Merge and Roblox publish: not performed.
- Do not mark any implementation checkbox complete until its tests/evidence exist.


## Recovery checkpoint (2026-11-16, latest source review)

The work below is saved on `feat/018-bubble-blaster-pilot-priority`. Continue on this branch; do not restart or replace existing code.

### Persisted changes at this checkpoint
- `src/server/Services/BubbleGunService.lua`: server-owned Tool template and lobby display; prompt distance verification; server-side role, tool, direction, range, and cooldown gates; impact-time raycast and target revalidation; projectile cancellation at round cleanup; hold restoration on timeout, death, character removal, player removal, and role transition; winner anchoring preservation; world impact burst.
- `src/server/Services/PilotPriorityService.lua`: session-only score state, 0..100 cap, one award per round, 54-second elimination threshold, winner reward, controller wait-time tie-break, selected-controller score reset.
- `src/server/Services/RoundService.lua`: human-first priority selection, first-solo-round bot exception, removal of the legacy `nextController` selection path, timeout co-winners, living humanoid checks, Controller victory fallback, safe result payloads containing winner names/roles, and restoration of a winning human Controller to the visible lobby.
- `src/client/HUD.client.lua`: compact DRONE percentage indicator on a separate Core UI safe-area ScreenGui, visible for Waiting/Runner and hidden for Controller, updated from the score attribute.
- `tests/cloud_smoke_tests.luau`: added Pilot Priority, selection, co-winner, dead-runner, controller restoration, trial prompt, server-shot, projectile-impact, and bubble hold lifecycle cases.
- `tools/validate_project.py`: structural checks for the new services, remote, config, server validation, safe HUD, and regression tests.

### Confirmed source-level observations
- The branch comparison against `main` reports 39 commits ahead and 0 behind.
- The comparison reports only the intended 10 changed files: checklist, BubbleGun client/service, PilotPriority service, HUD, Bootstrap, RoundService, GameConfig, smoke tests, and project validator.
- The existing `StrikeService.lua`, `BotService.lua`, `ArenaService.lua`, `Audio.client.lua`, `default.project.json`, and upload workflow are unchanged in the branch diff.
- `ROUND_SECONDS = 180`, `MAP_COUNT = 1`, and the existing Universe/Place IDs remain unchanged.
- No Pull Request for Update #18 has been created. No merge or Roblox upload has been performed.

### Remaining verification and delivery work
- [ ] Run `python tools/validate_project.py` against this exact branch.
- [ ] Run `selene src tests` and resolve all diagnostics.
- [ ] Run `rojo build default.project.json` and inspect the generated place.
- [ ] Confirm GitHub Actions validation is green for this branch.
- [ ] Review the full diff for protected drone, lens, laser, map, round duration, and publishing workflow changes.
- [ ] Execute the Roblox cloud smoke test only after the place version is deliberately uploaded to the existing private test place.
- [ ] Verify mobile touch input, Safe Area/thumbstick separation, and multiple clients in Studio/device testing. These cannot be inferred from static source review.
- [ ] Perform a final separate code-review pass.
- [ ] Create the Update #18 Pull Request against `main` only after the repository checks succeed.
- [ ] Do not merge or publish.

### Verification status at this checkpoint
- Source changes: committed to the feature branch.
- Structural validator: updated, not executed in this environment.
- Selene: not executed.
- Rojo build: not executed.
- GitHub Actions check result: not confirmed by the available status response.
- Roblox cloud/runtime tests: not executed.
- Device Simulator/real phone: not tested.
- Multiplayer clients: not tested.
- Pull Request: not created.
- Merge/upload/publication: not performed.

Do not mark implementation or test items complete based only on source inspection. The source-level work is not a substitute for a successful build, lint, Roblox runtime test, or phone test.


## Recovery checkpoint (2026-11-16, latest CI and self-review)

Continue from this branch and commit. Do not restart the Update #18 implementation.

### Saved source state
- Latest reviewed implementation commit: `7e32919de1b3406bd33b273e3fed292922e4cd2d`.
- Current branch: `feat/018-bubble-blaster-pilot-priority`.
- Base: `main`, comparison: 47 commits ahead, 0 behind.
- Exactly 10 changed files in the branch comparison: this checklist, BubbleGun client/service, HUD, Bootstrap, PilotPriorityService, RoundService, GameConfig, cloud smoke tests, and `tools/validate_project.py`.
- Protected systems remain outside the diff: `StrikeService.lua`, `BotService.lua`, `ArenaService.lua`, `Audio.client.lua`, `default.project.json`, and `.github/workflows/upload-private-test.yml`. Round duration remains 180 seconds and map count remains 1.

### CI evidence on the reviewed source commit
- GitHub Actions run: [43887761737](https://github.com/Vx1133/SkyfallArena1/actions/runs/43887761737), head `7e32919de1b3406bd33b273e3fed292922e4cd2d`.
- Result: **success**.
- `python tools/validate_project.py`: passed.
- `selene src tests`: passed, 0 errors, 0 warnings, 0 parse errors.
- `rojo build default.project.json`: passed.
- Build artifact: `SkyfallArena-place`, artifact ID `14234913431`, created by this run.

### Issues found and repaired during final review
- Updated the stale validator assertion for the first solo-human controller exception to match the current `readyPlayers` flow.
- Added a structural guard for balanced duplicate-Tool cleanup, then removed the extra `end` that Selene had identified in `BubbleGunService.lua`.
- Reformatted seven one-line statements in the cloud smoke tests; Selene then passed without warnings.
- Found that stale dead human Runner entries could be selected through the sole/longest-survivor fallback if a death event was delayed. `_getSoleSurvivor` now reuses the living-human filter, and `_getLongestSurvivor` now requires a present living Humanoid with Runner role. Added a regression smoke test for both pre-timeout and timeout resolution. The source validator, Selene, and Rojo all passed after this change.

### Still unverified and must remain unchecked
- Roblox Cloud smoke tests have **not** been run. The repository workflow requires the explicit manual input `UPLOAD_PRIVATE_TEST` and uploads a new version to the existing Start Place before running the cloud script. It does not make the experience public, but it does modify the configured private place version.
- Device Simulator, real-phone touch/Tool use, Safe Area/thumbstick overlap, and multi-client multiplayer testing have not been run.
- The smoke-test script is linted and included in the project, but its live Roblox execution is not proven by the regular validation workflow.
- No Update #18 Pull Request has been created yet at this checkpoint. No merge, Roblox upload, or public release has been performed.

### Next actions
- [ ] Obtain the explicit private-place upload confirmation before running the manual Roblox upload/cloud-test workflow.
- [ ] Run the cloud smoke tests against the exact uploaded private place version and inspect the success marker/logs.
- [ ] Run Device Simulator and real-phone checks, then test with at least two clients.
- [ ] Create the Update #18 Pull Request against `main` after final checks. Keep it unmerged and do not publish publicly.


## Pull Request checkpoint (2026-11-16)
- [x] Draft Pull Request #18 created against `main`: https://github.com/Vx1133/SkyfallArena1/pull/18
- PR head when opened: `bbfd1404718529a00672751f1740105054e5832e`.
- PR is open and unmerged. No Roblox upload or public release occurred.
- The PR description records the successful repository CI run and leaves cloud/device/multiplayer verification explicitly pending.
