import 'package:flutter_test/flutter_test.dart';
import 'package:bienen_app/features/gesundheit/domain/gesundheitsereignis.dart';

void main() {
  test('Roundtrip + istAktiv', () {
    final e = Gesundheitsereignis.fromJson({
      'id': 'g1', 'volk_id': 'v1', 'festgestellt_am': '2026-07-19', 'krankheit': 'afb',
      'schweregrad': 'schwer', 'status': 'gemeldet', 'gemeldet_am': '2026-07-19',
      'labor_eingesandt': false, 'foto_urls': ['b/v1/f.jpg'], 'massnahme': 'gesperrt',
      'verantwortliche_person': 'Dani', 'notiz': null,
      'is_storniert': false, 'storno_grund': null, 'storno_am': null,
    });
    expect(e.krankheit, 'afb');
    expect(e.status, 'gemeldet');
    expect(e.gemeldetAm, isNotNull);
    expect(e.fotoUrls, ['b/v1/f.jpg']);
    expect(e.istAktiv, isTrue);
    final j = e.toInsertJson();
    expect(j['volk_id'], 'v1');
    expect(j['krankheit'], 'afb');
    expect(j.containsKey('id'), isFalse);
  });
  test('istAktiv false bei storniert/abgeschlossen', () {
    Gesundheitsereignis mk(String status, {bool storno = false}) => Gesundheitsereignis(
        id: 'x', volkId: 'v1', festgestelltAm: DateTime(2026, 7, 19), krankheit: 'kalkbrut',
        status: status, isStorniert: storno);
    expect(mk('verdacht').istAktiv, isTrue);
    expect(mk('ausgeheilt').istAktiv, isFalse);
    expect(mk('saniert').istAktiv, isFalse);
    expect(mk('erloschen').istAktiv, isFalse);
    expect(mk('verdacht', storno: true).istAktiv, isFalse);
  });
}
