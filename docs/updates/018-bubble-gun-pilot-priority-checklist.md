# Update 018: Bubble Blaster + Pilot Priority + Multiple Winners

> Status: Planning. A checkbox may be marked complete only after the named test or direct evidence is recorded below.
> Branch: `feat/018-bubble-blaster-pilot-priority`
> Base: `main`

## 1. Repository review and implementation plan
- [x] Read current GameConfig, Bootstrap, RoundService, StrikeService, BotService, HUD, Audio, Rojo project mapping, and cloud smoke tests. Evidence: fetched all requested files from `main`; RoundService (1,229 lines), BotService (808 lines), and cloud smoke tests (981 lines) reviewed in sections.
- [x] Confirm lobby spawn geometry and available bot target interfaces. Evidence: lobby platform is `ArenaService.lobbyFolder/WaitingPlatform`, spawn radius is 49 studs, and `BotService:GetAliveBots()` exposes live Runner bot models and Humanoids.
- [x] Record implementation plan and exact files to change. Plan: isolate session scoring in `PilotPriorityService`; isolate Tool, lobby station, projectile, target validation, and hold cleanup in `BubbleGunService`; wire lifecycle callbacks through `RoundService`; keep input/reticle in a client script; keep HUD changes isolated to `HUD.client.lua`.
- [ ] Confirm protected systems: golden drone model, lens, laser visuals, map count, round duration, and publishing workflow remain unchanged.

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
- [ ] Run cloud smoke tests and project structural validation.
- [ ] Run Selene on `src` and `tests`.
- [ ] Run `rojo build default.project.json`.
- [ ] Review diff for protected drone, lens, laser, map, round duration, and publish workflow changes.
- [ ] Record each test result and any untestable device/runtime behavior below.
- [ ] Verify Device Simulator and a real phone for touch, Safe Area, Tool equip/fire, and thumbstick overlap (mark unverified if unavailable).
- [ ] Verify multiplayer behavior with at least two real clients when available (mark unverified if unavailable).

## 9. Review and delivery
- [ ] Perform an independent code review or documented self-review if no reviewer agent is available.
- [ ] Resolve all critical and important findings.
- [ ] Create a Pull Request against `main`.
- [ ] Confirm CI results for structural validation, Selene, and Rojo build.
- [ ] Do not merge or publish this update.

## Evidence log
| Item | Evidence / command / result |
|---|---|
| Repository baseline | Existing files read from `main`; current service interfaces inspected |
| Checklist created | Commit SHA to be recorded |
| Tests | Pending |
| Device / multiplayer runtime | Pending |
| Review | Pending |
\n## Implementation plan (approved scope from the supplied specification)\n- `src/shared/GameConfig.lua`: add only bubble and Pilot Priority constants, preserving `ROUND_SECONDS = 180` and all laser/drone values.\n- `src/server/Bootstrap.server.lua`: create the BubbleShot remote, require/start the two new services, and connect RoundService lifecycle callbacks.\n- `src/server/Services/PilotPriorityService.lua` (new): own in-memory per-human scores, one-reward-per-round guard, tie-breaking timestamps, and selection.\n- `src/server/Services/BubbleGunService.lua` (new): build the trusted native Tool and lobby station, centralize grants, validate shots on the server, create projectile/bubble visuals, and restore held targets on every cleanup path.\n- `src/server/Services/RoundService.lua`: delegate score/selection, grant the Tool to Runners only, remove nextController bypass, reward eliminations/winners, and broadcast all human co-winners.\n- `src/client/BubbleGun.client.lua` (new): connect standard Tool equip/Activated input, camera aim, and a compact equipped reticle.\n- `src/client/HUD.client.lua`: add only the small DRONE percentage text, update on the score attribute, and keep it away from thumbstick/safe-area edges.\n- `tests/cloud_smoke_tests.luau` and `tools/validate_project.py`: add regression and structural checks.\n- Reviewed but planned unchanged: `StrikeService.lua`, `BotService.lua`, `Audio.client.lua`, `default.project.json`, and `ArenaService.lua`. Their current interfaces already support the requested integration. No external models, DataStore, map edits, laser edits, or publishing workflow changes.\n