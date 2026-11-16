# Update 018: Bubble Blaster + Pilot Priority + Multiple Winners

**Branch:** `feature/update-018-bubble-blaster-pilot-priority`  
**Base:** `main`  
**Status:** Planning started. No implementation task is marked complete yet.

## Implementation checklist

### A. Repository audit and constraints
- [ ] Read `GameConfig.lua`, `Bootstrap.server.lua`, `RoundService.lua`, `StrikeService.lua`, `BotService.lua`, `HUD.client.lua`, `Audio.client.lua`, `default.project.json`, and `cloud_smoke_tests.luau`.
- [ ] Trace current lobby geometry, player roles, runner/bot state, controller selection, winner resolution, and round cleanup.
- [ ] Preserve the existing experience, Start Place, Classic arena, golden drone, red lens, laser implementation, map count, 180-second round, and private publishing state.
- [ ] Record implementation plan and changed-file scope before gameplay code changes.

### B. Bubble Blaster asset and lobby trial station
- [ ] Build a project-owned Classic Roblox-style turquoise, pearl-white, and subtle-gold Bubble Blaster from native Parts only.
- [ ] Create a real Roblox `Tool` with a valid Handle, welded details, muzzle attachment, and lightweight bubble VFX.
- [ ] Add a compact display pedestal near the lobby spawn without obstructing the PLAY control or normal spawn positions.
- [ ] Add a `ProximityPrompt` labelled `TRY FOR FREE` with keyboard, gamepad, and touch support.
- [ ] Keep the station available to every player and give each player at most one owned test copy.
- [ ] Add a stationary, isolated training target beside the station.
- [ ] Centralize trial/free Runner grants so a future ownership check can replace them without rewriting weapon logic.
- [ ] Grant one copy to each human Runner at round start, never to the controller.
- [ ] Prevent duplicate copies across respawns, re-equips, and later rounds.

### C. Server-authoritative Bubble Blaster
- [ ] Add configurable capture duration (2.5 seconds), fire cooldown (8 seconds), and maximum range (60 studs).
- [ ] Add a client controller for Tool activation, camera-direction aiming, mobile activation, and a small equipped-only reticle.
- [ ] Add server validation for tool ownership/equipment, role, cooldown, finite unit direction, range, line of sight, and valid target.
- [ ] Accept only the training target while waiting; accept only living Runner players and supported living Runner bots during an active round.
- [ ] Reject self-hits, controllers, spectators, lobby players, invalid targets, duplicate captures, and client-supplied target/user identifiers.
- [ ] Allow one target per projectile and prevent direct damage or killing.
- [ ] Create readable moving bubble projectile and capture/pop visual effects with mobile-safe instance counts.
- [ ] Snapshot movement/physics properties before capture and restore them after expiry, death, character removal, player departure, or round cleanup.
- [ ] Ensure a Runner falls normally if the floor tile beneath them is destroyed during capture.
- [ ] Keep the server as the authority for hit detection and capture state.

### D. Pilot Priority
- [ ] Add a per-human session-only Pilot Priority score in the inclusive 0–100 range.
- [ ] Display the score as a percentage and update the player attribute only when the score changes.
- [ ] Award +0 for elimination before 30% of the round (54 seconds).
- [ ] Award +5 for a valid Runner elimination at or after 30% and before the round win.
- [ ] Award +10 to every human Runner winner, instead of +5, with no double award.
- [ ] Do not award bots, departed players, or duplicate round rewards.
- [ ] Cap the score at 100 and clear departed-player state.

### E. Pilot selection
- [ ] Select the highest-priority ready human for the drone after the protected solo first-round exception.
- [ ] Break priority ties by the longest time since the player's previous controller turn.
- [ ] Randomize only among players still tied after the previous-controller rule.
- [ ] Reset the selected player's score to zero and record the selection round.
- [ ] Prevent immediate repeat selection when another player has equal priority.
- [ ] Preserve the first-round single-human bot-controller exception.
- [ ] Prefer a ready human over bots after the first-round exception; use a bot only when no human is eligible.
- [ ] Remove all authority for the legacy `nextController` shortcut to bypass priority ordering.

### F. Multiple winners and result state
- [ ] At the 180-second timeout, award every living human Runner as a winner.
- [ ] Award +10 Pilot Priority and one win statistic to each such human, exactly once.
- [ ] Preserve sole-survivor win behavior before timeout.
- [ ] Preserve the current controller-win fallback when no Runner remains.
- [ ] Keep winner names, role attributes, anchored result poses, round state broadcasts, and result countdown consistent with multiple winners.
- [ ] Preserve instant floor reset and existing round/lobby transitions.

### G. Pilot Priority HUD
- [ ] Add a compact `DRONE NN%` indicator near (not over) the mobile movement thumbstick.
- [ ] Keep text white, readable, subtle, and approximately 10–12 px.
- [ ] Respect screen safe areas and avoid the jump button, tool controls, and center view.
- [ ] Show during Waiting and Runner play; hide while controlling the drone.
- [ ] Update only when the replicated priority value changes.
- [ ] Preserve the existing top round timer/player count bar and laser controller UI.

### H. Automated tests and validation
- [ ] Extend cloud smoke tests for the trial station, prompt, training target, tool uniqueness, and grant rules.
- [ ] Test fire rate, range, direction validation, line of sight, role restrictions, and target eligibility.
- [ ] Test single-target hit, capture duration, movement restoration, death/removal cleanup, and tile-break fall behavior.
- [ ] Test 30% elimination threshold, +5/+10 exclusivity, caps, no bot rewards, no duplicate rewards, and departure behavior.
- [ ] Test priority ordering, tie-breaking, anti-repeat, score reset, first-round solo exception, human-over-bot fallback, and legacy shortcut removal.
- [ ] Test timeout multiple human winners, a sole winner, and controller fallback.
- [ ] Test no duplicate tool grants after respawn or later rounds.
- [ ] Test that arena reset, golden drone, lens, laser, and controller camera remain unchanged.
- [ ] Run project validation, Selene, and Rojo build in CI.
- [ ] Inspect the final diff for unintended or protected-file changes.
- [ ] Run Device Simulator and real phone touch tests (record as pending if unavailable).
- [ ] Run a live private multiplayer test with real players (record as pending if unavailable).

### I. Review and delivery
- [ ] Create a feature branch and keep all update changes isolated from `main`.
- [ ] Open a Pull Request only after source review and available automated checks.
- [ ] Do not merge or publish this update.
- [ ] Report completed items with evidence and explicitly list every untested live/device behavior.

## Plan and intended file scope

Planned implementation targets (subject to findings during the audit):
- `src/shared/GameConfig.lua`
- `src/server/Bootstrap.server.lua`
- `src/server/Services/RoundService.lua`
- `src/server/Services/BotService.lua` (only the minimal Runner-bot support needed)
- `src/server/Services/BubbleGunService.lua` (new)
- `src/client/BubbleGun.client.lua` (new)
- `src/client/HUD.client.lua`
- `tests/cloud_smoke_tests.luau`
- `tools/validate_project.py`

The golden drone/laser implementation and `default.project.json` are read-only unless a demonstrated Rojo mapping issue requires a documented exception.

## Evidence log

- Repository audit: pending.
- First checklist-only commit: pending.
- Implementation commits: pending.
- Automated CI: pending.
- Device Simulator / real phone: pending.
- Live multiplayer: pending.
- Pull Request review: pending.
