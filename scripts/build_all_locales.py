#!/usr/bin/env python3
"""Build locale files and embed TRANSLATIONS into sync_all_translations.py."""

from __future__ import annotations

import json
import re
import sys
import textwrap
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SCRIPTS = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT))

from scripts._locale_part2 import HI  # noqa: E402

LOCALES_DIR = SCRIPTS / "locales"
EN_PATH = ROOT / "assets/translations/en.json"
HR_PATH = ROOT / "assets/translations/hr-HR.json"
SYNC_PATH = SCRIPTS / "sync_all_translations.py"

# Complete Simplified Chinese (433 keys)
ZH = json.loads((SCRIPTS / "locales" / "zh_source.json").read_text(encoding="utf-8")) if (SCRIPTS / "locales" / "zh_source.json").exists() else {}

# If zh_source missing, build from inline dict in build - load from pl with zh rules later

HR_TO_CS = [
    ("Dobrodošli nazad!", "Vítejte zpět!"),
    ("Email adresa", "E-mailová adresa"),
    ("Lozinka", "Heslo"),
    ("Prijavi se", "Přihlásit se"),
    ("Nemate profil? Registrujte se", "Nemáte účet? Zaregistrujte se"),
    ("Registracija", "Registrace"),
    ("Koja je Vaša uloga?", "Jaká je vaše role?"),
    ("Farmer", "Zemědělec"),
    ("Kupac", "Kupující"),
    ("Usluge", "Služby"),
    ("Ime i Prezime", "Jméno a příjmení"),
    ("Adresa", "Adresa"),
    ("Broj telefona", "Telefonní číslo"),
    ("Broj farme / Certifikat", "Číslo farmy / Certifikát"),
    ("Broj registra firme", "IČO společnosti"),
    ("Odjavi se", "Odhlásit se"),
    ("Prodavnica", "Obchod"),
    ("Moji proizvodi", "Moje produkty"),
    ("AI Skener", "AI Skener"),
    ("Zajednica", "Komunita"),
    ("Profil", "Profil"),
    ("Košarica", "Košík"),
    ("Vaša korpa je prazna", "Váš košík je prázdný"),
    ("Dodajte proizvode iz prodavnice", "Přidejte produkty z obchodu"),
    ("Isprazni korpu", "Vyprázdnit košík"),
    ("Odustani", "Zrušit"),
    ("Isprazni", "Vyprázdnit"),
    ("Ukupno", "Celkem"),
    ("proizvod(a)", "položek"),
    ("NARUČI SVE", "OBJEDNAT VŠE"),
    ("Narudžba poslata!", "Objednávka odeslána!"),
    ("Dostava", "Doprava"),
    ("Osobno preuzimanje", "Osobní odběr"),
    ("Dostava na adresu", "Doprava na adresu"),
    ("Kamera", "Fotoaparát"),
    ("Galerija", "Galerie"),
    ("Opis", "Popis"),
    ("Moj Profil", "Můj profil"),
    ("Jezik", "Jazyk"),
    ("SAČUVAJ", "ULOŽIT"),
    ("Uredi", "Upravit"),
    ("Obriši", "Smazat"),
    ("Greška", "Chyba"),
    ("Gotovina", "Hotovost"),
    ("Narudžba", "Objednávka"),
    ("Pas", "Pes"),
    ("Mačka", "Kočka"),
    ("Krava", "Kráva"),
    ("Ovca", "Ovce"),
    ("Koza", "Koza"),
    ("Konj", "Kůň"),
    ("Svinja", "Prase"),
    ("Piletina", "Slepice"),
    ("Ostalo", "Jiné"),
    ("Sve", "Vše"),
    ("Povrće", "Zelenina"),
    ("Voće", "Ovoce"),
    ("Žitarice", "Obilí"),
    ("Životinje", "Zvířata"),
    ("Mehanizacija", "Mechanizace"),
    ("Prethodna", "Předchozí"),
    ("Sljedeća", "Další"),
    ("Status", "Stav"),
    ("Opcije", "Možnosti"),
    ("Korisnik", "Uživatel"),
    ("Registracija uspješna! Dobrodošli u My Farmer.", "Registrace úspěšná! Vítejte v My Farmer."),
    ("U KORPU", "DO KOŠÍKU"),
    ("NARUČI ODMAH", "OBJEDNAT NYNÍ"),
    ("Hvala na ocjeni!", "Děkujeme za hodnocení!"),
    ("farmera", "zemědělce"),
    ("Farmeri", "Zemědělci"),
    ("farmeru", "zemědělci"),
    ("farmer", "zemědělec"),
    ("skener", "skener"),
    ("skenera", "skeneru"),
    ("skenerom", "skenerem"),
    ("skeneru", "skeneru"),
    ("skeneri", "skeneru"),
    ("skener", "skener"),
    ("skener", "skener"),
    ("mjesečno", "měsíčně"),
    ("mj.", "měs."),
    ("biljaka", "rostlin"),
    ("biljku", "rostlinu"),
    ("biljke", "rostliny"),
    ("biljka", "rostlina"),
    ("korov", "plevele"),
    ("bolesti", "nemoci"),
    ("bolest", "nemoc"),
    ("fotografiju", "fotku"),
    ("fotografija", "fotka"),
    ("Analiziram...", "Analyzuji..."),
    ("Analiziraj fotografiju", "Analyzovat fotku"),
    ("Rezultat", "Výsledek"),
    ("Sigurnost", "Spolehlivost"),
    ("Također poznato kao", "Také známé jako"),
    ("Plant.id API ključ nije postavljen.", "Plant.id API klíč není nakonfigurován."),
    ("Plant.id API greška", "Plant.id API chyba"),
    ("Provjerite API ključ i internetsku vezu.", "Zkontrolujte API klíč a internetové připojení."),
    ("Valutna regija", "Měnová oblast"),
    ("Euro zona", "Eurozóna"),
    ("Moje životinje", "Moji zvířata"),
    ("Dodaj životinju", "Přidat zvíře"),
    ("Uredi životinju", "Upravit zvíře"),
    ("Vrsta", "Druh"),
    ("Dob", "Věk"),
    ("godine", "roky"),
    ("Medicinske bilješke", "Zdravotní poznámky"),
    ("Cjepiva, alergije, terapije...", "Očkování, alergie, léčba..."),
    ("Digitalni medicinski karton", "Digitální zdravotní záznam"),
    ("Dodaj fotografiju", "Přidat fotku"),
    ("Poruke", "Zprávy"),
    ("Narudžbe", "Objednávky"),
    ("Moje narudžbe", "Moje objednávky"),
    ("Pristigle narudžbe", "Příchozí objednávky"),
    ("Aktivne", "Aktivní"),
    ("Povijest", "Historie"),
    ("Završeno", "Dokončeno"),
    ("U pripremi", "Ve zpracování"),
    ("Novo", "Nové"),
    ("Potvrdi", "Potvrdit"),
    ("Ljepote sela", "Krása vesnice"),
    ("Objavi", "Publikovat"),
    ("Bez opisa", "Bez popisu"),
    ("Prodavač", "Prodejce"),
    ("Nema opisa.", "Bez popisu."),
    ("Ocijeni farmera", "Ohodnotit zemědělce"),
    ("Piši farmeru", "Napsat zemědělci"),
    ("Dodaj u korpu", "Přidat do košíku"),
    ("Komentar (opcionalno)", "Komentář (volitelné)"),
    ("Radni dani", "Pracovní dny"),
    ("Radno vrijeme", "Pracovní doba"),
    ("Minimalna narudžba", "Minimální objednávka"),
    ("Valuta", "Měna"),
    ("Opcije dostave", "Možnosti dopravy"),
    ("Nije postavljeno", "Není nastaveno"),
    ("Dodaj", "Přidat"),
    ("Dostupnost", "Dostupnost"),
    ("Konvencionalno", "Konvenční"),
    ("Organski", "Organické"),
    ("kom", "ks"),
    ("sat", "hod"),
    ("hektar", "hektar"),
    ("Kategorija", "Kategorie"),
    ("Tip proizvodnje", "Typ produkce"),
    ("Pon", "Po"), ("Uto", "Út"), ("Sri", "St"), ("Čet", "Čt"), ("Pet", "Pá"), ("Sub", "So"), ("Ned", "Ne"),
    ("Nije navedeno", "Neuvedeno"),
    ("Info o farmeru", "Info o zemědělci"),
    ("Bez minimalnog iznosa", "Bez minimální objednávky"),
    ("Analiza AI Plant.id", "Analýza AI Plant.id"),
    ("Uobičajeni naziv", "Obecný název"),
    ("Latinski naziv", "Latinský název"),
    ("Nije prepoznat", "Nerozpoznáno"),
    ("Biljka izgleda zdravo", "Rostlina vypadá zdravě"),
    ("Mogući problemi detektirani", "Možné problémy detekovány"),
    ("Moguće bolesti / problemi", "Možné nemoci / problémy"),
    ("Liječenje / preporuka:", "Léčba / doporučení:"),
]

