# Skyfall Arena

Skyfall Arena is a mobile-conscious Roblox survival game built around one fixed destructible Sky Garden arena, a golden laser drone, and ten AI-controlled NPC participants.

## Current game design

- The existing Roblox experience and Start Place are retained: Universe ID 7975091208, Start Place ID 104752078056182. The experience remains Private.
- There is exactly one playable map: SKYFALL SKY GARDEN ARENA. Rounds do not rotate to another layout.
- The map keeps a 15 by 15 floor, 225 destructible tiles, zero designed tile gaps, and a natural floating-garden silhouette around the playable grid.
- The lobby WaitingPlatform is the authoritative source for visible map surface finishes. Every generated map BasePart and each playable tile receive the lobby Material, MaterialVariant, Reflectance, TopSurface, BottomSurface, and supported Texture/Decal children. Map colors remain independently art-directed.
- The lobby and Sky Garden use the same Roblox Plastic and native Studs/Inlet visual language. The green map palette is kept separate from the exact lobby baseplate color.
- The golden drone, downward-facing red lens, blue laser, ten bots, and lobby-first PLAY flow are preserved.
- Broken tiles become non-collidable and remain broken until the next round. Reset restores the full grid and its Sky Garden palette.
- The controller camera is a true vertical overhead view. Its height adapts to viewport aspect ratio and arena size, and the drone body is hidden locally so it cannot block the view.
- The active HUD shows the round timer and participant count. PLAY remains separate and is required before joining a round.
- A human becomes the aircraft Controller only after explicitly opting in with the aircraft icon. Without that choice, a ready bot controls the aircraft and the human remains a Runner.
- The owner Debug Drone override is development-only. Its button is visible in Roblox Studio, the server rejects it in live Roblox sessions, and end-of-round cleanup clears its flag for every connected player.

## Map design and mobile performance

The Sky Garden uses three mature tree groups, layered canopies, exposed roots, hanging vines, floating islets, and one curved natural root arch. Decorations are generated from project-owned Luau code and remain anchored, non-collidable, non-touchable, and non-queryable.

The builder has a measured 55-BasePart decoration budget. It uses one localized PointLight, restrained shadows, and Beam-based vines. It does not import third-party map packages or executable model scripts.

Workspace streaming uses a 64-stud high-priority radius and a bounded 192-stud target radius. Static map and NPC parts do not cast shadows. Bot tile lookup uses cached warning coordinates and constant-time grid lookup.

These measures reduce avoidable rendering and repeated search work. They cannot guarantee frame rate or device temperature on every phone. Hardware, graphics settings, network conditions, and live player counts still affect performance.

## Asset and permission safety

Arena, lobby, drone, laser, map decoration, HUD, and audio systems are built from project-owned Luau code. No unreviewed Creator Store model package or executable third-party model is inserted. Roblox audio permissions and actual playback quality still require a live test.

Bot rigs use Roblox's built-in HumanoidDescription system. The server remains authoritative for bot creation, player readiness, role assignment, laser targeting, and controller selection.

## Development and verification

- Luau source in this repository is the source of truth.
- Rojo packages the source into the existing Start Place.
- Rokit pins Rojo, Selene, and Lune. No additional library is needed for the current architecture.
- GitHub Actions runs pure-Luau policy tests, structural validation, Selene lint, and a Rojo place build.
- Roblox headless cloud smoke tests require the separate ROBLOX_LUAU_TEST_API_KEY. Without it, they are skipped and must not be reported as passed.
- Static CI cannot replace a Roblox Studio visual review or real-phone playtest.

## Required live playtest

1. Start a fresh Roblox server after uploading a reviewed private-test build.
2. Join and press PLAY without touching the aircraft icon. The human should remain a Runner while a ready bot controls the drone.
3. Complete a round and join the next one without enabling the aircraft icon. The human must not be forced into the drone.
4. Test opt-in and cancellation explicitly, then test the Studio-only Debug Drone separately in Roblox Studio.
5. Inspect the Sky Garden from top-down and oblique angles, compare tile and decoration finishes to WaitingPlatform, and check low-end mobile graphics.

## Publishing

The manual workflow Upload Skyfall Arena private test targets only the existing Universe and Start Place. It does not create another experience or change the audience setting. Keep the experience private. Publishing and cloud-test credentials remain in GitHub Actions secrets.
