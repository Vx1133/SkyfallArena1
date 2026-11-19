#!/usr/bin/env python3
"""Offline visual and structural QA for GLB/GLTF assets used by Skyfall Arena.

Creates a four-view geometry contact sheet and a JSON report. This is an asset
inspection aid, not a substitute for a Roblox client playtest.
"""
from __future__ import annotations

import argparse
import json
import math
import sys
from pathlib import Path
from typing import Any

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
import trimesh
from mpl_toolkits.mplot3d.art3d import Poly3DCollection

VIEWS = ((28, -55, "Isometric"), (0, -90, "Front"), (90, -90, "Top"), (0, 0, "Side"))


def _load_scene(path: Path) -> trimesh.Scene:
    loaded = trimesh.load(path, force="scene", process=False)
    if isinstance(loaded, trimesh.Trimesh):
        scene = trimesh.Scene()
        scene.add_geometry(loaded, node_name=path.stem, geom_name=path.stem)
        return scene
    if not isinstance(loaded, trimesh.Scene):
        raise ValueError(f"Unsupported GLTF object returned by trimesh: {type(loaded).__name__}")
    return loaded


def _as_world_mesh(scene: trimesh.Scene) -> trimesh.Trimesh:
    meshes = scene.dump(concatenate=False)
    meshes = [m for m in meshes if isinstance(m, trimesh.Trimesh) and len(m.vertices) and len(m.faces)]
    if not meshes:
        raise ValueError("The file contains no renderable triangle meshes")
    return trimesh.util.concatenate(meshes)


def _mesh_color(mesh: trimesh.Trimesh, count: int) -> np.ndarray:
    try:
        colors = np.asarray(mesh.visual.face_colors)
        if colors.ndim == 2 and len(colors) == len(mesh.faces):
            return colors[:count] / 255.0
    except Exception:
        pass
    return np.tile(np.array([[0.55, 0.65, 0.78, 1.0]]), (count, 1))


def _axis_equal(ax: Any, bounds: np.ndarray) -> None:
    center = bounds.mean(axis=0)
    extent = np.maximum(bounds[1] - bounds[0], 0.001)
    radius = float(extent.max()) * 0.55
    ax.set_xlim(center[0] - radius, center[0] + radius)
    ax.set_ylim(center[1] - radius, center[1] + radius)
    ax.set_zlim(center[2] - radius, center[2] + radius)
    ax.set_box_aspect((1, 1, 1))
    ax.set_axis_off()


def render_contact_sheet(mesh: trimesh.Trimesh, destination: Path, max_faces: int) -> None:
    face_count = len(mesh.faces)
    step = max(1, math.ceil(face_count / max_faces))
    face_indices = np.arange(0, face_count, step, dtype=np.int64)
    sampled = mesh.triangles[face_indices]
    colors = _mesh_color(mesh, face_count)[face_indices]
    bounds = np.asarray(mesh.bounds, dtype=float)

    fig = plt.figure(figsize=(14, 10), dpi=120, constrained_layout=True)
    for i, (elev, azim, label) in enumerate(VIEWS, start=1):
        ax = fig.add_subplot(2, 2, i, projection="3d")
        collection = Poly3DCollection(sampled, facecolors=colors, edgecolors="none", linewidths=0)
        ax.add_collection3d(collection)
        ax.view_init(elev=elev, azim=azim)
        _axis_equal(ax, bounds)
        ax.set_title(label, fontsize=12, pad=5)
    fig.suptitle("Skyfall Arena Asset Review", fontsize=15)
    destination.parent.mkdir(parents=True, exist_ok=True)
    fig.savefig(destination, bbox_inches="tight", facecolor="white")
    plt.close(fig)


