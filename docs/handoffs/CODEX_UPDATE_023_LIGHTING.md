# Codex handoff: Skyfall Arena Update #23 lighting uniformity

Repository: https://github.com/Vx1133/SkyfallArena1
Branch: `feat/023-remove-pilot-drone-hud`
Pull request: https://github.com/Vx1133/SkyfallArena1/pull/21
Target Universe: `7975091208`
Start Place: `104752078056182`

## Mission

Perform an independent code and visual-quality review of the shared lighting profile that removes harsh exposure changes between all maps. Do not merge or publish. Preserve the already implemented removal of the PILOT and DRONE HUD labels in this same Update #23 pull request.

## Verified source issue

The previous ArenaService map table supplied separate Lighting values. Classic used black Ambient and OutdoorAmbient, Brightness 2, Exposure 0, and FogEnd 100000. Cyberpunk used blue Ambient/OutdoorAmbient, Brightness 2.8, Exposure 0.08, FogEnd 2200, plus Atmosphere, SunRays, Bloom Intensity 0.3, and ColorCorrection. The _setLighting(theme) method applied different global values whenever map selection changed.

## Implementation now on this branch

- `src/shared/LightingProfile.lua`: pure data table containing the one project-wide global profile.
- `src/server/Services/LightingProfileService.lua`: the only service allowed to write Lighting properties and manage the shared Sky/Atmosphere/Bloom/SunRays/ColorCorrection.
- `ArenaService.lua`: both maps call the same profile; map-level lighting values were removed.
- `tests/lune/update_023_lighting_profile.luau`: checks exposure bounds, ambient channel ordering, moderate Bloom/Atmosphere, daylight, and mobile quality preference.
- `tools/validate_project.py`: checks that Lighting writes are centralized and that no map-specific Lighting profile is left behind.
- `.github/workflows/validate.yml`: runs the new Lune test along with existing validation.

## Review requirements

1. Confirm every current map and the lobby call the same global Lighting profile.
2. Confirm no other source file writes global Lighting properties or creates competing map-specific post-processing effects.
3. Confirm the managed profile removes duplicate/legacy environment post-effects before applying its one known effect stack.
4. Confirm property names and enum values against current Roblox API documentation. Do not invent an AmbientOcclusionEffect class or undocumented AO property.
5. Keep `LightingStyle.Realistic` as the engine AO/contact-shading path only if current API/runtime support is confirmed. Roblox may lower lighting quality on mobile devices; verify both high and low graphics settings.
6. Confirm Bloom threshold/intensity do not wash out the white Cyberpunk surfaces or cyan Neon strips.
7. Confirm the Classic map is no longer too dark after ambient fill is raised, while the Cyberpunk map is no longer excessively bright.
8. Do not force `Lighting.Technology = Future`; do not add high-frequency client loops, many new lights, or expensive post effects.
9. Preserve all existing geometry, gameplay, tile logic, HUD behavior, and server authority.

## Required checks

- `lune run tests/lune/update_023_lighting_profile.luau`
- `lune run tests/lune/update_019_policy.luau`
- `lune run tests/lune/update_022_policy.luau`
- `python tools/validate_project.py`
- `selene src tests`
- `rojo sourcemap default.project.json --output build/sourcemap.json`
- `rojo build default.project.json --output build/SkyfallArena.rbxlx`
- `git diff --check`

Then open the built place in Roblox Studio and compare a full round/map rotation at high and low graphics quality, including mobile viewport. Record screenshots or a short capture of both maps under the same time/exposure conditions. Do not claim visual matching from static tests alone.

## Completion report

Report exact commit, files reviewed, any code corrections, CI results, runtime/Studio checks actually performed, and remaining limitations. Never claim zero bugs or a completed Codex review unless the Codex session actually performed and returned the review.


## Additional Update #23 review: round-start aircraft-control state

### Verified root cause
`RoundService:_clearReadyPlayers()` preserved an enabled `SkyfallDebugDroneEnabled` flag by re-inserting the owner into the next ready list. `RoundService:_chooseController()` then applied that owner-only debug override before normal bot fallback. If left on, that manual test flag caused repeated owner control on later rounds.

