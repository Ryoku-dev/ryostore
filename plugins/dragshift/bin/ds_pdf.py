"""PDF toolkit for DragShift on Ryoku (PDF24-style): numbering, grayscale, flatten,
splitting, searchable OCR, page organizing, watermarks, stamps and unlocking.

Pure functions on PyMuPDF; no Qt. The engine calls use() once with upstream's
open_pdf (refuses password-protected files) and sibling (never-overwriting output
paths). Every result is written to a hidden ".part" file and renamed into place,
so a cancelled job never leaves half a PDF behind. Originals are only read.
"""
from __future__ import annotations

import math
import os
import re
import shutil
import subprocess
from pathlib import Path

import pymupdf as fitz

from ds_archive import temp_part

TESSDATA = "/usr/share/tessdata"
OCR_DPI = 300
NUMBER_PT = 12
_io = {"open": fitz.open, "sibling": None}


class PdfError(Exception):
    """A message that is fine to show the user as-is."""


def use(open_pdf, sibling) -> None:
    _io["open"], _io["sibling"] = open_pdf, sibling


_BROKEN = (fitz.FileDataError, fitz.EmptyFileError, RuntimeError, ValueError)


def _readable(opener, src):
    try:
        return opener(src)
    except _BROKEN:
        raise PdfError(f"Can't read {Path(src).name}: it isn't a valid PDF") from None


def _open(src):
    return _readable(_io["open"], src)


def _raw(src):
    """fitz.open without upstream's password refusal (for the password tools)."""
    return _readable(fitz.open, src)


def _out(src, label: str) -> Path:
    return _io["sibling"](src, label, ".pdf")


def _save(doc, out: Path, **kw) -> Path:
    part = temp_part(out.parent, ".part.pdf")
    try:
        doc.save(part, garbage=3, deflate=True, **kw)
        part.replace(out)
    finally:
        part.unlink(missing_ok=True)
    return out


# ---------------------------------------------------------------- page ranges
_RANGE = re.compile(r"^\s*(\d*)\s*(-?)\s*(\d*)\s*$")


def parse_ranges(text: str, count: int) -> list[int]:
    """'1-3, 7, 10-' -> zero-based page indexes, sorted, no repeats. Empty or 'all' = every page."""
    text = (text or "").strip().lower()
    if text in ("", "all"):
        return list(range(count))
    pages: set[int] = set()
    for part in text.split(","):
        m = _RANGE.match(part)
        if not m or not (m.group(1) or m.group(3)) or (not m.group(2) and m.group(3)):
            raise PdfError(f"'{part.strip()}' isn't a page range (use e.g. 1-3, 7, 10-)")
        a = int(m.group(1)) if m.group(1) else 1
        b = (int(m.group(3)) if m.group(3) else count) if m.group(2) else a
        if a < 1 or b > count or a > b:
            raise PdfError(f"Pages {part.strip()} are outside 1-{count}")
        pages.update(range(a - 1, b))
    return sorted(pages)


def label_for(pages: list[int]) -> str:
    """[0, 1, 2, 6] -> 'pages 1-3, 7' (for file names)."""
    runs, start = [], None
    for i, p in enumerate(pages):
        if start is None:
            start = p
        if i + 1 == len(pages) or pages[i + 1] != p + 1:
            runs.append(f"{start + 1}" if start == p else f"{start + 1}-{p + 1}")
            start = None
    s = ", ".join(runs)
    return ("page " if len(pages) == 1 else "pages ") + (s if len(s) <= 40 else s[:37] + "…")


# ---------------------------------------------------------------- one-click tools
def number_pages(src) -> Path:
    with _open(src) as doc:
        n = doc.page_count
        for i, page in enumerate(doc):
            r = page.rect  # the page as the reader sees it
            _upright(page, fitz.Rect(r.x0, r.y1 - 40, r.x1, r.y1 - 14), lambda box, rot: page.insert_textbox(
                box, f"{i + 1} / {n}", fontsize=NUMBER_PT, fontname="helv", rotate=rot,
                align=fitz.TEXT_ALIGN_CENTER, color=(0.1, 0.1, 0.1)))
        return _save(doc, _out(src, "Numbered"))


def grayscale(src) -> Path:
    with _open(src) as doc:
        for page in doc:
            page.recolor(1)
        return _save(doc, _out(src, "Gray"))


def flatten(src) -> Path:
    with _open(src) as doc:
        if not any(p.first_annot or p.first_widget for p in doc):
            raise PdfError("Nothing to flatten: this PDF has no form fields or annotations")
        doc.bake(annots=True, widgets=True)
        return _save(doc, _out(src, "Flattened"))


