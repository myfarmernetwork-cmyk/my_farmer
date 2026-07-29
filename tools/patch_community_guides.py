import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DART = ROOT / "lib/widgets/farmer_help_widgets.dart"

guide_keys = [
    "guide_community_feed_title",
    "guide_community_feed_body",
    "guide_community_add_post_title",
    "guide_community_add_post_body",
    "guide_community_pagination_title",
    "guide_community_pagination_body",
]

lang_files = {
    "hr": "hr.json",
    "de": "de.json",
    "en": "en.json",
    "pl": "pl.json",
    "fr": "fr.json",
    "es": "es.json",
    "it": "it.json",
    "cs": "cs.json",
    "sv": "sv.json",
    "uk": "uk.json",
    "ru": "ru.json",
    "hi": "hi.json",
    "id": "id.json",
    "sw": "sw.json",
    "ar": "ar.json",
    "tr": "tr.json",
    "zh": "zh.json",
    "sr": "sr.json",
}

translations = {}
for lang, fname in lang_files.items():
    with open(ROOT / "assets/translations" / fname, encoding="utf-8") as f:
        translations[lang] = json.load(f)


def dart_str(s: str) -> str:
    return "'" + s.replace("\\", "\\\\").replace("'", "\\'").replace("\n", " ") + "'"


def render_block(key: str) -> str:
    lines = [f"  '{key}': {{"]
    for lang in lang_files:
        val = translations[lang].get(key)
        if not val:
            continue
        ds = dart_str(val)
        if len(val) > 72:
            lines.append(f"    '{lang}':")
            lines.append(f"        {ds},")
        else:
            lines.append(f"    '{lang}': {ds},")
    lines.append("  },")
    return "\n".join(lines)


text = DART.read_text(encoding="utf-8")

for key in guide_keys:
    pattern = rf"  '{re.escape(key)}': \{{.*?\}},\n"
    block = render_block(key) + "\n"
    text, count = re.subn(pattern, block, text, count=1, flags=re.DOTALL)
    if count != 1:
        raise SystemExit(f"Failed to replace {key}")

# Remove Croatian last-resort fallback in farmerGuideTr.
text = text.replace(
    "  return resolved?[lang] ?? resolved?['en'] ?? resolved?['hr'] ?? translated;",
    "  return resolved?[lang] ?? resolved?['en'] ?? translated;",
)

DART.write_text(text, encoding="utf-8")
print("patched", DART)
