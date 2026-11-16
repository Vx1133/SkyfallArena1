# Codex handoff: Skyfall Arena Update #22 visual review

Repository: `Vx1133/SkyfallArena1`
Branch: `feat/022-elements-floor-pilot-opt-in`
Pull request: https://github.com/Vx1133/SkyfallArena1/pull/20
Target experience: Universe `7975091208`, Start Place `104752078056182`

## Mission

Review and improve the existing Update #22 implementation for a distinctive, polished, mobile-friendly arena. Continue patching the current map. Do not rebuild the map, replace the experience, or change the playable arena dimensions.

## Already implemented in this branch

- Daytime lighting profile for the Cyberpunk arena, using a default Roblox Sky, midday ClockTime, zero stars, no moon, pale-blue Atmosphere, restrained SunRays, and restrained Bloom.
- Lobby floor appearance capture and exact transfer of Material, MaterialVariant, Reflectance, Color, TopSurface, and BottomSurface to the new destructible floor tiles.
- Surface-only lobby material profile application to solid Cyberpunk architecture. White/blue/silver color accents remain intentional; luminous cyan accents remain Neon.
- Dedicated `CyberpunkPillarService` for four integrated corner pillars. Their bases overlap perimeter rails, foot bridges extend to rail lines, mid collars intersect the existing cross-braces, and crowns meet their columns.
- Dedicated existing-element visual blending for Fire, Water, Earth, and Air. It only wraps existing element models; it does not fabricate replacement element models.
- Explicit human pilot opt-in and automated policy tests from the earlier Update #22 scope.

## Mandatory constraints

1. Preserve all existing hand-authored map and lobby content. Do not clear or recreate the Workspace or the full arena.
2. Preserve the 15x15 tile grid, tile names, positions, sizes, gameplay remotes, round lifecycle, player roles, and existing game systems.
3. Do not move, resize, or replace the four pillar structures without a precise measured reason and an explicit implementation note.
4. Keep the Roblox server authoritative. Never trust client-supplied pilot state.
5. Keep mobile performance in mind. Avoid high-frequency loops, large particle counts, many lights, or expensive post-processing.
6. Do not add external assets with unknown permissions or fabricated asset IDs.
7. Do not force `Lighting.Technology = Future` without device profiling and runtime support evidence.
8. Do not merge the PR or publish to Roblox. Prepare a reviewed PR and report the exact commit and validation status.

## Review tasks

- Inspect `ArenaService.lua`, `FloorAppearanceService.lua`, `CyberpunkPillarService.lua`, `ElementIntegrationService.lua`, and the Python structural validator.
- Check that the default Sky instance properties are valid for the Roblox runtime and that the map is visibly daytime with stars and moon disabled.
- Check that the Lobby `WaitingPlatform` profile is captured after it exists, and that the same Material, MaterialVariant, and Reflectance reach all solid map surfaces, including all four faces/sides of perimeter structures and pillar surfaces. Neon is the only deliberate material exception.
- Inspect all four pillar positions against the arena perimeter rails and cross-braces. Confirm continuous contact, no visible gaps, no penetration into runner paths, and consistent symmetry.
- Confirm pillar crown/core contact, light-source count, and mobile readability. Reduce visual complexity if needed, but keep the unified design.
- Review the existing element model discovery contract. If real element models are not present in the repository, report that asset dependency instead of creating substitutes.
- Add regression checks for any real defects found.

## Required validation

Run and report each result separately:

1. `python tools/validate_project.py`
2. `lune run tests/lune/update_019_policy.luau`
3. `lune run tests/lune/update_022_policy.luau`
4. `selene src tests`
5. `rojo sourcemap default.project.json --output build/sourcemap.json`
6. `rojo build default.project.json --output build/SkyfallArena.rbxlx`
7. `git diff --check`

Then inspect the generated build artifact. If Roblox Studio is unavailable, say clearly that live visual, physics, and mobile runtime testing was not performed. Static checks do not prove in-engine behavior.

## Completion report

Summarize changed files, design decisions, checks passed/failed/not run, remaining asset requirements, and the final PR URL. Never claim zero defects or complete runtime validation without evidence.
