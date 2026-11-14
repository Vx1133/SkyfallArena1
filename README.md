# Skyfall Arena

Skyfall Arena is a Roblox last-survivor game. Every human player and three AI opponents start in the waiting lobby. When a round begins, everyone enters the arena while an automatic laser randomly targets floor tiles. The last contestant standing wins.

## Current foundation

- Original experience and Start Place are kept. Updates publish new versions to the same Place ID.
- A 9 by 9 arena with an expanded sci-fi lobby, spawn pads, illuminated borders, corner pylons, and an overhead laser rig.
- Every player and three named AI runners are contestants. There is no player-controlled laser role.
- The automatic laser randomly targets safe tiles, often favors tiles near active contestants to keep pressure on them, warns before striking, and breaks the tile.
- The laser becomes faster and launches multiple strikes during overtime.
- The round ends when one contestant remains. The winner receives a session win, and player best survival time is tracked in the server leaderboard.
- After results, all players and bots return to the lobby and the next round begins automatically.
- The mobile HUD is compact and displays the round, survivor count, elapsed time, and overtime state.

The AI opponents use scripted Roblox NPC logic and PathfindingService, not an external cloud AI model. They have different movement speeds, reaction delays, and risk preferences. Their behavior needs live playtesting and balance tuning.

## Development and release workflow

- Luau source files in this repository are the source of truth.
- Rojo 7.7.1 maps the source into a Roblox place file.
- Rokit pins the build tools.
- Feature branches are used for individual updates. Pull requests run structural validation, Selene lint, and a Rojo build.
- After review and merge, the upload workflow publishes a new version to the same existing Start Place. It does not create another Roblox experience or change the Audience setting.
- Previous Roblox place versions remain available in version history.

No Roblox Studio installation on the phone is required for source changes or cloud builds.

## Validation

Every push to a feature branch and every pull request to main runs the validation workflow. A successful run uploads an artifact named SkyfallArena-place containing SkyfallArena.rbxlx. This is a build artifact, not a Roblox publish.

## Publishing

Use the separate manual workflow Upload Skyfall Arena private test to publish the merged main branch to the configured Start Place. Keep the experience private. The Roblox Open Cloud key is stored only as a GitHub Actions secret.

## Status

This is the next playable foundation. Cloud checks can confirm code structure, lint, and place-file generation, but they cannot prove that NPC movement, live physics, mobile layout, or game balance behave correctly in a Roblox server. Those still require a private in-game playtest.