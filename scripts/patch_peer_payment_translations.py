#!/usr/bin/env python3
"""Patch peer-to-peer payment translation keys into all locale files."""

from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT_DIR = ROOT / "assets" / "translations"

KEYS = [
    "profile_payment_methods_peer_hint",
    "peer_payment_disclaimer",
    "peer_payment_disclaimer_short",
    "peer_payment_accept_checkbox",
    "peer_payment_confirm_order",
    "peer_payment_amount",
    "peer_payment_paypal_title",
    "peer_payment_paypal_instruction",
    "peer_payment_bank_title",
    "peer_payment_bank_instruction",
    "peer_payment_cash_title",
    "peer_payment_cash_instruction",
    "peer_payment_option_paypal",
    "peer_payment_option_paypal_hint",
    "peer_payment_option_bank",
    "peer_payment_option_bank_hint",
    "peer_payment_upcoming_required",
    "peer_payment_multi_seller",
    "peer_payment_seller_missing_title",
    "peer_payment_seller_missing_paypal",
    "peer_payment_seller_missing_bank",
    "peer_payment_order_success_paypal",
    "peer_payment_order_success_bank",
    "order_badge_direct_paypal",
    "order_badge_bank",
]


def main() -> None:
    en = json.loads((OUT_DIR / "en.json").read_text(encoding="utf-8-sig"))
    hr = json.loads((OUT_DIR / "hr.json").read_text(encoding="utf-8-sig"))
    locale_sources = {
        "en": en, "hr": hr, "hr-HR": hr, "hr-BA": hr,
        "bs": hr, "sr": hr, "sr-RS": hr, "sr-BA": hr,
    }
    updated = 0
    for path in sorted(OUT_DIR.glob("*.json")):
        code = path.stem
        source = locale_sources.get(code, en)
        data = json.loads(path.read_text(encoding="utf-8-sig"))
        changed = False
        for key in KEYS:
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
