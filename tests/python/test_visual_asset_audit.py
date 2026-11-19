import tempfile
import unittest
from pathlib import Path

import numpy as np
import trimesh
from PIL import Image

from tools.visual_asset_audit import audit_image, audit_model


class VisualAssetAuditTests(unittest.TestCase):
    def test_valid_png_is_decoded_and_measured(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "preview.png"
            pixels = np.zeros((320, 480, 3), dtype=np.uint8)
            pixels[:, :, 0] = np.linspace(20, 220, 480, dtype=np.uint8)
            pixels[:, :, 1] = 90
            pixels[:, :, 2] = 150
            Image.fromarray(pixels, mode="RGB").save(path)

            report = audit_image(path)
            self.assertEqual(report["status"], "passed")
            self.assertEqual(report["width"], 480)
            self.assertEqual(report["height"], 320)

    def test_valid_glb_reports_mesh_metrics(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "box.glb"
            trimesh.creation.box().export(path)

            report = audit_model(path)
            self.assertEqual(report["status"], "passed")
            self.assertEqual(report["mesh_count"], 1)
            self.assertGreater(report["triangle_count"], 0)
            self.assertGreater(report["vertex_count"], 0)

    def test_invalid_image_is_reported_as_error(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "broken.png"
            path.write_bytes(b"not an image")

            report = audit_image(path)
            self.assertEqual(report["status"], "error")
            self.assertTrue(report["errors"])


if __name__ == "__main__":
    unittest.main()
