/// Saison-Regelwerk Modul 4.4 — Fachkonstante (Muster krankheit.dart, KEIN DB-Seed).
/// Quelle: imkerei/02_Recherche/02_Jahresablauf_Imker_Arosa_1570m.md (Kompaktkalender).
/// Basisfenster = Mittelland; `offsetAnwenden` (Frühjahr/Tracht) verschiebt um
/// betriebs_einstellungen.saison_offset_default_tage (Arosa +42 = DATENWERT, kein Code).
/// Herbst-/Winterregeln sind kalenderfix mit alpin-sicheren Fenstern (alpiner Herbst kommt
/// FRÜHER — ein positiver Offset wäre dort falsch; früh einfüttern schadet nie).
library;

import 'package:bienen_app/features/aufgaben/domain/aufgabe.dart';
import 'package:bienen_app/features/voelker/domain/betriebs_einstellungen.dart';

enum RegelEbene { volk, betrieb }

class SaisonRegel {
  final String key;
  final String titel;
  final String beschreibung;
  final String kategorie; // = DB-CHECK-Wert
  final RegelEbene ebene;
  final int startMonat, startTag, endMonat, endTag; // Basisfenster (inkl.)
  final bool offsetAnwenden;
  final int? intervallTage;
  final String? aktionRoute; // 'durchsicht'|'behandlung'|'fuetterung'|'varroa'|null
  final bool nurBeiVermehrung;
  final int? nurBeiAnzahlErnten;

  const SaisonRegel({
    required this.key,
    required this.titel,
    required this.beschreibung,
    required this.kategorie,
    required this.ebene,
    required this.startMonat,
    required this.startTag,
    required this.endMonat,
    required this.endTag,
    this.offsetAnwenden = false,
    this.intervallTage,
    this.aktionRoute,
    this.nurBeiVermehrung = false,
    this.nurBeiAnzahlErnten,
  });
}