def _extract(doc, pages: list[int], out: Path) -> Path:
    nd = fitz.open()
    try:
        for p in pages:
            nd.insert_pdf(doc, from_page=p, to_page=p)
        return _save(nd, out)
    finally:
        nd.close()


def split_halves(src) -> list[Path]:
    with _open(src) as doc:
        n = doc.page_count
        if n < 2:
            raise PdfError("A one-page PDF can't be split in half")
        half = (n + 1) // 2
        return [_extract(doc, list(range(half)), _out(src, "part 1")),
                _extract(doc, list(range(half, n)), _out(src, "part 2"))]


def _safe(title: str) -> str:
    t = re.sub(r"[\x00-\x1f/\\:*?\"<>|]+", " ", title).strip(" .")
    return re.sub(r"\s+", " ", t)[:60] or "chapter"


def split_chapters(src) -> list[Path]:
    with _open(src) as doc:
        tops = [(t, max(1, p)) for lvl, t, p in doc.get_toc(simple=True) if lvl == 1 and p >= 1]
        if not tops:
            raise PdfError("This PDF has no bookmarks to split by")
        starts = sorted({p for _, p in tops})
        if starts[0] > 1:
            tops.insert(0, ("Front matter", 1))
        outs, seen = [], set()
        tops.sort(key=lambda x: x[1])
        for i, (title, start) in enumerate(tops):
            if start in seen:  # two bookmarks on one page: the first names it
                continue
            seen.add(start)
            nxt = next((p for _, p in tops[i + 1:] if p > start), doc.page_count + 1)
            outs.append(_extract(doc, list(range(start - 1, nxt - 1)),
                                 _out(src, f"{len(outs) + 1:02d} {_safe(title)}")))
        return outs


def make_searchable(src, lang: str) -> tuple[Path, int]:
    """OCR the pages that have no text; pages with text are copied untouched.
    Returns (output, pages recognised)."""
    tess = os.environ.get("TESSDATA_PREFIX") or TESSDATA
    with _open(src) as doc:
        todo = [i for i, p in enumerate(doc) if not p.get_text().strip()]
        if not todo:
            raise PdfError("This PDF already has selectable text")
        nd = fitz.open()
        try:
            for i, page in enumerate(doc):
                if i not in todo:
                    nd.insert_pdf(doc, from_page=i, to_page=i)
                    continue
                pix = page.get_pixmap(dpi=OCR_DPI)
                try:
                    data = pix.pdfocr_tobytes(language=lang, tessdata=tess)
                except Exception as e:  # noqa: BLE001 - MuPDF raises plain RuntimeErrors
                    raise PdfError(f"Text recognition failed on page {i + 1}: {e}") from None
                with fitz.open("pdf", data) as one:
                    nd.insert_pdf(one)
            return _save(nd, _out(src, "Searchable")), len(todo)
        finally:
            nd.close()


# ---------------------------------------------------------------- organize
def organize(srcs: list, items: list, label: str, cuts: tuple = ()) -> list[Path]:
    """Build PDFs from `items`: (source index, page index or None for a blank page,
    extra rotation in degrees). `cuts` are item positions where a new file starts;
    with cuts the files are "<label> 1", "<label> 2"..."""
    if not items:
        raise PdfError("No pages left to save")
    docs = [_open(s) for s in srcs]
    try:
        bounds = sorted({0, *[c for c in cuts if 0 < c < len(items)], len(items)})
        groups = [items[a:b] for a, b in zip(bounds, bounds[1:])]
        outs = []
        for k, group in enumerate(groups, 1):
            nd = fitz.open()
            try:
                size = None
                for si, pno, rot in group:
                    if pno is None:
                        w, h = size or (595, 842)  # blank: the size of the page before it, or A4
                        nd.new_page(width=w, height=h)
                    else:
                        nd.insert_pdf(docs[si], from_page=pno, to_page=pno)
                        size = (docs[si][pno].rect.width, docs[si][pno].rect.height)
                    pg = nd[-1]
                    pg.set_rotation((pg.rotation + rot) % 360)
                name = f"{label} {k}" if len(groups) > 1 else label
                outs.append(_save(nd, _out(srcs[0], name)))
            finally:
                nd.close()
        return outs
    finally:
        for d in docs:
            d.close()


# ---------------------------------------------------------------- watermark / stamp
CORNERS = ("center", "top-left", "top-right", "bottom-left", "bottom-right")


def _anchor(r, w: float, h: float, where: str, margin: float = 28) -> fitz.Rect:
    x = {"left": r.x0 + margin, "right": r.x1 - margin - w}
    y = {"top": r.y0 + margin, "bottom": r.y1 - margin - h}
    if where == "center":
        return fitz.Rect(r.x0 + (r.width - w) / 2, r.y0 + (r.height - h) / 2,
                         r.x0 + (r.width + w) / 2, r.y0 + (r.height + h) / 2)
    vert, horiz = where.split("-")
    return fitz.Rect(x[horiz], y[vert], x[horiz] + w, y[vert] + h)


