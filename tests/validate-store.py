#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import subprocess
import sys
from typing import Iterable


CATEGORIES = (
    "rices", "lockscreens", "barstyles", "launchers", "docks", "osds", "notifications",
    "sidebars", "fastfetch", "plugins", "bundles", "decors", "launcher-images",
    "fastfetch-emblems", "ryotunes-skins", "vesktop-themes",
)


class FolderProduct:
    """A category whose product installs whole into ryoku/<category>/<id> and
    runs from its own folder: entry is the file the shell loads, preview the
    optional Settings preview, and reserved the ids of the ones the shell ships
    (the shell always runs its own for those, so a Store product cannot take
    one)."""

    def __init__(self, noun: str, entry: str, preview: str | None, reserved: set[str]):
        self.noun, self.entry, self.preview, self.reserved = noun, entry, preview, reserved


FOLDER_PRODUCTS = {
    # The shell's modules/launcher/catalog.json.
    "launchers": FolderProduct("launcher", "Main.qml", "Preview.qml",
                               {"main", "hero", "okshell", "kairos", "spotlight", "python"}),
    # The shell's services/Dock.qml builtinDesigns.
    "docks": FolderProduct("dock", "Dock.qml", None, {"ryoku", "python", "shima", "ii", "none"}),
    "osds": FolderProduct("OSD design", "Osd.qml", None, {"ryoku"}),
    "notifications": FolderProduct("notification design", "Card.qml", None, {"ryoku"}),
    "sidebars": FolderProduct("sidebar design", "Sidebar.qml", None, {"ryoku"}),
}
REQUIRED_ENTRY_FIELDS = (
    "id", "name", "version", "path", "author", "summary", "description",
    "tags", "accent", "surface", "preview", "screenshots", "manifest",
    "manifestSha256", "upstream",
)
TEXT_FIELDS = (
    "id", "name", "version", "path", "author", "summary", "description",
    "accent", "surface", "preview", "manifest", "manifestSha256", "upstream",
)
ID_PATTERN = re.compile(r"^[a-z0-9]+(?:-[a-z0-9]+)*$")
HEX_PATTERN = re.compile(r"^[0-9a-f]{64}$")
COLOR_PATTERN = re.compile(r"^#[0-9A-Fa-f]{6}$")
UPSTREAM_PATTERN = re.compile(r"^https://[^\s/]+\.[^\s/]+/\S+$")
DISCORD_PATTERN = re.compile(r"^https://(?:discord\.gg|discord\.com/invite)/[A-Za-z0-9-]+$")
# The package managers `ryoku-host pkgmgr` names, one per family of Ryoku
# editions; an item limited to some of them declares `packageManagers`.
PACKAGE_MANAGERS = ("pacman", "dnf", "xbps")
# Bundle package items keep their Arch names. These tables name them on the
# other editions; ryoku-host lays them under Ryoku's own edition tables.
EDITION_TABLES = ("void", "fedora")
NATIVE_PACKAGE_PATTERN = re.compile(r"^[A-Za-z0-9][A-Za-z0-9+_.-]*$")
# Official Void repositories a row may need switched on first, and Ryoku's own
# repository (configured by the installer on every edition).
TABLE_REPOSITORIES = {"void": {"multilib", "nonfree", "multilib-nonfree", "ryoku"}, "fedora": {"ryoku"}}
# Nerd Font code points that draw one operating system's own mark: the Font
# Logos distributions and the dev, fa and md families' distribution, Windows,
# Apple and Android marks. A fastfetch preset runs on whichever edition the
# user has, so it may not claim one; its logo already shows the system, and Tux
# (U+F31A, U+F17C, U+E712, U+F033D) is the neutral mark.
DISTRIBUTION_MARKS = frozenset(int(code, 16) for code in """
    F300 F301 F302 F303 F304 F305 F306 F307 F309 F30A F30B F30C F30D F30E F30F
    F310 F311 F312 F313 F314 F315 F316 F317 F318 F319 F31B F31C F31D F31E F31F
    F321 F322 F325 F326 F327 F328 F329 F32A F32B F32D F32E F32F F331 F333 F334
    F337 F33A F33E F33F F340 F341 F342 F343 F344 F345 F346 F347 F348 F349 F34A
    F374 F37D F37E F380 F382 F385
    E62A E635 E70E E70F E711 E73A E77D E78A E7BB E7D9 E7E6 E843 E857
    ED04 EF3D EF46 EF5D EF6D EF72 F179 F17A F17B F28F
    F0032 F0035 F0372 F0548 F05B3 F08C7 F08DA F08DB F08E0 F08E8 F08ED F0A21
    F111A F111B F160A
""".split())
# fastfetch's per-manager package counts. Each prints nothing on the editions
# that use another manager, so a format names all of them or none.
PACKAGE_COUNTS = {"pacman", "rpm", "xbps"}
PACKAGE_COUNT_PATTERN = re.compile(r"\{(pacman|rpm|xbps)\}")
# A preset may hand the readout to an executable in its own product folder:
#   // ryoku:renderer <product-id>/<relative-executable>
# ryoku-fastfetch resolves the same marker at runtime; the store rejects a
# renderer that escapes its product, is not executable, or is not installed.
RENDERER_LINE = re.compile(r"^//[ \t]*ryoku:renderer\b.*$", re.MULTILINE)
RENDERER_PATTERN = re.compile(r"^//[ \t]*ryoku:renderer[ \t]+(\S+)$", re.MULTILINE)
RENDERER_TARGET = re.compile(r"^[a-z0-9][a-z0-9-]*/[A-Za-z0-9_./-]+$")
MAX_FILE_SIZE = 256 * 1024 * 1024
MAX_PRODUCT_SIZE = 512 * 1024 * 1024
MAX_FILES = 2048
DOC_NAMES = ("readme", "license", "copying", "notice", "authors")
DOC_EXTENSIONS = {"", ".md", ".txt", ".rst", ".adoc"}
FILE_FIELDS = {"source", "destination", "mode", "size", "sha256", "install"}
VECTOR_MEDIA = {".svg"}
RASTER_MEDIA = {".png", ".jpg", ".jpeg", ".webp", ".gif", ".avif"}
LOAD_FAILED = object()


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def safe_relative(value: object) -> bool:
    if not isinstance(value, str) or not value or "\\" in value or "\x00" in value:
        return False
    path = PurePosixPath(value)
    return (
        not path.is_absolute()
        and bool(path.parts)
        and path.as_posix() == value
        and all(part not in ("", ".", "..") for part in path.parts)
    )


