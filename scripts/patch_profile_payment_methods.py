#!/usr/bin/env python3
"""Patch profile payment methods translation keys into all locale files."""

from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT_DIR = ROOT / "assets" / "translations"

PROFILE_PAYMENT_KEYS = [
    "profile_payment_methods_title",
    "profile_payment_methods_add",
    "profile_payment_methods_empty",
    "profile_payment_methods_empty_hint",
    "profile_payment_methods_summary_empty",
    "profile_payment_methods_loading",
    "profile_payment_methods_saved",
    "profile_payment_methods_default",
    "profile_payment_methods_set_default",
    "profile_payment_methods_delete_title",
    "profile_payment_methods_delete_body",
    "profile_payment_methods_delete_confirm",
    "profile_payment_methods_add_paypal_hint",
    "profile_payment_methods_add_card_hint",
    "profile_payment_methods_add_bank_hint",
    "profile_payment_methods_bank",
    "profile_payment_methods_bank_name",
    "profile_payment_methods_iban",
    "profile_payment_methods_account_holder",
    "profile_payment_methods_save_card_title",
    "profile_payment_methods_save_card_hint",
    "profile_payment_methods_card_security_hint",
    "profile_payment_methods_count_paypal",
    "profile_payment_methods_count_card",
    "profile_payment_methods_count_bank",
    "guide_profile_payment_methods_title",
    "guide_profile_payment_methods_body",
    "profile_payment_methods_error_title",
    "profile_payment_methods_error_permission",
    "profile_payment_methods_error_permission_hint",
    "profile_payment_methods_error_load",
    "profile_payment_methods_error_offline",
    "profile_payment_methods_error_auth",
    "profile_payment_methods_error_retry",
]


def main() -> None:
    en = json.loads((OUT_DIR / "en.json").read_text(encoding="utf-8-sig"))
    hr = json.loads((OUT_DIR / "hr.json").read_text(encoding="utf-8-sig"))
    de = json.loads((OUT_DIR / "de.json").read_text(encoding="utf-8-sig"))

    locale_sources = {
        "en": en,
        "hr": hr,
        "hr-HR": hr,
        "hr-BA": hr,
        "bs": hr,
        "sr": hr,
        "sr-RS": hr,
        "sr-BA": hr,
        "de": de,
    }

    updated = 0
    for path in sorted(OUT_DIR.glob("*.json")):
        code = path.stem
        source = locale_sources.get(code, en)
        data = json.loads(path.read_text(encoding="utf-8-sig"))
        changed = False
        for key in PROFILE_PAYMENT_KEYS:
            value = source.get(key) or en.get(key)
            if value and data.get(key) != value:
                data[key] = value
                changed = True
        if changed:
            path.write_text(
                json.dumps(data, ensure_ascii=False, indent=2) + "\n",
                encoding="utf-8",
            )
            updated += 1
            print(f"updated {path.name}")
    print(f"Done. Updated {updated} files.")


if __name__ == "__main__":
    main()
