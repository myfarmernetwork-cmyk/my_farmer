"""Nova skica kategorija — jednostavno, moderno, cijele ikone."""
from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "mockups" / "mockup_trgovina_kategorije_v2.png"
ICONS = ROOT / "assets" / "mockups" / "skica_kategorije_v2"

BG = (8, 72, 52)
TILE = 88
GAP = 10
RADIUS = 18
STROKE = 2

# (id, label, selected)
ITEMS = [
    ("all", "Sve", True),
    ("vegetables", "Povrće", False),
    ("fruit", "Voće", False),
    ("cereals", "Žitarice", False),
    ("animals", "Životinje", False),
    ("mechanization", "Mehanizacija", False),
    ("fertilizers", "Đubrivo", False),
    ("protection", "Zaštita", False),
]


def icon_canvas(size: int = 64) -> tuple[Image.Image, ImageDraw.ImageDraw]:
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    return img, ImageDraw.Draw(img)


def save_icon(code: str, size: int = 64) -> Image.Image:
    img, d = icon_canvas(size)
    c = size // 2
    pad = size * 0.14
    s = (size - pad * 2) / 24.0

    def xy(x: float, y: float) -> tuple[float, float]:
        return pad + x * s, pad + y * s

    def line(pts, w=STROKE):
        d.line([xy(x, y) for x, y in pts], fill=(255, 255, 255, 255), width=w)

    def circle(x, y, r, w=STROKE):
        px, py = xy(x, y)
        d.ellipse((px - r * s, py - r * s, px + r * s, py + r * s), outline=(255, 255, 255, 255), width=w)

    def sq(x, y, w, h, r=2):
        x0, y0 = xy(x, y)
        x1, y1 = xy(x + w, y + h)
        d.rounded_rectangle((x0, y0, x1, y1), radius=int(r * s), outline=(255, 255, 255, 255), width=STROKE)

    if code == "all":
        sq(4, 4, 7, 7)
        sq(13, 4, 7, 7)
        sq(4, 13, 7, 7)
        sq(13, 13, 7, 7)
    elif code == "vegetables":
        line([(12, 3), (10, 10), (9, 21), (15, 21), (14, 10), (12, 3)])
        line([(10, 10), (7, 6), (12, 3), (17, 6), (14, 10)])
    elif code == "fruit":
        circle(12, 14, 6.5)
        line([(12, 3), (12, 7)])
        line([(12, 5), (15, 4)])
    elif code == "cereals":
        line([(4, 20), (20, 4)])
        for i in range(4):
            bx = 8 + i * 3.5
            line([(bx, 14 - i), (bx + 1.2, 12.5 - i), (bx + 2.4, 14 - i)])
    elif code == "animals":
        line([(6, 10), (6, 7), (9, 5), (15, 5), (18, 7), (18, 10)])
        line([(6, 7), (5, 4), (7, 5)])
        line([(18, 7), (19, 4), (17, 5)])
        line([(7, 10), (7, 16), (12, 19), (17, 16), (17, 10)])
        circle(12, 15.5, 2.2, w=STROKE)
    elif code == "mechanization":
        circle(8, 17, 3.2)
        circle(17, 15.5, 4)
        line([(8, 17), (13, 14), (17, 14), (19, 11), (19, 8), (16, 6), (11, 6), (8, 9), (8, 17)])
        line([(17, 8), (17, 5)])
    elif code == "fertilizers":
        line([(6, 9), (8, 6), (16, 6), (18, 9), (6, 9)])
        line([(7, 9), (8, 19), (16, 19), (17, 9)])
        line([(11, 14), (11, 11), (13, 11), (13, 14)])
        line([(12, 11), (12, 9), (11, 8), (13, 8), (12, 9)])
    elif code == "protection":
        line([(10, 4), (14, 4)])
        line([(9, 6), (15, 6)])
        line([(9.5, 6), (11, 18), (13, 18), (14.5, 6)])
        line([(10, 18), (14, 18)])
        line([(12, 12), (12, 15)])
        line([(5, 9), (5, 12), (3.5, 12.8), (5, 13.6), (5, 16)])

    ICONS.mkdir(parents=True, exist_ok=True)
    img.save(ICONS / f"{code}.png")
    return img


def tint_icon(icon: Image.Image, color: tuple[int, int, int]) -> Image.Image:
    out = icon.copy()
    px = out.load()
    r, g, b = color
    for y in range(out.height):
        for x in range(out.width):
            _, _, _, a = px[x, y]
            if a:
                px[x, y] = (r, g, b, a)
    return out


def main() -> None:
    for code, _, _ in ITEMS:
        save_icon(code)

    pad = 20
    width = pad * 2 + len(ITEMS) * TILE + (len(ITEMS) - 1) * GAP
    height = 200
    img = Image.new("RGB", (width, height), BG)
    draw = ImageDraw.Draw(img)

    try:
        title = ImageFont.truetype("segoeuib.ttf", 20)
        sub = ImageFont.truetype("segoeui.ttf", 11)
        lbl = ImageFont.truetype("segoeui.ttf", 10)
    except OSError:
        title = sub = lbl = ImageFont.load_default()

    draw.text((pad, 16), "Trgovina", fill=(255, 255, 255), font=title)
    draw.text((pad, 42), "Kategorije v2 — jednostavno · scroll →", fill=(200, 230, 210), font=sub)

    y = 72
    x = pad
    forest = (62, 120, 92)

    for code, label, selected in ITEMS:
        fill = (248, 252, 250) if selected else (255, 255, 255, 34)
        outline = (255, 255, 255, 90)
        if selected:
            draw.rounded_rectangle((x, y, x + TILE, y + TILE), radius=RADIUS, fill=fill, outline=(255, 255, 255, 180), width=1)
        else:
            overlay = Image.new("RGBA", (width, height), (0, 0, 0, 0))
            od = ImageDraw.Draw(overlay)
            od.rounded_rectangle((x, y, x + TILE, y + TILE), radius=RADIUS, fill=(255, 255, 255, 34), outline=(255, 255, 255, 70), width=1)
            img = Image.alpha_composite(img.convert("RGBA"), overlay).convert("RGB")
            draw = ImageDraw.Draw(img)

        icon = Image.open(ICONS / f"{code}.png").convert("RGBA")
        icon = icon.resize((40, 40), Image.Resampling.LANCZOS)
        if selected:
            icon = tint_icon(icon, forest)
        img.paste(icon, (x + (TILE - 40) // 2, y + 14), icon)

        draw = ImageDraw.Draw(img)
        tw = draw.textlength(label, font=lbl)
        tc = forest if selected else (255, 255, 255)
        draw.text((x + (TILE - tw) / 2, y + TILE - 24), label, fill=tc, font=lbl)
        x += TILE + GAP

    OUT.parent.mkdir(parents=True, exist_ok=True)
    img.save(OUT)
    print(OUT)
    print(ICONS)


if __name__ == "__main__":
    main()
