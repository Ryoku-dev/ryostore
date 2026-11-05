#!/usr/bin/env python3
"""dragshift_engine - the bridge between the Ryoku bar panel and the DragShift engine.

Runs inside the engine's own venv (bin/dragshift execs it with `python -I`), imports
the pinned DragShift checkout from $DRAGSHIFT_ENGINE, and answers every call with
exactly one JSON object on stdout: {"ok": true, ...} and exit 0, or
{"ok": false, "error": "...", ["fix": "..."]} and exit 1. The QML never parses
anything else and never builds a shell string to call us (R9).

Commands (paths must be absolute):
    [OPTIONS] doctor
    [OPTIONS] actions PATH...
    [OPTIONS] convert --to TARGET PATH...
    [OPTIONS] tool TOOL PATH...
    [OPTIONS] editor [--dry] EDITOR FILE...
    trash PATH...
    reveal PATH
OPTIONS: --output next|folder, --ocr-lang CODES (e.g. eng+vie)

PATHs may be folders: they can be archived, and their images batch-processed.
It writes only new files and folders beside the originals (or in a "DragShift"
subfolder beside them, with --output folder). Originals are never modified.
"""
from __future__ import annotations

import importlib
import importlib.util
import json
import os
import shutil
import signal
import subprocess
import sys
import traceback
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))  # -I leaves our own dir off sys.path
import ds_archive  # noqa: E402
import ds_extras  # noqa: E402
import ds_media  # noqa: E402
import ds_pdf  # noqa: E402

PLUGIN_DIR = Path(__file__).resolve().parent.parent
PIN_FILE = PLUGIN_DIR / "engine" / "PIN"
DEFAULT_ENGINE = "~/.local/share/dragshift/engine"
MAX_FILES = 500
LEDGER_KEEP = 100
OPTIONS = {"output": "next", "ocr_lang": "eng"}
USER_ERRORS = (ds_archive.ArchiveError, ds_media.MediaError, ds_extras.ExtrasError, ds_pdf.PdfError)

# Filled by load_engine(): the DragShift modules this bridge drives.
convert = imaging = util = report = None
_loaded_from: Path | None = None


class Refusal(Exception):
    """A request we turn down with a message that is fine to show as-is."""


# ---------------------------------------------------------------- engine loading
def engine_dir() -> Path:
    return Path(os.environ.get("DRAGSHIFT_ENGINE") or DEFAULT_ENGINE).expanduser().resolve()


def load_engine(path: Path) -> None:
    """Import the headless DragShift modules from the checkout at `path`."""
    global convert, imaging, util, report, _loaded_from
    if _loaded_from == path:
        return
    if not (path / "dragshift" / "__init__.py").is_file():
        raise Refusal(f"No DragShift checkout at {path}")
    sys.path.insert(0, str(path))
    convert = importlib.import_module("dragshift.convert")
    imaging = importlib.import_module("dragshift.imaging")
    util = importlib.import_module("dragshift.util")
    report = importlib.import_module("dragshift.report")
    ds_pdf.use(convert.open_pdf, util.sibling)
    _loaded_from = path


def read_pin() -> str:
    try:
        return PIN_FILE.read_text().strip()
    except OSError:
        return ""


def git_head(path: Path) -> str:
    try:
        r = subprocess.run(["git", "-C", str(path), "rev-parse", "HEAD"],
                           capture_output=True, text=True, timeout=10)
    except (OSError, subprocess.SubprocessError):
        return ""
    return r.stdout.strip() if r.returncode == 0 else ""


def git_dirty(path: Path) -> bool:
    try:
        r = subprocess.run(["git", "-C", str(path), "status", "--porcelain", "--untracked-files=no"],
                           capture_output=True, text=True, timeout=10)
    except (OSError, subprocess.SubprocessError):
        return False
    return r.returncode == 0 and bool(r.stdout.strip())


