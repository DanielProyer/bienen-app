import 'package:flutter/material.dart';

/// Zentrale Design-Tokens (Richtung A: warm, beruhigt). Bausteine/Screens lesen
/// NUR Tokens, nie rohe Hex-/Pixelwerte. Die alte AppColors-Palette bleibt für
/// noch nicht migrierte Screens bestehen.
class BeeTokens {
  BeeTokens._();

  // ── Farb-Rollen: Flächen ──
  static const oberflaeche = Color(0xFFFAF7F2); // Seiten-Hintergrund
  static const karte = Colors.white;

  // ── Text ──
  static const textPrimaer = Color(0xFF4E342E);
  static const textSekundaer = Color(0xFF8B5E0B);
  static const textGedaempft = Color(0xFFA1887F);

  // ── Rand ──
  static const rand = Color(0xFFEAE3D6);
  static const randStark = Color(0xFFD7CCC8);
  static const chevron = Color(0xFFC9BCA8);

  // ── Akzent ──
  static const honig = Color(0xFFD4920B);
  static const honigTint = Color(0xFFFAEEDA);

  // ── Signal-Rollen (Fläche + Text) ──
  static const erfolgFlaeche = Color(0xFFEAF3DE);
  static const erfolgText = Color(0xFF3B6D11);
  static const warnungFlaeche = Color(0xFFFAEEDA);
  static const warnungText = Color(0xFF854F0B);
  static const gefahrFlaeche = Color(0xFFFCEBEB);
  static const gefahrText = Color(0xFFA32D2D);
  static const infoFlaeche = Color(0xFFE6F1FB);
  static const infoText = Color(0xFF185FA5);

  // ── Abstände (4/8-Raster) ──
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;

  // ── Radien ──
  static const rKarte = 12.0;
  static const rControl = 14.0;
  static const rPille = 20.0;

  // ── Tap-Ziele ──
  static const tapMin = 48.0;
  static const stepper = 52.0;

  // ── Schrift-Skala (2 Gewichte) ──
  static const titel = TextStyle(fontSize: 20, fontWeight: FontWeight.w500, color: textPrimaer, height: 1.3);
  static const abschnitt = TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: textPrimaer, height: 1.35);
  static const text = TextStyle(fontSize: 15, fontWeight: FontWeight.w400, color: textPrimaer, height: 1.45);
  static const label = TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: textSekundaer, height: 1.3);
  static const gedaempft = TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: textGedaempft, height: 1.3);
}

enum BeeSignal { erfolg, warnung, gefahr, info, neutral }

extension BeeSignalFarben on BeeSignal {
  Color get flaeche => switch (this) {
        BeeSignal.erfolg => BeeTokens.erfolgFlaeche,
        BeeSignal.warnung => BeeTokens.warnungFlaeche,
        BeeSignal.gefahr => BeeTokens.gefahrFlaeche,
        BeeSignal.info => BeeTokens.infoFlaeche,
        BeeSignal.neutral => BeeTokens.karte,
      };
  Color get text => switch (this) {
        BeeSignal.erfolg => BeeTokens.erfolgText,
        BeeSignal.warnung => BeeTokens.warnungText,
        BeeSignal.gefahr => BeeTokens.gefahrText,
        BeeSignal.info => BeeTokens.infoText,
        BeeSignal.neutral => BeeTokens.textSekundaer,
      };
}
