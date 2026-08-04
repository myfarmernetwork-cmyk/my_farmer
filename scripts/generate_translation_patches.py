#!/usr/bin/env python3
"""Generate zh/hi/id translation patches from *_needs.json."""

from __future__ import annotations

import json
import re
import time
from pathlib import Path

from deep_translator import GoogleTranslator

ROOT = Path(__file__).resolve().parent.parent
PATCH_DIR = ROOT / "assets" / "translations" / "patches"

# Keep brand names, product names, and technical tokens untranslated.
KEEP_LITERAL = [
    "My Farmer",
    "Premium",
    "Premium Pro",
    "Google Play",
    "Google Pay",
    "Apple Pay",
    "Google Maps",
    "Google Firebase",
    "RevenueCat",
    "Open-Meteo",
    "Plant.id",
    "Sentinel Hub",
    "Sentinel-2",
    "Stripe",
    "PayPal",
    "Firebase",
    "GDPR",
    "NIRS",
    "NDVI",
    "NIRS/NDVI",
    "AI",
    "GPS",
    "FCM",
    "IBAN",
    "HTTPS",
    "EAN",
    "UPC",
    "QR",
    "CSV",
    "PDF",
    "BPG",
    "OPG",
    "PAYPAL",
    "GOOGLE PAY",
    "PAYPAL DIRECT",
    "barkod",
    "naziv",
    "cijena",
    "zaliha",
    "jedinica",
    "PAYMENT_SIMULATION",
    "com.myfarmer.network",
    "4242 4242 4242 4242",
    "Plant Scanner",
    "Agro-Alarm",
    "Agro-Alarme",
    "Agro-Allarmi",
]

PLACEHOLDER_RE = re.compile(r"\{[a-zA-Z0-9_]+\}")


def load_needs(lang: str) -> dict[str, dict]:
    path = PATCH_DIR / f"{lang}_needs.json"
    with path.open(encoding="utf-8") as fh:
        return json.load(fh)


def mask_placeholders(text: str) -> tuple[str, list[str]]:
    placeholders: list[str] = []

    def repl(match: re.Match[str]) -> str:
        placeholders.append(match.group(0))
        return f"__PH{len(placeholders) - 1}__"

    return PLACEHOLDER_RE.sub(repl, text), placeholders


def unmask_placeholders(text: str, placeholders: list[str]) -> str:
    for i, ph in enumerate(placeholders):
        text = text.replace(f"__PH{i}__", ph)
        text = text.replace(f"__ PH {i} __", ph)
        text = text.replace(f"__PH {i}__", ph)
        text = text.replace(f"__ PH{i}__", ph)
    return text


def mask_literals(text: str) -> tuple[str, list[tuple[str, str]]]:
    masked: list[tuple[str, str]] = []
    for i, literal in enumerate(sorted(KEEP_LITERAL, key=len, reverse=True)):
        if literal in text:
            token = f"__BR{i}__"
            text = text.replace(literal, token)
            masked.append((token, literal))
    return text, masked


def unmask_literals(text: str, masked: list[tuple[str, str]]) -> str:
    for token, literal in masked:
        text = text.replace(token, literal)
        # Some translators add spaces around tokens
        spaced = token.replace("__", "__ ")
        text = text.replace(spaced, literal)
    return text


def normalize_source(text: str) -> str:
    return (
        text.replace("\u2014", " - ")
        .replace("\u2013", "-")
        .replace("\u2026", "...")
        .replace("\ufffd", "-")
    )


def translate_text(text: str, target: str, translator: GoogleTranslator) -> str:
    if not text.strip():
        return text

    source = normalize_source(text)
    source, literals = mask_literals(source)
    source, placeholders = mask_placeholders(source)

    translated = source
    for attempt in range(4):
        try:
            translated = translator.translate(source)
            break
        except Exception:
            time.sleep(1.5 * (attempt + 1))
            if attempt == 3:
                translated = source

    translated = unmask_placeholders(translated, placeholders)
    translated = unmask_literals(translated, literals)
    return translated


def build_patch(lang: str, target_code: str) -> dict[str, str]:
    needs = load_needs(lang)
    translator = GoogleTranslator(source="en", target=target_code)
    patch: dict[str, str] = {}

    keys = list(needs.keys())
    for idx, key in enumerate(keys, 1):
        english = needs[key]["en"]
        patch[key] = translate_text(english, target_code, translator)
        if idx % 25 == 0:
            print(f"  {lang}: {idx}/{len(keys)}")
            time.sleep(0.3)

    return patch


def write_patch(lang: str, patch: dict[str, str]) -> Path:
    needs = load_needs(lang)
    out = PATCH_DIR / f"{lang}_patch.json"
    ordered = {k: patch[k] for k in needs}
    with out.open("w", encoding="utf-8", newline="\n") as fh:
        json.dump(ordered, fh, ensure_ascii=False, indent=2)
        fh.write("\n")
    return out


def validate_patch(lang: str, patch: dict[str, str]) -> None:
    needs = load_needs(lang)
    missing = set(needs) - set(patch)
    extra = set(patch) - set(needs)
    if missing:
        raise SystemExit(f"{lang}: missing {len(missing)} keys")
    if extra:
        raise SystemExit(f"{lang}: extra {len(extra)} keys")

    for key, english in ((k, needs[k]["en"]) for k in needs):
        translated = patch[key]
        for ph in PLACEHOLDER_RE.findall(english):
            if ph not in translated:
                raise SystemExit(f"{lang}/{key}: missing placeholder {ph}")


def main() -> None:
    import sys

    requested = sys.argv[1:] if len(sys.argv) > 1 else ["zh", "hi", "id"]
    all_targets = [
        ("zh", "zh-CN"),
        ("hi", "hi"),
        ("id", "id"),
    ]
    targets = [t for t in all_targets if t[0] in requested]

    for lang, code in targets:
        print(f"Translating {lang} -> {code}...")
        patch = build_patch(lang, code)
        validate_patch(lang, patch)
        out = write_patch(lang, patch)
        print(f"Wrote {len(patch)} keys to {out}")


if __name__ == "__main__":
    main()
