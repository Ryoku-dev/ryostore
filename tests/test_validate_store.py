from __future__ import annotations

import datetime
import hashlib
import importlib.util
import json
import os
import re
from pathlib import Path
import tempfile
import unittest
from unittest import mock


MODULE_PATH = Path(__file__).with_name("validate-store.py")
SPEC = importlib.util.spec_from_file_location("validate_store", MODULE_PATH)
validate_store = importlib.util.module_from_spec(SPEC)
assert SPEC and SPEC.loader
SPEC.loader.exec_module(validate_store)

PACK_PATH = Path(__file__).parents[1] / "tools" / "pack-product.py"
PACK_SPEC = importlib.util.spec_from_file_location("pack_product", PACK_PATH)
pack_product = importlib.util.module_from_spec(PACK_SPEC)
assert PACK_SPEC and PACK_SPEC.loader
PACK_SPEC.loader.exec_module(pack_product)

CATEGORIES = (
    "rices", "lockscreens", "barstyles", "fastfetch", "plugins", "bundles",
    "decors", "launcher-images", "fastfetch-emblems", "ryotunes-skins",
)


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def write_json(path: Path, value: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2) + "\n", encoding="utf-8")


def build_skin_product(root: Path, product_id: str = "demo") -> tuple[Path, dict]:
    """A valid ryotunes-skins product, its manifest built by the real pack tool."""
    product = root / "ryotunes-skins" / product_id
    product.mkdir(parents=True, exist_ok=True)
    skin = {
        "format": 1,
        "id": product_id,
        "name": "Demo",
        "author": "Ryoku",
        "version": "1.0.0",
        "license": "CC0-1.0",
        "description": "Demo skin.",
        "default": "dark",
        "modes": {
            "dark": {
                "paper": "#101010", "paperLift": "#1a1a1a", "ink": "#e6e6e6",
                "inkDim": "#b0b0b0", "bone": "#e6e6e6", "inkOnBone": "#101010",
                "sun": "#e2342a", "alert": "#d33b32",
            }
        },
        "accent": "artwork",
        "wash": 1.0,
    }
    write_json(product / "skin.json", skin)
    (product / "LICENSE").write_text("CC0-1.0\n", encoding="utf-8")
    (product / "PROVENANCE.txt").write_text("Demo provenance.\n", encoding="utf-8")
    (product / "preview.png").write_bytes(b"fixture preview")
    mode = skin["modes"][skin["default"]]
    entry = {
        "id": product_id,
        "name": "Demo",
        "version": "1.0.0",
        "path": f"ryotunes-skins/{product_id}",
        "author": "Ryoku",
        "summary": "Demo skin",
        "description": "Demo skin.",
        "tags": ["dark", "ryoku", "colorscheme"],
        "accent": mode["sun"],
        "surface": mode["paper"],
        "preview": "preview.png",
        "screenshots": [],
        "manifest": "manifest.json",
        "manifestSha256": "0" * 64,
        "lastUpdated": "2020-01-01",
    }
    write_json(root / "ryotunes-skins" / "registry.json", {"schema": 1, "ryotunes-skins": [entry]})
    pack_product.pack_product(root, "ryotunes-skins", product_id)
    entry = json.loads(
        (root / "ryotunes-skins" / "registry.json").read_text(encoding="utf-8")
    )["ryotunes-skins"][0]
    return product, entry


