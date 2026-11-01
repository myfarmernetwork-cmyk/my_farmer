"""Izreže ikone iz referentne slike kategorija i generira preview."""
from __future__ import annotations

from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
SRC = Path(
    r"C:\Users\User\.cursor\projects\c-Users-User-my-farmer\assets"
    r"\c__Users_User_AppData_Roaming_Cursor_User_workspaceStorage_de12944fed8fc7557c219fc1f4eddc42_images"
    r"_Screenshot_2026-08-22_005643-42919a1d-c007-415e-9c12-9d2728327e87.png"
)
OUT_DIR = ROOT / "assets" / "icons" / "categories" / "cropped"
OUT_TILES = ROOT / "assets" / "icons" / "categories" / "cropped_tiles"
PREVIEW = ROOT / "assets" / "mockups" / "mockup_category_icons_cropped.png"

# Kalibracija cal1 — referenca 338×433
LEFT, TOP = 28, 34
TILE_W, TILE_H = 80, 104
GAP_X, GAP_Y = 16, 16

NAMES = [
    "all",
    "vegetables",
    "fruit",
    "animals",
    "cereals",
    "mechanization",
    "fertilizers_stimulants",
    "plant_protection",
]

GRID_SLOTS = [
    (0, 0),
    (0, 1),
    (0, 2),
    (1, 0),
    (1, 1),
    (1, 2),
    (2, 0),
    (2, 2),
]

LABELS = [
    "Sve",
    "Povrće",
    "Voće",
    "Životinje",
    "Žitarice",
    "Mehanizacija",
    "Đubrivo",
    "Kemija",
]

# Posebni inset po ikoni (l, t, r, b) — bez teksta
ICON_INSETS: dict[str, tuple[int, int, int, int]] = {
    "all": (6, 6, 6, 38),
    "animals": (8, 0, 8, 32),
}
DEFAULT_INSET = (8, 4, 8, 32)


def tile_bbox(col: int, row: int) -> tuple[int, int, int, int]:
    x0 = LEFT + col * (TILE_W + GAP_X)
    y0 = TOP + row * (TILE_H + GAP_Y)
    return x0, y0, x0 + TILE_W, y0 + TILE_H


def icon_bbox(name: str, col: int, row: int) -> tuple[int, int, int, int]:
    x0, y0, x1, y1 = tile_bbox(col, row)
    l, t, r, b = ICON_INSETS.get(name, DEFAULT_INSET)
    return x0 + l, y0 + t, x1 - r, y1 - b


def extract_white_icon(region: Image.Image, size: int = 96) -> Image.Image:
    rgb = np.array(region.convert("RGB"), dtype=np.int16)
    bright = (
        (rgb[:, :, 0] > 140)
        & (rgb[:, :, 1] > 140)
        & (rgb[:, :, 2] > 140)
        & (rgb.mean(axis=2) > 150)
    )
    rgba = np.zeros((*rgb.shape[:2], 4), dtype=np.uint8)
    rgba[:, :, 0:3] = 255
    rgba[:, :, 3] = (bright * 255).astype(np.uint8)

    icon = Image.fromarray(rgba, "RGBA")
    bbox = icon.getbbox()
    if bbox:
        icon = icon.crop(bbox)

    square = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    icon.thumbnail((size - 4, size - 4), Image.Resampling.LANCZOS)
    ox = (size - icon.width) // 2
    oy = (size - icon.height) // 2
    square.paste(icon, (ox, oy), icon)
    return square


def square_tile_from_source(region: Image.Image, size: int = 120) -> Image.Image:
    """Cijela pločica iz reference — kvadrat."""
    sq = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    fitted = region.copy()
    fitted.thumbnail((size, size), Image.Resampling.LANCZOS)
    ox = (size - fitted.width) // 2
    oy = (size - fitted.height) // 2
    sq.paste(fitted, (ox, oy))
    return sq


def main() -> None:
    src = Image.open(SRC).convert("RGBA")
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    OUT_TILES.mkdir(parents=True, exist_ok=True)

    icons: list[Image.Image] = []
    tiles: list[Image.Image] = []

    for name, (row, col) in zip(NAMES, GRID_SLOTS):
        ibox = icon_bbox(name, col, row)
        tbox = tile_bbox(col, row)
        region = src.crop(ibox)
        tile_region = src.crop(tbox)

        icon = extract_white_icon(region, size=96)
        icon.save(OUT_DIR / f"{name}.png")

        tile = square_tile_from_source(tile_region, size=120)
        tile.save(OUT_TILES / f"{name}.png")

        icons.append(icon)
        tiles.append(tile)

    gap = 12
    cell = 120
    cols, rows = 3, 3
    pw = cols * cell + (cols + 1) * gap
    ph = rows * cell + (rows + 1) * gap + 36
    panel = Image.new("RGBA", (pw, ph), (8, 58, 42, 255))
    draw = ImageDraw.Draw(panel)

    try:
        font = ImageFont.truetype("segoeui.ttf", 11)
        title = ImageFont.truetype("segoeuib.ttf", 13)
    except OSError:
        font = ImageFont.load_default()
        title = font

    draw.text((gap, 8), "Izrezane ikone iz reference (1:1)", fill=(255, 255, 255, 255), font=title)

    for idx, ((row, col), icon, label) in enumerate(zip(GRID_SLOTS, icons, LABELS)):
        x = gap + col * (cell + gap)
        y = gap + 28 + row * (cell + gap)

        tile_bg = Image.new("RGBA", (cell, cell), (6, 48, 34, 255))
        draw.rectangle((0, 0, cell - 1, cell - 1), outline=(255, 255, 255, 55), width=1)

        display = icon.resize((76, 76), Image.Resampling.LANCZOS)
        tile_bg.paste(display, ((cell - 76) // 2, 12), display)
        panel.paste(tile_bg, (x, y), tile_bg)

        tw = draw.textlength(label, font=font)
        draw.text(
            (x + (cell - tw) / 2, y + cell - 22),
            label,
            fill=(255, 255, 255, 230),
            font=font,
        )

    PREVIEW.parent.mkdir(parents=True, exist_ok=True)
    panel.convert("RGB").save(PREVIEW)
    print(f"Icons:  {OUT_DIR}")
    print(f"Tiles:  {OUT_TILES}")
    print(f"Preview: {PREVIEW}")


if __name__ == "__main__":
    main()
