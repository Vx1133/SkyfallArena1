# Skyfall Arena Update #027: One Sky Garden and Controller Safety

## Scope

This update replaces the two-map rotation with one fixed playable map and strengthens the controller-selection safety boundary.

## Single playable map

- The only playable map is now SKYFALL SKY GARDEN ARENA.
- The green natural sanctuary is retained and identified as the single Sky Garden design: mature trees, layered canopies, exposed roots, hanging vines, floating islets, and a curved root arch.
- CyberpunkMapBuilder.lua and the unused MapRotation.lua are removed from the source tree.
- GameConfig declares ACTIVE_MAP_ID = 1 and MAP_COUNT = 1; RoundService uses the fixed ID each round.
- Unsupported map IDs safely fall back to the one configured map.
- The 15 by 15, 225-tile gameplay floor, drone, laser, bots, round duration, and lobby-first Play flow are retained.

## Lobby-matched surface finish

The live WaitingPlatform remains the authoritative finish profile. Map tiles and generated visible BaseParts continue to inherit Material, MaterialVariant, Reflectance, TopSurface, BottomSurface, and supported Texture/Decal children.

The map retains its own green color palette. The lobby's exact baseplate Color is not copied over the map palette. The map surface audit remains in place after each fixed-map build.

## Controller-selection fix

- Normal human aircraft control remains opt-in only. A human must press PLAY and explicitly enable the aircraft icon during Waiting/Intermission.
- Without manual opt-in, the player remains a Runner. A fully built bot is selected as Controller when one is available.
- The owner Debug Drone override is now Studio-only at both boundaries: the button is hidden outside Studio, and the server rejects DebugController requests when RunService:IsStudio() is false.
- End-of-round cleanup clears SkyfallDebugDroneEnabled for every connected player, even when the remembered debug-owner pointer is missing or stale.
- Regression coverage checks that a stale debug flag cannot make the owner the Controller in the next round.

## Dependencies

No new third-party libraries were added. Existing pinned tools remain Rojo 7.7.1, Selene 0.32.0, and Lune 0.11.1.

## Verification boundary

Repository CI is expected to run Lune policy tests, tools/validate_project.py, Selene, and a Rojo place build.

A successful CI run proves source validation, lint, and place packaging only. It does not prove final appearance in Roblox Studio, live bot navigation, controller camera behavior on a phone, or live multiplayer behavior. The Roblox cloud smoke-test secret was not configured at the last recorded upload, so live headless smoke execution must be reported separately.