def doctor(path: Path, pin: str | None = None) -> dict:
    """Is the engine present, importable and at the commit this plugin was tested with?"""
    pin = read_pin() if pin is None else pin
    r = {"ok": False, "engine": str(path), "pin": pin, "python": sys.executable,
         "sha": "", "pinned": False, "heif": False, "editors": False}
    try:
        load_engine(path)
    except Exception as e:  # noqa: BLE001 - any import failure is a doctor finding
        r["error"] = f"DragShift engine not usable: {e}"
        r["fix"] = f"{PLUGIN_DIR / 'engine' / 'setup.sh'} {path}"
        return r
    r["sha"] = git_head(path)
    r["dirty"] = git_dirty(path)
    r["pinned"] = bool(pin) and r["sha"] == pin
    r["heif"] = bool(getattr(convert, "HEIF_OK", False))
    r["editors"] = importlib.util.find_spec("PySide6") is not None
    r["ffmpeg"] = ds_media.available()
    r["ocrLangs"] = ds_extras.ocr_langs()
    r["wlcopy"] = shutil.which("wl-copy") is not None
    if not r["pinned"]:
        r["error"] = f"Engine is at {r['sha'][:12] or 'an unknown commit'}, plugin is tested with {pin[:12]}"
        r["fix"] = f"git -C {path} checkout --detach {pin}"
        return r
    if r["dirty"]:
        r["error"] = "The engine checkout has local edits to tracked files"
        r["fix"] = f"git -C {path} status   (then restore or stash the edits)"
        return r
    r["ok"] = True
    return r


# ---------------------------------------------------------------- menus
FORMAT_HINTS = {"JPG": "Small, universal", "PNG": "Lossless · transparency", "WEBP": "Smallest for web",
                "HEIC": "iPhone format", "TIFF": "Print · archival", "AVIF": "Next-gen, tiny",
                "BMP": "Uncompressed", "PDF": "Document", "ICO": "Windows icon", "GIF": "Legacy web",
                "DOCX": "Editable Word", "TXT": "Plain text"}

# id -> (label, action name upstream's report understands, function(path) -> list[Path])
IMAGE_TOOLS = {
    "compress": ("Compress", "Compress", lambda p: [imaging.compress_image(p)]),
    "compress-500kb": ("Under 500 KB", "Compress", lambda p: [_compress_under(p, 500 * 1024)]),
    "half": ("Half size", "Resize", lambda p: [_resize(p, "pct", 50)]),
    "long-1920": ("1920 px", "Resize", lambda p: [_resize(p, "long", 1920)]),
    "long-1280": ("1280 px", "Resize", lambda p: [_resize(p, "long", 1280)]),
    "strip-location": ("Remove location", "Metadata", lambda p: [imaging.strip_location(p)]),
    "strip-all": ("Remove all metadata", "Metadata", lambda p: [imaging.strip_image_metadata(p)]),
}
PDF_TOOLS = {
    "compress": ("Compress", "Compress", lambda p: [imaging.compress_pdf(p)]),
    "split": ("Split pages", "Split", lambda p: imaging.split_pdf(p)),
    "rotate": ("Rotate 90°", "Rotate", lambda p: [imaging.rotate_pdf(p)]),
    "extract": ("Extract images", "Extract", lambda p: imaging.extract_pdf_images(p)),
    "strip-all": ("Remove metadata", "Metadata", lambda p: [imaging.strip_pdf_metadata(p)]),
    "numbers": ("Page numbers", "Page numbers added", lambda p: [ds_pdf.number_pages(p)]),
    "gray": ("Grayscale", "Converted to grayscale", lambda p: [ds_pdf.grayscale(p)]),
    "flatten": ("Flatten", "Flattened", lambda p: [ds_pdf.flatten(p)]),
    "halves": ("Split in half", "Split", lambda p: ds_pdf.split_halves(p)),
    "chapters": ("Split by bookmarks", "Split", lambda p: ds_pdf.split_chapters(p)),
}

VIDEO_TOOLS = {
    "compress": ("Compress", "Compress", lambda p: [ds_media.compress_video(p, util.sibling)]),
}


def tools_for(cat: str) -> dict:
    """One-file-at-a-time tools: id -> (label, report action, function(path) -> outputs)."""
    return {"image": IMAGE_TOOLS, "pdf": PDF_TOOLS, "video": VIDEO_TOOLS}.get(cat, {})


