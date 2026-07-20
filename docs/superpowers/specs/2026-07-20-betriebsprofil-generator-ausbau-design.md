# Betriebsprofil & Generator-Ausbau — Design-Spec (v1)

**Datum:** 2026-07-20 · **Status:** in Review · **Module:** 4.4 Aufgaben-Generator + F4 Betriebs-Einstellungen (+ 4.6-Andockung)
**Anlass:** bienen.ch/BGD-Auswertung (`../imkerei/02_Recherche/21_Betriebskonzept`, `22_Varroa`, `25_Vermehrung`, `27_Gute_Praxis`; Findings `docs/bienen-ch-findings.md`, D-41). Erste Sub-Spec der Zerlegung **A+B** (Fundament); Phänologie (C) und Ableger/Zucht-Event-Ketten (D=4.16/4.17) folgen als eigene Zyklen.

> **Scope-Abgrenzung:** Diese Spec macht den Generator **konfigurierbar** (Strategie-Weichen), **härtet das Timing** (Ordnungs-Garantie, 2. Ernte) und **füllt Regel-Lücken** — alles im bestehenden **Fenster+Offset-Modell**. Sie führt **KEINEN** phänologischen Anker und **KEINE** Event-getriggerten Folgeaufgaben ein (bewusst C bzw. D). Die feine alpine Sommer-Präzision bleibt bis C approximativ — hier wird nur die **Reihenfolge garantiert** und die **Mittelland-Korrektheit** hergestellt.

## 1. Ziele & Nicht-Ziele
**Ziele:**
1. **Betriebsprofil bearbeitbar** (F4-Settings-Seite) — heute nur per Ops-Seed. Exponiert `saison_offset_default_tage`, `winterfutter_ziel_kg` + 3 neue Strategie-Weichen.
2. **Generator konfigurierbar:** die Weichen filtern/formen, welche Regeln erscheinen.
3. **Timing-Bugs behoben:** Post-Ernte-Kette kann nie vor der Ernte auslösen; 2. Ernte für Mehrmandantenfähigkeit.
4. **Regel-Lücken gefüllt** (Vermehrung, Serbelvölker, Trachtlücke, Fluglochbeobachtung, Wabenerneuerung, Notbehandlung, Winterbehandlungs-Erfolgskontrolle, Umweiselung).
5. **4.6-Andockung:** 20-kg-BGD-Warnschwelle + futterart-Konzentrations-Enum.

**Nicht-Ziele (spätere Specs):** Phänologischer Indikatorpflanzen-Anker (C); Honigreinheit-Warnung (braucht Tracht-Signal → C); Ableger/Zucht-Event-Ketten mit relativen Folgeaufgaben (D=4.16/4.17); Onboarding-Assistent (F5); Feinabbildung der alpinen Sommer-Stauchung (C).

## 2. Betriebsprofil (Datenmodell + Settings-Seite)

### 2.1 Migration I01 (`betriebs_einstellungen`, additive Spalten)
```sql
alter table public.betriebs_einstellungen
  add column if not exists anzahl_ernten int not null default 1
    check (anzahl_ernten in (1, 2)),
  add column if not exists sommerbehandlung_methode text not null default 'ameisensaeure'
    check (sommerbehandlung_methode in ('ameisensaeure', 'biotechnisch', 'beide')),
  add column if not exists vermehrung_aktiv boolean not null default false;
```
Reine Spalten-Ergänzung (keine Datenmigration). Arosa-Defaults passen (1 Ernte, Ameisensäure, keine Vermehrung). **UPDATE-Policy: bereits vorhanden** (Review-Verifikation): `betriebs_einstellungen_upd_writer` (C01, `using`/`with check` `kann_schreiben(betrieb_id)`) + `grant update to authenticated` existieren — I01 legt **nur die drei Spalten** an, keine Policy. `get_advisors(security)` → 0 neue Findings erwartet. **Optionales Compliance-Hardening (Review, nice):** die amtlichen Felder `imker_identnummer`/`kanton` liegen unter dem table-weiten UPDATE-Grant; sie haben aktuell keine Schreib-UI (null). Als Härtung kann I01 den Grant auf die 5 editierbaren Spalten einschränken (`revoke update … ; grant update(saison_offset_default_tage, winterfutter_ziel_kg, anzahl_ernten, sommerbehandlung_methode, vermehrung_aktiv) …`) — im Plan abwägen (Ops-Seed-Verträglichkeit prüfen), nicht blockierend.