def reject_json_constant(value: str) -> None:
    raise ValueError(f"invalid numeric constant {value}")


def load_json(path: Path, errors: list[str], label: str) -> object:
    try:
        return json.loads(
            path.read_text(encoding="utf-8"),
            parse_constant=reject_json_constant,
        )
    except FileNotFoundError:
        errors.append(f"{label}: missing")
    except (OSError, UnicodeError, ValueError) as error:
        errors.append(f"{label}: invalid JSON: {error}")
    return LOAD_FAILED


def contains_symlink(root: Path, value: str) -> bool:
    current = root
    for part in PurePosixPath(value).parts:
        current /= part
        if current.is_symlink():
            return True
    return False


def product_file(product: Path, value: object) -> Path | None:
    if not safe_relative(value):
        return None
    relative = str(value)
    candidate = product.joinpath(*PurePosixPath(relative).parts)
    if contains_symlink(product, relative):
        return None
    try:
        candidate.resolve().relative_to(product.resolve())
    except (OSError, ValueError):
        return None
    return candidate


def is_documentation(relative: str) -> bool:
    path = PurePosixPath(relative)
    name = path.name.lower()
    named_document = any(name == prefix or name.startswith(prefix + ".") for prefix in DOC_NAMES)
    in_documentation = bool(path.parts and path.parts[0].lower() in ("docs", "documentation"))
    if path.suffix == "":
        return named_document
    return (named_document or in_documentation) and path.suffix.lower() in DOC_EXTENSIONS


def starts_with_shebang(path: Path) -> bool:
    try:
        with path.open("rb") as source:
            return source.read(2) == b"#!"
    except OSError:
        return False


def is_executable_code(path: Path) -> bool:
    try:
        return bool(path.stat().st_mode & 0o111) or starts_with_shebang(path)
    except OSError:
        return False


def media_error(path: Path, label: str) -> str | None:
    if path.suffix.lower() not in VECTOR_MEDIA | RASTER_MEDIA:
        return f"{label}: unsupported media format: {path.name}"
    try:
        dimension_output = subprocess.run(
            ["magick", "identify", "-format", "%w %h\n", str(path)],
            check=True,
            capture_output=True,
            text=True,
        ).stdout
        dimensions = []
        for record in dimension_output.splitlines():
            values = record.split()
            if len(values) != 2:
                raise ValueError(f"invalid dimensions {record!r}")
            dimensions.append((int(values[0]), int(values[1])))
        if not dimensions:
            raise ValueError("missing dimensions")
        for width, height in dimensions:
            if width < 1280 or height < 720:
                return f"{label}: preview is smaller than 1280x720: {width}x{height}"
        deviation_output = subprocess.run(
            [
                "magick",
                str(path),
                "-background",
                "#808080",
                "-alpha",
                "remove",
                "-alpha",
                "off",
                "-colorspace",
                "gray",
                "-format",
                "%[fx:standard_deviation]\n",
                "info:",
            ],
            check=True,
            capture_output=True,
            text=True,
        ).stdout
        deviations = [
            float(record)
            for record in deviation_output.splitlines()
            if record.strip()
        ]
        if not deviations or max(deviations) <= 0.001:
            return f"{label}: preview is blank"
    except FileNotFoundError:
        return f"{label}: ImageMagick 'magick' is unavailable"
    except (subprocess.CalledProcessError, ValueError, IndexError) as error:
        return f"{label}: unreadable media: {error}"
    return None


