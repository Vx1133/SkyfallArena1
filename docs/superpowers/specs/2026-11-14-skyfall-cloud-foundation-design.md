# Skyfall Arena cloud foundation design

Date: 2026-11-14

## Intent

Create a real Roblox project source tree for Skyfall Arena that can be edited and built from GitHub without requiring Roblox Studio on the user's Android phone.

The game concept carried forward from the project brief is a round-based survival arena. One selected player operates a stationary overhead strike system and marks floor tiles. The other players move across the arena, avoid marked tiles, and try to remain alive. Eliminated players watch as spectators. The controller role rotates between rounds and is not an automatic winner.

## Goals

- Establish a reproducible Roblox source project with Rojo 7.7.1 and Rokit.
- Build an RBXLX place file in GitHub Actions.
- Keep gameplay decisions on the server and validate all strike requests.
- Support phone touch input and desktop mouse input.
- Keep the first arena procedural and built from ordinary Parts.
- Work on a feature branch and open a draft pull request for review.

## Non-goals for this first foundation

- Publishing to a live Roblox experience.
- Monetization, VIP perks, persistent player data, matchmaking across servers, or analytics.
- Final art direction, external 3D asset imports, sound design, and advanced effects.
- Claiming live runtime testing before a Roblox playtest is available.

## Constraints

- No Roblox Studio installation on the Android phone.
- No paid build service or paid API.
- No credentials committed to Git.
- The current repository initially contained only README.md.
- Roblox place publishing requires an existing Place ID and a scoped Open Cloud API key. These are not currently available in the repository context.

## Approaches considered

1. Roblox Studio on the phone. Rejected because Roblox Studio is a desktop application, not an Android editor.
2. Rojo source plus GitHub Actions. Selected. It keeps Luau source readable in Git, pins tool versions, and generates a place artifact on a hosted runner.
3. A third-party hosted Roblox editor. Deferred because it adds another service, permissions, and possible cost without improving this repository's source-of-truth model.

## Initial gameplay defaults

These are implementation defaults for the first playable pass, not final balancing decisions:

- Minimum players: 2.
- Arena: 9 by 9 tiles.
- Intermission: 15 seconds.
- Round length: 100 seconds.
- Results display: 7 seconds.
- Strike warning: 1.2 seconds.
- Controller strike cooldown: 2.25 seconds.
- Tile repair delay: 8 seconds.
- One controller is selected at the start of each round. Other players are runners.
- The controller wins if all runners are eliminated. Runners win if time expires or the controller leaves or is eliminated.

## Architecture

- Shared configuration: ReplicatedStorage.Shared.
- Server bootstrap and services: ServerScriptService.SkyfallServer.
- Client HUD and input: StarterPlayerScripts.SkyfallClient.
- ArenaService creates the tile grid, lobby, controller deck, and laser visuals.
- RoundService owns roles, round phases, player elimination, and winner decisions.
- StrikeService validates the controller's requested tile, warns, strikes, and schedules tile repair.
- The client can request a target, but cannot decide whether a target is valid or whether a tile breaks.

## Safety and publishing boundary

The validation workflow only reads repository content and uploads a build artifact. It does not publish to Roblox. A later, separate manual publishing workflow may use Roblox's Assets API after the user supplies a Place ID and configures the API key directly in GitHub Actions secrets.

## Acceptance criteria

- The source tree maps to valid Roblox services through the Rojo project file.
- GitHub Actions can install the pinned tools, lint Luau, validate repository structure, and build an RBXLX artifact.
- The server owns round state and validates controller strike requests.
- The client supports tap and mouse targeting while the controller role is active.
- No API key, password, or other secret is included in the repository.
