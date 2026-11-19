# Visual Asset QA Pipeline

This pipeline separates technical asset checks from artistic review.

## Supported inputs

The audit scans the configured assets directory recursively for:

- GLB and glTF models
- PNG, JPEG, and WebP images

The current repository does not yet contain production GLB/image assets in that folder. In that case, CI reports `no_assets`. This is an explicit skipped state, not a successful audit of assets that do not exist.

## Automated checks

The Python audit uses pinned versions of Pillow, NumPy, and Trimesh.

For images it checks that the file decodes, reports dimensions and color mode, and flags likely blank or extremely low-contrast renders. These are technical warnings only.

For GLB/glTF it checks that geometry loads, reports meshes, vertices, triangles, extents and watertight mesh counts, and flags non-finite coordinates, degenerate triangles, unusually high triangle counts, large files, or unusually large scene extents.

A malformed image/model or non-finite model geometry fails CI. Performance-related thresholds are warnings because the correct budget depends on the asset's role and the target device.

## Visual review loop

1. Build or edit a scene in the hosted 3D Jutsu workspace. Keep the scene at documented scale and use a delivery camera.
2. Render a PNG from the intended camera, not just a viewport screenshot.
3. Retrieve the render artifact and inspect the actual image for silhouette, framing, depth, contact, readability, materials, lighting and mobile-sized composition.
4. Correct the largest visible defect, render again, and record the reviewed revision.
5. Export GLB only after the scene passes the visual review. Run the repository asset audit before considering it ready for Roblox import.
6. Verify the imported result in Roblox. A valid GLB is not proof that Roblox imported it correctly or that it performs well in a live game.

The interactive 3D preview is useful for the project owner to inspect and rotate the scene. It is not, by itself, pixel evidence available to the assistant. An assistant visual pass requires the rendered image itself to be accessible in the conversation. If artifact retrieval is blocked by network or DNS, report visual review as blocked rather than claiming it passed. A screenshot attached by the project owner can be reviewed directly.

## Limits

This audit does not judge whether an environment is attractive, whether gameplay sightlines are good, or whether an asset is suitable for a particular art direction. It also does not replace Roblox Studio/importer checks, collision tests, mobile performance profiling, or a live playtest.

Source units are reported as supplied by the GLB. Verify scale before Roblox import; do not silently assume that every external asset uses the same units.
