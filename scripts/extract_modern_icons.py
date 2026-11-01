"""Potvrđene skice -> PNG ikone (samo linije, bez ruba pločice).

1. Makni natpis (donjih ~28 %)
2. Zelena -> prozirna, bijelo ostaje
3. Bbox bijelog sadržaja; ako je to cijela pločica, inset ~11 % (makni rub)
4. Padding oko ikone, skaliraj u kvadrat — ništa se ne reže
"""
from __future__ import annotations

from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
MOCKUPS = ROOT / "assets" / "mockups"
OUT = ROOT / "assets" / "icons" / "categories" / "modern"

MAP = {
    "vegetables": "skica_mrkva_moderna_preview.png",
    "fruit": "skica_jabuka_moderna_preview.png",
    "cereals": "skica_zitarica_moderna_preview.png",
    "animals": "skica_zivotinje_moderna_preview.png",
    "mechanization": "skica_mehanizacija_moderna_preview.png",
    "fertilizers_stimulants": "skica_djubrivo_moderna_preview.png",
    "plant_protection": "skica_kemija_moderna_preview.png",
}

CANVAS = 256
MAX_SIDE = 180
LABEL_CUT = 0.72
TILE_INSET = 0.11
PAD_RATIO = 0.10


def green_to_alpha(rgb: np.ndarray) -> Image.Image:
    r = rgb[:, :, 0].astype(np.float32)
    g = rgb[:, :, 1].astype(np.float32)
    b = rgb[:, :, 2].astype(np.float32)
    bright = (r + g + b) / 3.0
    green = (g > r + 6) & (g > b + 4) & (g > 38)
    alpha = np.zeros(rgb.shape[:2], dtype=np.uint8)
    alpha[(~green) & (bright > 150)] = 255
    rgba = np.zeros((*rgb.shape[:2], 4), dtype=np.uint8)
    rgba[:, :, 0:3] = 255
    rgba[:, :, 3] = alpha
    return Image.fromarray(rgba, "RGBA")


def alpha_bbox(alpha: np.ndarray, threshold: int = 20) -> tuple[int, int, int, int] | None:
    ys, xs = np.where(alpha > threshold)
    if len(xs) == 0:
        return None
    return int(xs.min()), int(ys.min()), int(xs.max()), int(ys.max())


def looks_like_tile(bw: int, bh: int) -> bool:
    side = min(bw, bh)
    return side > 380 and abs(bw - bh) < side * 0.18


def extract_icon(src: Path) -> Image.Image:
    img = Image.open(src).convert("RGB")
    w, h = img.size
    top_h = int(h * LABEL_CUT)
    work = np.array(img.crop((0, 0, w, top_h)))
    rgba = np.array(green_to_alpha(work))
    alpha = rgba[:, :, 3]

    bb = alpha_bbox(alpha)
    if bb is None:
        raise RuntimeError(f"No icon pixels in {src.name}")

    x0, y0, x1, y1 = bb
    bw, bh = x1 - x0 + 1, y1 - y0 + 1

    if looks_like_tile(bw, bh):
        inset = int(min(bw, bh) * TILE_INSET)
        sub = alpha[y0 + inset : y1 - inset + 1, x0 + inset : x1 - inset + 1]
        inner = alpha_bbox(sub)
        if inner is not None:
            ix0, iy0, ix1, iy1 = inner
            x0, y0 = x0 + inset + ix0, y0 + inset + iy0
            x1, y1 = x0 + (ix1 - ix0), y0 + (iy1 - iy0)

    bw, bh = x1 - x0 + 1, y1 - y0 + 1
    pad = max(10, int(max(bw, bh) * PAD_RATIO))
    x0 = max(0, x0 - pad)
    y0 = max(0, y0 - pad)
    x1 = min(w - 1, x1 + pad)
    y1 = min(top_h - 1, y1 + pad)

    crop = work[y0 : y1 + 1, x0 : x1 + 1]
    icon = green_to_alpha(crop)

    out = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    icon.thumbnail((MAX_SIDE, MAX_SIDE), Image.Resampling.LANCZOS)
    ox = (CANVAS - icon.width) // 2
    oy = (CANVAS - icon.height) // 2
    out.paste(icon, (ox, oy), icon)
    return out


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    for code, fname in MAP.items():
        out_path = OUT / f"{code}.png"
        extract_icon(MOCKUPS / fname).save(out_path)
        im = Image.open(out_path)
        bb = im.getbbox()
        if bb:
            m = min(bb[0], bb[1], im.width - bb[2], im.height - bb[3])
            fill = max(bb[2] - bb[0], bb[3] - bb[1]) / CANVAS
            print(f"OK {code} margin={m}px fill={fill:.0%}")
        else:
            print(f"WARN {code} empty")


if __name__ == "__main__":
    main()
