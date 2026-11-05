"""Folders and archives: pack, extract, batch, and folder-safe Undo."""
from __future__ import annotations

import io
import tarfile
import zipfile
from pathlib import Path

import pytest

from conftest import eng
from test_engine import fail, ok


def names_in_zip(p: Path) -> set[str]:
    with zipfile.ZipFile(p) as z:
        return set(z.namelist())


# ---------------------------------------------------------------- menus
def test_actions_for_a_folder(photos):
    r = ok(["actions", str(photos)])
    assert r["category"] == "folder" and r["files"] == [str(photos)]
    ids = [t["id"] for t in r["tools"]]
    assert ids[:3] == ["batch-webp", "batch-jpg", "batch-compress"]
    assert {"zip", "tar-gz", "tar-xz", "copy-path"} <= set(ids)
    assert r["convert"] == [] and r["editors"] == []


def test_actions_for_an_unknown_file_still_offer_archiving(tmp_path):
    f = tmp_path / "Makefile"
    f.write_text("all:\n")
    r = ok(["actions", str(f)])
    assert r["category"] == "any"
    assert [t["id"] for t in r["tools"]] == ["zip", "tar-gz", "tar-xz", "copy-path"]


def test_an_image_next_to_a_folder_keeps_image_rings_and_zips_everything(photos, png):
    r = ok(["actions", str(photos), str(png)])
    assert r["category"] == "image" and r["files"] == [str(png)]
    assert r["all"] == [str(photos), str(png)]
    assert next(t for t in r["tools"] if t["id"] == "zip")["all"] is True


# ---------------------------------------------------------------- pack
@pytest.mark.parametrize("fmt,suffix", [("zip", ".zip"), ("tar-gz", ".tar.gz"), ("tar-xz", ".tar.xz")])
def test_folder_round_trip(photos, fmt, suffix):
    r = ok(["tool", fmt, str(photos)])
    out = Path(r["outs"][0])
    assert out.name == photos.name + suffix and out.parent == photos.parent
    assert "1 link left out" in r["detail"]
    extracted = Path(ok(["tool", "extract", str(out)])["outs"][0])
    assert extracted.name == photos.name + " (1)"  # the original folder is in the way
    for rel in ("a.png", "trip/b.jpg", "trip/day 1/c #1.png", "notes.txt", ".thumbnails/hidden.png"):
        assert (extracted / rel).read_bytes() == (photos / rel).read_bytes(), rel
    assert not (extracted / "link.png").exists()


def test_several_items_become_archive_zip(photos, png, pdf):
    out = Path(ok(["tool", "zip", str(photos), str(png), str(pdf)])["outs"][0])
    assert out.name == "Archive.zip"
    names = names_in_zip(out)
    assert {"shot.png", "Doc.pdf", f"{photos.name}/a.png"} <= names


def test_a_name_clash_never_overwrites(photos):
    first = Path(ok(["tool", "zip", str(photos)])["outs"][0])
    before = first.read_bytes()
    second = Path(ok(["tool", "zip", str(photos)])["outs"][0])
    assert second.name == f"{photos.name} (1).zip" and first.read_bytes() == before


def test_a_single_file_is_named_without_its_extension(png):
    assert Path(ok(["tool", "zip", str(png)])["outs"][0]).name == "shot.zip"


def test_no_part_files_are_left_behind(photos):
    ok(["tool", "tar-xz", str(photos)])
    assert not [p for p in photos.parent.iterdir() if p.name.endswith(".part")]


# ---------------------------------------------------------------- extract safety
def _zip_with(tmp_path: Path, name: str, data: bytes = b"x", attr: int | None = None) -> Path:
    p = tmp_path / "evil.zip"
    with zipfile.ZipFile(p, "w") as z:
        info = zipfile.ZipInfo(name)
        if attr is not None:
            info.external_attr = attr << 16
        z.writestr(info, data)
    return p


@pytest.mark.parametrize("member", ["../escape.txt", "/etc/escape.txt", "a/../../escape.txt", "C:/x.txt"])
def test_zip_members_outside_the_folder_are_refused(tmp_path, member):
    r = fail(["tool", "extract", str(_zip_with(tmp_path, member))])
    assert "outside" in r["error"]
    assert not (tmp_path.parent / "escape.txt").exists()
    assert [p.name for p in tmp_path.iterdir()] == ["evil.zip"]  # no temp folder left


