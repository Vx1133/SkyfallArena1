# Procedural Laser VFX System Implementation Plan

> **For agentic workers:** Implement task-by-task. Keep the experience Private and do not merge or publish.

**Goal:** Add a performant 24-element, fully code-generated laser shot with smooth extension, 3-second cooldown feedback, and impact timing.

**Architecture:** A new `LaserVFX.lua` module builds the effect from Beams, attachments, particles, lights and transient pulse Parts. ArenaService delegates creation, StrikeService remains authoritative for shot validation and damage timing, and the existing HUD shows the replicated ready-at time.

**Tech Stack:** Roblox Luau, Beam, Attachment, ParticleEmitter, TweenService, Debris, ScreenGui.

**Spec:** `docs/superpowers/specs/2026-11-16-procedural-laser-vfx-design.md`

## Global Constraints
- Keep Universe ID `7975091208` and Start Place ID `104752078056182`.
- Keep source-of-truth in Luau + Rojo.
- Preserve the existing 1.5-second target warning and 3-second human cooldown.
- Never trust a client-supplied cooldown or damage result.
- Do not add external models, image assets, paid services, or custom shaders.
- Do not merge to main or publish to Roblox.

## Review Focus
- Endpoint attachment and source attachment remain valid while the drone is rotating toward a target.
- Broken tiles remain in Workspace long enough for the impact burst to render.
- Repeated input inside the cooldown cannot create additional effects or break tiles.
- Bot controller shots continue using the same effect without showing the human-only cooldown HUD.
- The HUD remains hidden outside the active controller role and handles a missing ready-at attribute as Ready.

---

### Task 1: Define behavioral tests and configuration

**Files:**
- Modify: `tests/cloud_smoke_tests.luau`
- Modify: `tools/validate_project.py`
- Modify: `src/shared/GameConfig.lua`

**Interfaces:**
- Produces configuration values for extension, hold, fade, layer count and existing cooldown.

- [ ] Add tests asserting the 24-layer breakdown, positive source-to-target texture flow, tweenable endpoint, and particle/light/pulse elements.
- [ ] Run repository validation and observe expected failures while the module and config are absent.
- [ ] Add config constants: extension 0.24, hold 0.08, fade 0.14, total visual layer count 24.
- [ ] Run lint and Rojo build after implementation.

### Task 2: Implement LaserVFX module

**Files:**
- Create: `src/server/Services/LaserVFX.lua`
- Modify: `src/server/Services/ArenaService.lua`

**Interfaces:**
- `LaserVFX.Create(arena, tile) -> boolean`
- `ArenaService:CreateStrikeBeam(tile) -> boolean`

- [ ] Create 14 named Beam passes with shared source/animated endpoint attachments.
- [ ] Tween endpoint position and each Beam width over the configured extension time.
- [ ] Emit 4 manual particle bursts, pulse 2 lights, animate 4 spheres, fade the Beams, and clean temporary instances.
- [ ] Keep the optical source on the current `LaserOrigin` attachment.

### Task 3: Integrate timing, cooldown and HUD

**Files:**
- Modify: `src/server/Services/StrikeService.lua`
- Modify: `src/client/HUD.client.lua`

**Interfaces:**
- Server attribute: `SkyfallLaserReadyAt` (server Unix timestamp).
- Client reads `Workspace:GetServerTimeNow()` only for display; server `os.clock()` remains authoritative.

- [ ] Delay tile break until extension + hold completes.
- [ ] Set `SkyfallLaserReadyAt` after an accepted human shot; retain the server cooldown gate.
- [ ] Show controller-only progress/status UI, refreshed at 10 Hz or less.
- [ ] Keep touch and mouse input single-shot, with no auto-fire.

### Task 4: Verify and review

**Files:**
- All modified files.

- [ ] Run `python tools/validate_project.py`.
- [ ] Run `selene src tests`.
- [ ] Run `rojo build default.project.json -o build/SkyfallArena.rbxlx`.
- [ ] Inspect workflow results and open a PR. Do not merge or publish.
- [ ] Report that private mobile rendering/FPS validation remains outstanding.