const kSaisonRegeln = <SaisonRegel>[
  // ---- kalenderfix ----
  SaisonRegel(key: 'werkstatt_winter', titel: 'Werkstatt: Rähmchen, Mittelwände, Material',
      beschreibung: 'Winterruhe nutzen: Rähmchen drahten, Mittelwände einlöten, Material für die Saison bestellen.',
      kategorie: 'werkstatt', ebene: RegelEbene.betrieb,
      startMonat: 1, startTag: 1, endMonat: 2, endTag: 28),
  SaisonRegel(key: 'futtervorrat_winter', titel: 'Futtervorrat prüfen (Gewicht/Futterteig)',
      beschreibung: 'Beute von aussen anheben/wägen; bei Bedarf Futterteig direkt aufs Volk legen.',
      kategorie: 'durchsicht', ebene: RegelEbene.volk,
      startMonat: 2, startTag: 1, endMonat: 3, endTag: 20),
  SaisonRegel(key: 'gemuelldiagnose_fruehjahr', titel: 'Gemülldiagnose Frühjahr (Milbenfall)',
      beschreibung: 'Windel einlegen, natürlichen Milbenfall pro Tag zählen — Startwert für die Saison.',
      kategorie: 'behandlung', ebene: RegelEbene.volk,
      startMonat: 3, startTag: 1, endMonat: 3, endTag: 31, aktionRoute: 'varroa'),
  SaisonRegel(key: 'maeuseschutz_entfernen', titel: 'Mäusegitter/Fluglochkeil entfernen',
      beschreibung: 'Nach dem Reinigungsflug Flugloch wieder freigeben (Pollenhöschen dürfen nicht abgestreift werden).',
      kategorie: 'schutz', ebene: RegelEbene.betrieb,
      startMonat: 3, startTag: 15, endMonat: 4, endTag: 15),
  SaisonRegel(key: 'gemuelldiagnose_sommer', titel: 'Gemülldiagnose nach Ernte',
      beschreibung: 'Milbenfall/Tag nach der Ernte messen — Entscheidungsgrundlage für die Sommerbehandlung.',
      kategorie: 'behandlung', ebene: RegelEbene.volk,
      startMonat: 7, startTag: 1, endMonat: 7, endTag: 15, aktionRoute: 'varroa'),
  SaisonRegel(key: 'startfuetterung', titel: 'Startfütterung (~5 kg)',
      beschreibung: 'Nach dem Abschleudern sofort ~5 kg füttern, damit das Volk nicht in eine Futterlücke fällt.',
      kategorie: 'fuetterung', ebene: RegelEbene.volk,
      startMonat: 7, startTag: 15, endMonat: 7, endTag: 31, aktionRoute: 'fuetterung'),
  SaisonRegel(key: 'sommerbehandlung_1', titel: '1. Varroa-Sommerbehandlung starten',
      beschreibung: 'Ameisensäure-Langzeitbehandlung nach der Ernte starten (Temperaturfenster beachten).',
      kategorie: 'behandlung', ebene: RegelEbene.volk,
      startMonat: 7, startTag: 20, endMonat: 8, endTag: 15, aktionRoute: 'behandlung'),
  SaisonRegel(key: 'hauptfuetterung', titel: 'Hauptfütterung (Etappen)',
      beschreibung: 'Winterfutter in 2–3 Etappen auffüttern (Ziel siehe Winterfutter-Balken je Volk).',
      kategorie: 'fuetterung', ebene: RegelEbene.volk,
      startMonat: 8, startTag: 1, endMonat: 8, endTag: 31, aktionRoute: 'fuetterung'),
  SaisonRegel(key: 'sommerbehandlung_2', titel: '2. Varroa-Sommerbehandlung',
      beschreibung: 'Zweite Behandlung nach Abschluss der Fütterung — Wintervölker milbenarm aufziehen.',
      kategorie: 'behandlung', ebene: RegelEbene.volk,
      startMonat: 8, startTag: 25, endMonat: 9, endTag: 20, aktionRoute: 'behandlung'),
  SaisonRegel(key: 'auffuetterung_abschliessen', titel: 'Auffütterung ABSCHLIESSEN (Deadline!)',
      beschreibung: 'Fütterung spätestens jetzt abschliessen, damit das Volk das Futter noch invertieren und verdeckeln kann.',
      kategorie: 'fuetterung', ebene: RegelEbene.volk,
      startMonat: 9, startTag: 1, endMonat: 9, endTag: 10, aktionRoute: 'fuetterung'),
  SaisonRegel(key: 'futterkontrolle_herbst', titel: 'Futterkontrolle + Weiselkontrolle',
      beschreibung: 'Futtervorrat und Weiselrichtigkeit prüfen; schwache Völker jetzt vereinigen.',
      kategorie: 'durchsicht', ebene: RegelEbene.volk,
      startMonat: 9, startTag: 20, endMonat: 10, endTag: 10, aktionRoute: 'durchsicht'),
  SaisonRegel(key: 'maeuseschutz_ansetzen', titel: 'Mäusegitter/Fluglochkeil ansetzen',
      beschreibung: 'Vor dem ersten Frost Mäusegitter montieren + Flugloch auf max. 6 mm Höhe verkleinern (BGD 4.3) — Mäuse zerstören im Winter ganze Völker.',
      kategorie: 'schutz', ebene: RegelEbene.betrieb,
      startMonat: 10, startTag: 1, endMonat: 10, endTag: 31),
  SaisonRegel(key: 'winterfest_machen', titel: 'Winterfest: Windsicherung, Beschwerung, Schnee-Zugang',
      beschreibung: 'Deckel beschweren, Beuten gegen Sturm sichern, Zugang bei Schnee planen.',
      kategorie: 'schutz', ebene: RegelEbene.betrieb,
      startMonat: 10, startTag: 10, endMonat: 10, endTag: 31),
  SaisonRegel(key: 'spechtschutz', titel: 'Spechtschutz anbringen (Netz/Verkleidung)',
      beschreibung: 'Grünspechte hacken im Winter Beuten an — Netz oder Verkleidung anbringen.',
      kategorie: 'schutz', ebene: RegelEbene.betrieb,
      startMonat: 11, startTag: 1, endMonat: 11, endTag: 30),
  SaisonRegel(key: 'brutfreiheit_pruefen', titel: 'Brutfreiheit prüfen (vor Winterbehandlung)',
      beschreibung: 'Nach ~3 Wochen Dauerfrost bzw. ab Mitte November Brutfreiheit kontrollieren.',
      kategorie: 'behandlung', ebene: RegelEbene.volk,
      startMonat: 11, startTag: 1, endMonat: 11, endTag: 20),
  SaisonRegel(key: 'oxalsaeure_winter', titel: 'Oxalsäure-Winterbehandlung (brutfrei)',
      beschreibung: 'Restentmilbung im brutfreien Zustand — träufeln bei geschlossener Wintertraube.',
      kategorie: 'behandlung', ebene: RegelEbene.volk,
      startMonat: 11, startTag: 15, endMonat: 12, endTag: 15, aktionRoute: 'behandlung'),
  // ---- Frühjahr/Tracht (offsetAnwenden) ----
  SaisonRegel(key: 'erste_durchsicht', titel: 'Erste kurze Durchsicht (ab ~15 °C)',
      beschreibung: 'Kurzkontrolle: Volksstärke, Futter, Weiselrichtigkeit — nicht auseinanderreissen.',
      kategorie: 'durchsicht', ebene: RegelEbene.volk,
      startMonat: 3, startTag: 1, endMonat: 3, endTag: 25, offsetAnwenden: true, aktionRoute: 'durchsicht'),
  SaisonRegel(key: 'fruehjahrsdurchsicht', titel: 'Frühjahrsdurchsicht (vollständig)',
      beschreibung: 'Vollständige Durchsicht bei 16–20 °C: Brutbild, Futterkranzprobe, Bodentausch.',
      kategorie: 'durchsicht', ebene: RegelEbene.volk,
      startMonat: 3, startTag: 15, endMonat: 4, endTag: 10, offsetAnwenden: true, aktionRoute: 'durchsicht'),
  SaisonRegel(key: 'wabenhygiene', titel: 'Wabenhygiene/Bodentausch',
      beschreibung: 'Alte, dunkle Waben ausscheiden; Boden tauschen oder reinigen.',
      kategorie: 'durchsicht', ebene: RegelEbene.volk,
      startMonat: 3, startTag: 1, endMonat: 4, endTag: 15, offsetAnwenden: true),
  SaisonRegel(key: 'drohnenrahmen_einsetzen', titel: 'Drohnenrahmen einsetzen',
      beschreibung: 'Drohnenrahmen als biotechnische Varroa-Falle einhängen.',
      kategorie: 'durchsicht', ebene: RegelEbene.volk,
      startMonat: 3, startTag: 20, endMonat: 4, endTag: 10, offsetAnwenden: true),
  SaisonRegel(key: 'drohnenschnitt', titel: 'Drohnenrahmen schneiden',
      beschreibung: 'Verdeckelte Drohnenbrut alle ~14 Tage ausschneiden (Varroa-Entnahme).',
      kategorie: 'durchsicht', ebene: RegelEbene.volk,
      startMonat: 4, startTag: 1, endMonat: 6, endTag: 30, offsetAnwenden: true, intervallTage: 14),
  SaisonRegel(key: 'brutraum_erweitern', titel: 'Brutraum erweitern',
      beschreibung: 'Bei starkem Wachstum Brutraum mit Mittelwänden erweitern.',
      kategorie: 'durchsicht', ebene: RegelEbene.volk,
      startMonat: 4, startTag: 1, endMonat: 4, endTag: 20, offsetAnwenden: true),
  SaisonRegel(key: 'honigraum_aufsetzen', titel: 'Honigraum aufsetzen',
      beschreibung: 'Bei Trachtbeginn Honigraum aufsetzen (Absperrgitter kontrollieren).',
      kategorie: 'durchsicht', ebene: RegelEbene.volk,
      startMonat: 4, startTag: 10, endMonat: 4, endTag: 30, offsetAnwenden: true),
  SaisonRegel(key: 'schwarmkontrolle', titel: 'Schwarmkontrolle (alle 7 Tage!)',
      beschreibung: 'Wöchentlich auf Schwarmzellen kontrollieren — ein versäumter Termin kann das halbe Volk kosten.',
      kategorie: 'durchsicht', ebene: RegelEbene.volk,
      startMonat: 4, startTag: 15, endMonat: 6, endTag: 1, offsetAnwenden: true, intervallTage: 7,
      aktionRoute: 'durchsicht'),
  SaisonRegel(key: 'honigernte', titel: 'Honigernte (Reife prüfen)',
      beschreibung: 'Verdeckelungsgrad/Wassergehalt prüfen, reife Honigwaben abschleudern.',
      kategorie: 'sonstiges', ebene: RegelEbene.volk,
      startMonat: 5, startTag: 20, endMonat: 6, endTag: 5, offsetAnwenden: true),
];

