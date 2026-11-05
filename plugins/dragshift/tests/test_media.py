"""Video and audio through the system ffmpeg (skipped when it isn't installed)."""
from __future__ import annotations

import shutil
import subprocess
from pathlib import Path

import pytest

from conftest import eng
from test_engine import fail, ok

pytestmark = pytest.mark.skipif(shutil.which("ffmpeg") is None, reason="ffmpeg not installed")


def _gen(out: Path, *args: str) -> Path:
    subprocess.run(["ffmpeg", "-nostdin", "-loglevel", "error", *args, str(out)], check=True)
    return out


@pytest.fixture
def clip(tmp_path) -> Path:
    return _gen(tmp_path / "clip one.mov", "-f", "lavfi", "-i", "testsrc=size=321x241:rate=10:duration=1",
                "-f", "lavfi", "-i", "sine=frequency=440:duration=1", "-shortest",
                "-c:v", "mpeg4", "-c:a", "aac")


@pytest.fixture
def silent(tmp_path) -> Path:
    return _gen(tmp_path / "silent.mp4", "-f", "lavfi", "-i", "testsrc=size=160x120:rate=10:duration=1",
                "-c:v", "mpeg4")


@pytest.fixture
def tone(tmp_path) -> Path:
    return _gen(tmp_path / "tone.wav", "-f", "lavfi", "-i", "sine=frequency=440:duration=1")


def test_actions_for_video_and_audio(clip, tone):
    v = ok(["actions", str(clip)])
    assert v["category"] == "video" and [c["id"] for c in v["convert"]] == ["MP4", "WEBM", "GIF", "MP3"]
    assert "compress" in [t["id"] for t in v["tools"]]
    a = ok(["actions", str(tone)])
    assert a["category"] == "audio" and [c["id"] for c in a["convert"]] == ["MP3", "OPUS", "FLAC"]


@pytest.mark.parametrize("target", ["MP4", "WEBM", "GIF", "MP3"])
def test_video_converts(clip, target):
    out = Path(ok(["convert", "--to", target, str(clip)])["outs"][0])
    assert out.name == f"clip one.{target.lower()}" and out.stat().st_size > 0


@pytest.mark.parametrize("target", ["MP3", "OPUS", "FLAC"])
def test_audio_converts(tone, target):
    out = Path(ok(["convert", "--to", target, str(tone)])["outs"][0])
    assert out.suffix == "." + target.lower() and out.stat().st_size > 0


def test_compress_video_keeps_even_dimensions(clip):
    out = Path(ok(["tool", "compress", str(clip)])["outs"][0])
    assert out.name == "clip one Compressed.mp4"
    dims = subprocess.run(["ffprobe", "-v", "error", "-select_streams", "v:0", "-show_entries",
                           "stream=width,height", "-of", "csv=p=0", str(out)],
                          capture_output=True, text=True, check=True).stdout.strip()
    w, h = map(int, dims.split(","))
    assert w % 2 == 0 and h % 2 == 0


def test_an_existing_output_is_never_overwritten(clip):
    taken = clip.with_suffix(".mp3")
    taken.write_bytes(b"mine")
    out = Path(ok(["convert", "--to", "MP3", str(clip)])["outs"][0])
    assert out.name == "clip one (1).mp3" and taken.read_bytes() == b"mine"


def test_audio_from_a_silent_video_is_a_clean_error(silent):
    r = fail(["convert", "--to", "MP3", str(silent)])
    assert "no audio track" in r["error"]
    assert sorted(p.name for p in silent.parent.iterdir()) == ["silent.mp4"]


def test_missing_ffmpeg_names_the_package(clip, monkeypatch):
    monkeypatch.setattr(eng.ds_media, "available", lambda: False)
    assert "'ffmpeg' package" in fail(["convert", "--to", "MP4", str(clip)])["error"]
