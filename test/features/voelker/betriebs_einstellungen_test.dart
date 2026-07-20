import 'package:flutter_test/flutter_test.dart';
import 'package:bienen_app/features/voelker/domain/betriebs_einstellungen.dart';

void main() {
  test('fromJson liest Strategie-Flags; Defaults bei fehlend', () {
    final e = BetriebsEinstellungen.fromJson({
      'saison_offset_default_tage': 42, 'winterfutter_ziel_kg': 22,
      'anzahl_ernten': 2, 'sommerbehandlung_methode': 'biotechnisch', 'vermehrung_aktiv': true,
    });
    expect(e.anzahlErnten, 2);
    expect(e.sommerbehandlungMethode, 'biotechnisch');
    expect(e.vermehrungAktiv, true);
    const leer = BetriebsEinstellungen.leer();
    expect(leer.anzahlErnten, 1);
    expect(leer.sommerbehandlungMethode, 'ameisensaeure');
    expect(leer.vermehrungAktiv, false);
  });
  test('toUpdateJson enthält genau die 5 editierbaren Felder', () {
    const e = BetriebsEinstellungen(saisonOffsetDefaultTage: 42, winterfutterZielKg: 22,
      anzahlErnten: 1, sommerbehandlungMethode: 'beide', vermehrungAktiv: false);
    final j = e.toUpdateJson();
    expect(j.keys.toSet(), {'saison_offset_default_tage', 'winterfutter_ziel_kg',
      'anzahl_ernten', 'sommerbehandlung_methode', 'vermehrung_aktiv'});
    expect(j['sommerbehandlung_methode'], 'beide');
  });
}