# Whole-job tools: id -> (label, handler(files of the kind, every dropped path) -> reply).
# ANY_TOOLS work on every drop and take every dropped path, whatever its kind.
def job_tools_for(cat: str) -> dict:
    return {"image": {"copy": ("Copy", _t_copy_image), "ocr": ("Text", _t_ocr)},
            "pdf": {"searchable": ("Searchable", _t_searchable)},
            "archive": {"extract": ("Extract", _t_extract)},
            "folder": {"batch-webp": ("Images → WEBP", _t_batch("WEBP")),
                       "batch-jpg": ("Images → JPG", _t_batch("JPG")),
                       "batch-compress": ("Compress images", _t_batch("Compressed"))},
            }.get(cat, {})


def any_tools() -> dict:
    t = {k: (f"{v[0]}", _t_pack(k)) for k, v in ds_archive.FORMATS.items()}
    t["copy-path"] = ("Copy path", _t_copy_paths)
    return t


def targets_for(cat: str, suffix: str) -> list[str]:
    if cat in ("video", "audio"):
        return ds_media.targets_for(cat, suffix)
    if cat in ("image", "pdf", "docx", "text"):
        return convert.targets_for(cat, suffix)
    return []


# id -> (label, tools.py class, takes a list of paths, extra kwargs) - mirrors app.run_item
IMAGE_EDITORS = {
    "crop": ("Crop", "CropWindow", False), "edit": ("Edit", "EditWindow", False),
    "annotate": ("Annotate", "AnnotateWindow", False), "redact": ("Redact", "RedactWindow", False),
    "add-bg": ("Add BG", "AddBgWindow", False), "compress-custom": ("Compress…", "CompressWindow", True),
    "resize-custom": ("Resize…", "ResizeWindow", True), "metadata": ("Metadata", "MetadataWindow", False),
}
# A 5th field names the module that owns the window class (default: upstream tools).
PDF_EDITORS = {
    "organize": ("Organize…", "OrganizeWindow", True, {}, "ds_pdfwin"),
    "watermark": ("Watermark…", "WatermarkWindow", False, {}, "ds_pdfwin"),
    "protect": ("Protect", "ProtectWindow", False),
    "unlock": ("Unlock…", "UnlockWindow", False, {}, "ds_pdfwin"),
    "metadata": ("Metadata", "MetadataWindow", False, {"is_pdf": True}),
}


def _compress_under(p, max_bytes: int) -> Path:
    im = convert.open_image(p)
    target = imaging.lossy_target(p)
    quality, side = imaging.plan_target_size(im, target, max_bytes)
    return imaging.compress_to(p, quality, side, target)


def _resize(p, mode: str, value: int) -> Path:
    with convert.open_image(p) as im:
        dims = imaging.resize_dims(im.size, mode, value)
    return imaging.resize_image(p, dims)


def editors_for(cat: str) -> dict:
    return {"image": IMAGE_EDITORS, "pdf": PDF_EDITORS}.get(cat, {})


# ---------------------------------------------------------------- input checks
def kind_of(p: Path) -> str | None:
    if p.is_dir():
        return "folder"
    if ds_archive.archive_suffix(p):
        return "archive"
    return util.category(p) or ds_media.category(p)


def check_files(args: list[str]) -> tuple[list[Path], list[Path]]:
    """(files and folders, dropped items that are neither: vanished, sockets...)."""
    if not args:
        raise Refusal("No files given")
    if len(args) > MAX_FILES:
        raise Refusal(f"Too many files ({len(args)}); the limit is {MAX_FILES}")
    items, skipped = [], []
    for a in args:
        p = Path(a)
        if not p.is_absolute():
            raise Refusal(f"Not an absolute path: {a}")
        (items if p.is_file() or p.is_dir() else skipped).append(p)
    if not items:
        raise Refusal("No usable files: " + ", ".join(p.name or str(p) for p in skipped[:3]))
    return items, skipped


