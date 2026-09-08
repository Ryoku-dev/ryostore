#!/usr/bin/env python3
"""Render eye-candy showcase covers for products that have no real capture yet.

The Store shows every product's ``preview`` as artwork and overlays its own
name, category, and status on top. A cover therefore has to be pure imagery in
the product's own palette, with no baked-in text to duplicate the overlay. This
tool owns exactly ``assets/preview.webp``: a product that ships a real capture
under any other name (for example ``assets/hero.png``) is left untouched.

Each cover is a textless, on-brand composition built from the product's accent
and surface colours, with a motif chosen per category:

  rices      an abstract desktop: wallpaper glow, a floating window, a bar with
             islands, and a dock
  bundles    a grid of tool cards, a few lit in the accent, reading as a set
  barstyles  a prominent bar of islands seated above a window

Geometry is authored in a 1280x720 design space and scaled to OUTPUT_W x
OUTPUT_H, so covers render crisp on HiDPI panels (a 2560-wide hero is upscaled
from nothing). Rendering is deterministic: the seed comes from the product id,
so re-running produces byte-identical output and stable hashes. After writing a
cover the tool repairs the delivery chain it would otherwise break: the preview
row's size and sha256 in the product manifest, and the manifest's own sha256 in
the category registry.
"""
from __future__ import annotations

import argparse
import hashlib
import io
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

DESIGN_W = 1280
OUTPUT_W, OUTPUT_H = 2560, 1440
K = OUTPUT_W / DESIGN_W
WIDTH, HEIGHT = OUTPUT_W, OUTPUT_H
OWNED_PREVIEW = "assets/preview.webp"


def u(value) -> int:
    """Scale a design-space length to output pixels."""
    return int(round(value * K))


def hex_rgb(value: str) -> tuple[int, int, int]:
    value = value.lstrip("#")
    return tuple(int(value[i:i + 2], 16) for i in (0, 2, 4))


def mix(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3))


def darker(c, f):
    return tuple(max(0, int(c[i] / f)) for i in range(3))


def rounded(draw, box, radius, fill=None, outline=None, width=1):
    draw.rounded_rectangle([u(box[0]), u(box[1]), u(box[2]), u(box[3])],
                           radius=u(radius), fill=fill, outline=outline, width=max(1, u(width)))


def ellipse(draw, box, **kw):
    draw.ellipse([u(box[0]), u(box[1]), u(box[2]), u(box[3])], **kw)


def base_wall(accent, surface, glow_xy, glow_r, tilt):
    top = mix(surface, accent, 0.42)
    bottom = darker(surface, 1.5)
    rows = np.linspace(0, 1, HEIGHT)[:, None]
    cols = np.linspace(0, 1, WIDTH)[None, :]
    ramp = np.clip(rows * 0.8 + (1 - cols) * tilt, 0, 1)
    wall = np.zeros((HEIGHT, WIDTH, 3), np.float32)
    for i in range(3):
        wall[:, :, i] = top[i] * (1 - ramp) + bottom[i] * ramp
    img = Image.fromarray(wall.astype(np.uint8), "RGB")

    mask = Image.new("L", (WIDTH, HEIGHT), 0)
    gx, gy = int(WIDTH * glow_xy[0]), int(HEIGHT * glow_xy[1])
    gr = int(WIDTH * glow_r)
    ImageDraw.Draw(mask).ellipse([gx - gr, gy - gr, gx + gr, gy + gr], fill=255)
    mask = mask.filter(ImageFilter.GaussianBlur(u(170)))
    glow = np.asarray(img, np.float32) + (np.asarray(mask, np.float32) / 255 * 0.5)[:, :, None] * np.array(
        mix(accent, (255, 255, 255), 0.4)
    )
    return Image.fromarray(np.clip(glow, 0, 255).astype(np.uint8), "RGB")


def finish(img, seed):
    rng = np.random.default_rng(seed)
    noise = rng.normal(0, 1, (HEIGHT, WIDTH)).astype(np.float32) * 8.0
    current = np.asarray(img, np.float32) + noise[:, :, None]
    ys, xs = np.mgrid[0:HEIGHT, 0:WIDTH]
    dist = np.sqrt(((xs - WIDTH / 2) / (WIDTH / 2)) ** 2 + ((ys - HEIGHT / 2) / (HEIGHT / 2)) ** 2)
    vignette = np.clip(1 - (dist - 0.72) * 0.7, 0.42, 1.0)
    return Image.fromarray(np.clip(current * vignette[:, :, None], 0, 255).astype(np.uint8), "RGB")


