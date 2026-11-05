"""Video and audio for DragShift on Ryoku, through the system ffmpeg.

Every ffmpeg call is an argv list (never a shell string), reads nothing from
stdin, and writes to a hidden ".part" file that is renamed into place only when
ffmpeg succeeds. subprocess.run kills ffmpeg if the job is cancelled.
"""
from __future__ import annotations

import shutil
import subprocess
from pathlib import Path

from ds_archive import temp_part

VIDEO_EXTS = {".mp4", ".mov", ".mkv", ".webm", ".avi", ".m4v"}
AUDIO_EXTS = {".mp3", ".m4a", ".wav", ".flac", ".ogg", ".opus"}
VIDEO_TARGETS = ["MP4", "WEBM", "GIF", "MP3"]
AUDIO_TARGETS = ["MP3", "OPUS", "WAV", "FLAC"]
HINTS = {"MP4": "Plays everywhere", "WEBM": "Open web video", "GIF": "First 15 s · 480 px",
         "MP3": "Universal audio", "OPUS": "Small, great quality", "WAV": "Uncompressed",
         "FLAC": "Lossless"}
SAME = {".m4v": "MP4", ".ogg": "OPUS"}

_EVEN = "scale=trunc(iw/2)*2:trunc(ih/2)*2"
_ARGS = {
    "MP4": ["-vf", _EVEN, "-c:v", "libx264", "-crf", "23", "-preset", "medium", "-pix_fmt", "yuv420p",
            "-c:a", "aac", "-b:a", "160k", "-movflags", "+faststart"],
    "WEBM": ["-c:v", "libvpx-vp9", "-crf", "33", "-b:v", "0", "-row-mt", "1", "-c:a", "libopus", "-b:a", "128k"],
    "GIF": ["-t", "15", "-an", "-vf", "fps=15,scale='min(480,iw)':-1:flags=lanczos,"
            "split[a][b];[a]palettegen[p];[b][p]paletteuse", "-loop", "0"],
    "MP3": ["-vn", "-c:a", "libmp3lame", "-q:a", "2"],
    "OPUS": ["-vn", "-c:a", "libopus", "-b:a", "128k"],
    "WAV": ["-vn", "-c:a", "pcm_s16le"],
    "FLAC": ["-vn", "-c:a", "flac"],
    "COMPRESS": ["-vf", "scale=-2:'min(1080,trunc(ih/2)*2)'", "-c:v", "libx264", "-crf", "28",
                 "-preset", "medium", "-pix_fmt", "yuv420p", "-c:a", "aac", "-b:a", "128k",
                 "-movflags", "+faststart"],
}


class MediaError(Exception):
    """A message that is fine to show the user as-is."""


def category(path: str | Path) -> str | None:
    ext = Path(path).suffix.lower()
    return "video" if ext in VIDEO_EXTS else "audio" if ext in AUDIO_EXTS else None


def targets_for(cat: str, src_ext: str) -> list[str]:
    cur = SAME.get(src_ext.lower(), src_ext.lower().lstrip(".").upper())
    return [t for t in {"video": VIDEO_TARGETS, "audio": AUDIO_TARGETS}.get(cat, []) if t != cur]


def available() -> bool:
    return shutil.which("ffmpeg") is not None


def _ffmpeg(src: Path, out: Path, args: list[str]) -> Path:
    if not available():
        raise MediaError("ffmpeg isn't installed. Install the 'ffmpeg' package.")
    part = temp_part(out.parent, f".part{out.suffix}")
    cmd = ["ffmpeg", "-nostdin", "-hide_banner", "-loglevel", "error", "-y", "-i", str(src), *args, str(part)]
    try:
        r = subprocess.run(cmd, stdin=subprocess.DEVNULL, capture_output=True, text=True)
        if r.returncode != 0 or not part.is_file() or part.stat().st_size == 0:
            msg = (r.stderr.strip().splitlines() or ["ffmpeg failed"])[-1]
            if "does not contain any stream" in r.stderr or "matches no streams" in r.stderr:
                msg = "This file has no audio track" if "-vn" in args else "This file has no video track"
            raise MediaError(f"{src.name}: {msg}")
        part.replace(out)
    finally:
        part.unlink(missing_ok=True)
    return out


def convert(src: Path, cat: str, target: str, sibling) -> Path:
    if target not in targets_for(cat, src.suffix):
        raise MediaError(f"Can't convert {cat} to {target}")
    return _ffmpeg(src, sibling(src, ext="." + target.lower()), _ARGS[target])


def compress_video(src: Path, sibling) -> Path:
    return _ffmpeg(src, sibling(src, "Compressed", ".mp4"), _ARGS["COMPRESS"])