def validate_manifest(
    category: str,
    entry: dict,
    product: Path,
    manifest: object,
    errors: list[str],
    require_media: bool,
) -> None:
    label = f"{category}/{entry.get('id', '?')}"
    if not isinstance(manifest, dict):
        errors.append(f"{label}: manifest must be an object")
        return
    expected = {
        "schema": 1,
        "id": entry.get("id"),
        "category": category,
        "version": entry.get("version"),
    }
    for field, value in expected.items():
        actual = manifest.get(field)
        matches = (
            type(actual) is int and actual == value
            if field == "schema"
            else actual == value
        )
        if not matches:
            errors.append(f"{label}: manifest {field} does not match registry")
    destination = manifest.get("destination")
    if not safe_relative(destination):
        errors.append(f"{label}: manifest destination must be relative: {destination}")

    files = manifest.get("files")
    if not isinstance(files, list) or not files:
        errors.append(f"{label}: manifest files must be a non-empty array")
        return
    if len(files) > MAX_FILES:
        errors.append(f"{label}: manifest has more than {MAX_FILES} files")

    declared: dict[str, bool] = {}
    destinations: set[str] = set()
    total_size = 0
    for index, row in enumerate(files):
        row_label = f"{label}: files[{index}]"
        if not isinstance(row, dict):
            errors.append(f"{row_label} must be an object")
            continue
        unknown_fields = sorted(set(row) - FILE_FIELDS)
        for field in unknown_fields:
            errors.append(f"{row_label} has unknown field {field}")
        source = row.get("source")
        destination_value = row.get("destination")
        if not safe_relative(source):
            errors.append(f"{label}: source escapes product root: {source}")
            continue
        if not safe_relative(destination_value):
            errors.append(f"{label}: destination must be relative: {destination_value}")
            continue
        source_key = str(source)
        destination_key = str(destination_value)
        if source_key in declared:
            errors.append(f"{label}: duplicate source: {source_key}")
        if destination_key in destinations:
            errors.append(f"{label}: duplicate destination: {destination_key}")
        destination_parts = PurePosixPath(destination_key).parts
        for existing in destinations:
            existing_parts = PurePosixPath(existing).parts
            if (
                existing != destination_key
                and (
                    existing_parts == destination_parts[:len(existing_parts)]
                    or destination_parts == existing_parts[:len(destination_parts)]
                )
            ):
                errors.append(f"{label}: destination path collision: {destination_key}")
                break
        destinations.add(destination_key)

        mode = row.get("mode")
        if mode not in ("0644", "0755"):
            errors.append(f"{label}: invalid mode for {source}: {mode}")
        size = row.get("size")
        if not isinstance(size, int) or isinstance(size, bool) or size < 0 or size > MAX_FILE_SIZE:
            errors.append(f"{label}: invalid size for {source}: {size}")
            size = 0
        total_size += size
        digest = row.get("sha256")
        if not isinstance(digest, str) or not HEX_PATTERN.fullmatch(digest):
            errors.append(f"{label}: invalid sha256 for {source}")
        install = row.get("install")
        if not isinstance(install, bool):
            errors.append(f"{label}: install must be boolean for {source}")
            install = False
        declared[source_key] = install

        path = product_file(product, source_key)
        if path is None:
            continue
        if path.is_symlink():
            errors.append(f"{label}: symlink forbidden: {source}")
            continue
        if not path.is_file():
            errors.append(f"{label}: declared source missing: {source}")
            continue
        actual_size = path.stat().st_size
        if isinstance(row.get("size"), int) and actual_size != row["size"]:
            errors.append(f"{label}: size mismatch: {source}")
        if isinstance(digest, str) and HEX_PATTERN.fullmatch(digest) and sha256(path) != digest:
            errors.append(f"{label}: sha256 mismatch: {source}")
        executable = bool(path.stat().st_mode & 0o111)
        if executable and mode != "0755":
            errors.append(f"{label}: executable source requires mode 0755: {source}")
        if mode == "0755":
            shebang = starts_with_shebang(path)
            if not executable or not shebang:
                errors.append(f"{label}: mode 0755 is only valid for executable scripts: {source}")

    if total_size > MAX_PRODUCT_SIZE:
        errors.append(f"{label}: declared product exceeds {MAX_PRODUCT_SIZE} bytes")

    manifest_name = str(entry.get("manifest", ""))
    for path in product.rglob("*"):
        relative = path.relative_to(product).as_posix()
        if path.is_symlink():
            errors.append(f"{label}: symlink forbidden: {relative}")
        elif (
            path.is_file()
            and relative != manifest_name
            and relative not in declared
            and (not is_documentation(relative) or is_executable_code(path))
        ):
            errors.append(f"{label}: undeclared payload {relative}")

    screenshots = entry.get("screenshots")
    media = [entry.get("preview")] + (screenshots if isinstance(screenshots, list) else [])
    for index, value in enumerate(media):
        kind = "preview" if index == 0 else "screenshot"
        if not safe_relative(value):
            errors.append(f"{label}: {kind} escapes product root: {value}")
            continue
        path = product_file(product, value)
        if path is None or not path.is_file() or path.is_symlink():
            errors.append(f"{label}: {kind} missing: {value}")
            continue
        if value not in declared:
            errors.append(f"{label}: {kind} is undeclared: {value}")
        elif declared[value]:
            errors.append(f"{label}: {kind} must use install false: {value}")
        if require_media:
            issue = media_error(path, label)
            if issue:
                errors.append(issue.replace("preview", kind, 1))


