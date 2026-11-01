"""Dijagnostika: gdje se gubi sadrzaj ikona (skica -> PNG)."""
from __future__ import annotations

from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
MOCKUPS = ROOT / "assets" / "mockups"
OUT = ROOT / "assets" / "icons" / "categories" / "modern"

FOCUS = ["vegetables", "animals", "mechanization"]
MAP = {
    "vegetables": "skica_mrkva_moderna_preview.png",
    "animals": "skica_zivotinje_moderna_preview.png",
    "mechanization": "skica_mehanizacija_moderna_preview.png",
}

CROP = {"mechanization": {"side": 0.62, "cy": 0.42}}
DEFAULT = {"side": 0.56, "cy": 0.42}


def crop_window(w: int, h: int, code: str) -> tuple[int, int, int, int]:
    cfg = {**DEFAULT, **CROP.get(code, {})}
    side = int(min(w, h) * cfg["side"])
    cx, cy = w // 2, int(h * cfg["cy"])
    x0 = max(0, cx - side // 2)
    y0 = max(0, cy - side // 2)
    x1 = min(w, x0 + side)
    y1 = min(h, y0 + side)
    return x0, y0, x1, y1


def icon_mask(rgb: np.ndarray, icon_only: bool) -> np.ndarray:
    bright = rgb.mean(axis=2) > 175
    if icon_only:
        ch = rgb.shape[0]
        bright[int(ch * 0.72) :, :] = False  # iskljuci natpis ispod ploce
    return bright


def bbox(mask: np.ndarray) -> tuple[int, int, int, int] | None:
    ys, xs = np.where(mask)
    if len(xs) == 0:
        return None
    return int(xs.min()), int(ys.min()), int(xs.max()), int(ys.max())


def report_bbox(name: str, bb: tuple[int, int, int, int], w: int, h: int) -> None:
    lx, ty, rx, by = bb
    print(f"{name}: bbox=({lx},{ty})-({rx},{by}) na {w}x{h}")
    ml, mt, mr, mb = lx, ty, w - 1 - rx, h - 1 - by
    print(f"  margine: L={ml} T={mt} R={mr} B={mb}")
    if min(ml, mt, mr, mb) < 8:
        print("  >> BLIZU RUBA (<8px)")


def main() -> None:
    for code in FOCUS:
        skica_path = MOCKUPS / MAP[code]
        png_path = OUT / f"{code}.png"
        img = np.array(Image.open(skica_path).convert("RGB"))
        sh, sw = img.shape[:2]
        x0, y0, x1, y1 = crop_window(sw, sh, code)
        crop = img[y0:y1, x0:x1]
        ch, cw = crop.shape[:2]

        print(f"\n=== {code} ===")
        print(f"skica: {sw}x{sh}, crop prozor: ({x0},{y0})-({x1},{y1}) = {cw}x{ch}")

        # Ikona unutar cijele skice (bez natpisa)
        full_icon = bbox(icon_mask(img, icon_only=True))
        if full_icon:
            fx0, fy0, fx1, fy1 = full_icon
            report_bbox("ikona na skici", full_icon, sw, sh)
            outside = fx0 < x0 or fy0 < y0 or fx1 > x1 or fy1 > y1
            print(f"  izvan crop prozora: {outside}")
            if outside:
                print(f"    lijevo  {max(0, x0 - fx0)}px izgubljeno" if fx0 < x0 else "    lijevo OK")
                print(f"    gore    {max(0, y0 - fy0)}px izgubljeno" if fy0 < y0 else "    gore OK")
                print(f"    desno   {max(0, fx1 - x1)}px izgubljeno" if fx1 > x1 else "    desno OK")
                print(f"    dolje   {max(0, fy1 - y1)}px izgubljeno" if fy1 > y1 else "    dolje OK")

        crop_icon = bbox(icon_mask(crop, icon_only=True))
        if crop_icon:
            report_bbox("ikona u cropu (prije PNG)", crop_icon, cw, ch)

        if png_path.exists():
            png = Image.open(png_path)
            pa = np.array(png.split()[-1])
            png_bb = bbox(pa > 20)
            if png_bb:
                report_bbox("finalni PNG", png_bb, png.width, png.height)
                fill_w = (png_bb[2] - png_bb[0] + 1) / png.width
                fill_h = (png_bb[3] - png_bb[1] + 1) / png.height
                print(f"  popuna canvasa: {fill_w:.0%} x {fill_h:.0%}")
                if fill_w > 0.85 or fill_h > 0.85:
                    print("  >> IKONA PREVELIKA U PNG - pri 34px rub nestaje")


if __name__ == "__main__":
    main()