def same_kind(checked: tuple[list[Path], list[Path]]) -> tuple[str, list[Path], list[Path]]:
    """The first file of a known kind decides; the rest of that kind come along.
    All folders is "folder"; nothing known (unknown files, folders mixed in) is "any",
    which can still be archived. Nothing is ever fatal here."""
    items, skipped = checked
    kinds = [kind_of(p) for p in items]
    cat = next((k for k in kinds if k not in (None, "folder")), None)
    if cat is None:
        cat = "folder" if all(k == "folder" for k in kinds) else "any"
        return cat, list(items), list(skipped)
    keep = [p for p, k in zip(items, kinds) if k == cat]
    return cat, keep, skipped + [p for p in items if p not in keep]


def summary(action: str, srcs: list[Path], outs: list[Path]) -> dict:
    res = report.summarize(action, srcs, outs)
    return {"ok": True, "outs": [str(o) for o in res.outs], "title": res.title,
            "detail": res.detail, "good": res.good}


def reply(title: str, detail: str, outs: list[Path] | None = None, good: str = "") -> dict:
    return {"ok": True, "outs": [str(o) for o in outs or []], "title": title, "detail": detail, "good": good}


# ---------------------------------------------------------------- created folders
# Undo may move a *folder* to the Trash only if this engine created it (extract,
# batch). The ledger lives in the plugin's own Ryoku state dir.
def _ledger() -> Path:
    state = Path(os.environ.get("XDG_STATE_HOME") or "~/.local/state").expanduser()
    return state / "ryoku" / "plugins" / "dragshift" / "created-dirs"


def created_dirs() -> list[str]:
    try:
        return [ln for ln in _ledger().read_text(encoding="utf-8").splitlines() if ln]
    except OSError:
        return []


def remember_dir(d: Path) -> None:
    led = _ledger()
    led.parent.mkdir(parents=True, exist_ok=True)
    keep = [x for x in created_dirs() if x != str(d)][-(LEDGER_KEEP - 1):] + [str(d)]
    tmp = led.with_name(led.name + ".part")
    tmp.write_text("\n".join(keep) + "\n", encoding="utf-8")
    tmp.replace(led)


def _tree_size(paths: list[Path]) -> int:
    total = 0
    for p in paths:
        if p.is_file():
            total += p.stat().st_size
        elif p.is_dir():
            for root, _, files in os.walk(p, followlinks=False):
                total += sum((Path(root) / f).lstat().st_size for f in files)
    return total


# ---------------------------------------------------------------- whole-job tools
def _t_pack(fmt: str):
    def run_pack(files: list[Path], everything: list[Path]) -> dict:
        dest, n, skipped = ds_archive.pack(everything, fmt, util.output_dir, util.unique_path)
        before, after = util.human_size(_tree_size(everything)), util.human_size(dest.stat().st_size)
        what = everything[0].name if len(everything) == 1 else f"{len(everything)} items"
        detail = f"{dest.name} · {before} → {after}"
        if skipped:
            detail += f" · {skipped} link{'s' if skipped != 1 else ''} left out"
        return reply(f"Archived {what}", detail, [dest])
    return run_pack


def _t_copy_paths(files: list[Path], everything: list[Path]) -> dict:
    ds_extras.copy_paths(everything)
    n = len(everything)
    return reply("Path copied" if n == 1 else f"{n} paths copied", everything[0].name if n == 1 else "")


def _t_copy_image(files: list[Path], everything: list[Path]) -> dict:
    ds_extras.copy_image(files[0], convert.open_image)
    return reply("Image copied", files[0].name + (" (first file)" if len(files) > 1 else ""))


def _t_ocr(files: list[Path], everything: list[Path]) -> dict:
    out, text = ds_extras.ocr(files[0], OPTIONS["ocr_lang"], convert.open_image, util.sibling)
    words = len(text.split())
    return reply("Text copied", f"{out.name} · {words} word{'s' if words != 1 else ''}", [out])


def _t_searchable(files: list[Path], everything: list[Path]) -> dict:
    lang = OPTIONS["ocr_lang"]
    if not ds_extras.LANG_RE.match(lang):
        raise Refusal(f"'{lang}' isn't a valid OCR language (use codes like eng or eng+vie)")
    missing = [c for c in lang.split("+") if c not in ds_extras.ocr_langs()]
    if missing:
        raise Refusal(f"OCR language '{missing[0]}' isn't installed. "
                      f"Install the 'tesseract-data-{missing[0]}' package.")
    outs, done = [], 0
    for f in files:
        out, n = ds_pdf.make_searchable(f, lang)
        outs.append(out)
        done += n
    return reply("Searchable PDF" if len(outs) == 1 else f"{len(outs)} searchable PDFs",
                 f"{outs[0].name} · {done} page{'s' if done != 1 else ''} recognised", outs)


