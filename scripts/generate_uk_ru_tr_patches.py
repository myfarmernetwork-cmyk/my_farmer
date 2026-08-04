#!/usr/bin/env python3
"""Generate uk_patch.json, ru_patch.json, and tr_patch.json from *_needs.json."""

from __future__ import annotations

import json
import re
import time
from pathlib import Path

from deep_translator import GoogleTranslator

ROOT = Path(__file__).resolve().parent.parent
PATCH_DIR = ROOT / "assets" / "translations" / "patches"
LOCALE_DIR = ROOT / "assets" / "translations"

BRANDS = [
    "My Farmer",
    "PayPal",
    "Stripe",
    "Premium",
    "NIRS",
    "NDVI",
    "Sentinel-2",
    "GPS",
    "CSV",
    "IBAN",
    "Google Maps",
    "Google Pay",
    "Apple Pay",
    "Google Play",
    "RevenueCat",
    "Plant.id",
    "Sentinel Hub",
    "Open-Meteo",
    "Firebase",
    "PAYPAL",
    "GOOGLE PAY",
    "PAYPAL DIRECT",
]

PLACEHOLDER_RE = re.compile(r"\{[a-zA-Z0-9_]+\}")


def load_json(path: Path) -> dict:
    with path.open(encoding="utf-8-sig") as fh:
        return json.load(fh)


def protect(text: str) -> tuple[str, list[tuple[str, str]]]:
    """Replace placeholders and brand names with opaque tokens."""
    tokens: list[tuple[str, str]] = []
    result = text

    def add_token(original: str) -> str:
        token = f"@@T{len(tokens)}@@"
        tokens.append((token, original))
        return token

    for match in PLACEHOLDER_RE.finditer(result):
        pass  # handled below via findall order

    # Protect placeholders first (longest match via regex sub)
    def ph_sub(m: re.Match[str]) -> str:
        return add_token(m.group(0))

    result = PLACEHOLDER_RE.sub(ph_sub, result)

    # Protect brand names (longest first to avoid partial overlaps)
    for brand in sorted(BRANDS, key=len, reverse=True):
        if brand in result:
            result = result.replace(brand, add_token(brand))

    return result, tokens


def restore(text: str, tokens: list[tuple[str, str]]) -> str:
    for token, original in tokens:
        text = text.replace(token, original)
    return text


def translate_text(text: str, target: str, translator: GoogleTranslator) -> str:
    if not text.strip():
        return text

    protected, tokens = protect(text)
    if not protected.strip():
        return text

    # Chunk long texts (Google limit ~5000 chars; stay safe)
    if len(protected) > 4500:
        parts = protected.split("\n\n")
        translated_parts = []
        for part in parts:
            if part.strip():
                translated_parts.append(
                    translate_text(part, target, translator) if "@@T" in part or len(part) > 10 else part
                )
            else:
                translated_parts.append(part)
        return restore("\n\n".join(translated_parts), tokens)

    for attempt in range(5):
        try:
            out = translator.translate(protected)
            return restore(out, tokens)
        except Exception as exc:  # noqa: BLE001
            if attempt == 4:
                raise
            time.sleep(1.5 * (attempt + 1))
            print(f"  retry {attempt + 1} ({target}): {exc}")

    return text  # unreachable


def build_patch(
    lang: str,
    needs_path: Path,
    locale_path: Path,
    out_path: Path,
) -> int:
    needs = load_json(needs_path)
    locale = load_json(locale_path) if locale_path.is_file() else {}

    target_map = {"uk": "uk", "ru": "ru", "tr": "tr"}
    translator = GoogleTranslator(source="en", target=target_map[lang])

    patch: dict[str, str] = {}
    total = len(needs)

    for i, key in enumerate(needs, 1):
        en = needs[key]["en"]

        # Prefer existing locale translation when present
        if key in locale and locale[key].strip():
            patch[key] = locale[key]
            continue

        print(f"[{lang}] {i}/{total} {key}")
        patch[key] = translate_text(en, lang, translator)
        time.sleep(0.15)

    with out_path.open("w", encoding="utf-8", newline="\n") as fh:
        json.dump(patch, fh, ensure_ascii=False, indent=2)
        fh.write("\n")

    return len(patch)


def verify_patch(path: Path, needs_path: Path) -> None:
    needs = load_json(needs_path)
    patch = load_json(path)
    missing = set(needs) - set(patch)
    extra = set(patch) - set(needs)
    if missing:
        raise SystemExit(f"{path.name}: missing keys {sorted(missing)[:5]}...")
    if extra:
        raise SystemExit(f"{path.name}: extra keys {sorted(extra)[:5]}...")

    for key, value in patch.items():
        en = needs[key]["en"]
        for ph in PLACEHOLDER_RE.findall(en):
            if ph not in value:
                print(f"  WARN placeholder {ph} missing in {key}")

    print(f"  verified {len(patch)} keys in {path.name}")


def main() -> None:
    configs = [
        ("uk", "uk_needs.json", "uk.json", "uk_patch.json"),
        ("ru", "ru_needs.json", "ru.json", "ru_patch.json"),
        ("tr", "tr_needs.json", "tr.json", "tr_patch.json"),
    ]

    for lang, needs_file, locale_file, patch_file in configs:
        needs_path = PATCH_DIR / needs_file
        locale_path = LOCALE_DIR / locale_file
        out_path = PATCH_DIR / patch_file

        print(f"\n=== Generating {patch_file} ===")
        count = build_patch(lang, needs_path, locale_path, out_path)
        verify_patch(out_path, needs_path)
        print(f"Wrote {count} keys -> {out_path}")


if __name__ == "__main__":
    main()
