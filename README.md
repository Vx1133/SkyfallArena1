# Skyfall Arena

Skyfall Arena is a Roblox survival round game. One human player controls the overhead laser system while runners move across a tiled arena and avoid marked floor tiles.

## Current playtest foundation

- 9 by 9 procedural arena with a lobby and elevated controller deck.
- Waiting, intermission, active-round, and results phases.
- Three AI runner NPCs are available, so one human can start a solo test.
- The AI runners use Roblox pathfinding and reactive tile-risk checks to move toward safe floor tiles and escape marked tiles.
- Human players can still join. One human is selected as controller, other humans and the three bots become runners.
- Server-validated laser targeting, warning indicators, tile breaks, and automatic tile repairs.
- Eliminated runners become spectators until the next round.
- Compact, responsive HUD layout and touch controls for phones, plus mouse support for desktop.

The bots are scripted in-game NPC behavior, not external cloud AI services. The three bots have different movement speeds and reaction delays. Their behavior is intended for a first playtest and still needs live balance testing.

## Cloud development

- Luau source files are the editable project.
- Rojo 7.7.1 maps the source files into a Roblox place.
- Rokit pins the command-line tools.
- GitHub Actions validates, lints, and builds the RBXLX place file.
- No Roblox Studio installation on the phone is required for source changes or cloud builds.

## Build and validation

Every push to a feature branch and every pull request to main runs the validation workflow. A successful run uploads an artifact named SkyfallArena-place containing SkyfallArena.rbxlx.

Open the repository's Actions tab to view a run and download its artifact.

## Publishing

The separate private test upload workflow publishes a new version to the configured Roblox Start Place. It does not change the experience audience setting. The Roblox Open Cloud key is stored only as a GitHub Actions secret and must never be committed to source code or shared in chat.

## Project status

This is a playable foundation for testing, not a finished or publicly released experience. The latest build must still be tested in a live Roblox server for NPC movement, phone layout, round flow, and gameplay balance.
