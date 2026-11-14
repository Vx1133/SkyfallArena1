# Skyfall Arena cloud foundation implementation plan

Date: 2026-11-14

## Task 1: Establish the source project

- Add the Rojo project mapping.
- Pin Rojo and Selene in the Rokit manifest.
- Configure Selene for Roblox globals.
- Add ignore rules for local caches and generated place files.
- Add a Python standard-library validation script for project structure.

Verification: parse JSON and TOML, check required source paths, and run the structural validator in GitHub Actions.

## Task 2: Build the arena service

- Generate a 9 by 9 tile floor from shared configuration.
- Add a lobby pad and controller deck.
- Track tile state and strike tokens so delayed work from an old round cannot affect a reset tile.
- Add a short-lived laser column effect.

Verification: Selene lint and Rojo place build. Runtime collision and visual checks remain part of later Roblox playtesting.

## Task 3: Build server-owned round logic

- Implement waiting, intermission, active, and results phases.
- Select one controller and register all remaining players as runners.
- Move eliminated players to the spectator role.
- End rounds on controller loss, runner elimination, or timer expiry.
- Broadcast round state to clients.

Verification: Selene lint and Rojo place build. Multiplayer edge cases require runtime playtesting.

## Task 4: Build controller input and HUD

- Display current phase, timer, role, and surviving runner count.
- Use a fixed overhead camera while a player is the active controller.
- Raycast from touch or mouse input to the arena tile folder.
- Send only tile coordinates to the server.

Verification: Selene lint and Rojo place build. Touch, camera, and input behavior require runtime playtesting.

## Task 5: Add continuous validation

- Run the structural validator.
- Lint all Luau source with Selene.
- Build the RBXLX place with Rojo.
- Upload the built place as a GitHub Actions artifact.
- Keep the workflow read-only and separate from publishing.

Verification: inspect the actual GitHub Actions run and its uploaded artifact before marking the cloud build complete.

## Task 6: Review and handoff

- Inspect the diff and repository tree.
- Open a draft pull request from the feature branch to main.
- Report any CI failures accurately and fix them before calling the build verified.
- Document the remaining Place ID and Open Cloud key requirements for a future publishing workflow.