def package_manager_gate_error(value: dict) -> str | None:
    """An entry or bundle part may name the package managers it runs on, with the
    sentence the Store shows everywhere else. None when absent or sound."""
    managers = value.get("packageManagers")
    reason = value.get("packageManagersReason")
    if managers is None:
        return None if reason is None else "packageManagersReason needs packageManagers"
    if (
        not isinstance(managers, list)
        or not managers
        or not all(isinstance(manager, str) and manager in PACKAGE_MANAGERS for manager in managers)
        or len(set(managers)) != len(managers)
    ):
        return f"packageManagers must list distinct values from {', '.join(PACKAGE_MANAGERS)}"
    if not isinstance(reason, str) or not reason.strip():
        return "packageManagers needs a packageManagersReason sentence"
    return None


def normalized_bundle_components(manifest: object) -> list[dict] | None:
    if not isinstance(manifest, dict) or not isinstance(manifest.get("items"), list):
        return None
    components = []
    for item in manifest["items"]:
        if not isinstance(item, dict):
            return None
        name = item.get("name")
        component = {
            "type": item.get("type"),
            "name": name,
            "detect": item.get("detect") or name,
            "tier": item.get("tier") or "core",
        }
        # `group` is optional and only emitted when set, so an ungrouped bundle
        # keeps its existing components unchanged.
        group = item.get("group")
        if group:
            component["group"] = group
        component["interactive"] = item.get("interactive", False)
        component["summary"] = item.get("summary") or ""
        # A part limited to some editions carries its gate inline too, so the
        # Store can grey it out without fetching bundle.json.
        for field in ("packageManagers", "packageManagersReason"):
            if field in item:
                component[field] = item[field]
        if (
            not all(isinstance(component[field], str) and component[field]
                    for field in ("type", "name", "detect", "tier"))
            or type(component["interactive"]) is not bool
            or not isinstance(component["summary"], str)
            or not isinstance(component.get("group", ""), str)
        ):
            return None
        components.append(component)
    return components


def validate_bundle_components(entry: dict, manifest: object, errors: list[str]) -> None:
    label = f"bundles/{entry.get('id', '?')}"
    expected = normalized_bundle_components(manifest)
    if expected is None or entry.get("components") != expected:
        errors.append(f"{label}: components do not match manifest items")
        return
    for item in manifest["items"]:
        gate = package_manager_gate_error(item)
        if gate:
            errors.append(f"{label}: part {item.get('name')}: {gate}")


def bundle_package_lanes(root: Path, entries: list) -> dict[str, set[str]]:
    """Every bundle package item, mapped to the ids of the bundles listing it."""
    lanes: dict[str, set[str]] = {}
    for entry in entries:
        if not isinstance(entry, dict) or not safe_relative(entry.get("path")) or not safe_relative(entry.get("manifest")):
            continue
        product = root.joinpath(*PurePosixPath(str(entry["path"])).parts)
        manifest_path = product_file(product, entry["manifest"])
        if manifest_path is None or not manifest_path.is_file():
            continue
        try:
            manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
        except (OSError, ValueError):
            continue
        items = manifest.get("items") if isinstance(manifest, dict) else None
        for item in items if isinstance(items, list) else []:
            if isinstance(item, dict) and item.get("type") == "package" and isinstance(item.get("name"), str):
                lanes.setdefault(item["name"], set()).add(str(entry.get("id")))
    return lanes


