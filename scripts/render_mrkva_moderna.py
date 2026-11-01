"""Moderna skica ikone mrkve — tanka cijela linija."""
from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
ICON = ROOT / "assets" / "mockups" / "skica_mrkva_moderna.png"
PREVIEW = ROOT / "assets" / "mockups" / "skica_mrkva_moderna_preview.png"

BG = (8, 72, 52)
TILE = 120
WHITE = (255, 255, 255, 255)


def draw_carrot(draw: ImageDraw.ImageDraw, cx: float, cy: float, scale: float, color=WHITE, w=3):
    s = scale

    def p(x, y):
        return cx + x * s, cy + y * s

    draw.line([p(-4, -18), p(0, -10), p(4, -18)], fill=color, width=w, joint="curve")
    draw.line([p(0, -10), p(0, -20)], fill=color, width=w)
    draw.line([p(-2, -14), p(-6, -20)], fill=color, width=w)
    draw.line([p(2, -14), p(6, -20)], fill=color, width=w)

    body = [
        p(0, -10),
        p(-7, 8),
        p(-5, 18),
        p(0, 22),
        p(5, 18),
        p(7, 8),
        p(0, -10),
    ]
    draw.line(body, fill=color, width=w, joint="curve")

    for y in (-2, 4, 10, 16):
        draw.line([p(-4 + abs(y) * 0.15, y), p(4 - abs(y) * 0.15, y)], fill=color, width=max(2, w - 1))


def main() -> None:
    size = 128
    icon = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(icon)
    draw_carrot(draw, size / 2, size / 2 + 4, 2.2, w=3)
    ICON.parent.mkdir(parents=True, exist_ok=True)
    icon.save(ICON)

    prev = Image.new("RGBA", (TILE + 40, TILE + 80), BG)
    pd = ImageDraw.Draw(prev)
    pd.rounded_rectangle(
        (20, 20, 20 + TILE, 20 + TILE),
        radius=18,
        fill=(255, 255, 255, 34),
        outline=(255, 255, 255, 80),
        width=1,
    )
    cx, cy = 20 + TILE / 2, 20 + TILE / 2 + 4
    draw_carrot(pd, cx, cy, 2.0, w=2)
    try:
        font = ImageFont.truetype("segoeui.ttf", 12)
        title = ImageFont.truetype("segoeuib.ttf", 14)
    except OSError:
        font = title = ImageFont.load_default()
    pd.text((20, 20 + TILE + 28), "Povrće", fill=WHITE, font=font)
    pd.text((20, 8), "Mrkva — moderna skica", fill=(200, 230, 210), font=title)
    prev.convert("RGB").save(PREVIEW)

    print(ICON)
    print(PREVIEW)


if __name__ == "__main__":
    main()
