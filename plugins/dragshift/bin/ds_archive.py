"""Folders and archives for DragShift on Ryoku: pack anything into ZIP/TAR, unpack safely.

Standard library only. Every write goes to a hidden ".part" name first and is
renamed into place at the end, so a cancelled job (SIGTERM unwinds through the
`finally` blocks) never leaves a half-written archive or folder behind.
"""
from __future__ import annotations

import os
import shutil
import stat
import tarfile
import tempfile
import zipfile
from pathlib import Path, PurePosixPath

# id -> (label, suffix, tarfile mode or None for zip, hint)
FORMATS = {
    "zip": ("ZIP", ".zip", None, "Opens anywhere"),
    "tar-gz": ("TAR.GZ", ".tar.gz", "w:gz", "Linux standard"),
    "tar-xz": ("TAR.XZ", ".tar.xz", "w:xz", "Smallest"),
}
# Longest first, so "x.tar.gz" is a .tar.gz and not a .gz.
ARCHIVE_SUFFIXES = (".tar.gz", ".tar.xz", ".tar.bz2", ".tgz", ".txz", ".tbz2", ".zip", ".tar")
MAX_MEMBERS = 200_000
SPARE_BYTES = 256 * 1024 ** 2  # leave this much disk free after extracting


def temp_part(folder: Path, suffix: str) -> Path:
    """A new, empty, hidden ".dragshift-XXXX<suffix>" in `folder`, with the mode a normal
    new file gets. Short on purpose: ".<long name>.part" can pass NAME_MAX (255 bytes)
    when the real output name doesn't."""
    fd, name = tempfile.mkstemp(prefix=".dragshift-", suffix=suffix, dir=folder)
    os.close(fd)
    umask = os.umask(0)
    os.umask(umask)
    os.chmod(name, 0o666 & ~umask)  # mkstemp's 0600 would make every result private
    return Path(name)


class ArchiveError(Exception):
    """A message that is fine to show the user as-is."""


def archive_suffix(path: str | Path) -> str:
    name = Path(path).name.lower()
    return next((s for s in ARCHIVE_SUFFIXES if name.endswith(s) and len(name) > len(s)), "")


def archive_stem(path: str | Path) -> str:
    p = Path(path)
    return p.name[: len(p.name) - len(archive_suffix(p))] if archive_suffix(p) else p.stem


# ---------------------------------------------------------------- pack
def _entries(item: Path) -> tuple[list[tuple[Path, str]], int]:
    """(path, name inside the archive) for `item` and everything under it, plus how
    many symlinks and special files were left out. Links are never followed."""
    base = item.parent
    if item.is_symlink():
        return [], 1
    if item.is_file():
        return [(item, item.name)], 0
    out, skipped = [(item, item.name)], 0
    for root, dirs, files in os.walk(item, followlinks=False):
        r = Path(root)
        dirs.sort()
        for d in list(dirs):
            if (r / d).is_symlink():
                dirs.remove(d)
                skipped += 1
            else:
                out.append((r / d, (r / d).relative_to(base).as_posix()))
        for f in sorted(files):
            p = r / f
            if p.is_symlink() or not stat.S_ISREG(p.lstat().st_mode):
                skipped += 1
            else:
                out.append((p, p.relative_to(base).as_posix()))
    return out, skipped


