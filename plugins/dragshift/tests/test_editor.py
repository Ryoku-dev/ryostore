"""bin/dragshift_editor.py: the editors save through upstream's own windows, offscreen."""
from __future__ import annotations

import json
import subprocess
from pathlib import Path

import pytest

from conftest import eng

import dragshift_editor as ed  # noqa: E402


@pytest.fixture
def notes(monkeypatch):
    """Editor results go to the shell's glass cards; record them instead."""
    sent = []
    monkeypatch.setattr(ed, "_ipc", lambda payload: sent.append((payload.get("title") or payload.get("error"),
                                                                 payload["ok"] is False)) or True)
    return sent


class ClickSave:
    """Stands in for app.exec(): presses the window's own primary button, like a user would."""

    def __init__(self, real):
        self.real = real

    def exec(self):
        from dragshift.tools import ToolWindow
        wins = [w for w in self.real.topLevelWidgets() if isinstance(w, ToolWindow) and w.isVisible()]
        assert len(wins) == 1
        wins[0].primary_btn.click()
        return 0


def test_crop_saves_a_new_file_end_to_end(png, notes, monkeypatch):
    real = ed._app()
    monkeypatch.setattr(ed, "_app", lambda: ClickSave(real))
    r = ed.open_editor(eng, eng.IMAGE_EDITORS["crop"], [png])
    assert r["ok"] is True, r
    out = Path(r["outs"][0])
    assert out.exists() and out != png and "Cropped" in out.name
    assert notes and notes[0][1] is False


def test_saver_records_success_and_notifies(png, notes):
    sink = {}
    out = eng.convert.convert(png, "image", "JPG")
    ed.saver(eng, "Crop", sink)("tool:Crop", [str(png)], lambda: out)
    assert sink["ok"] is True and sink["outs"] == [str(out[0])]
    assert notes == [(sink["title"], False)]


def test_saver_reports_a_user_error(png, notes):
    sink = {}

    def bad():
        raise eng.util.UserError("Nothing selected")
    ed.saver(eng, "Redact", sink)("tool:Redact", [str(png)], bad)
    assert sink == {"ok": False, "error": "Nothing selected"}
    assert notes == [("Nothing selected", True)]


def test_saver_reports_a_crash_with_its_type(png, notes):
    sink = {}
    ed.saver(eng, "Edit", sink)("tool:Edit", [str(png)], lambda: 1 / 0)
    assert sink["ok"] is False and sink["error"].startswith("ZeroDivisionError")


def test_notify_survives_a_missing_notifier(monkeypatch):
    def gone(*a, **k):
        raise FileNotFoundError("notify-send")
    monkeypatch.setattr(subprocess, "run", gone)
    ed._notify("t", "b", icon="/x.png", urgent=True)  # must not raise


def test_notify_passes_title_and_body_after_a_double_dash(monkeypatch):
    seen = {}
    monkeypatch.setattr(subprocess, "run", lambda cmd, **k: seen.setdefault("cmd", cmd))
    ed._notify("-t", "-b")
    cmd = seen["cmd"]
    assert cmd[0] == "notify-send" and cmd[-3:] == ["--", "-t", "-b"]


def test_results_fall_back_to_a_notification_without_the_shell(png, monkeypatch):
    shown = []
    monkeypatch.setattr(ed, "_ipc", lambda payload: False)
    monkeypatch.setattr(ed, "_notify", lambda title, body, icon="", urgent=False: shown.append(title))
    out = eng.convert.convert(png, "image", "JPG")
    ed.saver(eng, "Crop", {})("tool:Crop", [str(png)], lambda: out)
    assert len(shown) == 1


def test_ipc_sends_one_json_argument(monkeypatch):
    seen = {}

    class R:
        returncode = 0
    monkeypatch.setattr(subprocess, "run", lambda cmd, **k: seen.setdefault("cmd", cmd) and R())
    assert ed._ipc({"ok": True, "title": "x y", "outs": ["/a b.png"]}) is True
    cmd = seen["cmd"]
    assert cmd[:6] == ["qs", "-c", "shell", "ipc", "call", "dragshift"] and cmd[6] == "editorResult"
    assert json.loads(cmd[7])["outs"] == ["/a b.png"]


def test_ipc_failure_is_reported_not_raised(monkeypatch):
    def gone(*a, **k):
        raise FileNotFoundError("qs")
    monkeypatch.setattr(subprocess, "run", gone)
    assert ed._ipc({"ok": True}) is False
