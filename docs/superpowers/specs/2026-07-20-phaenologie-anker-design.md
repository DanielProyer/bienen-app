# Phänologischer Anker (Indikatorpflanzen) — Design-Spec (v2)

**Datum:** 2026-07-20 · **Status:** in Review (v2 nach adversarialem Multi-Agent-Review) · **Modul:** 4.4 Generator (Baustein C) + Keimzelle 4.20 · **Version:** 1.17.0+38
**Anlass:** bienen.ch/BGD-Betriebskonzept taktet Bienenarbeiten an **Indikatorpflanzen-Blüte** statt fixen Daten (Recherche `../imkerei/02_Recherche/21_Betriebskonzept_Jahresplanung_BGD.md`). Löst die von A+B (Spec 2026-07-20-betriebsprofil §3.3) bewusst offengelassene **alpine Sommer-Stauchung** + die 2-Ernten-Kettenverankerung.

> **Zerlegung:** Baustein **C** von A→B→C→D. A+B (v1.16.0) machten den Generator konfigurierbar + härteten das Timing mit flachem Offset. **C** ergänzt beobachtungsgetriebene Präzision — als **Override** (nur wenn beobachtet, sonst exakt A+B-Verhalten). **D** (Ableger/Zucht-Event-Ketten, 4.16/4.17) bleibt separat.

> **v2-Änderungen (aus dem Review):** (1) **Tracht-Anker auf Ketten-Verankerung umgebaut** — die alpine Sommer-Stauchung (Ernte ~+42, Behandlung ~Ende Juli) lässt sich mit **einem** geteilten Tracht-Offset nicht treffen; die Sommer-Behandlungskette hängt daher **relativ an der beobachteten Honigernte** statt an einem eigenen Offset. (2) **Alpenrose als Hochlagen-Tracht-Zeiger** (die Tal-Zeiger Linde/Robinie/Edelkastanie wachsen nicht auf 1570 m → am Flaggschiff-Standort nicht eintragbar). (3) **Offset-Klemme ±60 Tage** + Eingabe-Plausibilisierung (Fehleingabe darf keine Pflicht-Behandlung lautlos in die falsche Jahreszeit schieben). (4) immutable, jahr-gebundener DB-CHECK. (5) diverse Härtungen (siehe §9).

## 1. Ziele & Nicht-Ziele
**Ziele:**
1. **Phänologie-Beobachtungen je Betrieb/Jahr** (2 Anker: Frühjahr + Tracht) erfassen — jahr-historisiert (Keimzelle 4.20 Blühkalender).
2. **Generator nutzt beobachtete Blüte** → Frühjahrsregeln über einen phänologischen Offset, **Sommer-Behandlungskette über Ketten-Verankerung an der Honigernte** → behebt die alpine Sommer-Stauchung; `sommerbehandlung_1` trifft endlich Ende Juli.
3. **Rückwärtskompatibel:** ohne Beobachtung identisches Verhalten wie v1.16.0 (die 149 Bestandstests bleiben grün).
4. **Sicherheitsnetz:** Fehleingaben werden geklemmt/plausibilisiert, keine still falsch terminierte Pflicht-Behandlung.
5. **Honigreinheit-Warnung** (aus A+B verschoben) — **nur bei vorhandener Tracht-Beobachtung** als präziser Hinweis.

**Nicht-Ziele (spätere Zyklen):** Per-Standort-Phänologie (volles 4.20 — hier bewusst Betriebs-Ebene; die Promotion ist **nicht rein additiv**, siehe §9); Interpolation über >2 Anker; Grad-Tage/Wetter-API; Ableger/Zucht-Event-Ketten (D); automatischer Blühkalender-Import; **Cockpit-Erinnerungskarte** (Post-v1, aus Scope genommen).

## 2. Datenmodell

### 2.1 Indikator-Katalog (Dart-Fachkonstante `phaenologie.dart`)
Muster `krankheit.dart` (const-Liste, pure). Je Zeigerpflanze: `key`, `name`, `anker` (Enum), `referenzDoy`.

