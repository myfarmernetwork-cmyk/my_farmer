#!/usr/bin/env python3
"""Rebuild Serbian translation files from hr-HR base with Ekavian Latin Serbian."""
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
EN_PATH = ROOT / "assets" / "translations" / "en.json"
HR_PATH = ROOT / "assets" / "translations" / "hr-HR.json"
OUT_PATHS = [
    ROOT / "assets" / "translations" / "sr.json",
    ROOT / "assets" / "translations" / "sr-RS.json",
    ROOT / "assets" / "translations" / "sr-BA.json",
]

# Word-level Ekavian / Serbian adjustments applied to Croatian base text.
REPLACEMENTS = [
    ("Jeste li", "Da li ste"),
    ("jeste li", "da li ste"),
    ("uspješno", "uspešno"),
    ("uspjelo", "uspelo"),
    ("uspjela", "uspela"),
    ("uspjeh", "uspeh"),
    ("Osvježi", "Osveži"),
    ("osvježi", "osveži"),
    ("Provjeri", "Proveri"),
    ("provjeri", "proveri"),
    ("Provjerite", "Proverite"),
    ("provjerite", "proverite"),
    ("provjer", "prover"),
    ("Osobno", "Lično"),
    ("osobno", "lično"),
    ("Fotografiraj", "Fotografiši"),
    ("fotografiraj", "fotografiši"),
    ("Također", "Takođe"),
    ("također", "takođe"),
    ("mjesečno", "mesečno"),
    ("mjesečni", "mesečni"),
    ("mjesečna", "mesečna"),
    (" idućeg ", " narednog "),
    ("idući", "naredni"),
    ("Idući", "Naredni"),
    ("Cijena", "Cena"),
    ("cijena", "cena"),
    ("cijenu", "cenu"),
    ("cijeli", "celi"),
    ("cijelu", "celu"),
    ("Cjepiva", "Vakcine"),
    ("Liječenje", "Lečenje"),
    ("liječenje", "lečenje"),
    ("Povijest", "Istorija"),
    ("povijest", "istorija"),
    ("Ocijeni", "Oceni"),
    ("ocijenili", "ocenili"),
    ("ocjenu", "ocenu"),
    ("ocjeni", "oceni"),
    ("Vjerojatnost", "Verovatnoća"),
    ("vjerojatnost", "verovatnoća"),
    ("Procjena", "Procena"),
    ("procjena", "procena"),
    ("Promijeni", "Promeni"),
    ("promijeni", "promeni"),
    ("Sljedeća", "Sledeća"),
    ("Sljedeći", "Sledeći"),
    ("sljedeći", "sledeći"),
    ("Prethodna", "Prethodna"),
    ("registrirali", "registrovali"),
    ("Poslat ćemo", "Poslaćemo"),
    ("Poslat ", "Poslati "),
    ("poslano", "poslato"),
    ("Poslano", "Poslato"),
    ("spremanju", "čuvanju"),
    ("spremljenih", "sačuvanih"),
    ("spremljena", "sačuvana"),
    ("spreman", "sačuvan"),
    ("internetsku", "internet"),
    ("dozvolite", "dozvolite"),
    ("Omogućite", "Omogućite"),
    ("dosegnut", "dostignut"),
    ("Dosegnut", "Dostignut"),
    ("mjeseca", "meseca"),
    ("mjesec", "mesec"),
    ("prijevodom", "prevodom"),
    ("prijevod", "prevod"),
    ("Prijevod", "Prevod"),
    ("Tvrtke", "Firme"),
    ("tvrtke", "firme"),
    ("tržnici", "pijaci"),
    ("Hvala na ocjeni", "Hvala na oceni"),
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
    "cart_clear_confirm": "Da li ste sigurni da želite ukloniti sve proizvode?",
    "cart_order_all": "NARUČI SVE",
    "animals_delete_confirm": "Da li ste sigurni da želite obrisati ovaj karton?",
    "seller_delete_confirm": "Da li ste sigurni da želite obrisati ovaj proizvod?",
    "registration_success": "Registracija uspešna! Dobrodošli u My Farmer.",
    "profile_saved": "Profil uspešno sačuvan!",
    "community_post_success": "Slika uspešno objavljena!",
    "paywall_restore_failed": "Obnova nije uspela.",
    "chat_medical_error": "Slanje medicinskog kartona nije uspelo.",
    "role_hobby_farmer": "Hobi poljoprivrednik",
    "role_professional_farmer": "Profesionalni poljoprivrednik",
    "paywall_hobby_title": "Hobi poljoprivrednik Premium",
    "paywall_pro_title": "Profesionalni poljoprivrednik Premium",
    "shop_farmer_info": "Info o poljoprivredniku",
    "product_rate_farmer": "Oceni poljoprivrednika",
    "product_chat_farmer": "Piši poljoprivredniku",
    "product_already_reviewed": "Već ste ocenili ovog poljoprivrednika.",
    "product_no_paypal": "Poljoprivrednik nije postavio PayPal — plaćanje samo gotovinom.",
    "paywall_benefit_orders_desc": "Naručuj proizvode direktno od poljoprivrednika",
    "paywall_benefit_chat_desc": "Piši poljoprivrednicima u realnom vremenu",
    "role_buyer_info": "Besplatno: Pregled pijace, praćenje poljoprivrednika, 3 AI skeniranja u probnom periodu, osnovni profil.\n\nPremium (Kupac Premium): 15 AI skeniranja mesečno, digitalni karton životinja, automatski prevod chata, narudžbe i rezervacije.",
    "role_hobby_farmer_info": "Besplatno: Do 3 proizvoda u izlogu, osnovni profil gazdinstva, radno vreme i dostava.\n\nPremium (Hobi poljoprivrednik Premium): Do 4 proizvoda, 30 AI skeniranja/mes, sve Premium funkcije kupca, neograničen chat.",
    "role_professional_farmer_info": "Besplatno: Osnovni profil OPG-a, ograničen broj proizvoda u izlogu.\n\nPremium (Pro poljoprivrednik Premium): Neograničen izlog, tab Usluge mehanizacije, 60 skeniranja/mes, zone dostave i lično preuzimanje.",
    "search_no_results_radius": "Nema poljoprivrednika, firmi ili usluga unutar {km} km od Vas.",
    "cart_order_success_one": "Vaša narudžba je uspešno poslata. Poljoprivrednik će vas kontaktirati.",
    "cart_order_success_many": "Poslato je {count} narudžbi (po jednoj po poljoprivredniku). Poljoprivrednici će vas kontaktirati.",
    "cart_no_delivery_options": "Poljoprivrednik nije definisao opcije preuzimanja/dostave.",
    "product_min_order_required": "Minimalan iznos narudžbe kod ovog poljoprivrednika je {amount} {currency}.",
    "weekday_wed": "Sre",
    "profile_working_hours": "Radno vreme",
    "profile_pickup_schedule": "Raspored ličnog preuzimanja",
    "orders_tab_history": "Istorija",
    "animals_medical_history": "Istorija bolesti",
    "chat_select_all_records": "Pošalji celu istoriju bolesti",
    "animals_history_empty": "Još nema unosa u istoriji bolesti.",
    "animals_save_error": "Greška pri čuvanju",
    "profile_farm_location_saved": "Lokacija gazdinstva sačuvana.",
    "profile_photo_saved": "Profilna slika sačuvana!",
    "scanner_common_names": "Takođe poznato kao",
    "scanner_subtitle": "Fotografiši biljku i saznaj vrstu, korov ili bolest",
    "scanner_pick_photo": "Snimi ili odaberi fotografiju biljke",
    "paywall_benefit_orders": "Narudžbe",
    "paywall_simulate_purchase": "Simuliraj kupovinu",
    "paywall_restore": "Obnovi kupovinu",
    "paywall_sim_footer": "Aktivan simulacioni mod. Naplata preko Google Play-a nije aktivna.",
    "paywall_simulation_banner": "Test mod — kupovina je simulirana. Product ID-ovi su spremni za Google Play Console.",
    "paywall_prod_footer": "Pretplata se naplaćuje putem Google Play-a. Probni period podešava se u Play Console.",
    "paywall_buyer_price": "1,99 KM / 1,99 € mesečno",
    "paywall_hobby_price": "3,99 KM / 3,99 € mesečno",
    "paywall_pro_price": "5,99 KM / 5,99 € mesečno",
    "paywall_vet_price": "9,99 KM / 9,99 € mesečno",
    "paywall_pharmacy_price": "19,99 KM / 19,99 € mesečno",
    "paywall_buyer_features": "AI skener (15/mes), digitalni karton životinja, prevod chata",
    "chat_auto_translate": "Automatski prevod uključen",
    "chat_show_translated": "Prikaži prevod",
    "chat_medical_sent": "Medicinski karton poslat sa AI prevodom",
    "chat_send_medical_subtitle": "Karton će se automatski prevesti na jezik primaoca",
    "role_pharmacy": "Poljoprivredna apoteka",
    "role_buyer_desc": "Vlasnik ljubimaca i kupac hrane. Pristup pijaci, narudžbama i premium funkcijama.",
    "role_company": "Firma / preduzeće",
    "role_company_desc": "Firme za seme, đubriva, mašine, traktore i repromaterijal. Promotivni period 3 meseca nakon odobrenja.",
    "service_info_text": "Ovde unosite profesionalne poljoprivredne usluge i iznajmljivanje mehanizacije. Primeri: Duboko oranje (po dunumu/hektaru), Setva kukuruza (po dunumu), Berba i žetva, ili Iznajmljivanje traktora sa vozačem (po satu).",
    "add_product_is_service": "Ovo je usluga (oranje, setva, iznajmljivanje mehanizacije)",
    "community_title": "Lepote sela",
    "community_description_hint": "Npr. Prelep zalasak sunca iznad malinjaka...",
    "product_added_to_cart": "{name} je u korpi!",
    "product_review_thanks": "Hvala na oceni!",
    "product_send_review": "POŠALJI OCENU",
    "region_eu": "Evro zona (€)",
    "lang_uk": "Ukrajinski",
    "lang_ru": "Ruski",
    "scanner_limit_monthly": "Iskoristili ste mesečni limit skeniranja za Vaš paket kako bismo očuvali stabilnost sistema. Novi krediti biće dostupni prvog dana narednog meseca.",
    "scanner_limit_trial_daily": "Dostigli ste dnevni limit od 3 skeniranja u probnom periodu. Pokušajte ponovo sutra ili aktivirajte Premium.",
    "registration_pending_verification": "Nalog kreiran. Profil čeka proveru administratora.",
    "pending_verification_banner": "Nalog čeka admin proveru. Mapa, chat i AI skener nedostupni su do odobrenja.",
    "registration_email_in_use": "Email je već registrovan!",
    "forgot_password_hint": "Unesite email adresu sa kojom ste se registrovali. Poslaćemo vam link za ponovno postavljanje lozinke.",
    "forgot_password_sent": "Link za reset lozinke je poslat na vaš email.",
    "main_profile_load_error": "Greška pri učitavanju profila.",
    "orders_load_error": "Greška pri učitavanju narudžbi.",
    "chat_load_error": "Greška pri učitavanju poruka.",
    "cart_location_permission": "Dozvolite pristup lokaciji za proveru dostave.",
    "cart_gps_required_for_seller": "Omogućite GPS lokaciju kako bismo proverili dostavu kod {name}.",
    "profile_gps_error": "GPS greška: {error}",
    "profile_upload_error": "Greška pri otpremanju: {error}",
    "scanner_health_probability": "Verovatnoća zdravlja: {percent}%",
    "scanner_probability_label": "Verovatnoća: {percent}%",
    "scanner_treatment_label": "Lečenje / preporuka:",
    "scan_history_treatment": "Preporučeno lečenje",
    "animals_notes_hint": "Vakcine, alergije, terapije...",
    "animals_medical_notes": "Medicinske beleške",
    "animals_no_notes": "Još nema medicinskih beleški.",
    "animals_general_notes": "Opšte medicinske beleške",
    "animals_history_note": "Medicinska beleška",
    "chat_select_records": "Odaberite beleške za slanje",
    "chat_hint": "Upišite poruku...",
    "full_name": "Ime i prezime",
    "farm_number": "Broj farme / sertifikat",
    "reg_number": "Matični broj firme",
    "role_selection": "Koja je vaša uloga?",
    "role_selection_hint": "Odaberite opciju koja vas najbolje opisuje",
    "role_select_required": "Molimo odaberite ulogu!",
    "registration_fields_required": "Molimo popunite sva obavezna polja!",
    "product_limit_reached": "Dostignut limit proizvoda za Vaš paket.",
    "storefront_no_products": "Još nema proizvoda u ponudi.",
    "storefront_no_services": "Još nema usluga u ponudi.",
    "buyer_no_products": "Trenutno nema proizvoda u ponudi.",
    "orders_status_preparing": "U pripremi",
    "orders_change_status_title": "Promeni status",
    "orders_change_status_confirm": "Promeniti status na \"{status}\"?",
    "order_summary_label": "Narudžba",
    "seller_no_products_hint": "Dodajte prvi proizvod klikom na +",
    "add_product_category": "Kategorija",
    "add_product_production_type": "Tip proizvodnje",
    "prod_type_organic": "Organsko",
    "unit_kom_full": "komad (kom)",
    "shop_status": "Status",
    "scanner_plant_healthy": "Biljka izgleda zdravo",
    "scanner_problems_detected": "Mogući problemi detektovani",
    "scanner_health_unavailable": "Procena zdravlja nije dostupna za ovu sliku.",
    "nav_community": "Zajednica",
    "paywall_title": "My Farmer Premium",
    "paywall_subtitle": "Podrži domaće poljoprivrednike i otključaj sve alate",
}