def build_product(root: Path, category: str, product_id: str = "demo") -> tuple[Path, dict]:
    if category == "ryotunes-skins":
        return build_skin_product(root, product_id)
    product = root / category / product_id
    content = product / "content" / "Widget.qml"
    preview = product / "assets" / "preview.png"
    content.parent.mkdir(parents=True, exist_ok=True)
    preview.parent.mkdir(parents=True, exist_ok=True)
    content.write_text("import QtQuick\nItem {}\n", encoding="utf-8")
    preview.write_bytes(b"fixture preview")

    manifest = {
        "schema": 1,
        "id": product_id,
        "category": category,
        "version": "1.0.0",
        "destination": f"ryoku/{category}/{product_id}",
        "files": [
            {
                "source": "content/Widget.qml",
                "destination": "content/Widget.qml",
                "mode": "0644",
                "size": content.stat().st_size,
                "sha256": digest(content),
                "install": True,
            },
            {
                "source": "assets/preview.png",
                "destination": "assets/preview.png",
                "mode": "0644",
                "size": preview.stat().st_size,
                "sha256": digest(preview),
                "install": False,
            },
        ],
    }
    if category == "bundles":
        manifest["items"] = [
            {
                "type": "script",
                "name": "demo-tool",
                "detect": "demo",
                "summary": "Fixture tool.",
            }
        ]
    manifest_path = product / "manifest.json"
    write_json(manifest_path, manifest)
    entry = {
        "id": product_id,
        "name": "Demo",
        "version": "1.0.0",
        "path": f"{category}/{product_id}",
        "author": "Ryoku Team",
        "summary": "Fixture summary",
        "description": "Fixture description",
        "tags": ["fixture"],
        "accent": "#cdc4ba",
        "surface": "#101010",
        "preview": "assets/preview.png",
        "screenshots": [],
        "manifest": "manifest.json",
        "manifestSha256": digest(manifest_path),
    }
    if category == "bundles":
        entry["components"] = validate_store.normalized_bundle_components(manifest)
    return product, entry


def build_tree(root: Path) -> dict[str, tuple[Path, dict]]:
    products = {}
    for category in CATEGORIES:
        product, entry = build_product(root, category)
        write_json(root / category / "registry.json", {"schema": 1, category: [entry]})
        products[category] = (product, entry)
    return products


