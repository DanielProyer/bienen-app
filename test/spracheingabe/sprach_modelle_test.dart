import 'package:flutter_test/flutter_test.dart';
import 'package:bienen_app/features/spracheingabe/domain/sprach_modelle.dart';

void main() {
  test('Karte liest sich aus JSON, pruefbegriffe nie null', () {
    final k = SprachKarte.fromJson(const {
      'id': 'k1', 'art': 'satz', 'soll_text': 'Königin auf Wabe acht',
      'pruefbegriffe': ['Königin'], 'herkunft': 'start', 'aktiv': true,
    });
    expect(k.art, KartenArt.satz);
    expect(k.pruefbegriffe, ['Königin']);

    final ohne = SprachKarte.fromJson(const {
      'id': 'k2', 'art': 'wort', 'soll_text': 'Varroa', 'herkunft': 'eigen', 'aktiv': true,
    });
    expect(ohne.pruefbegriffe, isEmpty);
    expect(ohne.art, KartenArt.wort);
  });

  test('bei einer Wortkarte sind die Prüfbegriffe der Soll-Text selbst', () {
    // Sonst haette eine Wortkarte nichts zu zaehlen.
    final k = SprachKarte.fromJson(const {
      'id': 'k3', 'art': 'wort', 'soll_text': 'Weiselzellen', 'herkunft': 'start', 'aktiv': true,
    });
    expect(k.zuZaehlen, ['Weiselzellen']);
  });

  test('bei einer Satzkarte sind die Prüfbegriffe die hinterlegten', () {
    final k = SprachKarte.fromJson(const {
      'id': 'k4', 'art': 'satz', 'soll_text': 'keine Weiselzellen gesehen',
      'pruefbegriffe': ['Weiselzellen'], 'herkunft': 'start', 'aktiv': true,
    });
    expect(k.zuZaehlen, ['Weiselzellen']);
  });

  test('Probe und Ergebnis lesen sich aus JSON', () {
    final p = SprachProbe.fromJson(const {
      'id': 'p1', 'person_id': 'u1', 'karte_id': 'k1', 'soll_text': 'Varroa',
      'modus': 'drill', 'storage_path': 'b/u/x.webm', 'dauer_ms': 1200,
      'groesse_b': 4096, 'mime': 'audio/webm',
    });
    expect(p.modus, ProbenModus.drill);
    expect(p.dauerMs, 1200);

    final e = SprachErgebnis.fromJson(const {
      'id': 'e1', 'probe_id': 'p1', 'anbieter': 'infomaniak', 'modell': 'whisper',
      'mit_wortliste': true, 'transkript': 'Varroa', 'treffer_quote': 1.0,
      'wortfehlerrate': 0.0, 'dauer_ms': 4300,
    });
    expect(e.anbieter, 'infomaniak');
    expect(e.trefferQuote, 1.0);
    expect(e.fehler, isNull);
  });

  test('Korrektur wird erst ab der Lernschwelle als aktiv gemeldet', () {
    final k = SprachKorrektur.fromJson(const {
      'id': 'c1', 'person_id': 'u1', 'falsch': 'weissenzellen',
      'richtig': 'Weiselzellen', 'treffer': 1, 'quelle': 'training', 'aktiv': false,
    });
    expect(k.aktiv, isFalse);
  });

  test('nurAktive lässt unscharfe Beobachtungen draussen', () {
    // Der Verbraucher soll nicht selbst an `aktiv` denken muessen.
    final scharf = SprachKorrektur.fromJson(const {
      'id': 'c1', 'person_id': 'u1', 'falsch': 'weissenzellen',
      'richtig': 'Weiselzellen', 'treffer': 2, 'quelle': 'training', 'aktiv': true,
    });
    final beobachtung = SprachKorrektur.fromJson(const {
      'id': 'c2', 'person_id': 'u1', 'falsch': 'minuten',
      'richtig': 'Milben', 'treffer': 1, 'quelle': 'training', 'aktiv': false,
    });
    final regeln = SprachKorrektur.nurAktive([scharf, beobachtung]);
    expect(regeln.map((r) => r.richtig), ['Weiselzellen']);
  });
}