**`referenzDoy` = Kalibrier-DOY:** der Tag-im-Jahr, an dem diese Pflanze am **Referenzstandort blüht, bei dem Offset 0 die Basis-Regelfenster korrekt trifft** (die Basisfenster sind Mittelland-nah kalibriert). Offset = `beobachteter Blüh-DOY − referenzDoy` = wie viel später die Phänologie am eigenen Standort läuft. **Nicht-Schaltjahr-DOY** (siehe §3.6 Schaltjahr-Toleranz). Werte sind BGD-Richtwerte → **Fachstellen-Check** (Katalog-Kommentar).

```dart
enum PhaenoAnker { fruehjahr, tracht }

class Indikatorpflanze {
  final String key;
  final String name;
  final PhaenoAnker anker;
  final int referenzDoy; // Kalibrier-DOY am Referenzstandort (Nicht-Schaltjahr)
  const Indikatorpflanze({required this.key, required this.name, required this.anker, required this.referenzDoy});
}

const kIndikatorpflanzen = <Indikatorpflanze>[
  // Frühjahr — treibt die Frühjahrs-/Aufbauregeln (Offset). Alle drei sind bis in Hochlagen beobachtbar.
  Indikatorpflanze(key: 'salweide',     name: 'Sal-Weide',    anker: PhaenoAnker.fruehjahr, referenzDoy: 74),  // ~15.3.
  Indikatorpflanze(key: 'kirschbluete', name: 'Kirschblüte',  anker: PhaenoAnker.fruehjahr, referenzDoy: 110), // ~20.4.
  Indikatorpflanze(key: 'loewenzahn',   name: 'Löwenzahn',    anker: PhaenoAnker.fruehjahr, referenzDoy: 115), // ~25.4. (Default)
  // Tracht — treibt die Honigernte + (per Kette) die Varroa-Sommerbehandlung.
  // Hochlagen-Zeiger zuerst (in Arosa real beobachtbar), dann Tal-Zeiger für tiefere Mandanten.
  Indikatorpflanze(key: 'alpenrose',     name: 'Alpenrose',            anker: PhaenoAnker.tracht, referenzDoy: 160), // Hochlagen-Haupttracht-Marker (Default)
  Indikatorpflanze(key: 'bergwiesen',    name: 'Bergwiesen-Vollblüte', anker: PhaenoAnker.tracht, referenzDoy: 160),
  Indikatorpflanze(key: 'weidenroeschen',name: 'Weidenröschen',        anker: PhaenoAnker.tracht, referenzDoy: 175),
  Indikatorpflanze(key: 'linde',         name: 'Linde',                anker: PhaenoAnker.tracht, referenzDoy: 176), // Tal (~25.6.)
  Indikatorpflanze(key: 'edelkastanie',  name: 'Edelkastanie',         anker: PhaenoAnker.tracht, referenzDoy: 182), // Tal (~1.7.)
];
const kDefaultIndikator = {PhaenoAnker.fruehjahr: 'loewenzahn', PhaenoAnker.tracht: 'alpenrose'};
Indikatorpflanze? indikatorVon(String? key) { /* Lookup, null-tolerant */ }
```

**Warum Alpenrose als Default-Tracht-Zeiger:** Der Arosa-Trachtkalender (`../imkerei/02_Recherche/02_Jahresablauf_Imker_Arosa_1570m.md:33-48, :231-233`) weist die **Alpenrose (Blüte ab Mitte Juni) als Haupttracht-Marker** aus — der einzige in 1570 m real beobachtbare Tracht-Zeiger. Die Tal-Zeiger (Linde/Edelkastanie) bleiben für tiefer gelegene Mandanten im Katalog (Mandantenfähigkeit). `referenzDoy(alpenrose)=160` ist so kalibriert, dass die **normale Arosa-Blüte (~Mitte Juni) einen Offset nahe dem Frühjahrs-Offset ergibt** (Ernte Mitte Juli) — Feinwert unter Fachstellen-Check.