def rice_desktop(accent, surface, seed):
    img = base_wall(accent, surface, (0.7, 0.15), 0.55, 0.3)
    overlay = Image.new("RGBA", (WIDTH, HEIGHT), (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay)
    lift = mix(surface, (255, 255, 255), 0.06)
    ink = mix(surface, (255, 255, 255), 0.5)

    rounded(draw, [70, 54, DESIGN_W - 70, 104], 16, fill=darker(surface, 1.1) + (220,))
    rounded(draw, [86, 64, 250, 94], 10, fill=accent + (210,))
    for x0 in (DESIGN_W / 2 - 150, DESIGN_W / 2 - 40, DESIGN_W / 2 + 70):
        rounded(draw, [x0, 64, x0 + 90, 94], 10, fill=lift + (220,))
    rounded(draw, [DESIGN_W - 250, 64, DESIGN_W - 86, 94], 10, fill=lift + (220,))

    wx, wy, ww, wh = 150, 180, 560, 360
    rounded(draw, [wx, wy, wx + ww, wy + wh], 20, fill=lift + (240,), outline=accent + (120,), width=2)
    rounded(draw, [wx, wy, wx + ww, wy + 46], 20, fill=darker(lift, 1.15) + (255,))
    for i, cx in enumerate((wx + 26, wx + 50, wx + 74)):
        ellipse(draw, [cx - 6, wy + 17, cx + 6, wy + 29], fill=(accent if i == 0 else ink) + (230,))
    for i in range(5):
        yl = wy + 90 + i * 46
        line = ww - 90 if i % 2 else ww - 180
        rounded(draw, [wx + 30, yl, wx + 30 + line, yl + 16], 8, fill=ink + (70 if i else 150,))

    rounded(draw, [wx + ww + 40, wy, DESIGN_W - 150, wy + wh], 20, fill=darker(surface, 1.05) + (220,),
            outline=accent + (60,), width=2)
    for i in range(6):
        yl = wy + 40 + i * 54
        ellipse(draw, [wx + ww + 70, yl, wx + ww + 94, yl + 24], fill=accent + (150,) if i == 0 else ink + (60,))
        rounded(draw, [wx + ww + 110, yl + 4, DESIGN_W - 190, yl + 18], 6, fill=ink + (60,))

    dock = 6 * 72
    dx = (DESIGN_W - dock) // 2
    dh = 720
    rounded(draw, [dx - 16, dh - 104, dx + dock + 16, dh - 40], 18, fill=darker(surface, 1.2) + (210,))
    for i in range(6):
        colour = accent if i in (0, 3) else lift
        rounded(draw, [dx + i * 72 + 8, dh - 96, dx + i * 72 + 56, dh - 48], 12, fill=colour + (230,))

    img = Image.alpha_composite(img.convert("RGBA"), overlay).convert("RGB")
    return finish(img, seed)


def bundle_tiles(accent, surface, seed):
    img = base_wall(accent, surface, (0.78, 0.1), 0.5, 0.25)
    overlay = Image.new("RGBA", (WIDTH, HEIGHT), (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay)
    lift = mix(surface, (255, 255, 255), 0.07)
    ink = mix(surface, (255, 255, 255), 0.5)

    cols, rows = 4, 3
    tw, th, gx, gy = 210, 150, 44, 40
    grid_w = cols * tw + (cols - 1) * gx
    grid_h = rows * th + (rows - 1) * gy
    ox = (DESIGN_W - grid_w) // 2
    oy = (720 - grid_h) // 2 + 6
    for r in range(rows):
        for c in range(cols):
            x = ox + c * (tw + gx)
            y = oy + r * (th + gy)
            hot = (r * cols + c) in (0, 5, 10)
            fill = mix(surface, accent, 0.5) if hot else lift
            rounded(draw, [x, y, x + tw, y + th], 18, fill=fill + (235,),
                    outline=accent + (90,) if hot else ink + (40,), width=2)
            rounded(draw, [x + 22, y + 22, x + 70, y + 70], 12,
                    fill=(mix(accent, (255, 255, 255), 0.15) if hot else accent) + (200,))
            rounded(draw, [x + 86, y + 30, x + tw - 24, y + 44], 6,
                    fill=(ink if not hot else mix(accent, (255, 255, 255), 0.4)) + (150,))
            rounded(draw, [x + 86, y + 54, x + tw - 52, y + 66], 6, fill=ink + (80,))
            for li in range(2):
                rounded(draw, [x + 22, y + 92 + li * 22, x + tw - 24 - (li * 40), y + 104 + li * 22], 6,
                        fill=ink + (70,))

    img = Image.alpha_composite(img.convert("RGBA"), overlay).convert("RGB")
    return finish(img, seed)


def bar_style(accent, surface, seed):
    img = base_wall(accent, surface, (0.5, 0.62), 0.6, 0.0)
    overlay = Image.new("RGBA", (WIDTH, HEIGHT), (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay)
    lift = mix(surface, (255, 255, 255), 0.08)
    ink = mix(surface, (255, 255, 255), 0.55)
    bar_bg = darker(surface, 1.15)
    cx0 = DESIGN_W / 2

    by, bh = 150, 76
    rounded(draw, [70, by, DESIGN_W - 70, by + bh], 22, fill=bar_bg + (235,), outline=accent + (70,), width=2)
    rounded(draw, [92, by + 16, 300, by + bh - 16], 14, fill=lift + (230,))
    for i in range(5):
        cx = 112 + i * 36
        ellipse(draw, [cx, by + bh // 2 - 7, cx + 14, by + bh // 2 + 7], fill=(accent if i == 1 else ink) + (230,))
    rounded(draw, [cx0 - 190, by + 16, cx0 + 190, by + bh - 16], 14, fill=lift + (230,))
    rounded(draw, [cx0 - 150, by + bh // 2 - 8, cx0 - 30, by + bh // 2 + 8], 6, fill=accent + (210,))
    rounded(draw, [cx0 - 10, by + bh // 2 - 8, cx0 + 150, by + bh // 2 + 8], 6, fill=ink + (120,))
    rounded(draw, [DESIGN_W - 300, by + 16, DESIGN_W - 92, by + bh - 16], 14, fill=lift + (230,))
    for i, frac in enumerate((0.6, 0.35, 0.8)):
        x0 = DESIGN_W - 286 + i * 66
        rounded(draw, [x0, by + bh - 30, x0 + 48, by + bh - 22], 4, fill=ink + (70,))
        rounded(draw, [x0, by + bh - 30, x0 + 48 * frac, by + bh - 22], 4, fill=accent + (200,))

    rounded(draw, [210, by + bh + 70, DESIGN_W - 210, 720 - 70], 20,
            fill=mix(surface, (255, 255, 255), 0.04) + (200,), outline=accent + (45,), width=2)
    rounded(draw, [210, by + bh + 70, DESIGN_W - 210, by + bh + 116], 20, fill=bar_bg + (220,))
    for i, cx in enumerate((246, 276, 306)):
        ellipse(draw, [cx - 6, by + bh + 86, cx + 6, by + bh + 98], fill=(accent if i == 0 else ink) + (220,))
    for i in range(4):
        yl = by + bh + 150 + i * 46
        rounded(draw, [250, yl, DESIGN_W - 260 - (i % 2) * 120, yl + 16], 8, fill=ink + (60 if i else 130,))

    img = Image.alpha_composite(img.convert("RGBA"), overlay).convert("RGB")
    return finish(img, seed)

def lockscreen_scene(accent, surface, seed):
    img = base_wall(accent, surface, (0.5, 0.12), 0.62, 0.0)
    overlay = Image.new("RGBA", (WIDTH, HEIGHT), (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay)
    lift = mix(surface, (255, 255, 255), 0.08)
    ink = mix(surface, (255, 255, 255), 0.6)
    cx = DESIGN_W / 2

    def digit(x, y, on):
        col = accent if on else ink
        alpha = 210 if on else 90
        for dy in (0, 26, 52):
            rounded(draw, [x, y + dy, x + 64, y + dy + 16], 6, fill=col + (alpha,))
        rounded(draw, [x, y, x + 16, y + 68], 6, fill=col + (alpha,))
        rounded(draw, [x + 48, y, x + 64, y + 68], 6, fill=col + (alpha,))

    ty = 250
    digit(cx - 210, ty, True)
    digit(cx - 120, ty, True)
    for oy in (ty + 14, ty + 44):
        ellipse(draw, [cx - 20, oy, cx - 4, oy + 16], fill=accent + (230,))
    digit(cx + 20, ty, False)
    digit(cx + 110, ty, False)

    rounded(draw, [cx - 110, ty + 108, cx + 110, ty + 124], 8, fill=ink + (80,))

    ellipse(draw, [cx - 26, 500, cx + 26, 552], fill=lift + (235,), outline=accent + (120,), width=2)
    rounded(draw, [cx - 190, 580, cx + 190, 624], 22, fill=lift + (220,), outline=accent + (70,), width=2)
    rounded(draw, [cx - 174, 594, cx - 30, 610], 6, fill=accent + (200,))

    img = Image.alpha_composite(img.convert("RGBA"), overlay).convert("RGB")
    return finish(img, seed)



# ── Colour schemes ─────────────────────────────────────────────────────────
# Colour schemes are not manifest products: each is colorschemes/<Name>/<Name>.json
# ({dark?,light?} of Material roles) plus an optional preview. When a scheme ships
# no real art we bake a Ryoku-style card -- the desktop's own colour-scheme tile
# (ThemeCell) rendered as a cover: a paper-and-ink canvas, the bar wearing the
# palette across its islands, a floating window in surface+ink (app content
# carries no accent), and the five role pills [onSurface, primary, secondary,
# tertiary, error] as the hero. A real preview always wins; this only fills gaps.
CS_DW = 1280
CS_OW, CS_OH = 1600, 900
CS_K = CS_OW / CS_DW
RAW_BASE = "https://raw.githubusercontent.com/ryoku-dev/ryostore/main"


def _cu(value) -> int:
    return int(round(value * CS_K))


def _luma(c) -> float:
    return (0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2]) / 255


def _crr(draw, box, rad, fill=None, outline=None, width=1):
    draw.rounded_rectangle([_cu(box[0]), _cu(box[1]), _cu(box[2]), _cu(box[3])],
                           radius=_cu(rad), fill=fill, outline=outline, width=max(1, _cu(width)))


def _cel(draw, box, **kw):
    draw.ellipse([_cu(box[0]), _cu(box[1]), _cu(box[2]), _cu(box[3])], **kw)


def _cs_masks():
    """Glow, vignette, and float-shadow masks -- geometry is fixed across every
    card, so blur them once and reuse (keeps a whole-catalogue render fast)."""
    m = Image.new("L", (CS_OW, CS_OH), 0)
    gr = int(CS_OW * 0.42)
    ImageDraw.Draw(m).ellipse([int(CS_OW * 0.78) - gr, int(CS_OH * 0.12) - gr,
                               int(CS_OW * 0.78) + gr, int(CS_OH * 0.12) + gr], fill=255)
    glow = np.asarray(m.filter(ImageFilter.GaussianBlur(_cu(130))), np.float32) / 255
    ys, xs = np.mgrid[0:CS_OH, 0:CS_OW]
    dist = np.sqrt(((xs - CS_OW / 2) / (CS_OW / 2)) ** 2 + ((ys - CS_OH / 2) / (CS_OH / 2)) ** 2)
    vig = np.clip(1 - (dist - 0.72) * 0.55, 0.5, 1.0)[:, :, None]
    wx, wy, ww, wh = 150, 300, 470, 300
    px, pw, ph, py = (CS_DW - 520) / 2 + 120, 520, 300, 250
    sh = Image.new("L", (CS_OW, CS_OH), 0)
    sd = ImageDraw.Draw(sh)
    sd.rounded_rectangle([_cu(wx + 10), _cu(wy + 16), _cu(wx + ww + 10), _cu(wy + wh + 16)], radius=_cu(18), fill=95)
    sd.rounded_rectangle([_cu(px + 8), _cu(py + 16), _cu(px + pw + 8), _cu(py + ph + 16)], radius=_cu(26), fill=120)
    shadow = np.asarray(sh.filter(ImageFilter.GaussianBlur(_cu(9))), np.float32) / 255
    return glow, vig, shadow


_CS_GLOW, _CS_VIG, _CS_SHADOW = _cs_masks()


def colorscheme_card(sw, seed):
    """sw = [surface, onSurface, primary, secondary, tertiary, error, outline]."""
    surface, on_s, prim, sec, ter, err, outl = [hex_rgb(c) for c in sw]
    dark = _luma(surface) < 0.5
    top = mix(surface, prim, 0.12 if dark else 0.05)
    bot = darker(surface, 1.6) if dark else mix(surface, (0, 0, 0), 0.07)
    ramp = np.linspace(0, 1, CS_OH)[:, None]
    wall = np.empty((CS_OH, CS_OW, 3), np.float32)
    for i in range(3):
        wall[:, :, i] = top[i] * (1 - ramp) + bot[i] * ramp
    glowc = np.array(mix(prim, (255, 255, 255), 0.4), np.float32)
    wall += (_CS_GLOW * (0.32 if dark else 0.16))[:, :, None] * glowc
    wall *= (1 - _CS_SHADOW * 0.5)[:, :, None]
    img = Image.fromarray(np.clip(wall, 0, 255).astype(np.uint8), "RGB")
    ov = Image.new("RGBA", (CS_OW, CS_OH), (0, 0, 0, 0))
    d = ImageDraw.Draw(ov)
    lift = mix(surface, on_s, 0.10)
    ink = on_s
    wx, wy, ww, wh = 150, 300, 470, 300
    px, pw, ph, py = (CS_DW - 520) / 2 + 120, 520, 300, 250
    by, bh = 40, 58
    # the bar wears the whole palette across its islands
    _crr(d, [70, by, CS_DW - 70, by + bh], 20, fill=lift + (235,), outline=outl + (150,), width=1)
    _crr(d, [88, by + 14, 168, by + bh - 14], 13, fill=prim + (235,))
    for i, cx in enumerate((CS_DW / 2 - 150, CS_DW / 2 - 96, CS_DW / 2 - 42)):
        col = prim if i == 1 else ink
        _cel(d, [cx, by + bh / 2 - 6, cx + 12, by + bh / 2 + 6], fill=col + (230 if i == 1 else 120,))
    _crr(d, [CS_DW / 2 + 30, by + 16, CS_DW / 2 + 220, by + bh - 16], 12, fill=ink + (38,))
    _crr(d, [CS_DW / 2 + 44, by + bh / 2 - 4, CS_DW / 2 + 150, by + bh / 2 + 4], 5, fill=sec + (210,))
    for i, c in enumerate((ter, sec, err)):
        cx = CS_DW - 250 + i * 54
        _cel(d, [cx, by + bh / 2 - 7, cx + 14, by + bh / 2 + 7], fill=c + (220,))
    # paper-and-ink context window: surface + ink, no accent
    _crr(d, [wx, wy, wx + ww, wy + wh], 18, fill=surface + (255,), outline=outl + (160,), width=1)
    _crr(d, [wx, wy, wx + ww, wy + 42], 18, fill=lift + (255,))
    d.rectangle([_cu(wx), _cu(wy + 30), _cu(wx + ww), _cu(wy + 42)], fill=lift + (255,))
    for i, cx in enumerate((wx + 24, wx + 46, wx + 68)):
        _cel(d, [cx - 6, wy + 15, cx + 6, wy + 27], fill=(prim if i == 0 else ink) + (200 if i == 0 else 90,))
    for i in range(4):
        yl = wy + 70 + i * 40
        ln = ww - 70 if i % 2 else ww - 150
        _crr(d, [wx + 28, yl, wx + 28 + ln, yl + 13], 6, fill=ink + (60 if i else 120,))
    # hero: the ThemeCell plate with the five role pills
    _crr(d, [px, py, px + pw, py + ph], 26, fill=surface + (255,), outline=outl + (220,), width=2)
    pills = [on_s, prim, sec, ter, err]
    pad, gap = 46, 14
    pill_w = (pw - 2 * pad - gap * 4) / 5
    py0, ph0 = py + 70, ph - 110
    for i, c in enumerate(pills):
        x0 = px + pad + i * (pill_w + gap)
        _crr(d, [x0, py0, x0 + pill_w, py0 + ph0], pill_w / 2, fill=c + (255,))
    _cel(d, [px + pw - 34, py + 20, px + pw - 20, py + 34], fill=ink + (230,))
    out = np.asarray(Image.alpha_composite(img.convert("RGBA"), ov).convert("RGB"), np.float32)
    out += np.random.default_rng(seed).normal(0, 1, (CS_OH, CS_OW)).astype(np.float32)[:, :, None] * 2.0
    return Image.fromarray(np.clip(out * _CS_VIG, 0, 255).astype(np.uint8), "RGB")


def _cs_swatches(block: dict) -> list[str]:
    g = block.get
    return [g("mSurface", "#101010"), g("mOnSurface", "#cdc4ba"), g("mPrimary", "#cdc4ba"),
            g("mSecondary", g("mPrimary", "#888888")), g("mTertiary", g("mPrimary", "#888888")),
            g("mError", "#cc4444"), g("mOutline", g("mOnSurface", "#888888"))]


def regenerate_colorschemes(root: Path) -> list[str]:
    """Bake a preview.jpg card for every scheme that ships no real art, and point
    its registry `preview` at the raw URL. A scheme that already has a preview is
    left untouched."""
    from urllib.parse import quote
    registry_path = root / "colorschemes" / "registry.json"
    registry = json.loads(registry_path.read_text(encoding="utf-8"))
    changed: list[str] = []
    for entry in registry.get("themes", []):
        if entry.get("preview"):
            continue
        block = entry.get("dark") or entry.get("light")
        if not block:
            continue
        folder = root / entry["path"]
        folder.mkdir(parents=True, exist_ok=True)
        colorscheme_card(_cs_swatches(block), seed_for(entry["id"])).save(folder / "preview.jpg", quality=85)
        entry["preview"] = f"{RAW_BASE}/{quote(entry['path'], safe='/')}/preview.jpg"
        changed.append(entry["id"])
    registry_path.write_bytes(dump_json(registry))
    return changed


MOTIFS = {"rices": rice_desktop, "bundles": bundle_tiles, "barstyles": bar_style,
          "lockscreens": lockscreen_scene}
DEFAULT_ACCENT = "#cdc4ba"
DEFAULT_SURFACE = "#101010"


def seed_for(product_id: str) -> int:
    return int.from_bytes(hashlib.sha256(product_id.encode()).digest()[:8], "big")


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def dump_json(value) -> bytes:
    return (json.dumps(value, indent=2, ensure_ascii=False) + "\n").encode("utf-8")


def render_cover(category: str, accent_hex: str, surface_hex: str, product_id: str) -> bytes:
    accent = hex_rgb(accent_hex if isinstance(accent_hex, str) and accent_hex else DEFAULT_ACCENT)
    surface = hex_rgb(surface_hex if isinstance(surface_hex, str) and surface_hex else DEFAULT_SURFACE)
    image = MOTIFS[category](accent, surface, seed_for(product_id))
    buffer = io.BytesIO()
    image.save(buffer, "WEBP", quality=90, method=6)
    return buffer.getvalue()


def regenerate(root: Path, category: str) -> list[str]:
    changed: list[str] = []
    registry_path = root / category / "registry.json"
    registry = json.loads(registry_path.read_text(encoding="utf-8"))
    for entry in registry.get(category, []):
        preview = entry.get("preview")
        if preview != OWNED_PREVIEW:
            continue
        product = root / entry["path"]
        cover = render_cover(category, entry.get("accent"), entry.get("surface"), entry["id"])
        (product / preview).write_bytes(cover)

        manifest_name = entry["manifest"]
        manifest_path = product / manifest_name
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
        for row in manifest["files"]:
            if row.get("source") == preview:
                row["size"] = len(cover)
                row["sha256"] = sha256_bytes(cover)
                break
        else:
            raise SystemExit(f"{category}/{entry['id']}: manifest does not declare {preview}")
        manifest_bytes = dump_json(manifest)
        manifest_path.write_bytes(manifest_bytes)
        entry["manifestSha256"] = sha256_bytes(manifest_bytes)
        changed.append(f"{category}/{entry['id']}")
    registry_path.write_bytes(dump_json(registry))
    return changed


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Render eye-candy showcase covers and repair the delivery hashes")
    parser.add_argument("--root", default=".", help="catalogue root")
    parser.add_argument("--categories", default=",".join(MOTIFS), help="comma-separated categories to render")
    args = parser.parse_args(argv)
    root = Path(args.root).resolve()
    selected = [c.strip() for c in args.categories.split(",") if c.strip()]
    for category in selected:
        if category not in MOTIFS and category != "colorschemes":
            raise SystemExit(f"no showcase motif for category {category!r}")
    total: list[str] = []
    for category in selected:
        rendered = regenerate_colorschemes(root) if category == "colorschemes" else regenerate(root, category)
        total.extend(rendered)
        print(f"{category}: rendered {len(rendered)} cover(s)")
    print(f"showcase: {len(total)} product cover(s) refreshed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