def validate_bundle_tables(root: Path, entries: list, errors: list[str]) -> None:
    """bundles/packages/<edition>.tsv: one sorted row per bundle package, each a
    native name list or `-` with the sentence a user reads."""
    lanes = bundle_package_lanes(root, entries)
    for edition in EDITION_TABLES:
        relative = f"bundles/packages/{edition}.tsv"
        if contains_symlink(root, relative):
            errors.append(f"{relative}: symlink forbidden")
            continue
        path = root / "bundles" / "packages" / f"{edition}.tsv"
        if not path.is_file():
            if lanes:
                errors.append(f"{relative}: missing; every bundle package needs a row")
            continue
        lines = path.read_text(encoding="utf-8").split("\n")
        if lines and lines[-1] == "":
            lines.pop()
        if not lines or lines[0] != f"arch\t{edition}\tlanes\tnotes":
            errors.append(f"{relative}: header must be arch, {edition}, lanes, notes (tab-separated)")
            continue
        previous = b""
        rows = set()
        for number, line in enumerate(lines[1:], start=2):
            where = f"{relative}:{number}"
            fields = line.split("\t")
            if len(fields) != 4:
                errors.append(f"{where}: expected four tab-separated columns")
                continue
            arch, native, row_lanes, notes = fields
            if arch.encode() <= previous:
                errors.append(f"{where}: rows must be sorted by Arch name, once each")
            previous = arch.encode()
            rows.add(arch)
            if arch not in lanes:
                errors.append(f"{where}: {arch} is not a package in any bundle")
                continue
            expected_lanes = ",".join(sorted(lanes[arch]))
            if row_lanes != expected_lanes:
                errors.append(f"{where}: lanes must be {expected_lanes}")
            if native == "-":
                if not notes.strip() or notes.startswith("repo="):
                    errors.append(f"{where}: a - row needs the sentence a user reads")
                continue
            if not all(NATIVE_PACKAGE_PATTERN.fullmatch(name) for name in native.split(" ")):
                errors.append(f"{where}: invalid package names: {native}")
            repositories = notes.removeprefix("repo=").split(",") if notes.startswith("repo=") else None
            if notes and (
                repositories is None
                or len(set(repositories)) != len(repositories)
                or not set(repositories) <= TABLE_REPOSITORIES[edition]
            ):
                errors.append(f"{where}: invalid repository note: {notes}")
        for name in sorted(set(lanes) - rows):
            errors.append(f"{relative}: {name} has no row")


def validate_ryotunes_skin(entry: dict, product: Path, manifest: object, errors: list[str]) -> None:
    """A ryotunes-skins product carries a Ryotunes skin.json (format 1). Check it
    parses, is self-consistent with the folder and the registry entry, and that
    the manifest installs skin.json but not the preview."""
    label = f"ryotunes-skins/{entry.get('id', '?')}"
    skin_path = product / "skin.json"
    if not skin_path.is_file() or skin_path.is_symlink():
        errors.append(f"{label}: skin.json missing")
        return
    skin = load_json(skin_path, errors, f"{label}: skin.json")
    if skin is LOAD_FAILED:
        return
    if not isinstance(skin, dict):
        errors.append(f"{label}: skin.json must be an object")
        return

    if type(skin.get("format")) is not int or skin.get("format") != 1:
        errors.append(f"{label}: skin.json format must be 1")
    if skin.get("id") != product.name:
        errors.append(f"{label}: skin.json id must equal the folder name {product.name!r}")

    modes = skin.get("modes")
    if not isinstance(modes, dict) or not modes:
        errors.append(f"{label}: skin.json needs a non-empty modes object")
        modes = {}

    def valid_colour(value: object) -> bool:
        return isinstance(value, str) and bool(COLOR_PATTERN.fullmatch(value))

    if not any(
        isinstance(mode, dict) and valid_colour(mode.get("paper")) and valid_colour(mode.get("ink"))
        for mode in modes.values()
    ):
        errors.append(f"{label}: skin.json needs a mode with paper and ink as #rrggbb")

    default_mode = modes.get(skin.get("default", "dark")) if isinstance(modes, dict) else None
    if not isinstance(default_mode, dict):
        default_mode = next((m for m in modes.values() if isinstance(m, dict)), None)
    if isinstance(default_mode, dict):
        sun, paper = default_mode.get("sun"), default_mode.get("paper")
        accent, surface = entry.get("accent"), entry.get("surface")
        if valid_colour(sun) and valid_colour(accent) and accent.lower() != sun.lower():
            errors.append(f"{label}: registry accent must equal the default mode's sun")
        if valid_colour(paper) and valid_colour(surface) and surface.lower() != paper.lower():
            errors.append(f"{label}: registry surface must equal the default mode's paper")

    installs = {
        row["source"]: row.get("install")
        for row in (manifest.get("files") if isinstance(manifest, dict) else [])
        if isinstance(row, dict) and isinstance(row.get("source"), str)
    }
    if installs.get("skin.json") is not True:
        errors.append(f"{label}: skin.json must be declared with install true")
    preview = entry.get("preview")
    if isinstance(preview, str) and installs.get(preview) is not False:
        errors.append(f"{label}: preview must be declared with install false")


