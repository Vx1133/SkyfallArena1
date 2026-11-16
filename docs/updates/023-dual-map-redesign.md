# Update #23: Dual Map Redesign and Shared Lobby Surface Finish

**Branch:** `feat/023-remove-pilot-drone-hud`  
**Pull request:** [#21](https://github.com/Vx1133/SkyfallArena1/pull/21)  
**Implementation scope:** Replace the two legacy decoration builders with independent natural and orbital map builders. Enforce the lobby's live surface profile across every map BasePart and every playable tile.

## 1. Classic Nature Sanctuary

Implemented in `src/server/Services/ClassicNatureMapBuilder.lua`.

- Dedicated `ClassicNatureSanctuary` folder and `SkyfallMapIdentity = "Classic"`.
- Organic, asymmetrical three-tree composition with trunk cylinders, branch forks, layered ball-shaped canopies, and hanging vine Beams.
- Three irregular floating-islet groups with separate stone tops, shaded undersides, and moss shelves.
- A curved, segmented exposed-root arch and three exposed root clusters.
- Natural forest/bark/stone palette from `WorldDesignProfile.Classic`.
- Geometry is positioned outside the 15 × 15 destructible grid to preserve tile readability and controller sightlines.
- Geometry count is measured at build time and has a regression ceiling of 55 BaseParts.

## 2. Cyberpunk Orbital Sky Station

Implemented in `src/server/Services/CyberpunkMapBuilder.lua`.

- Dedicated `CyberpunkOrbitalStation` folder and `SkyfallMapIdentity = "Cyberpunk"`.
- Broken, offset, seven-vertex orbital frame with intentional gaps and elongated engineered frame members.
- Two asymmetric gate-spire assemblies with separate bases, vertical cores, crowns, and diagonal braces.
- Three offset angular decks.
- Suspended energy bridge and circuit paths implemented as Beams and Attachments, not Neon-material BaseParts.
- Restrained cyan PointLights with a bounded count/range.
- Ice-white, blue-white, steel-blue, navy, and cyan palette from `WorldDesignProfile.Cyberpunk`.
- Geometry is positioned outside the playable tile grid. Geometry count is measured at build time and has a regression ceiling of 32 BaseParts.

The Classic builder contains no Cyberpunk landmark family. The Cyberpunk builder contains no Classic tree, canopy, root, vine, or floating-islet family. Both builders carry different geometry-signature attributes. The playable 225-tile grid remains intentionally shared.

## 3. Lobby surface profile enforced globally

Implemented in `FloorAppearanceService.lua` and `MapDecorationFactory.lua`.

The authoritative profile is captured from the live `Lobby.WaitingPlatform`. It includes:

- Material
- MaterialVariant
- Reflectance
- TopSurface
- BottomSurface
- Existing Texture/Decal child settings, if such children exist on the source part (texture ID, face, transparency, and tiling values where applicable)

The current generated WaitingPlatform does not add a separate Texture or Decal asset. Its finish is based on the Roblox material plus native top/bottom surface settings. No texture ID or external asset was invented.

The profile is applied to:
- All 225 destructible tiles on both maps.
- Every BasePart created by both map builders.
- Every element-transition layer.

Map-specific `Color` is assigned after the shared material/surface profile and is not copied from the lobby. The two tile palettes therefore remain independent.

Neon-material BaseParts were removed from the new map builders. Cyan energy accents use Beam and light instances, leaving every actual structural BasePart eligible for the same lobby finish.

After every map selection, `FloorAppearanceService.Audit` inspects all generated map BaseParts and all 225 tile BaseParts. A mismatch raises an error naming the instance and property instead of silently continuing.

## 4. Deterministic map lifecycle

- `ArenaService` now delegates map decoration to `ClassicNatureMapBuilder` or `CyberpunkMapBuilder`.
- `SetMap` captures the lobby profile before applying either design.
- Generated map decoration is cleared and rebuilt deterministically at every map selection. This also applies any future change to the lobby surface profile.
- The existing 15 × 15 grid, tile dimensions, map rotation, runner/gameplay systems, aircraft control, HUD, and global lighting work are preserved.
- The obsolete four-corner `CyberpunkPillarService` has been removed.

## 5. Regression coverage

Updated `tests/cloud_smoke_tests.luau`:
- Scoped tree/bench/water cleanup assertions to `arena.lobbyFolder`, so Classic's new trees are not incorrectly rejected.
- Replaced the old Classic support/perimeter expectations with natural landmark checks.
- Replaced the old Cyberpunk four-pillar/Neon-strip checks with orbital frame, spire, energy bridge, angular deck, and circuit-beam checks.
- Added disjoint feature-family and geometry-signature checks.
- Added spatial checks for separated, irregular Classic tree landmarks and elongated Cyberpunk frame members.
- Audits lobby material properties across every BasePart in each map and every tile.
- Verifies all map decoration is anchored, non-collidable, non-touchable, and non-queryable.
- Checks map switching Classic → Cyberpunk → Classic → Cyberpunk, no cross-map geometry leakage, stable part counts, 225 tile retention, and map-specific palette restoration.

Updated `tests/lune/update_023_world_design.luau`:
- Checks compact lobby dimensions/spawn rings.
- Checks independent green-led natural Classic palette.
- Checks ice-white/blue-white Cyberpunk palette and separate architectural tones.
- Checks the map palettes are not aliases of each other.

Updated `tools/validate_project.py`:
- Requires both dedicated map builders and the shared geometry factory.
- Checks both map landmark families and forbids cross-map geometry names.
- Rejects Neon-material BaseParts in both builders and the factory.
- Requires the post-build map and tile surface audits.
- Removes the obsolete four-pillar source requirement and old frame-specific map assertions.

## 6. CI results

Latest successful PR validation run:
[GitHub Actions run #581](https://github.com/Vx1133/SkyfallArena1/actions/runs/43936283555)

All steps passed:
- Install pinned Roblox tools
- Verify tool versions
- Lune policy tests
- Python structural validation
- Selene Luau lint
- Rojo place build
- Upload build artifact

The Cloud smoke test file is included and linted. The standard validation workflow does not execute the Cloud smoke runtime suite.

## 7. Visual/runtime validation limitations

Roblox Studio and a live Roblox runtime were not available in this execution environment. Therefore:
- No Studio screenshots were captured.
- No live round was executed on either redesigned map.
- No device-level visual/performance inspection was performed.

The geometry and material profiles are implemented in Luau and pass the repository validation/lint/build pipeline, but final in-Studio appearance, camera occlusion, and runtime performance remain unverified. Do not label the redesign Studio-grade visually verified until those checks are performed.

## 8. Codex status

No live Codex session was connected to this workspace. The implementation was applied directly to the existing PR branch using the repository tools. The Codex handoff remains as a review specification, but no Codex agent execution or approval is claimed.

**PR #21 remains open and unmerged. The Roblox experience has not been uploaded or published.**