def pack(paths: list[Path], fmt: str, out_dir, unique_path) -> tuple[Path, int, int]:
    """Archive `paths` into one file. Returns (archive, entries written, skipped).
    One item is named after itself, several become "Archive"."""
    if fmt not in FORMATS:
        raise ArchiveError(f"Unknown archive format '{fmt}'")
    _, suffix, mode, _ = FORMATS[fmt]
    first = paths[0]
    name = (first.name if first.is_dir() else archive_stem(first)) if len(paths) == 1 else "Archive"
    dest = unique_path(out_dir(first) / (name + suffix))
    entries, skipped = [], 0
    for p in paths:
        e, s = _entries(p)
        entries += [(src, arc) for src, arc in e if src != dest]
        skipped += s
    if not entries:
        raise ArchiveError("Nothing to archive (only links or special files)")
    part = temp_part(dest.parent, ".part")
    try:
        if mode is None:
            with zipfile.ZipFile(part, "w", zipfile.ZIP_DEFLATED, compresslevel=6,
                                 strict_timestamps=False) as z:
                for src, arc in entries:
                    z.write(src, arc + "/" if src.is_dir() else arc)
        else:
            with tarfile.open(part, mode) as t:
                for src, arc in entries:
                    t.add(src, arc, recursive=False)
        part.replace(dest)
    finally:
        part.unlink(missing_ok=True)
    return dest, len(entries), skipped


# ---------------------------------------------------------------- unpack
def _check_zip_member(info: zipfile.ZipInfo) -> int:
    name = info.filename
    parts = PurePosixPath(name.replace("\\", "/")).parts
    if name.startswith(("/", "\\")) or (len(name) > 1 and name[1] == ":") or ".." in parts:
        raise ArchiveError(f"Refusing to extract: '{name}' points outside the folder")
    if stat.S_ISLNK(info.external_attr >> 16):
        raise ArchiveError(f"Refusing to extract: '{name}' is a symbolic link")
    if info.flag_bits & 0x1:
        raise ArchiveError("Password-protected ZIPs aren't supported")
    return info.file_size


def _room_for(total: int, where: Path) -> None:
    free = shutil.disk_usage(where).free
    if total + SPARE_BYTES > free:
        raise ArchiveError(f"Not enough disk space: needs {total / 1024 ** 2:.0f} MB, "
                           f"{free / 1024 ** 2:.0f} MB free")


def _open_tar(src: Path) -> tarfile.TarFile:
    try:
        return tarfile.open(src)
    except (tarfile.TarError, OSError, EOFError) as e:
        raise ArchiveError(f"{src.name} isn't a readable archive ({e})") from None


def unpack(src: Path, out_dir, unique_path) -> tuple[Path, int]:
    """Extract `src` into a new folder beside it. An archive that holds exactly one
    top-level folder is not wrapped in a second one. Returns (folder, entries)."""
    where = out_dir(src)
    tmp = Path(tempfile.mkdtemp(prefix=".dragshift-", suffix=".part", dir=where))
    umask = os.umask(0)
    os.umask(umask)
    tmp.chmod(0o777 & ~umask)  # mkdtemp's 0700 would otherwise become the folder's mode
    try:
        if archive_suffix(src) == ".zip":
            try:
                z = zipfile.ZipFile(src)
            except (zipfile.BadZipFile, OSError) as e:
                raise ArchiveError(f"{src.name} isn't a readable ZIP ({e})") from None
            with z:
                infos = z.infolist()
                if len(infos) > MAX_MEMBERS:
                    raise ArchiveError(f"Too many entries ({len(infos)})")
                _room_for(sum(_check_zip_member(i) for i in infos), where)
                z.extractall(tmp)
                count = len(infos)
        else:
            with _open_tar(src) as t:
                members = t.getmembers()
                if len(members) > MAX_MEMBERS:
                    raise ArchiveError(f"Too many entries ({len(members)})")
                _room_for(sum(m.size for m in members), where)
                try:
                    t.extractall(tmp, filter="data")
                except tarfile.FilterError as e:
                    raise ArchiveError(f"Refusing to extract: {e}") from None
                count = len(members)
        top = list(tmp.iterdir())
        if len(top) == 1 and top[0].is_dir() and not top[0].is_symlink():
            dest = unique_path(where / top[0].name)
            top[0].rename(dest)
        else:
            dest = unique_path(where / archive_stem(src))
            tmp.rename(dest)
        return dest, count
    finally:
        if tmp.exists():
            shutil.rmtree(tmp, ignore_errors=True)
