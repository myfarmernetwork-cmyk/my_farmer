#!/usr/bin/env python3
"""Re-translate patch keys that were copied from English locale files."""

from __future__ import annotations

import json
import re
import time
from pathlib import Path

from deep_translator import GoogleTranslator

ROOT = Path(__file__).resolve().parent.parent
PATCH_DIR = ROOT / "assets" / "translations" / "patches"

BRANDS = [
    "My Farmer", "PayPal", "Stripe", "Premium", "NIRS", "NDVI",
    "Sentinel-2", "GPS", "CSV", "IBAN", "Google Maps",
    "Google Pay", "Apple Pay", "Google Play", "RevenueCat",
    "Plant.id", "Sentinel Hub", "Open-Meteo", "Firebase",
]
PLACEHOLDER_RE = re.compile(r"\{[a-zA-Z0-9_]+\}")

# Keys intentionally identical across languages (badges, brand labels)
KEEP_ENGLISH = {
    "order_badge_paypal",
    "order_badge_google_pay",
    "order_badge_direct_paypal",
    "payment_sim_paypal_email",
    "paywall_pharmacy_benefit_scanner",
}

MANUAL_FIXES: dict[str, dict[str, str]] = {
    "uk": {
        "scanner_clear_photo": "Очистити",
        "first_aid_call": "Подзвонити",
        "first_aid_chat": "Повідомлення",
        "vet_intake_sort_unread": "Непрочитані",
        "vet_intake_sort_newest": "Найновіші",
        "forum_cat_crops": "Польові культури",
        "forum_cat_mechanization": "Механізація",
        "guide_profile_shop_hours_body": "Увімкніть доступність для замовлень, оберіть робочі дні та години, коли ви на фермі та доступні для покупців.",
    },
    "ru": {
        "scanner_clear_photo": "Очистить",
        "first_aid_call": "Позвонить",
        "first_aid_chat": "Сообщение",
        "forum_cat_crops": "Полевые культуры",
        "forum_cat_mechanization": "Механизация",
        "guide_profile_shop_hours_body": "Включите доступность для заказов, выберите рабочие дни и часы, когда вы на ферме и доступны для покупателей.",
    },
    "tr": {
        "scanner_clear_photo": "Temizle",
        "first_aid_call": "Ara",
        "vet_intake_sort_label": "Sırala",
        "forum_cat_crops": "Tarla bitkileri",
        "forum_cat_mechanization": "Mekanizasyon",
        "guide_profile_shop_hours_body": "Sipariş alımını açın, çalışma günlerini ve çiftlikte bulunduğunuz saatleri seçin.",
    },
}


def load(path: Path) -> dict:
    with path.open(encoding="utf-8-sig") as fh:
        return json.load(fh)


def protect(text: str) -> tuple[str, list[tuple[str, str]]]:
    tokens: list[tuple[str, str]] = []
    result = text

    def add_token(original: str) -> str:
        token = f"@@T{len(tokens)}@@"
        tokens.append((token, original))
        return token

    result = PLACEHOLDER_RE.sub(lambda m: add_token(m.group(0)), result)
    for brand in sorted(BRANDS, key=len, reverse=True):
        if brand in result:
            result = result.replace(brand, add_token(brand))
    return result, tokens


def restore(text: str, tokens: list[tuple[str, str]]) -> str:
    for token, original in tokens:
        text = text.replace(token, original)
    return text


def translate(text: str, target: str) -> str:
    protected, tokens = protect(text)
    translator = GoogleTranslator(source="en", target=target)
    for attempt in range(5):
        try:
            return restore(translator.translate(protected), tokens)
        except Exception:
            time.sleep(1.5 * (attempt + 1))
    return text


def should_retranslate(key: str, en: str, val: str) -> bool:
    if key in KEEP_ENGLISH:
        return False
    if val != en:
        return False
    # Short universal labels may stay
    if len(en) <= 12 and not any(c.isalpha() and c.isascii() for c in en if c.isalpha()):
        return False
    # Mostly uppercase badges
    if en.isupper() and len(en) < 20:
        return False
    return True


def fix_patch(lang: str, needs_file: str, patch_file: str) -> int:
    needs = load(PATCH_DIR / needs_file)
    patch = load(PATCH_DIR / patch_file)
    fixed = 0

    for key, entry in needs.items():
        en = entry["en"]
        if key in MANUAL_FIXES.get(lang, {}):
            patch[key] = MANUAL_FIXES[lang][key]
            fixed += 1
            continue
        if should_retranslate(key, en, patch.get(key, "")):
            print(f"[{lang}] retranslate {key}")
            patch[key] = translate(en, lang)
            fixed += 1
            time.sleep(0.2)

    out = PATCH_DIR / patch_file
    with out.open("w", encoding="utf-8", newline="\n") as fh:
        json.dump(patch, fh, ensure_ascii=False, indent=2)
        fh.write("\n")
    return fixed


def main() -> None:
    for lang, needs, patch in [
        ("uk", "uk_needs.json", "uk_patch.json"),
        ("ru", "ru_needs.json", "ru_patch.json"),
        ("tr", "tr_needs.json", "tr_patch.json"),
    ]:
        n = fix_patch(lang, needs, patch)
        print(f"{patch}: fixed {n} keys")


if __name__ == "__main__":
    main()