**Offset-Klemme:** Der aus einer Beobachtung abgeleitete Offset wird **auf ±60 Tage geklemmt** (§3.3) — Defense-in-Depth gegen Fehleingaben.

### 2.2 Migration J01 (`phaenologie_beobachtungen`, normale CRUD)
```sql
create table if not exists public.phaenologie_beobachtungen (
  id uuid primary key default gen_random_uuid(),
  jahr int not null,
  anker text not null check (anker in ('fruehjahr','tracht')),
  indikator_key text not null,
  blueh_am date not null,
  betrieb_id uuid not null default private.aktive_betrieb_id()
    references public.betriebe(id) on delete cascade,
  created_by uuid, updated_by uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (betrieb_id, jahr, anker),
  constraint phaeno_jahr_chk check (jahr between 2020 and 2100),
  -- immutable + bindet blueh_am ans jahr (verhindert Zukunfts-/Jahr-Drift-Eingabe in EINEM CHECK):
  constraint phaeno_blueh_im_jahr_chk check (blueh_am >= make_date(jahr,1,1) and blueh_am <= make_date(jahr,12,31))
);
alter table public.phaenologie_beobachtungen enable row level security;
revoke all on public.phaenologie_beobachtungen from anon, public;
grant select, insert, update, delete on public.phaenologie_beobachtungen to authenticated;
-- KEIN Zusatz-Index: unique(betrieb_id,jahr,anker) liefert das (betrieb_id)/(betrieb_id,jahr)-Präfix bereits.
-- set_row_actor + set_updated_at Trigger (Standard-Muster).
-- RLS: sel=meine_betrieb_ids; ins/upd/del=kann_schreiben(betrieb_id). Kein RPC, kein Errcode-Block.
-- Betriebs-Ebene (kein standort_id) — indikator_key + Tabelle sind für 4.20 WIEDERVERWENDBAR (nicht: Promotion trivial; siehe §9).
-- ROLLBACK (Ops): drop table public.phaenologie_beobachtungen;
```
- **CHECK immutable + jahr-gebunden:** `make_date(...)` ist IMMUTABLE (dump/restore-sicher), bindet `blueh_am` ans `jahr` und schliesst Zukunfts-/Jahr-Drift-Eingaben aus — ersetzt das frühere `current_date`-basierte + separate jahr-Check (Review: DB-Lupe).
- **Kein `idx_phaeno_betrieb_jahr`:** redundant zum Unique-Index (Review: DB-Lupe).
- **Upsert-Semantik (verbindlich):** PostgREST `.upsert(payload, onConflict: 'betrieb_id,jahr,anker')`. `toUpsertJson` liefert **NUR** `{jahr, anker, indikator_key, blueh_am}` — **betrieb_id und id werden weggelassen** (nicht `null`), damit der Spalten-Default `private.aktive_betrieb_id()` greift (sonst NOT-NULL-Bruch). `PhaenoBeobachtung`-Modell trägt betrieb_id/id gar nicht.
- **indikator_key↔anker-Guard:** kein DB-FK (Katalog Dart-only). `toUpsertJson` **asserted `indikatorVon(indikatorKey).anker == anker`** (+ Test) — verhindert stillen Fehl-Offset (Review: DB-Lupe).

## 3. Generator-Integration (Override + Ketten-Anker)

### 3.1 Prinzip
Phänologie **überschreibt** den A+B-Baseline **nur wenn beobachtet**; sonst exakt v1.16.0-Verhalten. Zwei Mechanismen:
- **Offset-Override (Frühjahr + Honigernte):** Regel-Fenster wird um den phänologischen Offset der Phase verschoben (wenn beobachtet), sonst flacher A+B-Offset.
- **Ketten-Anker (Sommer-Behandlungskette):** Regel-Fenster wird **relativ an einer Anker-Regel** (der beobachteten Honigernte) berechnet — nur wenn eine Tracht-Beobachtung existiert; sonst A+B-Baseline (kalenderfix).

