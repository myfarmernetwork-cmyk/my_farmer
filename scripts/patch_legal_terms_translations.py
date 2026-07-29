#!/usr/bin/env python3
"""Patch marketplace legal terms into all locale JSON files."""

from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT_DIR = ROOT / "assets" / "translations"

KEYS = [
    "legal_marketplace_terms_title",
    "legal_marketplace_terms_subtitle",
    "legal_terms_profile_title",
    "legal_terms_profile_subtitle",
    "legal_terms_read_link",
    "legal_terms_footer",
    "legal_terms_role_title",
    "legal_terms_role_body",
    "legal_terms_payments_title",
    "legal_terms_payments_body",
    "legal_terms_seller_title",
    "legal_terms_seller_body",
    "legal_terms_buyer_title",
    "legal_terms_buyer_body",
    "legal_terms_premium_title",
    "legal_terms_premium_body",
    "legal_terms_disputes_title",
    "legal_terms_disputes_body",
    "legal_terms_acceptance_title",
    "legal_terms_acceptance_body",
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
