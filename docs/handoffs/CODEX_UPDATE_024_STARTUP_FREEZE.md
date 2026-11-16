# Codex Handoff: Update #24 Global Startup Freeze

**Repository:** `Vx1133/SkyfallArena1`  
**Branch:** `fix/024-global-startup-freeze-guard`  
**Base:** `main`  
**Task:** Diagnose and fix global startup freeze / infinite wait behavior  
**Change report:** [Update #24 startup freeze fix](../updates/024-global-startup-freeze-fix.md)

## Execution note
This branch contains direct implementation changes and source-based investigation. It is not evidence that Codex or Roblox Studio executed the work. A live Codex session and Roblox Studio Runtime/Output were unavailable in the implementation environment.

## Confirmed source hazards addressed
1. The HUD blocked before building the Play UI on an unbounded wait for `Workspace.SkyfallArena.Tiles`. Workspace streaming is enabled. The HUD now creates UI without waiting for arena geometry and resolves tiles only when targeting.
2. The server bootstrap synchronously constructed ten bot avatars. `CreateHumanoidModelFromDescriptionAsync` yields, and `pcall` alone does not bound that wait. Bot rigs now load in a serial background queue, with a per-attempt timeout, stale-result token invalidation, and delayed retry.
3. Round intermission now waits for a completed bot rig or an explicitly opted-in human pilot. The readiness loop yields and remains in Waiting while no controller is available.
4. Client and server dependency waits in the reviewed startup paths now have explicit timeouts. Missing required server startup dependencies fail with a named diagnostic instead of an infinite wait.
5. Bootstrap startup stages log timing and fail with a timeout if a yielding stage does not complete within the configured deadline.

## Required review
- Confirm all remaining `WaitForChild` calls in `src/` include a timeout.
- Confirm HUD ScreenGui and Play button are built even while `Workspace.SkyfallArena` is not yet streamed to the client.
- Confirm no client script can hold HUD/menu setup on a Workspace descendant wait.
- Confirm `BotService.new()` returns without waiting for HumanoidDescription network generation.
- Confirm rig generation queue proceeds after a 14-second attempt timeout and discards any late model result.
- Confirm an initial player stays in Waiting until a ready bot exists, or the human explicitly opts into control.
- Confirm the existing ten-bot, manual pilot opt-in, lobby spawn, and gameplay behavior remain correct.
- Inspect Output for `[SkyfallStartup]` BEGIN/READY/FAILED/TIMEOUT and per-bot rig status lines.

## Required validation
Run the CI workflow on this branch / PR:
1. `lune run tests/lune/update_019_policy.luau`
2. `lune run tests/lune/update_022_policy.luau`
3. `lune run tests/lune/update_023_lighting_profile.luau`
4. `lune run tests/lune/update_023_world_design.luau`
5. `lune run tests/lune/update_023_control_state.luau`
6. `lune run tests/lune/update_024_startup_guard.luau`
7. `python tools/validate_project.py`
8. `selene src tests`
9. `rojo build default.project.json --output build/SkyfallArena.rbxlx`

## Studio runtime test plan
After the build succeeds, open the built place in Roblox Studio and:
1. Start a local server with one client. Inspect Output from server and client.
2. Confirm the HUD and Play button appear while arena geometry is still streaming.
3. Confirm `SkyfallArena.Tiles` eventually arrives and controller target selection starts working without restarting the HUD.
4. Confirm the server logs ArenaBuild and StartGameServices durations.
5. Confirm the first bot rig appears, then the rest populate without freezing player input.
6. Test a delayed or failed avatar-generation response if the Studio harness supports a controllable stub; verify the queue advances and the Waiting state remains responsive.
7. Press Play, observe intermission and a full round, then verify a second round.
8. Repeat with low graphics and a mobile-sized viewport.

## Reporting rules
Report exact CI run and commit SHA. Separate source/static/CI checks from checks actually performed in Studio. Do not claim the freeze is fully resolved or a 100% runtime verification until the live Studio test has passed.

## Release gate
Leave the PR open. Do not merge, dispatch upload-private-test, publish, or alter the experience privacy setting without an explicit owner request.
