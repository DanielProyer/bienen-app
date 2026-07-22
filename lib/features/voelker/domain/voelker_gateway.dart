import 'package:bienen_app/features/voelker/domain/volk.dart';
import 'package:bienen_app/features/voelker/domain/standort.dart';
import 'package:bienen_app/features/voelker/domain/koenigin.dart';
import 'package:bienen_app/features/voelker/domain/betriebs_einstellungen.dart';

/// Fachlicher Fehler mit stabilem Code (BA02x) + Klartext fuer die UI.
class VoelkerFehler implements Exception {
  final String code;
  final String message;
  const VoelkerFehler(this.code, this.message);
  @override
  String toString() => message;
}

abstract class VoelkerGateway {
  Future<List<Volk>> voelker();
  Future<List<Standort>> standorte();
  Future<List<Koenigin>> koeniginnen();
  Future<BetriebsEinstellungen?> einstellungen();
  Future<void> einstellungenSpeichern(String betriebId, BetriebsEinstellungen e);

  Future<void> volkSpeichern(Volk volk); // insert wenn id leer, sonst update
  Future<void> volkLoeschen(String id);
  /// Speichert einen Standort und gibt ihn MIT vergebener id zurueck — die
  /// braucht der Aufrufer, um ihn direkt einem Volk zuzuordnen.
  Future<Standort> standortSpeichern(Standort s);

  /// Loeschen: die DB setzt `voelker.standort_id` UND `aufgaben.standort_id`
  /// per ON DELETE SET NULL auf null (siehe `voelker_standort_fk` /
  /// `aufgaben_standort_fk`).
  Future<void> standortLoeschen(String id);

  /// Speichert eine Koenigin und gibt sie MIT vergebener id zurueck — die
  /// braucht der Aufrufer, um sie direkt einem Volk zuzuordnen (umweiseln).
  Future<Koenigin> koeniginSpeichern(Koenigin k);
  Future<void> koeniginLoeschen(String id);

  /// Atomare Umweiselung. [neueKoeniginId] null = Volk bleibt weisellos.
  Future<void> umweiseln({
    required String volkId,
    String? neueKoeniginId,
    String altGrund = 'ersetzt',
    DateTime? datum,
  });
}
