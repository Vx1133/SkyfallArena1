# Skyfall Arena Visual QA and Toolchain

## What the visual inspector does

`tools/visual_qa.py` reads a GLB or glTF asset, checks basic mesh integrity, and creates a four-view contact sheet (isometric, front, top, side) together with a JSON report.

Run it in the project environment:

```bash
python -m pip install --requirement tools/visual-qa-requirements.txt
python tools/visual_qa.py path/to/asset.glb --output-dir build/visual-qa
```

To verify the rendering pipeline itself without a supplied model:

```bash
python tools/visual_qa.py --self-test --output-dir build/visual-qa
```

The PNG contact sheet is the visual review target. Open and inspect the actual image before accepting an asset. The JSON report is supporting evidence only.

## Scope and limits

The inspector reports mesh count, vertices, triangles, dimensions, bounds, finite coordinates, watertightness, winding consistency, available material names, and whether texture-backed visuals are detected.

Its Matplotlib preview is a geometry and base-color diagnostic. It is **not** a physically based material render and does not reproduce Roblox lighting, SurfaceAppearance, collision behavior, physics, scripts, UI, or mobile performance. Use a Blender/3D Jutsu render for higher-fidelity material and lighting review, then test the asset in Roblox.

A good GLB report does not certify a playable Roblox map.

## Toolchain installed by Rokit in GitHub Actions

The project manifest pins these tools:

- Rojo 7.7.1
- Selene 0.32.0
- Lune 0.11.1
- Luau LSP 1.70.1
- StyLua 2.6.0
- Wally 0.3.2

The first three were already in use. Luau LSP adds a type-analysis pass with a Rojo sourcemap and Roblox type definitions. StyLua provides consistent Luau formatting. Wally is available as a package manager, but no third-party packages should be added unless a concrete feature needs one.

Luau LSP and StyLua are currently run as non-blocking baseline checks while existing diagnostics and formatting differences are measured. After the baseline is reviewed and corrected, their checks can become required gates.

## Roblox Open Cloud

Open Cloud is a hosted API, not a binary package to install. Place publishing and asset upload require a Roblox API key with narrow permissions and a selected experience. Store keys only as GitHub Actions secrets. Never commit or paste API keys into source files, chat, logs, or artifacts.

The existing place-upload workflow remains separate from visual asset QA. A future asset-upload step should be added only after the new experience's Universe ID, Place ID, asset type, and API permissions are confirmed.

## Where the checks run

GitHub Actions installs the pinned tools on its hosted Linux runner. The current ChatGPT execution container already has Python, Trimesh, Matplotlib, NumPy, Pillow, OpenCV, Playwright, and Chromium available, but outbound DNS from that container is restricted. This means large external binaries cannot reliably be installed into that container directly; the repository's CI runner is the supported install environment for the pinned Roblox CLI tools.

The workflow uploads the generated visual contact sheet and JSON report as the `skyfall-visual-qa` artifact for review.
