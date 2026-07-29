import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../config/subscription_limits.dart';
import '../models/subscription_tier.dart';
import 'company_catalog_pdf_fonts.dart';

/// PDF vodič: sve uloge — besplatno vs. plaćena pretplata.
class RolesSubscriptionPdfGuide {
  RolesSubscriptionPdfGuide._();

  static Future<Uint8List> build({
    required PdfPageFormat format,
    String languageCode = 'hr',
  }) async {
    final fonts = await CompanyCatalogPdfFonts.load(languageCode);

    pw.TextStyle heading({double size = 16, PdfColor? color}) => fonts.style(
          font: fonts.bold,
          fontSize: size,
          color: color ?? PdfColors.green900,
        );

    pw.TextStyle body({double size = 10.5, PdfColor? color}) => fonts.style(
          font: fonts.regular,
          fontSize: size,
          color: color,
        );

    pw.Widget bullet(String text) => pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 4, left: 8),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('• ', style: body()),
              pw.Expanded(child: pw.Text(text, style: body())),
            ],
          ),
        );

    pw.Widget roleSection({
      required String title,
      required String paidName,
      required String paidPrice,
      required List<String> freeItems,
      required List<String> paidItems,
      String? note,
    }) {
      return pw.Container(
        margin: const pw.EdgeInsets.only(bottom: 14),
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.green300),
          borderRadius: pw.BorderRadius.circular(8),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(title, style: heading(size: 14)),
            pw.SizedBox(height: 8),
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Besplatno', style: body().copyWith(font: fonts.bold)),
                      pw.SizedBox(height: 4),
                      for (final item in freeItems) bullet(item),
                    ],
                  ),
                ),
                pw.SizedBox(width: 12),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        '$paidName ($paidPrice)',
                        style: body().copyWith(font: fonts.bold),
                      ),
                      pw.SizedBox(height: 4),
                      for (final item in paidItems) bullet(item),
                    ],
                  ),
                ),
              ],
            ),
            if (note != null) ...[
              pw.SizedBox(height: 8),
              pw.Text(
                note,
                style: body(size: 9.5).copyWith(color: PdfColors.grey700),
              ),
            ],
          ],
        ),
      );
    }

    final buyerPrice =
        '${SubscriptionLimits.monthlyPriceEur(SubscriptionTier.buyerPremium).toStringAsFixed(2).replaceAll('.', ',')} €/mj';
    final hobbyPrice =
        '${SubscriptionLimits.monthlyPriceEur(SubscriptionTier.hobbyFarmerPremium).toStringAsFixed(2).replaceAll('.', ',')} €/mj';
    final proPrice =
        '${SubscriptionLimits.monthlyPriceEur(SubscriptionTier.professionalFarmerPremium).toStringAsFixed(2).replaceAll('.', ',')} €/mj';
    final vetPrice =
        '${SubscriptionLimits.monthlyPriceEur(SubscriptionTier.veterinarianLicense).toStringAsFixed(2).replaceAll('.', ',')} €/mj';
    final companyPrice =
        '${SubscriptionLimits.monthlyPriceEur(SubscriptionTier.pharmacyLicense).toStringAsFixed(2).replaceAll('.', ',')} €/mj';

    final doc = pw.Document(
      title: 'My Farmer — Uloge i pretplate',
      author: 'My Farmer',
    );

    doc.addPage(
      pw.MultiPage(
        pageFormat: format,
        margin: const pw.EdgeInsets.all(36),
        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'My Farmer · str. ${context.pageNumber}/${context.pagesCount}',
            style: body(size: 9, color: PdfColors.grey600),
          ),
        ),
        build: (context) => [
          pw.Text('My Farmer', style: heading(size: 24)),
          pw.SizedBox(height: 4),
          pw.Text(
            'Pregled uloga — besplatno i plaćene pretplate',
            style: heading(size: 15, color: PdfColors.grey800),
          ),
          pw.SizedBox(height: 10),
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: PdfColors.amber50,
              border: pw.Border.all(color: PdfColors.amber300),
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Text(
              'Osnovne cijene su u EUR. Stvarna cijena i valuta prikaza određuju se prema '
              'lokaciji uređaja (GPS/IP), ne prema jeziku sučelja. Veterinarska i poslovna '
              'licenca zahtijevaju admin odobrenje nakon kupnje.',
              style: body(size: 10),
            ),
          ),
          pw.SizedBox(height: 14),
          roleSection(
            title: '1. Kupac',
            paidName: 'Kupac Premium',
            paidPrice: buyerPrice,
            freeItems: [
              'Pregled tržnice i narudžbe proizvoda',
              'Osnovni profil',
              '${SubscriptionLimits.introAiScansTotal} probno AI skeniranje (ukupno)',
              'Forum i zajednica',
            ],
            paidItems: [
              '${SubscriptionLimits.buyerPremiumMonthlyScans} AI skeniranja mjesečno',
              'Do ${SubscriptionLimits.buyerPremiumMaxAnimals} životinja u digitalnom kartonu',
              'Rezervacija robe u dolasku i plaćanje karticom',
              'Premium chat (ukl. automatski prijevod)',
            ],
          ),
          roleSection(
            title: '2. Hobi Farmer',
            paidName: 'Hobi Farmer Premium',
            paidPrice: hobbyPrice,
            freeItems: [
              'Prodaja do ${SubscriptionLimits.hobbyMaxActiveProducts} proizvoda u izlogu',
              'Osnovno satelitsko ucrtavanje — ${SubscriptionLimits.farmerFreeMaxParcels} parcela',
              '${SubscriptionLimits.introAiScansTotal} probno AI skeniranje (ukupno)',
              'Profil gazdinstva, radno vrijeme, dostava/preuzimanje',
              'Narudžbe s tržnice (kao kupac)',
            ],
            paidItems: [
              '${SubscriptionLimits.hobbyPremiumMonthlyScans} AI skeniranja mjesečno',
              'Satelitsko mjerenje parcela — do ${SubscriptionLimits.hobbyPremiumMaxParcels} parcela',
              'NIRS/NDVI nadzor — ${SubscriptionLimits.hobbyPremiumNirsMonthlyLoads} učitavanja/mj',
              'Do ${SubscriptionLimits.hobbyPremiumMaxAnimals} životinja u kartonu',
              'Do ${SubscriptionLimits.hobbyMaxActiveProducts} proizvoda u izlogu',
              'Rezervacija u dolasku + sve Premium funkcije kupca',
            ],
          ),
          roleSection(
            title: '3. Profesionalni Farmer (Pro)',
            paidName: 'Pro Farmer Premium',
            paidPrice: proPrice,
            freeItems: [
              'Neograničena prodaja proizvoda u izlogu',
              'Tab Usluge (mehanizacija)',
              'Osnovno satelitsko ucrtavanje — ${SubscriptionLimits.farmerFreeMaxParcels} parcela',
              '${SubscriptionLimits.introAiScansTotal} probno AI skeniranje (ukupno)',
              'Profil OPG-a, zone dostave, osobno preuzimanje',
            ],
            paidItems: [
              '${SubscriptionLimits.proPremiumMonthlyScans} AI skeniranja mjesečno',
              'Do ${SubscriptionLimits.proPremiumMaxParcels} parcela s punim NIRS/NDVI nadzorom',
              'NIRS/NDVI — ${SubscriptionLimits.proPremiumNirsMonthlyLoads} učitavanja/mj',
              'Do ${SubscriptionLimits.proPremiumMaxAnimals} životinja s dokumentima',
              'Agro-Alarmi (zdravlje usjeva, vrijeme)',
              'Neograničena prodaja (ostaje besplatna)',
            ],
          ),
          roleSection(
            title: '4. Veterinar',
            paidName: 'Premium Veterinar',
            paidPrice: vetPrice,
            freeItems: [
              'Profil, adresa, broj licence',
              'Forum i zajednica',
              'Do ${SubscriptionLimits.vetFreeMaxActiveProducts} proizvoda/usluga u izlogu',
              '${SubscriptionLimits.introAiScansTotal} probno AI skeniranje (ukupno)',
              'Pronalazak ručnim upisivanjem u tražilicu',
            ],
            paidItems: [
              '${SubscriptionLimits.monthlyScansForTier(SubscriptionTier.veterinarianLicense)} AI skeniranja mjesečno',
              'Značka Provjereni Veterinar',
              'Digitalni prijem kartona pacijenata',
              'Do ${SubscriptionLimits.vetPremiumMaxPrivatePets} kućnih ljubimaca u evidenciji',
              'Automatsko pojavljivanje u radaru prve pomoći',
              'Neograničen izlog proizvoda/usluga',
              'Povezivanje s apotekama / repromaterijalom',
            ],
            note: 'Premium licenca: kupnja → admin odobrenje → aktivacija.',
          ),
          roleSection(
            title: '5. Firma (Poduzeće / Dobavljač)',
            paidName: 'Poslovna licenca',
            paidPrice: companyPrice,
            freeItems: [
              'Registracija s brojem registra firme',
              'Do ${SubscriptionLimits.companyFreeMaxActiveProducts} proizvoda u izlogu',
              'CSV uvoz kataloga (Excel/ERP export)',
              'Promotivno: 3 AI skeniranja/mj (3 mjeseca)',
              'Profil firme na tržnici',
            ],
            paidItems: [
              '${SubscriptionLimits.monthlyScansForTier(SubscriptionTier.pharmacyLicense)} AI skeniranja mjesečno',
              'Neograničen broj artikala u katalogu i izlogu',
              'Isticanje (boost) na vrhu tržnice',
              'Sponzorirane AI preporuke ispod skenera',
              'B2B tržišna analitika',
              'Zlatna poslovna značka (verificirani dobavljač)',
            ],
            note: 'Nema ERP integracije — proizvodi se uvode CSV datotekom. '
                'Poslovna licenca: kupnja → admin odobrenje → aktivacija.',
          ),
          pw.SizedBox(height: 8),
          pw.Text('Sažetka cijena (EUR, EU zona)', style: heading(size: 13)),
          pw.SizedBox(height: 6),
          pw.TableHelper.fromTextArray(
            headers: ['Uloga', 'Paket', 'Cijena (EUR/mj)'],
            headerStyle: body().copyWith(font: fonts.bold, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.green800),
            cellStyle: body(size: 10),
            cellAlignments: {
              0: pw.Alignment.centerLeft,
              1: pw.Alignment.centerLeft,
              2: pw.Alignment.center,
            },
            data: [
              ['Kupac', 'Premium', buyerPrice],
              ['Hobi Farmer', 'Premium', hobbyPrice],
              ['Pro Farmer', 'Premium Pro', proPrice],
              ['Veterinar', 'Licenca', vetPrice],
              ['Firma', 'Poslovna licenca', companyPrice],
            ],
          ),
          pw.SizedBox(height: 12),
          pw.Text(
            'Dokument generiran iz službenog poslovnog modela aplikacije My Farmer '
            '(subscription_limits.dart). Za najnovije informacije provjerite paywall u aplikaciji.',
            style: body(size: 9, color: PdfColors.grey600),
          ),
        ],
      ),
    );

    return doc.save();
  }
}