def apply_replacements(text: str) -> str:
    for old, new in REPLACEMENTS:
        text = text.replace(old, new)
    return replace_farmer_outside_placeholders(text)


def replace_farmer_outside_placeholders(text: str) -> str:
    parts = re.split(r"(\{[^}]+\})", text)
    for index, part in enumerate(parts):
        if part.startswith("{") and part.endswith("}"):
            continue
        for old, new in FARMER_REPLACEMENTS:
            part = part.replace(old, new)
        parts[index] = part
    return "".join(parts)


def build_sr_from_hr(hr: dict[str, str]) -> dict[str, str]:
    sr = {}
    for key, value in hr.items():
        if key in KEY_OVERRIDES:
            sr[key] = KEY_OVERRIDES[key]
        elif isinstance(value, str):
            sr[key] = apply_replacements(value)
        else:
            sr[key] = value
    return sr


def main() -> None:
    with open(EN_PATH, encoding="utf-8") as f:
        en = json.load(f)
    with open(HR_PATH, encoding="utf-8") as f:
        hr = json.load(f)

    if list(hr.keys()) != list(en.keys()):
        missing = [k for k in en if k not in hr]
        extra = [k for k in hr if k not in en]
        raise SystemExit(f"hr-HR key mismatch. missing={missing[:5]} extra={extra[:5]}")

    ordered = {k: build_sr_from_hr(hr)[k] for k in en}

    for out_path in OUT_PATHS:
        with open(out_path, "w", encoding="utf-8", newline="\n") as f:
            json.dump(ordered, f, ensure_ascii=False, indent=2)
            f.write("\n")
        print(f"Wrote {len(ordered)} keys to {out_path.name}")


if __name__ == "__main__":
    main()
