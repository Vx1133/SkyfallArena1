# Skyfall Arena Update #25: Startup Readiness and Early Play Guard

## Base and release state

- Based on the current `main` branch after Update #24 was merged.
- Carries forward the startup hardening from the superseded Update #24 PR #23.
- Adds server and character readiness gates plus automatic retry for failed bot rig generation.
- This PR is intended for review and manual merge. It does not publish or upload the Roblox place.

## Newly confirmed failure paths

### 1. PLAY could be sent before the server listener existed

The client created an active PLAY button while the server was still building the arena and constructing services. The `PlayRequest` RemoteEvent existed early, but the `RoundService` listener was not connected until service construction finished. An early `FireServer()` could therefore be sent before the listener was registered.

**Fix:** `ReplicatedStorage.SkyfallGameReady` starts as false. The server sets it true only after the startup stage has completed and `RoundService:Start()` has registered the game loop and request listener. The HUD displays `LOADING...` and disables PLAY until that replicated flag is true. Client input also passes a pure readiness policy, and the server owns the authoritative request check.

### 2. PLAY could be sent before the player's character was loaded

Character auto-loading is disabled. The server loads the first character asynchronously after it binds `CharacterAdded`. The game services could become ready before the character finished loading and being placed. A round could then begin with no valid character root for that player.

**Fix:** `SkyfallCharacterReady` starts false for each player. The character handler keeps it false while it waits for the Humanoid, HumanoidRootPart, and model parenting, then sets it true only after the current character is valid and has been placed/assigned its role. The HUD displays `SPAWNING...` and keeps PLAY disabled until this attribute is true. `RoundService:RequestPlay`, ready-player selection, and player-controller validation also require this server-owned state.

The character-ready flag is reset when a character is being processed and when a player dies or is eliminated. The next valid CharacterAdded flow restores it.

### 3. All bot rig attempts could fail without an automatic retry

The asynchronous bot queue already continued after a failed or timed-out avatar generation attempt, but failed rigs were only retried when another gameplay path explicitly requested a rebuild.

**Fix:** a yielding retry monitor checks failed/timed-out bot records at the configured retry interval and re-queues them only after their cooldown. Ready rigs are not retried. Existing per-attempt timeout, stale-result token protection, and serialized build queue remain in place.

## Carried-forward startup protections

- HUD startup never waits for streamed Workspace geometry.
- Static dependency waits have explicit timeouts.
- Arena and service startup stages emit BEGIN/READY/FAILED/TIMEOUT diagnostics and use bounded deadlines.
- Bot avatar generation runs in a background queue and does not block initial player/service construction.
- Round start waits for a valid bot controller or a player who explicitly opted into aircraft control.
- Lune tests and structural validation cover the readiness policy and unbounded WaitForChild regression.

## Changed implementation areas

- `src/server/Bootstrap.server.lua`: server readiness lifecycle and widened stage deadlines.
- `src/server/Services/RoundService.lua`: server-side character readiness, request rejection, and ready-player filtering.
- `src/server/Services/BotService.lua`: automatic retry monitor for failed/timed-out rigs.
- `src/client/HUD.client.lua`: loading/spawning states and disabled PLAY until both readiness gates pass.
- `src/shared/StartupReadinessPolicy.lua`: pure decisions for round readiness, Play readiness, and bot retry eligibility.
- `tests/lune/update_025_startup_guard.luau`: regression coverage for readiness and retry rules.
- `.github/workflows/validate.yml` and `tools/validate_project.py`: run and enforce the new regression checks.

## Validation and limitations

The PR CI must pass all Lune policy tests, Python structural validation, Selene lint, and Rojo place build.

A CI pass validates source and place packaging. It does not prove live Roblox behavior. Roblox Studio, live server/client Runtime Output, and a real mobile play session are not available in this implementation environment. After merge and private upload, verify the server Output contains:
- `[SkyfallStartup] READY ArenaBuild`
- `[SkyfallStartup] READY StartGameServices`
- `[SkyfallStartup] GAME_READY`
- `[SkyfallStartup] Bot rig ready: ...`

Then confirm the HUD changes from LOADING/SPAWNING to PLAY, the avatar is visible in the lobby, PLAY starts intermission, and a complete round and second round work.

No Codex execution or Studio runtime approval is claimed. Do not claim the live freeze is fully resolved until those runtime checks are completed.
