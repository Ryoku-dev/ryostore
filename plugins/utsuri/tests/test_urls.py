"""content/urls.js, run in node: the QML's drop-URL decoding."""
from __future__ import annotations

import json
import shutil
import subprocess

import pytest

from conftest import PLUGIN

pytestmark = pytest.mark.skipif(shutil.which("node") is None, reason="node not installed")


def js(expr: str):
    src = (PLUGIN / "content" / "urls.js").read_text().replace(".pragma library", "")
    p = subprocess.run(["node", "-e", f"{src}\nconsole.log(JSON.stringify({expr}))"],
                       capture_output=True, text=True, timeout=30)
    assert p.returncode == 0, p.stderr
    return json.loads(p.stdout)


def test_plain_and_percent_encoded_paths():
    urls = ["file:///tmp/a.png", "file:///tmp/T%E1%BA%BFt%20%231%20100%2520.png"]
    assert js(f"toPaths({json.dumps(urls)})") == ["/tmp/a.png", "/tmp/Tết #1 100%20.png"]


def test_localhost_form():
    assert js('toPaths(["file://localhost/home/x.pdf"])') == ["/home/x.pdf"]


def test_skips_non_file_urls_malformed_escapes_and_duplicates():
    urls = ["https://example.com/a.png", "file:///bad%E0%A4%A.png", "file:///x", "file:///x", "file:///"]
    assert js(f"toPaths({json.dumps(urls)})") == ["/x"]


def test_empty_and_missing():
    assert js("toPaths([])") == [] and js("toPaths(null)") == []


def test_base_name():
    assert js('baseName("/a/b/Photo 1.png")') == "Photo 1.png"
