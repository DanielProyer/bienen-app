import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:bienen_app/core/supabase/supabase_config.dart';
import 'package:bienen_app/features/backup/domain/export_format.dart';
// Bedingter Import: Web bekommt die dart:js_interop-Kapsel, VM/Tests einen
// No-op-Stub (js_interop baut nur auf dem Web-Ziel).
import 'package:bienen_app/features/backup/data/download_plattform_stub.dart'
    if (dart.library.js_interop) 'package:bienen_app/features/backup/data/download_plattform_web.dart';

/// Fortschritts-Meldung waehrend des Exports.
typedef ExportFortschritt = void Function(String schritt, int erledigt, int gesamt);

/// Baut das Export-Paket AUS DER SICHT DES ANGEMELDETEN NUTZERS:
/// alle Abfragen laufen ueber dessen Sitzung, die RLS liefert automatisch nur
/// den aktiven Betrieb. Keine Service-Keys im Client.
class ExportService {
  static const _tabellen = <String>[
    'betriebe', 'betrieb_mitglieder', 'profiles',
    'standorte', 'koeniginnen', 'voelker', 'inspections',
    'behandlungen', 'varroa_kontrollen', 'fuetterungen', 'gesundheitsereignisse',
    'aufgaben', 'vermehrungs_ereignisse', 'volk_bewertungen',
    'materials', 'material_purchases', 'construction_steps',
    'betriebs_einstellungen', 'phaenologie_beobachtungen', 'wissen_fotos',
    'scales', 'scale_alerts', 'weight_readings', 'funkstationen', 'einladungen',
  ];
  static const _buckets = <String>[
    'inspection-photos', 'health-photos', 'wissen-photos',
    'material-media', 'material-receipts', 'construction-photos',
  ];
  static const _seite = 1000;

  /// Liefert das fertige ZIP UND die Warnungen — der Aufrufer darf einen
  /// Teil-Erfolg nicht als vollen Erfolg melden.
  static Future<({Uint8List bytes, List<String> warnungen})> paketBauen({
    required String betriebId,
    ExportFortschritt? fortschritt,
  }) async {
    final client = SupabaseConfig.client;
    final archiv = Archive();
    final warnungen = <String>[];
    final zahlen = <String, int>{};
    final schema = <String, List<String>>{};
    final gesamt = _tabellen.length + _buckets.length;

    for (var i = 0; i < _tabellen.length; i++) {
      final t = _tabellen[i];
      fortschritt?.call('Tabelle $t', i, gesamt);
      final zeilen = <Map<String, dynamic>>[];
      try {
        var von = 0;
        for (;;) {
          final teil = await client.from(t).select().range(von, von + _seite - 1);
          zeilen.addAll((teil as List).cast<Map<String, dynamic>>());
          if (teil.length < _seite) break;
          von += _seite;
        }
      } catch (e) {
        warnungen.add('Tabelle $t nicht lesbar: $e');
        continue;
      }
      zahlen[t] = zeilen.length;
      if (zeilen.isNotEmpty) schema[t] = (zeilen.first.keys.toList()..sort());
      _dateiZu(archiv, 'daten/$t.json', utf8.encode(stabilesJson(zeilen)));
      _dateiZu(archiv, 'daten/$t.csv', utf8.encode(csvVon(zeilen)));
    }

    var fotoAnzahl = 0, fotoBytes = 0;
    for (var i = 0; i < _buckets.length; i++) {
      final b = _buckets[i];
      fortschritt?.call('Fotos $b', _tabellen.length + i, gesamt);
      try {
        for (final pfad in await _pfadeIn(b, '$betriebId/')) {
          try {
            final bytes = await client.storage.from(b).download(pfad);
            _dateiZu(archiv, 'fotos/$b/$pfad', bytes);
            fotoAnzahl++;
            fotoBytes += bytes.length;
          } catch (e) {
            warnungen.add('Foto nicht ladbar: $b/$pfad ($e)');
          }
        }
      } catch (e) {
        warnungen.add('Bucket $b nicht auflistbar: $e');
      }
    }

    _dateiZu(
      archiv,
      'manifest.json',
      utf8.encode(manifestVon(
        betriebId: betriebId,
        erstelltAm: DateTime.now().toUtc(),
        tabellen: zahlen,
        fotoAnzahl: fotoAnzahl,
        fotoBytes: fotoBytes,
        schema: schema,
        warnungen: warnungen,
      )),
    );

    fortschritt?.call('Paket schnüren', gesamt, gesamt);
    final roh = ZipEncoder().encode(archiv);
    if (roh == null) throw StateError('ZIP konnte nicht erzeugt werden');
    return (bytes: Uint8List.fromList(roh), warnungen: warnungen);
  }

  /// Rekursive Auflistung eines Bucket-Praefix.
  static Future<List<String>> _pfadeIn(String bucket, String praefix) async {
    final ergebnis = <String>[];
    final eintraege =
        await SupabaseConfig.client.storage.from(bucket).list(path: praefix);
    for (final e in eintraege) {
      final pfad = '$praefix${e.name}';
      if (e.id == null) {
        ergebnis.addAll(await _pfadeIn(bucket, '$pfad/'));
      } else {
        ergebnis.add(pfad);
      }
    }
    return ergebnis;
  }

  static void _dateiZu(Archive a, String name, List<int> bytes) {
    a.addFile(ArchiveFile(name, bytes.length, bytes));
  }

  /// Loest den Browser-Download aus.
  static void herunterladen(Uint8List bytes, String dateiname) {
    if (!kIsWeb) return;
    downloadImBrowser(bytes, dateiname);
  }
}
