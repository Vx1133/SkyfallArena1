# Skyfall Classic Studs, Ten Bots, Lobby-First Update

## Goal
Replace the polished Sunspire/modern lobby look with a connected Classic Roblox stud-built arena and lobby; normalize lighting; increase the bot roster to ten; require a deliberate Play action before any round; and give only the experience's personal creator account a server-validated flight inspection mode.

## Current baseline
- PR #8 is already merged to main.
- Main SHA at start: 92055e7d6cebacd27d13b019114cb4fae1454034.
- The project already has one 15x15 destructible arena, a separate lobby, one gold orb, a 180-second round, and a top HUD.
- Current configuration uses 3 bots and a 0.35-stud gap between tiles.
- RoundService automatically begins an intermission as soon as a human joins.
- The map forces a custom sky, Atmosphere, Clouds, ColorCorrection, Bloom, and SunRays.
- BotService creates 3 NPCs, including custom procedural fallback hair.
- The drone lens faces forward/sideways rather than directly down.

## User requirements
1. Restore a natural Roblox default sky/lighting look and remove the custom effects that make tiles look overexposed or reflective.
2. Keep ten AI bots, with appearance created through Roblox's built-in HumanoidDescription and player-model APIs. Do not construct fake hair or import unreviewed character packages.
3. Replace the map and lobby with a connected, readable Classic Stud / Retro Roblox environment. Tile surfaces must touch with no designed gap, and the wider arena foundation should read as one connected platform.
4. Retain the golden spherical drone. Place its red lens/reticle on the underside and point the target/weapon down toward the arena.
5. Players spawn in the lobby and remain there until they explicitly press Play. A join must never auto-start a round.
6. Add a flight inspection mode for the personal experience creator only. Authorization must be server-side and must never trust a client-only flag. If the experience is group-owned, owner-only flight is disabled until the owner's personal Roblox UserId is explicitly supplied.
7. Make the top HUD more compact and translucent, inside the phone safe area. Keep round timer and participant counts visible only during active rounds. Place lobby controls away from movement/jump regions.

## Design decisions
- Keep the existing universe (7975091208), Start Place (104752078056182), 15x15 tile grid, round survival rules, blue laser, red target warning, 3-second cooldown, and longest-survivor controller selection.
- Generate every map/lobby part from Luau. No third-party model, mesh, or script packages are imported.
- Use green Plastic floor tiles with 3x3 raised stud geometry per tile. Set TILE_GAP to exactly 0. The 3x3 pattern aligns to a uniform 4-stud grid across tile boundaries. Use a continuous sub-floor under the destructible grid.
- The waiting lobby is a separate green baseplate with stud geometry, colored classic brick structures, simple block trees, benches, clear spawn space, and no bridge into the arena.
- Reset Lighting to neutral defaults: Brightness 2, ClockTime 14, Ambient black, OutdoorAmbient 127, ExposureCompensation 0, environment diffuse/specular 0, GlobalShadows on, and no Sky, Atmosphere, Clouds, ColorCorrection, Bloom, or SunRays instances created by this project.
- Create exactly Config.BOT_COUNT (10) bots by cycling three simple AI behavior profiles. Let Roblox build the rig from HumanoidDescription. Remove all custom fallback hair builders and asset IDs.
- Add a server-backed PlayRequest RemoteEvent. Keep players in Waiting until they opt in. Intermission begins only when at least one human has requested Play. Only ready humans are moved into a round; bots join as the remaining participants. Reset ready state after results so another deliberate Play action is required.
- Admin flight uses a separate RemoteEvent and server service. The service authorizes only when game.CreatorType is User and player.UserId equals game.CreatorId. Group-owned experiences receive no implicit admin identity. Flight is available only in Waiting, is speed-clamped, and is force-disabled before intermission/round start.
- Lens normal is exactly Vector3.new(0, -1, 0), and its disc/reticle frame is built so the lens surface points vertically down. LaserOrigin remains at the orb underside.
- Mobile HUD uses a compact translucent status bar near the top safe area. Play/Flight controls appear only in the lobby, not over the bottom movement controls.

## Security and scope
- No external asset packages or scripts.
- No client-trusted admin flags, UserIds, or movement magnitudes.
- No publish, privacy change, universe creation, place creation, or credential changes.
- Existing workflow remains the release mechanism after review and explicit manual dispatch.
- Structural validation and Luau lint/Rojo build cannot prove live camera, physics, or rendering. A private Roblox mobile playtest remains required.

## Acceptance criteria
- Exactly 10 bots spawn in the lobby and are returned there between rounds.
- No round begins from PlayerAdded alone. One human pressing Play is sufficient to schedule a match.
- The lobby and arena remain physically separate.
- Every floor tile is positioned with zero designed gap, and the floor has a continuous support platform.
- The custom sky/effects are absent and neutral Lighting settings are applied.
- Golden drone red lens faces downward.
- Only the personal creator can enable flight. Non-owner requests are ignored; group-owned experiences do not auto-authorize group members.
- Flight stops automatically when the phase leaves Waiting.
- Active-round HUD is translucent, compact, safe-area aligned, and reports countdown/participants.
- Cloud tests cover the configuration, readiness flow, bot count, owner authorization, and arena spacing. CI lint and Rojo build pass.
