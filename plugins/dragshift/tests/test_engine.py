"""bin/dragshift_engine.py: every command the bar panel can send, in-process."""
from __future__ import annotations

import hashlib
from pathlib import Path

import pytest
from PIL import Image

from conftest import ENGINE, eng


def sha(p: Path) -> str:
    return hashlib.sha256(p.read_bytes()).hexdigest()


def ok(argv: list[str], **kw) -> dict:
    r = eng.run(argv, **kw)
    assert r["ok"] is True, r
    return r


def fail(argv: list[str], **kw) -> dict:
    r = eng.run(argv, **kw)
    assert r["ok"] is False, r
    assert r["error"], r
    return r


# ---------------------------------------------------------------- doctor
def test_doctor_reports_a_healthy_pinned_engine():
    r = ok(["doctor"])
    assert r["pinned"] is True
    assert r["sha"] == r["pin"]
    assert r["heif"] is True
    assert r["editors"] is True
    assert Path(r["engine"]).resolve() == ENGINE.resolve()


def test_doctor_flags_an_engine_at_the_wrong_commit():
    r = eng.doctor(ENGINE, pin="0" * 40)
    assert r["ok"] is False
    assert r["pinned"] is False
    assert "git -C" in r["fix"] and "0" * 40 in r["fix"]


def test_doctor_flags_local_edits_in_the_engine(monkeypatch):
    monkeypatch.setattr(eng, "git_dirty", lambda path: True)
    r = eng.doctor(ENGINE)
    assert r["ok"] is False and "local edits" in r["error"] and "git -C" in r["fix"]


def test_doctor_flags_a_missing_engine(tmp_path):
    r = eng.doctor(tmp_path / "nope")
    assert r["ok"] is False
    assert "fix" in r


# ---------------------------------------------------------------- actions
def test_actions_for_an_image(png):
    r = ok(["actions", str(png)])
    assert r["category"] == "image"
    ids = [c["id"] for c in r["convert"]]
    assert "JPG" in ids and "PNG" not in ids  # never offer the format it already is
    assert {"compress", "strip-location"} <= {t["id"] for t in r["tools"]}
    assert {"crop", "annotate", "redact", "edit", "add-bg"} <= {e["id"] for e in r["editors"]}


def test_actions_for_a_pdf_offers_merge_only_with_two(pdf, pdf2):
    one = ok(["actions", str(pdf)])
    assert one["category"] == "pdf"
    assert {"protect", "metadata"} <= {e["id"] for e in one["editors"]}
    assert "merge" not in {t["id"] for t in one["tools"]}
    two = ok(["actions", str(pdf), str(pdf2)])
    assert "merge" in {t["id"] for t in two["tools"]}


def test_single_file_editors_say_so_when_several_are_dropped(png, jpg):
    one = {e["id"]: e for e in ok(["actions", str(png)])["editors"]}
    two = {e["id"]: e for e in ok(["actions", str(png), str(jpg)])["editors"]}
    assert one["crop"]["label"] == "Crop"
    assert "first" in two["crop"]["label"]
    assert two["compress-custom"]["label"] == "Compress…"  # takes every file


def test_actions_for_two_images_offers_a_combined_pdf(png, jpg):
    r = ok(["actions", str(png), str(jpg)])
    pdf = next(c for c in r["convert"] if c["id"] == "PDF")
    assert "1 PDF" in pdf["hint"]


@pytest.mark.parametrize("fixture,cat", [("docx", "docx"), ("txt", "text")])
def test_actions_for_documents(request, fixture, cat):
    r = ok(["actions", str(request.getfixturevalue(fixture))])
    assert r["category"] == cat
    assert r["convert"] and r["editors"] == []
    assert [t["id"] for t in r["tools"]] == ["zip", "tar-gz", "tar-xz", "copy-path"]  # every drop can be archived


def test_actions_skips_files_of_another_kind(png, pdf):
    r = ok(["actions", str(png), str(pdf)])
    assert r["category"] == "image"
    assert r["files"] == [str(png)]
    assert r["skipped"] == [str(pdf)]


def test_an_unsupported_file_can_only_be_archived(tmp_path):
    p = tmp_path / "thing.xyz"
    p.write_bytes(b"?")
    r = ok(["actions", str(p)])
    assert r["category"] == "any" and r["convert"] == [] and r["editors"] == []
    assert "isn't a tool" in fail(["tool", "compress", str(p)])["error"]


def test_actions_rejects_missing_and_relative_paths(tmp_path):
    assert "No usable" in fail(["actions", str(tmp_path / "gone.png")])["error"]
    fail(["actions", "relative.png"])
    fail(["actions"])


def test_a_lone_directory_is_a_folder(tmp_path):
    assert ok(["actions", str(tmp_path)])["category"] == "folder"


