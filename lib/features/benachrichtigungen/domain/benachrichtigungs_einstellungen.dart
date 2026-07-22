/// Persoenliche Benachrichtigungs-Einstellungen eines Mitglieds.
/// `zuletztGesendetAm` wird NUR von der Edge Function gesetzt und daher nie
/// mitgeschrieben — sonst wuerde die App den Doppelversand-Riegel ueberschreiben.
class BenachrichtigungsEinstellungen {
  final String id;
  final String? telegramChatId;
  final bool aktiv;
  final int sendeStunde;
  final String zeitzone;
  final DateTime? zuletztGesendetAm;

  const BenachrichtigungsEinstellungen({
    required this.id,
    this.telegramChatId,
    this.aktiv = false,
    this.sendeStunde = 6,
    this.zeitzone = 'Europe/Zurich',
    this.zuletztGesendetAm,
  });

  const BenachrichtigungsEinstellungen.leer()
      : id = '',
        telegramChatId = null,
        aktiv = false,
        sendeStunde = 6,
        zeitzone = 'Europe/Zurich',
        zuletztGesendetAm = null;

  factory BenachrichtigungsEinstellungen.fromJson(Map<String, dynamic> j) =>
      BenachrichtigungsEinstellungen(
        id: j['id'] as String,
        telegramChatId: j['telegram_chat_id'] as String?,
        aktiv: (j['aktiv'] as bool?) ?? false,
        sendeStunde: (j['sende_stunde'] as num?)?.toInt() ?? 6,
        zeitzone: (j['zeitzone'] as String?) ?? 'Europe/Zurich',
        zuletztGesendetAm: _datum(j['zuletzt_gesendet_am']),
      );

  /// `zuletzt_gesendet_am` ist eine reine `date`-Spalte. Als UTC-Mitternacht
  /// lesen — `DateTime.parse` wuerde sie als LOKALE Mitternacht deuten und der
  /// Tag verschoebe sich je nach Zeitzone des Geraets.
  static DateTime? _datum(Object? v) {
    if (v == null) return null;
    final d = DateTime.parse(v as String);
    return DateTime.utc(d.year, d.month, d.day);
  }

  Map<String, dynamic> toUpdateJson() => {
        'telegram_chat_id': telegramChatId,
        'aktiv': aktiv,
        'sende_stunde': sendeStunde,
        'zeitzone': zeitzone,
      };

  BenachrichtigungsEinstellungen copyWith({
    String? telegramChatId,
    bool? aktiv,
    int? sendeStunde,
    String? zeitzone,
  }) =>
      BenachrichtigungsEinstellungen(
        id: id,
        telegramChatId: telegramChatId ?? this.telegramChatId,
        aktiv: aktiv ?? this.aktiv,
        sendeStunde: sendeStunde ?? this.sendeStunde,
        zeitzone: zeitzone ?? this.zeitzone,
        zuletztGesendetAm: zuletztGesendetAm,
      );
}
