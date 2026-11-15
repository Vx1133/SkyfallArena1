# Skyfall Arena

Skyfall Arena is a Roblox survival game built around a fixed 15 by 15 destructible arena, a gold laser drone, and ten AI-controlled NPC participants.

## Current design

- The existing Roblox experience and Start Place are retained. Updates target Universe ID `7975091208` and Start Place ID `104752078056182`. The experience remains Private.
- The playable map is one deterministic, fixed Classic Roblox arena. It does not randomly choose or vary map layouts.
- The green Plastic playfield has zero designed tile gaps. Native Roblox `Studs` top surfaces and `Inlet` undersides create the retro look without separate decorative stud Parts.
- The waiting lobby is one connected green Classic Stud baseplate. Trees, water, seating, floating welcome board, and the old colored entrance posts are removed.
- A continuous four-sided perimeter frame meets the playfield edges. Its corner supports overlap the edge beams, replacing disconnected blue posts and red gate pieces.
- The golden drone, downward-facing red lens, blue laser, 225 breakable tiles, ten bots, and lobby-first Play flow are preserved.
- Broken tiles hide their native stud surfaces and become non-collidable. Their studs return only when a new round resets the floor.
- The drone controller uses a true vertical overhead camera. Its height is calculated from viewport aspect ratio and arena size, with clearance above the drone and a local-only hide for the drone body so it cannot block the view.
- The active-round HUD shows only the round timer and participant count. It sits at the top safe area and is hidden outside the Active phase. The lobby Play control remains separate.
- Low-volume background music, a round-start cue, a Play-button cue, and a positional laser impact sound are included.
- Joining does not start a round. A player must press PLAY in the lobby before the intermission begins.
- Each round lasts at most 180 seconds. The next round resets the broken tiles.

## Mobile performance measures

- Workspace instance streaming is enabled with a 64-stud high-priority radius, a bounded 192-stud target radius, Improved model streaming, and Opportunistic stream-out.
- While a human controls the drone, replication focus follows the drone instead of the hidden character, keeping the overhead arena streamed in.
- Static map Parts and NPC body Parts do not cast shadows. The red target warning uses the tile color rather than creating a dynamic PointLight for every target.
- Native Studs/Inlet surfaces replace thousands of extra stud Parts and the 144 separate lobby floor panels.
- Bot nearest-tile lookup is constant-time. Each bot snapshots warning coordinates once per target decision instead of rescanning the full grid for every candidate tile.
- The ten bots and full 225-tile arena remain because they are core gameplay elements.

These measures reduce avoidable rendering, instance, and repeated search work. They cannot guarantee that every phone will remain cool. Real temperature and frame rate still depend on hardware, graphics settings, network conditions, and live gameplay.

## Asset and permission safety

The arena, lobby, drone, laser, HUD, and audio are controlled by project-owned Luau code. No unreviewed Creator Store model package or executable third-party model script is inserted. Sound assets use Roblox audio IDs; their access permissions and audible quality must still be confirmed in the private live experience.

Bot rigs continue to use Roblox's built-in HumanoidDescription system. The server remains authoritative for bot creation, player readiness, laser targeting, and creator flight.

## Development and release workflow

- Luau source files in this repository are the source of truth.
- Rojo maps the source into a Roblox place file.
- Feature branches and pull requests isolate each update. Pull requests run project validation, Selene lint, and a Rojo build.
- This update does not publish automatically. After review and merge, the separate manual upload workflow may update only the existing Start Place. It does not create a new Roblox experience or make the game public.

## Validation limits

CI checks source structure, Luau lint, and whether Rojo can build the place file. Cloud smoke tests cover map layout, native Classic surfaces, removal of lobby clutter, connected perimeter geometry, streaming settings, ten NPC rigs, Play flow, and round timing.

These checks cannot replace a private in-game test. Camera framing on real phones, actual streaming behavior, audio permissions and audibility, touch input, physics, ten-NPC navigation load, and device temperature still need a live Roblox playtest.

## Publishing

The manual workflow `Upload Skyfall Arena private test` targets Universe ID `7975091208` and Start Place ID `104752078056182`. Keep the experience private. Publishing and cloud test credentials remain in GitHub Actions secrets.