class ValidateStoreTest(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.products = build_tree(self.root)

    def tearDown(self) -> None:
        self.temp.cleanup()

    def errors(self) -> list[str]:
        return validate_store.validate_tree(self.root)

    def rewrite_manifest(self, category: str, mutate) -> None:
        product, entry = self.products[category]
        path = product / "manifest.json"
        manifest = json.loads(path.read_text(encoding="utf-8"))
        mutate(manifest)
        write_json(path, manifest)
        entry["manifestSha256"] = digest(path)
        write_json(self.root / category / "registry.json", {"schema": 1, category: [entry]})

    def test_valid_tree(self) -> None:
        self.assertEqual(self.errors(), [])

    def test_unsupported_registry_schema_is_rejected(self) -> None:
        _, entry = self.products["lockscreens"]
        write_json(
            self.root / "lockscreens" / "registry.json",
            {"schema": 2, "lockscreens": [entry]},
        )
        self.assertIn(
            "lockscreens/registry.json: unsupported schema",
            self.errors(),
        )

    def test_registry_extra_key_is_rejected(self) -> None:
        _, entry = self.products["lockscreens"]
        write_json(
            self.root / "lockscreens" / "registry.json",
            {"schema": 1, "lockscreens": [entry], "archived": []},
        )
        self.assertIn(
            "lockscreens/registry.json: invalid registry envelope",
            self.errors(),
        )

    def test_bundle_components_match_manifest_items(self) -> None:
        product, entry = self.products["bundles"]
        manifest_path = product / "manifest.json"
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
        manifest["items"] = [
            {
                "type": "script",
                "name": "demo-tool",
                "detect": "demo",
                "tier": "optional",
                "interactive": True,
                "summary": "Fixture tool.",
            }
        ]
        write_json(manifest_path, manifest)
        entry["manifestSha256"] = digest(manifest_path)
        entry["components"] = [
            {
                "type": "script",
                "name": "demo-tool",
                "detect": "wrong",
                "tier": "optional",
                "interactive": True,
                "summary": "Fixture tool.",
            }
        ]
        write_json(self.root / "bundles" / "registry.json", {"schema": 1, "bundles": [entry]})
        self.assertIn(
            "bundles/demo: components do not match manifest items",
            self.errors(),
        )

    def test_duplicate_ids(self) -> None:
        _, entry = self.products["rices"]
        write_json(self.root / "rices" / "registry.json", {"schema": 1, "rices": [entry, entry]})
        self.assertIn("rices/demo: duplicate id", self.errors())

    def test_missing_product_path(self) -> None:
        _, entry = self.products["rices"]
        entry["path"] = "rices/missing"
        write_json(self.root / "rices" / "registry.json", {"schema": 1, "rices": [entry]})
        self.assertIn("rices/demo: product path missing: rices/missing", self.errors())

    def test_manifest_hash_mismatch(self) -> None:
        _, entry = self.products["rices"]
        entry["manifestSha256"] = "0" * 64
        write_json(self.root / "rices" / "registry.json", {"schema": 1, "rices": [entry]})
        self.assertIn("rices/demo: manifest hash mismatch", self.errors())

    def test_null_registry_is_rejected(self) -> None:
        (self.root / "rices" / "registry.json").write_text("null\n", encoding="utf-8")
        self.assertIn("rices/registry.json: root must be an object", self.errors())

    def test_null_manifest_is_rejected(self) -> None:
        product, entry = self.products["rices"]
        manifest = product / "manifest.json"
        manifest.write_text("null\n", encoding="utf-8")
        entry["manifestSha256"] = digest(manifest)
        write_json(self.root / "rices" / "registry.json", {"schema": 1, "rices": [entry]})
        self.assertIn("rices/demo: manifest must be an object", self.errors())

    def test_non_json_numeric_constant_is_rejected(self) -> None:
        product, entry = self.products["rices"]
        manifest = product / "manifest.json"
        value = json.loads(manifest.read_text(encoding="utf-8"))
        value["extra"] = float("nan")
        write_json(manifest, value)
        entry["manifestSha256"] = digest(manifest)
        write_json(self.root / "rices" / "registry.json", {"schema": 1, "rices": [entry]})
        self.assertTrue(any("invalid JSON" in error for error in self.errors()))

    def test_parent_source_path_is_rejected(self) -> None:
        self.rewrite_manifest("rices", lambda manifest: manifest["files"][0].update(source="../Widget.qml"))
        self.assertIn("rices/demo: source escapes product root: ../Widget.qml", self.errors())

    def test_absolute_destination_is_rejected(self) -> None:
        self.rewrite_manifest("rices", lambda manifest: manifest["files"][0].update(destination="/tmp/Widget.qml"))
        self.assertIn("rices/demo: destination must be relative: /tmp/Widget.qml", self.errors())

    def test_symlink_is_rejected(self) -> None:
        product, _ = self.products["rices"]
        os.symlink(product / "content" / "Widget.qml", product / "content" / "Alias.qml")
        self.assertIn("rices/demo: symlink forbidden: content/Alias.qml", self.errors())

    def test_product_ancestor_symlink_is_rejected(self) -> None:
        product, entry = self.products["rices"]
        shared = self.root / "shared"
        shared.mkdir()
        product.rename(shared / "demo")
        os.symlink(shared, self.root / "rices" / "linked")
        entry["path"] = "rices/linked/demo"
        write_json(self.root / "rices" / "registry.json", {"schema": 1, "rices": [entry]})
        self.assertIn("rices/demo: product path contains a symlink: rices/linked/demo", self.errors())

    def test_registry_symlink_is_rejected(self) -> None:
        registry = self.root / "rices" / "registry.json"
        target = self.root / "rices-registry.json"
        registry.rename(target)
        os.symlink(target, registry)
        self.assertIn("rices/registry.json: symlink forbidden", self.errors())

    def test_invalid_manifest_hash_stops_before_parsing(self) -> None:
        product, entry = self.products["rices"]
        (product / "manifest.json").write_text("{", encoding="utf-8")
        entry["manifestSha256"] = "invalid"
        write_json(self.root / "rices" / "registry.json", {"schema": 1, "rices": [entry]})
        errors = self.errors()
        self.assertIn("rices/demo: manifestSha256 must be lowercase SHA-256", errors)
        self.assertFalse(any("invalid JSON" in error for error in errors))

    def test_invalid_collection_and_path_types_report_errors(self) -> None:
        _, entry = self.products["rices"]
        entry["screenshots"] = 42
        write_json(self.root / "rices" / "registry.json", {"schema": 1, "rices": [entry]})
        self.assertIn("rices/demo: screenshots must be non-empty strings", self.errors())

        self.products = build_tree(self.root)
        self.rewrite_manifest("rices", lambda manifest: manifest["files"][0].update(destination=[]))
        self.assertIn("rices/demo: destination must be relative: []", self.errors())

    def test_extra_manifest_file_key_is_rejected(self) -> None:
        self.rewrite_manifest("rices", lambda manifest: manifest["files"][0].update(extra=True))
        self.assertIn("rices/demo: files[0] has unknown field extra", self.errors())

    def test_documentation_directory_does_not_exempt_payload(self) -> None:
        product, _ = self.products["plugins"]
        docs = product / "docs"
        docs.mkdir()
        (docs / "Widget.qml").write_text("import QtQuick\nItem {}\n", encoding="utf-8")
        self.assertIn("plugins/demo: undeclared payload docs/Widget.qml", self.errors())

    def test_executable_documentation_path_is_not_exempt(self) -> None:
        product, _ = self.products["plugins"]
        docs = product / "docs"
        docs.mkdir()
        script = docs / "install"
        script.write_text("#!/usr/bin/env bash\nexit 0\n", encoding="utf-8")
        script.chmod(0o755)
        self.assertIn("plugins/demo: undeclared payload docs/install", self.errors())

    def test_executable_named_document_is_not_exempt(self) -> None:
        product, _ = self.products["plugins"]
        script = product / "docs" / "README"
        script.parent.mkdir()
        script.write_text("#!/usr/bin/env bash\nexit 0\n", encoding="utf-8")
        script.chmod(0o755)
        self.assertIn("plugins/demo: undeclared payload docs/README", self.errors())

    def test_destination_ancestor_collision_is_rejected(self) -> None:
        self.rewrite_manifest(
            "rices",
            lambda manifest: manifest["files"][1].update(
                destination="content/Widget.qml/preview.png"
            ),
        )
        self.assertIn(
            "rices/demo: destination path collision: content/Widget.qml/preview.png",
            self.errors(),
        )

    def test_bare_dot_path_is_rejected(self) -> None:
        self.rewrite_manifest(
            "rices",
            lambda manifest: manifest["files"][0].update(destination="."),
        )
        self.assertIn("rices/demo: destination must be relative: .", self.errors())

    def test_boolean_manifest_schema_is_rejected(self) -> None:
        self.rewrite_manifest("rices", lambda manifest: manifest.update(schema=True))
        self.assertIn("rices/demo: manifest schema does not match registry", self.errors())

    def test_noncanonical_source_path_is_rejected(self) -> None:
        self.rewrite_manifest(
            "rices",
            lambda manifest: manifest["files"][0].update(source="content//Widget.qml"),
        )
        self.assertIn("rices/demo: source escapes product root: content//Widget.qml", self.errors())

    def test_undeclared_payload_is_rejected(self) -> None:
        product, _ = self.products["plugins"]
        (product / "content" / "Extra.qml").write_text("import QtQuick\nItem {}\n", encoding="utf-8")
        self.assertIn("plugins/demo: undeclared payload content/Extra.qml", self.errors())

    def test_wrong_executable_mode_is_rejected(self) -> None:
        product, _ = self.products["bundles"]
        script = product / "content" / "install.sh"
        script.write_text("#!/usr/bin/env bash\nexit 0\n", encoding="utf-8")
        script.chmod(0o755)

        def add_script(manifest: dict) -> None:
            manifest["files"].append({
                "source": "content/install.sh",
                "destination": "content/install.sh",
                "mode": "0644",
                "size": script.stat().st_size,
                "sha256": digest(script),
                "install": True,
            })

        self.rewrite_manifest("bundles", add_script)
        self.assertIn("bundles/demo: executable source requires mode 0755: content/install.sh", self.errors())

    def test_missing_preview_is_rejected(self) -> None:
        product, _ = self.products["fastfetch"]
        (product / "assets" / "preview.png").unlink()
        self.assertIn("fastfetch/demo: preview missing: assets/preview.png", self.errors())

    def test_svg_media_is_decoded(self) -> None:
        media = self.root / "preview.svg"
        media.write_text(
            '<svg xmlns="http://www.w3.org/2000/svg" width="1280" height="720"/>',
            encoding="utf-8",
        )
        responses = [
            mock.Mock(stdout="1280 720"),
            mock.Mock(stdout="0.25"),
        ]
        with mock.patch.object(validate_store.subprocess, "run", side_effect=responses) as run:
            self.assertIsNone(validate_store.media_error(media, "fixture"))
        self.assertEqual(run.call_count, 2)

    def test_media_blankness_composites_alpha(self) -> None:
        media = self.root / "preview.png"
        media.write_bytes(b"fixture")
        responses = [
            mock.Mock(stdout="1280 720"),
            mock.Mock(stdout="0.25"),
        ]
        with mock.patch.object(validate_store.subprocess, "run", side_effect=responses) as run:
            self.assertIsNone(validate_store.media_error(media, "fixture"))
        deviation_command = run.call_args_list[1].args[0]
        self.assertIn("-background", deviation_command)
        self.assertIn("-alpha", deviation_command)
        self.assertIn("remove", deviation_command)

    def test_multiframe_media_statistics_are_parsed_per_frame(self) -> None:
        media = self.root / "preview.gif"
        media.write_bytes(b"fixture")
        responses = [
            mock.Mock(stdout="1280 720\n1280 720\n"),
            mock.Mock(stdout="0.25\n0.10\n"),
        ]
        with mock.patch.object(validate_store.subprocess, "run", side_effect=responses):
            self.assertIsNone(validate_store.media_error(media, "fixture"))

class MigratedCatalogueTest(unittest.TestCase):
    def test_migrated_categories_satisfy_store_contract(self) -> None:
        root = MODULE_PATH.parent.parent
        for category in ("rices", "plugins", "bundles", "barstyles", "fastfetch"):
            with self.subTest(category=category):
                self.assertEqual(
                    validate_store.validate_tree(root, (category,)),
                    [],
                )

    def test_plugins_publish_runtime_trees_through_product_manifests(self) -> None:
        root = MODULE_PATH.parent.parent
        registry = json.loads(
            (root / "plugins" / "registry.json").read_text(encoding="utf-8")
        )
        ids = [entry["id"] for entry in registry["plugins"]]
        # the shipped four are always listed; community plugins join them
        for shipped in ("obsidian", "market", "photo-frame", "stargate"):
            self.assertIn(shipped, ids)
        self.assertEqual(len(ids), len(set(ids)), "duplicate plugin id")
        for entry in registry["plugins"]:
            with self.subTest(plugin=entry["id"]):
                self.assertIn("official", entry, "every plugin says whether Ryoku wrote it")
                self.assertTrue(entry.get("hosts"), "every plugin names its hosts")
        for entry in registry["plugins"]:
            with self.subTest(plugin=entry["id"]):
                self.assertEqual(entry["manifest"], "product-manifest.json")
                product_root = root / entry["path"]
                manifest = json.loads(
                    (product_root / entry["manifest"]).read_text(encoding="utf-8")
                )
                self.assertEqual(
                    manifest["destination"], f"ryoku/plugins/{entry['id']}"
                )
                files = {item["source"]: item for item in manifest["files"]}
                self.assertTrue(files["manifest.json"]["install"])
                self.assertEqual(files["manifest.json"]["destination"], "manifest.json")
                accounted = {
                    path.relative_to(product_root).as_posix()
                    for path in product_root.rglob("*")
                    if path.is_file() and path.name != "product-manifest.json"
                }
                self.assertEqual(set(files), accounted)


    def test_fastfetch_presets_only_reach_their_own_product(self) -> None:
        """Applying a preset copies config.jsonc to ~/.config/fastfetch, while its
        other files install to ~/.local/share/ryoku/fastfetch/<id>. A config may
        therefore name assets in its own product directory and nowhere else, and
        every asset it names must actually be installed."""
        root = MODULE_PATH.parent.parent
        registry = json.loads(
            (root / "fastfetch" / "registry.json").read_text(encoding="utf-8")
        )
        forbidden = re.compile(
            r"\$HOME|/home/|%USERPROFILE%|(?<![A-Za-z])[A-Za-z]:[\\/]"
            r"|\$\(|\"type\"\s*:\s*\"(?:command|exec)\""
        )
        for entry in registry["fastfetch"]:
            with self.subTest(preset=entry["id"]):
                product = root / entry["path"]
                text = (product / "config.jsonc").read_text(encoding="utf-8")
                self.assertIsNone(
                    forbidden.search(text),
                    f"{entry['id']}: a preset must not shell out or name a foreign path",
                )
                manifest = json.loads((product / entry["manifest"]).read_text(encoding="utf-8"))
                installed = {
                    row["destination"] for row in manifest["files"] if row.get("install")
                }
                own = f"~/.local/share/ryoku/fastfetch/{entry['id']}/"
                for reference in re.findall(r"~/[^\"']+", text):
                    self.assertTrue(
                        reference.startswith(own),
                        f"{entry['id']}: reaches outside its product: {reference}",
                    )
                    self.assertIn(
                        reference[len(own):],
                        installed,
                        f"{entry['id']}: names an asset it does not install: {reference}",
                    )

    def test_lockscreens_satisfy_store_contract_without_core_fallback(self) -> None:
        root = MODULE_PATH.parent.parent
        self.assertEqual(validate_store.validate_tree(root, ("lockscreens",)), [])
        registry = json.loads(
            (root / "lockscreens" / "registry.json").read_text(encoding="utf-8")
        )
        ids = [entry["id"] for entry in registry["lockscreens"]]
        # the adopted legacy Tape stays and the built-in core fallback never
        # ships as an installable product; real qylock skins are offered beyond
        # the single legacy entry.
        self.assertIn("clockwork-tape", ids)
        self.assertNotIn("clockwork-orbital", ids)
        self.assertNotIn("clockwork-orbital", json.dumps(registry))
        self.assertGreater(len(ids), 1)
        self.assertEqual(len(ids), len(set(ids)))

    def test_bundle_components_are_complete_and_inline(self) -> None:
        root = MODULE_PATH.parent.parent
        registry = json.loads((root / "bundles" / "registry.json").read_text(encoding="utf-8"))
        for entry in registry["bundles"]:
            with self.subTest(bundle=entry["id"]):
                manifest = json.loads(
                    (root / entry["path"] / entry["manifest"]).read_text(encoding="utf-8")
                )
                self.assertEqual(
                    entry.get("components"),
                    validate_store.normalized_bundle_components(manifest),
                )


class RyotunesSkinsTest(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.product, self.entry = build_skin_product(self.root, "demo")

    def tearDown(self) -> None:
        self.temp.cleanup()

    def write_registry(self) -> None:
        write_json(
            self.root / "ryotunes-skins" / "registry.json",
            {"schema": 1, "ryotunes-skins": [self.entry]},
        )

    def errors(self) -> list[str]:
        self.write_registry()
        return validate_store.validate_tree(self.root, ("ryotunes-skins",))

    def test_valid_skin_product_passes(self) -> None:
        self.assertEqual(self.errors(), [])

    def test_registry_accent_must_match_default_mode_sun(self) -> None:
        self.entry["accent"] = "#00ff00"
        self.assertIn(
            "ryotunes-skins/demo: registry accent must equal the default mode's sun",
            self.errors(),
        )

    def test_registry_surface_must_match_default_mode_paper(self) -> None:
        self.entry["surface"] = "#00ff00"
        self.assertIn(
            "ryotunes-skins/demo: registry surface must equal the default mode's paper",
            self.errors(),
        )

    def test_skin_json_must_install(self) -> None:
        manifest_path = self.product / "manifest.json"
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
        for row in manifest["files"]:
            if row["source"] == "skin.json":
                row["install"] = False
        write_json(manifest_path, manifest)
        self.entry["manifestSha256"] = digest(manifest_path)
        self.assertIn(
            "ryotunes-skins/demo: skin.json must be declared with install true",
            self.errors(),
        )

    def test_skin_id_must_equal_folder(self) -> None:
        skin_path = self.product / "skin.json"
        skin = json.loads(skin_path.read_text(encoding="utf-8"))
        skin["id"] = "not-demo"
        write_json(skin_path, skin)
        self.write_registry()
        pack_product.pack_product(self.root, "ryotunes-skins", "demo")
        errors = validate_store.validate_tree(self.root, ("ryotunes-skins",))
        self.assertIn(
            "ryotunes-skins/demo: skin.json id must equal the folder name 'demo'",
            errors,
        )

    def test_pack_is_byte_stable(self) -> None:
        self.write_registry()
        manifest_path = self.product / "manifest.json"
        registry_path = self.root / "ryotunes-skins" / "registry.json"
        pack_product.pack_product(self.root, "ryotunes-skins", "demo")
        before = (manifest_path.read_bytes(), registry_path.read_bytes())
        pack_product.pack_product(self.root, "ryotunes-skins", "demo")
        self.assertEqual(before, (manifest_path.read_bytes(), registry_path.read_bytes()))

    def test_real_catalogue_validates(self) -> None:
        root = MODULE_PATH.parent.parent
        self.assertEqual(validate_store.validate_tree(root, ("ryotunes-skins",)), [])
        registry = json.loads(
            (root / "ryotunes-skins" / "registry.json").read_text(encoding="utf-8")
        )
        ids = [entry["id"] for entry in registry["ryotunes-skins"]]
        self.assertEqual(len(ids), 20)
        self.assertEqual(len(ids), len(set(ids)))
        self.assertIn("tokyo-night-storm", ids)
        for entry in registry["ryotunes-skins"]:
            with self.subTest(skin=entry["id"]):
                self.assertEqual(entry["manifest"], "manifest.json")
                manifest = json.loads(
                    (root / entry["path"] / entry["manifest"]).read_text(encoding="utf-8")
                )
                self.assertEqual(
                    manifest["destination"], f"ryoku/ryotunes-skins/{entry['id']}"
                )


def build_plugin_source(root: Path, product_id: str = "demo") -> dict:
    """A plugin product on disk plus a registry that names it, ready to pack.

    manifestSha256 is a placeholder; pack_product.pack_product overwrites it.
    """
    product = root / "plugins" / product_id
    payload = {
        "README.md": b"# Demo\n",
        "manifest.json": b'{"id": "demo"}\n',
        "service/Main.qml": b"import QtQuick\nItem {}\n",
        "content/Widget.qml": b"import QtQuick\nItem {}\n",
        "assets/preview.png": b"fixture preview",
        "assets/shot.png": b"fixture screenshot",
        "assets/sample.png": b"fixture sample",
        "bin/demo-tool": b"#!/usr/bin/env bash\necho demo\n",
    }
    for relative, data in payload.items():
        target = product / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(data)
    os.chmod(product / "bin" / "demo-tool", 0o755)
    entry = {
        "id": product_id,
        "name": "Demo",
        "version": "2.0.0",
        "path": f"plugins/{product_id}",
        "author": "Ryoku Team",
        "summary": "Fixture summary",
        "description": "Fixture description",
        "tags": ["bar-widget"],
        "accent": "#cdc4ba",
        "surface": "#101010",
        "preview": "assets/preview.png",
        "screenshots": ["assets/shot.png"],
        "manifest": "product-manifest.json",
        "manifestSha256": "0" * 64,
        "official": False,
        "hosts": ["topbarGlyph"],
        "lastUpdated": "2020-01-01",
    }
    write_json(root / "plugins" / "registry.json", {"schema": 1, "plugins": [entry]})
    return entry


class PackProductTest(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        build_plugin_source(self.root)

    def tearDown(self) -> None:
        self.temp.cleanup()

    def rows(self) -> dict[str, dict]:
        manifest = json.loads(
            (self.root / "plugins" / "demo" / "product-manifest.json").read_text("utf-8")
        )
        return {row["source"]: row for row in manifest["files"]}

    def test_packed_product_validates(self) -> None:
        pack_product.pack_product(self.root, "plugins", "demo")
        self.assertEqual(validate_store.validate_tree(self.root, ("plugins",)), [])

    def test_generated_bytecode_cannot_be_published(self) -> None:
        product = self.root / "plugins" / "demo"
        cache = product / "bin" / "__pycache__"
        cache.mkdir()
        (cache / "helper.cpython-314.pyc").write_bytes(b"generated bytecode")
        with self.assertRaises(ValueError):
            pack_product.pack_product(self.root, "plugins", "demo")
        self.assertFalse((product / "product-manifest.json").exists())

    def test_manifest_shape_matches_conventions(self) -> None:
        manifest = pack_product.pack_product(self.root, "plugins", "demo")
        self.assertEqual(manifest["schema"], 1)
        self.assertEqual(manifest["destination"], "ryoku/plugins/demo")
        self.assertEqual(manifest["version"], "2.0.0")
        sources = [row["source"] for row in manifest["files"]]
        self.assertEqual(sources, sorted(sources))
        self.assertNotIn("product-manifest.json", sources)
        for row in manifest["files"]:
            self.assertEqual(row["destination"], row["source"])

    def test_install_flags_and_modes(self) -> None:
        pack_product.pack_product(self.root, "plugins", "demo")
        rows = self.rows()
        self.assertFalse(rows["README.md"]["install"])  # documentation
        self.assertFalse(rows["assets/preview.png"]["install"])  # preview
        self.assertFalse(rows["assets/shot.png"]["install"])  # screenshot
        self.assertTrue(rows["assets/sample.png"]["install"])  # ordinary asset
        self.assertTrue(rows["manifest.json"]["install"])
        self.assertTrue(rows["content/Widget.qml"]["install"])
        self.assertEqual(rows["bin/demo-tool"]["mode"], "0755")  # shebang + exec bit
        self.assertTrue(rows["bin/demo-tool"]["install"])
        for source in ("README.md", "manifest.json", "assets/preview.png"):
            self.assertEqual(rows[source]["mode"], "0644")

    def test_registry_hash_tracks_manifest(self) -> None:
        pack_product.pack_product(self.root, "plugins", "demo")
        registry = json.loads((self.root / "plugins" / "registry.json").read_text("utf-8"))
        entry = registry["plugins"][0]
        self.assertEqual(
            entry["manifestSha256"],
            digest(self.root / "plugins" / "demo" / "product-manifest.json"),
        )

    def test_repack_is_byte_identical(self) -> None:
        pack_product.pack_product(self.root, "plugins", "demo")
        manifest_path = self.root / "plugins" / "demo" / "product-manifest.json"
        registry_path = self.root / "plugins" / "registry.json"
        before = (manifest_path.read_bytes(), registry_path.read_bytes())
        pack_product.pack_product(self.root, "plugins", "demo")
        after = (manifest_path.read_bytes(), registry_path.read_bytes())
        self.assertEqual(before, after)

    def test_touch_updates_only_last_updated(self) -> None:
        pack_product.pack_product(self.root, "plugins", "demo")
        registry_path = self.root / "plugins" / "registry.json"
        before = json.loads(registry_path.read_text("utf-8"))["plugins"][0]
        pack_product.pack_product(self.root, "plugins", "demo", touch=True)
        after = json.loads(registry_path.read_text("utf-8"))["plugins"][0]
        self.assertEqual(after["lastUpdated"], datetime.date.today().isoformat())
        self.assertEqual(after["manifestSha256"], before["manifestSha256"])

    def test_unsupported_category_is_rejected(self) -> None:
        with self.assertRaises(ValueError):
            pack_product.pack_product(self.root, "decors", "demo")



if __name__ == "__main__":
    unittest.main()