def _t_extract(files: list[Path], everything: list[Path]) -> dict:
    outs, count = [], 0
    for f in files:
        dest, n = ds_archive.unpack(f, util.output_dir, util.unique_path)
        remember_dir(dest)
        outs.append(dest)
        count += n
    title = "Extracted" if len(outs) == 1 else f"Extracted {len(outs)} archives"
    return reply(title, f"{outs[0].name} · {count} item{'s' if count != 1 else ''} · "
                        f"{util.human_size(_tree_size(outs))}", outs)


def _images_in(folder: Path) -> list[Path]:
    """Images anywhere under `folder`, skipping hidden folders and links."""
    found = []
    for root, dirs, names in os.walk(folder, followlinks=False):
        dirs[:] = sorted(d for d in dirs if not d.startswith("."))
        for n in sorted(names):
            p = Path(root) / n
            if not n.startswith(".") and not p.is_symlink() and util.category(p) == "image":
                found.append(p)
    return found


def _t_batch(mode: str):
    """Every image under each folder -> a new "<folder> <mode>" folder beside it,
    keeping the subfolder layout. The originals are only read."""
    def run_batch(folders: list[Path], everything: list[Path]) -> dict:
        outs, done, failed, first_err = [], 0, 0, ""
        for folder in folders:
            images = _images_in(folder)
            if mode != "Compressed":
                images = [p for p in images if mode in convert.targets_for("image", p.suffix)]
            if not images:
                continue
            if len(images) > MAX_FILES:
                raise Refusal(f"{folder.name} has {len(images)} images; the limit is {MAX_FILES}")
            root = util.unique_path(util.output_dir(folder) / f"{folder.name} {mode}")
            root.mkdir()
            remember_dir(root)
            outs.append(root)
            n, bad, err = _batch_into(folder, root, images, mode)
            done, failed, first_err = done + n, failed + bad, first_err or err
        if not outs:
            raise Refusal(f"No images to convert in {folders[0].name}" if mode != "Compressed"
                          else f"No images in {folders[0].name}")
        if done == 0:
            for r in outs:
                _gio_trash(str(r))
            raise Refusal(f"Every image failed: {first_err}")
        title = f"{done} image{'s' if done != 1 else ''} → " + ("compressed" if mode == "Compressed" else mode)
        detail = f"{outs[0].name} · {util.human_size(_tree_size(outs))}"
        if failed:
            detail += f" · {failed} failed ({first_err})"
        return reply(title, detail, outs)
    return run_batch


def _batch_into(folder: Path, root: Path, images: list[Path], mode: str) -> tuple[int, int, str]:
    original = util.output_dir

    def mirrored(src) -> Path:  # upstream's sibling() asks this where to write
        d = root / Path(src).parent.relative_to(folder)
        d.mkdir(parents=True, exist_ok=True)
        return d
    done, failed, err = 0, 0, ""
    util.output_dir = mirrored
    try:
        for img in images:
            try:
                if mode == "Compressed":
                    imaging.compress_image(img)
                else:
                    convert.convert(img, "image", mode)
                done += 1
            except Exception as e:  # noqa: BLE001 - one bad image must not sink the batch
                failed += 1
                err = err or f"{img.name}: {e}"
    finally:
        util.output_dir = original
    return done, failed, err