def validate_folder_product(category: str, entry: dict, manifest: object, errors: list[str]) -> None:
    """A folder product installs whole into ryoku/<category>/<id> and runs from
    its entry, so the manifest must install that entry (and the preview when it
    ships one), and the id must not be one the shell ships."""
    product = FOLDER_PRODUCTS[category]
    product_id = entry.get("id", "?")
    label = f"{category}/{product_id}"
    if product_id in product.reserved:
        errors.append(f"{label}: id is taken by a {product.noun} Ryoku ships")
    if not isinstance(manifest, dict):
        return
    if manifest.get("destination") != f"ryoku/{category}/{product_id}":
        errors.append(f"{label}: manifest destination must be ryoku/{category}/{product_id}")
    installs = {
        row["source"]: row.get("install")
        for row in (manifest.get("files") if isinstance(manifest.get("files"), list) else [])
        if isinstance(row, dict) and isinstance(row.get("source"), str)
    }
    if installs.get(product.entry) is not True:
        errors.append(f"{label}: {product.entry} must be declared with install true")
    if product.preview and product.preview in installs and installs[product.preview] is not True:
        errors.append(f"{label}: {product.preview} must be declared with install true")


def strip_jsonc(text: str) -> str:
    """fastfetch reads JSONC: drop comments and trailing commas outside strings
    so the json module can parse it."""
    out: list[str] = []
    commas: list[int] = []
    index, length, in_string = 0, len(text), False
    while index < length:
        char = text[index]
        if in_string:
            out.append(char)
            if char == "\\" and index + 1 < length:
                out.append(text[index + 1])
                index += 2
                continue
            in_string = char != '"'
            index += 1
        elif text.startswith("//", index):
            end = text.find("\n", index)
            index = length if end < 0 else end
        elif text.startswith("/*", index):
            end = text.find("*/", index + 2)
            index = length if end < 0 else end + 2
        else:
            if char == ",":
                commas.append(len(out))
            in_string = char == '"'
            out.append(char)
            index += 1
    joined = "".join(out)
    for at in commas:
        if joined[at + 1:].lstrip()[:1] in ("]", "}"):
            out[at] = ""
    return "".join(out)


def config_strings(value: object) -> Iterable[str]:
    if isinstance(value, str):
        yield value
    elif isinstance(value, dict):
        for key, item in value.items():
            yield key
            yield from config_strings(item)
    elif isinstance(value, list):
        for item in value:
            yield from config_strings(item)


def validate_fastfetch_renderer(
    entry: dict, product: Path, manifest: object, renderer: str, errors: list[str]
) -> None:
    """A renderer is an executable inside the preset's own product folder.
    ryoku-fastfetch runs it in place of fastfetch, so it must be installed,
    executable, and unable to reach another product."""
    label = f"fastfetch/{entry.get('id', '?')}"
    product_id = str(entry.get("id", ""))
    parts = PurePosixPath(renderer).parts
    if not RENDERER_TARGET.fullmatch(renderer) or ".." in parts:
        errors.append(
            f"{label}: renderer must be <product-id>/<executable> inside its own product: {renderer}"
        )
        return
    owner, _, relative = renderer.partition("/")
    if owner != product_id:
        errors.append(f"{label}: renderer must stay inside {product_id}/, not {owner}/")
        return
    target = product.joinpath(*PurePosixPath(relative).parts)
    if not target.is_file() or target.is_symlink():
        errors.append(f"{label}: renderer target missing: {renderer}")
        return
    if not target.stat().st_mode & 0o111:
        errors.append(f"{label}: renderer target must be executable: {renderer}")
        return
    rows = manifest.get("files") if isinstance(manifest, dict) else None
    row = next(
        (
            item
            for item in rows or []
            if isinstance(item, dict) and item.get("destination") == relative
        ),
        None,
    )
    if row is None or row.get("install") is not True:
        errors.append(f"{label}: renderer target must be installed: {renderer}")