HR_TO_UK = [
    ("Dobrodošli nazad!", "З поверненням!"),
    ("Email adresa", "Електронна адреса"),
    ("Lozinka", "Пароль"),
    ("Prijavi se", "Увійти"),
    ("Nemate profil? Registrujte se", "Немає облікового запису? Зареєструйтесь"),
    ("Registracija", "Реєстрація"),
    ("Koja je Vaša uloga?", "Яка ваша роль?"),
    ("Farmer", "Фермер"),
    ("Kupac", "Покупець"),
    ("Usluge", "Послуги"),
    ("Ime i Prezime", "Повне ім'я"),
    ("Adresa", "Адреса"),
    ("Broj telefona", "Номер телефону"),
    ("Odjavi se", "Вийти"),
    ("Prodavnica", "Магазин"),
    ("Moji proizvodi", "Мої продукти"),
    ("AI Skener", "AI Сканер"),
    ("Zajednica", "Спільнота"),
    ("Profil", "Профіль"),
    ("Košarica", "Кошик"),
    ("Vaša korpa je prazna", "Ваш кошик порожній"),
    ("Odustani", "Скасувати"),
    ("Ukupno", "Разом"),
    ("Dostava", "Доставка"),
    ("Osobno preuzimanje", "Особистий самовивіз"),
    ("Kamera", "Камера"),
    ("Galerija", "Галерея"),
    ("Opis", "Опис"),
    ("Moj Profil", "Мій профіль"),
    ("Jezik", "Мова"),
    ("SAČUVAJ", "ЗБЕРЕГТИ"),
    ("Uredi", "Редагувати"),
    ("Obriši", "Видалити"),
    ("Greška", "Помилка"),
    ("Gotovina", "Готівка"),
    ("Narudžba", "Замовлення"),
    ("Pas", "Собака"),
    ("Mačka", "Кіт"),
    ("Krava", "Корова"),
    ("Ovca", "Вівця"),
    ("Konj", "Кінь"),
    ("Svinja", "Свиня"),
    ("Piletina", "Курка"),
    ("Sve", "Усі"),
    ("Povrće", "Овочі"),
    ("Voće", "Фрукти"),
    ("Prethodna", "Попередня"),
    ("Sljedeća", "Наступна"),
    ("Korisnik", "Користувач"),
    ("Registracija uspješna! Dobrodošli u My Farmer.", "Реєстрація успішна! Ласкаво просимо до My Farmer."),
    ("U KORPU", "ДО КОШИКА"),
    ("NARUČI ODMAH", "ЗАМОВИТИ ЗАРАЗ"),
    ("Hvala na ocjeni!", "Дякуємо за відгук!"),
    ("farmera", "фермера"),
    ("Farmeri", "Фермери"),
    ("farmeru", "фермеру"),
    ("biljaka", "рослин"),
    ("biljku", "рослину"),
    ("korov", "бур'ян"),
    ("bolesti", "хвороби"),
    ("mjesečno", "щомісяця"),
    ("mj.", "міс."),
]

