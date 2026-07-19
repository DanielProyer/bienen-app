# Modul 4.4 „Aufgaben & Kalender" — Design-Spec (v1)

**Datum:** 2026-07-19 · **Status:** freigegeben (Kern-Scope) · **Modul:** 4.4 (P1)
**Fachgrundlage:** `../imkerei/02_Recherche/02_Jahresablauf_Imker_Arosa_1570m.md` (Kompaktkalender) · Scope-Spec §4.4 · Wegweiser `docs/imkerei-fachwissen-app-implikationen.md` (Querschnittsmuster `saison_offset`).

## 1. Ziel & Scope-Entscheid

Arbeitsplanung als tägliches Kernwerkzeug: **manuelle Aufgaben** je Volk/Standort/Betrieb (Fälligkeit, Priorität, abhaken) + **regelbasierter Saison-Generator** (alpiner Jahresablauf als Vorschläge, konfigurierbarer `saison_offset`) + **Fälligkeits-Ansicht** (Überfällig/Heute/Demnächst/Später) + Dashboard-Kachel.

**Bewusst NICHT in dieser Stufe** (Entscheid „Kern"):
- Push-/E-Mail-Reminder → braucht Benachrichtigungs-Engine F3 (existiert nicht). Erinnern = in-App (Fälligkeits-Gruppen + Dashboard-Kachel).
- Wetter-Kontext (→ 4.19), Waage-Trigger (→ 4.9, Waage noch nicht da).
- `assigned_to`/`done_by` (Mehrbenutzer-Zuweisung) → totes Feld, solange nur ein Mitglied im Betrieb; kommt, wenn Lorena eingeladen ist.
- Kalender-Monatsansicht, rrule-Wiederkehr, Bulk-Sammelaktionen (→ spätere Ausbaustufe, relevant ab 8+ Völkern).

**Integritätsstufe:** normale CRUD (wie 4.3 `varroa_kontrollen`) — Aufgaben sind operative Planung, kein Journal/Nachweis. Kein RPC, kein Soft-Delete, kein Immutable-Trigger, **kein Errcode-Block**.

**Platzierung:** neuer Haupt-Tab **„Aufgaben" (`/aufgaben`)**. Die statische Projekt-Todo-Seite (`todo_page.dart`, Route `/dashboard/todo`) wird **entfernt** (Inhalt lebt in `imkerei/ToDo.md`; die Seite war ein veraltetes Duplikat).

## 2. Datenmodell (Migration H01)

### 2.1 Tabelle `aufgaben`

Standard-Muster (betrieb_id NOT NULL Default `private.aktive_betrieb_id()`, `created_by`/`updated_by`, `set_row_actor`-Trigger; RLS: SELECT=`ist_mitglied`, INSERT/UPDATE/DELETE=`kann_schreiben`, `TO authenticated`, anon ausgesperrt).

| Spalte | Typ | Constraint |
|---|---|---|
| `id` | uuid PK default `gen_random_uuid()` | |
| `betrieb_id` | uuid NOT NULL | Default `private.aktive_betrieb_id()` |
| `titel` | text NOT NULL | `length(titel) between 1 and 200` |
| `beschreibung` | text | nullable |
| `kategorie` | text NOT NULL | CHECK in `('durchsicht','behandlung','fuetterung','schutz','werkstatt','verwaltung','sonstiges')` |
| `faellig_am` | date NOT NULL | |
| `prioritaet` | text NOT NULL default `'normal'` | CHECK in `('hoch','normal','niedrig')` |
| `status` | text NOT NULL default `'offen'` | CHECK in `('offen','erledigt','uebersprungen')` |
| `erledigt_am` | timestamptz | CHECK: `status='erledigt'` ⇔ `erledigt_am is not null` (beide Richtungen) |
| `volk_id` | uuid nullable | Komposit-FK `(betrieb_id, volk_id) → voelker(betrieb_id, id)` **ON DELETE CASCADE** (Planungsdaten) |
| `standort_id` | uuid nullable | Komposit-FK `(betrieb_id, standort_id) → standorte(betrieb_id, id)` **ON DELETE SET NULL (standort_id)** |
| `quelle` | text NOT NULL default `'manuell'` | CHECK in `('manuell','regel')` |
| `regel_key` | text nullable | CHECK: `quelle='regel'` ⇔ `regel_key is not null` |
| `saison_jahr` | int nullable | CHECK: `(quelle='regel') = (saison_jahr is not null)` |
| `created_at`/`updated_at`/`created_by`/`updated_by` | Standard | |

**Dedup-Index (Generator):**
```sql
create unique index aufgaben_regel_dedup on public.aufgaben
  (betrieb_id, regel_key, saison_jahr, volk_id, faellig_am) nulls not distinct
  where quelle = 'regel';
```
Ein angenommener ODER übersprungener Vorschlag existiert als Zeile → der Generator schlägt ihn nie erneut vor. „Überspringen" = Zeile mit `status='uebersprungen'` (kein Extra-Table).

Indizes: `(betrieb_id, status, faellig_am)` für die Listenabfrage, `(betrieb_id, volk_id)` für die Volk-Section.

### 2.2 Saison-Offset: Spalte existiert bereits (Korrektur nach Codebase-Check)

`betriebs_einstellungen.saison_offset_default_tage int not null default 0` besteht seit C01 (Modul 4.2), das Dart-Modell `BetriebsEinstellungen.saisonOffsetDefaultTage` liest sie bereits, und der Ops-Seed `seed-arosa-einstellungen.sql` setzt Arosa schon auf **42**. → **H01 legt NUR die `aufgaben`-Tabelle an**; kein neues Feld, kein Seed-Update, kein Modell-Ausbau. Der Generator konsumiert `saisonOffsetDefaultTage`.

## 3. Regelwerk `saison_regeln.dart` (Dart-Fachkonstante)

Muster wie `krankheit.dart`/`wirkstoff.dart`: Katalog als `const`-Liste, reine Funktionen, kein DB-Seed, kein Arosa-Hardcode.

```dart
enum RegelEbene { volk, betrieb }

class SaisonRegel {
  final String key;              // stabil, snake_case
  final String titel;
  final String beschreibung;     // 1-2 Sätze Fachkontext (aus Recherche 02)
  final String kategorie;        // = DB-CHECK-Wert
  final RegelEbene ebene;
  final int startMonat; final int startTag;   // Fensterbeginn (Basis)
  final int endMonat;   final int endTag;     // Fensterende = Fälligkeits-Default
  final bool offsetAnwenden;     // true = Frühjahrs-/Trachtregel, verschiebt um saison_offset_tage
  final int? intervallTage;      // z. B. 7 (Schwarmkontrolle), 14 (Drohnenschnitt)
  final String? aktionRoute;     // Deep-Link-Suffix: 'durchsicht' | 'behandlung' | 'fuetterung' | null
}
```

**Offset-Semantik (wichtiger Fachentscheid):** `saison_offset_tage` verschiebt NUR Frühjahrs-/Trachtregeln (`offsetAnwenden=true`) — alpin beginnt die Vegetation ~40–45 Tage SPÄTER. Herbst-/Winterregeln sind **kalenderfix mit alpin-sicheren Fenstern** aus der Recherche: alpin kommt der Herbst FRÜHER, ein positiver Offset wäre dort falsch; die alpinen Fenster sind für alle Betriebe konservativ-sicher (früh einfüttern schadet nie, spät ist fatal). Fein-Tuning je Betrieb (Fenster überschreiben) kommt mit F4 — nicht jetzt (YAGNI).

### Regel-Katalog (25 Regeln, Basisfenster)

**Kalenderfix (`offsetAnwenden=false`):**

| key | Titel | Kategorie | Ebene | Fenster | Intervall | aktionRoute |
|---|---|---|---|---|---|---|
| `werkstatt_winter` | Werkstatt: Rähmchen, Mittelwände, Material | werkstatt | betrieb | 1.1.–28.2. | — | — |
| `futtervorrat_winter` | Futtervorrat prüfen (Gewicht/Futterteig) | durchsicht | volk | 1.2.–20.3. | — | — |
| `gemuelldiagnose_fruehjahr` | Gemülldiagnose Frühjahr (Milbenfall) | behandlung | volk | 1.3.–31.3. | — | varroa¹ |
| `maeuseschutz_entfernen` | Mäusegitter/Fluglochkeil entfernen | schutz | betrieb | 15.3.–15.4. | — | — |
| `gemuelldiagnose_sommer` | Gemülldiagnose nach Ernte | behandlung | volk | 1.7.–15.7. | — | varroa¹ |
| `startfuetterung` | Startfütterung (~5 kg) | fuetterung | volk | 15.7.–31.7. | — | fuetterung |
| `sommerbehandlung_1` | 1. Varroa-Sommerbehandlung starten | behandlung | volk | 20.7.–15.8. | — | behandlung |
| `hauptfuetterung` | Hauptfütterung (Etappen) | fuetterung | volk | 1.8.–31.8. | — | fuetterung |
| `sommerbehandlung_2` | 2. Varroa-Sommerbehandlung | behandlung | volk | 25.8.–20.9. | — | behandlung |
| `auffuetterung_abschliessen` | Auffütterung ABSCHLIESSEN (Deadline!) | fuetterung | volk | 1.9.–10.9. | — | fuetterung |
| `futterkontrolle_herbst` | Futterkontrolle + Weiselkontrolle | durchsicht | volk | 20.9.–10.10. | — | durchsicht |
| `maeuseschutz_ansetzen` | Mäusegitter/Fluglochkeil ansetzen | schutz | betrieb | 1.10.–31.10. | — | — |
| `winterfest_machen` | Winterfest: Windsicherung, Beschwerung, Schnee-Zugang | schutz | betrieb | 10.10.–31.10. | — | — |
| `spechtschutz` | Spechtschutz anbringen (Netz/Verkleidung) | schutz | betrieb | 1.11.–30.11. | — | — |
| `brutfreiheit_pruefen` | Brutfreiheit prüfen (vor Winterbehandlung) | behandlung | volk | 1.11.–20.11. | — | — |
| `oxalsaeure_winter` | Oxalsäure-Winterbehandlung (brutfrei) | behandlung | volk | 15.11.–15.12. | — | behandlung |

¹ `varroa` führt zur Milbendiagnose (`/voelker/:id/varroa`), nicht zum Behandlungs-Formular — siehe §5 Routen-Mapping.

**Frühjahrs-/Trachtregeln (`offsetAnwenden=true`, Basis Mittelland; Arosa +42 ⇒ Fenster der Recherche):**

| key | Titel | Kategorie | Ebene | Basisfenster | Intervall | aktionRoute |
|---|---|---|---|---|---|---|
| `erste_durchsicht` | Erste kurze Durchsicht (ab ~15 °C) | durchsicht | volk | 1.3.–25.3. | — | durchsicht |
| `fruehjahrsdurchsicht` | Frühjahrsdurchsicht (vollständig) | durchsicht | volk | 15.3.–10.4. | — | durchsicht |
| `wabenhygiene` | Wabenhygiene/Bodentausch | durchsicht | volk | 1.3.–15.4. | — | — |
| `drohnenrahmen_einsetzen` | Drohnenrahmen einsetzen | durchsicht | volk | 20.3.–10.4. | — | — |
| `drohnenschnitt` | Drohnenrahmen schneiden | durchsicht | volk | 1.4.–30.6. | 14 | — |
| `brutraum_erweitern` | Brutraum erweitern | durchsicht | volk | 1.4.–20.4. | — | — |
| `honigraum_aufsetzen` | Honigraum aufsetzen | durchsicht | volk | 10.4.–30.4. | — | — |
| `schwarmkontrolle` | Schwarmkontrolle (alle 7 Tage!) | durchsicht | volk | 15.4.–1.6. | 7 | durchsicht |
| `honigernte` | Honigernte (Reife prüfen) | sonstiges | volk | 20.5.–5.6. | — | — |

**Saison-Jahr:** `saison_jahr` = Kalenderjahr des (verschobenen) Fensterbeginns. Kein Regelfenster überschreitet den Jahreswechsel (bewusst so geschnitten — Gotcha 11 aus 4.6 wird damit strukturell vermieden; Test sichert das ab).

### Generator (reine Funktion)

```dart
List<AufgabenVorschlag> anstehendeVorschlaege({
  required DateTime stichtag,
  required int saisonOffsetTage,
  required List<Aufgabe> regelAufgaben,   // quelle='regel' des relevanten Saisonjahrs
  required int anzahlAktiveVoelker,
})
```
- Fenster je Regel: Basis + Offset (falls `offsetAnwenden`). Vorschlag sichtbar ab **14 Tage Vorlauf** vor Fensterbeginn bis Fensterende.
- `ebene=volk`-Regeln nur bei `anzahlAktiveVoelker > 0`.
- **Dedup:** Regel unterdrückt, wenn für `(regel_key, saison_jahr)` bereits Zeile(n) existieren — bei Intervall-Regeln: wenn die jüngste Zeile weniger als `intervallTage` zurückliegt (nächster Vorschlag: `faellig = jüngste.faellig_am + intervallTage`, solange im Fenster).
- **Fälligkeits-Default beim Annehmen:** `faellig_am = Fensterende` (Deadline-Charakter); Intervall-Regeln: nächstes Intervalldatum.
- **Annehmen** einer `ebene=volk`-Regel: Checkbox-Liste aller aktiven Völker, vorbelegt „alle" → 1 Zeile je gewähltem Volk (Client-seitige Batch-Inserts; kein RPC nötig, Dedup-Index fängt Doppelklicks). `ebene=betrieb`: 1 Zeile ohne volk_id.
- **Überspringen:** 1 Zeile `status='uebersprungen'` (bei volk-Regeln OHNE volk_id — überspringt die Regel fürs ganze Saisonjahr; `nulls not distinct` macht das eindeutig). Generator wertet eine `uebersprungen`-Zeile ohne volk_id als „Regel für dieses Jahr aus".

## 4. UI

**Tab „Aufgaben" (`/aufgaben`, neuer Haupt-Tab, ersetzt statische Todo-Seite):**
1. **Saisonaufgaben-Vorschläge** (oben, nur wenn vorhanden): Karte je Vorschlag — Titel, Fenster („bis 10. Sept."), Beschreibung, Buttons **Annehmen** / **Überspringen**. Annehmen bei volk-Regeln öffnet Völker-Auswahl (Dialog, alle vorbelegt).
2. **Aufgabenliste** in Gruppen: **Überfällig** (rot) · **Heute** · **Demnächst** (≤14 Tage) · **Später**; sortiert nach `faellig_am`. Zeile: Checkbox (abhaken → `erledigt`+`erledigt_am`, Undo-Snackbar), Titel, Kategorie-Chip, Volk-/Standort-Badge (tappbar → Volk-Detail), Prio-Marker (hoch=amber), bei `aktionRoute`+volk_id ein **„Erfassen"-Pfeil** ins passende Formular. Abhaken ist **manuell** — kein Auto-Erledigen durch Journal-Einträge (bewusste Entkopplung).
3. **Erledigt/Übersprungen** (eingeklappt, letzte 30 Tage, Wiedereröffnen möglich).
4. **FAB „Neue Aufgabe"** → `AufgabeFormPage` (`/aufgaben/neu`, `/aufgaben/:id/bearbeiten`): Titel, Beschreibung, Kategorie, Fälligkeit, Priorität, optional Volk/Standort (Dropdowns via `await provider.future` — Gotcha 2). Löschen mit Confirm. **Rollen-Guard im build** (viewer read-only — Gotcha 5).

**Routen-Mapping `aktionRoute`:** `durchsicht` → `/voelker/:id/durchsicht` · `behandlung` → `/voelker/:id/behandlung` · `fuetterung` → `/voelker/:id/fuetterung`; Gemülldiagnose-Regeln → `/voelker/:id/varroa` (eigener Wert `varroa` im Katalog).

**Andocken:**
- **Dashboard-Kachel „Aufgaben":** `X offen · Y überfällig` (überfällig rot), tappbar → `/aufgaben`; ersetzt den bisherigen Todo-Link.
- **Volk-Detailseite:** Section „Offene Aufgaben" (max. 5 dieses Volks, Link „alle →"), Position zwischen bestehenden Sections.
- **Nav:** neuer Tab „Aufgaben" (Icon `checklist`); `todo_page.dart` + Route `/dashboard/todo` löschen.

## 5. Architektur (Feature-Struktur, Muster 4.14)

```
lib/features/aufgaben/
  domain/aufgabe.dart              // Modell + fromMap/toInsert
  domain/saison_regeln.dart        // Regel-Katalog + anstehendeVorschlaege() (pure)
  data/aufgaben_gateway.dart       // abstrakt
  data/fake_aufgaben_gateway.dart
  data/supabase_aufgaben_gateway.dart   // CRUD via PostgREST, kein RPC
  presentation/providers/aufgaben_provider.dart
  presentation/pages/aufgaben_page.dart
  presentation/pages/aufgabe_form_page.dart
  presentation/widgets/vorschlag_karte.dart
  presentation/widgets/aufgaben_gruppe.dart
  presentation/widgets/aufgaben_section.dart   // für Volk-Detailseite
```
- `aufgabenListProvider` (AsyncNotifier, Betriebsliste) + abgeleitete Provider: `aufgabenFuerVolkProvider(volkId)` (family), `offeneAufgabenZahlProvider` (Dashboard), `vorschlaegeProvider` (kombiniert Liste + Einstellungen + aktive Völker). **Invalidierung in `AuthController._datenNeuLaden()`** (Gotcha 1).
- Schreiben invalidiert `aufgabenListProvider` (abgeleitete rechnen daraus — keine Familys mit eigenem Fetch → Sammel-Invalidation-Falle D-18/D-23 entfällt strukturell).

## 6. Fehlerbehandlung & Edge Cases

- Dedup-Index-Verletzung (Doppelklick auf Annehmen) → PostgrestException abfangen, still ignorieren (Vorschlag verschwindet ohnehin).
- `betriebs_einstellungen` ohne Zeile (Alt-Betrieb) → Offset-Fallback 0 im Provider.
- Volk wird inaktiv/gelöscht: CASCADE räumt Volk-Aufgaben; inaktive Völker erscheinen nicht in der Annehmen-Auswahl.
- Wiedereröffnen: `status='offen'`, `erledigt_am=null` (CHECK erzwingt Konsistenz).
- Zeitzone: `faellig_am` ist `date` (lokal interpretiert); „Heute"-Vergleich über `DateUtils.dateOnly`.

## 7. Tests

- **Generator (pure):** Fenster mit/ohne Offset (0 und +42 ⇒ Recherche-KWs), Vorlauf 14 Tage, `anzahlAktiveVoelker=0`, Dedup (angenommen/übersprungen/volk-scharf), Intervall Schwarmkontrolle (7 Tage, Fensterende), Deadline-Regel Auffütterung, Fälligkeits-Default, **kein Regelfenster über Jahreswechsel** (struktureller Test über den Katalog), Katalog-Invarianten (Keys unique, Kategorien = DB-CHECK-Werte, Monat/Tag valide).
- **Provider:** Gruppierung überfällig/heute/demnächst/später, Abhaken/Undo, Zähl-Provider, Fake-Gateway-CRUD.
- **DB (DO-Tests in H01):** RLS-Isolation, CHECK-Paare (`erledigt`⇔`erledigt_am`, `regel`⇔`regel_key`/`saison_jahr`), Dedup-Index, Komposit-FKs, GUC-Trick für `kann_schreiben` (Gotcha 10).

## 8. Deploy

Version **1.14.0+32**. H01 auf Produktion (separat freigabepflichtig). `get_advisors(security)` → 0 neue Findings. Deploy via `bash deploy.sh` (stehende Freigabe nach grünen Tests).
