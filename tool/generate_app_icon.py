"""Export Icons.agriculture (login screen) to assets/images/app_icon.png."""
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
FONT_PATH = Path(r"C:\flutter\bin\cache\artifacts\material_fonts\materialicons-regular.otf")
OUTPUT = ROOT / "assets" / "images" / "app_icon.png"
CANVAS = 1024
ICON_SIZE = 720
CODEPOINT = 0xE063  # Icons.agriculture
GREEN = (76, 175, 80)  # Colors.green


def main() -> None:
    image = Image.new("RGB", (CANVAS, CANVAS), "white")
    draw = ImageDraw.Draw(image)
    font = ImageFont.truetype(str(FONT_PATH), ICON_SIZE)
    glyph = chr(CODEPOINT)

    left, top, right, bottom = draw.textbbox((0, 0), glyph, font=font)
    width = right - left
    height = bottom - top
    x = (CANVAS - width) // 2 - left
    y = (CANVAS - height) // 2 - top
    draw.text((x, y), glyph, font=font, fill=GREEN)

    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    image.save(OUTPUT, format="PNG")
    print(f"Saved {OUTPUT} ({OUTPUT.stat().st_size} bytes)")


if __name__ == "__main__":
    main()
