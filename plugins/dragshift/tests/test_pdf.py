"""The PDF toolkit (bin/ds_pdf.py) through the engine, plus its pure helpers."""
from __future__ import annotations

import hashlib
import shutil
from pathlib import Path

import pymupdf as fitz
import pytest

from conftest import eng
from test_engine import fail, ok

pdfmod = eng.ds_pdf


def sha(p: Path) -> str:
    return hashlib.sha256(p.read_bytes()).hexdigest()


def text_of(p: Path, i: int = 0) -> str:
    with fitz.open(p) as d:
        return d[i].get_text()


def pages(p: Path) -> int:
    with fitz.open(p) as d:
        return d.page_count


@pytest.fixture
def six(tmp_path) -> Path:
    d = fitz.open()
    for i in range(6):
        d.new_page().insert_text((72, 100), f"Page body {i + 1}", fontsize=20)
    d.set_toc([[1, "Intro", 1], [2, "Detail", 2], [1, "Middle/Part", 3], [1, "End", 5]])
    p = tmp_path / "Report.pdf"
    d.save(p)
    return p


@pytest.fixture
def form(tmp_path) -> Path:
    d = fitz.open()
    page = d.new_page()
    page.insert_text((72, 80), "Form here", fontsize=14)
    w = fitz.Widget()
    w.field_name, w.field_type, w.field_value = "name", fitz.PDF_WIDGET_TYPE_TEXT, "Ada"
    w.rect = fitz.Rect(72, 100, 300, 130)
    page.add_widget(w)
    page.add_highlight_annot(fitz.Rect(72, 66, 160, 84))
    p = tmp_path / "Form.pdf"
    d.save(p)
    return p


@pytest.fixture
def locked(tmp_path, six) -> Path:
    p = tmp_path / "Secret.pdf"
    with fitz.open(six) as d:
        d.save(p, encryption=fitz.PDF_ENCRYPT_AES_256, owner_pw="pw1234", user_pw="pw1234")
    return p


@pytest.fixture
def scan(tmp_path) -> Path:
    """A text page plus a page that is only a picture of text."""
    src = fitz.open()
    src.new_page().insert_text((72, 120), "HELLO WORLD 123", fontsize=48)
    pix = src[0].get_pixmap(dpi=200)
    d = fitz.open()
    d.new_page().insert_text((72, 100), "Already text", fontsize=20)
    d.new_page().insert_image(fitz.Rect(0, 0, 595, 842), pixmap=pix)
    p = tmp_path / "Scan.pdf"
    d.save(p)
    return p


# ---------------------------------------------------------------- ranges
@pytest.mark.parametrize("text,want", [("", [0, 1, 2, 3, 4, 5]), ("all", [0, 1, 2, 3, 4, 5]),
                                       ("1-3, 6", [0, 1, 2, 5]), ("5-", [4, 5]), ("-2", [0, 1]),
                                       ("2,2,1", [0, 1])])
def test_parse_ranges(text, want):
    assert pdfmod.parse_ranges(text, 6) == want


@pytest.mark.parametrize("bad", ["0", "7", "3-1", "a", "1-2-3", "4 5"])
def test_parse_ranges_refuses(bad):
    with pytest.raises(pdfmod.PdfError):
        pdfmod.parse_ranges(bad, 6)


def test_label_for():
    assert pdfmod.label_for([0, 1, 2, 6]) == "pages 1-3, 7"
    assert pdfmod.label_for([4]) == "page 5"


# ---------------------------------------------------------------- one-click
def test_actions_list_both_pdf_rings(six):
    ids = [t["id"] for t in ok(["actions", str(six)])["tools"]]
    for i in ("numbers", "gray", "flatten", "halves", "chapters", "searchable"):
        assert i in ids
    eds = [e["id"] for e in ok(["actions", str(six)])["editors"]]
    assert {"organize", "watermark", "unlock", "protect", "metadata"} <= set(eds)


def test_numbers(six):
    before = sha(six)
    out = Path(ok(["tool", "numbers", str(six)])["outs"][0])
    assert out.name == "Report Numbered.pdf" and "3 / 6" in text_of(out, 2)
    assert sha(six) == before


