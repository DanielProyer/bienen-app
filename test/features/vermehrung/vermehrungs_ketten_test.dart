import 'package:flutter_test/flutter_test.dart';
import 'package:bienen_app/features/aufgaben/domain/aufgabe.dart';
import 'package:bienen_app/features/vermehrung/domain/vermehrung.dart';
import 'package:bienen_app/features/vermehrung/domain/vermehrungs_ereignis.dart';
import 'package:bienen_app/features/vermehrung/domain/vermehrungs_ketten.dart';

VermehrungsEreignis _ev({String methode = 'brutableger', DateTime? am, String? stamm = 'v1', String? jung}) =>
    VermehrungsEreignis(id: 'e1', methode: methode, erstelltAm: am ?? DateTime(2026, 6, 5),
        stammvolkId: stamm, jungvolkId: jung);

Aufgabe _kettenAufgabe(String schrittKey, {String status = 'offen'}) => Aufgabe(
    id: 'a1', titel: 't', kategorie: 'durchsicht', faelligAm: DateTime(2026, 6, 14),
    status: status, quelle: 'ereignis', ereignisId: 'e1', schrittKey: schrittKey);

void main() {
  List<KettenVorschlag> lauf({required DateTime stichtag, List<VermehrungsEreignis>? ev,
          List<Aufgabe> auf = const [], Set<String> aktiv = const {'v1', 'j1'}}) =>
      kettenVorschlaege(stichtag: stichtag, ereignisse: ev ?? [_ev(jung: 'j1')],
          kettenAufgaben: auf, aktiveVolkIds: aktiv);

  test('Katalog-Invarianten: 4 Methoden, je >=1 Schritt, schrittKey eindeutig, chronologisch, tagVon<=tagBis', () {
    expect(kVermehrungsKetten.keys.toSet(), kVermehrungsMethoden.keys.toSet()); // kein Drift
    const erlaubteKat = {'durchsicht', 'behandlung', 'fuetterung', 'schutz', 'werkstatt', 'verwaltung', 'sonstiges'};
    for (final schritte in kVermehrungsKetten.values) {
      expect(schritte, isNotEmpty);
      final keys = schritte.map((s) => s.schrittKey).toList();
      expect(keys.toSet().length, keys.length); // eindeutig
      for (var i = 0; i < schritte.length; i++) {
        expect(schritte[i].tagVon <= schritte[i].tagBis, isTrue);
        if (i > 0) expect(schritte[i - 1].tagVon <= schritte[i].tagVon, isTrue); // chronologisch
        expect(erlaubteKat.contains(schritte[i].kategorie), isTrue);
      }
    }
  });

  test('Vorlauf: Schritt erscheint ab start-14, im Fenster', () {
    // brutableger Tag 9 (start=ende=14.6.), Vorlauf ab 31.5.
    final vor = lauf(stichtag: DateTime(2026, 5, 20)); // vor Vorlauf
    expect(vor.any((v) => v.schritt.schrittKey == 'zellen_brechen'), isFalse);
    final im = lauf(stichtag: DateTime(2026, 6, 1)); // im Vorlauf
    expect(im.any((v) => v.schritt.schrittKey == 'zellen_brechen'), isTrue);
  });

  test('Überfällig: nach fensterEnde bleibt offener Schritt sichtbar mit ueberfaellig=true', () {
    final v = lauf(stichtag: DateTime(2026, 6, 20)); // nach Tag 9 (14.6.)
    final z = v.firstWhere((x) => x.schritt.schrittKey == 'zellen_brechen');
    expect(z.ueberfaellig, isTrue);
  });

  test('Dedup ohne volk_id: angenommener/übersprungener Schritt -> kein Vorschlag mehr', () {
    final an = lauf(stichtag: DateTime(2026, 6, 12), auf: [_kettenAufgabe('zellen_brechen')]);
    expect(an.any((v) => v.schritt.schrittKey == 'zellen_brechen'), isFalse);
    final sk = lauf(stichtag: DateTime(2026, 6, 12), auf: [_kettenAufgabe('zellen_brechen', status: 'uebersprungen')]);
    expect(sk.any((v) => v.schritt.schrittKey == 'zellen_brechen'), isFalse);
  });

  test('stichtag mit Uhrzeit am Rand-Tag (ende) → noch sichtbar (Normalisierung)', () {
    final v = lauf(stichtag: DateTime(2026, 6, 14, 14, 30)); // Tag 9 = 14.6., mit Uhrzeit
    final z = v.where((x) => x.schritt.schrittKey == 'zellen_brechen');
    expect(z.isNotEmpty, isTrue);
    expect(z.first.ueberfaellig, isFalse); // heute==ende, nicht überfällig
  });

  test('Jungvolk null: jungvolk-Ziel-Schritte werden NICHT vorgeschlagen', () {
    // brutableger: beide Schritte ziel=jungvolk; ohne jungvolk_id keine Vorschläge
    final v = lauf(stichtag: DateTime(2026, 6, 12), ev: [_ev(jung: null)]);
    expect(v.where((x) => x.schritt.ziel == KettenZiel.jungvolk), isEmpty);
  });

  test('Ziel-Volk gelöscht (nicht in aktiveVolkIds) → kein Vorschlag', () {
    final v = lauf(stichtag: DateTime(2026, 6, 12), ev: [_ev(jung: 'j1')], aktiv: {}); // v1/j1 weg
    expect(v, isEmpty);
  });

  test('Methode ohne Katalog-Eintrag → Ereignis übersprungen (kein Crash)', () {
    final v = lauf(stichtag: DateTime(2026, 6, 12), ev: [_ev(methode: 'unbekannt', jung: 'j1')]);
    expect(v, isEmpty);
  });

  test('aufgabeAusKettenVorschlag: quelle=ereignis mit ereignisId/schrittKey', () {
    final v = lauf(stichtag: DateTime(2026, 6, 12)).first;
    final a = aufgabeAusKettenVorschlag(v);
    expect(a.quelle, 'ereignis');
    expect(a.ereignisId, 'e1');
    expect(a.schrittKey, v.schritt.schrittKey);
    expect(a.volkId, v.volkId);
    final sk = aufgabeAusKettenVorschlag(v, status: 'uebersprungen');
    expect(sk.status, 'uebersprungen');
  });
}
