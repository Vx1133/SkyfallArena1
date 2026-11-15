# Procedural 24-Layer Laser VFX Design

## Intent
Replace the current five-pass instant beam with a code-generated, time-bounded laser effect that feels like one deliberate shot. Keep the existing aircraft aiming, warning tile, target validation, destructive floor, and mobile-first constraints.

## Goals
- Build a 24-element visual stack in Luau: 14 Beam passes, 4 manual particle emitters, 2 short-lived PointLights, and 4 expanding pulse spheres.
- Extend the beam endpoint from the source attachment to the selected tile over 0.24 seconds.
- Hold briefly, then fade the beam and remove all temporary instances.
- Preserve one tap = one server-authorized shot and the existing exact 3-second human cooldown.
- Display a controller-only charge/cooldown bar synchronized with server time.
- Use Roblox built-in textures only. Do not import Blender models or external assets.

## Non-goals and platform constraints
- No custom GPU shader, post-process displacement buffer, or true screen-space refraction. Roblox's standard public API does not expose a user-authored screen distortion shader.
- No automatic continuous beam, no client-authoritative damage, and no changes to tile reset behavior.
- No automatic publish, experience visibility change, or merge to main.
- No high-rate always-on emitters, per-frame server loops, or dozens of persistent Parts.

## Approaches
1. Keep the existing five Beams and add wider widths. Rejected because it does not create a controlled extension, organized layers, or readable cooldown feedback.
2. Spawn 20-30 independent Parts and particle systems. Rejected because replicated geometry and shadow/physics overhead are unnecessary for a short-lived beam.
3. Use 14 attachment-linked Beam passes, 4 one-shot ParticleEmitters, 2 transient lights, and 4 pulse spheres, all grouped and cleaned up by Debris. Selected because Beams carry the long visual line efficiently while short-lived effects are bounded and server-authoritative.

## Architecture
- `LaserVFX.lua` owns all visual construction, endpoint tweening, impact burst, fade, and cleanup.
- `ArenaService:CreateStrikeBeam(tile)` becomes a thin delegate to LaserVFX.
- `StrikeService` remains authoritative. It retains the 1.5-second warning and 3-second server cooldown, delays tile break until the animated beam reaches the target, and replicates a server-time ready-at attribute for the HUD.
- `HUD.client.lua` displays a low-frequency updated cooldown status only while the human is the active controller.

## Timing
- Extension: 0.24 seconds.
- Impact hold: 0.08 seconds.
- Beam fade: 0.14 seconds.
- Human activation cooldown: exactly 3 seconds, still validated with the existing server clock gate.
- The 1.5-second target warning remains unchanged.

## Performance budget
- 14 short-lived Beam instances, 4 manual Emit calls with a bounded total burst, 2 transient PointLights, and 4 small non-collidable pulse Parts per shot.
- All temporary effects are non-collidable, non-touchable, non-queryable, shadowless, and automatically cleaned up.
- No always-on emitters and no RenderStepped VFX animation on the server.
- Real FPS and device thermals still require a private mobile playtest.
