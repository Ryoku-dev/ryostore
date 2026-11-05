"""DragShift's own PDF windows: Organize (pages: reorder, rotate, delete, duplicate,
blank, extract, cut, merge), Watermark (text or image stamp, live preview) and Unlock.

They subclass upstream's ToolWindow, so they look like DragShift's other editors and
save through the same `submit`/`run` path: the window closes, the job runs in the
background, and the result card (with Undo) appears. All PDF work is in ds_pdf.
"""
from __future__ import annotations

from pathlib import Path

import pymupdf as fitz
from PySide6.QtCore import QSize, Qt, QTimer
from PySide6.QtGui import QColor, QFont, QIcon, QImage, QPainter, QPixmap, QTransform
from PySide6.QtWidgets import (QAbstractItemView, QColorDialog, QComboBox, QFileDialog, QGridLayout,
                               QHBoxLayout, QLabel, QLineEdit, QListView, QListWidget,
                               QListWidgetItem, QPushButton)

from dragshift.tools import ToolWindow, section, slider, slider_row, toggle_row

import ds_pdf

THUMB = 120
CARD = QSize(THUMB + 8, int(THUMB * 1.42) + 24)  # thumbnail plus its label, drawn as one icon
ROLE = Qt.UserRole
IMG = Qt.UserRole + 1
TAGS = ["#e8a87c", "#85c1e9", "#a3d9a5", "#d7a9e3", "#f7dc6f", "#f1948a"]


def _qimage(pix) -> QImage:
    fmt = QImage.Format_RGBA8888 if pix.alpha else QImage.Format_RGB888
    return QImage(pix.samples, pix.width, pix.height, pix.stride, fmt).copy()


def _render(page, width: int) -> QImage:
    zoom = width / max(page.rect.width, 1)
    return _qimage(page.get_pixmap(matrix=fitz.Matrix(zoom, zoom), alpha=False))


def _status(label: QLabel, text: str, bad: bool = False) -> None:
    label.setText(text)
    label.setStyleSheet("color: #ff8a80;" if bad else "")


