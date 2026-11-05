"""service/menu.js (run in node) must offer exactly what the engine can do."""
from __future__ import annotations

import json
import shutil
import subprocess

import pytest

from conftest import PLUGIN, eng

pytestmark = pytest.mark.skipif(shutil.which("node") is None, reason="node not installed")


def js(expr: str):
    src = (PLUGIN / "service" / "menu.js").read_text().replace(".pragma library", "")
    p = subprocess.run(["node", "-e", f"{src}\nconsole.log(JSON.stringify({expr}))"],
                       capture_output=True, text=True, timeout=30)
    assert p.returncode == 0, p.stderr
    return json.loads(p.stdout)


EXTS = sorted(eng.util.IMAGE_EXTS | eng.util.PDF_EXTS | eng.util.DOCX_EXTS | eng.util.TEXT_EXTS)


@pytest.mark.parametrize("ext", EXTS)
def test_category_and_targets_match_the_engine(ext):
    name = f"/x/file{ext}"
    cat = eng.util.category(name)
    assert js(f"category({json.dumps(name)})") == cat
    want = eng.convert.targets_for(cat, ext)
    assert js(f"targetsFor({json.dumps(cat)}, {json.dumps(ext.lstrip('.'))}, true)") == want


def test_unknown_files_and_folders():
    assert js('category("/a/thing.xyz")') == ""
    assert js('category("/a/Makefile")') == "folder"  # a guess until stat answers
    assert js('category("/a/Makefile", {"/a/Makefile": "file"})') == ""
    assert js('category("/a/v1.2", {"/a/v1.2": "dir"})') == "folder"
    assert js('category("/a/.png")') == ""  # a dotfile, not a PNG
    b = js('build(["/a/thing.xyz"], true)')
    assert b["category"] == "any" and [r["name"] for r in b["rings"]] == ["Archive"]


@pytest.mark.parametrize("name,cat", [("a.zip", "archive"), ("a.tar.gz", "archive"), ("a.TGZ", "archive"),
                                      ("a.tar.xz", "archive"), ("a.mov", "video"), ("a.opus", "audio"),
                                      ("a.gz", ""), (".zip", "")])
def test_new_kinds_match_the_engine(tmp_path, name, cat):
    assert js(f'category("/a/{name}")') == cat
    p = tmp_path / name
    p.write_bytes(b"x")
    assert (eng.kind_of(p) or "") == cat


@pytest.mark.parametrize("cat,ext", [("video", "mov"), ("video", "mp4"), ("video", "m4v"),
                                     ("audio", "wav"), ("audio", "ogg"), ("audio", "mp3")])
def test_media_targets_match_the_engine(cat, ext):
    assert js(f'targetsFor("{cat}", "{ext}", true)') == eng.ds_media.targets_for(cat, "." + ext)


def test_heic_hidden_without_heif():
    assert "HEIC" not in js('targetsFor("image", "png", false)')


def test_every_ring_item_is_something_the_engine_accepts():
    for paths in (["/a/p.png"], ["/a/p.png", "/a/q.jpg"], ["/a/d.pdf"], ["/a/d.pdf", "/a/e.pdf"],
                  ["/a/w.docx"], ["/a/t.md"], ["/a/v.mov"], ["/a/s.wav"], ["/a/x.zip"], ["/a/Photos"],
                  ["/a/thing.xyz"]):
        b = js(f"build({json.dumps(paths)}, true)")
        cat = b["category"]
        for ring in b["rings"]:
            for it in ring["items"]:
                if it.get("all"):
                    assert it["id"] in eng.any_tools(), it
                elif it["kind"] == "convert":
                    assert it["id"] in eng.targets_for(cat, "." + paths[0].rsplit(".", 1)[1])
                elif it["kind"] == "tool":
                    assert it["id"] == "merge" or it["id"] in eng.tools_for(cat) \
                        or it["id"] in eng.job_tools_for(cat), (cat, it)
                else:
                    assert it["id"] in eng.editors_for(cat), it


def test_rings_fit_the_shader():
    for paths in (["/a/p.png"], ["/a/d.pdf"], ["/a/d.pdf", "/a/e.pdf"], ["/a/v.mov"], ["/a/Photos"]):
        for ring in js(f"build({json.dumps(paths)}, true)")["rings"]:
            assert 2 <= len(ring["items"]) <= 12, (paths, ring["name"])