def test_one_bad_item_does_not_sink_the_batch(tmp_path, png, jpg):
    odd = tmp_path / "thing.xyz"
    odd.write_bytes(b"?")
    r = ok(["actions", str(tmp_path), str(odd), str(tmp_path / "gone.png"), str(png), str(jpg)])
    assert r["category"] == "image" and r["files"] == [str(png), str(jpg)]
    assert len(r["skipped"]) == 3


def test_convert_skips_bad_items_too(tmp_path, png):
    r = ok(["convert", "--to", "JPG", str(tmp_path), str(png)])
    assert len(r["outs"]) == 1


# ---------------------------------------------------------------- convert
@pytest.mark.parametrize("target", ["JPG", "WEBP", "PDF", "HEIC", "AVIF", "ICO", "TIFF", "BMP", "GIF"])
def test_convert_png(png, target):
    before = sha(png)
    r = ok(["convert", "--to", target, str(png)])
    out = Path(r["outs"][0])
    assert out.exists() and out.parent == png.parent
    assert out.suffix.lower() == "." + target.lower()
    assert sha(png) == before  # the original is never touched
    assert r["title"]


def test_convert_two_images_to_one_pdf(png, jpg):
    r = ok(["convert", "--to", "PDF", str(png), str(jpg)])
    assert len(r["outs"]) == 1
    assert eng.convert.fitz.open(r["outs"][0]).page_count == 2


@pytest.mark.parametrize("target,n", [("PNG", 2), ("JPG", 2), ("TXT", 1), ("DOCX", 1)])
def test_convert_pdf(pdf, target, n):
    assert len(ok(["convert", "--to", target, str(pdf)])["outs"]) == n


def test_convert_docx_and_text(docx, txt):
    assert ok(["convert", "--to", "PDF", str(docx)])["outs"][0].endswith(".pdf")
    assert ok(["convert", "--to", "TXT", str(docx)])["outs"][0].endswith(".txt")
    assert ok(["convert", "--to", "PDF", str(txt)])["outs"][0].endswith(".pdf")
    assert ok(["convert", "--to", "DOCX", str(txt)])["outs"][0].endswith(".docx")


def test_convert_rejects_a_target_the_kind_cannot_take(pdf):
    assert "can't" in fail(["convert", "--to", "HEIC", str(pdf)])["error"].lower()


def test_convert_never_overwrites(png):
    a = ok(["convert", "--to", "JPG", str(png)])["outs"][0]
    b = ok(["convert", "--to", "JPG", str(png)])["outs"][0]
    assert a != b and Path(a).exists() and Path(b).exists()


def test_convert_handles_a_hostile_filename(weird):
    r = ok(["convert", "--to", "JPG", str(weird)])
    assert Path(r["outs"][0]).exists()


def test_output_folder_mode(png):
    r = ok(["--output", "folder", "convert", "--to", "JPG", str(png)])
    assert Path(r["outs"][0]).parent == png.parent / "DragShift"


def test_output_mode_is_validated(png):
    fail(["--output", "/etc", "convert", "--to", "JPG", str(png)])


# ---------------------------------------------------------------- tools
def test_compress_image_gets_smaller(jpg):
    r = ok(["tool", "compress", str(jpg)])
    assert Path(r["outs"][0]).stat().st_size < jpg.stat().st_size


def test_compress_under_a_target_size(jpg):
    r = ok(["tool", "compress-500kb", str(jpg)])
    assert Path(r["outs"][0]).stat().st_size <= 500 * 1024


def test_resize_half(jpg):
    out = ok(["tool", "half", str(jpg)])["outs"][0]
    assert Image.open(out).size == (800, 500)


def test_resize_long_side(jpg):
    out = ok(["tool", "long-1280", str(jpg)])["outs"][0]
    assert max(Image.open(out).size) == 1280


def test_strip_location_keeps_the_camera(jpg):
    out = ok(["tool", "strip-location", str(jpg)])["outs"][0]
    exif = Image.open(out).getexif()
    assert exif.get(0x010F) == "TestCam"
    assert not exif.get_ifd(0x8825)


def test_strip_all_metadata(jpg):
    out = ok(["tool", "strip-all", str(jpg)])["outs"][0]
    assert len(Image.open(out).getexif()) == 0


def test_tools_run_on_every_file(png, jpg):
    assert len(ok(["tool", "compress", str(png), str(jpg)])["outs"]) == 2


@pytest.mark.parametrize("tool,n", [("compress", 1), ("split", 2), ("rotate", 1), ("extract", 1), ("strip-all", 1)])
def test_pdf_tools(pdf, tool, n):
    assert len(ok(["tool", tool, str(pdf)])["outs"]) == n


def test_pdf_merge(pdf, pdf2):
    out = ok(["tool", "merge", str(pdf), str(pdf2)])["outs"][0]
    assert eng.convert.fitz.open(out).page_count == 3


def test_pdf_merge_needs_two(pdf):
    fail(["tool", "merge", str(pdf)])


def test_unknown_tool_for_the_kind(png):
    fail(["tool", "split", str(png)])


