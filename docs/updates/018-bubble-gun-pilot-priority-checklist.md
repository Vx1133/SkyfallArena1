# Update 018: Bubble Blaster + Pilot Priority + Multiple Winners

 > Status: Source changes are committed and repository CI has passed on the reviewed implementation commit. Roblox cloud, device, and multiplayer verification remain pending. Feature checkboxes stay unchecked until their required runtime evidence is recorded.
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
- [ ] Run cloud smoke tests (private Roblox upload and live execution still pending).
- [x] Run project structural validation. Evidence: GitHub Actions run `43889959436`, implementation commit `1bf1431915d0ffc13ca0757994ac967a5becb23c`, step `Validate repository structure` passed.
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
- [x] Keep this update unmerged and unpublished while Roblox cloud/device/multiplayer verification remains pending. Evidence: PR #18 is open as a draft and `merged = false`; no upload workflow was run.

## Evidence log
| Item | Evidence / command / result |
|---|---|
| Repository baseline | Existing files read from `main`; current service interfaces inspected |
| Checklist created | `9d7244e0bbefd289f4304221a72211b46860f51f`, plan update `566ead38d40be670eed813294a08ab782e0dfdf9` |
| Repository CI | Python validator, Selene (0 errors, 0 warnings, 0 parse errors), and Rojo build passed. PR validation run `43888479089` passed on `c175e1f529138b1832d78f356fbcfa84e425836e`; documentation-resume run `43889784753` passed on `caf7f3f0c99ccb7016e8ebb8a795ec5cfa53718f`. Live Roblox cloud smoke tests remain pending. |
| Device / multiplayer runtime | Device Simulator, real-phone input/Safe Area, and two-client tests remain pending. |
| Review | Self-review completed and fixes committed; no GitHub reviewer feedback is recorded yet. |

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


## Current checkpoint (2026-11-16)

Continue on the existing branch. Do not create a duplicate branch or Pull Request.

### Repository and Pull Request state
- Branch: `feat/018-bubble-blaster-pilot-priority`.
- Reviewed implementation commit: `1bf1431915d0ffc13ca0757994ac967a5becb23c`.
- Pull Request #18: https://github.com/Vx1133/SkyfallArena1/pull/18
- PR state at the last live check: open, draft, unmerged, and mergeable.
- Comparison against `main`: 51 commits ahead, 0 behind.
- The branch contains exactly the 10 Update #18 files listed in the original implementation plan.
- Protected source/workflow files remain outside the branch diff: `StrikeService.lua`, `BotService.lua`, `ArenaService.lua`, `Audio.client.lua`, `default.project.json`, and `.github/workflows/upload-private-test.yml`.
- `ROUND_SECONDS = 180` and `MAP_COUNT = 1` remain unchanged.

### Repository CI evidence on the reviewed implementation commit
- GitHub Actions run: https://github.com/Vx1133/SkyfallArena1/actions/runs/43889959436
- Head: `1bf1431915d0ffc13ca0757994ac967a5becb23c`.
- Result: success.
- `python tools/validate_project.py`: passed.
- `selene src tests`: passed with 0 errors, 0 warnings, and 0 parse errors.
- `rojo build default.project.json`: passed.
- Build artifact: `SkyfallArena-place`, artifact ID `14235309749` (available at the time of verification).

### Source review and interpretation
- The existing source for Pilot Priority scoring, controller selection, timeout co-winners, winner statistics, and the compact DRONE HUD is present on the feature branch and was reviewed in this pass.
- The regression test source includes coverage for priority rewards, controller tie-breaking, timeout co-winners, and stale/dead Runner entries.
- No new gameplay source changes were necessary in this continuation. The only correction in this pass is this recovery/evidence documentation.
- A successful validator, lint, and Rojo build do not prove live Roblox behavior. The cloud smoke-test script has not been executed in a Roblox server session.

### Remaining verification and delivery
- [ ] Execute Roblox cloud smoke tests against the existing private Start Place after explicit approval of the private upload workflow. The required confirmation is exactly `UPLOAD_PRIVATE_TEST`. No upload has been performed.
- [ ] Verify Tool input, Safe Area, and thumbstick separation in Device Simulator and on a real phone.
- [ ] Verify round behavior with at least two real clients.
- [ ] Obtain an independent GitHub review, or retain the documented self-review if no reviewer is available.
- [ ] Recheck CI on any later source-code change before considering merge.
- [ ] Keep PR #18 unmerged and the Roblox experience private until runtime verification and review are complete.

### Current verification boundary
- Repository structure, Selene, and Rojo build: verified by the linked CI run on the reviewed implementation commit.
- Pilot Priority and co-winner behavior: source and regression-test coverage reviewed; live Roblox execution remains unverified.
- Bubble Blaster gameplay behavior: implementation is present in the branch; the runtime checklist remains unchecked pending Roblox execution.
- Phone input/Safe Area and multiplayer: not tested.
- Pull Request: open as draft, not merged.
- Roblox upload/public release: not performed.

Do not mark a feature-behavior checkbox complete solely because CI passes.