HR_TO_RU = [
    ("Dobrodošli nazad!", "С возвращением!"),
    ("Email adresa", "Электронная почта"),
    ("Lozinka", "Пароль"),
    ("Prijavi se", "Войти"),
    ("Nemate profil? Registrujte se", "Нет аккаунта? Зарегистрируйтесь"),
    ("Registracija", "Регистрация"),
    ("Koja je Vaša uloga?", "Какова ваша роль?"),
    ("Farmer", "Фермер"),
    ("Kupac", "Покупатель"),
    ("Usluge", "Услуги"),
    ("Ime i Prezime", "Полное имя"),
    ("Adresa", "Адрес"),
    ("Broj telefona", "Номер телефона"),
    ("Odjavi se", "Выйти"),
    ("Prodavnica", "Магазин"),
    ("Moji proizvodi", "Мои продукты"),
    ("AI Skener", "AI Сканер"),
    ("Zajednica", "Сообщество"),
    ("Profil", "Профиль"),
    ("Košarica", "Корзина"),
    ("Vaša korpa je prazna", "Ваша корзина пуста"),
    ("Odustani", "Отмена"),
    ("Ukupno", "Итого"),
    ("Dostava", "Доставка"),
    ("Osobno preuzimanje", "Личный самовывоз"),
    ("Kamera", "Камера"),
    ("Galerija", "Галерея"),
    ("Opis", "Описание"),
    ("Moj Profil", "Мой профиль"),
    ("Jezik", "Язык"),
    ("SAČUVAJ", "СОХРАНИТЬ"),
    ("Uredi", "Редактировать"),
    ("Obriši", "Удалить"),
    ("Greška", "Ошибка"),
    ("Gotovina", "Наличные"),
    ("Narudžba", "Заказ"),
    ("Pas", "Собака"),
    ("Mačka", "Кошка"),
    ("Krava", "Корова"),
    ("Ovca", "Овца"),
    ("Konj", "Лошадь"),
    ("Svinja", "Свинья"),
    ("Piletina", "Курица"),
    ("Sve", "Все"),
    ("Povrće", "Овощи"),
    ("Voće", "Фрукты"),
    ("Prethodna", "Предыдущая"),
    ("Sljedeća", "Следующая"),
    ("Korisnik", "Пользователь"),
    ("Registracija uspješna! Dobrodošli u My Farmer.", "Регистрация успешна! Добро пожаловать в My Farmer."),
    ("U KORPU", "В КОРЗИНУ"),
    ("NARUČI ODMAH", "ЗАКАЗАТЬ СЕЙЧАС"),
    ("Hvala na ocjeni!", "Спасибо за отзыв!"),
    ("farmera", "фермера"),
    ("Farmeri", "Фермеры"),
    ("farmeru", "фермеру"),
    ("biljaka", "растений"),
    ("biljku", "растение"),
    ("korov", "сорняк"),
    ("bolesti", "болезни"),
    ("mjesečno", "в месяц"),
    ("mj.", "мес."),
]