def test_extract_reports_a_pdf_without_images(pdf2):
    assert "No images" in fail(["tool", "extract", str(pdf2)])["error"]


# ---------------------------------------------------------------- trash (undo)
def test_trash_moves_outputs_away(png, monkeypatch):
    calls = []
    monkeypatch.setattr(eng, "_gio_trash", lambda p: calls.append(p) or True)
    out = ok(["convert", "--to", "JPG", str(png)])["outs"][0]
    r = ok(["trash", out])
    assert r["trashed"] == 1 and calls == [out]


def test_trash_reports_files_it_could_not_move(png, monkeypatch):
    monkeypatch.setattr(eng, "_gio_trash", lambda p: False)
    out = ok(["convert", "--to", "JPG", str(png)])["outs"][0]
    r = fail(["trash", out])
    assert "1 of 1" in r["error"] and Path(out).exists()


def test_trash_reports_an_already_missing_file(tmp_path, monkeypatch):
    monkeypatch.setattr(eng, "_gio_trash", lambda p: True)
    fail(["trash", str(tmp_path / "gone.jpg")])


def test_trash_never_removes_a_users_own_dragshift_folder(tmp_path, png, monkeypatch):
    calls = []
    monkeypatch.setattr(eng, "_gio_trash", lambda p: calls.append(p) or Path(p).unlink() is None)
    out = ok(["--output", "folder", "convert", "--to", "JPG", str(png)])["outs"][0]
    ok(["trash", out])
    assert calls == [out]  # the now-empty DragShift folder stays


def test_trash_removes_the_folder_extract_made(pdf, monkeypatch):
    import shutil
    calls = []

    def fake(p):
        calls.append(p)
        P = Path(p)
        shutil.rmtree(P) if P.is_dir() else P.unlink()
        return True
    monkeypatch.setattr(eng, "_gio_trash", fake)
    outs = ok(["tool", "extract", str(pdf)])["outs"]
    folder = Path(outs[0]).parent
    ok(["trash", *outs])
    assert str(folder) in calls and not folder.exists()


def test_trash_refuses_relative_paths():
    fail(["trash", "x.jpg"])


# ---------------------------------------------------------------- editors
@pytest.mark.parametrize("editor", ["crop", "edit", "annotate", "redact", "add-bg",
                                    "compress-custom", "resize-custom", "metadata"])
def test_every_image_editor_constructs(png, editor):
    """Catches an upstream signature change before the user ever clicks."""
    r = ok(["editor", "--dry", editor, str(png)])
    assert "DragShift" in r["window"]


def test_pdf_metadata_editor_constructs(pdf):
    ok(["editor", "--dry", "metadata", str(pdf)])


def test_pdf_protect_editor_constructs(pdf):
    ok(["editor", "--dry", "protect", str(pdf)])


def test_an_image_editor_refuses_a_pdf(pdf):
    fail(["editor", "--dry", "crop", str(pdf)])


def test_editor_dry_run_does_not_need_a_window_system(png, monkeypatch):
    monkeypatch.setenv("QT_QPA_PLATFORM", "offscreen")
    ok(["editor", "--dry", "crop", str(png)])


# ---------------------------------------------------------------- the CLI surface
def test_unknown_command():
    fail(["frobnicate"])


def test_main_prints_one_json_line_and_sets_the_exit_code(png, capsys):
    assert eng.main(["actions", str(png)]) == 0
    out = capsys.readouterr().out.strip().splitlines()
    assert len(out) == 1 and '"ok": true' in out[0]
    assert eng.main(["nope"]) == 1


def test_an_unexpected_crash_still_answers_in_json(png, monkeypatch):
    def boom(*a, **k):
        raise RuntimeError("kaboom")
    monkeypatch.setattr(eng.convert, "convert", boom)
    r = fail(["convert", "--to", "JPG", str(png)])
    assert "kaboom" in r["error"]


# ---------------------------------------------------------------- reveal (show in folder)
def test_reveal_asks_the_file_manager_with_a_safe_uri(tmp_path, monkeypatch):
    p = tmp_path / "a, b's [1].png"
    p.write_bytes(b"x")
    calls = []
    monkeypatch.setattr(eng, "_spawn", lambda cmd: calls.append(cmd) or True)
    assert ok(["reveal", str(p)])["how"] == "filemanager"
    arg = calls[0][-2]
    assert arg.startswith("array:string:file://") and "," not in arg[len("array:string:"):]
    assert "'" not in arg


def test_reveal_falls_back_to_opening_the_folder(png, monkeypatch):
    calls = []
    monkeypatch.setattr(eng, "_spawn", lambda cmd: calls.append(cmd) or cmd[0] == "xdg-open")
    assert ok(["reveal", str(png)])["how"] == "folder"
    assert calls[-1] == ["xdg-open", str(png.parent)]


def test_reveal_needs_an_existing_absolute_path():
    fail(["reveal", "rel.png"])
    fail(["reveal"])
