#!/usr/bin/env python3
"""Update farmer_helper_scroll_hint across translation files."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TRANS_DIR = ROOT / "assets" / "translations"

HINTS = {
    "hr": "Povucite prstom gore ili dolje po tamnom dijelu da listate ekran. Svjetlo se automatski centrira na označeno polje.",
    "bs": "Povucite prstom gore ili dolje po tamnom dijelu da listate ekran. Svjetlo se automatski centrira na označeno polje.",
    "sr": "Povucite prstom gore ili dole po tamnom delu da listate ekran. Svetlo se automatski centrira na označeno polje.",
    "en": "Drag up or down on the dark area to scroll. The spotlight auto-centers on the highlighted field.",
    "de": "Wischen Sie auf dem dunklen Bereich nach oben/unten zum Scrollen. Das Spotlight zentriert sich automatisch.",
    "it": "Trascina su/giù sull'area scura per scorrere. Il riflettore si centra automaticamente sul campo evidenziato.",
    "fr": "Glissez vers le haut ou le bas sur la zone sombre pour faire défiler. Le spotlight se centre automatiquement.",
    "es": "Desliza arriba o abajo en la zona oscura para desplazarte. El foco se centra automáticamente en el campo resaltado.",
    "pl": "Przeciągnij w górę lub w dół po ciemnym obszarze, aby przewinąć. Reflektor automatycznie centruje pole.",
    "cs": "Táhněte nahoru nebo dolů po tmavé oblasti pro posun. Světlo se automaticky vycentruje na zvýrazněné pole.",
    "sv": "Dra upp eller ner på det mörka området för att scrolla. Spotlights centreras automatiskt.",
    "tr": "Kaydırmak için karanlık alanda yukarı/aşağı sürükleyin. Işık otomatik olarak vurgulanan alana ortalanır.",
    "ru": "Проведите вверх или вниз по тёмной области для прокрутки. Подсветка автоматически центрируется на поле.",
    "uk": "Проведіть вгору або вниз по темній області для прокрутки. Підсвітка автоматично центрується на полі.",
    "zh": "在暗色区域上下拖动以滚动。聚光灯会自动居中到高亮字段。",
    "hi": "स्क्रॉल करने के लिए गहरे क्षेत्र पर ऊपर/नीचे खींचें। स्पॉटलाइट स्वचालित रूप से केंद्रित होती है।",
    "id": "Geser ke atas/bawah di area gelap untuk scroll. Spotlight otomatis ke tengah bidang yang disorot.",
    "sw": "Buruta juu au chini kwenye eneo lenye giza ili kusogeza. Mwangaza huwa katikati kiotomatiki.",
    "ar": "اسحب لأعلى أو لأسفل على المنطقة الداكنة للتمرير. يتمركز الضوء تلقائيًا على الحقل المحدد.",
}

FILE_TO_LANG = {
    "hr": "hr", "hr-HR": "hr", "hr-BA": "hr",
    "bs": "bs", "sr": "sr", "sr-BA": "sr", "sr-RS": "sr",
    "en": "en", "de": "de", "it": "it", "fr": "fr", "es": "es",
    "pl": "pl", "cs": "cs", "sv": "sv", "tr": "tr", "ru": "ru",
    "uk": "uk", "zh": "zh", "hi": "hi", "id": "id", "sw": "sw", "ar": "ar",
}

for path in sorted(TRANS_DIR.glob("*.json")):
    lang = FILE_TO_LANG.get(path.stem)
    if not lang:
        continue
    data = json.loads(path.read_text(encoding="utf-8"))
    data["farmer_helper_scroll_hint"] = HINTS[lang]
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"updated {path.name}")