def test_gray(tmp_path):
    d = fitz.open()
    d.new_page().draw_rect(fitz.Rect(50, 50, 300, 300), color=(1, 0, 0), fill=(0, 0, 1))
    p = tmp_path / "Color.pdf"
    d.save(p)
    out = Path(ok(["tool", "gray", str(p)])["outs"][0])
    with fitz.open(out) as g:
        pix = g[0].get_pixmap(dpi=30)
    s = pix.samples
    assert all(s[i] == s[i + 1] == s[i + 2] for i in range(0, len(s), pix.n))


def test_flatten(form):
    out = Path(ok(["tool", "flatten", str(form)])["outs"][0])
    with fitz.open(out) as d:
        assert d[0].first_widget is None and d[0].first_annot is None
        assert "Form here" in d[0].get_text() and "Ada" in d[0].get_text()


def test_flatten_with_nothing_to_flatten(six):
    assert "Nothing to flatten" in fail(["tool", "flatten", str(six)])["error"]


def test_halves(six):
    outs = [Path(o) for o in ok(["tool", "halves", str(six)])["outs"]]
    assert [o.name for o in outs] == ["Report part 1.pdf", "Report part 2.pdf"]
    assert [pages(o) for o in outs] == [3, 3]


def test_chapters(six):
    outs = [Path(o) for o in ok(["tool", "chapters", str(six)])["outs"]]
    assert [o.name for o in outs] == ["Report 01 Intro.pdf", "Report 02 Middle Part.pdf", "Report 03 End.pdf"]
    assert [pages(o) for o in outs] == [2, 2, 2]
    assert "Page body 3" in text_of(outs[1])


def test_chapters_without_bookmarks(tmp_path):
    d = fitz.open()
    d.new_page()
    d.new_page()
    p = tmp_path / "Plain.pdf"
    d.save(p)
    assert "no bookmarks" in fail(["tool", "chapters", str(p)])["error"]


@pytest.mark.skipif(not Path(pdfmod.TESSDATA, "eng.traineddata").is_file(), reason="no eng tessdata")
def test_searchable(scan):
    r = ok(["tool", "searchable", str(scan)])
    out = Path(r["outs"][0])
    assert out.name == "Scan Searchable.pdf" and pages(out) == 2
    assert "Already text" in text_of(out, 0)
    assert "HELLO" in text_of(out, 1).upper()
    assert "1 page" in r["detail"]


def test_searchable_refuses_a_text_pdf(six):
    assert "already has selectable text" in fail(["tool", "searchable", str(six)])["error"]


def test_searchable_missing_language(scan):
    assert "tesseract-data-zzz" in fail(["--ocr-lang", "zzz", "tool", "searchable", str(scan)])["error"]


# ---------------------------------------------------------------- organize
def test_organize_reorder_rotate_delete_duplicate_blank(six):
    items = [(0, 5, 0), (0, 0, 90), (0, 0, 0), (0, None, 0)]
    out = pdfmod.organize([six], items, "Edited")[0]
    with fitz.open(out) as d:
        assert d.page_count == 4
        assert "Page body 6" in d[0].get_text() and d[1].rotation == 90
        assert "Page body 1" in d[2].get_text() and d[3].get_text() == ""


def test_organize_merges_in_the_given_order(six, pdf2):
    out = pdfmod.organize([six, pdf2], [(1, 0, 0), (0, 2, 0)], "Merged")[0]
    assert out.name == "Report Merged.pdf"
    assert "Second document" in text_of(out, 0) and "Page body 3" in text_of(out, 1)


def test_organize_cuts_into_parts(six):
    outs = pdfmod.organize([six], [(0, i, 0) for i in range(6)], "part", cuts=(2, 5))
    assert [o.name for o in outs] == ["Report part 1.pdf", "Report part 2.pdf", "Report part 3.pdf"]
    assert [pages(o) for o in outs] == [2, 3, 1]


def test_organize_with_nothing_left(six):
    with pytest.raises(pdfmod.PdfError):
        pdfmod.organize([six], [], "Edited")


