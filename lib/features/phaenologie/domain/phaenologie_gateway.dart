import 'package:bienen_app/features/phaenologie/domain/beobachtung.dart';

class PhaenologieFehler implements Exception {
  final String code;
  final String message;
  const PhaenologieFehler(this.code, this.message);
  @override
  String toString() => message;
}

abstract class PhaenologieGateway {
  /// Alle Beobachtungen des aktiven Betriebs (RLS filtert nach betrieb_id).
  Future<List<PhaenoBeobachtung>> alle();

  /// Upsert je (betrieb_id, jahr, anker) — überschreibt eine bestehende Zeile.
  Future<void> upsert(PhaenoBeobachtung b);
}