# ================================================================ ORGANIZE
class OrganizeWindow(ToolWindow):
    tool_name = "Pages saved"

    def __init__(self, paths, notify):
        paths = paths if isinstance(paths, (list, tuple)) else [paths]
        multi = len(paths) > 1
        super().__init__("Merge and organize pages" if multi else "Organize pages", paths, notify,
                         size=(900, 700))
        self.docs = [ds_pdf._open(p) for p in self.paths]  # refuses locked PDFs with a clear message
        self.multi = multi

        tools = QHBoxLayout()
        self.range = QLineEdit()
        self.range.setPlaceholderText("Select pages: 1-3, 7  (Enter selects, empty clears)")
        self.range.returnPressed.connect(self._select_range)
        tools.addWidget(self.range, 1)
        for text, tip, fn in (("⟲", "Rotate left", lambda: self._rotate(-90)),
                              ("⟳", "Rotate right", lambda: self._rotate(90)),
                              ("Duplicate", "Copy the selected pages", self._duplicate),
                              ("Blank", "Insert a blank page after the selection", self._blank),
                              ("Delete", "Remove the selected pages (Del)", self._delete)):
            b = QPushButton(text)
            b.setToolTip(tip)
            b.clicked.connect(fn)
            tools.addWidget(b)
        self.body.addLayout(tools)

        # A wrapping *list* rather than IconMode: IconMode's free placement leaves holes
        # and can duplicate pages on a multi-page drag; a list keeps a strict order, so
        # dragging any selection is a real move.
        self.grid = QListWidget()
        self.grid.setViewMode(QListView.ListMode)
        self.grid.setFlow(QListView.LeftToRight)
        self.grid.setWrapping(True)
        self.grid.setIconSize(CARD)
        self.grid.setResizeMode(QListView.Adjust)
        self.grid.setDragDropMode(QAbstractItemView.InternalMove)
        self.grid.setDragDropOverwriteMode(False)
        self.grid.setDefaultDropAction(Qt.MoveAction)
        self.grid.setSelectionMode(QAbstractItemView.ExtendedSelection)
        self.grid.setUniformItemSizes(True)
        self.grid.setSpacing(6)
        self.grid.setStyleSheet(
            "QListWidget { background: rgba(0,0,0,0.14); border: 1px solid rgba(255,255,255,0.18);"
            " border-radius: 10px; padding: 6px; color: white; }"
            "QListWidget::item { border-radius: 8px; padding: 4px; }"
            "QListWidget::item:hover { background: rgba(255,255,255,0.08); }"
            "QListWidget::item:selected { background: rgba(120,170,255,0.35); color: white; }")
        self.grid.model().rowsMoved.connect(lambda *_: self._relabel())
        self.grid.itemSelectionChanged.connect(self._update)
        self.grid.viewport().installEventFilter(self)  # click on empty space = select none
        self.body.addWidget(self.grid, 1)

        self.msg = QLabel("Drag pages to reorder · Ctrl/Shift-click to select several · Del removes")
        self.msg.setObjectName("dim")
        self.body.addWidget(self.msg)

        self.extract_btn = QPushButton("Extract selection")
        self.extract_btn.setToolTip("Save only the selected pages as a new PDF")
        self.extract_btn.clicked.connect(self._extract)
        self.cut_btn = QPushButton("Cut before selection")
        self.cut_btn.setToolTip("Split into separate PDFs, starting a new one at each selected page")
        self.cut_btn.clicked.connect(self._cut)
        self.body.addLayout(self.footer("Merge" if multi else "Save", self.save,
                                        extra_buttons=(self.extract_btn, self.cut_btn)))
        from PySide6.QtGui import QKeySequence, QShortcut
        QShortcut(QKeySequence.Delete, self.grid, activated=self._delete)
        QShortcut(QKeySequence.SelectAll, self.grid, activated=self.grid.selectAll)

        self._pending: list[QListWidgetItem] = []
        for si, doc in enumerate(self.docs):
            for pno in range(doc.page_count):
                self._add(self.grid.count(), si, pno, 0)
        self._relabel()
        QTimer.singleShot(0, self._render_some)

    def _enter(self):
        """Enter in the page box selects; it must never press Save."""
        if self.range.hasFocus():
            self._select_range()
        else:
            super()._enter()

    def eventFilter(self, obj, ev):
        from PySide6.QtCore import QEvent
        if (obj is self.grid.viewport() and ev.type() == QEvent.MouseButtonPress
                and self.grid.itemAt(ev.position().toPoint()) is None):
            self.grid.clearSelection()
        return super().eventFilter(obj, ev)

    def closeEvent(self, e):
        self._pending = []  # a queued _render_some must not touch the closed documents
        for d in self.docs:
            d.close()
        super().closeEvent(e)

    # ---- items
    def _add(self, row: int, si: int, pno, rot: int) -> QListWidgetItem:
        it = QListWidgetItem()
        it.setData(ROLE, (si, pno, rot))
        it.setSizeHint(CARD + QSize(12, 12))  # fixed up front: thumbnails arrive later
        it.setFlags(it.flags() | Qt.ItemIsDragEnabled)
        it.setFlags(it.flags() & ~Qt.ItemIsDropEnabled)
        if self.multi:
            it.setToolTip(self.paths[si].name)
        self.grid.insertItem(row, it)
        self._pending.append(it)
        return it

    def _render_some(self):
        """Thumbnails a few at a time, so a 300-page PDF opens instantly."""
        batch, self._pending = self._pending[:8], self._pending[8:]
        for it in batch:
            try:
                self._paint(it)
            except (RuntimeError, ValueError):  # item deleted, or window closed, before its turn
                continue
        if self._pending:
            QTimer.singleShot(0, self._render_some)

    def _paint(self, it: QListWidgetItem):
        si, pno, rot = it.data(ROLE)
        if pno is None:
            img = QImage(THUMB, int(THUMB * 1.41), QImage.Format_RGB888)
            img.fill(QColor("white"))
        else:
            img = _render(self.docs[si][pno], THUMB)
        if rot:
            img = img.transformed(QTransform().rotate(rot))
        it.setData(IMG, img)
        self._card(it, self.grid.row(it))

    def _card(self, it: QListWidgetItem, row: int):
        """The page thumbnail with its number underneath, as one picture."""
        si, pno, _ = it.data(ROLE)
        src = "blank" if pno is None else (f"{chr(65 + si)}·{pno + 1}" if self.multi else f"p{pno + 1}")
        label = f"{row + 1}  ({src})" if (self.multi or pno is None or pno != row) else f"{row + 1}"
        card = QPixmap(CARD)
        card.fill(Qt.transparent)
        p = QPainter(card)
        p.setRenderHint(QPainter.SmoothPixmapTransform)
        img = it.data(IMG)
        box_h = CARD.height() - 22
        if img is not None:
            pm = QPixmap.fromImage(img).scaled(CARD.width(), box_h, Qt.KeepAspectRatio, Qt.SmoothTransformation)
            p.drawPixmap((CARD.width() - pm.width()) // 2, (box_h - pm.height()) // 2, pm)
        else:
            p.fillRect(4, 4, CARD.width() - 8, box_h - 8, QColor(255, 255, 255, 40))
        f = QFont(self.font())
        f.setPointSizeF(9.5)
        p.setFont(f)
        p.setPen(QColor(TAGS[si % len(TAGS)]) if self.multi else QColor("white"))
        p.drawText(0, box_h, CARD.width(), 22, Qt.AlignCenter, label)
        p.end()
        it.setIcon(QIcon(card))

    def _relabel(self):
        for row in range(self.grid.count()):
            self._card(self.grid.item(row), row)
        self._update()

    def _selected(self) -> list[QListWidgetItem]:
        return sorted(self.grid.selectedItems(), key=self.grid.row)

    def _update(self):
        n, sel = self.grid.count(), len(self.grid.selectedItems())
        self.extract_btn.setEnabled(sel > 0)
        self.cut_btn.setEnabled(sel > 0 and any(self.grid.row(i) > 0 for i in self.grid.selectedItems()))
        if self.primary_btn is not None:
            self.primary_btn.setEnabled(n > 0)
        self.subtitle.setText(f"{n} page{'s' if n != 1 else ''}" + (f" · {sel} selected" if sel else "")
                              + (f" · from {len(self.paths)} PDFs" if self.multi else f" · {self.path.name}"))

    # ---- edits
    def _select_range(self):
        if not self.range.text().strip():
            self.grid.clearSelection()
            _status(self.msg, "Selection cleared")
            return
        try:
            rows = ds_pdf.parse_ranges(self.range.text(), self.grid.count())
        except ds_pdf.PdfError as e:
            _status(self.msg, str(e), bad=True)
            return
        self.grid.clearSelection()
        for r in rows:
            self.grid.item(r).setSelected(True)
        _status(self.msg, f"Selected {len(rows)} page{'s' if len(rows) != 1 else ''}")

    def _rotate(self, deg: int):
        for it in self._selected():
            si, pno, rot = it.data(ROLE)
            it.setData(ROLE, (si, pno, (rot + deg) % 360))
            self._paint(it)

    def _delete(self):
        for it in self._selected():
            self.grid.takeItem(self.grid.row(it))
        self._relabel()

    def _duplicate(self):
        sel = self._selected()
        for it in reversed(sel):
            si, pno, rot = it.data(ROLE)
            self._paint(self._add(self.grid.row(sel[-1]) + 1, si, pno, rot))
        self._relabel()

    def _blank(self):
        sel = self._selected()
        row = self.grid.row(sel[-1]) + 1 if sel else self.grid.count()
        si = sel[-1].data(ROLE)[0] if sel else 0
        self._paint(self._add(row, si, None, 0))
        self._relabel()

    # ---- saving
    def _items(self, only=None) -> list[tuple]:
        rows = range(self.grid.count()) if only is None else [self.grid.row(i) for i in only]
        return [self.grid.item(r).data(ROLE) for r in rows]

    def _go(self, name: str, label: str, items: list, cuts=()):
        srcs = list(self.paths)
        self.tool_name = name
        self.run(lambda: ds_pdf.organize(srcs, items, label, cuts), f"{name}…")

    def save(self):
        self._go("Merged" if self.multi else "Pages saved", "Merged" if self.multi else "Edited", self._items())

    def _extract(self):
        sel = self._selected()
        rows = [self.grid.row(i) for i in sel]
        self._go("Pages extracted", ds_pdf.label_for(rows), self._items(sel))

    def _cut(self):
        cuts = tuple(self.grid.row(i) for i in self._selected() if self.grid.row(i) > 0)
        self._go("Cut into parts", "part", self._items(), cuts)


# ================================================================ WATERMARK
POSITIONS = [("Center (diagonal)", "center"), ("Top left", "top-left"), ("Top right", "top-right"),
             ("Bottom left", "bottom-left"), ("Bottom right", "bottom-right")]


class WatermarkWindow(ToolWindow):
    tool_name = "Watermarked"

    def __init__(self, path, notify):
        super().__init__("Watermark or stamp", path, notify, size=(860, 640))
        with ds_pdf._open(self.path) as d:  # refuses locked PDFs
            self.count = d.page_count
        self.color = QColor(110, 110, 110)
        self.image: Path | None = None

        row = QHBoxLayout()
        self.preview = QLabel()
        self.preview.setAlignment(Qt.AlignCenter)
        self.preview.setMinimumSize(300, 420)
        row.addWidget(self.preview, 1)

        g = QGridLayout()
        g.setVerticalSpacing(10)
        modes, self.mode = toggle_row(["Text", "Image"])
        g.addWidget(section("Watermark"), 0, 0, 1, 3)
        g.addLayout(modes, 1, 0, 1, 3)
        self.text = QLineEdit("DRAFT")
        g.addWidget(QLabel("Text"), 2, 0)
        g.addWidget(self.text, 2, 1, 1, 2)
        self.size = slider(12, 160, 72)
        slider_row(g, 3, "Size", self.size, lambda v: f"{v} pt")
        self.opacity = slider(1, 100, 15)  # also fades a stamped image
        slider_row(g, 4, "Opacity", self.opacity, lambda v: f"{v}%")
        self.angle = slider(0, 90, 45)
        slider_row(g, 5, "Angle", self.angle, lambda v: f"{v}°")
        self.color_btn = QPushButton("Colour")
        self.color_btn.clicked.connect(self._pick_color)
        g.addWidget(self.color_btn, 6, 1)
        self.pick = QPushButton("Choose image…")
        self.pick.clicked.connect(self._pick_image)
        g.addWidget(QLabel("Image"), 7, 0)
        g.addWidget(self.pick, 7, 1, 1, 2)
        self.scale = slider(5, 60, 22)
        slider_row(g, 8, "Width", self.scale, lambda v: f"{v}% of page")
        self.where = QComboBox()
        for label, key in POSITIONS:
            self.where.addItem(label, key)
        g.addWidget(QLabel("Position"), 9, 0)
        g.addWidget(self.where, 9, 1, 1, 2)
        self.pages = QLineEdit()
        self.pages.setPlaceholderText(f"All {self.count} pages, or e.g. 1-3, 7")
        g.addWidget(QLabel("Pages"), 10, 0)
        g.addWidget(self.pages, 10, 1, 1, 2)
        self.msg = QLabel("")
        self.msg.setObjectName("dim")
        self.msg.setWordWrap(True)
        g.addWidget(self.msg, 11, 0, 1, 3)
        g.setRowStretch(12, 1)
        self._grid = g
        self._row_mode = {2: "text", 3: "text", 5: "text", 6: "text", 7: "image", 8: "image"}
        row.addLayout(g, 1)
        self.body.addLayout(row, 1)
        self.body.addLayout(self.footer("Apply", self.save))

        self._timer = QTimer(self, singleShot=True, interval=150, timeout=self._refresh)
        for sig in (self.text.textChanged, self.size.valueChanged, self.opacity.valueChanged,
                    self.angle.valueChanged, self.scale.valueChanged, self.where.currentIndexChanged,
                    self.pages.textChanged, self.mode.idToggled):
            sig.connect(lambda *_: self._timer.start())
        self._refresh()

    def _enter(self):
        """Enter in a text box refreshes the preview; only the Apply button applies."""
        if self.text.hasFocus() or self.pages.hasFocus():
            self._refresh()
        else:
            super()._enter()

    def _is_image(self) -> bool:
        return self.mode.checkedId() == 1

    def _pick_color(self):
        c = QColorDialog.getColor(self.color, None, "Watermark colour")
        if c.isValid():
            self.color = c
            self._timer.start()

    def _pick_image(self):
        f, _ = QFileDialog.getOpenFileName(None, "Stamp image", str(Path.home()),
                                           "Images (*.png *.jpg *.jpeg *.webp *.bmp)")
        if f:
            self.image = Path(f)
            self.pick.setText(self.image.name)
            self.mode.button(1).setChecked(True)
            self._timer.start()

    def _options(self) -> dict:
        c = self.color
        return {"text": self.text.text(), "size": self.size.value(), "opacity": self.opacity.value() / 100,
                "angle": self.angle.value(), "color": (c.redF(), c.greenF(), c.blueF()),
                "where": self.where.currentData()}

    def _refresh(self):
        img_mode = self._is_image()
        for r in range(self._grid.rowCount()):  # show only this mode's controls
            want = {"text": not img_mode, "image": img_mode}.get(self._row_mode.get(r), True)
            for c in range(self._grid.columnCount()):
                item = self._grid.itemAtPosition(r, c)
                if item and item.widget():
                    item.widget().setVisible(want)
        try:
            first = (ds_pdf.parse_ranges(self.pages.text(), self.count) or [0])[0]
            with ds_pdf._open(self.path) as src, fitz.open() as one:
                one.insert_pdf(src, from_page=first, to_page=first)
                if img_mode:
                    if self.image:
                        image, aspect = ds_pdf.load_stamp(self.image)
                        ds_pdf.apply_stamp(one[0], image, aspect, self.scale.value() / 100,
                                           self.where.currentData(), self.opacity.value() / 100)
                else:
                    o = self._options()
                    if o["text"].strip():
                        ds_pdf.apply_text(one[0], o["text"], o["size"], o["opacity"], o["angle"],
                                          o["color"], o["where"])
                img = _render(one[0], 360)
            self.preview.setPixmap(QPixmap.fromImage(img).scaled(
                self.preview.size(), Qt.KeepAspectRatio, Qt.SmoothTransformation))
            ready = bool(self.image) if img_mode else bool(self.text.text().strip())
            _status(self.msg, f"Preview: page {first + 1}" if ready else
                    ("Choose an image to stamp" if img_mode else "Type the watermark text"))
            self.primary_btn.setEnabled(ready)
        except ds_pdf.PdfError as e:
            _status(self.msg, str(e), bad=True)
            self.primary_btn.setEnabled(False)

    def save(self):
        src, pages = self.path, self.pages.text()
        if self._is_image():
            image, scale, where = self.image, self.scale.value() / 100, self.where.currentData()
            opacity = self.opacity.value() / 100
            self.tool_name = "Stamped"
            self.run(lambda: [ds_pdf.stamp_image(src, image, scale, where, pages, opacity)], "Stamping…")
        else:
            o = self._options()
            self.tool_name = "Watermarked"
            self.run(lambda: [ds_pdf.watermark_text(src, pages=pages, **o)], "Watermarking…")


# ================================================================ UNLOCK
class UnlockWindow(ToolWindow):
    tool_name = "Unlocked"

    def __init__(self, path, notify):
        if not ds_pdf.is_encrypted(path):  # before any window exists
            raise ds_pdf.PdfError(f"{Path(path).name} has no password, so there is nothing to unlock")
        super().__init__("Remove PDF password", path, notify, size=(520, 300))
        self.locked = ds_pdf.needs_password(self.path)
        g = QGridLayout()
        self.pw = QLineEdit()
        self.pw.setEchoMode(QLineEdit.Password)
        g.addWidget(QLabel("Password"), 0, 0)
        g.addWidget(self.pw, 0, 1)
        self.body.addLayout(g)
        self.msg = QLabel()
        self.msg.setObjectName("dim")
        self.msg.setWordWrap(True)
        self.body.addWidget(self.msg)
        self.body.addStretch(1)
        self.body.addLayout(self.footer("Unlock", self.save))
        if not self.locked:
            self.pw.setEnabled(False)
            _status(self.msg, "Opens without a password, but has editing/printing restrictions. "
                              "Unlock saves a copy without them.")
        else:
            _status(self.msg, "Saves a copy without the password. The original keeps it.")
            QTimer.singleShot(0, self.pw.setFocus)

    def save(self):
        pw, src = self.pw.text(), self.path
        if self.locked and not ds_pdf.password_ok(src, pw):
            _status(self.msg, "Wrong password. Try again.", bad=True)
            self.pw.selectAll()
            return
        self.run(lambda: [ds_pdf.unlock(src, pw)], "Unlocking…")
