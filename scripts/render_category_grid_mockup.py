"""Generira preview mockup kvadratnog grid-a kategorija."""
from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "mockups" / "mockup_category_grid_preview.png"

W, H = 390, 520
BG = (10, 75, 55)
PANEL = (8, 58, 42)
TILE = (6, 48, 34)
TILE_BORDER = (255, 255, 255, 55)
WHITE = (255, 255, 255)
GREEN_TEXT = (30, 90, 65)

LABELS = [
    ["Sve", "Povrće", "Voće"],
    ["Životinje", "Žitarice", "Mehanizacija"],
    ["Đubrivo i\nStimulansi", "", "Kemija"],
]


def draw_icon(draw: ImageDraw.ImageDraw, code: str, cx: int, cy: int, size: int = 28) -> None:
    s = size / 24
    ox, oy = cx - size / 2, cy - size / 2
    stroke = max(1, int(1.4 * s))

    def line(pts, width=stroke):
        scaled = [(ox + x * s, oy + y * s) for x, y in pts]
        draw.line(scaled, fill=WHITE, width=width)

    def rect(x, y, w, h, r=1):
        draw.rounded_rectangle(
            (ox + x * s, oy + y * s, ox + (x + w) * s, oy + (y + h) * s),
            radius=int(r * s),
            outline=WHITE,
            width=stroke,
        )

    if code == "all":
        for x, y in [(4, 4), (13.5, 4), (4, 13.5), (13.5, 13.5)]:
            rect(x, y, 6.5, 6.5)
    elif code == "vegetables":
        line([(12, 4), (11, 9), (10.5, 20)])
        line([(12, 4), (13, 9), (13.5, 20)])
        line([(11, 4), (13.2, 2), (13, 4)])
    elif code == "fruit":
        draw.ellipse(
            (ox + 6 * s, oy + 7 * s, ox + 18 * s, oy + 20 * s),
            outline=WHITE,
            width=stroke,
        )
        line([(12, 2), (12, 5)])
    elif code == "animals":
        line([(6.5, 8.5), (17.5, 8.5)])
        line([(7, 8.5), (7, 6.8), (17, 6.8), (17, 8.5)])
        line([(6.2, 9), (6.2, 14), (12, 17), (17.8, 14), (17.8, 9)])
        draw.ellipse(
            (ox + 9.8 * s, oy + 14.4 * s, ox + 14.2 * s, oy + 17.2 * s),
            outline=WHITE,
            width=stroke,
        )
    elif code == "cereals":
        line([(2, 22), (16, 8)])
        for bx in [3.5, 7.5, 11.5]:
            line([(bx, 12), (bx + 1.5, 10.5), (bx + 3, 12), (bx + 1.5, 13.5), (bx, 12)])
    elif code == "mechanization":
        draw.ellipse((ox + 4 * s, oy + 14 * s, ox + 10 * s, oy + 20 * s), outline=WHITE, width=stroke)
        draw.ellipse((ox + 14 * s, oy + 12 * s, ox + 21 * s, oy + 19 * s), outline=WHITE, width=stroke)
        line([(8, 16), (14, 13), (18, 13), (20, 10), (20, 8), (18, 6), (12, 6), (8, 10), (8, 16)])
    elif code == "fertilizers":
        line([(4.5, 9), (6, 7), (11, 7), (9.5, 9), (4.5, 9)])
        line([(4.5, 9), (5.2, 17), (10.8, 17), (11.5, 9)])
        line([(14.5, 17), (14.5, 12), (13.2, 12), (14.5, 9.5), (15.8, 12), (14.5, 12)])
        line([(13.8, 17), (16.6, 17)])
    elif code == "chemistry":
        line([(10, 3), (14, 3)])
        line([(9.5, 5), (14.5, 5)])
        line([(9, 5.5), (11.2, 19), (12.8, 19), (15, 5.5)])
        line([(8.5, 19), (15.5, 19)])
        draw.ellipse((ox + 10.8 * s, oy + 12.8 * s, ox + 13.2 * s, oy + 15.2 * s), outline=WHITE, width=stroke)


def main() -> None:
    img = Image.new("RGB", (W, H), BG)
    draw = ImageDraw.Draw(img)

    try:
        font = ImageFont.truetype("segoeui.ttf", 11)
        font_b = ImageFont.truetype("segoeuib.ttf", 13)
    except OSError:
        font = ImageFont.load_default()
        font_b = font

    draw.text((18, 16), "Trgovina — kategorije (preview)", fill=WHITE, font=font_b)

    panel = (14, 48, W - 14, 48 + 330)
    draw.rounded_rectangle(panel, radius=22, fill=PANEL)

    codes = [
        ["all", "vegetables", "fruit"],
        ["animals", "cereals", "mechanization"],
        ["fertilizers", "", "chemistry"],
    ]

    pad = 16
    gap = 10
    cols, rows = 3, 3
    inner_w = panel[2] - panel[0] - pad * 2
    inner_h = panel[3] - panel[1] - pad * 2
    tile = min((inner_w - gap * (cols - 1)) // cols, (inner_h - gap * (rows - 1)) // rows)

    start_x = panel[0] + pad + (inner_w - (tile * cols + gap * (cols - 1))) // 2
    start_y = panel[1] + pad + (inner_h - (tile * rows + gap * (rows - 1))) // 2

    for r in range(rows):
        for c in range(cols):
            code = codes[r][c]
            label = LABELS[r][c]
            if not code:
                continue
            x0 = start_x + c * (tile + gap)
            y0 = start_y + r * (tile + gap)
            x1, y1 = x0 + tile, y0 + tile
            draw.rounded_rectangle((x0, y0, x1, y1), radius=14, fill=TILE, outline=TILE_BORDER, width=1)
            draw_icon(draw, code, (x0 + x1) // 2, (y0 + y1) // 2 - 8, size=30)
            if "\n" in label:
                parts = label.split("\n")
                ty = y1 - 28
                for i, part in enumerate(parts):
                    tw = draw.textlength(part, font=font)
                    draw.text((x0 + (tile - tw) / 2, ty + i * 12), part, fill=WHITE, font=font)
            else:
                tw = draw.textlength(label, font=font)
                draw.text((x0 + (tile - tw) / 2, y1 - 22), label, fill=WHITE, font=font)

    draw.rounded_rectangle((14, 392, W - 14, 430), radius=14, fill=(255, 255, 255, 20))
    draw.text((28, 404), "Sve = 4 kvadratića  ·  3×3 grid  ·  pojednostavljene ikone", fill=(230, 240, 235), font=font)

    OUT.parent.mkdir(parents=True, exist_ok=True)
    img.save(OUT)
    print(f"Saved: {OUT}")


if __name__ == "__main__":
    main()
