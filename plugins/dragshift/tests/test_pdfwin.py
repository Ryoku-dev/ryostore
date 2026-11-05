"""bin/ds_pdfwin.py: the Organize, Watermark and Unlock windows, offscreen, end to end."""
from __future__ import annotations

from pathlib import Path

import pymupdf as fitz
import pytest

from conftest import eng
from test_engine import ok
from test_pdf import locked, six  # noqa: F401  (fixtures)

import dragshift_editor as ed  # noqa: E402


@pytest.fixture
def notes(monkeypatch):
    sent = []
    monkeypatch.setattr(ed, "_ipc", lambda payload: sent.append(payload) or True)
    return sent


class Drive:
    """Stands in for app.exec(): lets the test act on the one open window, like a user."""

    def __init__(self, real, act):
        self.real, self.act = real, act

    def exec(self):
        from dragshift.tools import ToolWindow
        wins = [w for w in self.real.topLevelWidgets() if isinstance(w, ToolWindow) and w.isVisible()]
        assert len(wins) == 1
        self.real.processEvents()
        self.act(wins[0])
        return 0


def run_window(monkeypatch, editor: str, files: list, act) -> dict:
    from PySide6.QtWidgets import QApplication
    real = QApplication.instance() or ed._app()
    monkeypatch.setattr(ed, "_app", lambda: Drive(real, act))
    return ed.open_editor(eng, eng.PDF_EDITORS[editor], files)


@pytest.mark.parametrize("editor", ["organize", "watermark", "unlock"])
def test_new_windows_construct(six, locked, editor):
    pdf = locked if editor == "unlock" else six  # unlock refuses a plain PDF before any window
    assert "DragShift" in ok(["editor", "--dry", editor, str(pdf)])["window"]


def test_organize_reorders_deletes_and_saves(monkeypatch, notes, six):
    def act(w):
        w.grid.item(0).setSelected(True)
        w._delete()                     # page 1 gone
        it = w.grid.takeItem(4)         # last page (6) to the front
        w.grid.insertItem(0, it)
        w._relabel()
        w.grid.clearSelection()
        w.grid.item(1).setSelected(True)
        w._rotate(90)
        w.primary_btn.click()
    r = run_window(monkeypatch, "organize", [six], act)
    out = Path(r["outs"][0])
    assert out.name == "Report Edited.pdf"
    with fitz.open(out) as d:
        assert d.page_count == 5
        assert "Page body 6" in d[0].get_text() and "Page body 2" in d[1].get_text()
        assert d[1].rotation == 90


def test_organize_merges_two_pdfs_in_window_order(monkeypatch, notes, six, pdf2):
    def act(w):
        assert w.grid.count() == 7 and w.multi
        w.grid.insertItem(0, w.grid.takeItem(6))  # the other PDF's page first
        w._relabel()
        w.primary_btn.click()
    out = Path(run_window(monkeypatch, "organize", [six, pdf2], act)["outs"][0])
    assert out.name == "Report Merged.pdf"
    with fitz.open(out) as d:
        assert d.page_count == 7 and "Second document" in d[0].get_text()


def test_organize_range_select_extract_and_cut(monkeypatch, notes, six):
    def act(w):
        w.range.setText("2-3, 5")
        w._select_range()
        assert len(w.grid.selectedItems()) == 3
        w._extract()
    out = Path(run_window(monkeypatch, "organize", [six], act)["outs"][0])
    assert out.name == "Report pages 2-3, 5.pdf"
    with fitz.open(out) as d:
        assert d.page_count == 3

    def cut(w):
        w.range.setText("3, 5")
        w._select_range()
        w._cut()
    outs = run_window(monkeypatch, "organize", [six], cut)["outs"]
    assert [Path(o).name for o in outs] == ["Report part 1.pdf", "Report part 2.pdf", "Report part 3.pdf"]


def test_organize_bad_range_says_so(monkeypatch, notes, six):
    def act(w):
        w.range.setText("9")
        w._select_range()
        assert "outside" in w.msg.text()
        w.close()
    assert run_window(monkeypatch, "organize", [six], act)["outs"] == []


