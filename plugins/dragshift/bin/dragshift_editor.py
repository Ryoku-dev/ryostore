#!/usr/bin/env python3
"""dragshift_editor - opens one of DragShift's own editor windows for a file.

Imported by dragshift_engine for the `editor` command; never run on its own.
Each editor is a short-lived process: no tray icon, no IPC socket, no Shift
watcher. The window's Wayland app_id is "dragshift", which the Hyprland rule in
the README floats and centres. Results go to the plugin's glass result cards
over the shell's IPC; if the shell can't be reached, to a desktop notification.
"""
from __future__ import annotations

import json
import importlib
import os
import subprocess
from pathlib import Path

APP_ID = "dragshift"


def _notify(title: str, body: str, icon: str = "", urgent: bool = False) -> None:
    cmd = ["notify-send", "--app-name=DragShift", "-u", "critical" if urgent else "normal"]
    if icon:
        cmd += ["-i", icon]
    try:
        subprocess.run([*cmd, "--", title, body], capture_output=True, timeout=10)
    except (OSError, subprocess.SubprocessError):
        pass  # a missing notifier must never fail the save itself


def _ipc(payload: dict) -> bool:
    """Hand a result to the running shell (service/Main.qml editorResult)."""
    try:
        r = subprocess.run(["qs", "-c", "shell", "ipc", "call", "dragshift", "editorResult",
                            json.dumps(payload, ensure_ascii=False)], capture_output=True, timeout=10)
    except (OSError, subprocess.SubprocessError):
        return False
    return r.returncode == 0


def _announce(label: str, sink: dict, thumb: str = "") -> None:
    if _ipc(sink):
        return
    if sink.get("ok"):
        _notify(sink.get("title", ""), " · ".join(x for x in (sink.get("detail"), sink.get("good")) if x), thumb)
    else:
        _notify(f"{label} failed", sink.get("error", ""), urgent=True)


def _app():
    from PySide6.QtWidgets import QApplication
    app = QApplication.instance()
    if app is None:
        if os.environ.get("QT_QPA_PLATFORM") != "offscreen":
            # The engine's bundled Qt can't load the desktop's qt6ct theme. Through the
            # portal, file pickers are the desktop's own (GTK, Dolphin...); with no portal
            # running Qt falls back to its built-in dialog.
            os.environ["QT_QPA_PLATFORMTHEME"] = "xdgdesktopportal"
        app = QApplication([APP_ID])
        app.setApplicationName("DragShift")
        app.setDesktopFileName(APP_ID)
    return app


def saver(eng, label: str, sink: dict):
    """The `submit` callback editor windows call: run the save, record it in `sink`, notify."""
    def save(action, srcs, fn, working="", extra=""):
        try:
            outs = fn()
            res = eng.report.summarize(action, srcs, outs, extra)
            sink.clear()
            sink.update(ok=True, outs=[str(o) for o in res.outs], title=res.title,
                        detail=res.detail, good=res.good)
            _announce(label, sink, str(res.thumb) if res.thumb else "")
        except Exception as e:  # noqa: BLE001 - shown to the user, never swallowed
            msg = str(e) if isinstance(e, eng.util.UserError) else f"{type(e).__name__}: {e}"
            sink.clear()
            sink.update(ok=False, error=msg)
            _announce(label, sink)
    return save


def open_editor(eng, spec: tuple, files: list[Path], dry: bool = False) -> dict:
    """eng = the running dragshift_engine module (passed in: under `python -I` it is
    __main__, and a fresh import would be a second, unloaded copy).
    spec = (label, class name, takes_list[, kwargs[, module]]); the class comes from
    upstream's tools.py unless a plugin module (bin/ds_pdfwin.py) is named. Blocks until
    the window closes."""
    if dry and not os.environ.get("WAYLAND_DISPLAY") and not os.environ.get("DISPLAY"):
        os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
    app = _app()
    from dragshift import tools  # Qt widgets: only here, never on the headless path
    label, cls_name, takes_list = spec[:3]
    kwargs = spec[3] if len(spec) > 3 else {}
    result: dict = {"ok": True, "outs": [], "title": f"{label} closed", "detail": "", "good": ""}
    save = saver(eng, label, result)

    def notify(action, srcs, outs, extra=""):  # upstream's synchronous path
        save(action, srcs, lambda: outs, extra=extra)

    arg = [str(f) for f in files] if takes_list else str(files[0])
    owner = importlib.import_module(spec[4]) if len(spec) > 4 else tools  # plugin-owned windows
    try:
        w = getattr(owner, cls_name)(arg, notify, **kwargs)
    except Exception as e:  # noqa: BLE001 - detached: stdout goes nowhere, so always say why
        if dry:
            raise
        known = isinstance(e, (*eng.USER_ERRORS, eng.util.UserError))  # e.g. "has no password"
        if not known:
            import traceback
            traceback.print_exc()
        result.update(ok=False, error=str(e) if known else f"Couldn't open {label}: {type(e).__name__}: {e}")
        _announce(label, result)  # detached: stdout goes nowhere, the card is the answer
        return result
    w.submit = save
    if dry:
        title = w.windowTitle()
        w.close()
        return {"ok": True, "window": title}
    w.present()
    app.exec()
    return result
