#!/usr/bin/env python3
"""Merge translation patches and fill Balkan locales from hr/hr-HR."""

from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TRANS_DIR = ROOT / "assets" / "translations"
PATCH_DIR = TRANS_DIR / "patches"

BALKAN_FROM_HR = ("bs", "sr", "sr-RS", "sr-BA", "hr-BA")
BALKAN_FROM_HR_HR = ("hr",)


def load(path: Path) -> dict[str, str]:
    with path.open(encoding="utf-8-sig") as fh:
        return json.load(fh)


def save(path: Path, data: dict[str, str]) -> None:
    with path.open("w", encoding="utf-8", newline="\n") as fh:
        json.dump(data, fh, ensure_ascii=False, indent=2)
        fh.write("\n")


def order_by_en(en: dict[str, str], locale: dict[str, str]) -> dict[str, str]:
    ordered: dict[str, str] = {}
    for key in en:
        if key in locale:
            ordered[key] = locale[key]
    for key, value in locale.items():
        if key not in ordered:
            ordered[key] = value
    return ordered


def fill_balkan(en: dict[str, str], hr: dict[str, str], hr_hr: dict[str, str]) -> None:
    for loc in BALKAN_FROM_HR:
        path = TRANS_DIR / f"{loc}.json"
        data = load(path)
        before = len(set(en) - set(data))
        for key in en:
            if key not in data and key in hr:
                data[key] = hr[key]
        save(path, order_by_en(en, data))
        after = len(set(en) - set(load(path)))
        print(f"  {loc}: missing {before} -> {after}")

    for loc in BALKAN_FROM_HR_HR:
        path = TRANS_DIR / f"{loc}.json"
        data = load(path)
        before = len(set(en) - set(data))
        for key in en:
            if key not in data and key in hr_hr:
                data[key] = hr_hr[key]
        save(path, order_by_en(en, data))
        after = len(set(en) - set(load(path)))
        print(f"  {loc}: missing {before} -> {after}")

    # hr-HR: fill gaps from hr
    path = TRANS_DIR / "hr-HR.json"
    data = load(path)
    before = len(set(en) - set(data))
    for key in en:
        if key not in data and key in hr:
            data[key] = hr[key]
    save(path, order_by_en(en, data))
    after = len(set(en) - set(load(path)))
    print(f"  hr-HR: missing {before} -> {after}")


def apply_patches(en: dict[str, str]) -> None:
    if not PATCH_DIR.is_dir():
        print("No patches directory — skip patch merge.")
        return

    for patch_path in sorted(PATCH_DIR.glob("*_patch.json")):
        loc = patch_path.name.replace("_patch.json", "")
        locale_path = TRANS_DIR / f"{loc}.json"
        if not locale_path.is_file():
            print(f"  skip {loc}: locale file missing")
            continue

        patch = load(patch_path)
        data = load(locale_path)
        data.update(patch)
        save(locale_path, order_by_en(en, data))
        missing = len(set(en) - set(data))
        print(f"  {loc}: applied {len(patch)} keys, missing {missing}")


def report(en: dict[str, str]) -> None:
    print("\n=== Summary ===")
    print(f"{'locale':<10} {'keys':>6} {'missing':>8}")
    print("-" * 28)
    for path in sorted(TRANS_DIR.glob("*.json")):
        if path.parent != TRANS_DIR:
            continue
        loc = path.stem
        if loc == "en":
            continue
        data = load(path)
        missing = len(set(en) - set(data))
        print(f"{loc:<10} {len(data):>6} {missing:>8}")


def main() -> int:
    en = load(TRANS_DIR / "en.json")
    hr = load(TRANS_DIR / "hr.json")
    hr_hr = load(TRANS_DIR / "hr-HR.json")

    print("Filling Balkan locales from hr/hr-HR...")
    fill_balkan(en, hr, hr_hr)

    print("\nApplying patch files...")
    apply_patches(en)

    report(en)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
