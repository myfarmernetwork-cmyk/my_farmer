#!/usr/bin/env python3
"""Rebuild Bosnian translation files from hr-HR base."""
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
EN_PATH = ROOT / "assets" / "translations" / "en.json"
HR_PATH = ROOT / "assets" / "translations" / "hr-HR.json"
OUT_PATHS = [
    ROOT / "assets" / "translations" / "bs.json",
    ROOT / "assets" / "translations" / "hr-BA.json",
]

FARMER_REPLACEMENTS = [
    ("Farmeri", "Poljoprivrednici"),
    ("Farmera", "Poljoprivrednika"),
    ("Farmeru", "Poljoprivredniku"),
    ("Farmer", "Poljoprivrednik"),
    ("farmeri", "poljoprivrednici"),
    ("farmera", "poljoprivrednika"),
    ("farmeru", "poljoprivredniku"),
    ("farmer", "poljoprivrednik"),
    ("farmere", "poljoprivrednike"),
]

KEY_OVERRIDES = {
    "app_name": "My Farmer",
    "cart_title": "Moja korpa",
    "buyer_home_title": "Pijaca My Farmer",
    "nav_marketplace": "Pijaca",
    "cart_empty_hint": "Dodajte proizvode sa pijace",
    "registration_success": "Registracija uspješna! Dobrodošli u My Farmer.",
    "role_hobby_farmer": "Hobi poljoprivrednik",
    "role_professional_farmer": "Profesionalni poljoprivrednik",
    "paywall_hobby_title": "Hobi poljoprivrednik Premium",
    "paywall_pro_title": "Profesionalni poljoprivrednik Premium",
    "role_buyer_info": "Besplatno: Pregled pijace, praćenje poljoprivrednika, 3 AI skeniranja u probnom periodu, osnovni profil.\n\nPremium (Kupac Premium): 15 AI skeniranja mjesečno, digitalni karton životinja, automatski prevod chata, narudžbe i rezervacije.",
    "role_hobby_farmer_info": "Besplatno: Do 3 proizvoda u izlogu, osnovni profil gazdinstva, radno vrijeme i dostava.\n\nPremium (Hobi poljoprivrednik Premium): Do 4 proizvoda, 30 AI skeniranja/mj, sve Premium funkcije kupca, neograničen chat.",
    "role_professional_farmer_info": "Besplatno: Osnovni profil gazdinstva (OPG), ograničen broj proizvoda u izlogu.\n\nPremium (Pro poljoprivrednik Premium): Neograničen izlog, tab Usluge mehanizacije, 60 skeniranja/mj, zone dostave i lično preuzimanje.",
    "role_company_info": "Besplatno: Profil firme nakon odobrenja administratora, promotivni period 3 mj s 3 skeniranja/mj.\n\nLicenca (Firma): Katalog proizvoda (sjeme, gnojiva, strojevi, traktori), 100 skeniranja/mj, poslovni izlog na pijaci.",
    "search_no_results_radius": "Nema poljoprivrednika, firmi ili usluga unutar {km} km od vas.",
    "cart_order_success_one": "Vaša narudžba je uspješno poslata. Poljoprivrednik će vas kontaktirati.",
    "cart_order_success_many": "Poslato je {count} narudžbi (po jednoj po poljoprivredniku). Poljoprivrednici će vas kontaktirati.",
    "cart_no_delivery_options": "Poljoprivrednik nije definisao opcije preuzimanja/dostave.",
    "cart_pickup": "Lično preuzimanje",
    "cart_delivery_out_of_range": "Predaleko od {name} za dostavu (maks. {maxKm} km). Odaberite lično preuzimanje.",
    "cart_seller_no_delivery": "{name} ne nudi dostavu na adresu. Odaberite lično preuzimanje.",
    "cart_delivery_too_far_detail": "Predaleko od {name}: {distanceKm} km (maks. {maxKm} km). Odaberite lično preuzimanje.",
    "order_delivery_pickup": "Lično preuzimanje",
    "profile_pickup_schedule": "Raspored ličnog preuzimanja",
    "product_no_paypal": "Poljoprivrednik nije postavio PayPal — plaćanje samo gotovinom.",
    "product_rate_farmer": "Ocijeni poljoprivrednika",
    "product_chat_farmer": "Piši poljoprivredniku",
    "product_already_reviewed": "Već ste ocijenili ovog poljoprivrednika.",
    "product_min_order_required": "Minimalan iznos narudžbe kod ovog poljoprivrednika je {amount} {currency}.",
    "shop_farmer_info": "Info o poljoprivredniku",
    "paywall_benefit_orders_desc": "Naručuj proizvode direktno od poljoprivrednika",
    "paywall_benefit_chat_desc": "Piši poljoprivrednicima u realnom vremenu",
    "paywall_title": "My Farmer Premium",
    "paywall_subtitle": "Podrži domaće poljoprivrednike i otključaj sve alate",
    "role_buyer_desc": "Vlasnik ljubimaca i kupac hrane. Pristup pijaci, narudžbama i premium funkcijama.",
    "role_selection": "Koja je vaša uloga?",
    "role_selection_hint": "Odaberite opciju koja vas najbolje opisuje",
    "full_name": "Ime i prezime",
    "farm_number": "Broj gazdinstva / certifikat",
    "reg_number": "Matični broj firme",
    "lang_uk": "Ukrajinski",
    "lang_ru": "Ruski",
    "community_title": "Ljepote sela",
    "product_added_to_cart": "{name} je u korpi!",
    "profile_farm_location_saved": "Lokacija gazdinstva sačuvana.",
    "profile_saved": "Profil uspješno sačuvan!",
    "community_post_success": "Slika uspješno objavljena!",
    "registration_pending_verification": "Nalog kreiran. Profil čeka provjeru administratora.",
    "pending_verification_banner": "Nalog čeka provjeru administratora. Mapa, chat i AI skener nedostupni su do odobrenja.",
    "shop_status": "Status",
    "scanner_problems_detected": "Mogući problemi detektovani",
}


