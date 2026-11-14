# Skyfall Arena

Skyfall Arena is a multiplayer Roblox survival round game.

One player controls the arena's overhead strike system. The other players run across a tiled floor and try to survive as marked tiles are destroyed. Eliminated players become spectators. The controller role changes between rounds.

## Development approach

This repository uses a cloud-first source workflow:

- Luau source files are the editable project.
- Rojo 7.7.1 maps the source files into a Roblox place.
- Rokit pins the command-line tools.
- GitHub Actions checks the source and builds a downloadable RBXLX place artifact.
- No Roblox Studio installation on the phone is required for source changes or cloud builds.

The live Rojo sync workflow requires Roblox Studio and its plugin. This repository instead builds the place file in GitHub Actions.

## Current first-playable foundation

- 9 by 9 arena tile grid.
- Waiting, intermission, active-round, and results phases.
- One controller and a group of runners.
- Server-validated tile targeting.
- A visible warning before each laser strike.
- Broken tiles repair after a short delay.
- Falling or dying runners become spectators.
- Controller camera and tap-to-target controls, with mouse support.

The first pass uses normal Roblox Parts. Advanced editable geometry and custom asset workflows are intentionally deferred.

## Build

Every push to a feature branch and every pull request to main runs the validation workflow. A successful run uploads an artifact named SkyfallArena-place containing SkyfallArena.rbxlx.

Open the repository's Actions tab to view a run and download its artifact.

## Publishing

Publishing is not enabled yet. It requires an existing Roblox place, its Place ID, and a Roblox Open Cloud API key stored as a GitHub Actions secret. Never put that key in source code or in chat. See docs/CLOUD_PUBLISHING.md.

## Project status

This is a first cloud-buildable gameplay foundation, not a finished, balanced, or publicly published Roblox experience. Runtime playtesting and visual polish remain required.
