"""Izreži đubrivo i kemiju 1:1 iz referentne slike (zelena -> transparentno)."""
from __future__ import annotations

from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SRC = Path(
    r"C:\Users\User\.cursor\projects\c-Users-User-my-farmer\assets"
    r"\c__Users_User_AppData_Roaming_Cursor_User_workspaceStorage_de12944fed8fc7557c219fc1f4eddc42_images"
    r"_Screenshot_2026-08-22_005643-ae590ae4-0152-41d7-a9ef-7d026b6cafa8.png"
)
OUT = ROOT / "assets" / "icons" / "categories"
DEBUG = OUT / "_debug"


def white_alpha(rgb: np.ndarray) -> Image.Image:
    r = rgb[:, :, 0].astype(np.float32)
    g = rgb[:, :, 1].astype(np.float32)
    b = rgb[:, :, 2].astype(np.float32)
    # Bijeli stroke ima visok R i B; zelena pozadina ima niske R/B.
    strength = np.maximum(r, b)
    alpha = np.clip((strength - 95.0) * 2.8, 0, 255).astype(np.uint8)
    rgba = np.zeros((*rgb.shape[:2], 4), dtype=np.uint8)
    rgba[:, :, 0:3] = 255
    rgba[:, :, 3] = alpha
    return Image.fromarray(rgba, "RGBA")


def to_square(icon: Image.Image, size: int = 128) -> Image.Image:
    bbox = icon.getbbox()
    if bbox:
        icon = icon.crop(bbox)
    square = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    pad = 8
    icon.thumbnail((size - pad * 2, size - pad * 2), Image.Resampling.LANCZOS)
    square.paste(icon, ((size - icon.width) // 2, (size - icon.height) // 2), icon)
    return square


def main() -> None:
    src = Image.open(SRC).convert("RGB")
    w, h = src.size
    DEBUG.mkdir(parents=True, exist_ok=True)

    # 3 kolone, 3 reda — donji red: đubrivo | prazno | kemija
    # Kalibracija na 338x433 referenci.
    left, top = 22, 28
    tile_w, tile_h = 92, 118
    gap_x, gap_y = 10, 12
    icon_inset = (8, 6, 8, 36)

    crops = {
        "fertilizers_stimulants": (2, 0),
        "plant_protection": (2, 2),
        "mechanization": (1, 2),
    }

    for name, (row, col) in crops.items():
        x0 = left + col * (tile_w + gap_x) + icon_inset[0]
        y0 = top + row * (tile_h + gap_y) + icon_inset[1]
        x1 = left + col * (tile_w + gap_x) + tile_w - icon_inset[2]
        y1 = top + row * (tile_h + gap_y) + tile_h - icon_inset[3]
        x0, y0 = max(0, x0), max(0, y0)
        x1, y1 = min(w, x1), min(h, y1)
        region = src.crop((x0, y0, x1, y1))
        region.save(DEBUG / f"src_{name}.png")
        icon = to_square(white_alpha(np.array(region)), 128)
        dest = OUT / f"{name}.png"
        icon.save(dest)
        print(f"{name}: {dest} box=({x0},{y0},{x1},{y1})")


if __name__ == "__main__":
    main()