### 2.2 Dart-Modell
`BetriebsEinstellungen` ([betriebs_einstellungen.dart](../../lib/features/voelker/domain/betriebs_einstellungen.dart)) +3 Felder: `anzahlErnten` (int, Default 1), `sommerbehandlungMethode` (String, Default 'ameisensaeure'), `vermehrungAktiv` (bool, Default false); `fromJson` + `BetriebsEinstellungen.leer()` mit denselben Defaults. **Neu:** `toUpdateJson()` (die editierbaren Felder: saison_offset_default_tage, winterfutter_ziel_kg, anzahl_ernten, sommerbehandlung_methode, vermehrung_aktiv).

### 2.3 Settings-Seite (`/einstellungen`, neu)
- **Erreichbar** über neue Projekt-Kachel **„Betriebs-Einstellungen"** (Icon `tune`) in `projekt_page.dart`.
- **Felder** (Formular): Saison-Offset (int, Hinweis „alpin ~+42 Tage später als Mittelland"), Winterfutter-Ziel kg (num > 0, **Warnung wenn < 20**: „unter BGD-Minimum 20 kg"), Anzahl Ernten (SegmentedButton 1/2), Sommerbehandlung-Methode (SegmentedButton Ameisensäure/biotechnisch/beide), Vermehrung aktiv (SwitchListTile).
- **Rollen-Guard** im build: viewer → read-only Ansicht (Gotcha 5).
- **Speichern:** `EinstellungenNotifier.speichern(BetriebsEinstellungen)` → Gateway-Update `betriebs_einstellungen`. **Verbindlich `update(toUpdateJson()).eq('betrieb_id', <aktive_betrieb_id>)`** (Review-Härtung, Defense-in-depth: expliziter Filter zusätzlich zur RLS, statt „ganze Tabelle" — schützt gegen den Eigen-Scope-Fall, falls ein User je mehreren Betrieben angehört). `toUpdateJson()` enthält nur die 5 editierbaren Felder (kein `betrieb_id`). Cross-Tenant-Leak strukturell ausgeschlossen (`kann_schreiben`-USING filtert serverseitig). Direkt-Update ist Repo-Standard (auch fuetterungen-Storno, gesundheit etc.) — keine RPC nötig. Fehlerfest (try/catch + Snackbar). Nach Erfolg `ref.invalidateSelf()` → Generator + Winterfutter-Balken rechnen sofort neu.
- **Gateway:** `VoelkerGateway` bekommt `einstellungenSpeichern(BetriebsEinstellungen)` (Fake + Supabase).

## 3. Generator-Ausbau

### 3.1 `SaisonRegel` — neue Gating-/Form-Felder
```dart
class SaisonRegel {
  // ... bestehend (key, titel, beschreibung, kategorie, ebene, Fenster, offsetAnwenden, intervallTage, aktionRoute)
  final bool nurBeiVermehrung;        // default false — Regel nur wenn vermehrung_aktiv
  final int? nurBeiAnzahlErnten;      // z. B. 2 — Regel nur wenn anzahl_ernten == Wert (null = immer)
}
```
`sommerbehandlung_methode` formt **nicht** über ein Flag am Regel-Objekt, sondern der Generator wählt zwischen **Methoden-Varianten** derselben Regel (siehe 3.3).

### 3.2 Generator-Signatur
```dart
List<AufgabenVorschlag> anstehendeVorschlaege({
  required DateTime stichtag,
  required int saisonOffsetTage,
  required List<Aufgabe> regelAufgaben,
  required int anzahlAktiveVoelker,
  BetriebsEinstellungen einstellungen = const BetriebsEinstellungen.leer(),   // NEU, DEFAULT
})
```
**Default-Parameter (Review-Finding):** `einstellungen` bekommt den Default `const BetriebsEinstellungen.leer()` (bereits `const`) — sonst brechen alle **14 bestehenden `anstehendeVorschlaege`-Aufrufe** in `test/features/aufgaben/generator_test.dart` zur Compile-Zeit. Filter-Logik: Regel überspringen, wenn `nurBeiVermehrung && !einstellungen.vermehrungAktiv` **oder** `nurBeiAnzahlErnten != null && einstellungen.anzahlErnten != nurBeiAnzahlErnten`. `vorschlaegeProvider` reicht `einstellungen` (via `betriebsEinstellungenProvider`) explizit durch; `saisonOffsetTage` = `einstellungen.saisonOffsetDefaultTage`.

> **Test-Audit (Review-Finding):** Die Änderung von `gemuelldiagnose_sommer` (Fenster 1.–15.7. → 6.6.–20.6.) erfordert, alle Bestandstest-Assertions zu diesem Key zu prüfen. Der Test „Fenster ohne Offset … am 19.07." (`sommerbehandlung_1` aktiv) **bleibt grün**, weil `sommerbehandlung_1` NICHT geändert wird (v2-Entscheid). Der Plan listet die Test-Anpassung explizit als Schritt (nicht nur „Bestand grün").

