import 'package:flutter/material.dart';

/// Topla smeđa paleta — zamjena za narandžastu akcent boju (potvrde, staklene kartice).
abstract final class AgroAccentColors {
  static const glassTop = Color(0xFFF7F0E8);
  static const glassMid = Color(0xFFEDE0D0);
  static const glassBottom = Color(0xFFE2D2BE);

  static const borderLight = Color(0xFFF5EDE3);
  static const border = Color(0xFFD4C4B0);
  static const borderShadow = Color(0x338D6E63);

  static const textDark = Color(0xFF4E342E);
  static const textMedium = Color(0xFF5D4037);

  static const accent = Color(0xFF8D6E63);
  static const accentDark = Color(0xFF6D4C41);
  static const accentDeep = Color(0xFF5D4037);

  static const infoBackground = Color(0xFFF5EDE3);
  static const infoBorder = Color(0xFFD7C4B0);
  static const infoIcon = Color(0xFF6D4C41);
  static const infoText = Color(0xFF4E342E);

  static const snackBarBackground = Color(0xFF6D4C41);

  /// OneSoil-style smaragdna — blago posvjetljena (build 80 bio previše tamno).
  static const headerGreen = Color(0xFF0A6B4A);
  static const headerGreenDark = Color(0xFF06442A);
  /// Šumska zelena (Menta-Šumska Staklena) — filter chipovi, aktivni tab.
  static const forestGreen = Color(0xFF4E876E);
  /// Mint akcent — zastarjelo; preferiraj [forestGreen].
  static const headerGreenActive = forestGreen;

  /// Build 70 Material green — jedinstvena Marktplatz pozadina (#388E3C).
  static const marketplaceUnifiedGreen = Color(0xFF388E3C);
  static const marketplaceUnifiedGreenTop = marketplaceUnifiedGreen;
  static const marketplaceUnifiedGreenBottom = marketplaceUnifiedGreen;
  /// Tamniji chipovi / search na unified pozadini (Colors.green[800]).
  static const marketplaceChipGreen = Color(0xFF2E7D32);

  /// Ravna build 70 zelena — cijeli Marktplatz.
  static const marketplaceUnifiedBackgroundGradient = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [marketplaceUnifiedGreen, marketplaceUnifiedGreen],
      );

  /// Bez top highlighta — flat build 70.
  static const marketplaceUnifiedTopHighlight = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0x00000000), Color(0x00000000)],
      );

  /// Staklo filter zone — rgba(255,255,255,0.15) prema UI referenci.
  static const filterZoneGlassFill = Color(0x26FFFFFF);

  /// Zaobljeni rubovi tržišta — search, kategorije, kartice proizvoda.
  static const marketplaceCornerRadius = 16.0;
  /// Pilula — filter chipovi, search, vet red (radius 20).
  static const marketplacePillRadius = 20.0;
  static const marketplacePillHeight = 36.0;
  /// Search + vet pilula — ista visina.
  static const marketplaceWidePillHeight = 40.0;

  /// Satin staklo donje navigacije — dovoljno prozirno da blur prođe.
  static const navGlassBackground = Color(0xBFF3EDE6);
  static const navInactive = Color(0xFF616161);

  /// Svijetlozelena cijena na tamnom overlayu kartice.
  static const priceGreen = Color(0xFF81C784);
  static const cardTextLight = Color(0xFFF5F5F0);

  /// Medno staklo — aktivni tip „Alle“ u filter traci.
  static const honeyGlassTop = Color(0xFFC9A06A);
  static const honeyGlassBottom = Color(0xFF9A7348);
  static const honeyGlassHighlight = Color(0xFFE8D4B8);

  static LinearGradient get headerGradient => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          headerGreen.withValues(alpha: 0.98),
          headerGreenDark.withValues(alpha: 0.99),
        ],
      );

  /// Pozadina cijelog Marktplatza (header → grid proizvoda).
  static const marketplaceBackgroundGradient = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [headerGreen, headerGreenDark],
      );

  /// Tamno-staklena zelena pozadina headera — neprozirna zelena, bez blur-a.
  static BoxDecoration get headerGlassDecoration => const BoxDecoration(
        gradient: headerGradientSolid,
      );

  /// Neprozirna tamna smaragdna (OneSoil).
  static const headerGradientSolid = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [headerGreen, headerGreenDark],
      );

  /// Postepeni prijelaz: jasna slika gore → tamno dno za čitljiv tekst.
  static LinearGradient get cardOverlayGradient => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        stops: [0.0, 0.55, 0.78, 1.0],
        colors: [
          Color(0x00000000),
          Color(0x00000000),
          Color(0x66000000),
          Color(0xB3000000),
        ],
      );

  /// Donji rub kartice — blago tamnjenje pri dnu slike (ne cijela kartica).
  static const marketplacePhotoScrimGradient = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        stops: [0.0, 0.45, 1.0],
        colors: [
          Color(0x00000000),
          Color(0x33000000),
          Color(0x99000000),
        ],
      );

  /// Visina donjeg scrima (udio visine kartice).
  static const marketplacePhotoScrimHeightFactor = 0.42;

  /// Omjer kartice — viša kartica, više slike vidljivo (kao prije).
  static const marketplaceProductCardAspectRatio = 0.72;

  /// Tamno-zeleni stakleni badge cijene na kartici proizvoda.
  static BoxDecoration get marketplacePricePillDecoration => BoxDecoration(
        color: headerGreenDark.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      );

  /// Cream/brown staklo — build +71 marketplace kartice.
  static LinearGradient get imageFadeGradient => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0x00000000),
          Color(0x00000000),
          Color(0x33F7F0E8),
          Color(0xCCF5EDE3),
          Color(0xF2EDE0D0),
        ],
        stops: [0.0, 0.42, 0.58, 0.78, 1.0],
      );

  static List<BoxShadow> get cardShadow => const [
        BoxShadow(
          color: borderShadow,
          blurRadius: 10,
          offset: Offset(0, 4),
        ),
        BoxShadow(
          color: Color(0xD9F5EDE3),
          blurRadius: 0,
          offset: Offset(0, -0.5),
        ),
      ];

  /// Jača sjena kartice na tamno-zelenoj pozadini tržišta.
  static List<BoxShadow> get marketplaceCardShadow => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.42),
          blurRadius: 14,
          offset: const Offset(0, 6),
        ),
        BoxShadow(
          color: Colors.white.withValues(alpha: 0.07),
          blurRadius: 0,
          offset: const Offset(0, -0.5),
        ),
      ];
}