def validate_fastfetch_preset(
    entry: dict, product: Path, manifest: object, errors: list[str]
) -> None:
    """A preset runs on whichever Ryoku edition the user has (Arch, CachyOS,
    Fedora or Void), so its logo, package counts and glyphs follow that system
    instead of naming one."""
    label = f"fastfetch/{entry.get('id', '?')}"
    config_path = product / "config.jsonc"
    if not config_path.is_file() or config_path.is_symlink():
        errors.append(f"{label}: config.jsonc missing")
        return
    try:
        raw = config_path.read_text(encoding="utf-8")
        config = json.loads(strip_jsonc(raw))
    except (UnicodeDecodeError, ValueError) as error:
        errors.append(f"{label}: config.jsonc does not parse: {error}")
        return
    if not isinstance(config, dict):
        errors.append(f"{label}: config.jsonc must be an object")
        return

    logo = config.get("logo")
    kind, source = "auto", logo
    if isinstance(logo, dict):
        kind, source = logo.get("type", "auto"), logo.get("source")
    if (
        isinstance(source, str) and source not in ("", "none")
        and (kind in ("builtin", "small") or (kind == "auto" and "/" not in source))
    ):
        errors.append(
            f"{label}: logo names the built-in {source!r} logo; leave source out so each edition draws its own"
        )

    texts = list(config_strings(config))
    for text in texts:
        named = set(PACKAGE_COUNT_PATTERN.findall(text))
        if named and named != PACKAGE_COUNTS:
            errors.append(
                f"{label}: a package count names only {', '.join(sorted(named))}; "
                "name pacman, rpm and xbps together or keep the default format"
            )
            break
    marks = sorted({ord(char) for text in texts for char in text if ord(char) in DISTRIBUTION_MARKS})
    if marks:
        errors.append(
            f"{label}: draws one system's own mark ({', '.join(f'U+{mark:04X}' for mark in marks)}); "
            "use Tux (U+F31A) or a neutral glyph"
        )

    declared = RENDERER_LINE.findall(raw)
    renderers = RENDERER_PATTERN.findall(raw)
    if len(declared) > 1:
        errors.append(f"{label}: declare one ryoku:renderer line, not {len(declared)}")
    elif declared and not renderers:
        errors.append(
            f"{label}: renderer line must read `// ryoku:renderer <product-id>/<executable>`"
        )
    elif renderers:
        validate_fastfetch_renderer(entry, product, manifest, renderers[0], errors)