def replace_farmer_outside_placeholders(text: str) -> str:
    parts = re.split(r"(\{[^}]+\})", text)
    for index, part in enumerate(parts):
        if part.startswith("{") and part.endswith("}"):
            continue
        for old, new in FARMER_REPLACEMENTS:
            part = part.replace(old, new)
        parts[index] = part
    return "".join(parts)


def build_bs_from_hr(hr: dict[str, str]) -> dict[str, str]:
    bs = {}
    for key, value in hr.items():
        if key in KEY_OVERRIDES:
            bs[key] = KEY_OVERRIDES[key]
        elif key == "cart_title":
            bs[key] = "Moja korpa"
        elif isinstance(value, str):
            text = value.replace("Košarica", "Moja korpa")
            text = text.replace("Osobno preuzimanje", "Lično preuzimanje")
            text = text.replace("osobno preuzimanje", "lično preuzimanje")
            text = text.replace("Osobnog preuzimanja", "Ličnog preuzimanja")
            text = text.replace("My Farmer Prodavnica", "Pijaca My Farmer")
            text = text.replace("tržnici", "pijaci")
            text = text.replace("tržnice", "pijace")
            text = text.replace("Tržnici", "Pijaci")
            bs[key] = replace_farmer_outside_placeholders(text)
        else:
            bs[key] = value
    return bs


def main() -> None:
    with open(EN_PATH, encoding="utf-8") as f:
        en = json.load(f)
    with open(HR_PATH, encoding="utf-8") as f:
        hr = json.load(f)

    if list(hr.keys()) != list(en.keys()):
        raise SystemExit("hr-HR key order/count mismatch vs en.json")

    ordered = {k: build_bs_from_hr(hr)[k] for k in en}

    for out_path in OUT_PATHS:
        with open(out_path, "w", encoding="utf-8", newline="\n") as f:
            json.dump(ordered, f, ensure_ascii=False, indent=2)
            f.write("\n")
        print(f"Wrote {len(ordered)} keys to {out_path.name}")


if __name__ == "__main__":
    main()
