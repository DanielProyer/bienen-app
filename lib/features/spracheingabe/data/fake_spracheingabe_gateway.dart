import 'package:bienen_app/features/spracheingabe/data/spracheingabe_gateway.dart';
import 'package:bienen_app/features/spracheingabe/domain/lernschwelle.dart';
import 'package:bienen_app/features/spracheingabe/domain/sprach_modelle.dart';

/// Speicherfassung des Gateways fuer Tests — kein Netz, keine Datenbank.
class FakeSpracheingabeGateway implements SpracheingabeGateway {
  final List<SprachKarte> karten = [];
  final List<SprachProbe> proben = [];
  final List<SprachErgebnis> ergebnisse = [];
  final List<SprachKorrektur> korrekturen = [];
  int _lauf = 0;

  String _id(String praefix) => '$praefix${++_lauf}';

  @override
  Future<List<SprachKarte>> kartenLaden() async => karten.where((k) => k.aktiv).toList();

  @override
  Future<SprachKarte> karteAnlegen(SprachKarte karte) async {
    final neu = SprachKarte(
      id: _id('k'),
      personId: karte.personId,
      art: karte.art,
      sollText: karte.sollText,
      pruefbegriffe: karte.pruefbegriffe,
      herkunft: karte.herkunft,
      aktiv: karte.aktiv,
    );
    karten.add(neu);
    return neu;
  }

  @override
  Future<SprachProbe> probeAnlegen(SprachProbe probe) async {
    final neu = SprachProbe(
      id: _id('p'),
      personId: probe.personId,
      karteId: probe.karteId,
      sollText: probe.sollText,
      modus: probe.modus,
      storagePath: probe.storagePath,
      dauerMs: probe.dauerMs,
      groesseB: probe.groesseB,
      mime: probe.mime,
    );
    proben.add(neu);
    return neu;
  }

  @override
  Future<SprachErgebnis> ergebnisAnlegen(SprachErgebnis e) async {
    final neu = SprachErgebnis(
      id: _id('e'),
      probeId: e.probeId,
      anbieter: e.anbieter,
      modell: e.modell,
      mitWortliste: e.mitWortliste,
      transkript: e.transkript,
      trefferQuote: e.trefferQuote,
      wortfehlerrate: e.wortfehlerrate,
      dauerMs: e.dauerMs,
      fehler: e.fehler,
    );
    ergebnisse.add(neu);
    return neu;
  }

  @override
  Future<List<SprachErgebnis>> ergebnisseZu(String probeId) async =>
      ergebnisse.where((e) => e.probeId == probeId).toList();

  @override
  Future<List<SprachKorrektur>> korrekturenLaden() async => List.of(korrekturen);

  @override
  Future<SprachKorrektur?> verhoererMelden({
    required String betriebId,
    required String personId,
    required String falsch,
    required String richtig,
    required String quelle,
  }) async {
    final schluessel = falsch.trim().toLowerCase();
    if (schluessel.isEmpty || richtig.trim().isEmpty) return null;

    final i = korrekturen.indexWhere((k) => k.falsch == schluessel);
    final treffer = i < 0 ? 1 : korrekturen[i].treffer + 1;
    final neu = SprachKorrektur(
      id: i < 0 ? _id('c') : korrekturen[i].id,
      personId: personId,
      falsch: schluessel,
      richtig: richtig.trim(),
      treffer: treffer,
      quelle: quelle,
      aktiv: darfRegelWerden(treffer: treffer, falsch: schluessel, richtig: richtig),
    );
    if (i < 0) {
      korrekturen.add(neu);
    } else {
      korrekturen[i] = neu;
    }
    return neu;
  }
}