### 3.2 SaisonRegel-Felder (neu)
```dart
// bestehend: offsetAnwenden (A+B-Baseline-Offset), nurBeiVermehrung, nurBeiAnzahlErnten …
PhaenoAnker? phase;         // Offset-Override-Phase (fruehjahr|tracht); null = kein Offset-Override
String? ankerRegelKey;      // Ketten-Anker: Key der Regel, an die diese Regel relativ hängt (nur bei Tracht-Beobachtung)
int ankerVersatzStartTage;  // Fensterstart = AnkerEnde + Versatz (Default 0)
int ankerVersatzEndeTage;   // Fensterende  = AnkerEnde + Versatz (Default 0)
```
Der **dynamische Letzte-Ernte-Anker** (`honigernte_sommer` bei 2 Ernten, sonst `honigernte`) wird im Generator aufgelöst (Sentinel-Key `'__letzte_ernte'`), damit die Behandlung der **letzten** Ernte folgt.

### 3.3 effektiverOffset (pure, in `saison_regeln.dart`)
```dart
int effektiverOffset({
  required SaisonRegel regel,
  required int saisonJahr,
  required List<PhaenoBeobachtung> beobachtungen,
  required int flatOffset,
}) {
  final phase = regel.phase;
  if (phase != null) {
    final b = _beobachtungFuer(beobachtungen, saisonJahr, phase); // Inline-Helper, kein package:collection
    final ind = b == null ? null : indikatorVon(b.indikatorKey);
    if (b != null && ind != null && ind.anker == phase) {          // anker-Guard
      final off = _doy(b.bluehAm) - ind.referenzDoy;
      return off.clamp(-kMaxOffsetTage, kMaxOffsetTage);           // ±60 Klemme
    }
  }
  return regel.offsetAnwenden ? flatOffset : 0;                    // A+B-Baseline
}
```
`kMaxOffsetTage = 60`. `_doy(date)` = Tag im Jahr (schaltjahr-tolerant). `_beobachtungFuer`/`_firstOrNull` = Inline-Helper (kein `firstWhereOrNull`/`package:collection` → kein `depend_on_referenced_packages`-Lint).

### 3.4 Ketten-Anker im Generator
Für eine Regel mit `ankerRegelKey != null` **und vorhandener Tracht-Beobachtung**:
1. Anker-Regel auflösen (`'__letzte_ernte'` → `honigernte_sommer` wenn `anzahlErnten==2`, sonst `honigernte`).
2. Effektives **Anker-Ende** berechnen (Basis-Ende der Anker-Regel + deren effektiver Offset, selbe Kalenderkomponenten-Arithmetik, DST-sicher).
3. Eigenes Fenster = `[AnkerEnde + ankerVersatzStartTage, AnkerEnde + ankerVersatzEndeTage]`.

**Ohne Tracht-Beobachtung** verhält sich die Regel wie A+B (eigenes Basisfenster + `offsetAnwenden?flat:0`). So bleibt die Rückwärtskompatibilität erhalten und die Kette greift erst, wenn die Honigernte phänologisch verankert ist.

**Ordnung strukturell garantiert:** Da `gemuelldiagnose_sommer`, `sommerbehandlung_1` mit **steigendem Versatz** an derselben (letzten) Ernte hängen, gilt `honigernte(_sommer) ≤ gemuelldiagnose_sommer ≤ sommerbehandlung_1` per Konstruktion — für jeden Anker-Zeitpunkt.