/// Katalog-Lookup (null bei unbekanntem/fehlendem Key — Drift-tolerant).
SaisonRegel? regelVon(String? key) {
  if (key == null) return null;
  for (final r in kSaisonRegeln) {
    if (r.key == key) return r;
  }
  return null;
}

/// Auflösung des Aufgabentexts je Betriebsstrategie (heute nur sommerbehandlung_1 nach Methode).
String beschreibungFuer(SaisonRegel r, BetriebsEinstellungen e) {
  if (r.key == 'sommerbehandlung_1') {
    switch (e.sommerbehandlungMethode) {
      case 'biotechnisch':
        return '1. Sommerbehandlung biotechnisch (Brutstopp/Bannwabe/komplette Brutentnahme) — Vorbereitung ab 1. Juli-Hälfte.';
      case 'beide':
        return '1. Sommerbehandlung: Ameisensäure ODER biotechnisch (Brutstopp/Bannwabe) — nach der Ernte, vor Ende Juli.';
      default: // ameisensaeure
        return '1. Sommerbehandlung mit Ameisensäure starten (vor Ende Juli, Temperaturfenster beachten).';
    }
  }
  return r.beschreibung;
}

// --- Generator ---

/// Vorlauf, mit dem Fenster-Regeln vor Fensterbeginn erscheinen.
const kVorlaufTage = 14;

