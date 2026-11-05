"""Clipboard (wl-copy) and OCR (tesseract)."""
from __future__ import annotations

import os
import shutil
import stat
from pathlib import Path

import pytest
from PIL import Image, ImageDraw, ImageFont

from conftest import eng
from test_engine import fail, ok


@pytest.fixture
def clipboard(tmp_path, monkeypatch) -> Path:
    """A fake wl-copy on PATH that records its argv and stdin."""
    bindir = tmp_path / "fakebin"
    bindir.mkdir()
    log = tmp_path / "clip"
    script = bindir / "wl-copy"
    script.write_text(f'#!/bin/sh\nprintf "%s\\n" "$@" > "{log}.args"\ncat > "{log}.data"\n')
    script.chmod(script.stat().st_mode | stat.S_IEXEC)
    monkeypatch.setenv("PATH", f"{bindir}{os.pathsep}{os.environ['PATH']}")
    return log


def test_copy_paths_uses_every_dropped_item(clipboard, photos, png):
    r = ok(["tool", "copy-path", str(photos), str(png)])
    assert r["title"] == "2 paths copied" and r["outs"] == []
    assert Path(f"{clipboard}.data").read_text() == f"{photos}\n{png}"
    assert "text/plain;charset=utf-8" in Path(f"{clipboard}.args").read_text()


def test_copy_image_sends_png(clipboard, jpg):
    ok(["tool", "copy", str(jpg)])
    data = Path(f"{clipboard}.data").read_bytes()
    assert data[:8] == b"\x89PNG\r\n\x1a\n"
    assert "image/png" in Path(f"{clipboard}.args").read_text()


def test_copy_image_handles_cmyk(clipboard, tmp_path):
    p = tmp_path / "print.jpg"
    Image.new("CMYK", (40, 30), (0, 128, 255, 0)).save(p)
    ok(["tool", "copy", str(p)])
    assert Path(f"{clipboard}.data").read_bytes()[:4] == b"\x89PNG"


def test_missing_wl_copy_names_the_package(png, monkeypatch):
    monkeypatch.setattr(eng.ds_extras.shutil, "which", lambda c: None)
    assert "'wl-clipboard' package" in fail(["tool", "copy", str(png)])["error"]


def test_ocr_language_is_validated(png):
    assert "valid OCR language" in fail(["--ocr-lang", "eng;rm", "tool", "ocr", str(png)])["error"]


def test_ocr_names_the_missing_language_package(png):
    r = fail(["--ocr-lang", "eng+zzz", "tool", "ocr", str(png)])
    assert "tesseract-data-zzz" in r["error"] or "tesseract isn't installed" in r["error"]


@pytest.mark.skipif(shutil.which("tesseract") is None, reason="tesseract not installed")
def test_ocr_reads_text_saves_and_copies_it(clipboard, tmp_path):
    if "eng" not in eng.ds_extras.ocr_langs():
        pytest.skip("tesseract has no eng data")
    p = tmp_path / "shot.webp"
    im = Image.new("RGB", (900, 220), "white")
    font = ImageFont.load_default(size=96)
    ImageDraw.Draw(im).text((40, 50), "HELLO 123", fill="black", font=font)
    im.save(p)
    r = ok(["tool", "ocr", str(p)])
    out = Path(r["outs"][0])
    assert out.name == "shot Text.txt" and "HELLO" in out.read_text()
    assert "HELLO" in Path(f"{clipboard}.data").read_text()


def test_ocr_of_a_blank_image_says_so(clipboard, tmp_path):
    if shutil.which("tesseract") is None or "eng" not in eng.ds_extras.ocr_langs():
        pytest.skip("tesseract with eng needed")
    p = tmp_path / "blank.png"
    Image.new("RGB", (200, 100), "white").save(p)
    assert fail(["tool", "ocr", str(p)])["error"] == "No text found in this image"
    assert sorted(x.name for x in tmp_path.iterdir() if x.is_file()) == ["blank.png"]


def test_doctor_reports_the_optional_tools():
    r = ok(["doctor"])
    assert isinstance(r["ffmpeg"], bool) and isinstance(r["wlcopy"], bool)
    assert isinstance(r["ocrLangs"], list) and "osd" not in r["ocrLangs"]