# ---------------------------------------------------------------- commands
def cmd_actions(args: list[str]) -> dict:
    checked = check_files(args)
    everything = checked[0]
    cat, files, skipped = same_kind(checked)
    first = files[0]
    conv = []
    for t in targets_for(cat, first.suffix):
        hint = FORMAT_HINTS.get(t, "") if cat in ("image", "pdf", "docx", "text") else ds_media.HINTS.get(t, "")
        if cat == "image" and t == "PDF" and len(files) > 1:
            hint = f"{len(files)} images → 1 PDF"
        conv.append({"id": t, "label": t, "hint": hint})
    tools = [{"id": k, "label": v[0]} for k, v in tools_for(cat).items()]
    if cat == "pdf" and len(files) > 1:
        tools.insert(0, {"id": "merge", "label": f"Merge {len(files)}"})
    tools += [{"id": k, "label": v[0]} for k, v in job_tools_for(cat).items()]
    tools += [{"id": k, "label": v[0], "all": True} for k, v in any_tools().items()]
    many = len(files) > 1
    editors = [{"id": k, "label": v[0] + (" (first file)" if many and not v[2] else "")}
               for k, v in editors_for(cat).items()]
    return {"ok": True, "category": cat, "files": [str(f) for f in files],
            "all": [str(p) for p in everything],
            "skipped": [str(f) for f in skipped], "convert": conv, "tools": tools, "editors": editors}


def cmd_convert(args: list[str]) -> dict:
    if len(args) < 2 or args[0] != "--to":
        raise Refusal("usage: convert --to TARGET FILE...")
    target = args[1].upper()
    cat, files, _ = same_kind(check_files(args[2:]))
    if target not in targets_for(cat, files[0].suffix):
        raise Refusal(f"Can't convert {cat} to {target}")
    if cat in ("video", "audio"):
        outs = [ds_media.convert(f, cat, target, util.sibling) for f in files]
    elif cat == "image" and target == "PDF" and len(files) > 1:
        outs = convert.images_to_single_pdf(files)
    else:
        outs = [o for f in files for o in convert.convert(f, cat, target)]
    return summary(f"convert:{target}", files, outs)


def cmd_tool(args: list[str]) -> dict:
    if not args:
        raise Refusal("usage: tool TOOL FILE...")
    name, rest = args[0], args[1:]
    checked = check_files(rest)
    everything = checked[0]
    if name in any_tools():
        return any_tools()[name][1]([], everything)
    cat, files, _ = same_kind(checked)
    if name in job_tools_for(cat):
        return job_tools_for(cat)[name][1](files, everything)
    if cat == "pdf" and name == "merge":
        if len(files) < 2:
            raise Refusal("Merge needs at least two PDFs")
        return summary("tool:Merge", files, [imaging.merge_pdfs(files)])
    spec = tools_for(cat).get(name)
    if spec is None:
        raise Refusal(f"'{name}' isn't a tool for {'these items' if cat == 'any' else cat + ' files'}")
    _, action, fn = spec
    outs = [o for f in files for o in fn(f)]
    return summary(f"tool:{action}", files, outs)


def _gio_trash(path: str) -> bool:
    try:
        return subprocess.run(["gio", "trash", "--", path], capture_output=True, timeout=60).returncode == 0
    except (OSError, subprocess.SubprocessError):
        return False


def cmd_trash(args: list[str]) -> dict:
    """Undo: move these outputs to the Trash. Partial success is reported as failure.
    A folder is accepted only if this engine created it (see remember_dir)."""
    if not args:
        raise Refusal("usage: trash PATH...")
    paths = [Path(a) for a in args]
    if not all(p.is_absolute() for p in paths):
        raise Refusal("trash takes absolute paths only")
    ours = set(created_dirs())
    for p in paths:
        if p.is_dir() and not p.is_symlink() and str(p) not in ours:
            raise Refusal(f"{p.name} is a folder DragShift didn't create; it was left alone")
    n = sum(1 for p in paths if (p.is_file() or p.is_dir()) and _gio_trash(str(p)))
    # extract_pdf_images always makes a fresh "<name> images" folder (unique_path),
    # so an emptied one is ours. A "DragShift" output folder may predate us: kept.
    for d in {p.parent for p in paths}:
        if d.name.endswith(" images") and d.is_dir() and not any(d.iterdir()):
            _gio_trash(str(d))
    if n < len(paths):
        raise Refusal(f"Couldn't move {len(paths) - n} of {len(paths)} to the Trash "
                      "(already gone, or gio trash failed)")
    return {"ok": True, "trashed": n}