# ---------------------------------------------------------------- watermark / stamp / unlock
def test_watermark_only_on_chosen_pages(six):
    out = pdfmod.watermark_text(six, "DRAFT", pages="2-3")
    with fitz.open(out) as d:
        marks = [len(d[i].get_images()) - len(fitz.open(six)[i].get_images()) for i in range(3)]
        assert marks == [0, 1, 1]
        assert d[1].get_images()[-1][0] == d[2].get_images()[-1][0]  # one shared image
    assert out.name == "Report Watermarked.pdf"


def test_watermark_opacity_is_in_the_image_alpha(six):
    """LibreOffice ignores text opacity, so the fade must live in the image itself."""
    def peak(op):
        pix, _, _ = pdfmod.text_image("DRAFT", 72, op, 0, (0.5, 0.5, 0.5))
        return max(pix.samples[pix.n - 1::pix.n])
    assert peak(1.0) == 255 and peak(0.2) == 51 and peak(0.01) <= 3


def test_watermark_needs_text(six):
    with pytest.raises(pdfmod.PdfError):
        pdfmod.watermark_text(six, "   ")


def test_stamp_lands_in_the_corner(six, png):
    out = pdfmod.stamp_image(six, png, scale=0.2, where="bottom-right")
    with fitz.open(out) as d:
        r = d[0].get_image_rects(d[0].get_images()[0][0])[0]
        assert r.x1 > d[0].rect.width * 0.8 and r.y1 > d[0].rect.height * 0.8


def test_unlock(locked):
    out = pdfmod.unlock(locked, "pw1234")
    with fitz.open(out) as d:
        assert not d.needs_pass and "Page body 1" in d[0].get_text()


def test_unlock_wrong_password(locked):
    with pytest.raises(pdfmod.PdfError, match="Wrong password"):
        pdfmod.unlock(locked, "nope")
    assert [p.name for p in locked.parent.iterdir() if "Unlocked" in p.name] == []


def test_unlock_a_plain_pdf(six):
    with pytest.raises(pdfmod.PdfError, match="no password"):
        pdfmod.unlock(six, "x")


def test_other_tools_refuse_a_locked_pdf(locked):
    assert "password" in fail(["tool", "numbers", str(locked)])["error"]


