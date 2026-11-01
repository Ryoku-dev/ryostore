"""The Customize page's data: option keys and hiding (menu.js), themes (themes.js)."""
from __future__ import annotations

import json
import shutil
import subprocess

import pytest

from conftest import PLUGIN, eng

pytestmark = pytest.mark.skipif(shutil.which("node") is None, reason="node not installed")


def js(expr: str, lib: str = "menu.js"):
    src = (PLUGIN / "service" / lib).read_text().replace(".pragma library", "")
    p = subprocess.run(["node", "-e", f"{src}\nconsole.log(JSON.stringify({expr}))"],
                       capture_output=True, text=True, timeout=30)
    assert p.returncode == 0, p.stderr
    return json.loads(p.stdout)


def labels(b) -> list[list[str]]:
    return [[i["label"] for i in r["items"]] for r in b["rings"]]


def test_hiding_an_option_removes_it_from_the_menu():
    b = js('applyHidden(build(["/a/x.png"], true), ["image|convert:WEBP"])')
    assert "WEBP" not in labels(b)[0] and "JPG" in labels(b)[0]


def test_hiding_is_per_kind_of_file():
    b = js('applyHidden(build(["/a/x.pdf"], true), ["image|tool:compress", "image|editor:compress-custom"])')
    assert "Compress" in labels(b)[1], "a PDF keeps its Compress"


def test_pack_options_are_shared_by_every_kind():
    hidden = '["*|tool:zip"]'
    for path in ("/a/x.png", "/a/x.pdf", "/a/x.mp4"):
        b = js(f'applyHidden(build(["{path}"], true), {hidden})')
        assert all("ZIP" not in ring for ring in labels(b)), path


def test_a_ring_with_everything_off_disappears():
    keys = js('build(["/a/x.zip"], true).rings[0].items.map(i => itemKey("archive", i))')
    b = js(f'applyHidden(build(["/a/x.zip"], true), {json.dumps(keys)})')
    assert b["rings"] == []


def test_nothing_hidden_leaves_the_menu_as_it_was():
    assert js('applyHidden(build(["/a/x.png"], true), [])') == js('build(["/a/x.png"], true)')


def test_the_catalogue_covers_every_menu_option():
    keys = {i["key"] for g in js("catalogue()") for i in g["items"]}
    for path in ("/a/x.png", "/a/x.pdf", "/a/x.docx", "/a/x.txt", "/a/x.mp4", "/a/x.mp3", "/a/x.zip", "/a/dir"):
        b = js(f'build(["{path}", "/a/y.pdf"], true)' if path.endswith(".pdf") else f'build(["{path}"], true)')
        for ring in b["rings"]:
            for it in ring["items"]:
                key = ("*" if it.get("all") else b["category"]) + "|" + it["kind"] + ":" + it["id"]
                assert key in keys, (path, key)
    for it in js('buildText("hello").rings[0].items'):
        assert "text-selection|" + it["kind"] + ":" + it["id"] in keys


def test_catalogue_keys_are_unique():
    keys = [i["key"] for g in js("catalogue()") for i in g["items"]]
    assert len(keys) == len(set(keys))


def test_transparent_is_the_default_and_first_theme():
    assert js("THEMES[0].id", "themes.js") == "transparent"
    assert js('byId("no-such").id', "themes.js") == "transparent"
    assert js('resolve("transparent", null).themed', "themes.js") is False


def test_matugen_reads_the_live_scheme():
    look = js('resolve("matugen", {cardTop: "#101010", accent: "#ff0000", bright: "#eeeeee"})', "themes.js")
    assert look["themed"] and look["tint"] == "#101010" and look["accent"] == "#ff0000" and look["ink"] == "#eeeeee"


def test_every_coloured_theme_has_tint_accent_and_ink():
    for t in js("THEMES", "themes.js"):
        if t["id"] in ("transparent", "matugen"):
            continue
        look = js(f'resolve("{t["id"]}", null)', "themes.js")
        assert look["themed"] and all(look[k].startswith("#") and len(look[k]) == 7 for k in ("tint", "accent", "ink"))


def test_hover_label_reads_on_every_theme_and_on_light_or_dark_matugen():
    schemes = ['{cardTop: "#141218", accent: "#d0bcff", bright: "#e6e0e9"}',   # dark wallpaper
               '{cardTop: "#fdf8ff", accent: "#6750a4", bright: "#1d1b20"}',   # light wallpaper
               '{cardTop: "#1a1a10", accent: "#fff0a0", bright: "#eeeedd"}']   # pale accent
    looks = [f'resolve("matugen", {s})' for s in schemes]
    looks += [f'resolve("{t["id"]}", null)' for t in js("THEMES", "themes.js") if t["id"] not in ("transparent", "matugen")]
    for look in looks:
        ratio = js(f"contrast(hoverInk({look}), hoverColor({look}))", "themes.js")
        assert ratio >= 3.0, (look, ratio)


def test_body_labels_read_on_every_coloured_theme():
    for t in js("THEMES", "themes.js"):
        if t["id"] in ("transparent", "matugen"):
            continue
        ratio = js(f'contrast(resolve("{t["id"]}", null).ink, resolve("{t["id"]}", null).tint)', "themes.js")
        assert ratio >= 4.5, (t["id"], ratio)
