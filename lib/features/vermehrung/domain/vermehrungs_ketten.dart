import 'package:bienen_app/features/aufgaben/domain/aufgabe.dart';
import 'package:bienen_app/features/vermehrung/domain/vermehrungs_ereignis.dart';

enum KettenZiel { stammvolk, jungvolk }

class KettenSchritt {
  final String schrittKey;
  final String titel;
  final String beschreibung;
  final int tagVon;
  final int tagBis;
  final KettenZiel ziel;
  final String kategorie;
  const KettenSchritt({
    required this.schrittKey, required this.titel, required this.beschreibung,
    required this.tagVon, required this.tagBis, required this.ziel, required this.kategorie,
  });
}

/// Fachliche Ketten (Recherche 25 §10). Kellerhaft-Offset: die "≤7 T nach Einlogieren"-Frist
/// zählt ab Einlogieren (nach 3–5 T Kellerhaft), NICHT ab Tag 0 → konservativ Tag 10–12.
/// Werte sind BGD-Richtwerte (Fachstellen-Check).
const kVermehrungsKetten = <String, List<KettenSchritt>>{
  'brutableger': [
    KettenSchritt(schrittKey: 'zellen_brechen', titel: 'Weiselzellen bis auf 1 ausbrechen',
        beschreibung: 'Überzählige Weiselzellen bis auf 1 (max. 2) ausbrechen. Danach bis zur Weiselkontrolle NICHT öffnen.',
        tagVon: 9, tagBis: 9, ziel: KettenZiel.jungvolk, kategorie: 'durchsicht'),
    KettenSchritt(schrittKey: 'weiselkontrolle_os', titel: 'Weiselkontrolle + Oxalsäure bei Eilage',
        beschreibung: 'Weiselrichtigkeit prüfen; bei Königin in Eilage Oxalsäure sprühen (Oxuvar 5.7 %, 3–4 ml/Wabenseite), idealerweise auf Neubau.',
        tagVon: 25, tagBis: 30, ziel: KettenZiel.jungvolk, kategorie: 'behandlung'),
  ],
  'kunstschwarm': [
    KettenSchritt(schrittKey: 'kellerhaft_ende', titel: 'Kellerhaft beenden, einlogieren',
        beschreibung: 'Nach 3–5 T Kellerhaft: Futterteigverschluss, Mittelwände, einlogieren, füttern.',
        tagVon: 3, tagBis: 5, ziel: KettenZiel.jungvolk, kategorie: 'durchsicht'),
    KettenSchritt(schrittKey: 'weiselkontrolle_os', titel: 'Weiselkontrolle (Königin-Annahme) + Oxalsäure',
        beschreibung: 'Spätestens 7 T nach Einlogieren: Weiselrichtigkeit prüfen (zugesetzte Königin angenommen?). Bei Eilage Oxalsäure sprühen.',
        tagVon: 10, tagBis: 12, ziel: KettenZiel.jungvolk, kategorie: 'behandlung'),
  ],
  'koeniginnen_kunstschwarm': [
    KettenSchritt(schrittKey: 'stammvolk_zellen_brechen', titel: 'Stammvolk: Weiselzellen bis auf 1 ausbrechen',
        beschreibung: '9 T nach Bildung im Stammvolk die Nachschaffungszellen bis auf 1 (max. 2) ausbrechen.',
        tagVon: 9, tagBis: 9, ziel: KettenZiel.stammvolk, kategorie: 'durchsicht'),
    KettenSchritt(schrittKey: 'jungvolk_weiselkontrolle_os', titel: 'Jungvolk: Weiselkontrolle + Oxalsäure',
        beschreibung: 'Spätestens 7 T nach Einlogieren: Weiselrichtigkeit; bei Eilage Oxalsäure sprühen.',
        tagVon: 10, tagBis: 12, ziel: KettenZiel.jungvolk, kategorie: 'behandlung'),
    KettenSchritt(schrittKey: 'stammvolk_weiselkontrolle_os', titel: 'Stammvolk: Weiselkontrolle + Oxalsäure (Doppelbremse)',
        beschreibung: 'Bei Brutfreiheit die zweite Varroa-Bremse nutzen: Oxalsäure vor Verdeckelung der ersten Brut der neuen Königin.',
        tagVon: 25, tagBis: 30, ziel: KettenZiel.stammvolk, kategorie: 'behandlung'),
  ],
  'flugling': [
    KettenSchritt(schrittKey: 'zellen_brechen', titel: 'Flugling: Weiselzellen bis auf 1 ausbrechen',
        beschreibung: '9 T nach Bildung überzählige Weiselzellen bis auf 1 (max. 2) ausbrechen.',
        tagVon: 9, tagBis: 9, ziel: KettenZiel.jungvolk, kategorie: 'durchsicht'),
    KettenSchritt(schrittKey: 'weiselkontrolle_os', titel: 'Flugling: Weiselkontrolle + Oxalsäure',
        beschreibung: '25–30 T nach Bildung Weiselkontrolle; bei Eilage Oxalsäure, auf Neubau setzen.',
        tagVon: 25, tagBis: 30, ziel: KettenZiel.jungvolk, kategorie: 'behandlung'),
    KettenSchritt(schrittKey: 'brutling_os', titel: 'Brutling (Stammvolk): Oxalsäure nach Auslaufen der Brut',
        beschreibung: 'Der Brutling wird mit der gedeckelten Brut milbenärmer; nach Auslaufen der Brut Oxalsäure.',
        tagVon: 25, tagBis: 30, ziel: KettenZiel.stammvolk, kategorie: 'behandlung'),
  ],
};

