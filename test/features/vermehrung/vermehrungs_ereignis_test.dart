import 'package:flutter_test/flutter_test.dart';
import 'package:bienen_app/features/vermehrung/domain/vermehrung.dart';
import 'package:bienen_app/features/vermehrung/domain/vermehrungs_ereignis.dart';

void main() {
  test('Methoden-Metadaten: 4 Methoden, Labels, brutfreiBeiErstellung nur schwarmartig', () {
    expect(kVermehrungsMethoden.keys.toSet(),
        {'kunstschwarm', 'koeniginnen_kunstschwarm', 'brutableger', 'flugling'});
    expect(kVermehrungsMethoden['kunstschwarm']!.brutfreiBeiErstellung, isTrue);
    expect(kVermehrungsMethoden['brutableger']!.brutfreiBeiErstellung, isFalse);
    expect(kVermehrungsMethoden['flugling']!.brutfreiBeiErstellung, isFalse);
  });

  test('Ereignis fromJson/toInsertJson: ohne betrieb_id/id, jungvolk null möglich', () {
    final e = VermehrungsEreignis.fromJson({
      'id': 'e1', 'betrieb_id': 'b1', 'methode': 'brutableger', 'erstellt_am': '2026-06-05',
      'stammvolk_id': 'v1', 'jungvolk_id': null, 'os_bei_erstellung': false, 'notiz': null,
    });
    expect(e.id, 'e1');
    expect(e.methode, 'brutableger');
    expect(e.erstelltAm, DateTime(2026, 6, 5));
    expect(e.jungvolkId, isNull);
    final j = e.toInsertJson();
    expect(j.containsKey('betrieb_id'), isFalse);
    expect(j.containsKey('id'), isFalse);
    expect(j['methode'], 'brutableger');
    expect(j['erstellt_am'], '2026-06-05');
  });
}
