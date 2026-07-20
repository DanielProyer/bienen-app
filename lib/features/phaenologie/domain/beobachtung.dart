import 'package:bienen_app/features/phaenologie/domain/phaenologie.dart';

/// Eine beobachtete Zeigerpflanzen-Blüte (je Betrieb/Jahr/Anker eindeutig).
/// Trägt bewusst KEIN betrieb_id/id — die setzt die DB (Default aktive_betrieb_id()).
class PhaenoBeobachtung {
  final int jahr;
  final PhaenoAnker anker;
  final String indikatorKey;
  final DateTime bluehAm;
  const PhaenoBeobachtung({
    required this.jahr,
    required this.anker,
    required this.indikatorKey,
    required this.bluehAm,
  });

  factory PhaenoBeobachtung.fromJson(Map<String, dynamic> j) => PhaenoBeobachtung(
        jahr: j['jahr'] as int,
        anker: (j['anker'] as String) == 'tracht' ? PhaenoAnker.tracht : PhaenoAnker.fruehjahr,
        indikatorKey: j['indikator_key'] as String,
        bluehAm: DateTime.parse(j['blueh_am'] as String),
      );

  /// NUR die vier fachlichen Felder — betrieb_id/id werden WEGGELASSEN (nicht null gesetzt),
  /// damit der DB-Default private.aktive_betrieb_id() greift. anker-Guard verhindert stillen
  /// Fehl-Offset (tracht-Key auf fruehjahr-Anker o. ä.).
  Map<String, dynamic> toUpsertJson() {
    assert(indikatorVon(indikatorKey)?.anker == anker,
        'indikatorKey "$indikatorKey" passt nicht zum anker $anker');
    final d = bluehAm;
    final iso = '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    return {
      'jahr': jahr,
      'anker': anker == PhaenoAnker.tracht ? 'tracht' : 'fruehjahr',
      'indikator_key': indikatorKey,
      'blueh_am': iso,
    };
  }
}
