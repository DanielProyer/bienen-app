import 'dart:convert';

/// Format-Vertrag des Backups — identisch zur Node-Seite (scripts/backup.mjs im
/// Repo bienen-backup). Aenderungen hier MUESSEN dort mitgezogen werden;
/// `format_version` im Manifest macht Drift sichtbar.

String _zeilenSchluessel(Map<String, dynamic> z) {
  final id = z['id'];
  return (id == null) ? jsonEncode(z) : id.toString();
}

List<Map<String, dynamic>> _sortiert(List<Map<String, dynamic>> zeilen) {
  final kopie = [...zeilen];
  kopie.sort((a, b) => _zeilenSchluessel(a).compareTo(_zeilenSchluessel(b)));
  return kopie;
}

Map<String, dynamic> _schluesselSortiert(Map<String, dynamic> m) {
  final keys = m.keys.toList()..sort();
  return {for (final k in keys) k: m[k]};
}

/// CSV mit BOM; Spalten alphabetisch, jeder Wert gequotet, `"` verdoppelt,
/// null → leer, Objekte/Listen als kompaktes JSON.
String csvVon(List<Map<String, dynamic>> zeilen) {
  if (zeilen.isEmpty) return '﻿';
  final spalten = <String>{for (final z in zeilen) ...z.keys}.toList()..sort();
  String feld(dynamic w) {
    if (w == null) return '""';
    final s = (w is Map || w is List) ? jsonEncode(w) : w.toString();
    return '"${s.replaceAll('"', '""')}"';
  }

  final kopf = spalten.map(feld).join(',');
  final leib = _sortiert(zeilen)
      .map((z) => spalten.map((s) => feld(z[s])).join(','))
      .join('\n');
  return '﻿$kopf\n$leib\n';
}

/// JSON: stabil sortiert, Schluessel alphabetisch, 2 Space, Zeilenumbruch am Ende.
String stabilesJson(List<Map<String, dynamic>> zeilen) {
  final daten = _sortiert(zeilen).map(_schluesselSortiert).toList();
  return '${const JsonEncoder.withIndent('  ').convert(daten)}\n';
}

/// manifest.json als Text.
String manifestVon({
  required String betriebId,
  required DateTime erstelltAm,
  required Map<String, int> tabellen,
  required int fotoAnzahl,
  required int fotoBytes,
  required Map<String, List<String>> schema,
  required List<String> warnungen,
}) {
  final m = _schluesselSortiert({
    'betrieb_id': betriebId,
    'erstellt_am': erstelltAm.toUtc().toIso8601String(),
    'format_version': 1,
    'fotos': {'anzahl': fotoAnzahl, 'bytes': fotoBytes},
    'schema': _schluesselSortiert(schema),
    'tabellen': _schluesselSortiert(tabellen),
    'warnungen': warnungen,
  });
  return '${const JsonEncoder.withIndent('  ').convert(m)}\n';
}
