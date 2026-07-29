#!/usr/bin/env python3
"""Generira PDF uloga s ugrađenim DejaVu fontom (hrvatski znakovi)."""
from __future__ import annotations

import urllib.request
from pathlib import Path

from fpdf import FPDF

ROOT = Path(__file__).resolve().parents[1]
FONTS = ROOT / "assets" / "fonts"
OUT = ROOT / "docs" / "My_Farmer_Uloge_i_Pretplate.pdf"

DEJAVU_REGULAR = "https://cdn.jsdelivr.net/gh/dejavu-fonts/dejavu-fonts@version_2_37/ttf/DejaVuSans.ttf"
DEJAVU_BOLD = "https://cdn.jsdelivr.net/gh/dejavu-fonts/dejavu-fonts@version_2_37/ttf/DejaVuSans-Bold.ttf"


def ensure_fonts() -> tuple[Path, Path]:
    FONTS.mkdir(parents=True, exist_ok=True)
    regular = FONTS / "DejaVuSans.ttf"
    bold = FONTS / "DejaVuSans-Bold.ttf"
    if not regular.exists():
        print("Preuzimam DejaVuSans.ttf...")
        urllib.request.urlretrieve(DEJAVU_REGULAR, regular)
    if not bold.exists():
        print("Preuzimam DejaVuSans-Bold.ttf...")
        urllib.request.urlretrieve(DEJAVU_BOLD, bold)
    return regular, bold


def bullet(pdf: FPDF, text: str) -> None:
    pdf.set_x(pdf.l_margin + 4)
    pdf.multi_cell(0, 5, f"- {text}")


def role_block(
    pdf: FPDF,
    title: str,
    paid_label: str,
    free_items: list[str],
    paid_items: list[str],
    note: str | None = None,
) -> None:
    pdf.ln(2)
    pdf.set_font("DejaVu", "B", 12)
    pdf.set_fill_color(240, 248, 240)
    pdf.cell(0, 8, title, new_x="LMARGIN", new_y="NEXT", fill=True)
    pdf.ln(2)

    y0 = pdf.get_y()
    col_w = (pdf.w - pdf.l_margin - pdf.r_margin) / 2 - 4

    pdf.set_font("DejaVu", "B", 10)
    pdf.set_x(pdf.l_margin)
    pdf.cell(col_w, 6, "Besplatno", new_x="RIGHT", new_y="TOP")
    pdf.cell(8, 6, "")
    pdf.cell(col_w, 6, paid_label, new_x="LMARGIN", new_y="NEXT")

    pdf.set_font("DejaVu", "", 9)
    left_y = pdf.get_y()
    pdf.set_x(pdf.l_margin)
    for item in free_items:
        pdf.set_x(pdf.l_margin)
        pdf.multi_cell(col_w, 4.5, f"- {item}")

    right_y = left_y
    pdf.set_y(left_y)
    right_x = pdf.l_margin + col_w + 8
    for item in paid_items:
        pdf.set_xy(right_x, right_y)
        pdf.multi_cell(col_w, 4.5, f"- {item}")
        right_y = pdf.get_y()

    pdf.set_y(max(pdf.get_y(), right_y) + 2)
    if note:
        pdf.set_font("DejaVu", "", 8)
        pdf.set_text_color(80, 80, 80)
        pdf.multi_cell(0, 4, note)
        pdf.set_text_color(0, 0, 0)


