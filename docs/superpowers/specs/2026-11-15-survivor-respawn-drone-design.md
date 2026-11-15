# Skyfall Arena Survivor, Respawn, and Drone Motion Design

## Intent
Make active-round status truthful, ensure eliminated players respawn in the waiting area, preserve reliable fall elimination, and make the golden controller drone feel like a guided mechanical aircraft rather than a static prop.

## Goals
- During an active round, the HUD counts only living runners physically participating in the arena, including living bots. Exclude the controller and all waiting/spectating players.
- After a player dies or is eliminated, remove them from the live count immediately and place their next living character in the waiting area. A dead character must never remain stranded at the previous sky position.
- Keep the controller's top-down camera and controller role intact.
- Reduce the brown support slab to a thin, non-collidable visual foundation. Keep the out-of-bounds check as the actual fall detector.
- Add a subtle hover animation and a motorized gimballed lens that aims toward the chosen tile.
- Improve laser readability with layered beams, a bright impact pulse, particles, and a short-lived shock ring, while keeping effects inexpensive and using built-in Roblox resources.

## Non-goals
- Do not change the game mode, 15x15 arena, ten bots, round duration, map, lobby, or existing Universe/Place IDs.
- Do not publish or change the Roblox experience's privacy.
- Do not add paid assets or third-party runtime dependencies.
- Do not claim a real Studio physics test where no Roblox Studio session is available.

## Technical choices
- Keep server authority for runner rosters and HUD state.
- Use the existing `aliveRunners` table plus BotService's live-bot count as the active population.
- Use the actual CharacterAdded model argument during placement, with generation guards and a bounded respawn recovery path.
- Use a thin, non-colliding support Part and retain the out-of-bounds Y threshold as the elimination source of truth.
- Weld the aircraft's static body to its anchored root. Attach the lens subassembly to a Motor6D and tween its C0 toward the target, then return it home. Tween the root CFrame for slow hover movement.
- Use TweenService and a small number of short-lived Beam, ParticleEmitter, light, and shock-ring effects.

## Constraints
- Preserve the existing controller camera, touch target selection, round state remote contract, mobile performance settings, and private manual publishing workflow.
- Keep all code compatible with the repository's pinned Rojo and Selene versions.
- CI can lint and build the place, but only a private in-game test can validate actual physics, character lifecycle, and visual appearance.
