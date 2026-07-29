# -*- coding: utf-8 -*-
"""Merge company catalog translation blocks into all locale JSON files."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent / "assets" / "translations"
BLOCKS_PATH = Path(__file__).resolve().parent / "company_catalog_locale_blocks.json"
PREFIXES = ("company_catalog_", "guide_company_catalog_")


def extract(d: dict) -> dict:
    return {k: v for k, v in d.items() if k.startswith(PREFIXES)}


def merge(locale: str, block: dict) -> None:
    path = ROOT / f"{locale}.json"
    data = json.loads(path.read_text(encoding="utf-8"))
    data.update(block)
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"updated {locale}: {len(block)} keys")


def main() -> None:
    hr = json.loads((ROOT / "hr.json").read_text(encoding="utf-8"))
    sr = json.loads((ROOT / "sr.json").read_text(encoding="utf-8"))

    for loc in ("hr-BA", "hr-HR"):
        merge(loc, extract(hr))
    for loc in ("sr-RS", "sr-BA"):
        merge(loc, extract(sr))

    extra = json.loads(BLOCKS_PATH.read_text(encoding="utf-8"))
    for locale, block in extra.items():
        merge(locale, block)

    print("done")


if __name__ == "__main__":
    main()
