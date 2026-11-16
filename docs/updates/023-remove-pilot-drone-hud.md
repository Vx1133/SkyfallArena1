# Skyfall Arena Update #23: remove Pilot and Drone HUD indicators

## Scope

Remove the two requested on-screen elements from the player HUD:

- The lobby `PILOT: OFF / PILOT: ON` opt-in button.
- The lower-corner `DRONE 0%` Pilot Priority indicator.

## Preserved

- The `PLAY` button and round/player status HUD.
- The laser cooldown display for the active controller.
- The overhead controller camera and the in-world aircraft/drone model.
- Server-side Pilot Priority and explicit opt-in validation logic.
- The separate owner-only Debug Drone control.

## Gameplay note

The standard player-facing pilot opt-in button is no longer available. Players continue to default to `SkyfallPilotOptIn = false`, so the bot remains the normal controller unless another trusted server-side flow explicitly opts a player in. This update does not change controller selection rules.

## Validation

- Repository validation now rejects reintroducing either removed HUD element.
- Existing Update #22 server-side Pilot Opt-In policy tests remain enabled.
- Selene lint and Rojo place build remain part of GitHub Actions validation.
- Roblox Studio visual/mobile playtesting is still required for final in-engine confirmation.
