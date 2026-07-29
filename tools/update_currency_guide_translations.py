#!/usr/bin/env python3
"""Update guide_profile_currency_body across all translation files."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TRANS_DIR = ROOT / "assets" / "translations"

BODY: dict[str, str] = {
    "hr": (
        "Zeleno polje pokazuje valutu u kojoj se prikazuju i preračunavaju sve cijene. "
        "Određuje je vaša lokacija (GPS/IP), ne jezik aplikacije — npr. u EU vidite € "
        "čak i s bosanskim ili hrvatskim sučeljem."
    ),
    "bs": (
        "Zeleno polje pokazuje valutu u kojoj se prikazuju i preračunavaju sve cijene. "
        "Određuje je vaša lokacija (GPS/IP), ne jezik aplikacije — npr. u EU vidite € "
        "čak i s bosanskim sučeljem."
    ),
    "sr": (
        "Zeleno polje pokazuje valutu za sve cijene. Određuje je lokacija (GPS/IP), "
        "ne jezik aplikacije — u dijaspori možete ručno odabrati BiH ili Srbiju iznad."
    ),
    "en": (
        "The green field shows the currency used for all prices. It is set by your "
        "location (GPS/IP), not the app language — e.g. in the EU you see € even with "
        "Bosnian or Croatian UI."
    ),
    "de": (
        "Das grüne Feld zeigt die Währung für alle Preise. Sie wird durch Ihren Standort "
        "(GPS/IP) bestimmt, nicht durch die App-Sprache — in der EU sehen Sie z. B. € "
        "auch bei bosnischer oder kroatischer Oberfläche."
    ),
    "it": (
        "Il campo verde mostra la valuta usata per tutti i prezzi. È determinata dalla "
        "tua posizione (GPS/IP), non dalla lingua dell'app — ad es. nell'UE vedi € "
        "anche con interfaccia bosniaca o croata."
    ),
    "fr": (
        "Le champ vert indique la devise utilisée pour tous les prix. Elle est déterminée "
        "par votre position (GPS/IP), pas par la langue de l'app — par ex. dans l'UE vous "
        "voyez € même avec l'interface bosniaque ou croate."
    ),
    "es": (
        "El campo verde muestra la moneda de todos los precios. La determina tu ubicación "
        "(GPS/IP), no el idioma de la app — p. ej. en la UE ves € incluso con interfaz "
        "bosnia o croata."
    ),
    "pl": (
        "Zielone pole pokazuje walutę wszystkich cen. Ustala ją lokalizacja (GPS/IP), "
        "a nie język aplikacji — np. w UE widzisz € nawet z interfejsem bośniackim "
        "lub chorwackim."
    ),
    "cs": (
        "Zelené pole ukazuje měnu pro všechny ceny. Určuje ji vaše poloha (GPS/IP), "
        "ne jazyk aplikace — v EU např. uvidíte € i s bosenským nebo chorvatským "
        "rozhraním."
    ),
    "sv": (
        "Det gröna fältet visar valutan för alla priser. Den bestäms av din plats (GPS/IP), "
        "inte appspråket — t.ex. i EU ser du € även med bosnisk eller kroatisk gränssnitt. "
        "Köpare kan välja Sverige eller EU ovan."
    ),
    "tr": (
        "Yeşil alan tüm fiyatların para birimini gösterir. Uygulama dili değil, konumunuz "
        "(GPS/IP) belirler — örn. AB'de Bosna veya Hırvat arayüzüyle bile € görürsünüz."
    ),
    "ru": (
        "Зелёное поле показывает валюту всех цен. Её определяет ваше местоположение "
        "(GPS/IP), а не язык приложения — например, в ЕС вы видите € даже с "
        "боснийским или хорватским интерфейсом."
    ),
    "uk": (
        "Зелене поле показує валюту всіх цін. Її визначає ваше місцезнаходження "
        "(GPS/IP), а не мова застосунку — наприклад, в ЄС ви бачите € навіть з "
        "боснійським або хорватським інтерфейсом."
    ),
    "zh": (
        "绿色字段显示所有价格使用的货币。由您的位置（GPS/IP）决定，而非应用语言——"
        "例如在欧盟，即使使用波斯尼亚语或克罗地亚语界面也会显示 €。"
    ),
    "hi": (
        "हरा क्षेत्र सभी कीमतों की मुद्रा दिखाता है। यह ऐप की भाषा नहीं, आपका स्थान "
        "(GPS/IP) तय करता है — जैसे EU में बोस्नियाई या क्रोएशियाई UI पर भी € दिखेगा।"
    ),
    "id": (
        "Kolom hijau menampilkan mata uang semua harga. Ditentukan oleh lokasi Anda "
        "(GPS/IP), bukan bahasa aplikasi — mis. di UE Anda melihat € meski antarmuka "
        "Bosnia atau Kroasia."
    ),
    "sw": (
        "Sehemu ya kijani inaonyesha sarafu ya bei zote. Inaamuliwa na eneo lako "
        "(GPS/IP), si lugha ya programu — mf. katika EU unaona € hata na kiolesura "
        "cha Kibosnia au Kikroeshia."
    ),
    "ar": (
        "يُظهر الحقل الأخضر العملة المستخدمة لجميع الأسعار. يحددها موقعك (GPS/IP) "
        "وليس لغة التطبيق — مثلاً في الاتحاد الأوروبي ترى € حتى مع واجهة بوسنية "
        "أو كرواتية."
    ),
}

FILE_TO_LANG = {
    "hr": "hr",
    "hr-HR": "hr",
    "hr-BA": "hr",
    "bs": "bs",
    "sr": "sr",
    "sr-BA": "sr",
    "sr-RS": "sr",
    "en": "en",
    "de": "de",
    "it": "it",
    "fr": "fr",
    "es": "es",
    "pl": "pl",
    "cs": "cs",
    "sv": "sv",
    "tr": "tr",
    "ru": "ru",
    "uk": "uk",
    "zh": "zh",
    "hi": "hi",
    "id": "id",
    "sw": "sw",
    "ar": "ar",
}

TITLE: dict[str, str] = {
    "hr": "Trenutna valuta",
    "bs": "Trenutna valuta",
    "sr": "Trenutna valuta",
    "en": "Current currency",
    "de": "Aktuelle Währung",
    "it": "Valuta attuale",
    "fr": "Devise actuelle",
    "es": "Moneda actual",
    "pl": "Aktualna waluta",
    "cs": "Aktuální měna",
    "sv": "Aktuell valuta",
    "tr": "Geçerli para birimi",
    "ru": "Текущая валюта",
    "uk": "Поточна валюта",
    "zh": "当前货币",
    "hi": "वर्तमान मुद्रा",
    "id": "Mata uang saat ini",
    "sw": "Sarafu ya sasa",
    "ar": "العملة الحالية",
}


def main() -> None:
    for path in sorted(TRANS_DIR.glob("*.json")):
        lang = FILE_TO_LANG.get(path.stem)
        if lang is None:
            continue
        data = json.loads(path.read_text(encoding="utf-8"))
        data["guide_profile_currency_title"] = TITLE[lang]
        data["guide_profile_currency_body"] = BODY[lang]
        path.write_text(
            json.dumps(data, ensure_ascii=False, indent=2) + "\n",
            encoding="utf-8",
        )
        print(f"updated {path.name}")


if __name__ == "__main__":
    main()