def _check_where(where: str) -> None:
    if where not in CORNERS:
        raise PdfError(f"Unknown position '{where}'")


WM_ZOOM = 3          # watermark image resolution: 3 px per point (216 dpi)
WM_MAX_PX = 3000     # ...but never wider or taller than this
WM_MAX_CHARS = 200
_fonts: list = []


def _upright(page, rect, draw):
    """Call draw(box, rotate) so `rect`, given in the page as the reader sees it, lands
    there upright. Page.remove_rotation() would be simpler but drops the CropBox (which
    can bring cropped-away content back), so the crop is lifted only while drawing."""
    crop = fitz.Rect(page.cropbox)
    page.set_cropbox(page.mediabox)
    try:
        seen = crop * page.rotation_matrix  # where the crop sits in the uncropped view
        return draw((rect + (seen.x0, seen.y0, seen.x0, seen.y0)) * page.derotation_matrix,
                    page.rotation)
    finally:
        page.set_cropbox(crop)


def _system_font():
    """A system sans with Vietnamese and other Latin/Greek/Cyrillic letters, or None."""
    if shutil.which("fc-match") is None:
        return None
    try:
        r = subprocess.run(["fc-match", "-f", "%{file}", "sans-serif:charset=1ea3 111 3b1 431"],
                           capture_output=True, text=True, timeout=10)
        return fitz.Font(fontfile=r.stdout.strip()) if r.stdout.strip() else None
    except (OSError, subprocess.SubprocessError, RuntimeError):
        return None


def _runs(text: str, size: float) -> list:
    """Split `text` into (run, font) pieces, each character in the first font that has it:
    Helvetica, then the system sans (Vietnamese...), then MuPDF's CJK font."""
    if not _fonts:
        _fonts.extend(f for f in (fitz.Font("helv"), _system_font(), fitz.Font("cjk")) if f)
    runs: list = []
    for ch in text:
        font = next((f for f in _fonts if ch == " " or f.has_glyph(ord(ch))), None)
        if font is None:
            raise PdfError(f"No installed font can draw '{ch}'")
        if runs and runs[-1][1] is font:
            runs[-1] = (runs[-1][0] + ch, font)
        else:
            runs.append((ch, font))
    return runs


def _fade_table(opacity: float) -> bytes:
    return bytes(round(a * max(0.0, min(opacity, 1.0))) for a in range(256))


def text_image(text: str, size: float = 60, opacity: float = 0.2, angle: float = 45,
               color=(0.6, 0.1, 0.1)) -> tuple:
    """The watermark as a transparent image: (pixmap, width pt, height pt).
    Viewers such as LibreOffice ignore the opacity of PDF *text* but honour an image's
    alpha channel, so drawing the text as an image fades it in every viewer."""
    if len(text) > WM_MAX_CHARS:
        raise PdfError(f"Watermark text is too long (at most {WM_MAX_CHARS} characters)")
    runs = _runs(text, size)
    tw = sum(f.text_length(t, fontsize=size) for t, f in runs)
    a = math.radians(angle)
    w = tw * abs(math.cos(a)) + size * abs(math.sin(a)) + 8
    h = tw * abs(math.sin(a)) + size * abs(math.cos(a)) + 8
    zoom = min(WM_ZOOM, WM_MAX_PX / max(w, h))
    with fitz.open() as d:
        pg = d.new_page(width=w, height=h)
        centre = fitz.Point(w / 2, h / 2)
        writer, pos = fitz.TextWriter(pg.rect), fitz.Point(centre.x - tw / 2, centre.y + size * 0.35)
        for t, f in runs:
            _, pos = writer.append(pos, t, font=f, fontsize=size)
        writer.write_text(pg, morph=(centre, fitz.Matrix(angle)))  # rises left to right
        mask = pg.get_pixmap(matrix=fitz.Matrix(zoom, zoom), colorspace=fitz.csGRAY, alpha=False)
    pix = fitz.Pixmap(fitz.csRGB, mask.irect, True)
    pix.set_rect(pix.irect, tuple(round(c * 255) for c in color) + (255,))
    ink = bytes(255 - v for v in range(256))  # black-on-white render -> coverage
    pix.set_alpha(mask.samples.translate(ink).translate(_fade_table(opacity)))
    return pix, w, h