/// Kürzerer Vorlauf für Intervall-Regeln (sonst erschiene der 7-Tage-Rhythmus sofort wieder).
const kIntervallVorlaufTage = 2;

class AufgabenVorschlag {
  final SaisonRegel regel;
  final DateTime fensterStart;
  final DateTime fensterEnde;
  final DateTime faelligAm;
  final int saisonJahr;
  final String beschreibung;
  const AufgabenVorschlag({
    required this.regel,
    required this.fensterStart,
    required this.fensterEnde,
    required this.faelligAm,
    required this.saisonJahr,
    required this.beschreibung,
  });
}

DateTime _tag(DateTime d) => DateTime(d.year, d.month, d.day);

/// Reine Funktion: welche Saisonaufgaben stehen am [stichtag] an?
/// [regelAufgaben] = alle Aufgaben mit quelle='regel' (jeder Status — angenommene UND
/// übersprungene Zeilen dedupen). Saison-Anker gekapselt: Kandidatenjahre Vorjahr/aktuell/Folgejahr
/// (Vorlauf über Jahreswechsel; Gotcha 11 aus 4.6).
List<AufgabenVorschlag> anstehendeVorschlaege({
  required DateTime stichtag,
  required int saisonOffsetTage,
  required List<Aufgabe> regelAufgaben,
  required int anzahlAktiveVoelker,
  BetriebsEinstellungen einstellungen = const BetriebsEinstellungen.leer(),
}) {
  final heute = _tag(stichtag);
  final out = <AufgabenVorschlag>[];
  for (final r in kSaisonRegeln) {
    if (r.ebene == RegelEbene.volk && anzahlAktiveVoelker == 0) continue;
    if (r.nurBeiVermehrung && !einstellungen.vermehrungAktiv) continue;
    if (r.nurBeiAnzahlErnten != null && einstellungen.anzahlErnten != r.nurBeiAnzahlErnten) continue;
    // DST-sicher: Tages-Arithmetik ausschliesslich über Kalenderkomponenten
    // (Dart normalisiert Überlauf auf lokale Mitternacht) — NIE Duration addieren,
    // sonst kippt das Datum bei Offsets über die Zeitumstellung (Europe/Zurich).
    final off = r.offsetAnwenden ? saisonOffsetTage : 0;
    for (final jahr in [heute.year - 1, heute.year, heute.year + 1]) {
      final start = DateTime(jahr, r.startMonat, r.startTag + off);
      final ende = DateTime(jahr, r.endMonat, r.endTag + off);
      if (heute.isAfter(ende)) continue;
      final vorhanden = regelAufgaben
          .where((a) => a.regelKey == r.key && a.saisonJahr == jahr)
          .toList();
      if (vorhanden.any((a) => a.status == 'uebersprungen' && a.volkId == null)) continue;
      if (r.intervallTage == null) {
        if (vorhanden.isNotEmpty) continue;
        if (heute.isBefore(DateTime(start.year, start.month, start.day - kVorlaufTage))) continue;
        out.add(AufgabenVorschlag(
            regel: r, fensterStart: start, fensterEnde: ende, faelligAm: ende, saisonJahr: jahr,
            beschreibung: beschreibungFuer(r, einstellungen)));
      } else {
        DateTime faellig;
        if (vorhanden.isEmpty) {
          if (heute.isBefore(DateTime(start.year, start.month, start.day - kVorlaufTage))) continue;
          faellig = heute.isBefore(start) ? start : heute;
        } else {
          final juengste = vorhanden.map((a) => _tag(a.faelligAm)).reduce((a, b) => a.isAfter(b) ? a : b);
          faellig = DateTime(juengste.year, juengste.month, juengste.day + r.intervallTage!);
          // Kalendertag-Vergleich statt difference(): eine Duration über die
          // Zeitumstellung verlöre eine Stunde und damit ggf. einen Tag.
          final vorlaufGrenze = DateTime(heute.year, heute.month, heute.day + kIntervallVorlaufTage);
          if (faellig.isAfter(vorlaufGrenze)) continue;
        }
        if (faellig.isAfter(ende)) continue;
        out.add(AufgabenVorschlag(
            regel: r, fensterStart: start, fensterEnde: ende, faelligAm: faellig, saisonJahr: jahr,
            beschreibung: beschreibungFuer(r, einstellungen)));
      }
    }
  }
  out.sort((a, b) => a.faelligAm.compareTo(b.faelligAm));
  return out;
}
