"""Skica: Trgovina kategorije — svi kvadrati Sve → Zaštita bilja."""
from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "mockups" / "mockup_trgovina_kategorije_skica.png"
ICONS_DIR = ROOT / "assets" / "mockups" / "skica_kategorije"

# Boje iz app referenci
BG_TOP = (10, 107, 74)
BG_BOTTOM = (6, 68, 42)
TILE_INACTIVE = (255, 255, 255, 33)
TILE_ACTIVE = (255, 255, 255, 245)
TILE_BORDER = (255, 255, 255, 77)
FOREST = (78, 135, 110)
WHITE = (255, 255, 255)

CATEGORIES = [
    ("all", "Sve", True),
    ("vegetables", "Povrće", False),
    ("fruit", "Voće", False),
    ("cereals", "Žitarice", False),
    ("animals", "Životinje", False),
    ("mechanization", "Mehanizacija", False),
    ("fertilizers", "Đubrivo i\nStimulansi", False),
    ("protection", "Zaštita\nbilja", False),
]


def stroke(draw: ImageDraw.ImageDraw, pts, color=WHITE, width=2):
    draw.line(pts, fill=color, width=width, joint="curve")


def draw_icon(draw: ImageDraw.ImageDraw, code: str, cx: int, cy: int, size: int = 36):
    s = size / 24.0
    ox, oy = cx - size / 2, cy - size / 2
    w = max(2, int(1.6 * s))

    def p(x, y):
        return ox + x * s, oy + y * s

    def line(pts):
        stroke(draw, [p(x, y) for x, y in pts], width=w)

    def rect(x, y, rw, rh, r=1.2):
        draw.rounded_rectangle(
            (p(x, y)[0], p(x, y)[1], p(x + rw, y + rh)[0], p(x + rw, y + rh)[1]),
            radius=int(r * s),
            outline=WHITE,
            width=w,
        )

    if code == "all":
        for x, y in [(3.5, 3.5), (13.5, 3.5), (3.5, 13.5), (13.5, 13.5)]:
            rect(x, y, 7, 7)
    elif code == "vegetables":
        line([(2.3, 21.7), (8.6, 14), (15.3, 15), (22, 9)])
        line([(8.6, 14), (6.6, 12)])
        line([(15.3, 15), (12.9, 12.5)])
        line([(15, 2), (15, 9), (17, 3.3)])
    elif code == "fruit":
        draw.ellipse(
            (p(6, 7)[0], p(6, 7)[1], p(18, 20.9)[0], p(18, 20.9)[1]),
            outline=WHITE,
            width=w,
        )
        line([(10, 2), (12, 5)])
    elif code == "cereals":
        line([(2, 22), (16, 8)])
        for bx in [3.5, 7.5, 11.5]:
            line([(bx, 12), (bx + 1.5, 10.5), (bx + 3, 12), (bx + 1.5, 13.5), (bx, 12)])
        line([(20, 2), (22, 2), (22, 4), (20, 6), (18, 6), (18, 4), (20, 2)])
    elif code == "animals":
        line([(8, 7.2), (6.4, 3.6)])
        line([(16, 7.2), (17.6, 3.6)])
        line([(8.8, 5.6), (8.8, 3.4)])
        line([(15.2, 5.6), (15.2, 3.4)])
        line([(6.4, 9.2), (6.4, 14), (12, 17.8), (17.6, 14), (17.6, 9.2)])
        line([(9.4, 14.2), (14.6, 14.2)])
        draw.arc(
            (p(9.6, 14.2)[0], p(9.6, 14.2)[1], p(14.4, 17.4)[0], p(14.4, 17.4)[1]),
            0,
            180,
            fill=WHITE,
            width=w,
        )
    elif code == "mechanization":
        draw.ellipse((p(4, 14)[0], p(4, 14)[1], p(10, 20)[0], p(10, 20)[1]), outline=WHITE, width=w)
        draw.ellipse((p(14, 12)[0], p(14, 12)[1], p(21, 19)[0], p(21, 19)[1]), outline=WHITE, width=w)
        line([(8, 16), (14, 13), (18, 13), (20, 10), (20, 8), (18, 6), (12, 6), (8, 10), (8, 16)])
        line([(18, 5), (18, 8)])
    elif code == "fertilizers":
        line([(4.2, 8.2), (5.6, 6.4), (11.8, 6.4), (10.4, 8.2), (4.2, 8.2)])
        line([(4.2, 8.2), (5, 18.2), (11.6, 18.2), (12.4, 8.2)])
        line([(8.4, 15.6), (8.4, 11)])
        line([(7.2, 12.6), (8.4, 10.4), (9.6, 12.6)])
        for cx2, cy2 in [(18.2, 8.4), (21.1, 11.6), (16.4, 13.2)]:
            draw.ellipse(
                (p(cx2 - 1.15, cy2 - 1.15)[0], p(cx2 - 1.15, cy2 - 1.15)[1],
                 p(cx2 + 1.15, cy2 + 1.15)[0], p(cx2 + 1.15, cy2 + 1.15)[1]),
                outline=WHITE,
                width=w,
            )
        line([(17.3, 9.2), (20.2, 10.8)])
        line([(17.4, 12.2), (17.3, 9.6)])
        line([(20.2, 12.4), (17.4, 12.6)])
    elif code == "protection":
        line([(10, 2), (14, 2)])
        line([(9.5, 5), (14.5, 5)])
        line([(9, 5.5), (11.2, 19), (12.8, 19), (15, 5.5)])
        line([(8.5, 19), (15.5, 19)])
        line([(10.8, 13.2), (13.2, 13.2), (13.2, 15.6), (10.8, 15.6), (10.8, 13.2)])
        line([(4.6, 7.2), (4.6, 9.8), (2.8, 10.4), (4.6, 11), (4.6, 13.6)])
        for cx2, cy2 in [(19.6, 8.2), (22.2, 11.2), (17.8, 12.6)]:
            draw.ellipse(
                (p(cx2 - 1.1, cy2 - 1.1)[0], p(cx2 - 1.1, cy2 - 1.1)[1],
                 p(cx2 + 1.1, cy2 + 1.1)[0], p(cx2 + 1.1, cy2 + 1.1)[1]),
                outline=WHITE,
                width=w,
            )
        line([(18.8, 9), (21.3, 10.4)])
        line([(18.8, 11.8), (18.7, 9.2)])
        line([(21.3, 11.8), (18.8, 12)])


