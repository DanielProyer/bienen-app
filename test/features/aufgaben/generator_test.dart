import 'package:flutter_test/flutter_test.dart';
import 'package:bienen_app/features/aufgaben/domain/aufgabe.dart';
import 'package:bienen_app/features/aufgaben/domain/saison_regeln.dart';

Aufgabe _regelAufgabe(String key, int jahr, DateTime faellig,
        {String status = 'offen', String? volkId = 'v1'}) =>
    Aufgabe(
      id: 'x', titel: 'x', kategorie: 'sonstiges', faelligAm: faellig,
      status: status, volkId: volkId, quelle: 'regel', regelKey: key, saisonJahr: jahr,
    );

void main() {
  // 19.07. ohne Offset: gemuelldiagnose_sommer (bis 15.7.) vorbei; startfuetterung (15.–31.7.)
  // und sommerbehandlung_1 (20.7.–15.8.) aktiv; hauptfuetterung (ab 1.8.) im 14-Tage-Vorlauf.
  test('Fenster ohne Offset: aktive + Vorlauf-Regeln am 19.07.', () {
    final v = anstehendeVorschlaege(
      stichtag: DateTime(2026, 7, 19), saisonOffsetTage: 0,
      regelAufgaben: const [], anzahlAktiveVoelker: 1,
    );
    final keys = v.map((x) => x.regel.key).toSet();
    expect(keys.contains('startfuetterung'), isTrue);
    expect(keys.contains('sommerbehandlung_1'), isTrue);
    expect(keys.contains('hauptfuetterung'), isTrue); // 1.8. liegt <= 14 Tage voraus
    expect(keys.contains('gemuelldiagnose_sommer'), isFalse); // Fenster vorbei
    expect(keys.contains('oxalsaeure_winter'), isFalse);
  });

  test('Offset +42 verschiebt Frühjahrsregeln: honigraum_aufsetzen am 5.6. aktiv', () {
    // Basis 10.4.–30.4. + 42 = 22.5.–11.6.
    final v = anstehendeVorschlaege(
      stichtag: DateTime(2026, 6, 5), saisonOffsetTage: 42,
      regelAufgaben: const [], anzahlAktiveVoelker: 1,
    );
    expect(v.map((x) => x.regel.key), contains('honigraum_aufsetzen'));
    // fix-Regel bleibt unverschoben: startfuetterung am 5.6. NICHT aktiv
    expect(v.map((x) => x.regel.key), isNot(contains('startfuetterung')));
  });

  test('keine volk-Regeln ohne aktive Völker (betrieb-Regeln bleiben)', () {
    final v = anstehendeVorschlaege(
      stichtag: DateTime(2026, 10, 15), saisonOffsetTage: 0,
      regelAufgaben: const [], anzahlAktiveVoelker: 0,
    );
    expect(v.every((x) => x.regel.ebene == RegelEbene.betrieb), isTrue);
    expect(v.map((x) => x.regel.key), contains('maeuseschutz_ansetzen'));
  });

  test('Dedup: angenommene Regel (Zeile vorhanden) wird nicht mehr vorgeschlagen', () {
    final v = anstehendeVorschlaege(
      stichtag: DateTime(2026, 7, 19), saisonOffsetTage: 0,
      regelAufgaben: [_regelAufgabe('startfuetterung', 2026, DateTime(2026, 7, 31))],
      anzahlAktiveVoelker: 1,
    );
    expect(v.map((x) => x.regel.key), isNot(contains('startfuetterung')));
  });

  test('Dedup: übersprungene Regel (volkId null) unterdrückt fürs Saisonjahr', () {
    final v = anstehendeVorschlaege(
      stichtag: DateTime(2026, 7, 19), saisonOffsetTage: 0,
      regelAufgaben: [_regelAufgabe('sommerbehandlung_1', 2026, DateTime(2026, 8, 15),
          status: 'uebersprungen', volkId: null)],
      anzahlAktiveVoelker: 1,
    );
    expect(v.map((x) => x.regel.key), isNot(contains('sommerbehandlung_1')));
  });

  test('Intervall: Schwarmkontrolle nächster Termin = jüngste + 7, erst ab 2 Tagen Vorlauf', () {
    // Offset 0: Fenster 15.4.–1.6. Jüngste Zeile faellig 10.5. → nächster 17.5.
    final basis = [_regelAufgabe('schwarmkontrolle', 2026, DateTime(2026, 5, 10))];
    final am16 = anstehendeVorschlaege(
      stichtag: DateTime(2026, 5, 16), saisonOffsetTage: 0,
      regelAufgaben: basis, anzahlAktiveVoelker: 1,
    );
    final sk16 = am16.where((x) => x.regel.key == 'schwarmkontrolle').toList();
    expect(sk16.single.faelligAm, DateTime(2026, 5, 17));

    final am12 = anstehendeVorschlaege(
      stichtag: DateTime(2026, 5, 12), saisonOffsetTage: 0,
      regelAufgaben: basis, anzahlAktiveVoelker: 1,
    );
    expect(am12.where((x) => x.regel.key == 'schwarmkontrolle'), isEmpty); // 17.5. > 12.5.+2
  });

  test('Intervall: nach Fensterende kein Vorschlag mehr', () {
    final v = anstehendeVorschlaege(
      stichtag: DateTime(2026, 6, 10), saisonOffsetTage: 0,
      regelAufgaben: [_regelAufgabe('schwarmkontrolle', 2026, DateTime(2026, 5, 30))],
      anzahlAktiveVoelker: 1,
    );
    expect(v.where((x) => x.regel.key == 'schwarmkontrolle'), isEmpty); // 6.6. > 1.6. Ende
  });

  test('faelligAm-Default = Fensterende (Deadline-Charakter)', () {
    final v = anstehendeVorschlaege(
      stichtag: DateTime(2026, 9, 5), saisonOffsetTage: 0,
      regelAufgaben: const [], anzahlAktiveVoelker: 1,
    );
    final auf = v.firstWhere((x) => x.regel.key == 'auffuetterung_abschliessen');
    expect(auf.faelligAm, DateTime(2026, 9, 10));
    expect(auf.saisonJahr, 2026);
  });

  test('Jahreswechsel-Vorlauf: werkstatt_winter (ab 1.1.) erscheint schon am 20.12. mit saisonJahr Folgejahr', () {
    final v = anstehendeVorschlaege(
      stichtag: DateTime(2026, 12, 20), saisonOffsetTage: 0,
      regelAufgaben: const [], anzahlAktiveVoelker: 1,
    );
    final w = v.firstWhere((x) => x.regel.key == 'werkstatt_winter');
    expect(w.saisonJahr, 2027);
  });

  test('sortiert nach faelligAm aufsteigend', () {
    final v = anstehendeVorschlaege(
      stichtag: DateTime(2026, 7, 19), saisonOffsetTage: 0,
      regelAufgaben: const [], anzahlAktiveVoelker: 1,
    );
    for (var i = 1; i < v.length; i++) {
      expect(v[i - 1].faelligAm.isAfter(v[i].faelligAm), isFalse);
    }
  });
}
