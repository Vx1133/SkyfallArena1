# Update #24: Global Startup Freeze and Infinite Wait Hardening

## Status
Implementation is on branch `fix/024-global-startup-freeze-guard`, based on the merged Update #23 commit. This change is prepared for review in a pull request. It has not been merged or uploaded to Roblox.

## Findings from source inspection

### 1. HUD initialization depended on streamed Workspace geometry
The client HUD called `Workspace:WaitForChild("SkyfallArena"):WaitForChild("Tiles")` before constructing its ScreenGui and Play button. The Rojo project enables Workspace streaming. A client can receive the StarterPlayer script before those Workspace descendants stream in, so this wait could delay the entire HUD startup. The HUD now initializes from replicated UI dependencies only. It looks up the arena tile folder with `FindFirstChild` only when an aircraft controller actually targets a tile. A not-yet-streamed arena therefore disables targeting temporarily without blocking the menu.

### 2. NPC construction ran synchronously inside server bootstrap
`BotService.new()` previously called `Players:CreateHumanoidModelFromDescriptionAsync()` ten times, one after another, before `Bootstrap.server.lua` reached `RoundService:Start()`. The API yields, and wrapping it in `pcall` catches errors but does not impose a time limit. Slow avatar construction could therefore delay the game services and the first round.

Bot construction now runs through one background queue. Each bot rig attempt has a 14-second deadline. A timed-out attempt is marked, its token is invalidated, and the queue continues. If Roblox returns an avatar model late, the stale model is destroyed instead of being installed. Failed and timed-out rigs are eligible for a later retry after a 30-second cooldown.

### 3. Round readiness depended on controller candidates existing immediately
With bot creation moved off the bootstrap path, the round loop must not select a controller before at least one rig is ready. The loop now remains in Waiting, yielding every 0.5 seconds, until a ready bot exists or a human explicitly opts in to aircraft control. The choice is covered by a pure policy module and Lune test.

### 4. Other client and module dependencies
Audio, Bubble Blaster, Admin Flight, server service modules, map builders, lighting, and shared configuration waits were reviewed. Single-argument waits in the reviewed source were changed to explicit 8-second waits, with warnings or fail-fast diagnostics where appropriate. The Audio HUD hook is optional so a missing HUD cannot keep the audio dependency task waiting forever.

### 5. Startup diagnostics and stage deadlines
Server bootstrap now logs BEGIN, READY, FAILED, and TIMEOUT records with elapsed time. Required folders and remotes are type-checked. Arena construction has a 20-second stage deadline, and service startup has a 10-second deadline. A yielded stage that exceeds its deadline is cancelled and reported clearly.

## Files changed
- `src/server/Bootstrap.server.lua`
- `src/server/Services/BotService.lua`
- `src/server/Services/RoundService.lua`
- `src/server/Services/ArenaService.lua`
- `src/server/Services/BubbleGunService.lua`
- `src/server/Services/StrikeService.lua`
- `src/server/Services/AdminFlightService.lua`
- `src/server/Services/ClassicNatureMapBuilder.lua`
- `src/server/Services/CyberpunkMapBuilder.lua`
- `src/server/Services/ElementIntegrationService.lua`
- `src/server/Services/LaserVFX.lua`
- `src/server/Services/LightingProfileService.lua`
- `src/server/Services/MapDecorationFactory.lua`
- `src/server/Services/PilotPriorityService.lua`
- `src/shared/GameConfig.lua`
- `src/shared/StartupReadinessPolicy.lua`
- `src/client/HUD.client.lua`
- `src/client/Audio.client.lua`
- `src/client/BubbleGun.client.lua`
- `src/client/AdminFlight.client.lua`
- `tests/lune/update_024_startup_guard.luau`
- `tools/validate_project.py`
- `.github/workflows/validate.yml`

## Validation
The PR workflow is configured to run:
- Existing Lune policy tests plus `update_024_startup_guard.luau`
- Python structural validation, including a source-wide audit against single-argument/unbounded `WaitForChild` calls
- Selene lint
- Rojo place build and build artifact upload

## Important limits
- No live Codex session was connected, so no Codex execution or review is claimed.
- Roblox Studio and the live Roblox Runtime/Output window were not accessible here. No live server/client play session, visual inspection, or mobile device test is claimed.
- No root-cause conclusion can be attributed to a captured live Output stack trace. The two source risks above are concrete startup blockers consistent with the reported symptom, but runtime confirmation is still required.
- A watchdog can cancel a yielded task or bounded stage. It cannot safely preempt a non-yielding CPU loop while that loop is monopolizing the Luau VM. The reviewed recurring loops in the key gameplay services contain yields; the automated CI and a live Studio playtest are still needed to confirm behavior.

## Release state
The PR must remain open for review. Do not merge or run the private Roblox upload workflow until the owner explicitly requests those actions.
