"""Analyze tile vs inner icon bounding boxes on skicas."""
from __future__ import annotations

from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
MOCKUPS = ROOT / "assets" / "mockups"

MAP = {
    "vegetables": "skica_mrkva_moderna_preview.png",
    "fruit": "skica_jabuka_moderna_preview.png",
    "cereals": "skica_zitarica_moderna_preview.png",
    "animals": "skica_zivotinje_moderna_preview.png",
    "mechanization": "skica_mehanizacija_moderna_preview.png",
    "fertilizers_stimulants": "skica_djubrivo_moderna_preview.png",
    "plant_protection": "skica_kemija_moderna_preview.png",
}


def tile_and_icon_bbox(path: Path, inset_pct: float = 0.12) -> dict:
    img = np.array(Image.open(path).convert("RGB"))
    h, w = img.shape[:2]
    r, g, b = img[:, :, 0].astype(float), img[:, :, 1].astype(float), img[:, :, 2].astype(float)
    bright = (r + g + b) / 3 > 175
    green = (g > r + 6) & (g > b + 4) & (g > 38)
    white = bright & (~green)
    cutoff = int(h * 0.72)
    wt = white.copy()
    wt[cutoff:, :] = False
    ys, xs = np.where(wt)
    tx0, ty0, tx1, ty1 = int(xs.min()), int(ys.min()), int(xs.max()), int(ys.max())
    tw, th = tx1 - tx0 + 1, ty1 - ty0 + 1
    inset = int(min(tw, th) * inset_pct)
    ix0, iy0 = tx0 + inset, ty0 + inset
    ix1, iy1 = tx1 - inset, ty1 - inset
    inner = wt[iy0 : iy1 + 1, ix0 : ix1 + 1]
    iys, ixs = np.where(inner)
    icon = (
        ix0 + int(ixs.min()),
        iy0 + int(iys.min()),
        ix0 + int(ixs.max()),
        iy0 + int(iys.max()),
    )
    return {"tile": (tx0, ty0, tx1, ty1), "icon": icon, "inset": inset}


def main() -> None:
    for code, fname in MAP.items():
        r = tile_and_icon_bbox(MOCKUPS / fname)
        t, i = r["tile"], r["icon"]
        print(
            f"{code}: tile={t[2]-t[0]+1}x{t[3]-t[1]+1} "
            f"icon=({i[0]},{i[1]})-({i[2]},{i[3]}) "
            f"size={i[2]-i[0]+1}x{i[3]-i[1]+1} inset={r['inset']}"
        )


if __name__ == "__main__":
    main()
