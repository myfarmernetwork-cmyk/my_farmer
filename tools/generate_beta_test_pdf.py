#!/usr/bin/env python3
"""Generira citljiv PDF uputa za beta testere (Arial TTF)."""
from __future__ import annotations

import shutil
from pathlib import Path

from fpdf import FPDF

ROOT = Path(__file__).resolve().parents[1]
FONTS = ROOT / "assets" / "fonts"
OUT = ROOT / "docs" / "My_Farmer_Beta_Test_Upute.pdf"
ASSET_OUT = ROOT / "assets" / "docs" / "My_Farmer_Beta_Test_Upute.pdf"
DESKTOP_OUT = Path.home() / "Desktop" / "My_Farmer_Beta_Test_Upute.pdf"

FONT = "ArialHR"


def ensure_fonts() -> tuple[Path, Path]:
    FONTS.mkdir(parents=True, exist_ok=True)
    regular = FONTS / "Arial.ttf"
    bold = FONTS / "Arial-Bold.ttf"

    if not regular.exists():
        shutil.copy2(r"C:\Windows\Fonts\arial.ttf", regular)
    if not bold.exists():
        shutil.copy2(r"C:\Windows\Fonts\arialbd.ttf", bold)

    return regular, bold


def setup_pdf() -> FPDF:
    regular, bold = ensure_fonts()
    pdf = FPDF()
    pdf.set_auto_page_break(auto=True, margin=18)
    pdf.add_page()
    pdf.add_font(FONT, "", str(regular))
    pdf.add_font(FONT, "B", str(bold))
    return pdf


def step_header(pdf: FPDF, title: str) -> None:
    pdf.ln(3)
    pdf.set_font(FONT, "B", 12)
    pdf.set_fill_color(240, 248, 240)
    pdf.cell(0, 9, title, new_x="LMARGIN", new_y="NEXT", fill=True)
    pdf.ln(1)


def bullet(pdf: FPDF, text: str, bold_prefix: str | None = None) -> None:
    pdf.set_x(pdf.l_margin + 4)
    if bold_prefix:
        pdf.set_font(FONT, "B", 10)
        pdf.write(5, f"- {bold_prefix} ")
        pdf.set_font(FONT, "", 10)
        pdf.multi_cell(0, 5, text)
    else:
        pdf.set_font(FONT, "", 10)
        pdf.multi_cell(0, 5, f"- {text}")


def build_pdf() -> FPDF:
    pdf = setup_pdf()

    pdf.set_font(FONT, "B", 18)
    pdf.set_text_color(27, 94, 32)
    pdf.cell(0, 10, "My Farmer", new_x="LMARGIN", new_y="NEXT")
    pdf.set_text_color(0, 0, 0)
    pdf.set_font(FONT, "B", 13)
    pdf.cell(0, 8, "Upute za beta testere (Google Play)", new_x="LMARGIN", new_y="NEXT")
    pdf.ln(2)

    pdf.set_fill_color(255, 248, 225)
    pdf.set_font(FONT, "", 9)
    pdf.multi_cell(
        0,
        5,
        "Hvala vam što pomažete u testiranju aplikacije My Farmer prije službenog "
        "izlaska na tržište. Molimo vas da slijedite korake ispod — Google prati "
        "aktivnost testera najmanje 14 dana prije odobrenja produkcijskog izdanja.",
        fill=True,
    )
    pdf.ln(3)

    step_header(pdf, "1. Korak: Pristupanje zatvorenoj Google grupi (uskoro)")
    pdf.set_font(FONT, "", 10)
    pdf.multi_cell(
        0,
        5,
        "Google dozvoljava preuzimanje aplikacije isključivo članovima naše "
        "zatvorene grupe.",
    )
    pdf.ln(1)
    bullet(
        pdf,
        "Čim pokrenem testiranje, poslaću vam službenu pozivnicu sa linkom "
        "za pristup našoj Google grupi.",
    )
    bullet(
        pdf,
        "Grupi obavezno morate pristupiti sa onom Gmail adresom koju koristite "
        "kao primarnu na svom Android mobilnom telefonu.",
        bold_prefix="Važno:",
    )

    step_header(pdf, "2. Korak: Preuzimanje aplikacije sa Google Play-a")
    pdf.set_font(FONT, "", 10)
    pdf.multi_cell(
        0,
        5,
        "Nakon što se učlanite u grupu, sistem će prepoznati vaš e-mail i omogućiti "
        "vam preuzimanje:",
    )
    pdf.ln(1)
    bullet(
        pdf,
        'Tada ću vam poslati poseban link za testiranje gdje treba da kliknete '
        'na dugme "Postani tester" (Become a tester).',
    )
    bullet(
        pdf,
        "Nakon toga, sistem će vas preusmjeriti na Google Play prodavnicu gdje "
        "ćete instalirati aplikaciju My Farmer kao i svaku drugu aplikaciju.",
    )

    step_header(pdf, "3. Korak: Pravila testiranja (obavezno za Google provjeru)")
    pdf.set_font(FONT, "", 10)
    pdf.multi_cell(
        0,
        5,
        "Google ima stroga pravila i pratiće aktivnost kako bi nam odobrio "
        "izlazak na tržište. Kada instalirate aplikaciju, molim vas da se "
        "pridržavate sljedećeg:",
    )
    pdf.ln(1)
    bullet(
        pdf,
        "Aplikacija mora ostati instalirana na vašem telefonu najmanje 14 dana zaredom.",
        bold_prefix="Ne brišite aplikaciju:",
    )
    bullet(
        pdf,
        "Otvorite aplikaciju barem jednom dnevno, isprobajte funkcije, skeniranje "
        "i pregledajte vremensku prognozu.",
        bold_prefix="Svakodnevno korištenje:",
    )
    bullet(
        pdf,
        "Ako aplikacija blokira ili uočite bilo kakav problem, napravite snimak "
        "ekrana (screenshot) i javite mi direktno na WhatsApp 01771986745 ili na "
        "e-mail myfarmer.network@gmail.com",
        bold_prefix="Prijava grešaka:",
    )

    pdf.ln(5)
    pdf.set_fill_color(232, 245, 233)
    pdf.set_font(FONT, "B", 11)
    pdf.cell(0, 7, "Kontakt za testere", new_x="LMARGIN", new_y="NEXT", fill=True)
    pdf.ln(2)
    pdf.set_font(FONT, "", 10)
    pdf.set_x(pdf.l_margin)
    pdf.multi_cell(
        0,
        5,
        "WhatsApp: 01771986745\nE-mail: myfarmer.network@gmail.com",
    )

    pdf.ln(4)
    pdf.set_font(FONT, "", 8)
    pdf.set_text_color(100, 100, 100)
    pdf.multi_cell(
        0,
        4,
        "My Farmer — zatvoreno testiranje (Closed testing). "
        "Dokument za distribuciju beta testerima.",
    )
    return pdf


def main() -> None:
    pdf = build_pdf()
    OUT.parent.mkdir(parents=True, exist_ok=True)
    ASSET_OUT.parent.mkdir(parents=True, exist_ok=True)

    pdf.output(str(OUT))
    pdf.output(str(ASSET_OUT))

    try:
        pdf.output(str(DESKTOP_OUT))
        print(f"Desktop: {DESKTOP_OUT} ({DESKTOP_OUT.stat().st_size} B)")
    except OSError as error:
        print(f"Desktop copy skipped: {error}")

    print(f"OK: {OUT} ({OUT.stat().st_size} B)")
    print(f"OK: {ASSET_OUT} ({ASSET_OUT.stat().st_size} B)")


if __name__ == "__main__":
    main()
