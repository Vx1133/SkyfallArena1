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

## Verified image handoff

A working handoff was verified on 2026-11-19 using the existing project `Enchanted Forest Island Map - Reference Reconstruction` at revision 3:

- A read-only Blender query confirmed 345 scene objects: 325 meshes, 16 curves, 2 cameras and 2 lights.
- A fresh 522x416 PNG was rendered from `CAM_Source_View` and published as a query artifact.
- The exact artifact bytes were retrieved and delivered to an image-capable review input.
- The image was visually inspected. The visual review is therefore not inferred from the interactive widget or from metadata alone.
- The read-only query and render did not commit a scene edit; project revision remained 3.

For future reviews, use this sequence:

1. Read the current project revision and active-operation state.
2. Render a small PNG from the delivery camera and publish it as an artifact.
3. Resolve the artifact using its returned artifact ID and operation ID (or exact committed revision).
4. Transfer the actual PNG/JPEG bytes through an image-capable review path. A URL, artifact ID, or interactive 3D widget alone is not visual evidence.
5. Verify the received image dimensions and inspect the image itself. Keep the source render unchanged; create a compressed review copy only when the image handoff has a size limit.
6. Record the project ID, revision, camera, dimensions and actual visual findings. If the image itself was not received, mark visual review as blocked.

The visual model review and the technical asset audit are separate gates. Passing one does not imply passing the other.

## Limits

This audit does not judge whether an environment is attractive, whether gameplay sightlines are good, or whether an asset is suitable for a particular art direction. It also does not replace Roblox Studio/importer checks, collision tests, mobile performance profiling, or a live playtest.
