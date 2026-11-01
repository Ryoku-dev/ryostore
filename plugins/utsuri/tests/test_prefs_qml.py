"""Prefs.qml and the Matugen theme, run for real in Quickshell (offscreen) against
Ryoku's own Scheme singleton, with Ryoku's colour files in a temp folder."""
from __future__ import annotations

import json
import os
import shutil
import subprocess

import pytest

from conftest import PLUGIN

pytestmark = pytest.mark.skipif(shutil.which("qs") is None or not os.path.isdir("/usr/lib/qt6/qml/Ryoku/PluginKit"),
                                reason="needs Quickshell and Ryoku's PluginKit")

DARK = {"surface": "#141218", "primary": "#d0bcff", "onSurface": "#e6e0e9", "surfaceContainer": "#211f26",
        "surfaceContainerLowest": "#0f0d13", "onSurfaceVariant": "#cac4d0", "outlineVariant": "#49454f"}


def run_probe(t, prefs_text: str) -> dict:
    """Run the probe with this prefs.json at start; -> {step: report}."""
    for d in ("cache/ryoku", "config/ryoku", "state", "cfg"):
        (t / d).mkdir(parents=True, exist_ok=True)
    (t / "cache" / "ryoku" / "colors.json").write_text(json.dumps(DARK))
    (t / "config" / "ryoku" / "theme.json").write_text(json.dumps({"followWallpaper": True}))
    (t / "state" / "prefs.json").write_text(prefs_text)
    shutil.copy(PLUGIN / "tests" / "qml" / "prefs_probe.qml", t / "cfg" / "shell.qml")
    shutil.copytree(PLUGIN / "service", t / "cfg" / "service", dirs_exist_ok=True)
    env = dict(os.environ, QT_QPA_PLATFORM="offscreen", XDG_CACHE_HOME=str(t / "cache"),
               XDG_CONFIG_HOME=str(t / "config"), PROBE_DIR=str(t / "state"))
    p = subprocess.run(["qs", "-p", str(t / "cfg" / "shell.qml")], env=env, capture_output=True, text=True, timeout=60)
    out = {}
    for line in (p.stdout + p.stderr).splitlines():
        if "PROBE " in line:
            d = json.loads(line.split("PROBE ", 1)[1])
            out[d["step"]] = d
    assert "file" in out, (p.stdout + p.stderr)[-3000:]
    out["disk"] = (t / "state" / "prefs.json").read_text()
    return out


@pytest.fixture(scope="module")
def steps(tmp_path_factory) -> dict:
    return run_probe(tmp_path_factory.mktemp("probe"), json.dumps({"theme": "matugen", "hidden": []}))


@pytest.mark.parametrize("text", ["{not json", "", json.dumps({"theme": "no-such-theme", "hidden": "not-a-list"}),
                                  json.dumps({"theme": 7, "hidden": [1, None, "image|convert:PNG"]})])
def test_a_broken_or_odd_prefs_file_falls_back_to_defaults(tmp_path, text):
    s = run_probe(tmp_path, text)["start"]
    assert s["theme"] == "transparent" and s["themed"] is False
    assert s["hidden"] == (["image|convert:PNG"] if "PNG" in text else [])


def test_turned_off_options_survive_a_restart(tmp_path):
    s = run_probe(tmp_path, json.dumps({"theme": "rose", "hidden": ["*|tool:zip", "image|convert:BMP"]}))["start"]
    assert s["theme"] == "rose" and s["hidden"] == ["*|tool:zip", "image|convert:BMP"]


def test_matugen_takes_the_wallpaper_scheme(steps):
    s = steps["start"]
    assert s["theme"] == "matugen" and s["themed"]
    assert (s["tint"], s["accent"], s["ink"]) == (DARK["surface"], DARK["primary"], DARK["onSurface"])


def test_matugen_follows_a_new_wallpaper_live(steps):
    s = steps["wallpaper-changed"]
    assert (s["tint"], s["accent"], s["ink"]) == ("#fdf8ff", "#6750a4", "#1d1b20")


def test_a_half_written_palette_never_paints_garbage(steps):
    s = steps["colors-half-written"]
    for k in ("tint", "accent", "ink"):
        assert len(s[k]) == 7 and s[k].startswith("#"), s


def test_choices_are_saved_to_the_file(steps):
    s = steps["after-setters"]
    want = ["*|tool:zip", "pdf|tool:gray"]
    assert s["theme"] == "ocean" and s["hidden"] == want
    saved = json.loads(steps["disk"])
    assert saved["theme"] == "ocean" and saved["hidden"] == want, "a quick toggle was lost on disk"


def test_saving_does_not_loop(steps):
    assert steps["idle"]["writes"] == 0, "prefs.json kept being rewritten with nothing changing"