def _place(page, pix, w: float, h: float, where: str, xref: int = 0) -> int:
    """Put a prepared image on `page`, shrunk to fit if it is bigger than the page.
    Pass the returned xref back to reuse the same image on the next page."""
    r = page.rect
    k = min(1.0, (r.width - 8) / w, (r.height - 8) / h)
    rect = _anchor(r, w * k, h * k, where, margin=min(28, (r.width - w * k) / 2, (r.height - h * k) / 2))
    return _upright(page, rect, lambda box, rot: page.insert_image(
        box, overlay=True, rotate=rot, **({"xref": xref} if xref else {"pixmap": pix})))


def apply_text(page, text: str, size: float = 60, opacity: float = 0.2, angle: float = 45,
               color=(0.6, 0.1, 0.1), where: str = "center") -> None:
    """Draw one watermark on `page` (also used for the window's live preview).
    Only the centre position is tilted; corner marks stay level."""
    pix, w, h = text_image(text, size, opacity, angle if where == "center" else 0, color)
    _place(page, pix, w, h, where)


def load_stamp(image: str | Path) -> tuple[Path, float]:
    """(image path, height / width), or a clean error."""
    image = Path(image)
    if not image.is_file():
        raise PdfError("Pick an image to stamp")
    try:
        pix = fitz.Pixmap(str(image))
    except Exception:  # noqa: BLE001 - any decode failure
        raise PdfError(f"{image.name} isn't an image PyMuPDF can read") from None
    return image, pix.height / pix.width


def faded(image: Path, opacity: float):
    """The image as a Pixmap with its alpha scaled by `opacity` (PDF images have no
    opacity setting of their own). Returns None at full opacity: insert the file as-is."""
    if opacity >= 1:
        return None
    pix = fitz.Pixmap(str(image))
    if pix.colorspace and pix.colorspace.n not in (1, 3):  # CMYK etc.: convert first
        pix = fitz.Pixmap(fitz.csRGB, pix)
    if not pix.alpha:
        pix = fitz.Pixmap(pix, 1)
    pix.set_alpha(pix.samples[pix.n - 1::pix.n].translate(_fade_table(opacity)))
    return pix


def apply_stamp(page, image: Path, aspect: float, scale: float = 0.25, where: str = "bottom-right",
                opacity: float = 1.0, pix=None) -> None:
    """`pix` = a faded() copy, so a multi-page stamp fades the image only once."""
    w = page.rect.width * max(0.05, min(scale, 1.0))
    rect = _anchor(page.rect, w, w * aspect, where)
    pix = pix if pix is not None else faded(image, opacity)
    src = {"filename": str(image)} if pix is None else {"pixmap": pix}
    _upright(page, rect, lambda box, rot: page.insert_image(box, keep_proportion=True, overlay=True,
                                                            rotate=rot, **src))


def watermark_text(src, text: str, size: float = 60, opacity: float = 0.2, angle: float = 45,
                   color=(0.6, 0.1, 0.1), where: str = "center", pages: str = "") -> Path:
    if not text.strip():
        raise PdfError("Type the watermark text first")
    _check_where(where)
    pix, w, h = text_image(text, size, opacity, angle if where == "center" else 0, color)
    with _open(src) as doc:
        xref = 0
        for i in parse_ranges(pages, doc.page_count):
            xref = _place(doc[i], pix, w, h, where, xref)  # one image, shared by every page
        return _save(doc, _out(src, "Watermarked"))


def stamp_image(src, image: str | Path, scale: float = 0.25, where: str = "bottom-right",
                pages: str = "", opacity: float = 1.0) -> Path:
    _check_where(where)
    image, aspect = load_stamp(image)
    pix = faded(image, opacity)
    with _open(src) as doc:
        for i in parse_ranges(pages, doc.page_count):
            apply_stamp(doc[i], image, aspect, scale, where, opacity, pix)
        return _save(doc, _out(src, "Stamped"))


# ---------------------------------------------------------------- unlock
def _encrypted(doc) -> bool:
    """True for any /Encrypt: a user password, or only an owner password with
    restrictions (PyMuPDF opens those silently and reports is_encrypted=False)."""
    return doc.needs_pass or doc.is_encrypted or doc.xref_get_key(-1, "Encrypt")[0] != "null"


def needs_password(src) -> bool:
    with _raw(src) as doc:
        return doc.needs_pass


def is_encrypted(src) -> bool:
    with _raw(src) as doc:
        return _encrypted(doc)


def password_ok(src, password: str) -> bool:
    with _raw(src) as doc:
        return not doc.needs_pass or bool(doc.authenticate(password))


def unlock(src, password: str) -> Path:
    with _raw(src) as doc:
        if not _encrypted(doc):
            raise PdfError("This PDF has no password")
        if doc.needs_pass and not doc.authenticate(password):
            raise PdfError("Wrong password")
        return _save(doc, _out(src, "Unlocked"), encryption=fitz.PDF_ENCRYPT_NONE)
