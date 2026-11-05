"""bin/utsuri: the stdlib launcher the QML runs. End to end, as a subprocess."""
from __future__ import annotations

import json
import os
import subprocess
from pathlib import Path

import pytest

from conftest import BIN, ENGINE

LAUNCHER = BIN / "utsuri"


def call(*args: str, engine: Path | str = ENGINE, env: dict | None = None) -> tuple[int, dict]:
    e = {k: v for k, v in os.environ.items() if k != "UTSURI_ENGINE"}
    e.update(env or {})
    p = subprocess.run([str(LAUNCHER), "--engine", str(engine), *args],
                       capture_output=True, text=True, env=e, timeout=120)
    lines = [l for l in p.stdout.splitlines() if l.strip()]
    assert len(lines) == 1, (p.stdout, p.stderr)
    return p.returncode, json.loads(lines[0])


def test_launcher_is_an_executable_script():
    assert os.access(LAUNCHER, os.X_OK)
    assert LAUNCHER.read_text().startswith("#!/usr/bin/env python3")


def test_launcher_runs_doctor_through_the_engine_venv():
    code, r = call("doctor")
    assert code == 0 and r["ok"] is True
    assert ".venv" in r["python"]


def test_launcher_explains_a_missing_engine(tmp_path):
    code, r = call("doctor", engine=tmp_path / "nowhere")
    assert code == 1 and r["ok"] is False
    assert "setup.sh" in r["fix"]


@pytest.mark.skipif(not ENGINE.is_relative_to(Path.home()), reason="engine is outside ~")
def test_launcher_expands_a_tilde_engine_path():
    home = Path.home()
    rel = "~/" + str(ENGINE.relative_to(home))
    code, r = call("doctor", engine=rel)
    assert code == 0, r


def test_launcher_converts_end_to_end(png):
    code, r = call("convert", "--to", "WEBP", str(png))
    assert code == 0 and Path(r["outs"][0]).exists()


def test_launcher_without_a_command():
    code, r = call()
    assert code == 1 and r["ok"] is False


def test_sigterm_unwinds_cleanly(jpg):
    """Cancel = SIGTERM. The engine must exit, not hang, and leave no .part file."""
    import signal
    import time
    big = jpg.with_name("big.png")
    from PIL import Image
    Image.effect_noise((6000, 6000), 64).convert("RGB").save(big)
    p = subprocess.Popen([str(LAUNCHER), "--engine", str(ENGINE), "tool", "compress-500kb", str(big)],
                         stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    time.sleep(1.5)
    p.send_signal(signal.SIGTERM)
    assert p.wait(timeout=20) != 0
    assert not list(big.parent.glob(".~*.part"))


# ---- the engine runs as a child: exit codes and signals must pass through ----

_RUNNER = """
import importlib.machinery, importlib.util, sys
loader = importlib.machinery.SourceFileLoader("launcher", sys.argv[1])
spec = importlib.util.spec_from_loader("launcher", loader)
mod = importlib.util.module_from_spec(spec); loader.exec_module(mod)
sys.exit(mod.run(sys.argv[2:], None))
"""


def _spawn(*cmd: str) -> subprocess.Popen:
    return subprocess.Popen(["python3", "-B", "-c", _RUNNER, str(LAUNCHER), *cmd],
                            stdout=subprocess.PIPE, text=True)


def _child_pid(parent: int) -> int:
    import time
    for _ in range(100):
        kids = Path(f"/proc/{parent}/task/{parent}/children").read_text().split()
        if kids:
            return int(kids[0])
        time.sleep(0.05)
    raise AssertionError("child never started")


def _gone(pid: int) -> bool:
    import time
    for _ in range(100):
        try:
            os.kill(pid, 0)
        except ProcessLookupError:
            return True
        # a zombie of an exited parent is reaped by init; treat Z as gone
        try:
            if Path(f"/proc/{pid}/stat").read_text().split()[2] == "Z":
                return True
        except FileNotFoundError:
            return True
        time.sleep(0.05)
    return False


def test_run_passes_the_exit_code_through():
    assert _spawn("sh", "-c", "exit 3").wait(timeout=10) == 3


def test_sigterm_reaches_the_engine_child():
    import signal
    p = _spawn("sleep", "30")
    kid = _child_pid(p.pid)
    p.send_signal(signal.SIGTERM)
    assert p.wait(timeout=10) == 128 + signal.SIGTERM
    assert _gone(kid)


def test_sigkill_of_the_launcher_takes_the_child_with_it():
    import signal
    p = _spawn("sleep", "30")
    kid = _child_pid(p.pid)
    p.send_signal(signal.SIGKILL)
    p.wait(timeout=10)
    assert _gone(kid)