def test_zip_symlinks_are_refused(tmp_path):
    r = fail(["tool", "extract", str(_zip_with(tmp_path, "link", b"/etc/passwd", 0o120777))])
    assert "symbolic link" in r["error"]


def test_tar_traversal_is_refused(tmp_path):
    p = tmp_path / "evil.tar.gz"
    with tarfile.open(p, "w:gz") as t:
        info = tarfile.TarInfo("../escape.txt")
        info.size = 1
        t.addfile(info, io.BytesIO(b"x"))
    assert "Refusing" in fail(["tool", "extract", str(p)])["error"]
    assert not (tmp_path.parent / "escape.txt").exists()


def test_extract_refuses_when_the_disk_is_too_small(tmp_path, monkeypatch):
    p = _zip_with(tmp_path, "big.bin", b"\0" * 4096)
    monkeypatch.setattr(eng.ds_archive, "SPARE_BYTES", 10 ** 18)
    assert "disk space" in fail(["tool", "extract", str(p)])["error"]


def test_a_broken_archive_is_a_clean_error(tmp_path):
    p = tmp_path / "broken.zip"
    p.write_bytes(b"not a zip")
    assert "readable" in fail(["tool", "extract", str(p)])["error"]


def test_loose_files_get_their_own_folder(tmp_path, png):
    p = tmp_path / "loose.zip"
    with zipfile.ZipFile(p, "w") as z:
        z.write(png, "one.png")
        z.write(png, "two.png")
    out = Path(ok(["tool", "extract", str(p)])["outs"][0])
    assert out.name == "loose" and sorted(x.name for x in out.iterdir()) == ["one.png", "two.png"]


# ---------------------------------------------------------------- batch
def test_batch_converts_every_image_and_keeps_the_layout(photos):
    r = ok(["tool", "batch-webp", str(photos)])
    root = Path(r["outs"][0])
    assert root.name == f"{photos.name} WEBP" and root.parent == photos.parent
    got = sorted(p.relative_to(root).as_posix() for p in root.rglob("*") if p.is_file())
    assert got == ["a.webp", "trip/b.webp", "trip/day 1/c #1.webp"]
    assert r["title"] == "3 images → WEBP"
    assert sorted(p.name for p in photos.iterdir()) == [".thumbnails", "a.png", "link.png", "notes.txt", "trip"]


def test_batch_skips_images_already_in_the_target_format(photos):
    root = Path(ok(["tool", "batch-jpg", str(photos)])["outs"][0])
    assert sorted(p.name for p in root.rglob("*.jpg")) == ["a.jpg", "c #1.jpg"]


def test_batch_compress(photos):
    root = Path(ok(["tool", "batch-compress", str(photos)])["outs"][0])
    assert root.name == f"{photos.name} Compressed"
    assert len([p for p in root.rglob("*") if p.is_file()]) == 3


def test_batch_on_a_folder_without_images(tmp_path):
    d = tmp_path / "Docs"
    d.mkdir()
    (d / "a.txt").write_text("x")
    assert fail(["tool", "batch-webp", str(d)])["error"] == "No images to convert in Docs"
    assert [p.name for p in tmp_path.iterdir()] == ["Docs"]


def test_batch_with_the_output_folder_setting(photos):
    root = Path(ok(["--output", "folder", "tool", "batch-webp", str(photos)])["outs"][0])
    assert root.parent == photos.parent / "DragShift"


# ---------------------------------------------------------------- undo
def test_undo_trashes_folders_dragshift_created(photos, monkeypatch):
    trashed = []
    monkeypatch.setattr(eng, "_gio_trash", lambda p: trashed.append(p) or True)
    root = ok(["tool", "batch-webp", str(photos)])["outs"][0]
    assert ok(["trash", root])["trashed"] == 1 and trashed == [root]


def test_undo_never_trashes_a_folder_it_did_not_create(photos, monkeypatch):
    monkeypatch.setattr(eng, "_gio_trash", lambda p: pytest.fail("must not trash"))
    assert "didn't create" in fail(["trash", str(photos)])["error"]


def test_the_ledger_is_capped(tmp_path):
    for i in range(eng.LEDGER_KEEP + 20):
        eng.remember_dir(tmp_path / f"d{i}")
    kept = eng.created_dirs()
    assert len(kept) == eng.LEDGER_KEEP and kept[-1] == str(tmp_path / f"d{eng.LEDGER_KEEP + 19}")