### 3.5 Regel-Zuordnung
- **`phase: fruehjahr`** (Offset-Override; `offsetAnwenden:true` als Fallback): erste_durchsicht, fruehjahrsdurchsicht, wabenhygiene, drohnenrahmen_einsetzen, drohnenschnitt, brutraum_erweitern, schwarmkontrolle, serbelvoelker_fruehjahr, jungvoelker_bilden, koeniginnen_vermehren, varroakontrolle_fruehsommer, trachtluecke_notfuetterung.
- **`phase: tracht`** (Offset-Override; `offsetAnwenden:true`): **honigraum_aufsetzen** (Tracht-Onset → an Tracht koppeln, behebt die Frühjahr↔Tracht-Inversion, Review: Generator-Lupe), **honigernte** (Haupt-/erste Ernte).
- **Ketten-Anker** (`ankerRegelKey`, greift **nur mit Tracht-Beobachtung**; die A+B-Baseline jeder Regel — `offsetAnwenden` + Basisfenster — bleibt für den beobachtungslosen Fall **exakt wie v1.16.0**):
  - `honigernte_sommer` → Anker `honigernte`, Versatz ~+35..+45 (2. Ernte; `nurBeiAnzahlErnten:2`). Baseline: kalenderfix (`offsetAnwenden:false`, wie v1.16.0).
  - `gemuelldiagnose_sommer` → Anker `'__letzte_ernte'`, Versatz ~0..+3 (Milbenkontrolle nach Abernten, direkt vor der Behandlung). Baseline: **`offsetAnwenden:true`, Basis 6.6.–20.6. unverändert** (v1.16.0) — der Kettenanker überschreibt nur bei Beobachtung.
  - `sommerbehandlung_1` → Anker `'__letzte_ernte'`, Versatz ~+5..+12 (**Behandlung direkt nach der letzten Ernte → Ende Juli in Arosa**). Baseline: kalenderfix (`offsetAnwenden:false`, 20.7.–15.8. wie v1.16.0).

  > **Rückwärtskompatibilität exakt:** Ohne Tracht-Beobachtung ist jede Kettenregel = ihr v1.16.0-Verhalten (eigenes Basisfenster + `offsetAnwenden?flat:0`); der Kettenanker ist ein reiner Override. Damit bleiben die 149 Bestandstests grün.
- **`phase: null`, kein Anker** (kalenderfix, unverändert): alle Herbst-/Winter- + Vorfrühling-Regeln (sommerbehandlung_2, auffuetterung_abschliessen, futterkontrolle_herbst, maeuseschutz_*, winterfest, spechtschutz, brutfreiheit, oxalsaeure_winter, umweiselung_pruefen, serbelvoelker_herbst, wabenerneuerung_herbst, winterbehandlung_erfolgskontrolle, werkstatt_winter, futtervorrat_winter, gemuelldiagnose_fruehjahr, maeuseschutz_entfernen, fluglochunterlage_beobachten).

Konkrete Versatz-Tageswerte (§3.5) werden im **Plan** endgültig fixiert (Fachstellen-Check) — die Bandbreiten hier sind Richtwerte.

### 3.6 Generator-Signatur & Provider
```dart
List<AufgabenVorschlag> anstehendeVorschlaege({
  required DateTime stichtag,
  required int saisonOffsetTage,
  required List<Aufgabe> regelAufgaben,
  required int anzahlAktiveVoelker,
  BetriebsEinstellungen einstellungen = const BetriebsEinstellungen.leer(),
  List<PhaenoBeobachtung> beobachtungen = const [],   // NEU, Default leer → 149 Tests unverändert
})
```
`vorschlaegeProvider` reicht `beobachtungen:` aus einem neuen `phaenologieProvider` durch; dieser in `AuthController._datenNeuLaden()` invalidieren (Gotcha 1). **Schaltjahr-Toleranz:** `referenzDoy` ist als Nicht-Schaltjahr-DOY definiert; in Schaltjahren driftet der Offset für Anker nach dem 29.2. um max. 1 Tag — dokumentiert im Katalog-/Funktionskommentar (operativ vernachlässigbar, kein Code-Fix).

## 4. Erfassungs-UX + Honigreinheit-Warnung

