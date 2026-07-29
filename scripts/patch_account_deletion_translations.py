#!/usr/bin/env python3
"""Patch account deletion strings into all locale JSON files."""

from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT_DIR = ROOT / "assets" / "translations"

KEYS = [
    "account_deletion_title",
    "account_deletion_confirm_body",
    "account_deletion_confirm_action",
    "account_deletion_tile_title",
    "account_deletion_tile_subtitle",
    "account_deletion_tile_pending",
    "account_deletion_pending_generic",
    "account_deletion_pending_until",
    "account_deletion_scheduled_snackbar",
    "account_deletion_failed",
    "account_deletion_already_requested",
    "account_deletion_admin_blocked",
    "account_deletion_login_required",
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
