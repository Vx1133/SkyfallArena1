# Codex Engineering Handoff: Update #23 Map Redesign and Studio-Grade QA

**Repository:** `Vx1133/SkyfallArena1`  
**Target branch:** `feat/023-remove-pilot-drone-hud`  
**Pull request:** [#21](https://github.com/Vx1133/SkyfallArena1/pull/21)  
**Scope:** Redesign both playable maps, unify the lobby surface finish across both maps, prove their visual/structural distinction, and complete pre-merge validation.

## 0. Execution contract

You are being asked to implement this task, not merely review it or write another plan.

1. Work on the existing Update #23 branch and preserve all already-committed work in PR #21. Do not reset, force-push, squash away, or overwrite the aircraft-control, HUD, lobby-resize, world-palette, or lighting changes.
2. Read the current source, tests, project mapping, and the latest PR diff before editing. The source code is authoritative if this handoff and the current code disagree.
3. Make the actual Luau/map-builder/test changes, commit them to the target branch, and let the PR validation workflow run.
4. Do not merge the PR or publish/upload the Roblox place. The task is to prepare a reviewable, passing PR.
5. Never claim Studio-grade visual verification from a Rojo build or static analysis alone. Use Roblox Studio/actual Roblox runtime for the final visual pass when available. If unavailable, report that limitation explicitly and provide the best available static evidence.
6. Do not invent external asset IDs, texture URLs, Marketplace models, or paid dependencies. Prefer deliberate procedural geometry built from supported Roblox instances and the existing pinned toolchain.
7. Keep the experience mobile-first and within the existing gameplay and streaming budgets. Avoid a high-part-count environment that looks detailed in a still image but performs poorly in live play.

## 1. Critical non-negotiable: map identity separation

The two maps may share the **15 × 15 destructible gameplay grid** (225 tiles), map rotation, common spawn/round systems, element transitions, and the lobby-sourced material finish. Those are shared gameplay contracts, not shared visual design.

Everything that makes the world read as a place must be independently designed:
- Distinct silhouette and macro layout.
- Distinct structural language and repeated forms.
- Distinct landmark placement, vertical rhythm, and negative space.
- Distinct decoration families and palette.
- No copied perimeter frame, corner-pillar layout, or generic supports between maps.

Do not solve this by changing only colors, materials, names, or lighting. A top-down or oblique screenshot of each map must make the two identities immediately distinguishable.

### Map A: Classic, nature-led floating sanctuary

**Identity:** an ancient, living sky-grove / floating natural sanctuary. It should feel organic, calm, spacious, and richly layered, not like a recolored tech arena.

Required visual language:
- Irregular floating stone shelves and broken natural landforms around and below the playfield.
- Uneven, non-mirrored clusters of mature trees with readable trunks, branch silhouettes, layered canopies, and a restrained amount of leaf variation.
- Large exposed roots, curved root arches, hanging vines, smaller mossy rock forms, and a few natural vertical landmarks.
- Use depth through foreground/midground/background layering and controlled height changes. Keep the gameplay floor readable from the controller camera.
- Use a coherent natural palette: deep forest greens, fresh leaf greens, warm bark, muted stone, and restrained warm sunlight accents. Avoid neon-heavy cyberpunk styling.
- The natural composition must be asymmetrical and organic. Do not place four identical towers at the arena corners. Do not use a rectangular metal-like perimeter frame.

Recommended procedural composition:
- A broken, curved natural stone/root arc on one side, not a closed square border.
- One dominant ancient canopy cluster, two smaller secondary tree/island groups, and one distant floating rock/branch landmark. Vary their height, density, and distance.
- Root structures can visually frame the play space from outside the 15 × 15 grid. Avoid putting large opaque geometry in front of the central tiles or the controller's overhead view.
- Any water-like visual must be represented without violating the lobby material requirement. Prefer non-BasePart effects such as Beams/particles where appropriate, or use the shared finish on any actual BasePart.

### Map B: New map, futuristic architectural identity

**Identity:** a premium white/blue cybernetic sky-station / orbital foundry. It must read as engineered architecture, not as a nature map with blue colors.

Required visual language:
- A clearly angular, engineered silhouette, with offset polygonal geometry (for example, a broken hexagonal/oblique orbital frame) rather than the Classic map's organic arcs.
- Layered structural decks, angled gantries, precise struts, and a small number of tall asymmetric spires or gate structures.
- Suspended energy paths and controlled cyan light accents. Prefer Beam, Attachment, PointLight, or SurfaceLight visuals for glow.
- Keep ice-white / blue-white surfaces, steel blue structure, deep navy contrast, and restrained cyan accents.
- Do not add trees, leaf canopies, exposed roots, vines, moss islands, natural arches, or organic rock clusters.
- Do not reuse the current four identical corner-pillar pattern as the main architectural identity. Replace or substantially recompose it into a distinct orbital/gantry layout.

Recommended procedural composition:
- A large broken polygonal ring around the grid with at least one intentional gap or offset.
- Two offset architectural gate/spire assemblies on a diagonal or opposing sides, with one elevated suspended ring or energy bridge.
- Secondary angular deck/wing forms at different heights. Ensure the silhouette differs visibly from the natural sanctuary in top-down and oblique views.
- Keep all structure outside the active tile grid unless it is deliberately overhead and proven not to obscure gameplay.

## 2. Unified lobby material finish across BOTH maps

The lobby's `WaitingPlatform` is the single authoritative source for the shared surface finish. Capture it once per map build/map selection and apply it consistently to both maps.

At minimum, every map floor tile and every generated visible structural BasePart must match the lobby profile for:
- `Material`
- `MaterialVariant`
- `Reflectance`
- `TopSurface`
- `BottomSurface`

Also inspect the actual lobby platform for any explicit supported texture children/assets (Texture, Decal, or other applicable surface object). If one exists and can be applied correctly to a target surface, include its texture identity and tiling/face settings in the shared profile. If no explicit texture asset exists, do not invent one or call a Roblox material a texture asset.

**Color is deliberately not part of the shared finish.** Preserve independent per-map colors. Never copy the lobby's green `Color` into either map's palette merely because the Material profile is captured.

Implementation requirements:
1. Refactor/extend `FloorAppearanceService` into the authoritative capture/apply path. Keep surface finish application separate from color assignment.
2. Apply the lobby profile to tiles in both map selections, not only Cyberpunk.
3. Apply the same profile to every generated BasePart in both map decoration folders, including irregular tree/rock parts, roots, arches, decks, rails, braces, pillars, trim, transition layers, and accent strips.
4. Remove the current hard-coded `Enum.Material.Neon` BasePart exceptions from the Cyberpunk structural finish policy. Use Beam/PointLight/SurfaceLight/ParticleEmitter effects for emissive appearance. All actual BaseParts, including accent geometry, must use the lobby surface profile.
5. Do not allow a map builder to quietly bypass the shared finish by creating a Part with a different Material or different Top/BottomSurface.
6. Apply map palette colors after the shared material profile so material copying never overwrites map identity.
7. Run a post-build surface audit over every BasePart descendant of the generated map and every tile. Fail loudly with the instance path/name and the mismatched property. Do not silently skip failed applications.

If the lobby surface source changes later, both maps should automatically follow it without separately hard-coded material values.

## 3. Recommended code organization

Keep `ArenaService` responsible for map lifecycle, tile reset, map identity, and delegating builders. Avoid growing one enormous conditional builder.

Suggested modules (names may be improved, but separation must remain explicit):
- `ClassicNatureMapBuilder.lua`
- `CyberpunkMapBuilder.lua`
- `FloorAppearanceService.lua` (shared lobby profile, application, and audit)
- A shared map palette/design-token module for both maps, if that reduces duplicated constants without merging their visual identities.

Every builder should:
- Return or populate one dedicated generated folder with a stable identity/name.
- Create only anchored static decoration unless a deliberate animated object is needed.
- Set generated decoration `CanCollide = false`, `CanTouch = false`, and `CanQuery = false`.
- Apply the lobby profile through the shared helper.
- Set map-specific color only after the shared finish is applied.
- Avoid modifying the destructible tile dimensions, positions, grid size, collision, or gameplay state.
- Clean up deterministically when switching maps. Repeated map selection must not duplicate parts, lights, attachments, or effects.

Do not introduce any Studio-only dependency or paid asset. Ensure all files are included by the current Rojo project mapping.

## 4. Performance and visual-quality constraints

Target Roblox mobile devices first, with up to 30 human slots and the existing 10 bots:
- Keep procedural decorative BasePart counts measured and bounded. Set an explicit per-map budget after counting the actual generated output; do not guess or use an obsolete test threshold.
- Prefer a few well-composed silhouettes over hundreds of tiny decorative parts.
- Use shadows selectively. Small leaves, tiny inlays, particles, and thin accent geometry should not all cast shadows.
- Avoid large numbers of dynamic lights. Use a small number of local lights with bounded range/brightness.
- Avoid transparent overlapping layers that create overdraw or flicker.
- Do not let decoration cover tile warnings, lasers, runners, the controller's line of sight, or the HUD.
- Keep decorations non-collidable and non-queryable so they cannot affect laser raycasts, targeting, touch handling, or player movement.
- Use stable names and `SkyfallGenerated` attributes for cleanup and QA.
- Do not create hidden full-size collision floors under the grid or any decoration that can catch eliminated players.

## 5. Required regression and uniqueness tests

Update `tests/cloud_smoke_tests.luau` and `tools/validate_project.py`. Add pure Lune tests for any data-only palette/design profiles.

### Both maps, shared invariants
- Exactly 225 destructible tiles remain.
- Tile positions, dimensions, grid attributes, collision, and gameplay map rotation remain unchanged.
- Both maps use the live lobby profile for every tile and every generated visible BasePart.
- Compare all five properties (Material, MaterialVariant, Reflectance, TopSurface, BottomSurface), not just one center tile.
- Verify map colors remain separate from the lobby Color.
- Verify every decoration part is anchored and non-collidable/non-touchable/non-queryable.
- Verify map switching in the sequence Classic → Cyberpunk → Classic → Cyberpunk does not accumulate geometry, lights, or effects.
- Verify reset restores each map's own palette and the lobby finish.
- Verify the 30 human spawn positions and 10 bot lobby positions remain valid.
- Verify all lighting/effect instances are cleaned and restored correctly on map changes.

### Classic-only uniqueness
Require a set of clearly named natural landmarks to exist, such as:
- `ClassicNatureRootArch_*`
- `ClassicNatureTreeTrunk_*`
- `ClassicNatureCanopy_*`
- `ClassicNatureFloatingIslet_*`
- `ClassicNatureVine_*`

Use the actual chosen naming scheme consistently. Verify natural landmark placement has intentional variation and the map contains no Cyberpunk-only architecture names or geometry.

### Cyberpunk-only uniqueness
Require a different set of clearly named engineered landmarks, such as:
- `CyberpunkOrbitalFrame_*`
- `CyberpunkGateSpire_*`
- `CyberpunkEnergyBridge_*`
- `CyberpunkAngularDeck_*`
- `CyberpunkCircuitBeam_*`

Use the actual chosen naming scheme consistently. Verify the map contains no natural tree/root/canopy/vine/organic-islet geometry.

### Cross-map non-similarity tests
Do not rely on names alone. Check:
- The required feature families are disjoint.
- The main geometry layout signatures differ (for example, organic irregular island/arc placement versus polygonal/angled orbital layout).
- Neither map contains the other map's defining landmark set.
- There is no shared corner-pillar/perimeter-rail template reused by both maps.
- The only intentional shared geometry is the gameplay grid and common gameplay-owned visual systems.

### Update legacy tests correctly
The current cloud test includes a blanket scan that rejects any name containing `tree` and scans the entire environment folder. That was suitable only for the old empty lobby. Narrow lobby-cleanliness assertions to `arena.lobbyFolder`; do not reject the new Classic map's nature geometry. Keep prohibitions on unwanted lobby trees/benches/water scoped to the lobby only.
The existing Classic test expects the old `ClassicArenaSupport`, `ClassicArenaOuterTrim`, straight perimeter beams, and corner posts. Replace those expectations with the new natural landmark checks.
The existing Cyberpunk test expects the current support/perimeter/corner-pylon layout and a small hard-coded part-count threshold. Replace those assertions with the new Cyberpunk design-signature checks and a measured mobile budget.
The current static validator also bans the old Classic tree naming/helper patterns. Update it to validate the new dedicated Classic builder and keep any lobby-only restrictions scoped to lobby code.
Do not simply delete tests to make CI pass. Replace obsolete assertions with stronger assertions for the requested new designs.

## 6. Visual QA evidence required before claiming ready

When Roblox Studio/runtime is available:
1. Capture each map from the same top-down camera angle and from at least two oblique angles.
2. Inspect the natural Classic map in daylight and check that canopy/rocks do not occlude the 225 tile floor.
3. Inspect the Cyberpunk map at high and low graphics quality. Confirm the polygonal/gantry silhouette reads clearly and cyan effects do not bloom out the white surfaces.
4. Inspect representative BaseParts from every geometry family (tree trunk, canopy, rock, root, Cyberpunk deck, spire, gantry, trim, accent) and compare their finish to the lobby WaitingPlatform.
5. Run one real round on each map, including controller camera, laser targeting, tile warnings/destruction, elimination, round cleanup, and map rotation.
6. Test mobile performance and ensure no excessive part/light/transparent-layer cost.

Attach screenshots or a concise evidence log to the PR. If Studio/runtime cannot be used, list the unverified visual/runtime checks plainly. Do not label the work "Studio-grade verified" based only on static CI.

## 7. Completion checklist

- [x] Classic has a recognizably organic nature sanctuary design and unique layout.
- [x] Cyberpunk has a recognizably engineered orbital/sky-station design and unique layout.
- [x] The two maps share only the required gameplay grid/common systems, not their defining architecture.
- [x] Every map BasePart and all 225 tiles use the lobby material profile on BOTH maps.
- [x] Map palette colors remain independent from lobby color.
- [x] Emissive accents do not violate the shared BasePart material policy.
- [x] Old tests are replaced with map-specific and cross-map uniqueness checks.
- [x] Lune tests pass.
- [x] Python structural validation passes.
- [x] Selene lint passes.
- [x] Rojo build succeeds and the artifact is uploaded.
- [x] Studio/runtime validation limitations are explicitly documented.
- [x] PR #21 remains open and unmerged.

**Definition of done:** a reviewable PR with two genuinely different maps, lobby-matched surface finishes throughout both, passing automated checks, and honest visual QA evidence.


## Implementation completion record (2026-11-16)

The actual map-builder implementation has been committed to the target branch.

- `src/server/Services/ClassicNatureMapBuilder.lua`: organic tree groups, layered canopies, vines, floating islets, exposed roots, and a curved root arch.
- `src/server/Services/CyberpunkMapBuilder.lua`: broken angular orbital frame, two asymmetrical gate spires, angular decks, support struts, and Beam-based energy/circuit paths.
- `src/server/Services/MapDecorationFactory.lua`: one shared low-level part/beam/light factory that applies the live lobby surface profile to every generated BasePart.
- `FloorAppearanceService.lua`: captures Material, MaterialVariant, Reflectance, TopSurface, BottomSurface, and any Texture/Decal children; applies and audits them on map parts and tiles.
- `ArenaService.lua`: both map builders are independent delegates; every map selection rebuilds and then audits the decoration and all 225 tiles.
- The obsolete `CyberpunkPillarService.lua` was removed.
- Legacy tests that prohibited trees globally, expected the old Classic perimeter rails, or expected Cyberpunk Neon strips/corner pillars were replaced with map-identity, cross-map separation, surface-profile, and deterministic-switch tests.

Latest successful PR validation at the time of this record:
https://github.com/Vx1133/SkyfallArena1/actions/runs/43935755946

That run passed Lune, Python structural validation, Selene, Rojo build, and artifact upload. Cloud smoke tests were updated and linted, but are not executed by the default validation workflow.

**Visual verification remains incomplete:** Roblox Studio/live runtime was not accessible in this execution environment, so no screenshots, real rounds, or device-performance evidence were produced. The automated build must not be described as visual Studio approval.

**Codex execution remains unclaimed:** no live Codex session was connected. The implementation was made directly in this branch; this file remains the exact review specification for any subsequent Codex review.
