import 'package:flutter/material.dart';

/// Ordnet dem Icon-Namen einer Wissens-Kategorie ein Symbol zu.
///
/// Warum die Zweiteilung: `wissen_katalog.dart` ist reines Dart ohne
/// Flutter-Import (damit die Domain in einfachen Tests ohne Widget-Umgebung
/// prüfbar bleibt). Die Kategorie trägt darum nur den Namen, das Symbol wird
/// hier in der Präsentationsschicht zugeordnet.
///
/// Ein Name ohne Eintrag hier bliebe unsichtbar — genau das war der Zustand
/// bis v1.39.3: das Feld existierte, ein Mapping nie. `wissen_katalog_test`
/// erzwingt deshalb, dass jede Kategorie hier auflösbar ist.
const kWissensKategorieSymbole = <String, IconData>{
  'eye': Icons.visibility_outlined,
  'bug': Icons.bug_report_outlined,
  'health': Icons.healing_outlined,
  'droplet': Icons.water_drop_outlined,
  'star': Icons.star_outline,
  'honeycomb': Icons.hexagon_outlined,
  'scale': Icons.balance,
};

/// Null, wenn der Name unbekannt ist — die Überschrift rendert dann ohne
/// Symbol statt zu werfen (KEIN `!`, gleiche Haltung wie `wissenVon`).
IconData? wissensKategorieSymbol(String iconName) => kWissensKategorieSymbole[iconName];