### 4.1 Phänologie-Sektion auf `/einstellungen`
Eigenständiges Sub-Widget mit **eigenem Inline-Save** (unabhängig von `_formKey`, **kein `context.go`**), liest `phaenologieProvider` per `watch` (eigenes Init, nicht das `_initialisiert`-Muster der Betriebseinstellungen):
- Zwei Zeilen (Frühjahrs-Anker, Tracht-Anker); je Zeile: Pflanzen-Dropdown (Katalog nach `anker` gefiltert, Default Löwenzahn/Alpenrose) + Datepicker (laufendes Saisonjahr) + Speichern.
- Upsert je Anker fürs laufende Jahr (`onConflict: betrieb_id,jahr,anker`; `toUpsertJson` ohne betrieb_id/id; anker-Guard). Fehlerfest (try/catch + Snackbar), invalidiert `phaenologieProvider`.
- **Eingabe-Plausibilisierung:** liegt `blueh_am` mehr als ~±45 Tage von `referenzDoy` entfernt, weicher Hinweis „Ungewöhnliches Blühdatum — bitte prüfen" (kein Block). Zusammen mit der ±60-Offset-Klemme (§3.3) das zweifache Sicherheitsnetz.
- **Kein separater viewer-Guard:** die Einstellungen-Seite ist bereits ganzseitig schreibgesperrt (`darfSchreibenProvider`) — ein Sektions-Guard wäre toter Code (Review: Architektur-Lupe).
- Hilfetext: „Wann die Zeigerpflanze an deinem Standort blüht, verschiebt die Saisonaufgaben präziser als das feste Offset."

