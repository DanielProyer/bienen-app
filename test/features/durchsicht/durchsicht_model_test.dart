import 'package:flutter_test/flutter_test.dart';
import 'package:bienen_app/features/durchsicht/domain/durchsicht.dart';

void main() {
  test('fromJson/toInsertJson Roundtrip inkl. text[]', () {
    final j = {
      'id': 'd1', 'volk_id': 'v1', 'durchgefuehrt_am': '2026-05-01',
      'weiselzustand': 'weiselrichtig', 'koenigin_gesehen': true, 'stifte_gesehen': true,
      'auffaelligkeiten': ['kalkbrut', 'varroa_sichtbar'], 'foto_urls': ['b/v1/foto_1.jpg'],
      'sanftmut': 3,
    };
    final d = Durchsicht.fromJson(j);
    expect(d.weiselzustand, 'weiselrichtig');
    expect(d.auffaelligkeiten, ['kalkbrut', 'varroa_sichtbar']);
    expect(d.fotoUrls, ['b/v1/foto_1.jpg']);
    final ins = d.toInsertJson();
    expect(ins['auffaelligkeiten'], ['kalkbrut', 'varroa_sichtbar']);
    expect(ins.containsKey('id'), isFalse); // id nie im Insert
  });

  test('unbekanntes Auffaelligkeits-Flag wird verworfen', () {
    expect(Durchsicht.gueltigeFlags(['kalkbrut', 'quatsch', 'ruhr']), ['kalkbrut', 'ruhr']);
  });
}
