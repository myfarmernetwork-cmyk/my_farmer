#!/usr/bin/env python3
"""Generate Swahili and Arabic translation patches from *_needs.json."""

from __future__ import annotations

import json
import re
import time
from pathlib import Path

from deep_translator import GoogleTranslator

ROOT = Path(__file__).resolve().parent.parent
PATCH_DIR = ROOT / "assets" / "translations" / "patches"

# Terms that must stay exactly as in English (case-sensitive where noted).
BRAND_TERMS = [
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
    "GOOGLE PAY",
    "PAYPAL",
    "PAYPAL DIRECT",
    "Google Play",
    "Google Firebase",
    "RevenueCat",
    "Open-Meteo",
    "Plant.id",
    "Sentinel Hub",
    "GDPR",
    "HTTPS",
    "Firebase",
    "FCM",
    "SKU",
    "EAN/UPC",
    "QR",
    "AI",
    "PAYMENT_SIMULATION=false",
    "PAYMENT_SIMULATION=true",
    "com.myfarmer.network",
    "firebase deploy --only firestore:rules",
    r".\\scripts\\run_dev.ps1",
    "4242 4242 4242 4242",
    "Stripe Native API",
    "AI Plant Scanner",
]

PLACEHOLDER_RE = re.compile(r"\{[a-zA-Z0-9_]+\}")


def protect(text: str) -> tuple[str, list[tuple[str, str]]]:
    """Replace protected segments with opaque tokens."""
    replacements: list[tuple[str, str]] = []
    protected = text

    # Placeholders first (order matters for nested protection).
    for match in PLACEHOLDER_RE.finditer(text):
        token = f"__PH{len(replacements)}__"
        replacements.append((token, match.group(0)))

    for token, original in replacements:
        protected = protected.replace(original, token, 1)

    # Brand / technical terms — longest first to avoid partial matches.
    for term in sorted(BRAND_TERMS, key=len, reverse=True):
        if term in protected:
            token = f"__BR{len(replacements)}__"
            replacements.append((token, term))
            protected = protected.replace(term, token)

    return protected, replacements


def restore(text: str, replacements: list[tuple[str, str]]) -> str:
    out = text
    for token, original in replacements:
        out = out.replace(token, original)
    return out


def translate_text(text: str, target: str, retries: int = 4) -> str:
    if not text.strip():
        return text

    protected, replacements = protect(text)
    last_err: Exception | None = None

    for attempt in range(retries):
        try:
            translated = GoogleTranslator(source="en", target=target).translate(protected)
            if translated is None:
                raise RuntimeError("empty translation")
            return restore(translated, replacements)
        except Exception as exc:  # noqa: BLE001
            last_err = exc
            time.sleep(1.5 * (attempt + 1))

    raise RuntimeError(f"translation failed for {target!r}: {last_err}") from last_err


def build_patch(needs_path: Path, target: str) -> dict[str, str]:
    needs = json.loads(needs_path.read_text(encoding="utf-8"))
    patch: dict[str, str] = {}
    keys = list(needs.keys())

    for i, key in enumerate(keys, 1):
        en = needs[key]["en"]
        patch[key] = translate_text(en, target)
        if i % 25 == 0:
            print(f"  {needs_path.name}: {i}/{len(keys)}")
            time.sleep(0.3)
        else:
            time.sleep(0.08)

    return patch


def write_patch(path: Path, data: dict[str, str]) -> None:
    with path.open("w", encoding="utf-8", newline="\n") as fh:
        json.dump(data, fh, ensure_ascii=False, indent=2)
        fh.write("\n")


def validate_patch(needs_path: Path, patch: dict[str, str]) -> None:
    needs = json.loads(needs_path.read_text(encoding="utf-8"))
    missing = set(needs) - set(patch)
    extra = set(patch) - set(needs)
    if missing:
        raise SystemExit(f"Missing keys in {needs_path.name}: {sorted(missing)[:5]}")
    if extra:
        raise SystemExit(f"Extra keys in patch: {sorted(extra)[:5]}")

    for key, entry in needs.items():
        en = entry["en"]
        translated = patch[key]
        for ph in PLACEHOLDER_RE.findall(en):
            if ph not in translated:
                raise SystemExit(f"Placeholder {ph} missing in {key}")


def main() -> None:
    sw_needs = PATCH_DIR / "sw_needs.json"
    ar_needs = PATCH_DIR / "ar_needs.json"
    sw_out = PATCH_DIR / "sw_patch.json"
    ar_out = PATCH_DIR / "ar_patch.json"

    print("Translating Swahili patch...")
    sw_patch = build_patch(sw_needs, "sw")
    validate_patch(sw_needs, sw_patch)
    write_patch(sw_out, sw_patch)
    print(f"Wrote {len(sw_patch)} keys -> {sw_out}")

    print("Translating Arabic patch...")
    ar_patch = build_patch(ar_needs, "ar")
    validate_patch(ar_needs, ar_patch)
    write_patch(ar_out, ar_patch)
    print(f"Wrote {len(ar_patch)} keys -> {ar_out}")


if __name__ == "__main__":
    main()
