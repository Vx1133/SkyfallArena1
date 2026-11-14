# Skyfall Arena

Skyfall Arena is a round-based Roblox arena game. Each round selects one controller to pilot the overhead laser aircraft. The other human players and three AI characters compete as runners. The last runner alive becomes the controller in the next round.

## Current game foundation

- The original Roblox experience and Start Place are retained. Releases update the same Place ID.
- All players and bots wait in a dedicated lobby before each round.
- The first controller is selected randomly from the available humans and bots. Later, the previous round's last survivor becomes the next controller.
- Human controllers pilot the aircraft from the raised deck and tap/click tiles to aim the laser. If a bot is selected, it targets tiles automatically.
- A warning appears before each laser strike. Destroyed floor tiles stay broken through the results and waiting period. The complete grid is restored only when the next round's map is loaded.
- The game ends when one runner remains, then moves players back to the lobby and repeats.
- Two maps rotate between rounds: Nexus Skygrid and Ember Reactor. They use the same balanced arena footprint but have different themes, lighting, structures, and colors.
- The overhead aircraft has a shaped fuselage, cockpit, wings, engines, animated rotors, and a visible laser emitter.
- Three AI characters have distinct appearances, hair, nameplates, movement animations, speeds, reaction delays, and risk preferences.
- The HUD is transparent, positioned near the top, and sized for mobile screens.
- Eliminated players are moved to the waiting area and Roblox respawns them there.

Bots use scripted Roblox NPC logic and PathfindingService. They are not external AI chat models.

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

## Test status

Cloud checks validate the project structure, Luau lint, and Rojo place build. They do not start a live Roblox server, so controller selection, NPC appearance and movement, touch aiming, respawn timing, laser physics, and the two-map rotation still require a private in-game playtest. Wins and best survival time are currently tracked for the current server session; persistent cross-session saving is a separate future update.
