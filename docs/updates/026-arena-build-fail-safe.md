# Skyfall Arena Update #26: Fail-Safe Arena Decoration Startup

## Historical investigation

### What the release history confirms

- GitHub PR #21 is titled **Update #23: distinct map redesign, shared lobby finishes, and control fixes**. It merged as commit `2d2e12d12dcb0feade58c3e013a418cb3dd53320`.
- The upload workflow published that commit as Roblox place version **20**.
- The upload of Roblox place version **21** used commit `c65e40d0f136edc06abd99140e9c528c5a41134c`, the Update #24 client HUD streamed-arena wait fix.
- Roblox place version **22** used commit `0d28c5fb99b1d67c54e2d77408f8e88eda258ebb`, after Update #25 was merged.
- GitHub PR #23 was an unmerged/superseded startup-fix attempt. It did not produce a Roblox upload.
- The upload workflow reported success for these versions, but headless Roblox Luau smoke tests were skipped because `ROBLOX_LUAU_TEST_API_KEY` was not configured.

### Confirmed risky change introduced in Update #23

Before Update #23, map decoration generation and element-transition generation were allowed to fail without stopping the arena. Update #23 changed the behavior:
- The new map builder was called directly during `ArenaService:Build()` and `SetMap()`.
- An `ElementIntegrationService.Build()` failure was promoted from a warning to a fatal `error()`.
- New strict surface audits could also throw out of `SetMap()`.
- `ArenaService:Build()` calls `SetMap(1)` before Bootstrap constructs and starts `RoundService`.

Therefore, one decorative/map-surface failure could stop `ArenaService:Build()` before the round service connects PlayRequest, before the first player character is loaded, and before `SkyfallGameReady` becomes true. This is a concrete source-level regression path consistent with a screen showing only sky/UI. Without the original live Roblox Output, the exact runtime assertion that failed cannot be named as proven.

## Update #26 implementation

### 1. Keep core gameplay readiness separate from decoration readiness

The core arena is considered ready only when:
- The lobby WaitingPlatform exists under the lobby folder.
- Exactly the configured 15 × 15 gameplay tile grid has been created.

A pure `ArenaStartupPolicy` reports gameplay readiness from this core state alone. Decorative geometry is tracked separately.

### 2. Fail open for optional map visuals

- Classic/Cyberpunk geometry generation runs as an isolated optional stage.
- If a map builder errors, partial generated decoration is cleared and the map falls back to the already-created lobby and collision tile grid.
- Element transition visuals are isolated separately. An error removes only the partial ElementTransitions folder.
- Surface audits run in protected calls. A failed audit emits a named warning and diagnostic status rather than terminating player startup.
- Global lighting application is isolated as an optional stage.
- The server records statuses on the arena root and emits `[SkyfallArenaBuild]` CORE_READY, OPTIONAL_STAGE_FAILED, and ARENA_READY diagnostics.

### 3. Keep true core failures visible

A missing lobby WaitingPlatform or an incomplete 225-tile gameplay grid remains a fatal core build error. Update #26 does not hide a genuinely unusable arena behind a green readiness flag.

## Files changed

- `src/server/Services/ArenaService.lua`
- `src/shared/ArenaStartupPolicy.lua`
- `tests/lune/update_026_arena_bootstrap_guard.luau`
- `.github/workflows/validate.yml`
- `tools/validate_project.py`
- `docs/updates/026-arena-build-fail-safe.md`
- `docs/handoffs/CODEX_UPDATE_026_ARENA_BUILD.md`

## Validation and limitations

CI must run all existing Lune suites, the new Update #26 fail-open policy test, repository structural validation, Selene, and Rojo place build.

No Roblox Studio Runtime/Output session is available in this environment. The PR does not claim that the original live error was reproduced. After upload, inspect Output:
- `[SkyfallArenaBuild] CORE_READY tiles=225`
- `[SkyfallArenaBuild] OPTIONAL_STAGE_FAILED ...` if a visual stage falls back
- `[SkyfallArenaBuild] ARENA_READY ...`
- `[SkyfallStartup] READY ArenaBuild`
- `[SkyfallStartup] READY StartGameServices`
- `[SkyfallStartup] GAME_READY`

If the decoration stage fails, the lobby/grid should still load and the avatar should spawn. If CORE_READY is absent, investigate the specific server error before changing more visual code.