def test_watermark_window_applies_text(monkeypatch, notes, six):
    def act(w):
        w.text.setText("CONFIDENTIAL")
        w.pages.setText("1")
        w._refresh()
        assert w.preview.pixmap() is not None and w.primary_btn.isEnabled()
        w.primary_btn.click()
    out = Path(run_window(monkeypatch, "watermark", [six], act)["outs"][0])
    with fitz.open(out) as d:
        assert len(d[0].get_images()) > len(d[1].get_images())  # drawn as a faded image, page 1 only


def test_watermark_shows_only_the_controls_of_its_mode(monkeypatch, notes, six):
    seen = {}

    def act(w):
        text_only, image_only = (w.text, w.size, w.angle, w.color_btn), (w.pick, w.scale)
        seen["text"] = (all(not x.isHidden() for x in text_only), all(x.isHidden() for x in image_only))
        w.mode.button(1).setChecked(True)
        w._refresh()
        seen["image"] = (all(x.isHidden() for x in text_only), all(not x.isHidden() for x in image_only))
        seen["opacity"] = not w.opacity.isHidden()  # opacity fades either one
        w.close()
    run_window(monkeypatch, "watermark", [six], act)
    assert seen == {"text": (True, True), "image": (True, True), "opacity": True}


def test_watermark_window_stamps_an_image(monkeypatch, notes, six, png):
    def act(w):
        w.image = png
        w.mode.button(1).setChecked(True)
        w._refresh()
        w.primary_btn.click()
    out = Path(run_window(monkeypatch, "watermark", [six], act)["outs"][0])
    assert out.name == "Report Stamped.pdf"
    with fitz.open(out) as d:
        assert d[0].get_images()


def test_unlock_window_wrong_then_right(monkeypatch, notes, locked):  # noqa: F811
    def act(w):
        w.pw.setText("nope")
        w.primary_btn.click()
        assert "Wrong password" in w.msg.text() and w.isVisible()
        w.pw.setText("pw1234")
        w.primary_btn.click()
    out = Path(run_window(monkeypatch, "unlock", [locked], act)["outs"][0])
    with fitz.open(out) as d:
        assert not d.needs_pass


def test_unlock_window_on_a_plain_pdf(monkeypatch, notes, six):  # noqa: F811
    def act(w):
        assert "no password" in w.msg.text() and not w.primary_btn.isEnabled()
        w.close()
    run_window(monkeypatch, "unlock", [six], act)


def test_moving_several_pages_at_once_keeps_every_page_once(monkeypatch, notes, six):
    from PySide6.QtCore import QModelIndex

    def act(w):
        assert w.grid.model().moveRows(QModelIndex(), 3, 3, QModelIndex(), 0)  # pages 4-6 to the front
        w._relabel()
        assert w.grid.count() == 6
        w.primary_btn.click()
    out = Path(run_window(monkeypatch, "organize", [six], act)["outs"][0])
    with fitz.open(out) as d:
        got = [d[i].get_text().split("Page body ")[1].strip() for i in range(d.page_count)]
    assert got == ["4", "5", "6", "1", "2", "3"]


def test_enter_in_the_page_box_selects_and_never_saves(monkeypatch, notes, six):
    from PySide6.QtCore import QPoint, Qt
    from PySide6.QtTest import QTest

    def act(w):
        w.range.hasFocus = lambda: True  # offscreen windows never get real keyboard focus
        w.range.setText("2-4")
        w._enter()  # what the window's Enter shortcut calls
        assert len(w.grid.selectedItems()) == 3 and w.isVisible()
        w.range.setText("")
        w._enter()
        assert w.grid.selectedItems() == []
        w.grid.item(0).setSelected(True)
        empty = w.grid.viewport().rect().bottomRight() - QPoint(5, 5)
        QTest.mouseClick(w.grid.viewport(), Qt.LeftButton, pos=empty)
        assert w.grid.selectedItems() == []
        w.close()
    assert run_window(monkeypatch, "organize", [six], act)["outs"] == []


def test_enter_in_the_watermark_text_does_not_apply(monkeypatch, notes, six):
    def act(w):
        w.text.hasFocus = lambda: True
        w._enter()
        assert w.isVisible()
        w.close()
    assert run_window(monkeypatch, "watermark", [six], act)["outs"] == []
