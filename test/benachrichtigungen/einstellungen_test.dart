import 'package:flutter_test/flutter_test.dart';
import 'package:bienen_app/features/benachrichtigungen/domain/benachrichtigungs_einstellungen.dart';

void main() {
  test('fromJson/toUpdateJson round-trip', () {
    final e = BenachrichtigungsEinstellungen.fromJson(const {
      'id': 'e1', 'betrieb_id': 'b1', 'user_id': 'u1', 'kanal': 'telegram',
      'telegram_chat_id': '12345', 'aktiv': true, 'sende_stunde': 7,
      'zeitzone': 'Europe/Zurich', 'zuletzt_gesendet_am': '2026-07-22',
    });
    expect(e.telegramChatId, '12345');
    expect(e.aktiv, isTrue);
    expect(e.sendeStunde, 7);
    expect(e.zuletztGesendetAm, DateTime.utc(2026, 7, 22));
    final j = e.toUpdateJson();
    expect(j['telegram_chat_id'], '12345');
    expect(j['sende_stunde'], 7);
    expect(j.containsKey('id'), isFalse, reason: 'id wird nie geschrieben');
    expect(j.containsKey('zuletzt_gesendet_am'), isFalse,
        reason: 'setzt ausschliesslich die Edge Function');
  });

  test('leer: fail-safe Defaults', () {
    const e = BenachrichtigungsEinstellungen.leer();
    expect(e.aktiv, isFalse, reason: 'erst nach erfolgreicher Verknuepfung an');
    expect(e.sendeStunde, 6);
    expect(e.zeitzone, 'Europe/Zurich');
    expect(e.telegramChatId, isNull);
  });
}