### 4.2 Honigreinheit-Warnung (Fütterungs-Formular) — nur bei Tracht-Beobachtung
Pure Funktion in `phaenologie.dart` (bekommt das Fenster als Parameter, importiert **nicht** `kSaisonRegeln` → kein Zyklus):
```dart
bool warntHonigreinheit({
  required String futterart, required String zweck, required DateTime datum,
  required (DateTime start, DateTime ende)? trachtFenster, // null ⇒ keine Tracht-Beobachtung ⇒ keine Warnung
});
```
- **Feuert nur, wenn eine Tracht-Beobachtung existiert** (`trachtFenster != null`) — ohne Signal keine Warnung (kein Präzisions-Versprechen; passt zur A+B-Begründung „braucht Tracht-Signal"). Review: Scope-Lupe.
- Regel: `futterart ∈ {zuckerwasser_1_1, zuckerwasser_3_2, invertsirup, futterteig}` **und** `datum ∈ trachtFenster`.
  - **Ableger-Schutz:** `zuckerwasser_1_1` mit `zweck` = Jungvolk-/Ableger-Aufbau löst **nicht** aus (kein Honigraum → keine Kontamination).
  - **Notfütterung:** statt Voll-Unterdrückung ein **weicherer** Hinweis „Honig aus dieser Periode nicht als reinen Honig ernten" (BGD: Notfütterung verfälscht bei aufliegendem Honigraum ebenfalls).
- **Fenster:** `trachtFenster` = `[honigraum_aufsetzen-Start (effektiv) … letzte-Ernte-Ende (effektiv)]`, im Generator/Provider aus den bereits berechneten effektiven Fenstern abgeleitet (nicht doppelt gerechnet). **2 Ernten:** Ende = `honigernte_sommer`-Ende. So deckt das Fenster die ganze Tracht inkl. Sommertracht ab (Review: Architektur-Lupe).
- Anzeige: weicher Inline-Hinweis (kein Block). `fuetterung_form_page` **prewarmt** `phaenologieProvider` + `betriebsEinstellungenProvider` (analog material/voelker), damit die Warnung deterministisch rechnet.

## 5. Architektur & Dateien
```
supabase/migrations/J01_phaenologie_beobachtungen.sql              (neu)
lib/features/phaenologie/domain/phaenologie.dart                   (neu: Katalog, PhaenoAnker, indikatorVon, _doy, warntHonigreinheit, kMaxOffsetTage — importiert NICHT aufgaben/domain)
lib/features/phaenologie/domain/beobachtung.dart                   (neu: PhaenoBeobachtung + fromJson/toUpsertJson[ohne betrieb_id/id, anker-Guard])
lib/features/phaenologie/domain/phaenologie_gateway.dart           (neu: abstrakt)
lib/features/phaenologie/data/{fake,supabase}_phaenologie_gateway.dart (neu)
lib/features/phaenologie/presentation/providers/phaenologie_provider.dart (neu)
lib/features/aufgaben/domain/saison_regeln.dart                    (Modify: SaisonRegel +phase/ankerRegelKey/ankerVersatz*, effektiverOffset+Ketten-Anker+Klemme im Generator, Signatur +beobachtungen; importiert phaenologie EINSEITIG)
lib/features/aufgaben/presentation/providers/aufgaben_provider.dart (Modify: beobachtungen durchreichen; trachtFenster ableiten)
lib/features/auth/presentation/auth_providers.dart                (Modify: phaenologieProvider in _datenNeuLaden)
lib/features/einstellungen/pages/einstellungen_page.dart          (Modify: Phänologie-Sub-Widget mit eigenem Inline-Save)
lib/features/fuetterung/presentation/pages/fuetterung_form_page.dart (Modify: Honigreinheit-Hinweis + Prewarm)
+ Tests
```
**Import-Richtung (verbindlich, kein Zyklus):** `saison_regeln.dart → phaenologie.dart` (einseitig, für Katalog/PhaenoAnker/PhaenoBeobachtung). `effektiverOffset` + Ketten-Logik leben in `saison_regeln.dart` (haben SaisonRegel/kSaisonRegeln). `warntHonigreinheit`/`trachtFenster`-Verbraucher bekommen Fenster als **Parameter**.

## 6. Tests
- **`effektiverOffset`:** Beobachtung → `(_doy−referenzDoy)` geklemmt ±60; anker-Mismatch (key≠phase) → Fallback; fehlt → `flatOffset`/0; phase=null → A+B.
- **Offset-Klemme / Fehleingabe (KRITISCH, Safety):** implausibles `blueh_am` (z. B. Alpenrose 5.2.) → Offset geklemmt; `sommerbehandlung_1` bleibt im Behandlungsfenster (Sommer), rutscht **nicht** in März.
- **Rückwärtskompatibilität (KRITISCH):** `beobachtungen: const []` → Generator liefert identische Vorschläge wie v1.16.0; 149 Bestandstests bleiben grün.
- **Ketten-Anker:** mit Tracht-Beobachtung (Alpenrose Mitte Juni) landet `honigernte` ~Mitte Juli und `sommerbehandlung_1` ~Ende Juli (nicht 15.8.); `honigernte_sommer ≤ sommerbehandlung_1` (2 Ernten); dynamischer `__letzte_ernte`-Anker: 1 Ernte → honigernte, 2 Ernten → honigernte_sommer.
- **Ordnungs-Invariante:** `honigernte(_sommer) ≤ gemuelldiagnose_sommer ≤ sommerbehandlung_1` (geteilter Kettenanker, steigender Versatz).
- **Cross-Phasen-Ordnung bei TEIL-Beobachtung (Review: Scope-Lupe):** nur Frühjahrs-Anker beobachtet (Tracht Fallback) → `honigraum_aufsetzen.fällig ≤ honigernte.fällig` (durch phase=tracht auf honigraum_aufsetzen + Klemme abgesichert); Gegenrichtung.
- **`warntHonigreinheit`:** ohne Tracht-Beobachtung (`trachtFenster==null`) → nie; mit Fenster: Zucker/Futterteig im Fenster → true; Ableger-`zuckerwasser_1_1` → false; Notfütterung → weicher Hinweis; ausserhalb → false; 2-Ernten-Fenster deckt Sommertracht.
- **Katalog-Invarianten:** je anker ≥1 Pflanze, Default-Keys existieren + `anker` stimmt, referenzDoy 1–366; **anker-Guard** in `toUpsertJson` (tracht-key auf fruehjahr-anker → Assertion).
- **Gateway/Provider:** Fake-CRUD (upsert je jahr/anker; toUpsertJson ohne betrieb_id/id), Provider-Roundtrip, `_datenNeuLaden`-Invalidierung.
- **DOY:** Schaltjahr-Toleranz (`_doy(29.2.)` kein Crash).

## 7. Deploy
Version **1.17.0+38** (Minor). Migration J01 auf Produktion `dcdcohktxbhdxnxjvcyp` (separat freigabepflichtig). `get_advisors(security)` → 0 neue Findings. Kein neuer Errcode-Block (BA050 frei). `bash deploy.sh` (stehende Freigabe nach grünen Tests).

## 8. decision-log / Roadmap
- **D-49 (neu):** Tracht-Anker als **Ketten-Verankerung** (Behandlung folgt der beobachteten Ernte) statt geteiltem Tracht-Offset — löst die alpine Sommer-Stauchung; Alpenrose als Hochlagen-Default-Zeiger. Grund: Ernte (~+42) und Behandlung (~Ende Juli) sind mit einem Offset nicht gleichzeitig treffbar.
- **4.20-Vermerk:** Betriebs-Ebene ist v1-ausreichend; Per-Standort-Promotion ist **nicht rein additiv** (Unique-Rework `+standort_id`, NULL-Distinct-/Fallback-Semantik) — als bekannte spätere Migration im decision-log notieren.

## 9. Review-Korrekturen (v1→v2, Kurzregister)
| # | Lupe | Korrektur |
|---|---|---|
| B1 | fachlich (Blocker) | Alpenrose/Bergwiesen/Weidenröschen als Hochlagen-Tracht-Zeiger; referenzDoy als Kalibrier-DOY definiert |
| B2 | scope (Blocker) | Offset-Klemme ±60 + Eingabe-Plausibilisierung + Safety-Test (keine Behandlung in falscher Jahreszeit) |
| W1 | generator | Sommer-Stauchung via Ketten-Anker (Behandlung folgt letzter Ernte) statt geteiltem Tracht-Offset |
| W2 | generator | honigraum_aufsetzen → phase=tracht (behebt Frühjahr↔Tracht-Inversion) + Cross-Phasen-Ordnungstest |
| W3 | generator | firstWhereOrNull → Inline-Helper (kein package:collection / Lint) |
| W4 | db | CHECK immutable + jahr-gebunden (`make_date`), ersetzt current_date + separaten jahr-Check |
| W5 | db | Upsert verbindlich: onConflict-Target + toUpsertJson ohne betrieb_id/id |
| W6 | architektur | Import-Zyklus aufgelöst (effektiverOffset in saison_regeln.dart, Fenster als Param) |
| W7 | architektur | Einstellungen: eigenständiges Phaeno-Sub-Widget mit Inline-Save; redundanter viewer-Guard raus |
| W8 | architektur | trachtFenster: 2-Ernten-Ende + kein Doppel-Offset; aus bereits berechneten Fenstern |
| W9 | scope | Honigreinheit nur bei Tracht-Beobachtung; Ableger-Schutz; Notfütterung weicher Hinweis; Futterteig ergänzt |
| N1 | db | idx_phaeno_betrieb_jahr gestrichen (redundant) |
| N2 | db | indikator_key↔anker-Assertion in toUpsertJson + Test |
| N3 | generator | Schaltjahr: referenzDoy als Nicht-Schaltjahr-DOY dokumentiert |
| N4 | architektur | Fütterungs-Formular prewarmt phaenologie/einstellungen-Provider |
| N5 | scope | Cockpit-Erinnerungskarte aus v1 genommen (Post-v1) |
| N6 | scope | 4.20-Promotion als nicht-additiv im decision-log vermerkt |

## 10. Offene Punkte (Plan)
- Exakte Versatz-Tageswerte der Kettenregeln (§3.5) + `referenzDoy`-Feinwerte (Alpenrose/Robinie) — Fachstellen-Check.
- Konkrete `trachtFenster`-Fensterrechnung aus den effektiven Regelfenstern (Provider-Ebene).
- Genaue Formulierung der `zweck`-Fälle für den Ableger-Schutz der Honigreinheit-Warnung.
