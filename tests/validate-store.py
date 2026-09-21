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
    "rices", "lockscreens", "barstyles", "fastfetch", "plugins", "bundles",
    "decors", "launcher-images", "fastfetch-emblems", "ryotunes-skins",
)
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
    expected = normalized_bundle_components(manifest)
    if expected is None or entry.get("components") != expected:
        errors.append(f"bundles/{entry.get('id', '?')}: components do not match manifest items")


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
