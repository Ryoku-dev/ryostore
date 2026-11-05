import hashlib
import json
from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[1]
PRODUCT = ROOT / "barstyles/iris"


class ShimaCatalogueTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        registry = json.loads((ROOT / "barstyles/registry.json").read_text())
        cls.matches = [item for item in registry["barstyles"] if item["id"] == "iris"]
        cls.entry = cls.matches[0] if cls.matches else None

    def test_single_existing_store_identity(self):
        self.assertEqual(len(self.matches), 1)
        self.assertEqual(self.entry["name"], "Shima")
        self.assertEqual(self.entry["path"], "barstyles/iris")
        self.assertEqual(self.entry["version"], "2.33.0")

    def test_original_and_ryoku_contributors_are_credited(self):
        self.assertEqual(self.entry["author"], "snowarch & aethctl")
        self.assertEqual(self.entry["upstream"], "https://github.com/snowarch/iNiR")

    def test_storefront_preview_and_manifest_integrity(self):
        manifest_path = PRODUCT / self.entry["manifest"]
        manifest_bytes = manifest_path.read_bytes()
        self.assertEqual(
            hashlib.sha256(manifest_bytes).hexdigest(),
            self.entry["manifestSha256"],
        )
        manifest = json.loads(manifest_bytes)
        self.assertEqual(manifest["category"], "barstyles")
        self.assertEqual(manifest["id"], "iris")
        self.assertEqual(manifest["version"], self.entry["version"])
        preview = self.entry["preview"]
        self.assertTrue((PRODUCT / preview).is_file())
        self.assertIn(preview, [row["source"] for row in manifest["files"]])

        for row in manifest["files"]:
            source = PRODUCT / row["source"]
            self.assertEqual(source.stat().st_size, row["size"])
            self.assertEqual(
                hashlib.sha256(source.read_bytes()).hexdigest(),
                row["sha256"],
            )

    def test_metadata_cannot_be_installed_as_a_fake_shell(self):
        self.assertTrue(self.entry["downloadPaused"])
        self.assertEqual(self.entry["windowManager"], "niri")
        self.assertIn("native Shima", self.entry["downloadPauseReason"])
        manifest = json.loads((PRODUCT / self.entry["manifest"]).read_text())
        self.assertGreater(len(manifest["files"]), 0)
        self.assertTrue(all(row["install"] is False for row in manifest["files"]))


if __name__ == "__main__":
    unittest.main()