def test_folder_rings():
    b = js('build(["/a/Photos", "/a/Docs"], true)')
    assert b["category"] == "folder" and b["files"] == ["/a/Photos", "/a/Docs"]
    assert [r["name"] for r in b["rings"]] == ["Archive", "Images"]
    assert [i["label"] for i in b["rings"][0]["items"]] == ["ZIP", "TAR.GZ", "TAR.XZ", "Copy path"]
    mixed = js('build(["/a/Photos", "/a/p.png"], true)')
    assert mixed["category"] == "image" and mixed["files"] == ["/a/p.png"]
    assert mixed["rings"][-1]["name"] == "Archive" and all(i["all"] for i in mixed["rings"][-1]["items"])


def test_rings_follow_utsuri_order():
    img = js('build(["/a/p.png"], true)')
    assert [r["name"] for r in img["rings"]] == ["Convert", "Tools", "Archive"]
    assert [i["label"] for i in img["rings"][1]["items"]] == \
        ["Compress", "Resize", "Crop", "Edit", "Annotate", "Redact", "Add BG", "Metadata", "Copy", "Text"]
    pdfs = js('build(["/a/d.pdf", "/a/e.pdf"], true)')
    assert [r["name"] for r in pdfs["rings"]] == ["Convert", "Tools", "Pages", "Archive"]
    assert [i["label"] for i in pdfs["rings"][1]["items"]] == \
        ["Compress", "Split", "Rotate", "Merge", "Extract", "Numbers", "Gray", "Flatten"]
    assert [i["label"] for i in pdfs["rings"][2]["items"]] == \
        ["Organize", "Watermark", "Protect", "Unlock", "Metadata", "Halves", "Chapters", "Searchable"]
    assert [r["name"] for r in js('build(["/a/w.docx"], true)')["rings"]] == ["Convert", "Archive"]


def test_mixed_drop_keeps_the_first_supported_kind():
    b = js('build(["/a/x.xyz", "/a/p.png", "/a/d.pdf", "/a/q.jpg"], true)')
    assert b["category"] == "image" and b["files"] == ["/a/p.png", "/a/q.jpg"]
    pdf_hint = next(i for i in b["rings"][0]["items"] if i["id"] == "PDF")["hint"]
    assert pdf_hint == "2 images → 1 PDF"


@pytest.mark.parametrize("n", [0, 5, 1023, 1024, 1536, 10 * 1024 ** 2, 3 * 1024 ** 3])
def test_human_size_matches_the_engine(n):
    assert js(f"humanSize({n})") == eng.util.human_size(n)


def test_every_one_click_tool_has_a_working_label():
    """Main.qml's _toolVerbs names the job on its card; a missing id falls back silently."""
    import re
    qml = (PLUGIN / "service" / "Main.qml").read_text()
    table = qml[qml.index("_toolVerbs"):qml.index("})", qml.index("_toolVerbs"))]
    verbs = set(re.findall(r'"?([\w-]+)"?\s*:\s*"', table))
    drops = (["/a/p.png"], ["/a/p.png", "/a/q.png"], ["/a/d.pdf"], ["/a/d.pdf", "/a/e.pdf"],
             ["/a/v.mov"], ["/a/s.wav"], ["/a/Photos"], ["/a/x.zip"])
    ids = {i["id"] for paths in drops for r in js(f"build({json.dumps(paths)}, true)")["rings"]
           for i in r["items"] if i.get("kind") == "tool"}
    assert ids and not ids - verbs, sorted(ids - verbs)


def test_dragged_text_gets_a_text_ring():
    b = js('buildText("Hôm nay trời đẹp quá")')
    assert b["category"] == "text-selection" and b["files"] == []
    (ring,) = b["rings"]
    assert [i["label"] for i in ring["items"]] == ["Translate", "Copy"]
    assert [i["kind"] for i in ring["items"]] == ["oumu", "text"]
    assert all(i["glyph"] and i["hint"] for i in ring["items"])


def test_translate_is_always_offered_and_blank_text_gets_no_ring():
    # Without Oumu the slice stays; picking it explains how to get Oumu (Main.qml).
    b = js('buildText("hello world")')
    assert [i["label"] for i in b["rings"][0]["items"]] == ["Translate", "Copy"]
    assert js('buildText("   ")')["rings"] == []


def test_word_count_for_the_hub():
    assert js('wordCount("one two  three")') == 3
    assert js('wordCount("")') == 0