### 3.3 Timing-Härtung (v2 — nach adversarialem Review überarbeitet)
**Entscheid nach Review:** Der Ordnungs-Bug wird **minimal-invasiv** behoben — NUR `gemuelldiagnose_sommer` wird offset-anchored, `sommerbehandlung_1` **bleibt kalenderfix Arosa-getunt**. Grund: Der Offset-Umbau von `sommerbehandlung_1` (verworfene v1) hätte (a) den einzigen Live-Mandanten Arosa **verschlechtert** (Behandlung ~11 Tage später, Winterbienen-Risiko) und (b) den 2-Ernten-Pfad **fachlich falsch** gemacht (Ameisensäure vor der 2. Ernte = Honigkontamination). Die Mittelland-Sommer-Präzision + der rule-to-rule-Anker gehören zu **C (Phänologie)**, wo sie exakt lösbar sind.

- **`gemuelldiagnose_sommer` → `offsetAnwenden: true`, Basis 6.6.–20.6.** (statt kalenderfix 1.–15.7.). Behebt den realen Bug: heute fällt die Diagnose (fällig 15.7.) für Arosa (+42) vor das Ernte-Ende (honigernte fällig 17.7.); neu fällig 1.8. (20.6.+42) → **nach** der Ernte. Diagnose ist **nicht-invasiv** (Windel-Messung), darf also auch bei aufgesetztem Honigraum laufen — kein Kontaminationsrisiko.
- **`sommerbehandlung_1` bleibt UNVERÄNDERT** (kalenderfix 20.7.–15.8.). Keine Arosa-Regression; und weil der Behandlungs-Start (20.7.) ≥ dem Ende der 2. Ernte (`honigernte_sommer`, Mittelland-Basis-Ende 20.7.) liegt, wird **auch der 2-Ernten-Fall korrekt** (Ameisensäure erst nach der letzten Ernte).
- **`startfuetterung` bleibt kalenderfix** (15.–31.7.; G6: „kein Änderungsbedarf") — für Arosa keine Fälligkeits-Inversion (honigernte fällig 17.7. ≤ startfuetterung fällig 31.7.); als bewusste Näherung dokumentiert (Fenster-Öffnung 15.7. ~2 Tage vor Ernte-Deadline, unverbindlicher Vorschlag).
- **Herbst-/Winterregeln bleiben kalenderfix** (alpin früher — positiver Offset wäre richtungsverkehrt). **⚠️ Betrifft auch die NEUEN Herbst-Regeln** `umweiselung_pruefen`, `serbelvoelker_herbst`, `wabenerneuerung_herbst` → **offset=nein** (siehe 3.4, korrigiert).
- **Invarianten-Tests** (Task-Pflicht, Offset ∈ {0, 42}):
  1. 1-Ernte: `honigernte.fällig ≤ gemuelldiagnose_sommer.fällig ≤ sommerbehandlung_1.fällig`.
  2. 2-Ernten (`anzahl_ernten=2`): zusätzlich `honigernte_sommer.fällig ≤ sommerbehandlung_1.fällig` (Behandlung nie vor der letzten Ernte).
- **Bekannte Flat-Offset-Grenze (→ C):** `gemuelldiagnose_sommer` (offset) liegt bei 2 Ernten vor `honigernte_sommer` — unkritisch, weil nicht-invasiv (ggf. nach der Ernte erneut messen). Die exakte alpine Sommer-Terminierung von `sommerbehandlung_1` (heute Arosa-getunt) und die 2-Ernten-Kettenverankerung löst erst C phänologisch.

### 3.4 Neue/geänderte Regeln
Basis = Mittelland; `offsetAnwenden` wie angegeben. Alle mit Merkblatt-Beleg in der `beschreibung`.

| key | Titel | Kat. | Ebene | Basis-Fenster | offset | Intervall | Gating | aktionRoute |
|---|---|---|---|---|---|---|---|---|
| `fluglochunterlage_beobachten` | Fluglochunterlage wöchentlich beobachten | durchsicht | volk | 1.2.–31.3.¹ | nein | 7 | immer | — |
| `serbelvoelker_fruehjahr` | Schwache/weisellose Völker beurteilen (vereinen) | durchsicht | volk | 15.3.–20.4. | ja | — | immer | — |
| `varroakontrolle_fruehsommer`² | Milbenkontrolle Frühsommer — Notbehandlungs-Schwelle prüfen (Ende Mai >3, Jun/Jul >10 Milben/Tag → sofort behandeln) | behandlung | volk | 20.5.–5.7. | ja | — | immer | varroa |
| `trachtluecke_notfuetterung` | Trachtlücke prüfen — bei Bedarf Notfütterung (Futterteig) | fuetterung | volk | 25.5.–5.7. | ja | — | immer | fuetterung |
| `jungvoelker_bilden` | Jungvölker/Ableger bilden (Zeitfenster)³ | durchsicht | volk | 20.5.–30.6. | ja | — | **Vermehrung** | — |
| `koeniginnen_vermehren` | Königinnen vermehren (Nachschaffung)³ | durchsicht | volk | 20.5.–30.6. | ja | — | **Vermehrung** | — |
| `honigernte_sommer` | 2. Honigernte (Sommer) — Reife prüfen | sonstiges | volk | 1.7.–20.7. | **nein**⁶ | — | **Anzahl Ernten=2** | — |
| `umweiselung_pruefen` | Alte Königin ersetzen prüfen (>2-jährig) | durchsicht | volk | 1.8.–31.8. | **nein**⁴ | — | immer | — |
| `wabenerneuerung_herbst` | Alte Brutwaben entnehmen (Ziel 1/3 pro Jahr) | durchsicht | volk | 15.8.–30.9. | **nein**⁴ | — | immer | — |
| `serbelvoelker_herbst` | Serbelvölker auflösen/abschwefeln | durchsicht | volk | 1.9.–30.9. | **nein**⁴ | — | immer | — |
| `winterbehandlung_erfolgskontrolle` | Totenfall zählen — >500 in 2 Wochen → Winterbehandlung wiederholen | behandlung | volk | 1.1.–20.1.⁵ | nein | — | immer | varroa |
| `sommerbehandlung_1` (**nur** Methoden-Text) | 1. Sommerbehandlung — `beschreibung` je Methode; bei biotechnisch/beide Zusatz „Brutstopp/Bannwabe vorbereiten" | behandlung | volk | 20.7.–15.8. (**unverändert**) | nein | — | Text je **Methode** | behandlung |

¹ Fensterende von 20.3. auf **31.3.** verlängert (Angleich an `gemuelldiagnose_fruehjahr`), damit der alpine Beobachtungsstart (~Mitte/Ende März) nicht abgeschnitten wird; die valide winterliche Kopfphase (Feb: Totenfall, Spitzmaus/Durchfall am Flugloch) bleibt erhalten.
² **NEU (Review-Finding):** schliesst die Frühsommer-Notbehandlungs-Lücke (Ziel 4). Text nennt die BGD-Schwellen 3/7/10 Milben/Tag (Recherche 22).
³ **Flat-Offset-Grenze (→ C):** für alpine Betriebe schiebt +42 das Ableger-Fenster in die riskante Juli/August-Zone (25_Vermehrung:277 „frühe Ableger Juni vorzuziehen"). Für Arosa unkritisch (Vermehrung Default aus); als bekannte Grenze dokumentiert, exakt via Phänologie (C).
⁴ **offset=nein (Review-BLOCKER korrigiert):** alpine Vorwinterarbeit liegt FRÜHER, nicht später — ein positiver Offset (+42) würde Umweiselung/Serbelvölker/Wabenerneuerung fatal in Okt/Nov schieben (keine begatteten Königinnen mehr; Wintertraube → Vereinigung unmöglich). Basisfenster Aug/Sep sind für beide Lagen tragbar (Mittelland kann bis Okt, Arosa MUSS bis spätestens Sep). Analog zu den bestehenden Herbst-Regeln.
⁵ Als eigenständige Januar-Regel `1.1.–20.1.` (kalenderfix) modelliert — NICHT über den Jahreswechsel (Gotcha 11 + Katalog-Test bleiben intakt); der Bezug „2 Wochen nach Oxalsäure (Nov/Dez)" ist fachlich robust.
⁶ **offset=nein (beim Plan-Schreiben erkannt):** wäre `honigernte_sommer` offset-basiert, fiele sie bei Offset 42 (fällig 31.8.) NACH der kalenderfixen `sommerbehandlung_1` (fällig 15.8.) → Behandlung vor 2. Ernte, Invariante bräche. **2 Ernten = Mittelland-Konzept** (niedriger Offset); das fixe Früh-Juli-Fenster ist Mittelland-korrekt und garantiert `honigernte_sommer.fällig (20.7.) ≤ sommerbehandlung_1.fällig (15.8.)` für **alle** Offsets. (Ein unrealistischer alpin-Betrieb mit 2 Ernten wäre ohnehin über `anzahl_ernten` konfigurierbar; die Kombi 2-Ernten+grosser-Offset ist praktisch ausgeschlossen.)

`wabenhygiene` (bestehend): `beschreibung` um „Ziel: 1/3 der Brutwaben pro Jahr erneuern (3-Jahres-Zyklus)" ergänzen.

**Methoden-Varianten `sommerbehandlung_1`:** der Generator erzeugt den Vorschlag mit methodenabhängiger `beschreibung`:
- `ameisensaeure`: „1. Sommerbehandlung mit Ameisensäure starten (vor Ende Juli, Temperaturfenster beachten)."
- `biotechnisch`: „1. Sommerbehandlung biotechnisch (Brutstopp/Bannwabe/komplette Brutentnahme) — Vorbereitung ab 1. Juli-Hälfte."
- `beide`: kombinierter Text.
**Verbindliche Verdrahtung (Review-Finding — sonst persistiert die App den generischen Text auch bei biotechnisch/beide):**
- Hilfsfunktion `beschreibungFuer(regel, einstellungen)` hält die Varianten-Logik zentral + getestet.
- **`AufgabenVorschlag` trägt eine bereits aufgelöste `beschreibung`** (Feld), die der **Generator** via `beschreibungFuer(regel, einstellungen)` beim Erzeugen setzt.
- **`_ausVorschlag` (aufgaben_provider.dart) liest `v.beschreibung`** statt `v.regel.beschreibung` → der Annahme-Pfad bleibt einstellungen-frei, der persistierte Text stimmt.
- **Test-Pflicht:** nicht nur `beschreibungFuer` isoliert, sondern der **Annahme-Pfad** (angenommene Aufgabe trägt bei `methode=biotechnisch` den biotechnischen Text).
- Dedup unberührt: der Dedup-Index nutzt `regel_key`/`saison_jahr`/`volk_id`/`faellig_am` — der variable `beschreibung`-Text geht nicht in den Key ein.

### 3.5 Gating im Katalog (Zusammenfassung)
- `nurBeiVermehrung=true`: `jungvoelker_bilden`, `koeniginnen_vermehren`.
- `nurBeiAnzahlErnten=2`: `honigernte_sommer`.
- Alle übrigen: immer (bzw. wie bisher `ebene=volk` → nur bei aktiven Völkern).

## 4. 4.6-Andockung

### 4.1 20-kg-Warnschwelle
Rein in der Settings-Seite (2.3): Inline-Warnung bei `winterfutter_ziel_kg < 20`. Keine Migration, keine Logikänderung am Winterfutter-Balken.

### 4.2 futterart-Konzentration (Migration I02)
```sql
-- neue Whitelist
alter table public.fuetterungen drop constraint if exists fuetterungen_futterart_check; -- Name aus F01 verifizieren
-- Backfill VOR neuem CHECK:
update public.fuetterungen set futterart = 'zuckerwasser_3_2' where futterart = 'zuckerwasser';
update public.fuetterungen set futterart = 'invertsirup'     where futterart = 'zuckersirup';
alter table public.fuetterungen add constraint fuetterungen_futterart_check
  check (futterart in ('zuckerwasser_1_1','zuckerwasser_3_2','invertsirup','futterteig','futterwaben','honig','sonstige'));
```
- **RPC `fuetterung_erfassen` (F02) MUSS in I02 mitgeführt werden (Review-Finding):** `create or replace function public.fuetterung_erfassen(...)` mit der neuen Whitelist **im selben Migrationsfile/Transaktion**, direkt nach dem CHECK-Wechsel (Signatur/Grants unverändert — `create or replace` erhält Grants; Fehlercode BA040 bleibt). Sonst driften CHECK und die einzige Schreibpforte auseinander (neue Werte → BA040, alte Werte → CHECK-Verletzung).
- **Constraint-Name verifiziert:** `fuetterungen_futterart_check` (Live-DB `pg_constraint` bestätigt) — kein „if exists"-Blindflug nötig, aber idempotent belassen.
- **Dart `Futterart`** ([futterart.dart](../../lib/features/fuetterung/domain/futterart.dart)): `werte`/`labels` neu: Zuckerwasser 1:1 (Jungvölker), Zuckerwasser 3:2 (Winterfutter), Invertsirup (Apiinvert), Futterteig, Futterwaben, Honig, Sonstige. Formular-Dropdown konsumiert automatisch.
- **Parität-Test dreifach (Review):** `Futterart.werte` == DB-CHECK == **RPC-Whitelist** (nicht nur Dart==DB) — Drift-Schutz über alle drei Orte.
- **Backfill/Bio-Nachweis (Review):** `fuetterungen` ist aktuell **leer** (0 Zeilen, verifiziert) → der Backfill (`zuckerwasser→zuckerwasser_3_2`, `zuckersirup→invertsirup`) trifft 0 Zeilen, es wird **keine dokumentierte Bio-Nachweis-Zeile umgeschrieben**. UPDATE ist auf `fuetterungen` **by design erlaubt** (F01: kein Immutable-Trigger, UPDATE-Policy vorhanden). Das Mapping `zuckerwasser→3_2` ist ein Konzentrations-Default (bei echtem Bestand nicht belegbar) — **im decision-log als bewusste Einmal-Korrektur auf leerer Tabelle dokumentieren**. `where futterart in ('zuckerwasser','zuckersirup')` idempotent.
- **Rollback-DO (App-CLAUDE.md-Pflicht):** I01 Reverse = `drop column` der 3 Spalten; I02 Reverse = reverse-UPDATE + alter CHECK zurück + RPC-Redefinition zurück. Als Rollback-Block in den Migrationsfiles (bzw. `supabase/ops/`) spezifizieren.

## 5. Architektur & Dateien
```
supabase/migrations/I01_betriebs_einstellungen_strategie.sql   (neu)
supabase/migrations/I02_fuetterungen_futterart_konzentration.sql (neu)
lib/features/voelker/domain/betriebs_einstellungen.dart         (Modify: +3 Felder, toUpdateJson)
lib/features/voelker/domain/voelker_gateway.dart               (Modify: einstellungenSpeichern)
lib/features/voelker/data/{fake,supabase}_voelker_gateway.dart (Modify)
lib/features/voelker/presentation/providers/voelker_provider.dart (Modify: EinstellungenNotifier.speichern)
lib/features/einstellungen/pages/einstellungen_page.dart        (neu)
lib/features/aufgaben/domain/saison_regeln.dart                (Modify: Gating-Felder, gemuelldiagnose-Offset, ~10 Regeln, AufgabenVorschlag.beschreibung, beschreibungFuer)
lib/features/aufgaben/presentation/providers/aufgaben_provider.dart (Modify: einstellungen an Generator; _ausVorschlag liest v.beschreibung)
lib/features/aufgaben/presentation/widgets/vorschlag_karte.dart (Modify, optional: Fenster statt Deadline zeigen — §9)
lib/features/fuetterung/domain/futterart.dart                  (Modify)
lib/features/fuetterung/... (RPC-Aufruf/Enum, Formular)        (Modify falls nötig)
lib/features/projekt/pages/projekt_page.dart                   (Modify: Kachel)
lib/core/router/app_router.dart                                (Modify: /einstellungen)
+ Tests (s. u.)
```

## 6. Tests
- **Generator-Gating:** je Flag ein Test — `vermehrung_aktiv` schaltet `jungvoelker_bilden`/`koeniginnen_vermehren`; `anzahl_ernten=2` schaltet `honigernte_sommer`; Defaults (Arosa) zeigen keine der gegateten.
- **Ordnungs-Invariante (2 Fälle, Offset ∈ {0,42}):** (1) `honigernte ≤ gemuelldiagnose_sommer ≤ sommerbehandlung_1`; (2) bei `anzahl_ernten=2` zusätzlich `honigernte_sommer.fällig ≤ sommerbehandlung_1.fällig` (Behandlung nie vor der letzten Ernte).
- **Herbst-Regeln offset=nein:** Test, dass `umweiselung_pruefen`/`serbelvoelker_herbst`/`wabenerneuerung_herbst` bei Offset 42 NICHT nach Okt/Nov rutschen (Fälligkeit ≤ 30.9. bzw. 31.8.).
- **Methoden-Varianten + Annahme-Pfad:** `beschreibungFuer(sommerbehandlung_1, methode)` je Methode korrekt; UND die **angenommene Aufgabe** trägt bei `methode=biotechnisch` den biotechnischen Text (nicht den generischen).
- **Katalog-Invarianten** (Bestand erweitern): neue Anzahl Regeln (~35), Keys unique, Kategorien = erlaubte Werte, **kein Fenster über Jahreswechsel** (winterbehandlung_erfolgskontrolle als Jan-Regel prüft das mit).
- **Bestandstest-Audit:** Assertions zu `gemuelldiagnose_sommer` an das neue Fenster (6.6.–20.6.) anpassen; `sommerbehandlung_1`-Assertion bleibt (unverändert).
- **futterart-Parität dreifach:** Dart == DB-CHECK == RPC-Whitelist.
- **Settings:** Modell-Roundtrip (fromJson/toUpdateJson), Notifier.speichern ruft Gateway mit `.eq('betrieb_id',…)` + invalidiert; Warnschwelle-Logik (<20) pure Funktion + Test.
- **Bestand grün** (133 Tests, inkl. v1.15.3-Puderzucker), nach dem 14-Call-Site-kompatiblen Default-Parameter (3.2).

## 7. Deploy
Version **1.16.0+37**. Migrationen `I01`/`I02` auf Produktion (separat freigabepflichtig). `get_advisors(security)` → 0 neue Findings (I01 additiv; I02 CHECK/RPC). Deploy via `bash deploy.sh` (stehende Freigabe nach grünen Tests).

## 8. Durch adversarialen Review geklärt (v2)
Der Multi-Agent-Review (5 Lupen + Skeptiker-Verify, 25 bestätigte/teilweise Findings, 1 widerlegt) hat mehrere reale v1-Fehler korrigiert — alle oben eingearbeitet:
- **BLOCKER:** neue Herbst-Regeln offset=nein (v1 fälschlich offset=ja → Okt/Nov-Verschiebung, überlebenskritisch).
- **BLOCKER/konvergent:** `sommerbehandlung_1` bleibt kalenderfix (v1-Offset-Umbau hätte Arosa verschlechtert + den 2-Ernten-Pfad fachlich falsch gemacht [AS vor Ernte]); nur `gemuelldiagnose_sommer` wird offset. 2-Ernten-Ordnung jetzt korrekt + getestet.
- **behoben:** Notbehandlungs-Regel (`varroakontrolle_fruehsommer`) ergänzt; Default-Parameter (14 Bestandstests); `beschreibungFuer`-Verdrahtung bis zur persistierten Aufgabe; RPC F02 in I02 + dreifach-Parität; Rollback-Blöcke; expliziter `.eq('betrieb_id')`-Filter; Fluglochunterlage-Fenster verlängert.
- **geklärt (kein Handlungsbedarf):** UPDATE-Policy existiert (C01); Constraint-Name verifiziert; `fuetterungen` leer (0 Zeilen) → Backfill unkritisch; `startfuetterung` kalenderfix ok (keine Arosa-Inversion); winterbehandlung-Jahreswechsel korrekt.

**Verbleibende bewusste Näherungen (→ C Phänologie), dokumentiert:** exakte alpine Sommer-Terminierung `sommerbehandlung_1`; Ableger-Fenster alpin (+42 → Juli/Aug); `gemuelldiagnose_sommer` vor `honigernte_sommer` bei 2 Ernten (nicht-invasiv).

## 9. UI-Feinschliff (Review, nice, optional)
`VorschlagKarte` zeigt heute nur `bis <fällig>` (Fensterende). Um Vorschläge als **Fenster** statt reiner Deadline zu zeigen (stützt die Timing-Logik), optional `<fensterStart> – <fällig>` darstellen (`AufgabenVorschlag.fensterStart` vorhanden). Klein; im Plan als optionaler Schritt.