def inspect_asset(path: Path, output_dir: Path, max_faces: int) -> dict[str, Any]:
    scene = _load_scene(path)
    mesh = _as_world_mesh(scene)
    vertices = np.asarray(mesh.vertices, dtype=float)
    bounds = np.asarray(mesh.bounds, dtype=float)
    dimensions = np.asarray(mesh.extents, dtype=float)
    finite_vertices = bool(np.isfinite(vertices).all())
    positive_dimensions = bool(np.all(dimensions > 1e-6))

    geometry_names = list(scene.geometry.keys())
    materials: set[str] = set()
    textured_visuals = 0
    for geometry in scene.geometry.values():
        visual = getattr(geometry, "visual", None)
        material = getattr(visual, "material", None)
        if material is not None:
            materials.add(str(getattr(material, "name", type(material).__name__)))
        if visual is not None and getattr(visual, "kind", None) == "texture":
            textured_visuals += 1

    preview_path = output_dir / f"{path.stem}-views.png"
    render_contact_sheet(mesh, preview_path, max_faces=max_faces)

    return {
        "source": str(path),
        "valid": finite_vertices and positive_dimensions and len(mesh.faces) > 0,
        "mesh_count": len(geometry_names),
        "mesh_names": geometry_names,
        "vertex_count": int(len(mesh.vertices)),
        "triangle_count": int(len(mesh.faces)),
        "finite_vertices": finite_vertices,
        "positive_dimensions": positive_dimensions,
        "bounds_min": [round(float(x), 5) for x in bounds[0]],
        "bounds_max": [round(float(x), 5) for x in bounds[1]],
        "dimensions": [round(float(x), 5) for x in dimensions],
        "watertight": bool(mesh.is_watertight),
        "winding_consistent": bool(mesh.is_winding_consistent),
        "material_names": sorted(materials),
        "textured_mesh_count": textured_visuals,
        "preview": str(preview_path),
        "preview_faces_sampled": min(len(mesh.faces), max_faces),
        "notes": [
            "Dimensions use the GLTF scene's native coordinate units, usually meters.",
            "The contact sheet previews geometry and base colors; it is not a full PBR or Roblox lighting render.",
            "This report does not validate Roblox collisions, physics, scripts, or mobile performance.",
        ],
    }


def _self_test(output_dir: Path, max_faces: int) -> dict[str, Any]:
    scene = trimesh.Scene()
    box = trimesh.creation.box(extents=(4.0, 3.0, 1.5))
    box.visual.face_colors = [95, 150, 90, 255]
    scene.add_geometry(box, node_name="QA_Test_Box", geom_name="QA_Test_Box")
    sphere = trimesh.creation.icosphere(subdivisions=2, radius=0.7)
    sphere.apply_translation((0.0, 0.0, 1.1))
    sphere.visual.face_colors = [190, 165, 95, 255]
    scene.add_geometry(sphere, node_name="QA_Test_Detail", geom_name="QA_Test_Detail")
    fixture = output_dir / "visual-qa-self-test.glb"
    output_dir.mkdir(parents=True, exist_ok=True)
    fixture.write_bytes(scene.export(file_type="glb"))
    return inspect_asset(fixture, output_dir, max_faces)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("asset", nargs="?", type=Path, help="Input .glb or .gltf file")
    parser.add_argument("--output-dir", type=Path, default=Path("build/visual-qa"))
    parser.add_argument("--max-faces", type=int, default=30000)
    parser.add_argument("--self-test", action="store_true", help="Render a generated fixture to verify the pipeline")
    args = parser.parse_args()
    if args.max_faces < 100:
        parser.error("--max-faces must be at least 100")
    try:
        if args.self_test:
            report = _self_test(args.output_dir, args.max_faces)
        elif args.asset is not None and args.asset.is_file():
            report = inspect_asset(args.asset, args.output_dir, args.max_faces)
        else:
            parser.error("Provide an existing .glb/.gltf asset or use --self-test")
        report_path = args.output_dir / "visual-qa-report.json"
        report_path.parent.mkdir(parents=True, exist_ok=True)
        report_path.write_text(json.dumps(report, indent=2), encoding="utf-8")
        print(json.dumps(report, indent=2))
        return 0 if report["valid"] else 2
    except Exception as exc:
        print(f"visual_qa failed: {type(exc).__name__}: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