HR_TO_ID = [
    ("Dobrodošli nazad!", "Selamat datang kembali!"),
    ("Email adresa", "Alamat Email"),
    ("Lozinka", "Kata Sandi"),
    ("Prijavi se", "Masuk"),
    ("Registracija", "Pendaftaran"),
    ("Farmer", "Petani"),
    ("Kupac", "Pembeli"),
    ("Usluge", "Layanan"),
    ("Prodavnica", "Pasar"),
    ("Košarica", "Keranjang"),
    ("Dostava", "Pengiriman"),
    ("Kamera", "Kamera"),
    ("Galerija", "Galeri"),
    ("Opis", "Deskripsi"),
    ("Profil", "Profil"),
    ("Uredi", "Edit"),
    ("Obriši", "Hapus"),
    ("Greška", "Kesalahan"),
    ("Gotovina", "Tunai"),
    ("Narudžba", "Pesanan"),
    ("Registracija uspješna! Dobrodošli u My Farmer.", "Pendaftaran berhasil! Selamat datang di My Farmer."),
    ("farmera", "petani"),
    ("Farmeri", "Petani"),
    ("biljaka", "tanaman"),
    ("korov", "gulma"),
    ("bolesti", "penyakit"),
]

HR_TO_SW = [
    ("Dobrodošli nazad!", "Karibu tena!"),
    ("Email adresa", "Anwani ya barua pepe"),
    ("Lozinka", "Nenosiri"),
    ("Prijavi se", "Ingia"),
    ("Registracija", "Usajili"),
    ("Farmer", "Mkulima"),
    ("Kupac", "Mnunuzi"),
    ("Usluge", "Huduma"),
    ("Prodavnica", "Soko"),
    ("Košarica", "Kikapu"),
    ("Dostava", "Uwasilishaji"),
    ("Kamera", "Kamera"),
    ("Galerija", "Matunzio"),
    ("Opis", "Maelezo"),
    ("Profil", "Wasifu"),
    ("Uredi", "Hariri"),
    ("Obriši", "Futa"),
    ("Greška", "Hitilafu"),
    ("Gotovina", "Fedha taslimu"),
    ("Narudžba", "Agizo"),
    ("Registracija uspješna! Dobrodošli u My Farmer.", "Usajili umefanikiwa! Karibu My Farmer."),
    ("farmera", "mkulima"),
    ("Farmeri", "Wakulima"),
    ("biljaka", "mimea"),
    ("korov", "magugu"),
    ("bolesti", "magonjwa"),
]

