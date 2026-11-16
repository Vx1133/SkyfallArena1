# Engineering Handoff: Update #25 Startup Readiness Gate

**Repository:** `Vx1133/SkyfallArena1`  
**Base:** `main`  
**Task:** Fix early Play requests, character readiness, and bot retry after startup timeouts.

## Implementation contract

1. Preserve the current main branch. This update is rebased from main and includes the previously proposed startup hardening without replacing newer main-only fixes.
2. Do not merge or upload Roblox from this work session. The repository owner reviews and merges the PR manually.
3. Do not claim live Runtime or Output verification without a Roblox Studio session.

## Critical invariants

- `ReplicatedStorage.SkyfallGameReady` remains false until the server has connected the PlayRequest listener and started all required services.
- A client may not send a Play request unless the server is ready, the local character is ready, the round phase is Waiting, and the player is not already queued.
- The server must reject a PlayRequest when `SkyfallCharacterReady` is not true, regardless of the client UI.
- `SkyfallCharacterReady` becomes true only after the current character has a live Humanoid and HumanoidRootPart, has entered the world, and has completed the role-specific placement/hidden-controller setup.
- Failed and timed-out bot rig requests are retried after the bounded cooldown. Ready rigs are not retried. Late rig results from invalidated build tokens are destroyed.
- Retry monitoring and round waiting must yield. No tight polling loops.
- Existing 15x15 grid, map rotation, player/bot role rules, controller selection, and HUD layout remain intact.

## Validation required

1. Run all Lune policy tests, including `update_024_startup_guard.luau` and `update_025_startup_guard.luau`.
2. Run `python tools/validate_project.py`.
3. Run `selene src tests`.
4. Build with `rojo build default.project.json --output build/SkyfallArena.rbxlx`.
5. Inspect the diff against current main. Confirm it does not remove the lazy Workspace tile lookup from the HUD or the structural guard added by Update #24.
6. Confirm the Play readiness flag is set false at startup and true only after StartGameServices completes.
7. Confirm both client and server check `SkyfallCharacterReady`.
8. Confirm bot retry monitoring has a wait interval and only requeues Failed/TimedOut rigs after cooldown.

## Studio/runtime release test

After manual merge and private upload:
1. Start a local server with one client and inspect both server and client Output.
2. Confirm the server logs ArenaBuild READY, StartGameServices READY, and GAME_READY.
3. Confirm the client first shows LOADING or SPAWNING while startup/character creation is incomplete.
4. Confirm the player's avatar appears at the lobby spawn before PLAY becomes active.
5. Press PLAY once. Confirm it changes to JOINING, then READY, and the server begins intermission.
6. Complete a round, verify controller selection, runner placement, laser targeting, elimination/respawn, round cleanup, and a second round.
7. If all bot avatar calls fail, confirm the round remains responsive and explicit human pilot opt-in remains usable. Confirm timed-out/failed rigs retry at the bounded cooldown.
8. Repeat with a mobile-sized viewport and lower graphics settings.

## Honest reporting

CI and Rojo build success are source/package checks only. They do not replace Studio runtime testing. Record the exact CI run, commit SHA, place version, and Output evidence. No Codex execution or live Roblox test should be claimed unless actually run.
