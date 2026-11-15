# Skyfall Single-Arena Redesign

## Intent
Replace the five rotating environments with one polished daytime arena and a physically separate waiting garden. Preserve the current Roblox experience and Start Place, the three PathfindingService bots, the destructible 15x15 floor, and the refined golden spherical controller drone.

## Goals
- One stable playable map named SKYFALL SUNSPIRE, plus a separate waiting garden with no bridge connecting the two.
- Three named AI bots remain in the experience for solo testing.
- A match begins after at least one human enters the server. On the first round with one human, a bot pilots the drone so the human can play as a runner.
- Each active round lasts at most 180 seconds. The HUD displays a countdown from 03:00.
- The longest-surviving runner becomes the next controller. A sole survivor ends the round early.
- The tile marker is red. The laser travels visibly from the underside of the gold sphere to the marked tile in blue/cyan.
- The controller character is hidden away from the arena. The orb is the only visible controller presence.
- The active-round HUD is a compact safe-area top bar showing TIME, PLAYERS, LEFT, and OUT. It is hidden in waiting/intermission/results.
- Bright afternoon lighting and a distinct six-face Skybox are used instead of relying on the default sky.

## Non-goals
- No new Roblox universe or place.
- No auto-publish, audience-setting changes, monetization changes, or new paid services.
- No third-party map/vehicle/model imports, no external AI service, and no imported executable scripts.
- No repair timer for destroyed tiles. Tiles reset only at the next round.

## Constraints
- Existing Universe ID: 7975091208.
- Existing Start Place ID: 104752078056182.
- Experience stays Private.
- Source remains Luau + Rojo. GitHub validation is structural validation, Selene lint, and Rojo build. It cannot replace a real mobile playtest.
- The existing refined golden sphere and its mobile controller camera are retained from the unmerged PR #7 branch.

## Approaches
1. Import a Creator Store map and skybox model. Rejected because model contents and scripts cannot be inspected adequately in the current phone-first workflow.
2. Build all geometry procedurally and use only six skybox texture IDs documented in Roblox's official lighting sample. Selected because no model package or model scripts enter the DataModel, while the map remains editable in source.
3. Keep the five maps and simply hide four. Rejected because it leaves unnecessary selection and map-decoration branches in the game code.

## Selected design
Keep the existing modular services. Reduce the map catalog to one theme, generate one permanent arena environment, and keep the lobby separately generated. Build the drone from Parts, hide the human or bot controller model while it pilots, and draw a short-lived Beam between the drone's underside attachment and the selected floor tile. RoundService owns round timing, survivor records, and next-controller selection. The client HUD only renders server-authoritative round state.

The first round with one human assigns a bot as controller, leaving the human as a runner. From the next round onward, the prior round's longest-surviving runner is the controller. On timeout, survival time decides the winner; if multiple runners tie at the full duration, one of those tied runners is selected.

The sky uses the six image IDs shown in the official Roblox Creator Hub lighting example. These are texture references only, not imported models or scripts. All map, lobby, orb, laser and UI geometry remains generated from project code.

## Remaining builder decisions
- Keep the arena grid at 15x15 and the current three-second human strike cooldown.
- Use a short 8-second intermission and the existing 6-second results period.
- Use a warm stone, soft teal, garden green, and restrained gold palette. Avoid Neon.
- Hide nameplates above bots to avoid mobile-screen clutter.
- Preserve the 30-human capacity setting already documented; the three bots are additional test participants.
