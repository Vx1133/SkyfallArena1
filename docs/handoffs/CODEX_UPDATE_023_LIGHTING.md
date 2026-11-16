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
3. Confirm property names and enum values against current Roblox API documentation. Do not invent an AmbientOcclusionEffect class or undocumented AO property.
4. Keep `LightingStyle.Realistic` as the engine AO/contact-shading path only if current API/runtime support is confirmed. Roblox may lower lighting quality on mobile devices; verify both high and low graphics settings.
5. Confirm Bloom threshold/intensity do not wash out the white Cyberpunk surfaces or cyan Neon strips.
6. Confirm the Classic map is no longer too dark after ambient fill is raised, while the Cyberpunk map is no longer excessively bright.
7. Do not force `Lighting.Technology = Future`; do not add high-frequency client loops, many new lights, or expensive post effects.
8. Preserve all existing geometry, gameplay, tile logic, HUD behavior, and server authority.

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