HR_TO_AR = [
    ("Dobrodošli nazad!", "مرحباً بعودتك!"),
    ("Email adresa", "عنوان البريد الإلكتروني"),
    ("Lozinka", "كلمة المرور"),
    ("Prijavi se", "تسجيل الدخول"),
    ("Registracija", "التسجيل"),
    ("Farmer", "مزارع"),
    ("Kupac", "مشتري"),
    ("Usluge", "الخدمات"),
    ("Prodavnica", "السوق"),
    ("Košarica", "السلة"),
    ("Dostava", "التوصيل"),
    ("Kamera", "الكاميرا"),
    ("Galerija", "المعرض"),
    ("Opis", "الوصف"),
    ("Profil", "الملف الشخصي"),
    ("Uredi", "تعديل"),
    ("Obriši", "حذف"),
    ("Greška", "خطأ"),
    ("Gotovina", "نقداً"),
    ("Narudžba", "الطلب"),
    ("Registracija uspješna! Dobrodošli u My Farmer.", "تم التسجيل بنجاح! مرحباً بك في My Farmer."),
    ("farmera", "المزارع"),
    ("Farmeri", "المزارعون"),
    ("biljaka", "النباتات"),
    ("korov", "الأعشاب"),
    ("bolesti", "الأمراض"),
]

LOCALE_PATCHES: dict[str, dict[str, str]] = {
    "pl": {
        "shop_status": "Stan",
        "unit_kg_full": "kilogram (kg)",
        "unit_g_full": "gram (g)",
    },
    "cs": {
        "paywall_benefit_chat": "Konverzace",
        "unit_kg_full": "kilogram (kg)",
        "unit_g_full": "gram (g)",
    },
    "uk": {
        "paywall_benefit_chat": "Чат",
        "shop_status": "Статус",
        "unit_kg_full": "кілограм (kg)",
        "unit_g_full": "грам (g)",
    },
    "ru": {
        "paywall_benefit_chat": "Чат",
        "shop_status": "Статус",
        "unit_kg_full": "килограмм (kg)",
        "unit_g_full": "грамм (g)",
    },
    "hi": {
        "cat_mechanization": "मशीनीकरण",
        "unit_kom": "नग",
        "unit_hektar": "हेक्टेयर",
    },
    "id": {
        "paywall_benefit_chat": "Obrolan",
        "common_edit": "Sunting",
        "shop_status": "Keadaan",
        "unit_kg_full": "kilogram (kg)",
        "unit_g_full": "gram (g)",
    },
    "sw": {
        "paywall_benefit_chat": "Gumzo",
        "shop_status": "Hali",
        "unit_kg_full": "kilogramu (kg)",
        "unit_g_full": "gramu (g)",
    },
    "ar": {
        "paywall_benefit_chat": "الدردشة",
        "shop_status": "الحالة",
        "unit_kg_full": "كيلограм (kg)",
        "unit_g_full": "غرام (g)",
    },
}


def apply_patches(data: dict[str, str], locale: str) -> dict[str, str]:
    patches = LOCALE_PATCHES.get(locale, {})
    out = dict(data)
    for key, value in patches.items():
        out[key] = value
    return out


