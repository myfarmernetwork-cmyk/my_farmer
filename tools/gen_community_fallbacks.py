import json

guide_keys = [
    "guide_community_feed_title",
    "guide_community_feed_body",
    "guide_community_add_post_title",
    "guide_community_add_post_body",
    "guide_community_pagination_title",
    "guide_community_pagination_body",
]

lang_files = {
    "en": "en.json",
    "de": "de.json",
    "fr": "fr.json",
    "es": "es.json",
    "it": "it.json",
    "pl": "pl.json",
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
    "hr": "hr.json",
    "sr": "sr.json",
}

data = {}
for lang, fname in lang_files.items():
    with open(f"assets/translations/{fname}", encoding="utf-8") as f:
        data[lang] = json.load(f)


def esc(s: str) -> str:
    return s.replace("\\", "\\\\").replace("'", "\\'").replace("\n", " ")


langs_order = [
    "hr",
    "de",
    "en",
    "pl",
    "fr",
    "es",
    "it",
    "cs",
    "sv",
    "uk",
    "ru",
    "hi",
    "id",
    "sw",
    "ar",
    "tr",
    "zh",
    "sr",
]

lines = []
for gk in guide_keys:
    lines.append(f"  '{gk}': {{")
    for lang in langs_order:
        val = data.get(lang, {}).get(gk)
        if not val:
            continue
        if len(val) > 72:
            lines.append(f"    '{lang}':")
            lines.append(f"        '{esc(val)}',")
        else:
            lines.append(f"    '{lang}': '{esc(val)}',")
    lines.append("  },")

with open("tools/community_fallbacks.txt", "w", encoding="utf-8") as out:
    out.write("\n".join(lines))
print("written", len(lines), "lines")
