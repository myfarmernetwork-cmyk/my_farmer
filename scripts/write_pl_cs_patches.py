#!/usr/bin/env python3
"""Write cs_patch.json and pl_patch.json from translation data."""

from __future__ import annotations

import json
from pathlib import Path

from _patch_translations_data import CS, PL

ROOT = Path(__file__).resolve().parent.parent
PATCH_DIR = ROOT / "assets" / "translations" / "patches"
TRANS_DIR = ROOT / "assets" / "translations"


def main() -> None:
    pl_needs = json.loads((PATCH_DIR / "pl_needs.json").read_text(encoding="utf-8"))
    cs_needs = json.loads((PATCH_DIR / "cs_needs.json").read_text(encoding="utf-8"))
    pl_json = json.loads((TRANS_DIR / "pl.json").read_text(encoding="utf-8"))

    cs_missing = [k for k in cs_needs if k not in CS]
    if cs_missing:
        raise SystemExit(f"Missing CS translations: {len(cs_missing)} — e.g. {cs_missing[:5]}")

    pl_missing_keys = [k for k in pl_needs if k not in pl_json]
    pl_missing = [k for k in pl_missing_keys if k not in PL]
    if pl_missing:
        raise SystemExit(f"Missing PL translations: {len(pl_missing)} — e.g. {pl_missing[:5]}")

    cs_patch = {k: CS[k] for k in cs_needs}
    pl_patch: dict[str, str] = {}
    for k in pl_needs:
        pl_patch[k] = pl_json[k] if k in pl_json else PL[k]

    for name, patch in (("cs_patch.json", cs_patch), ("pl_patch.json", pl_patch)):
        out = PATCH_DIR / name
        with out.open("w", encoding="utf-8", newline="\n") as fh:
            json.dump(patch, fh, ensure_ascii=False, indent=2)
            fh.write("\n")
        print(f"Wrote {len(patch)} keys to {out}")

    print(f"CS patch keys: {len(cs_patch)} (expected {len(cs_needs)})")
    print(f"PL patch keys: {len(pl_patch)} (expected {len(pl_needs)})")
    print(f"PL dict keys: {len(PL)} (expected {len(pl_missing_keys)})")


if __name__ == "__main__":
    main()