def _spawn(cmd: list[str]) -> bool:
    try:
        return subprocess.run(cmd, capture_output=True, timeout=10).returncode == 0
    except (OSError, subprocess.SubprocessError):
        return False


def cmd_reveal(args: list[str]) -> dict:
    """Select the file in the file manager (FileManager1, which Dolphin implements),
    else open its folder. as_uri() percent-encodes commas and quotes, so the
    dbus-send array argument cannot be split or broken by the file name."""
    if len(args) != 1 or not Path(args[0]).is_absolute() or not Path(args[0]).exists():
        raise Refusal("usage: reveal ABSOLUTE_PATH")
    p = Path(args[0])
    if _spawn(["dbus-send", "--session", "--print-reply", "--dest=org.freedesktop.FileManager1",
               "/org/freedesktop/FileManager1", "org.freedesktop.FileManager1.ShowItems",
               f"array:string:{p.as_uri()}", "string:"]):
        return {"ok": True, "how": "filemanager"}
    if _spawn(["xdg-open", str(p.parent)]):
        return {"ok": True, "how": "folder"}
    raise Refusal("No file manager answered")


def cmd_editor(args: list[str]) -> dict:
    dry = bool(args) and args[0] == "--dry"
    args = args[1:] if dry else args
    if not args:
        raise Refusal("usage: editor [--dry] EDITOR FILE...")
    name = args[0]
    cat, files, _ = same_kind(check_files(args[1:]))
    spec = editors_for(cat).get(name)
    if spec is None:
        raise Refusal(f"'{name}' isn't a {cat} editor")
    import dragshift_editor  # Qt is imported only on this path
    return dragshift_editor.open_editor(sys.modules[__name__], spec, files, dry=dry)


COMMANDS = {"actions": cmd_actions, "convert": cmd_convert, "tool": cmd_tool,
            "trash": cmd_trash, "reveal": cmd_reveal, "editor": cmd_editor}


def run(argv: list[str], env: dict | None = None) -> dict:
    """Run one command and return its JSON-able answer. Never raises."""
    saved = {k: os.environ.get(k) for k in (env or {})}
    try:
        os.environ.update(env or {})
        args = list(argv)
        OPTIONS.update(output="next", ocr_lang="eng")
        while args[:1] in (["--output"], ["--ocr-lang"]):
            if len(args) < 2:
                raise Refusal(f"{args[0]} needs a value")
            if args[0] == "--output" and args[1] not in ("next", "folder"):
                raise Refusal("--output must be 'next' or 'folder'")
            OPTIONS["output" if args[0] == "--output" else "ocr_lang"] = args[1]
            args = args[2:]
        output = OPTIONS["output"]
        if not args:
            raise Refusal("No command given")
        cmd, rest = args[0], args[1:]
        if cmd == "doctor":
            return doctor(engine_dir())
        if cmd not in COMMANDS:
            raise Refusal(f"Unknown command '{cmd}'")
        load_engine(engine_dir())
        util.CONFIG["output"] = output
        return COMMANDS[cmd](rest)
    except (Refusal, *USER_ERRORS) as e:
        return {"ok": False, "error": str(e)}
    except Exception as e:  # noqa: BLE001 - every failure must still answer in JSON
        if util is not None and isinstance(e, util.UserError):
            return {"ok": False, "error": str(e)}
        traceback.print_exc(file=sys.stderr)
        return {"ok": False, "error": f"{type(e).__name__}: {e}"}
    finally:
        for k, v in saved.items():
            if v is None:
                os.environ.pop(k, None)
            else:
                os.environ[k] = v


def _terminate(signum, frame):
    """Cancel from the panel sends SIGTERM: unwind, so upstream's atomic_save
    `finally` blocks delete their hidden .part files instead of leaving them."""
    raise SystemExit(143)


def main(argv: list[str] | None = None) -> int:
    signal.signal(signal.SIGTERM, _terminate)
    r = run(sys.argv[1:] if argv is None else argv)
    print(json.dumps(r, ensure_ascii=False), flush=True)
    return 0 if r.get("ok") else 1


if __name__ == "__main__":
    sys.exit(main())