def validate_entry(category: str, entry: object, root: Path, errors: list[str], require_media: bool) -> None:
    if not isinstance(entry, dict):
        errors.append(f"{category}/?: registry entry must be an object")
        return
    product_id = entry.get("id", "?")
    label = f"{category}/{product_id}"
    for field in REQUIRED_ENTRY_FIELDS:
        if field not in entry:
            errors.append(f"{label}: missing registry field {field}")
    for field in TEXT_FIELDS:
        if field in entry and (not isinstance(entry[field], str) or not entry[field]):
            errors.append(f"{label}: registry field {field} must be a non-empty string")
    if isinstance(product_id, str) and not ID_PATTERN.fullmatch(product_id):
        errors.append(f"{label}: invalid id")
    if "tags" in entry and (not isinstance(entry["tags"], list) or not all(isinstance(tag, str) and tag for tag in entry["tags"])):
        errors.append(f"{label}: tags must be non-empty strings")
    if "screenshots" in entry and (not isinstance(entry["screenshots"], list) or not all(isinstance(value, str) and value for value in entry["screenshots"])):
        errors.append(f"{label}: screenshots must be non-empty strings")
    for field in ("accent", "surface"):
        value = entry.get(field)
        if isinstance(value, str) and value and not COLOR_PATTERN.fullmatch(value):
            errors.append(f"{label}: {field} must be a six-digit hex colour")

    upstream = entry.get("upstream")
    if isinstance(upstream, str) and upstream:
        control = any(ord(char) < 0x20 or ord(char) == 0x7f for char in upstream)
        if control or not UPSTREAM_PATTERN.fullmatch(upstream):
            errors.append(f"{label}: upstream must be an https project URL with a host and a path")
    discord = entry.get("discord")
    if discord is not None and (not isinstance(discord, str) or not DISCORD_PATTERN.fullmatch(discord)):
        errors.append(f"{label}: discord must be a discord.gg or discord.com/invite invite link")
    gate = package_manager_gate_error(entry)
    if gate:
        errors.append(f"{label}: {gate}")

    path_value = entry.get("path")
    if not safe_relative(path_value):
        errors.append(f"{label}: product path must be relative: {path_value}")
        return
    product_relative = str(path_value)
    if contains_symlink(root, product_relative):
        errors.append(f"{label}: product path contains a symlink: {path_value}")
        return
    product = root.joinpath(*PurePosixPath(product_relative).parts)
    try:
        product.resolve().relative_to(root)
    except (OSError, ValueError):
        errors.append(f"{label}: product path escapes catalogue root: {path_value}")
        return
    if not product.is_dir():
        errors.append(f"{label}: product path missing: {path_value}")
        return

    manifest_value = entry.get("manifest")
    if not safe_relative(manifest_value):
        errors.append(f"{label}: manifest path must be relative: {manifest_value}")
        return
    manifest_path = product_file(product, manifest_value)
    if manifest_path is None or not manifest_path.is_file() or manifest_path.is_symlink():
        errors.append(f"{label}: manifest missing: {manifest_value}")
        return
    expected_hash = entry.get("manifestSha256")
    if not isinstance(expected_hash, str) or not HEX_PATTERN.fullmatch(expected_hash):
        errors.append(f"{label}: manifestSha256 must be lowercase SHA-256")
        return
    if sha256(manifest_path) != expected_hash:
        errors.append(f"{label}: manifest hash mismatch")
        return
    manifest = load_json(manifest_path, errors, f"{label}: manifest")
    if manifest is not LOAD_FAILED:
        validate_manifest(category, entry, product, manifest, errors, require_media)
        if category == "bundles":
            validate_bundle_components(entry, manifest, errors)
        elif category == "ryotunes-skins":
            validate_ryotunes_skin(entry, product, manifest, errors)
        elif category in FOLDER_PRODUCTS:
            validate_folder_product(category, entry, manifest, errors)
        elif category == "fastfetch":
            validate_fastfetch_preset(entry, product, manifest, errors)


def validate_tree(
    root: Path,
    categories: Iterable[str] | None = None,
    require_media: bool = False,
) -> list[str]:
    root = Path(root).resolve()
    selected = tuple(categories) if categories is not None else CATEGORIES
    errors: list[str] = []
    unknown = sorted(set(selected) - set(CATEGORIES))
    for category in unknown:
        errors.append(f"unknown category: {category}")
    for category in selected:
        if category not in CATEGORIES:
            continue
        registry_path = root / category / "registry.json"
        if contains_symlink(root, f"{category}/registry.json"):
            errors.append(f"{category}/registry.json: symlink forbidden")
            continue
        registry = load_json(registry_path, errors, f"{category}/registry.json")
        if registry is LOAD_FAILED:
            continue
        if not isinstance(registry, dict):
            errors.append(f"{category}/registry.json: root must be an object")
            continue
        if set(registry) != {"schema", category}:
            errors.append(f"{category}/registry.json: invalid registry envelope")
            continue
        if type(registry.get("schema")) is not int or registry["schema"] != 1:
            errors.append(f"{category}/registry.json: unsupported schema")
            continue
        entries = registry.get(category)
        if not isinstance(entries, list):
            errors.append(f"{category}/registry.json: {category} must be an array")
            continue
        seen: set[str] = set()
        for entry in entries:
            product_id = entry.get("id") if isinstance(entry, dict) else "?"
            if isinstance(product_id, str) and product_id in seen:
                errors.append(f"{category}/{product_id}: duplicate id")
                continue
            if isinstance(product_id, str):
                seen.add(product_id)
            validate_entry(category, entry, root, errors, require_media)
        if category == "bundles":
            validate_bundle_tables(root, entries, errors)
    return errors


def parse_categories(value: str) -> tuple[str, ...]:
    return tuple(category.strip() for category in value.split(",") if category.strip())


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Validate the complete RyoStore product catalogue")
    parser.add_argument("--root", type=Path, default=Path("."))
    parser.add_argument("--categories", type=parse_categories)
    parser.add_argument("--require-media", action="store_true")
    args = parser.parse_args(argv)
    selected = args.categories if args.categories is not None else CATEGORIES
    errors = validate_tree(args.root, selected, args.require_media)
    if errors:
        for error in errors:
            print(f"FAIL: {error}", file=sys.stderr)
        print(f"{len(errors)} store catalogue error(s) found", file=sys.stderr)
        return 1
    print(f"store catalogue OK: {len(selected)} categories validated")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
