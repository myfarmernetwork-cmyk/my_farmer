#!/usr/bin/env python3
"""Patch privacy policy, registration consent, and beta guide strings."""

from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT_DIR = ROOT / "assets" / "translations"

KEYS = [
    "privacy_policy_title",
    "privacy_policy_subtitle",
    "privacy_policy_intro",
    "privacy_policy_profile_title",
    "privacy_policy_profile_subtitle",
    "privacy_policy_open_web",
    "privacy_policy_web_failed",
    "privacy_policy_footer",
    "privacy_controller_title",
    "privacy_controller_body",
    "privacy_data_title",
    "privacy_data_body",
    "privacy_purpose_title",
    "privacy_purpose_body",
    "privacy_location_title",
    "privacy_location_body",
    "privacy_third_parties_title",
    "privacy_third_parties_body",
    "privacy_retention_title",
    "privacy_retention_body",
    "privacy_rights_title",
    "privacy_rights_body",
    "privacy_security_title",
    "privacy_security_body",
    "privacy_contact_title",
    "privacy_contact_body",
    "registration_legal_consent_prefix",
    "registration_legal_consent_required",
    "registration_legal_terms_link",
    "registration_legal_privacy_link",
    "registration_legal_and",
    "beta_guide_screen_title",
    "beta_guide_profile_title",
    "beta_guide_profile_subtitle",
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