def render_icon_png(code: str, size: int = 96) -> Image.Image:
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    draw_icon(draw, code, size // 2, size // 2, size=size - 16)
    return img


def draw_tile(
    base: Image.Image,
    x: int,
    y: int,
    tile: int,
    code: str,
    label: str,
    selected: bool,
    font,
    font_sm,
):
    layer = Image.new("RGBA", base.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    fill = TILE_ACTIVE if selected else TILE_INACTIVE
    d.rounded_rectangle(
        (x, y, x + tile, y + tile),
        radius=16,
        fill=fill,
        outline=TILE_BORDER,
        width=1,
    )
    icon_color = FOREST if selected else WHITE
    icon_layer = Image.new("RGBA", (tile, tile), (0, 0, 0, 0))
    idraw = ImageDraw.Draw(icon_layer)
    # temp draw on white then tint
    tmp = Image.new("RGBA", (tile, tile), (0, 0, 0, 0))
    tdraw = ImageDraw.Draw(tmp)
    draw_icon(tdraw, code, tile // 2, tile // 2 - 6, size=34)
    if selected:
        r, g, b = FOREST
        px = tmp.load()
        for iy in range(tile):
            for ix in range(tile):
                _, _, _, a = px[ix, iy]
                if a:
                    px[ix, iy] = (r, g, b, a)
    icon_layer.paste(tmp, (0, 0), tmp)
    layer.paste(icon_layer, (x, y), icon_layer)

    d = ImageDraw.Draw(layer)
    lines = label.split("\n")
    f = font_sm if len(lines) > 1 else font
    ty = y + tile - (22 if len(lines) == 1 else 30)
    for i, line in enumerate(lines):
        tw = d.textlength(line, font=f)
        tx = x + (tile - tw) / 2
        d.text((tx, ty + i * 11), line, fill=FOREST if selected else WHITE, font=f)
    return Image.alpha_composite(base, layer)


def main() -> None:
    ICONS_DIR.mkdir(parents=True, exist_ok=True)
    for code, _, _ in CATEGORIES:
        render_icon_png(code).save(ICONS_DIR / f"{code}.png")

    tile = 80
    gap = 8
    pad = 16
    row_w = len(CATEGORIES) * tile + (len(CATEGORIES) - 1) * gap + pad * 2
    W, H = max(420, row_w + 20), 220

    img = Image.new("RGBA", (W, H), BG_TOP)
    draw = ImageDraw.Draw(img)
    for y in range(H):
        t = y / max(H - 1, 1)
        r = int(BG_TOP[0] * (1 - t) + BG_BOTTOM[0] * t)
        g = int(BG_TOP[1] * (1 - t) + BG_BOTTOM[1] * t)
        b = int(BG_TOP[2] * (1 - t) + BG_BOTTOM[2] * t)
        draw.line([(0, y), (W, y)], fill=(r, g, b))

    try:
        title = ImageFont.truetype("segoeuib.ttf", 18)
        font = ImageFont.truetype("segoeui.ttf", 10)
        font_sm = ImageFont.truetype("segoeui.ttf", 9)
        note = ImageFont.truetype("segoeui.ttf", 11)
    except OSError:
        title = font = font_sm = note = ImageFont.load_default()

    draw.text((pad, 12), "Trgovina", fill=WHITE, font=title)
    draw.text((pad, 38), "Kategorije — skica (scroll lijevo → desno)", fill=(230, 240, 235), font=note)

    y0 = 68
    x = pad
    for code, label, selected in CATEGORIES:
        img = draw_tile(img, x, y0, tile, code, label, selected, font, font_sm)
        x += tile + gap

    # scroll hint
    draw.rounded_rectangle(
        (pad, y0 + tile + 14, W - pad, y0 + tile + 36),
        radius=10,
        fill=(255, 255, 255, 25),
        outline=(255, 255, 255, 40),
    )
    draw.text(
        (pad + 10, y0 + tile + 20),
        "8 kvadrata: Sve → Zaštita bilja  ·  isti fajlovi u assets/mockups/skica_kategorije/",
        fill=(230, 240, 235),
        font=note,
    )

    OUT.parent.mkdir(parents=True, exist_ok=True)
    img.convert("RGB").save(OUT)
    print(f"Skica: {OUT}")
    print(f"Ikone: {ICONS_DIR}")


if __name__ == "__main__":
    main()
