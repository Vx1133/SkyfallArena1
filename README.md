# Skyfall Arena

Skyfall Arena is a round-based Roblox survival game. Three AI bots and human participants take part on one destructible arena while one participant controls a hovering golden laser sphere. The runner who survives the longest becomes the next round's controller.

## Current game design

- The existing Roblox experience and Start Place are retained. All releases target the same Start Place ID.
- The source supports up to 30 human players, with three additional AI bots for testing. The active arena is one 15 by 15 grid of individually destructible floor tiles.
- The only playable map is **Skyfall Sunspire**, a bright morning environment with pale stone, warm gold trim, soft teal details, garden trees, a floating foundation, and a custom six-face skybox.
- The waiting garden is a separate area. Players and bots return there between rounds and after elimination. There is no bridge or shared floor between the lobby and the arena.
- The controller drone is a detailed gold metal sphere with upper and lower armor plates, a double equatorial band, a red ruby targeting lens, fine reticle details, and a downward laser origin. No pilot platform or visible pilot avatar is placed beside the sphere.
- The target tile flashes red. The strike is a blue outer Beam with a pale blue-white core, visibly connected from the underside of the gold sphere to the selected tile.
- Each active round lasts at most 180 seconds. The HUD counts down from 03:00 and ends early when only one grounded runner remains.
- On the first round with one human player, one bot controls the drone so the human can test the runner role. On later rounds, the previous round's longest-surviving runner becomes the next controller. At the 180-second limit, the highest recorded runner survival time decides the winner.
- The compact mobile HUD appears only during an active round. Its four top-bar values are TIME, PLAYERS, LEFT, and OUT. It respects the device's top safe area.
- The controller camera switches between a close angled landscape view and a near-overhead portrait view. Touch targeting uses a ray from the active camera, and the player's regular camera is restored when the controller role ends.
- Human laser requests are validated by the server and limited to one successful strike every three seconds. A red warning appears before each strike. Destroyed tiles remain broken until the next round begins.
- The three AI bots keep different movement speeds, reaction delays, caution levels, and path choices. They use Roblox PathfindingService, not an external AI service. Their floating nameplates are removed to reduce screen clutter.

## Asset safety and environment

The arena, lobby, golden drone, laser, and bot fallback hair are generated from Luau Parts and Roblox Instances. No third-party map, vehicle, or character model package is imported, and no scripts are brought in from a Creator Store model.

The sky uses six texture IDs documented in Roblox's official lighting tutorial. Those IDs are image textures only, not inserted models or executable packages. Roblox warns that Creator Store models can contain malicious backdoor scripts, so uninspected model imports are intentionally excluded from this update.

## Development and release workflow

- Luau source files in this repository are the source of truth.
- Rojo 7.7.1 maps the source into a Roblox place file.
- Rokit pins the build tools.
- Feature branches and pull requests keep each update isolated. Pull requests run structure validation, Selene lint, and a Rojo build.
- After review and merge, the separate manual upload workflow can publish to the same existing Start Place. It does not create another Roblox experience or change the Audience setting.
- Previous Roblox place versions remain available in version history.

No Roblox Studio installation on the phone is required for source changes or cloud builds.

## Important place setting

The source code and arena layout support 30 human players. Roblox's actual maximum-player setting is a place configuration, not a Luau runtime setting. It must be set to 30 in the existing place's Creator Dashboard settings before a 30-human-player test. This update does not create a new place or change the experience's privacy.

## Validation

The validation workflow runs repository structure checks, Selene lint, and a Rojo build. A successful run uploads an artifact named `SkyfallArena-place` containing `SkyfallArena.rbxlx`. This is a build artifact, not a Roblox publish.

The cloud smoke tests validate the 15 by 15 grid, one-map design, six-face skybox, separated lobby, golden sphere, blue laser, red target warning, broken-tile persistence, 180-second countdown, and server-side laser cooldown. These are headless checks. They do not simulate Roblox rendering, actual physics, player movement, or real touch input.

## Publishing

The separate manual workflow `Upload Skyfall Arena private test` requires the exact confirmation `UPLOAD_PRIVATE_TEST`. It targets Universe ID `7975091208` and Start Place ID `104752078056182`. Keep the experience private. Roblox publishing and cloud test credentials are stored only as GitHub Actions secrets.

For cloud execution tests, add the separate repository secret `ROBLOX_LUAU_TEST_API_KEY` using a Roblox API key restricted to this universe and the Luau Execution Read and Write permissions. Keep `ROBLOX_API_KEY` for the existing Assets upload only.

## What still needs an in-game playtest

A private in-game test is still required to confirm camera framing on real phone aspect ratios, blue laser rendering and targeting precision, tile collision and falling, NPC navigation across the full floor, spawn spacing at 25 to 30 players, cloud rendering, and overall mobile performance. GitHub validation and cloud smoke tests cannot prove those visual and physics behaviors.