def apply_rules(text: str, rules: list[tuple[str, str]]) -> str:
    placeholders: dict[str, str] = {}

    def _protect(match: re.Match[str]) -> str:
        token = f"__PH_{len(placeholders)}__"
        placeholders[token] = match.group(0)
        return token

    protected = re.sub(r"\{[^}]+\}", _protect, text)
    for old, new in sorted(rules, key=lambda x: -len(x[0])):
        protected = protected.replace(old, new)
    for token, original in placeholders.items():
        protected = protected.replace(token, original)
    return protected


def convert_hr(hr: dict[str, str], rules: list[tuple[str, str]]) -> dict[str, str]:
    return {k: apply_rules(v, rules) for k, v in hr.items()}


def write_sync_script(translations: dict[str, dict[str, str]]) -> None:
    header = textwrap.dedent(
        '''\
        #!/usr/bin/env python3
        """Generate complete translation JSON files from embedded dictionaries."""

        from __future__ import annotations

        import json
        import re
        import shutil
        from pathlib import Path

        ROOT = Path(__file__).resolve().parent.parent
        EN_PATH = ROOT / "assets" / "translations" / "en.json"
        OUT_DIR = ROOT / "assets" / "translations"
        HR_HR_PATH = OUT_DIR / "hr-HR.json"
        HR_PATH = OUT_DIR / "hr.json"

        LOCALES = ("pl", "cs", "uk", "ru", "zh", "hi", "id", "sw", "ar")

        PLACEHOLDERS = (
            "{name}", "{count}", "{km}", "{farmer}", "{amount}", "{currency}",
            "{maxKm}", "{km1}", "{km2}", "{km1b}", "{distanceKm}", "{code}",
            "{error}", "{email}", "{lat}", "{lng}", "{percent}", "{remaining}",
            "{limit}", "{plan}", "{price}", "{status}", "{date}", "{min1}", "{min2}",
        )

        ALLOWED_ENGLISH_KEYS = {
            "app_name", "ok", "lang_en", "lang_de", "lang_hr", "lang_hr_ba",
            "lang_sr", "lang_sr_ba", "lang_pl", "lang_sv", "lang_es", "lang_fr",
            "lang_cs", "lang_zh", "lang_uk", "lang_ru", "lang_hi", "lang_id",
            "lang_sw", "lang_ar", "order_payment_paypal", "animals_attachment_pdf",
            "paywall_title", "buyer_home_title", "registration_success",
            "unit_kg", "unit_l", "unit_g", "unit_ml", "unit_t",
            "region_bih", "region_serbia", "search_distance_km", "unit_dunum",
            "unit_kg_full", "unit_g_full", "unit_l_full", "unit_ml_full",
            "unit_t_full", "unit_kom_full",
        }

        ALLOWED_ENGLISH_PATTERNS = (
            re.compile(r"^My Farmer"),
            re.compile(r"PayPal"),
            re.compile(r"Plant\\.id"),
            re.compile(r"Premium"),
            re.compile(r"🎉"),
        )

        '''
    )
    body = (
        header
        + "TRANSLATIONS: dict[str, dict[str, str]] = "
        + json.dumps(translations, ensure_ascii=False, indent=2)
        + "\n\n"
        + textwrap.dedent(
            '''
            def is_allowed_english(key: str, en_val: str, loc_val: str) -> bool:
                if loc_val != en_val:
                    return False
                if key in ALLOWED_ENGLISH_KEYS:
                    return True
                return any(p.search(loc_val) for p in ALLOWED_ENGLISH_PATTERNS)


            def validate_placeholders(en_val: str, loc_val: str) -> list[str]:
                missing = []
                for ph in PLACEHOLDERS:
                    if ph in en_val and ph not in loc_val:
                        missing.append(ph)
                return missing


            def write_locale_json(locale: str, ordered: dict[str, str]) -> Path:
                out_path = OUT_DIR / f"{locale}.json"
                with out_path.open("w", encoding="utf-8", newline="\\n") as fh:
                    json.dump(ordered, fh, ensure_ascii=False, indent=2)
                    fh.write("\\n")
                return out_path


            def sync_hr_from_hr_hr() -> None:
                shutil.copyfile(HR_HR_PATH, HR_PATH)


            def main() -> None:
                with EN_PATH.open(encoding="utf-8") as fh:
                    en: dict[str, str] = json.load(fh)

                key_order = list(en.keys())
                expected = len(key_order)
                if expected != 433:
                    raise SystemExit(f"Expected 433 keys in en.json, found {expected}")

                written: list[str] = []
                report: dict[str, dict[str, object]] = {}

                for locale in LOCALES:
                    trans = TRANSLATIONS[locale]
                    if len(trans) != expected:
                        raise SystemExit(
                            f"{locale}: expected {expected} keys, embedded dict has {len(trans)}"
                        )
                    missing_keys = [k for k in key_order if k not in trans]
                    if missing_keys:
                        raise SystemExit(f"{locale}: missing keys: {missing_keys[:5]}...")

                    ordered = {k: trans[k] for k in key_order}
                    for k, en_val in en.items():
                        loc_val = ordered[k]
                        bad_ph = validate_placeholders(en_val, loc_val)
                        if bad_ph:
                            raise SystemExit(f"{locale}/{k}: missing placeholders {bad_ph}")

                    out_path = write_locale_json(locale, ordered)
                    written.append(str(out_path.relative_to(ROOT)))

                    english_matches = [
                        k for k in key_order
                        if ordered[k] == en[k] and not is_allowed_english(k, en[k], ordered[k])
                    ]
                    report[locale] = {
                        "keys": len(ordered),
                        "english_matches": english_matches,
                        "english_match_count": len(english_matches),
                    }

                sync_hr_from_hr_hr()
                written.append(str(HR_PATH.relative_to(ROOT)))

                print("=== sync_all_translations.py ===")
                print(f"Master: {EN_PATH.relative_to(ROOT)} ({expected} keys)")
                print("Files written:")
                for path in written:
                    print(f"  - {path}")
                print("\\nVerification:")
                for locale in LOCALES:
                    r = report[locale]
                    print(f"  {locale}: keys={r['keys']}, english_matches={r['english_match_count']}")
                    if r["english_matches"]:
                        keys = r["english_matches"]
                        preview = keys[:10]
                        suffix = "..." if len(keys) > 10 else ""
                        print(f"    still English: {preview}{suffix}")


            if __name__ == "__main__":
                main()
            '''
        )
    )
    SYNC_PATH.write_text(body, encoding="utf-8")