const kKettenVorlaufTage = 14;

class KettenVorschlag {
  final VermehrungsEreignis ereignis;
  final KettenSchritt schritt;
  final DateTime fensterStart;
  final DateTime fensterEnde;
  final DateTime faelligAm;
  final String? volkId;
  final bool ueberfaellig;
  final String beschreibung;
  const KettenVorschlag({
    required this.ereignis, required this.schritt, required this.fensterStart, required this.fensterEnde,
    required this.faelligAm, required this.volkId, required this.ueberfaellig, required this.beschreibung,
  });
}

DateTime _tag(DateTime d) => DateTime(d.year, d.month, d.day);

/// Reine Funktion: welche Ketten-Schritte stehen am [stichtag] an?
/// Relative Fristen (kalenderunabhängig). DST-sicher (Kalenderkomponenten). Überfällige offene
/// Einmal-Schritte bleiben sichtbar (ueberfaellig=true). Dedup NUR über (ereignis_id, schritt_key).
List<KettenVorschlag> kettenVorschlaege({
  required DateTime stichtag,
  required List<VermehrungsEreignis> ereignisse,
  required List<Aufgabe> kettenAufgaben,
  required Set<String> aktiveVolkIds,
}) {
  final heute = _tag(stichtag);
  final out = <KettenVorschlag>[];
  for (final e in ereignisse) {
    final kette = kVermehrungsKetten[e.methode];
    if (kette == null) continue; // Katalog-Drift-tolerant
    for (final s in kette) {
      // Dedup: existiert eine Ketten-Aufgabe für (ereignis, schritt)?
      final schonMaterialisiert = kettenAufgaben.any((a) =>
          a.ereignisId == e.id && a.schrittKey == s.schrittKey);
      if (schonMaterialisiert) continue;
      // Ziel-Volk
      final volkId = s.ziel == KettenZiel.stammvolk ? e.stammvolkId : e.jungvolkId;
      if (volkId == null) continue;                 // jungvolk noch nicht verknüpft / stammvolk weg
      if (!aktiveVolkIds.contains(volkId)) continue; // Volk gelöscht/inaktiv
      final start = DateTime(e.erstelltAm.year, e.erstelltAm.month, e.erstelltAm.day + s.tagVon);
      final ende = DateTime(e.erstelltAm.year, e.erstelltAm.month, e.erstelltAm.day + s.tagBis);
      final vorlaufGrenze = DateTime(start.year, start.month, start.day - kKettenVorlaufTage);
      if (heute.isBefore(vorlaufGrenze)) continue;   // noch nicht im Vorlauf
      out.add(KettenVorschlag(
        ereignis: e, schritt: s, fensterStart: start, fensterEnde: ende, faelligAm: ende,
        volkId: volkId, ueberfaellig: heute.isAfter(ende), beschreibung: s.beschreibung,
      ));
    }
  }
  out.sort((a, b) => a.faelligAm.compareTo(b.faelligAm));
  return out;
}

/// Für die Ketten-Vorschau im Formular: alle Schritte einer Methode, datiert ab [erstelltAm] (read-only).
List<({KettenSchritt schritt, DateTime von, DateTime bis})> kettenVorschauFuer(String methode, DateTime erstelltAm) {
  final kette = kVermehrungsKetten[methode] ?? const [];
  return [
    for (final s in kette)
      (schritt: s,
       von: DateTime(erstelltAm.year, erstelltAm.month, erstelltAm.day + s.tagVon),
       bis: DateTime(erstelltAm.year, erstelltAm.month, erstelltAm.day + s.tagBis)),
  ];
}

/// Materialisiert einen Vorschlag als normale Aufgabe (quelle='ereignis').
Aufgabe aufgabeAusKettenVorschlag(KettenVorschlag v, {String status = 'offen'}) => Aufgabe(
      id: '', titel: v.schritt.titel, beschreibung: v.beschreibung, kategorie: v.schritt.kategorie,
      faelligAm: v.faelligAm, status: status, volkId: v.volkId,
      quelle: 'ereignis', ereignisId: v.ereignis.id, schrittKey: v.schritt.schrittKey,
    );