def test_stamp_opacity_fades_the_image(six, png):
    solid = pdfmod.stamp_image(six, png, where="center")
    faint = pdfmod.stamp_image(six, png, where="center", opacity=0.1)

    def darkest(p):  # the stamp sits on white page centre; fainter = lighter
        with fitz.open(p) as d:
            pix = d[0].get_pixmap(dpi=40)
            return min(sum(pix.pixel(x, pix.height // 2)) for x in range(pix.width))
    assert darkest(faint) > darkest(solid) + 150


def test_unlock_on_a_plain_pdf_answers_without_a_window(six):
    assert "no password" in fail(["editor", "--dry", "unlock", str(six)])["error"]


# ---------------------------------------------------------------- 0.4.0 review findings
CROP = fitz.Rect(50, 20, 300, 370)


@pytest.fixture
def turned(tmp_path) -> Path:
    """Four cropped pages at /Rotate 0, 90, 180, 270, each with text outside its crop."""
    d = fitz.open()
    for rot in (0, 90, 180, 270):
        pg = d.new_page(width=600, height=400)
        pg.insert_text((400, 300), "HIDDEN-MARGIN", fontsize=12)
        pg.insert_text((80, 100), f"Body {rot}", fontsize=12)
        pg.set_cropbox(CROP)
        pg.set_rotation(rot)
    p = tmp_path / "Turned.pdf"
    d.save(p)
    return p


def _visible_bottom_right_ink(page) -> bool:
    pix = page.get_pixmap()
    w, h = pix.width, pix.height
    return any(pix.pixel(x, y) != (255, 255, 255)
               for y in range(int(h * 0.8), h - 1) for x in range(int(w * 0.6), w - 1))


@pytest.mark.parametrize("tool", ["numbers", "watermark", "stamp"])
def test_marks_keep_the_crop_and_rotation_of_turned_pages(turned, png, tool):
    with fitz.open(turned) as d:
        sizes = [tuple(p.rect) for p in d]
    out = {"numbers": lambda: pdfmod.number_pages(turned),
           "watermark": lambda: pdfmod.watermark_text(turned, "DRAFT", where="bottom-right"),
           "stamp": lambda: pdfmod.stamp_image(turned, png, where="bottom-right")}[tool]()
    with fitz.open(out) as d:
        for i, pg in enumerate(d):
            assert pg.rotation == (0, 90, 180, 270)[i] and pg.cropbox == CROP
            assert tuple(pg.rect) == sizes[i]
            assert "HIDDEN-MARGIN" not in pg.get_text()
            if tool != "numbers":
                assert _visible_bottom_right_ink(pg), (tool, i)


def test_numbers_sit_at_the_bottom_the_reader_sees(turned):
    out = pdfmod.number_pages(turned)
    with fitz.open(out) as d:
        for i, pg in enumerate(d):
            hit = [b for b in pg.get_text("blocks") if f"{i + 1} / 4" in b[4]]
            assert hit, i
            r = fitz.Rect(hit[0][:4]) * pg.rotation_matrix  # into the reader's frame
            assert r.y0 > pg.rect.height * 0.8, (i, r, pg.rect)


@pytest.fixture
def owner_only(tmp_path) -> Path:
    """Opens without a password but carries an owner password and restrictions."""
    d = fitz.open()
    d.new_page().insert_text((72, 100), "Restricted body", fontsize=20)
    p = tmp_path / "Restricted.pdf"
    d.save(p, encryption=fitz.PDF_ENCRYPT_AES_256, owner_pw="own", user_pw="",
           permissions=fitz.PDF_PERM_ACCESSIBILITY)
    return p


def test_unlock_removes_owner_only_restrictions(owner_only):
    assert pdfmod.is_encrypted(owner_only)
    out = pdfmod.unlock(owner_only, "")
    with fitz.open(out) as d:
        assert d.xref_get_key(-1, "Encrypt")[0] == "null" and "Restricted body" in d[0].get_text()


@pytest.fixture
def broken(tmp_path) -> Path:
    p = tmp_path / "Broken.pdf"
    p.write_bytes(b"%PDF-1.7\nthis is not really a pdf\n")
    return p


def test_a_broken_pdf_gets_a_clean_message(broken):
    for call in (lambda: pdfmod.number_pages(broken), lambda: pdfmod.is_encrypted(broken)):
        with pytest.raises(pdfmod.PdfError, match="isn't a valid PDF"):
            call()
    assert "isn't a valid PDF" in fail(["editor", "--dry", "watermark", str(broken)])["error"]


def test_watermark_draws_vietnamese_and_cjk():
    runs = pdfmod._runs("Bản quyền Đã duyệt 机密", 40)
    assert "".join(t for t, _ in runs) == "Bản quyền Đã duyệt 机密"
    for text, font in runs:
        assert all(font.has_glyph(ord(c)) for c in text), (text, font.name)


def test_watermark_text_has_a_sane_length(six):
    with pytest.raises(pdfmod.PdfError, match="too long"):
        pdfmod.watermark_text(six, "X" * 201)


def test_a_huge_watermark_is_shrunk_to_fit_the_page(six):
    out = pdfmod.watermark_text(six, "CONFIDENTIAL DOCUMENT", size=160, angle=0)
    with fitz.open(out) as d:
        r = d[0].get_image_rects(d[0].get_images()[-1][0])[0]
        assert d[0].rect.contains(r)


def test_long_file_names_still_save(tmp_path):
    p = tmp_path / ("L" * 244 + ".pdf")  # the output fits NAME_MAX, a ".stem.part.pdf" would not
    d = fitz.open()
    d.new_page()
    d.save(p)
    out = pdfmod.grayscale(p)
    assert out.exists() and not [x for x in tmp_path.iterdir() if ".part" in x.name]


def test_results_get_normal_file_permissions(six):
    import os
    umask = os.umask(0)
    os.umask(umask)
    assert pdfmod.grayscale(six).stat().st_mode & 0o777 == 0o666 & ~umask