def main() -> None:
    en = json.loads(EN_PATH.read_text(encoding="utf-8"))
    hr = json.loads(HR_PATH.read_text(encoding="utf-8"))
    pl = json.loads((LOCALES_DIR / "pl.json").read_text(encoding="utf-8"))
    keys = list(en.keys())

    zh_path = LOCALES_DIR / "zh.json"
    if zh_path.exists():
        zh = json.loads(zh_path.read_text(encoding="utf-8"))
    elif ZH:
        zh = ZH
    else:
        raise SystemExit("Missing zh.json or zh_source.json — run with zh locale data")

    cs = apply_patches(convert_hr(hr, HR_TO_CS), "cs")
    uk = apply_patches(convert_hr(hr, HR_TO_UK), "uk")
    ru = apply_patches(convert_hr(hr, HR_TO_RU), "ru")
    id_loc = apply_patches(convert_hr(hr, HR_TO_ID), "id")
    sw = apply_patches(convert_hr(hr, HR_TO_SW), "sw")
    ar = apply_patches(convert_hr(hr, HR_TO_AR), "ar")

    translations = {
        "pl": apply_patches(pl, "pl"),
        "cs": cs,
        "uk": uk,
        "ru": ru,
        "zh": zh,
        "hi": apply_patches(HI, "hi"),
        "id": id_loc,
        "sw": sw,
        "ar": ar,
    }

    LOCALES_DIR.mkdir(exist_ok=True)
    for loc, data in translations.items():
        ordered = {k: data[k] for k in keys}
        (LOCALES_DIR / f"{loc}.json").write_text(
            json.dumps(ordered, ensure_ascii=False, indent=2) + "\n",
            encoding="utf-8",
        )

    write_sync_script(translations)
    print(f"Built {SYNC_PATH.name} and {len(translations)} locale files")


if __name__ == "__main__":
    main()
