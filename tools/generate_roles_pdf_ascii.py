#!/usr/bin/env python3
"""Generira citljiv PDF (ASCII) bez vanjskih fontova."""
from pathlib import Path

from fpdf import FPDF

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "docs" / "My_Farmer_Uloge_i_Pretplate.pdf"
ASSET_OUT = ROOT / "assets" / "docs" / "My_Farmer_Uloge_i_Pretplate.pdf"


def role_block(pdf, title, paid_label, free_items, paid_items, note=None):
    pdf.ln(2)
    pdf.set_font("Helvetica", "B", 11)
    pdf.cell(0, 7, title, new_x="LMARGIN", new_y="NEXT")
    pdf.set_font("Helvetica", "B", 9)
    pdf.cell(95, 5, "Besplatno", new_x="RIGHT", new_y="TOP")
    pdf.cell(5, 5, "")
    pdf.cell(0, 5, paid_label, new_x="LMARGIN", new_y="NEXT")
    pdf.set_font("Helvetica", "", 8)
    start_y = pdf.get_y()
    pdf.set_xy(10, start_y)
    for item in free_items:
        pdf.set_x(10)
        pdf.multi_cell(95, 4, f"- {item}")
    end_left = pdf.get_y()
    pdf.set_xy(110, start_y)
    for item in paid_items:
        pdf.set_x(110)
        pdf.multi_cell(90, 4, f"- {item}")
    end_right = pdf.get_y()
    pdf.set_y(max(end_left, end_right) + 2)
    if note:
        pdf.set_font("Helvetica", "I", 7)
        pdf.multi_cell(0, 3.5, note)
        pdf.set_font("Helvetica", "", 8)


def build_pdf() -> FPDF:
    pdf = FPDF()
    pdf.set_auto_page_break(auto=True, margin=15)
    pdf.add_page()
    pdf.set_font("Helvetica", "B", 18)
    pdf.cell(0, 10, "My Farmer", new_x="LMARGIN", new_y="NEXT")
    pdf.set_font("Helvetica", "B", 13)
    pdf.cell(0, 8, "Uloge i pretplate (besplatno vs. placeno)", new_x="LMARGIN", new_y="NEXT")
    pdf.ln(2)
    pdf.set_font("Helvetica", "", 9)
    pdf.multi_cell(
        0,
        4.5,
        "Cijene su u EUR (EU zona). Stvarna valuta ovisi o lokaciji (GPS/IP), ne o jeziku. "
        "Veterinarska i poslovna licenca zahtijevaju admin odobrenje nakon kupnje.",
    )
    pdf.ln(3)

    sections = [
        (
            "1. Kupac",
            "Kupac Premium (1,99 EUR/mj)",
            [
                "Pregled trzista i narudzbe",
                "Osnovni profil",
                "1 probno AI skeniranje",
                "Forum i zajednica",
            ],
            [
                "15 AI skeniranja / mj",
                "Do 10 zivotinja (digitalni karton)",
                "Rezervacija u dolasku + kartica",
                "Premium chat s prijevodom",
            ],
        ),
        (
            "2. Hobi Farmer",
            "Hobi Farmer Premium (3,99 EUR/mj)",
            [
                "Do 5 proizvoda u izlogu",
                "1 parcela (satelitsko ucrtavanje)",
                "1 probno AI skeniranje",
                "Profil gazdinstva, radno vrijeme",
            ],
            [
                "30 AI skeniranja / mj",
                "Do 5 parcela + satelitsko mjerenje",
                "NIRS/NDVI: 20 ucitavanja / mj",
                "Do 20 zivotinja, rezervacija u dolasku",
            ],
        ),
        (
            "3. Pro Farmer",
            "Pro Farmer Premium (9,99 EUR/mj)",
            [
                "Neogranicena prodaja u izlogu",
                "Tab Usluge (mehanizacija)",
                "1 parcela (osnovno ucrtavanje)",
                "1 probno AI skeniranje",
            ],
            [
                "60 AI skeniranja / mj",
                "Do 50 parcela + puni NIRS/NDVI",
                "NIRS/NDVI: 50 ucitavanja / mj",
                "Do 500 zivotinja, Agro-Alarmi",
            ],
        ),
        (
            "4. Veterinar",
            "Premium Veterinar (9,99 EUR/mj)",
            [
                "Profil, adresa, broj licence",
                "Forum i zajednica",
                "Do 5 proizvoda u izlogu",
                "Rucna pretraga u trazilici",
            ],
            [
                "50 AI skeniranja / mj",
                "Znacka Provjereni Veterinar",
                "Digitalni karton pacijenata",
                "Radar prve pomoci, neogranicen izlog",
            ],
            "Kupnja -> admin odobrenje -> aktivacija.",
        ),
        (
            "5. Firma",
            "Poslovna licenca (19,99 EUR/mj)",
            [
                "Registracija s brojem registra",
                "Do 5 proizvoda u izlogu",
                "CSV uvoz kataloga (Excel/ERP)",
                "3 AI skena / mj (3 mj promo)",
            ],
            [
                "100 AI skeniranja / mj",
                "Neogranicen katalog i izlog",
                "Boost na vrhu trzista",
                "AI preporuke, B2B analitika",
            ],
            "Bez ERP API-ja. CSV uvoz. Admin odobrenje nakon kupnje.",
        ),
    ]

    for section in sections:
        note = section[4] if len(section) > 4 else None
        role_block(pdf, section[0], section[1], section[2], section[3], note)

    pdf.add_page()
    pdf.set_font("Helvetica", "B", 12)
    pdf.cell(0, 8, "Sazetka cijena (EUR)", new_x="LMARGIN", new_y="NEXT")
    pdf.ln(2)
    pdf.set_font("Helvetica", "B", 9)
    for row in [
        ("Uloga", "Paket", "Cijena"),
        ("Kupac", "Premium", "1,99 EUR/mj"),
        ("Hobi Farmer", "Premium", "3,99 EUR/mj"),
        ("Pro Farmer", "Premium Pro", "9,99 EUR/mj"),
        ("Veterinar", "Licenca", "9,99 EUR/mj"),
        ("Firma", "Poslovna licenca", "19,99 EUR/mj"),
    ]:
        pdf.cell(60, 6, row[0], border=1)
        pdf.cell(60, 6, row[1], border=1)
        pdf.cell(40, 6, row[2], border=1)
        pdf.ln()
    return pdf


def main():
    pdf = build_pdf()
    OUT.parent.mkdir(parents=True, exist_ok=True)
    ASSET_OUT.parent.mkdir(parents=True, exist_ok=True)
    pdf.output(str(OUT))
    pdf.output(str(ASSET_OUT))
    print(f"OK: {OUT} ({OUT.stat().st_size} B)")
    print(f"OK: {ASSET_OUT} ({ASSET_OUT.stat().st_size} B)")


if __name__ == "__main__":
    main()
