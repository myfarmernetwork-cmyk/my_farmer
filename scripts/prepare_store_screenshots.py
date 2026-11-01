"""Prepare Play Store phone screenshots: upscale + blur private names."""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "assets" / "store_screenshots"
SRC = ROOT / "assets" / "store_screenshots" / "_source"

# Relative blur boxes: (x1, y1, x2, y2) as fractions of width/height.
BLUR_BOXES: dict[str, list[tuple[float, float, float, float]]] = {
    "01_marketplace_home.jpg": [
        # firma.velika — seller line below price on both visible cards
        (0.05, 0.734, 0.46, 0.758),
        (0.54, 0.734, 0.95, 0.758),
    ],
    "02_marketplace_products.jpg": [
        # Martina Depcinski — seller line below price, one box per card
        (0.05, 0.386, 0.46, 0.414),
        (0.54, 0.386, 0.95, 0.414),
        (0.05, 0.676, 0.46, 0.704),
        (0.54, 0.676, 0.95, 0.704),
    ],
    "03_ai_scanner.png": [],
    "04_my_parcels.jpg": [
        (0.08, 0.928, 0.38, 0.958),
        (0.58, 0.928, 0.88, 0.958),
    ],
    "05_new_product.png": [],
    "06_my_profile.png": [],
}

TARGET_WIDTH = 1080


def blur_regions(image: Image.Image, boxes: list[tuple[float, float, float, float]]) -> Image.Image:
    result = image.copy()
    w, h = result.size
    for x1, y1, x2, y2 in boxes:
        box = (
            int(x1 * w),
            int(y1 * h),
            int(x2 * w),
            int(y2 * h),
        )
        if box[2] <= box[0] or box[3] <= box[1]:
            continue
        region = result.crop(box)
        blurred = region.filter(ImageFilter.GaussianBlur(radius=14))
        result.paste(blurred, box)
    return result


def upscale(image: Image.Image) -> Image.Image:
    w, h = image.size
    if w >= TARGET_WIDTH:
        return image
    scale = TARGET_WIDTH / w
    return image.resize(
        (TARGET_WIDTH, int(h * scale)),
        Image.Resampling.LANCZOS,
    )


def process(source: Path, dest_name: str) -> None:
    image = Image.open(source).convert("RGB")
    boxes = BLUR_BOXES.get(dest_name, [])
    image = blur_regions(image, boxes)
    image = upscale(image)
    ASSETS.mkdir(parents=True, exist_ok=True)
    out = ASSETS / dest_name
    image.save(out, format="JPEG", quality=92, optimize=True)
    print(f"saved {out} ({image.size[0]}x{image.size[1]})")


def main() -> None:
    mapping = {
        "Screenshot_20260911-204804_My_Farmer-ad7a9c9e-6b52-4dfb-a650-207ef2fdc9b9.jpg": "01_marketplace_home.jpg",
        "Screenshot_20260911-204914_My_Farmer-a7655a78-cd15-4505-a125-a35e7f7f619e.jpg": "02_marketplace_products.jpg",
        "Screenshot_20260911-204930_My_Farmer-056adfbe-0340-4d60-93ad-4543175b3043.png": "03_ai_scanner.png",
        "Screenshot_20260911-205418_My_Farmer-bce85cf8-ded1-44ab-ae2d-3bccc416f778.jpg": "04_my_parcels.jpg",
        "Screenshot_20260911-205436_My_Farmer-1b096244-f7bd-4585-b2b1-2c1cd758cb1e.png": "05_new_product.png",
        "Screenshot_20260911-205138_My_Farmer-10cd09a9-8cea-4560-b52a-0c1cd758cb1e.png": "06_my_profile.png",
    }

    search_roots = [
        ROOT / "assets",
        Path(r"C:\Users\User\.cursor\projects\c-Users-User-my-farmer\assets"),
    ]

    for fragment, dest_name in mapping.items():
        found = None
        for base in search_roots:
            matches = list(base.rglob(f"*{fragment.split('_My_Farmer')[0].split('Screenshot_')[-1]}*"))
            if not matches:
                # fallback: match by timestamp chunk
                key = fragment.split("Screenshot_")[-1].split("_My_Farmer")[0]
                matches = [p for p in base.rglob("Screenshot_*") if key in p.name]
            if matches:
                found = matches[0]
                break
        if found is None:
            raise FileNotFoundError(f"Missing source for {dest_name} ({fragment})")
        process(found, dest_name.replace(".png", ".jpg"))


if __name__ == "__main__":
    main()
