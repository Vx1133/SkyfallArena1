# Update #22: Preserve the map, blend existing elements, unify the floor, and make pilot control optional

## Implementation notes

- The existing experience, place, lobby, arena grid, tile positions, tile dimensions, and major geometry are retained. This update does not rebuild the map from scratch.
- The server keeps the existing `SkyfallArena/Environment` folders. It refreshes only `ActiveMap/GeneratedDecor`, preserving other hand-authored lobby and map children.
- The destructible tile grid is reused by its existing `Tile_x_z` names. Existing tiles are not repositioned or resized by this update. Missing tiles are created only when absent.
- The existing lobby `WaitingPlatform` is reused. The Cyberpunk arena floor captures its current Color, Material, MaterialVariant, Reflectance, TopSurface, and BottomSurface, then reapplies that profile when tiles reset.
- Existing Fire, Water, Earth, and Air models are discovered by the `SkyfallElement` tag plus the `SkyfallElementType` attribute, by specific `SkyfallFireElement`, `SkyfallWaterElement`, `SkyfallEarthElement`, and `SkyfallAirElement` tags, or by supported names such as `FireElement`, `WaterZone`, `EarthArea`, and `AirElement`.
- The element integration adds three thin, non-collidable visual transition layers around each discovered existing model or BasePart. It does not move, resize, replace, or create the element models themselves. A subtle point-light pulse is limited to one light per discovered element.
- **Important asset limitation:** the current GitHub source tree does not contain authored Fire, Water, Earth, or Air models. The integration therefore does not invent replacement models. Those existing objects must already be present in the published Workspace and named/tagged as above, otherwise the service warns and does not build their transition layers. Place them under `ActiveMap` or another preserved Workspace folder, not inside `ActiveMap/GeneratedDecor`.
- Human aircraft control now requires a player to set `PILOT: ON` while waiting and also press `PLAY`. If no ready player opted in, an eligible bot controls the aircraft. The opt-in is consumed for that round. The existing owner-only Debug Drone override remains a separate explicit opt-in.
- `StreamingEnabled` was already enabled in `default.project.json`; this update preserves the existing mobile-oriented streaming settings.
- Terrain editing and `Lighting.Technology = Future` are intentionally not forced. The current arena floor is a grid of BaseParts, not a Terrain region, and no mobile device profiling evidence justifies a global Future lighting change.

## Validation

- CI runs the existing Update #19 Lune policy test and the new Update #22 pilot opt-in policy test.
- Python structural validation, Selene linting, and Rojo place build remain part of the validation workflow.
- Roblox Studio visual/physics/mobile playtesting is still required for final in-engine confirmation. A successful static build does not prove runtime behavior.
