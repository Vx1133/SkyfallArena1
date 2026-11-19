# AGENTS.md

## Project Mission
Build and maintain a reliable, mobile-conscious Roblox experience. Preserve existing gameplay and project architecture unless a task explicitly authorizes changing them. Prefer small, testable changes over broad rewrites.

## Role 1: System Architect and Luau Gameplay Engineer

- Put `--!strict` at the top of every new or substantially modified Luau source file.
- Add explicit types to public functions, parameters, return values, state tables, and important locals. Avoid `any` unless an external API forces it, and document why.
- Use `task.wait`, `task.spawn`, and `task.defer`; do not introduce deprecated `wait`, `spawn`, or `delay` calls.
- Separate server services, client controllers, shared modules, and configuration. Keep modules focused and avoid circular dependencies.
- Treat the server as authoritative. The client may request an action, but the server validates identity, permissions, state, range, cooldowns, ownership, and all numeric/string payload bounds before applying it.
- Never trust client-supplied damage, rewards, currency, inventory, alive-player counts, round outcomes, or DataStore values.
- Validate every RemoteEvent and RemoteFunction input. Rate-limit requests and reject malformed, stale, oversized, or out-of-state requests.
- Keep DataStore operations on the server. Use `pcall`, bounded retries with backoff, and explicit handling for throttling and failed writes. Do not overwrite valid saved data with defaults after a failed read.
- Disconnect events and clean up Instances, tasks, and tweens when their owning round, character, UI, or controller ends. Reuse an existing Trove/Janitor implementation if the repository has one; do not add a second cleanup framework unnecessarily.
- Avoid unbounded loops, repeated full-descendant scans, and expensive work on every frame. Prefer event-driven updates and cached references.

## Role 2: Procedural Builder and Spatial Engineering

- Use a 4- or 8-stud grid for major structural placement unless gameplay dimensions require a documented exception.
- Build reusable modules for floors, walls, pillars, barriers, platforms, and decorative elements. Keep dimensions and offsets explicit and deterministic.
- Use `CFrame`, `CFrame.Angles`, `Model:PivotTo`, and local-space transforms for assembly and rotation. Avoid piecemeal position edits when a model pivot is more reliable.
- Make procedural generation deterministic when practical by using a seeded random generator. Keep generation parameters separate from generated instances.
- Set collision, anchoring, query, touch, and network-ownership properties intentionally. Do not create unnecessary physics simulations for static geometry.
- Use Roblox materials and `SurfaceAppearance`/PBR assets only where supported and useful. Provide sensible material/color fallbacks.
- Keep collision geometry simpler than visual geometry when this improves mobile performance.
- For spatial/image-processing helper scripts, document coordinate units, axis orientation, scale conversion, and supported input formats. Do not silently mix pixels, studs, meters, and normalized coordinates.

## Role 3: Cinematic, Lighting, and Visual Direction

- Create a consistent visual baseline using Lighting, Atmosphere, BloomEffect, and ColorCorrectionEffect where they serve the art direction.
- Use `Enum.Technology.Future` only when the target Roblox runtime supports it and device profiling justifies it. Do not assume a particular Lighting technology is available on every device.
- Tune Atmosphere density, offset, color, and decay for depth without obscuring gameplay or UI.
- Keep Bloom subtle. Tune ColorCorrection for controlled contrast and saturation rather than crushing shadow detail or clipping highlights.
- Use DepthOfFieldEffect selectively for menus or cinematic/cutscene moments. Keep it disabled or very restrained during precision gameplay so players can read the arena and hazards clearly.
- Use TweenService for camera and lighting transitions, with cancellation and cleanup when a round or cutscene ends.
- Support low-end mobile devices with restrained post-processing, limited particles, efficient shadows, and scalable visual quality. Test readability at phone-sized resolutions.
- Do not use a visual effect merely because it is available. Every effect must have a clear visual purpose and a tested performance cost.

## Role 4: Visual Asset QA

- Run `python -m pip install -r requirements-visual-audit.txt` before using the visual asset audit script in a fresh Python environment.
- Run `python -m unittest discover -s tests/python -v` and `python tools/visual_asset_audit.py --root assets --allow-empty --json-output build/visual_asset_audit.json`.
- Treat this script as technical validation only. It does not judge composition, polish, gameplay readability, or aesthetic quality.
- For a 3D scene, inspect the scene structure, render from its delivery camera, retrieve the PNG artifact, and inspect the actual image. Do not count an interactive preview widget or a successful Blender operation as visual proof available to the assistant.
- If the PNG cannot be retrieved or attached because of a network/DNS limitation, mark visual review as blocked. Never claim a visual pass without viewing the image itself.
- Keep the 3D source scene separate from the Roblox production map until scale, object count, collision, materials, mobile cost, and import behavior are reviewed.

## Roblox Project Structure

Follow the repository's established structure. If no structure exists, use a clear separation similar to:

```text
src/
  client/
  server/
  shared/
  assets/
```

Do not move or rename existing project files as part of an unrelated task.

## Validation and Build Gate

Run the checks supported by the current environment and report which ones actually ran:

1. `rojo sourcemap default.project.json --output build/sourcemap.json`
2. `luau-lsp analyze --platform roblox --definitions @roblox="$ROBLOX_LUAU_DEFINITIONS" --sourcemap build/sourcemap.json <Luau files>`
3. `selene <Luau files>`
4. `rojo build default.project.json --output build/place.rbxlx`
5. Run relevant pure-Luau utility tests with Lune. Lune is not a substitute for Roblox Studio runtime testing.
6. Run the Python visual asset audit and its unit tests where Python dependencies are available.
7. Use Darklua only with an explicit output path. Never minify or overwrite the original source tree in place.

If Roblox Studio or the Rojo Studio plugin is unavailable, state that live synchronization and in-Studio behavior were not tested. A successful Rojo build does not prove that a live Roblox server/client session works.

## Change Management

- Inspect the existing implementation before editing. Preserve unrelated behavior and public interfaces.
- Do not claim that code is error-free or fully tested without evidence from the checks above and any required Studio playtests.
- Keep secrets, access tokens, cookies, and local authentication files out of source control, logs, and generated artifacts.
- Do not publish, deploy, merge, or push changes unless explicitly requested.
- Summarize changed files, tests run, tests not run, and remaining risks after each engineering task.
