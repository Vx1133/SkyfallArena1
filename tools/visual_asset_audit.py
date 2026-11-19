#!/usr/bin/env python3
"""Technical QA for image and glTF assets; this does not judge artistic quality."""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any

import numpy as np
import trimesh
from PIL import Image, ImageStat, UnidentifiedImageError

IMAGE_EXTENSIONS = {".png", ".jpg", ".jpeg", ".webp"}
MODEL_EXTENSIONS = {".glb", ".gltf"}


def audit_image(path: Path) -> dict[str, Any]:
    errors: list[str] = []
    warnings: list[str] = []
    try:
        with Image.open(path) as probe:
            image_format = probe.format
            probe.verify()
        with Image.open(path) as source:
            width, height = source.size
            mode = source.mode
            has_alpha = "A" in source.getbands() or "transparency" in source.info
            rgb = source.convert("RGB")
            stats = ImageStat.Stat(rgb)
            mean_brightness = round(sum(stats.mean) / 3, 2)
            mean_channel_stddev = round(sum(stats.stddev) / 3, 2)

        if width < 256 or height < 256:
            warnings.append("Image is smaller than 256 pixels on at least one edge.")
        if mean_brightness < 4 or mean_brightness > 251:
            warnings.append("Image is almost entirely black or white; check render exposure.")
        if mean_channel_stddev < 2:
            warnings.append("Image has very low channel variation; check for a blank render.")

        return {
            "path": str(path),
            "kind": "image",
            "status": "warning" if warnings else "passed",
            "format": image_format,
            "width": width,
            "height": height,
            "mode": mode,
            "has_alpha": has_alpha,
            "file_bytes": path.stat().st_size,
            "mean_brightness_0_255": mean_brightness,
            "mean_channel_stddev": mean_channel_stddev,
            "errors": errors,
            "warnings": warnings,
        }
    except (OSError, UnidentifiedImageError, ValueError) as exc:
        errors.append(f"Image could not be decoded: {exc}")
        return {
            "path": str(path),
            "kind": "image",
            "status": "error",
            "errors": errors,
            "warnings": warnings,
        }


def _as_scene(loaded: Any) -> trimesh.Scene:
    if isinstance(loaded, trimesh.Scene):
        return loaded
    if isinstance(loaded, trimesh.Trimesh):
        scene = trimesh.Scene()
        scene.add_geometry(loaded, geom_name="mesh_0")
        return scene
    raise TypeError(f"Unsupported loaded geometry type: {type(loaded).__name__}")


def audit_model(path: Path) -> dict[str, Any]:
    errors: list[str] = []
    warnings: list[str] = []
    try:
        loaded = trimesh.load(path, force="scene", process=False)
        scene = _as_scene(loaded)
        mesh_items = [
            (name, geom)
            for name, geom in scene.geometry.items()
            if isinstance(geom, trimesh.Trimesh)
        ]
        meshes = [geom for _, geom in mesh_items]
        if not meshes:
            errors.append("Model contains no triangle mesh geometry.")

        vertex_count = 0
        triangle_count = 0
        degenerate_triangles = 0
        non_finite_vertices = 0
        watertight_meshes = 0
        mesh_summaries: list[dict[str, Any]] = []

        for mesh_name, mesh in mesh_items:
            vertices = np.asarray(mesh.vertices, dtype=np.float64)
            faces = np.asarray(mesh.faces, dtype=np.int64)
            vertex_count += int(len(vertices))
            triangle_count += int(len(faces))

            finite_mask = np.isfinite(vertices)
            non_finite_vertices += (
                int((~finite_mask).any(axis=1).sum()) if len(vertices) else 0
            )
            if len(faces):
                areas = np.asarray(mesh.area_faces, dtype=np.float64)
                degenerate_triangles += int(
                    (~np.isfinite(areas) | (areas <= 1e-12)).sum()
                )
            if mesh.is_watertight:
                watertight_meshes += 1

            bounds = mesh.bounds
            extents = (
                [round(float(v), 4) for v in (bounds[1] - bounds[0])]
                if bounds is not None else None
            )
            mesh_summaries.append({
                "name": str(mesh_name),
                "vertices": int(len(vertices)),
                "triangles": int(len(faces)),
                "extents_source_units": extents,
                "watertight": bool(mesh.is_watertight),
            })

        if non_finite_vertices:
            errors.append(
                f"Model has {non_finite_vertices} vertices with non-finite coordinates."
            )
        if triangle_count == 0:
            errors.append("Model has zero triangles.")
        if triangle_count and degenerate_triangles / triangle_count > 0.02:
            warnings.append(
                f"{degenerate_triangles} triangles "
                f"({degenerate_triangles / triangle_count:.1%}) are degenerate "
                "or have non-finite area."
            )
        if triangle_count > 250_000:
            warnings.append(
                "Model exceeds 250,000 triangles; review mobile performance and LOD needs."
            )
        if path.stat().st_size > 20 * 1024 * 1024:
            warnings.append("Model file exceeds 20 MiB; review texture and mesh budgets.")

        bounds = scene.bounds
        scene_extents = (
            [round(float(v), 4) for v in (bounds[1] - bounds[0])]
            if bounds is not None else None
        )
        if scene_extents and max(scene_extents) > 500:
            warnings.append(
                "Scene extent exceeds 500 source units; verify scale before Roblox import."
            )

        status = "error" if errors else "warning" if warnings else "passed"
        return {
            "path": str(path),
            "kind": "model",
            "status": status,
            "format": path.suffix.lower(),
            "file_bytes": path.stat().st_size,
            "mesh_count": len(meshes),
            "vertex_count": vertex_count,
            "triangle_count": triangle_count,
            "degenerate_triangle_count": degenerate_triangles,
            "watertight_mesh_count": watertight_meshes,
            "scene_extents_source_units": scene_extents,
            "meshes": mesh_summaries,
            "errors": errors,
            "warnings": warnings,
        }
    except Exception as exc:
        errors.append(
            f"Model could not be loaded or inspected: {type(exc).__name__}: {exc}"
        )
        return {
            "path": str(path),
            "kind": "model",
            "status": "error",
            "errors": errors,
            "warnings": warnings,
        }


