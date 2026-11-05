"""Clipboard and OCR for DragShift on Ryoku (wl-copy, tesseract).

wl-copy forks a helper that keeps serving the clipboard after we exit, so its
output is sent to /dev/null: a captured pipe would keep the job waiting until
the clipboard changes.
"""
from __future__ import annotations

import io
import re
import shutil
import subprocess
import tempfile
from pathlib import Path

LANG_RE = re.compile(r"^[A-Za-z_]+(\+[A-Za-z_]+)*$")


class ExtrasError(Exception):
    """A message that is fine to show the user as-is."""


def _need(cmd: str, package: str) -> None:
    if shutil.which(cmd) is None:
        raise ExtrasError(f"{cmd} isn't installed. Install the '{package}' package.")


def _wl_copy(data: bytes, mime: str) -> None:
    _need("wl-copy", "wl-clipboard")
    r = subprocess.run(["wl-copy", "--type", mime], input=data,
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=15)
    if r.returncode != 0:
        raise ExtrasError("wl-copy couldn't reach the clipboard (is this a Wayland session?)")


def copy_image(src: Path, open_image) -> None:
    """Put the image on the clipboard as PNG, which every app can paste."""
    if src.suffix.lower() == ".png":
        data = src.read_bytes()
    else:
        buf = io.BytesIO()
        with open_image(src) as im:
            im.save(buf, "PNG")
        data = buf.getvalue()
    _wl_copy(data, "image/png")


def copy_paths(paths: list[Path]) -> None:
    _wl_copy("\n".join(str(p) for p in paths).encode(), "text/plain;charset=utf-8")


def ocr_langs() -> list[str]:
    if shutil.which("tesseract") is None:
        return []
    try:
        r = subprocess.run(["tesseract", "--list-langs"], capture_output=True, text=True, timeout=15)
    except (OSError, subprocess.SubprocessError):
        return []
    return [ln.strip() for ln in r.stdout.splitlines()[1:] if ln.strip() and ln.strip() != "osd"]


def ocr(src: Path, lang: str, open_image, sibling) -> tuple[Path, str]:
    """Read the text in an image, save it as "<name> Text.txt" and copy it."""
    _need("tesseract", "tesseract")
    if not LANG_RE.match(lang):
        raise ExtrasError(f"'{lang}' isn't a valid OCR language (use codes like eng or eng+vie)")
    have = ocr_langs()
    missing = [code for code in lang.split("+") if code not in have]
    if missing:
        raise ExtrasError(f"OCR language '{missing[0]}' isn't installed. "
                          f"Install the 'tesseract-data-{missing[0]}' package.")
    with tempfile.TemporaryDirectory(prefix="dragshift-ocr-") as tmp:
        png = Path(tmp) / "page.png"
        with open_image(src) as im:  # HEIC/AVIF/WEBP become something leptonica reads
            im.save(png, "PNG")
        r = subprocess.run(["tesseract", str(png), "stdout", "-l", lang], stdin=subprocess.DEVNULL,
                           capture_output=True, text=True, timeout=300)
    text = r.stdout.strip()
    if r.returncode != 0:
        raise ExtrasError(f"tesseract failed: {(r.stderr.strip().splitlines() or ['no output'])[-1]}")
    if not text:
        raise ExtrasError("No text found in this image")
    out = sibling(src, "Text", ".txt")
    out.write_text(text + "\n", encoding="utf-8")
    _wl_copy(text.encode(), "text/plain;charset=utf-8")
    return out, text