### Changes on this branch
- The normal HUD now exposes one compact `✈` manual opt-in icon. The old `PILOT: OFF/ON` and `DRONE 0%` text indicators remain absent.
- Manual opt-in can be toggled on/off during Waiting and during Intermission for a player already marked Ready.
- `PilotOptInPolicy.ResolveCandidates` selects manually opted-in ready humans first, otherwise valid bots. There is no solo-human fallback.
- Owner Debug Drone remains separate and manual, but is now a one-round override. End-of-round cleanup disables the flag and clears debug auto-ready/pointer state.
- The server initializes and owns `SkyfallAircraftControlActive`. The character is unhidden/unanchored and the flag cleared for normal character control. Only the explicit server-side controller transition sets it true.
- The client camera requires Active phase + Controller role + `SkyfallAircraftControlActive == true`. A stale role by itself cannot lock the camera to the aircraft.
- `_runRound` resolves a valid controller before switching to Active or changing human roles. If no valid candidate exists, it fails closed to Waiting.

### Required review
1. Confirm a single ready human and ten valid bots selects a bot by default.
2. Confirm the `✈` icon is the only normal-player path to human aircraft control and can be switched off before round start.
3. Confirm a player without explicit opt-in remains Runner with normal character movement, visible body, and default camera.
4. Confirm the owner Debug Drone override only affects the explicitly requested round and resets at cleanup.
5. Confirm nine non-controller bots are still spawned as independent Runners when one bot pilots.
6. Confirm the active camera flag cannot remain true after cleanup, respawn, or demotion.
7. Preserve map/lighting changes already in this PR and do not merge or publish.

### Additional checks
- `lune run tests/lune/update_023_control_state.luau`
- Existing Lune policy tests and full project CI.
- Roblox Studio runtime checks must include one real player plus all ten bots, manual icon on/off, respawn, round-end cleanup, and a second round without touching the aircraft icon.

No Codex session is connected to this workspace, so this brief is committed for a real Codex session to review. Do not claim that a live Codex review occurred.

- The normal aircraft icon is intentionally gated by `SkyfallReady`: the player must press PLAY first, then can opt in or cancel during Waiting/Intermission. New PLAY requests and end-of-round cleanup clear stale opt-in for all humans.


## Additional Update #23 review: compact lobby, materials, and palette

### Required design review
1. Check the 120 × 120 waiting platform against 30 human spawn points at radius 42 and 10 bot points at radius 52. Confirm every spawn remains inside the platform and the Bubble Blaster station stays reachable.
2. Confirm the source of the green bleed: the prior `ArenaService:SetMap(2)` copied `WaitingPlatform.Color` into `theme.tileColor`, then applied that color to every Cyberpunk floor tile.
3. Confirm the correction keeps the lobby's Material, MaterialVariant, Reflectance, TopSurface, and BottomSurface but keeps color under the active map palette.
4. Audit every non-Neon BasePart under `ActiveMap/GeneratedDecor`: floor tiles, support, under-deck, perimeter trim, cross-braces, pillar foundations/cores/collars/inlays, and element-transition layers must use the captured lobby material/surface profile.
5. Verify Neon perimeter channels and pillar spines remain Neon by design. They are emissive light accents, not structural surface finishes.
6. Confirm Cyberpunk tiles use cool ice-white/blue-white rather than the lobby green. Confirm Earth transitions use champagne stone rather than green, and that structure, roof, silver, navy, and cyan use the central world palette.
7. Check all repeated map switches and `ResetTiles()` restore the same palette and material profile without accumulating geometry.

### Additional checks
- `lune run tests/lune/update_023_world_design.luau`
- Existing lighting and gameplay Lune tests
- Python structural validation, Selene, and Rojo build
- In Studio, inspect top, bottom, side, and angled views of representative tile, trim, brace, pillar, and element-transition parts.
- Run the lobby with 30 human spawn positions plus 10 bot positions, and verify the Bubble Blaster prompt remains reachable.
- Capture screenshots of the lobby and Cyberpunk map on high and low graphics quality. Static tests cannot establish final visual appearance.

Do not claim an in-Studio visual inspection unless Studio was actually launched and the new map was viewed.
