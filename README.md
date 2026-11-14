# Skyfall Arena

Skyfall Arena is a round-based Roblox survival arena. Each round selects one controller to operate a hovering golden laser sphere. The other human players and three AI characters try to survive as the floor tiles are destroyed. The last runner alive becomes the controller in the next round.

## Current game design

- The existing Roblox experience and Start Place are retained. Updates target the same Place ID.
- The experience is intended to support up to 30 human players. The arena layout is sized for that capacity, with 15 by 15 individually destructible floor tiles.
- The five original map environments rotate between rounds: Suncrest Castle, Cloudspire Kingdom, Golden Dunes Temple, Emerald Grove Sanctuary, and Azure Harbor Fortress. The next map is selected randomly without repeating the immediately previous map.
- Every map uses bright daytime lighting, a consistent square-stud construction style, readable tile seams, and no neon map decoration or segmented circular arena barriers.
- Players and bots gather in a redesigned garden lobby with a medium-sized water feature, clear walkways, benches, and planters.
- The controller uses a hovering gold sphere with five upper and four lower armor plates, a double equatorial band, concentric ruby-lens reticles, and a tightly contained red highlight.
- The controller camera switches between a close angled landscape view and a near-overhead portrait view. Tile selection uses a ray from the active camera, and the original player camera zoom is restored after the controller role ends.
- Human laser requests are limited by the server to one successful strike every three seconds. A warning appears before each laser strike. Destroyed floor tiles stay broken through the results and waiting period. The complete grid is restored only when the next round map is loaded.
- The mobile HUD displays only the timer, total participants, and players remaining in the round.
- The first controller is selected randomly from available humans and bots. Later, the previous round's last survivor becomes the next controller.
- Three scripted AI characters have distinct appearances, hair, movement animations, speeds, reaction delays, and risk preferences. Bots use Roblox PathfindingService, not external AI chat models.
- Eliminated players move to the waiting lobby and Roblox respawns them there.

## Development and release workflow

- Luau source files in this repository are the source of truth.
- Rojo 7.7.1 maps the source into a Roblox place file.
- Rokit pins the build tools.
- Feature branches and pull requests keep each update isolated. Pull requests run structural validation, Selene lint, and a Rojo build.
- After review and merge, the separate manual upload workflow publishes to the same existing Start Place. It does not create another Roblox experience or change the Audience setting.
- Previous Roblox place versions remain available in version history.

No Roblox Studio installation on the phone is required for source changes or cloud builds.

## Important place setting

The source code and arena layout support 30 human players. Roblox's actual maximum-player setting is a place configuration, not a Luau runtime setting. It must be set to 30 in the existing place's Creator Dashboard settings before a 30-human-player test. This update does not create a new place or change the experience's privacy.

## Validation

The validation workflow runs repository structure checks, Selene lint, and a Rojo build. A successful run uploads an artifact named `SkyfallArena-place` containing `SkyfallArena.rbxlx`. This is a build artifact, not a Roblox publish.

The cloud smoke-test workflow validates the uploaded DataModel, the 15 by 15 tile grid, five map configurations, daytime and non-neon map construction, square floor studs, broken-tile persistence, map reset, controller selection, and server-side laser cooldown. These are headless checks. They do not simulate Roblox physics, camera rendering, real player movement, or touch input.

## Publishing

The separate manual workflow `Upload Skyfall Arena private test` requires the exact confirmation `UPLOAD_PRIVATE_TEST`. It targets Universe ID `7975091208` and Start Place ID `104752078056182`. Keep the experience private. Roblox publishing and cloud test credentials are stored only as GitHub Actions secrets.

For cloud execution tests, add the separate repository secret `ROBLOX_LUAU_TEST_API_KEY` using a Roblox API key restricted to this universe and the Luau Execution Read and Write permissions. Keep `ROBLOX_API_KEY` for the existing Assets upload only.

## What still needs an in-game playtest

A private in-game test is still required to confirm camera framing on real phone aspect ratios, laser targeting precision, tile collision and falling, NPC navigation around the larger floor, spawn spacing at 25 to 30 players, water appearance, and overall mobile performance. Cloud smoke tests cannot prove those visual and physics behaviors.