def audit_directory(root: Path, allow_empty: bool) -> dict[str, Any]:
    if not root.exists():
        if allow_empty:
            return {
                "schema_version": 1,
                "root": str(root),
                "status": "no_assets",
                "asset_count": 0,
                "passed": 0,
                "warnings": 0,
                "errors": 0,
                "assets": [],
                "note": (
                    "Asset folder does not exist yet; visual asset checks are ready "
                    "for future files."
                ),
            }
        raise FileNotFoundError(f"Asset directory does not exist: {root}")

    supported_extensions = IMAGE_EXTENSIONS | MODEL_EXTENSIONS
    candidates = sorted(
        p for p in root.rglob("*")
        if p.is_file() and p.suffix.lower() in supported_extensions
    )
    if not candidates and not allow_empty:
        raise FileNotFoundError(
            f"No supported image or glTF assets found under: {root}"
        )

    results = [
        audit_image(p) if p.suffix.lower() in IMAGE_EXTENSIONS else audit_model(p)
        for p in candidates
    ]
    error_count = sum(item["status"] == "error" for item in results)
    warning_count = sum(item["status"] == "warning" for item in results)
    passed_count = sum(item["status"] == "passed" for item in results)
    status = "error" if error_count else "warning" if warning_count else "passed"
    if not candidates:
        status = "no_assets"

    return {
        "schema_version": 1,
        "root": str(root),
        "status": status,
        "asset_count": len(results),
        "passed": passed_count,
        "warnings": warning_count,
        "errors": error_count,
        "assets": results,
    }


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Inspect PNG/JPEG/WebP images and GLB/glTF geometry."
    )
    parser.add_argument(
        "--root", type=Path, default=Path("assets"),
        help="Directory to scan recursively."
    )
    parser.add_argument(
        "--allow-empty", action="store_true",
        help="Return no_assets instead of failing when no assets exist."
    )
    parser.add_argument(
        "--json-output", type=Path,
        help="Optional path to write the full JSON report."
    )
    args = parser.parse_args()

    try:
        report = audit_directory(args.root, args.allow_empty)
    except Exception as exc:
        print(f"Visual asset audit failed: {exc}", file=sys.stderr)
        return 2

    print(
        f"Visual asset audit: {report['status']} | assets={report['asset_count']} | "
        f"passed={report['passed']} | warnings={report['warnings']} | "
        f"errors={report['errors']}"
    )
    for item in report["assets"]:
        print(f"- {item['status'].upper()}: {item['path']}")
        for warning in item.get("warnings", []):
            print(f"  WARNING: {warning}")
        for error in item.get("errors", []):
            print(f"  ERROR: {error}")

    if args.json_output:
        args.json_output.parent.mkdir(parents=True, exist_ok=True)
        args.json_output.write_text(
            json.dumps(report, indent=2), encoding="utf-8"
        )

    return 1 if report["errors"] else 0


if __name__ == "__main__":
    raise SystemExit(main())
