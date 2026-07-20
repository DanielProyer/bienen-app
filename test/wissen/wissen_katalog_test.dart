import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:bienen_app/features/wissen/domain/wissen_eintrag.dart';
import 'package:bienen_app/features/wissen/domain/wissen_katalog.dart';

void main() {
  test('keys eindeutig und nicht leer', () {
    final keys = kWissensKatalog.map((e) => e.key).toList();
    expect(keys.toSet().length, keys.length);
    expect(keys.any((k) => k.trim().isEmpty), isFalse);
  });
  test('verwandte lösen auf', () {
    for (final e in kWissensKatalog) {
      for (final v in e.verwandte) {
        expect(wissenVon(v), isNotNull, reason: '${e.key} → verwandte $v fehlt');
      }
    }
  });
  test('kategorie existiert', () {
    final kats = kWissensKategorien.map((k) => k.key).toSet();
    for (final e in kWissensKatalog) {
      expect(kats.contains(e.kategorie), isTrue, reason: e.key);
    }
  });
  test('jede skizze existiert und ist in pubspec deklariert', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final declared = RegExp(r'-\s+(assets/\S+)').allMatches(pubspec).map((m) => m.group(1)!).toList();
    for (final e in kWissensKatalog) {
      if (e.skizze == null) continue;
      expect(File(e.skizze!).existsSync(), isTrue, reason: 'Datei fehlt: ${e.skizze}');
      final covered = declared.any((d) => d == e.skizze || (d.endsWith('/') && e.skizze!.startsWith(d)));
      expect(covered, isTrue, reason: 'nicht in pubspec: ${e.skizze}');
    }
  });
  test('rechercheAsset existiert', () {
    for (final e in kWissensKatalog) {
      for (final l in e.mehr) {
        if (l.rechercheAsset != null) {
          expect(File(l.rechercheAsset!).existsSync(), isTrue, reason: l.rechercheAsset);
        }
      }
    }
  });
  test('wissenVon Null-Kontrakt (kein Throw)', () {
    expect(wissenVon(null), isNull);
    expect(wissenVon('gibt_es_nicht'), isNull);
  });
  test('belegteKategorien filtert leere aus', () {
    expect(belegteKategorien().map((k) => k.key), contains('durchsicht'));
    const leere = WissensKategorie(key: 'varroa', titel: 'Varroa', icon: 'bug');
    const voll = WissensKategorie(key: 'durchsicht', titel: 'Durchsicht', icon: 'eye');
    const eintrag = WissensEintrag(key: 'x', titel: 'X', kurzinfo: 'x', kategorie: 'durchsicht');
    final res = belegteKategorien(kategorien: const [voll, leere], katalog: const [eintrag]);
    expect(res.map((k) => k.key), ['durchsicht']);
  });
}
