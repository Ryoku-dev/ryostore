#!/usr/bin/env python3
"""Import curated qylock lockscreen themes into the RyoStore catalogue.

Previews are pulled straight from qylock's own promo assets (Assets/<name>.gif)
at a pinned commit - no local rendering. Three phases keep it reproducible:

  fetch  - for each curated theme pull the runtime payload (Main.qml, theme.conf,
           metadata.desktop, font/*, background, extra qml/png) into
           lockscreens/<id>/content/, the repo LICENSE + a PROVENANCE.txt at the
           product root, the promo gif into assets/preview.gif, and - when the
           theme ships an image background (bg.png / background.png) - a copy of
           it as assets/shot-1.<ext>.

  compress - re-encode any theme .mp4 wider than 1080p or over 12 MB in place to
           <=1080p H.264 (CRF 23), so animated backgrounds stay lean; a note is
           appended to PROVENANCE.txt. Idempotent: already-lean clips are skipped.

  build  - write each manifest.json (real byte sizes + sha256; preview.gif and
           screenshots install:false; content/* + LICENSE + PROVENANCE
           install:true; destination qylock/themes/<id>) and rewrite
           lockscreens/registry.json with matching manifestSha256 values.
           accent/surface are sampled from the gif's first frame.

Usage:
    tools/import-qylock.py fetch      # pull payloads + gifs for every curated id
    tools/import-qylock.py compress   # re-encode oversized video to <=1080p
    tools/import-qylock.py build      # assemble manifests + registry
    tools/import-qylock.py all        # fetch, compress, then build
    tools/import-qylock.py ids        # print curated ids
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import urllib.request
import urllib.parse
from pathlib import Path

REPO = "Darkkal44/qylock"
COMMIT = "f6561e2ceae33f26e5e660742a5df2f725cbe514"
UPSTREAM_URL = "https://github.com/Darkkal44/qylock"
RAW = f"https://raw.githubusercontent.com/{REPO}/{COMMIT}"
TREE_API = f"https://api.github.com/repos/{REPO}/git/trees/{COMMIT}?recursive=1"

ROOT = Path(__file__).resolve().parent.parent
CATEGORY = "lockscreens"
CATEGORY_DIR = ROOT / CATEGORY
VERSION = "1.0.0"

SKIP_NAMES = {".gitkeep"}
IMAGE_EXTS = {".png", ".jpg", ".jpeg", ".webp", ".gif"}
BG_RE = re.compile(r"^(bg|background)\.(png|jpg|jpeg|webp|gif)$", re.IGNORECASE)

# Re-encode oversized theme video to a lean lockscreen background: cap width at
# 1080p and shed absurd source bitrates via CRF. Files already within the limits
# are left untouched, so `compress` is idempotent and safe to re-run.
VIDEO_MAX_WIDTH = 1920
VIDEO_MAX_HEIGHT = 1080
VIDEO_MAX_BYTES = 12_000_000
VIDEO_NOTE = (
    "\nVideo note: the .mp4 background(s) were re-encoded to <=1080p H.264 "
    "(CRF 23) from the upstream source to keep the catalogue lean; every other "
    "byte is upstream-verbatim.\n"
)

# Promo gif whose normalised name does not equal the theme dir's normalised name.
GIF_ALIASES = {"windows-7": "win7", "last-of-us": "the_last_of_us"}

# Curated set: themes that have BOTH a themes/<upstream> dir AND an Assets gif.
# `upstream` is the qylock theme directory; `id` is the kebab-case catalogue id.
CURATED = [
    dict(id="field", upstream="field", name="Field",
         summary="An open pasture under soft light with a feather-light clock.",
         description="A serene qylock scene: a wide field, a thin Orbitron clock, and a quiet amber login tucked into the corner.",
         tags=["scenic", "minimal", "calm"]),
    dict(id="girl-coffee", upstream="girl-coffee", name="Coffee Break",
         summary="A cosy hand-drawn morning with a warm mug in hand.",
         description="A lo-fi illustrated character taking a coffee break, paired with the rounded Itim typeface and a soft, unobtrusive login.",
         tags=["anime", "cozy", "illustrated"]),
    dict(id="girl-pillow", upstream="girl-pillow", name="Lazy Sunday",
         summary="A soft illustrated scene, curled up and half awake.",
         description="A relaxed lo-fi illustration with the rounded Itim font and a gentle right-aligned login - quiet, warm, and unhurried.",
         tags=["anime", "cozy", "illustrated"]),
    dict(id="man-bicycle", upstream="man-bicycle", name="Evening Ride",
         summary="A lone cyclist against a wide illustrated sky.",
         description="A cinematic lo-fi ride with the Itim typeface and a minimal login tucked into the frame.",
         tags=["scenic", "illustrated", "calm"]),
    dict(id="material-you", upstream="material-you", name="Material You",
         summary="Google's Material You language, clean and adaptive.",
         description="A crisp Material You lock with the Google Sans typeface, rounded surfaces, and a tidy centred login.",
         tags=["material", "clean", "modern"]),
    dict(id="material-you-dark", upstream="material-you-dark", name="Material You Dark",
         summary="The Material You language in a deep, quiet dark palette.",
         description="The dark sibling of the Material You lock: the Google Sans typeface and rounded surfaces over a low-light palette, with a tidy centred login.",
         tags=["material", "dark", "clean"]),
    dict(id="minecraft", upstream="minecraft", name="Minecraft Menu",
         summary="The blocky main-menu look, splash text and all.",
         description="A nostalgic Minecraft title-screen lock: stone-button widgets, a random yellow splash line, and the classic logo.",
         tags=["game", "retro", "playful"]),
    dict(id="nier-automata", upstream="nier-automata", name="NieR: Automata",
         summary="The stark beige-and-black UI of YoRHa.",
         description="A faithful NieR: Automata lock with bordered YoRHa buttons, the signature muted palette, and a precise login.",
         tags=["game", "minimal", "monochrome"]),
    dict(id="ninja-gaiden", upstream="ninja_gaiden", name="Ninja Gaiden",
         summary="High-contrast action styling with the Tektur face.",
         description="A sharp Ninja Gaiden lock: bold Tektur type, a dark cinematic background, and a decisive login.",
         tags=["game", "bold", "dark"]),
    dict(id="women-umbrella", upstream="women-umbrella", name="Rainy Walk",
         summary="An illustrated figure under an umbrella in gentle rain.",
         description="A moody lo-fi illustration of a walk in the rain, with a calm, understated login.",
         tags=["illustrated", "rain", "calm"]),
    dict(id="windows-7", upstream="windows_7", name="Windows 7",
         summary="The nostalgic Windows 7 welcome screen.",
         description="A throwback Windows 7 lock: a round avatar, a glassy credential field, and the familiar blue welcome mood.",
         tags=["os", "retro", "nostalgic"]),
    dict(id="nothing", upstream="nothing", name="Nothing OS",
         summary="Dot-matrix minimalism in red and black.",
         description="A Nothing-inspired lock: NDot dot-matrix numerals, twin rounded widgets, and a bright, airy backdrop.",
         tags=["minimal", "monochrome", "modern"]),
    dict(id="terraria", upstream="terraria", name="Terraria",
         summary="The Terraria main menu, pixel logo and all.",
         description="A Terraria title-screen lock with the pixel logo, a tree-lined horizon, and wood-panel buttons.",
         tags=["game", "pixel", "retro"]),
    dict(id="pixel-sakura", upstream="pixel-sakura", name="Pixel Sakura",
         summary="A pixel-art courtyard under drifting cherry blossom.",
         description="An animated pixel-art scene of falling sakura petals, warm and unhurried, with a tidy login.",
         tags=["pixel", "anime", "calm"]),
    dict(id="pixel-cyberpunk", upstream="pixel-cyberpunk", name="Pixel Cyberpunk",
         summary="A neon pixel-art cityscape humming with rain and signage.",
         description="An animated pixel-art cyberpunk street, all neon reflections and drizzle, with a crisp login.",
         tags=["pixel", "cyberpunk", "neon"]),
    dict(id="pixel-waterfall", upstream="pixel-waterfall", name="Pixel Waterfall",
         summary="A tranquil pixel-art waterfall in a mossy glen.",
         description="An animated pixel-art waterfall scene, cool and green, with a calm minimal login.",
         tags=["pixel", "nature", "calm"]),
    dict(id="star-rail", upstream="star-rail", name="Star Rail",
         summary="An astral, animated backdrop for the trailblazers.",
         description="A Honkai: Star Rail inspired lock with an animated cosmic backdrop and a clean, modern login.",
         tags=["game", "anime", "space"]),
    dict(id="winter", upstream="winter", name="Winter",
         summary="A quiet, animated snowfall in cold blue.",
         description="A calm winter lock: soft, drifting snow over a cold-blue scene with an understated login.",
         tags=["scenic", "winter", "calm"]),
    dict(id="r1999-2", upstream="R1999_2", name="Reverse: 1999",
         summary="Vintage flourish with an animated period backdrop.",
         description="A Reverse: 1999 inspired lock with an animated vintage backdrop, a period logo, and an elegant login.",
         tags=["game", "anime", "vintage"]),
    dict(id="genshin", upstream="Genshin", name="Genshin Impact",
         summary="A moonlit abyss of drifting pillars in deep blue.",
         description="A Genshin Impact inspired lock: towering ruins beneath a pale moon, slow-drifting clouds, and a clean login on the descending path.",
         tags=["game", "anime", "night"]),
    dict(id="r1999-1", upstream="R1999_1", name="Reverse: 1999",
         summary="A pensive period portrait bathed in soft sepia light.",
         description="A Reverse: 1999 inspired lock centred on a wistful character portrait in warm vintage tones, with an understated login.",
         tags=["game", "anime", "vintage"]),
    dict(id="dog-samurai", upstream="dog-samurai", name="Dog Samurai",
         summary="A painterly samurai hound under drifting red petals.",
         description="A cinematic video lock: a straw-hatted samurai dog with a sheathed katana as crimson petals fall, paired with a bold clock and a minimal login.",
         tags=["samurai", "painterly", "cinematic"]),
    dict(id="enfield", upstream="enfield", name="Enfield",
         summary="Golden hour spilling through a plant-framed window.",
         description="A warm, atmospheric lock: late sun pours past ivy and a weathered window frame, with a quiet login.",
         tags=["cozy", "warm", "scenic"]),
    dict(id="forest", upstream="forest", name="Forest",
         summary="Sunbeams pouring through a misty autumn canopy.",
         description="A tranquil video lock: light rays drift over an aerial autumn forest wrapped in fog, with a soft clock and an unobtrusive login.",
         tags=["scenic", "nature", "calm"]),
    dict(id="last-of-us", upstream="last-of-us", name="The Last of Us",
         summary="A lone blossom tree adrift in cold grey mist.",
         description="A The Last of Us inspired lock: a solitary cherry tree on a rocky outcrop among fog-veiled cliffs, with a spare, moody login.",
         tags=["game", "scenic", "moody"]),
    dict(id="osu", upstream="osu", name="osu!",
         summary="The osu! rhythm game, tap-circles and all.",
         description="An osu! inspired lock with difficulty menus, neon tap-circles, and a playful, score-driven login.",
         tags=["game", "rhythm", "playful"]),
    dict(id="osumania", upstream="osumania", name="osu!mania",
         summary="A four-key note highway glowing in neon green.",
         description="An osu!mania inspired lock: vertical scrolling notes, key-binding widgets, and PERFECT combos over a dark stage.",
         tags=["game", "rhythm", "neon"]),
    dict(id="pixel-coffee", upstream="pixel-coffee", name="Pixel Coffee",
         summary="A warm pixel cafe glowing after dark.",
         description="A cosy pixel-art lock: amber lamps over a late-night cafe, city lights through the window, and a tidy login.",
         tags=["pixel", "cozy", "night"]),
    dict(id="pixel-dusk-city", upstream="pixel-dusk-city", name="Pixel Dusk City",
         summary="A red-lit pixel skyline smouldering at dusk.",
         description="A pixel-art lock: a silhouetted city under a burning dusk sky, framed by dark leaves and tangled wires, with a minimal login.",
         tags=["pixel", "city", "dusk"]),
    dict(id="pixel-emerald", upstream="pixel-emerald", name="Pixel Emerald",
         summary="A seaside cycling route in bright pixel green.",
         description="A Pokemon inspired pixel lock: a cyclist on a fenced coastal path amid lush fields and creatures, with a cheerful login.",
         tags=["pixel", "game", "nostalgic"]),
    dict(id="pixel-hollowknight", upstream="pixel-hollowknight", name="Pixel Hollow Knight",
         summary="A horned knight silhouetted against embered dark.",
         description="A Hollow Knight inspired pixel lock: a pale-horned figure above drifting orange embers in the deep, with a stark login.",
         tags=["game", "pixel", "dark"]),
    dict(id="pixel-munchlax", upstream="pixel-munchlax", name="Pixel Munchlax",
         summary="A little companion on a grassy hill under summer clouds.",
         description="A bright pixel-art lock: a small creature resting on green grass beneath towering white clouds, with a clean login.",
         tags=["pixel", "cute", "calm"]),
    dict(id="pixel-night-city", upstream="pixel-night-city", name="Pixel Night City",
         summary="A glittering pixel skyline humming after dark.",
         description="A pixel-art lock: dense neon-lit towers over shadowed rooftops, cool and electric, with a crisp login.",
         tags=["pixel", "city", "night"]),
    dict(id="pixel-rainyroom", upstream="pixel-rainyroom", name="Pixel Rainy Room",
         summary="A rainy night at the desk, monitor aglow.",
         description="A lo-fi pixel lock: rain on the window and a blue monitor glow across a dim bedroom, with a quiet login.",
         tags=["pixel", "cozy", "rain"]),
    dict(id="pixel-skyscrapers", upstream="pixel-skyscrapers", name="Pixel Skyscrapers",
         summary="A pastel dawn washing over a layered skyline.",
         description="A pixel-art lock: peach-and-mauve skies and a soft sun behind stacked skyscrapers, with a calm login.",
         tags=["pixel", "city", "pastel"]),
    dict(id="sword", upstream="sword", name="Sword",
         summary="A lone blade planted in a misty grove.",
         description="A moody, near-monochrome lock: a katana standing point-down among blurred dark trees, with a spare login.",
         tags=["dark", "minimal", "cinematic"]),
    dict(id="wuwa", upstream="wuwa", name="Wuthering Waves",
         summary="A lone figure amid drifting ruins under pale light.",
         description="A Wuthering Waves inspired lock: a desolate greyscale expanse of floating debris cut by a single beam of light, with a modern login.",
         tags=["game", "anime", "monochrome"]),
]

CURATED_BY_ID = {t["id"]: t for t in CURATED}


def http_get(url: str) -> bytes:
    # Percent-encode unsafe chars (e.g. the space in osu's "A Glow.jpg") while
    # keeping URL structure and existing %xx escapes intact so urllib accepts it.
    url = urllib.parse.quote(url, safe="/:?#[]@!$&'()*+,;=~%")
    request = urllib.request.Request(url, headers={"User-Agent": "ryoku-import-qylock"})
    with urllib.request.urlopen(request, timeout=120) as response:
        return response.read()


def tree_blobs() -> list[str]:
    data = json.loads(http_get(TREE_API))
    if data.get("truncated"):
        raise SystemExit("qylock tree is truncated; per-theme fetch needed")
    return [item["path"] for item in data["tree"] if item["type"] == "blob"]


def normalise(name: str) -> str:
    return name.lower().replace("_", "-")


def resolve_gif(theme: dict, blobs: list[str]) -> str | None:
    """Map a theme to its Assets/<name>.gif by normalised name (case + _/-)."""
    gifs = [path for path in blobs if path.startswith("Assets/") and path.endswith(".gif")]
    alias = GIF_ALIASES.get(theme["id"])
    wanted = normalise(alias) if alias else normalise(theme["upstream"])
    for path in gifs:
        stem = normalise(Path(path).name[:-len(".gif")])
        if stem == wanted:
            return path
    return None


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def dump_json(value: object) -> bytes:
    return (json.dumps(value, indent=2, ensure_ascii=False) + "\n").encode("utf-8")


def selected(ids: list[str]) -> list[dict]:
    if not ids:
        return CURATED
    chosen = []
    for wanted in ids:
        if wanted not in CURATED_BY_ID:
            raise SystemExit(f"unknown theme id: {wanted}")
        chosen.append(CURATED_BY_ID[wanted])
    return chosen


def write_file(path: Path, data: bytes) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(data)
    os.chmod(path, 0o644)


# --------------------------------------------------------------------------- #
# fetch
# --------------------------------------------------------------------------- #
def provenance_text(theme: dict, gif_path: str) -> str:
    return (
        f"{theme['name']} qylock theme\n\n"
        f"Upstream: {UPSTREAM_URL}\n"
        f"Vendored from commit: {COMMIT}\n"
        f"Upstream theme: themes/{theme['upstream']}\n"
        f"Upstream preview: {gif_path}\n"
        f"Author: Darkkal44 and qylock contributors\n"
        f"License: GNU General Public License version 3; see LICENSE\n\n"
        "Ryoku ships assets/preview.gif (and assets/shot-*.<ext>) as catalogue "
        "media pulled directly from the qylock repository. These previews are "
        "not installed with the runtime payload.\n"
    )


def find_background(content: Path) -> Path | None:
    for child in sorted(content.iterdir()):
        if child.is_file() and BG_RE.match(child.name):
            return child
    return None


def fetch(ids: list[str]) -> None:
    themes = selected(ids)
    blobs = tree_blobs()
    license_bytes = http_get(f"{RAW}/LICENSE")
    for theme in themes:
        gif_path = resolve_gif(theme, blobs)
        if gif_path is None:
            print(f"SKIP {theme['id']}: no matching Assets gif")
            continue

        product = CATEGORY_DIR / theme["id"]
        content = product / "content"
        content.mkdir(parents=True, exist_ok=True)

        prefix = f"themes/{theme['upstream']}/"
        files = [path for path in blobs if path.startswith(prefix)]
        if not files:
            raise SystemExit(f"no upstream files for themes/{theme['upstream']}")
        kept = 0
        for path in files:
            rel = path[len(prefix):]
            if Path(rel).name in SKIP_NAMES:
                continue
            write_file(content / rel, http_get(f"{RAW}/{path}"))
            kept += 1

        write_file(product / "LICENSE", license_bytes)
        write_file(product / "PROVENANCE.txt", provenance_text(theme, gif_path).encode("utf-8"))

        # Promo gif -> preview.gif, pulled directly (no processing).
        write_file(product / "assets" / "preview.gif", http_get(f"{RAW}/{gif_path}"))

        # Image background -> shot-1 (same bytes already pulled into content).
        shot = "(none)"
        background = find_background(content)
        if background is not None and background.suffix.lower() in IMAGE_EXTS:
            shot_path = product / "assets" / f"shot-1{background.suffix.lower()}"
            write_file(shot_path, background.read_bytes())
            shot = shot_path.name
        else:
            # Any stale shot from a previous run must not linger as undeclared payload.
            for stale in (product / "assets").glob("shot-*"):
                stale.unlink()

        print(f"fetched {theme['id']}: {kept} content files, preview={Path(gif_path).name}, shot-1={shot}")


# --------------------------------------------------------------------------- #
# compress: shrink oversized theme video in place
# --------------------------------------------------------------------------- #
def video_dimensions(path: Path) -> tuple[int, int]:
    out = subprocess.run(
        ["ffprobe", "-v", "error", "-select_streams", "v:0",
         "-show_entries", "stream=width,height", "-of", "csv=p=0:s=x", str(path)],
        check=True, capture_output=True, text=True).stdout.strip()
    width, _, height = out.partition("x")
    return int(width), int(height)


def needs_compression(path: Path) -> bool:
    width, height = video_dimensions(path)
    return (width > VIDEO_MAX_WIDTH or height > VIDEO_MAX_HEIGHT
            or path.stat().st_size > VIDEO_MAX_BYTES)


def reencode(path: Path) -> bool:
    """Re-encode to <=1080p H.264; keep the result only when it is actually
    smaller. Returns True when the file was replaced."""
    tmp = path.with_name(f".{path.stem}.compress.mp4")
    subprocess.run(
        ["ffmpeg", "-v", "error", "-y", "-i", str(path),
         "-vf", f"scale='min({VIDEO_MAX_WIDTH},iw)':-2",
         "-c:v", "libx264", "-crf", "23", "-preset", "medium",
         "-movflags", "+faststart", "-an", str(tmp)],
        check=True)
    if tmp.stat().st_size < path.stat().st_size:
        os.replace(tmp, path)
        os.chmod(path, 0o644)
        return True
    tmp.unlink()
    return False


def note_reencode(product: Path) -> None:
    prov = product / "PROVENANCE.txt"
    if not prov.exists():
        return
    text = prov.read_text(encoding="utf-8")
    if "Video note:" not in text:
        prov.write_text(text + VIDEO_NOTE, encoding="utf-8")


def compress(ids: list[str]) -> None:
    for theme in selected(ids):
        product = CATEGORY_DIR / theme["id"]
        touched = 0
        for clip in sorted((product / "content").rglob("*.mp4")):
            if not needs_compression(clip):
                continue
            before = clip.stat().st_size
            if not reencode(clip):
                continue
            touched += 1
            print(f"compressed {theme['id']}/{clip.relative_to(product)}: "
                  f"{before // 1_000_000}M -> {clip.stat().st_size // 1_000_000}M")
        if touched:
            note_reencode(product)


# --------------------------------------------------------------------------- #
# build: manifest + registry + colours
# --------------------------------------------------------------------------- #
def magick(*args: str) -> str:
    return subprocess.run(["magick", *args], check=True, capture_output=True, text=True).stdout


def luminance(rgb: tuple[int, int, int]) -> float:
    r, g, b = rgb
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def saturation(rgb: tuple[int, int, int]) -> float:
    hi, lo = max(rgb), min(rgb)
    return 0.0 if hi == 0 else (hi - lo) / hi


def hexof(rgb: tuple[int, int, int]) -> str:
    return "#{:02x}{:02x}{:02x}".format(*rgb)


def histogram(path: Path, colors: int = 16) -> list[tuple[int, tuple[int, int, int]]]:
    # Composite every animation frame (-coalesce), stack them (-append) and
    # reduce once, so the palette reflects the whole clip rather than a single
    # (often dark fade-in) first frame.
    text = magick(str(path), "-coalesce", "-resize", "120x", "-append",
                  "-colors", str(colors), "-depth", "8", "-format", "%c",
                  "histogram:info:")
    out: list[tuple[int, tuple[int, int, int]]] = []
    for line in text.splitlines():
        line = line.strip()
        if not line or "(" not in line:
            continue
        count = int(line.split(":", 1)[0].strip())
        srgb = line[line.find("(") + 1:line.find(")")].split(",")
        rgb = tuple(int(float(component)) for component in srgb[:3])
        out.append((count, rgb))
    return out


def sample_colours(preview: Path) -> tuple[str, str]:
    """accent = most saturated prominent colour; surface = darkest colour."""
    bins = histogram(preview)
    if not bins:
        return "#cdc4ba", "#101010"
    surface = min(bins, key=lambda item: luminance(item[1]))[1]
    total = sum(count for count, _ in bins) or 1
    accent = max(bins, key=lambda item: saturation(item[1]) * (0.4 + 0.6 * item[0] / total))[1]
    if saturation(accent) < 0.12:
        accent = max(bins, key=lambda item: luminance(item[1]))[1]
    return hexof(accent), hexof(surface)


def declared_files(product: Path) -> list[dict]:
    rows = []
    for path in sorted(product.rglob("*")):
        if not path.is_file():
            continue
        rel = path.relative_to(product).as_posix()
        if rel == "manifest.json":
            continue
        if rel.startswith("assets/"):
            destination, install = Path(rel).name, False   # media installs nowhere
        elif rel.startswith("content/"):
            destination, install = rel[len("content/"):], True
        else:                                               # LICENSE, PROVENANCE.txt
            destination, install = rel, True
        data = path.read_bytes()
        rows.append({
            "source": rel, "destination": destination, "mode": "0644",
            "size": len(data), "sha256": sha256_bytes(data), "install": install,
        })

    def order(row: dict) -> tuple:
        source = row["source"]
        bucket = 0 if source in ("LICENSE", "PROVENANCE.txt") else 1 if source.startswith("assets/") else 2
        return (bucket, source)

    rows.sort(key=order)
    return rows


def build(ids: list[str]) -> None:
    themes = selected(ids)
    registry_path = CATEGORY_DIR / "registry.json"
    registry = json.loads(registry_path.read_text(encoding="utf-8"))
    entries = {entry["id"]: entry for entry in registry[CATEGORY]}

    for theme in themes:
        pid = theme["id"]
        product = CATEGORY_DIR / pid
        preview = product / "assets" / "preview.gif"
        if not preview.is_file():
            print(f"SKIP {pid}: no assets/preview.gif (run fetch first)")
            continue

        screenshots = ["assets/preview.gif"]
        shots = sorted((product / "assets").glob("shot-*"))
        screenshots += [f"assets/{shot.name}" for shot in shots]

        accent, surface = sample_colours(preview)

        files = declared_files(product)
        manifest = {
            "schema": 1, "id": pid, "category": CATEGORY, "version": VERSION,
            "destination": f"qylock/themes/{pid}", "files": files,
        }
        manifest_bytes = dump_json(manifest)
        write_file(product / "manifest.json", manifest_bytes)

        entries[pid] = {
            "id": pid, "name": theme["name"], "version": VERSION,
            "path": f"{CATEGORY}/{pid}", "author": "Darkkal44", "upstream": UPSTREAM_URL,
            "summary": theme["summary"], "description": theme["description"],
            "tags": list(theme["tags"]), "accent": accent, "surface": surface,
            "preview": "assets/preview.gif", "screenshots": screenshots,
            "manifest": "manifest.json", "manifestSha256": sha256_bytes(manifest_bytes),
        }
        print(f"built {pid}: accent={accent} surface={surface} "
              f"screenshots={len(screenshots)} files={len(files)}")

    ordered = sorted(entries.values(), key=lambda entry: entry["id"])
    registry[CATEGORY] = ordered
    registry_path.write_bytes(dump_json(registry))
    print(f"registry.json updated: {len(ordered)} lockscreens")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Import curated qylock lockscreen themes (direct gif previews)")
    sub = parser.add_subparsers(dest="command", required=True)
    for name, help_text in (("fetch", "pull payloads + gifs + backgrounds"),
                            ("compress", "re-encode oversized video to <=1080p"),
                            ("build", "assemble manifests + registry"),
                            ("all", "fetch, compress, then build")):
        parser_cmd = sub.add_parser(name, help=help_text)
        parser_cmd.add_argument("ids", nargs="*", help="theme ids (default: all curated)")
    sub.add_parser("ids", help="print curated ids")

    args = parser.parse_args(argv)
    if args.command == "fetch":
        fetch(args.ids)
    elif args.command == "compress":
        compress(args.ids)
    elif args.command == "build":
        build(args.ids)
    elif args.command == "all":
        fetch(args.ids)
        compress(args.ids)
        build(args.ids)
    elif args.command == "ids":
        print(" ".join(t["id"] for t in CURATED))
    return 0


if __name__ == "__main__":
    sys.exit(main())