def main() -> None:
    regular, bold = ensure_fonts()
    OUT.parent.mkdir(parents=True, exist_ok=True)

    pdf = FPDF()
    pdf.set_auto_page_break(auto=True, margin=18)
    pdf.add_page()
    pdf.add_font("DejaVu", "", str(regular))
    pdf.add_font("DejaVu", "B", str(bold))

    pdf.set_font("DejaVu", "B", 20)
    pdf.set_text_color(27, 94, 32)
    pdf.cell(0, 12, "My Farmer", new_x="LMARGIN", new_y="NEXT")
    pdf.set_font("DejaVu", "B", 14)
    pdf.set_text_color(0, 0, 0)
    pdf.cell(0, 8, "Uloge i pretplate - besplatno vs. placeno", new_x="LMARGIN", new_y="NEXT")
    pdf.ln(3)

    pdf.set_fill_color(255, 248, 225)
    pdf.set_font("DejaVu", "", 9)
    pdf.multi_cell(
        0,
        5,
        "Osnovne cijene su u EUR. Stvarna cijena i valuta odreduju se prema lokaciji "
        "(GPS/IP), ne prema jeziku sucelja. Veterinarska i poslovna licenca zahtijevaju "
        "admin odobrenje nakon kupnje.",
        fill=True,
    )
    pdf.ln(4)

    role_block(
        pdf,
        "1. Kupac",
        "Kupac Premium (1,99 EUR/mj)",
        [
            "Pregled trzista i narudzbe proizvoda",
            "Osnovni profil",
            "1 probno AI skeniranje (ukupno)",
            "Forum i zajednica",
        ],
        [
            "15 AI skeniranja mjesečno",
            "Do 10 zivotinja u digitalnom kartonu",
            "Rezervacija robe u dolasku i placanje karticom",
            "Premium chat (uklj. automatski prijevod)",
        ],
    )

    role_block(
        pdf,
        "2. Hobi Farmer",
        "Hobi Farmer Premium (3,99 EUR/mj)",
        [
            "Prodaja do 5 proizvoda u izlogu",
            "Osnovno satelitsko ucrtavanje - 1 parcela",
            "1 probno AI skeniranje (ukupno)",
            "Profil gazdinstva, radno vrijeme, dostava",
            "Narudzbe s trzista (kao kupac)",
        ],
        [
            "30 AI skeniranja mjesečno",
            "Satelitsko mjerenje - do 5 parcela",
            "NIRS/NDVI nadzor - 20 ucitavanja/mj",
            "Do 20 zivotinja u kartonu",
            "Do 5 proizvoda u izlogu",
            "Rezervacija u dolasku + Premium kupca",
        ],
    )

    role_block(
        pdf,
        "3. Profesionalni Farmer (Pro)",
        "Pro Farmer Premium (9,99 EUR/mj)",
        [
            "Neogranicena prodaja proizvoda u izlogu",
            "Tab Usluge (mehanizacija)",
            "Osnovno satelitsko ucrtavanje - 1 parcela",
            "1 probno AI skeniranje (ukupno)",
            "Profil OPG-a, zone dostave",
        ],
        [
            "60 AI skeniranja mjesečno",
            "Do 50 parcela s punim NIRS/NDVI nadzorom",
            "NIRS/NDVI - 50 ucitavanja/mj",
            "Do 500 zivotinja s dokumentima",
            "Agro-Alarmi (zdravlje usjeva, vrijeme)",
            "Neogranicena prodaja (ostaje besplatna)",
        ],
    )

    role_block(
        pdf,
        "4. Veterinar",
        "Premium Veterinar (9,99 EUR/mj)",
        [
            "Profil, adresa, broj licence",
            "Forum i zajednica",
            "Do 5 proizvoda/usluga u izlogu",
            "1 probno AI skeniranje (ukupno)",
            "Pronalazak rucnim upisivanjem u trazilicu",
        ],
        [
            "50 AI skeniranja mjesečno",
            "Znacka Provjereni Veterinar",
            "Digitalni prijem kartona pacijenata",
            "Do 10 kucnih ljubimaca u evidenciji",
            "Automatsko pojavljivanje u radaru prve pomoci",
            "Neogranicen izlog proizvoda/usluga",
        ],
        note="Premium licenca: kupnja -> admin odobrenje -> aktivacija.",
    )

    role_block(
        pdf,
        "5. Firma (Poduzece / Dobavljac)",
        "Poslovna licenca (19,99 EUR/mj)",
        [
            "Registracija s brojem registra firme",
            "Do 5 proizvoda u izlogu",
            "CSV uvoz kataloga (Excel/ERP export)",
            "Promotivno: 3 AI skeniranja/mj (3 mjeseca)",
            "Profil firme na trzistu",
        ],
        [
            "100 AI skeniranja mjesečno",
            "Neogranicen broj artikala u katalogu",
            "Isticanje (boost) na vrhu trzista",
            "Sponzorirane AI preporuke ispod skenera",
            "B2B trzisna analitika",
            "Zlatna poslovna znacka",
        ],
        note="Nema ERP integracije - proizvodi se uvode CSV datotekom. "
        "Licenca: kupnja -> admin odobrenje -> aktivacija.",
    )

    pdf.add_page()
    pdf.set_font("DejaVu", "B", 13)
    pdf.cell(0, 8, "Sažetka cijena (EUR, EU zona)", new_x="LMARGIN", new_y="NEXT")
    pdf.ln(2)

    headers = ["Uloga", "Paket", "Cijena"]
    rows = [
        ["Kupac", "Premium", "1,99 EUR/mj"],
        ["Hobi Farmer", "Premium", "3,99 EUR/mj"],
        ["Pro Farmer", "Premium Pro", "9,99 EUR/mj"],
        ["Veterinar", "Licenca", "9,99 EUR/mj"],
        ["Firma", "Poslovna licenca", "19,99 EUR/mj"],
    ]
    col_widths = [55, 55, 40]
    pdf.set_font("DejaVu", "B", 9)
    pdf.set_fill_color(27, 94, 32)
    pdf.set_text_color(255, 255, 255)
    for h, w in zip(headers, col_widths):
        pdf.cell(w, 7, h, border=1, fill=True)
    pdf.ln()
    pdf.set_text_color(0, 0, 0)
    pdf.set_font("DejaVu", "", 9)
    for row in rows:
        for cell, w in zip(row, col_widths):
            pdf.cell(w, 7, cell, border=1)
        pdf.ln()

    pdf.ln(6)
    pdf.set_font("DejaVu", "", 8)
    pdf.set_text_color(100, 100, 100)
    pdf.multi_cell(
        0,
        4,
        "Dokument: My Farmer poslovni model (subscription_limits.dart). "
        "Za najnovije informacije provjerite paywall u aplikaciji.",
    )

    pdf.output(str(OUT))
    print(f"Saved: {OUT} ({OUT.stat().st_size} bytes)")


if __name__ == "__main__":
    main()
