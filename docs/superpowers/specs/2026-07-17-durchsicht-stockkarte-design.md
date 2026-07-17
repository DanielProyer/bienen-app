# Design-Spec: Durchsicht/Stockkarte (Modul 4.3) — Kern-Durchsicht

**Stand:** 2026-07-17 · **Status:** überarbeitet nach adversarialem Multi-Agent-Review (25 Findings, 14 bestätigt, 0 Blocker/hoch) · **Modell:** Fable 5 (DB/RLS/mandantenkritisch)
**Grundlage:** [Funktionsumfang-Scope](2026-07-11-app-funktionsumfang-scope.md) §4.3 · [App-Implikationen](../../imkerei-fachwissen-app-implikationen.md) · Fachwissen: `../../../imkerei/02_Recherche/11` (fünf Kernfragen), `10` (Brut/Weisel), `14` (Krankheiten/Meldepflicht)
**Baut auf:** Modul 4.2 „Völker & Standorte" (v1.9.0) — die Volk-Detailseite hat eine vorbereitete Platzhalter-Sektion „Verlauf", an die 4.3 andockt.

---

## 1. Zweck

Die **digitale Stockkarte statt Papier**: pro Volk strukturierte, datierte Durchsichts-Einträge, am Stand mit wenigen Taps erfassbar. Die Durchsicht ist die **Beobachtung** (Weisel-, Brut-, Futter-, Platz-, Gesundheitszustand) — sie speist die Volk-Timeline und liefert später (4.17) Selektionsdaten. Sie ist der erste echte **Ereignis-Lieferant** für die 4.2-Drehscheibe.

**Realitätscheck:** Herbst 2026 = 1 Volk. Datenmodell auf 32/64 auslegen, UI schlicht. **YAGNI für die Bedienoberfläche, nicht für Datenintegrität.**

## 2. Scope

### In Scope
- Neue Tabelle `inspections` + View `v_letzte_durchsichten` + **privater** Storage-Bucket `inspection-photos`.
- Flutter-Feature `lib/features/durchsicht/`: geführtes Durchsichts-Formular (vollflächige Seite), Timeline in der Volk-Detailseite, Durchsichts-Detailansicht.
- Zwei kleine Eingriffe in 4.2 (Andockstellen): „Verlauf"-Sektion → echte Timeline; `VolkCard` → „zuletzt gesehen vor X Tagen".
- Foto-Upload je Durchsicht (privat, Signed-URL) + Storage-Lösch-Lifecycle.

### Bewusst NICHT in Scope (Begründung)
| Ausgeschlossen | Warum |
|---|---|
| **Echte Folge-Aufgaben (`tasks`)** | Modul 4.4 existiert nicht. Statt „erzeugt `tasks`" nur ein Empfehlungsdatum `naechste_durchsicht_am`. |
| **Spracheingabe / Offline-Outbox** | Feld-Komfort bzw. Querschnittsthema (PWA-Härtung). |
| **Konfigurierbare Feldsätze (HiveTracks)** | Bei 1–8 Völkern YAGNI; fester, fachlich fundierter Feldsatz. |
| **Auto-Mutation des Volks** | Eine Durchsicht ändert `voelker` **nicht**. „weisellos"/„faulbrut_verdacht" wird sichtbar; Handeln läuft über 4.2/4.5/4.14. |
| **Tiefe Krankheits-Diagnose / Meldepflicht-Engine** | Modul 4.14. Hier nur `auffaelligkeiten`-Schnell-Flags (inkl. `faulbrut_verdacht` als Frühwarn-Flag). |
| **Behandlung / Varroa-Zählung** | Modul 4.5. `auffaelligkeiten` enthält höchstens `varroa_sichtbar` als Beobachtung. |
| **Zentrale Foto-Galerie / Orphan-Bereinigung** | Modul 4.25. 4.3 räumt eigene Fotos beim Löschen best-effort ab; eine serverseitige Orphan-Bereinigung liefert 4.25 nach. |

## 3. Getroffene Entscheide

1. **Zuschnitt = Kern-Durchsicht** (strukturierte Erfassung + Timeline + Foto); Voice/Offline/Config-Felder/echte `tasks` später.
2. **Foto jetzt mit rein, aber DATENSCHUTZ-BEWUSST:** Durchsichts-Fotos zeigen Brutbild/Krankheiten (Gesundheitsdaten eines Betriebs, später Seuchen-Beweisfotos). Anders als Bau-Fotos gehören sie **nicht** in einen public-read-Bucket → **privater Bucket + Signed-URL**; `foto_urls` speichert **Pfade**, keine öffentlichen URLs (macht einen späteren Wechsel migrationsfrei — hier ohnehin Greenfield).
3. **Timeline in der Detailseite statt neuem Nav-Tab**; Formular als **vollflächige Seite** (viele Felder).
4. **Record-only:** Durchsicht = Beobachtung, keine Seiteneffekte auf `voelker`.

## 4. Datenmodell

`inspections` folgt dem etablierten Mandanten-Muster:
- `betrieb_id uuid NOT NULL DEFAULT private.aktive_betrieb_id()` + `created_by`/`updated_by` + `created_at`/`updated_at`.
- Trigger `set_row_actor` + `set_updated_at`.
- RLS `inspections_{sel_member|ins_writer|upd_writer|del_writer}`; `revoke all from anon, public` + `grant select,insert,update,delete to authenticated`.
- Enums als `text` + `CHECK`; **`unique (betrieb_id, id)`** (Konsistenz mit dem C-Serien-Muster; ermöglicht künftige Same-Tenant-Kind-FKs aus 4.14/4.25).
- **Same-Tenant-Integrität:** `volk_id` als Komposit-FK `(betrieb_id, volk_id) → voelker(betrieb_id, id) ON DELETE CASCADE`. *(CASCADE ist bewusst: `voelker` wird im Normalfall per Status „aufgelöst", **nicht** hart gelöscht — CASCADE feuert nur beim Fehleingabe-Hard-Delete.)*

### 4.1 Tabelle `inspections`

| Spalte | Typ | Notiz |
|---|---|---|
| `id` | `uuid PK DEFAULT gen_random_uuid()` | |
| `volk_id` | `uuid NOT NULL` | Komposit-FK `(betrieb_id, volk_id) → voelker ON DELETE CASCADE` |
| `durchgefuehrt_am` | `date NOT NULL DEFAULT current_date` | **App setzt das Datum client-seitig** (lokale CH-Zeit; DB-Default `current_date` ist UTC und nur Fallback) |
| **Kontext** | | |
| `wetter` | `text NULL` | Freitext |
| `temperatur_c` | `numeric NULL` | (darf negativ sein) |
| `dauer_min` | `int NULL` | `CHECK (dauer_min is null or dauer_min >= 0)` |
| **W — Weisel** | | |
| `weiselzustand` | `text NULL` | CHECK: `weiselrichtig\|weisellos\|drohnenbruetig\|unsicher` |
| `koenigin_gesehen` | `boolean NOT NULL DEFAULT false` | |
| `stifte_gesehen` | `boolean NOT NULL DEFAULT false` | frische Eier = Weiselrichtig-Indiz |
| `weiselzellen` | `text NULL` | CHECK: `keine\|spielnaepfchen\|schwarmzellen\|nachschaffungszellen` |
| `weiselzellen_anzahl` | `int NULL` | `CHECK (… is null or … >= 0)` |
| **B — Brut** | | |
| `brutbild` | `text NULL` | CHECK: `geschlossen\|lueckig\|bunt\|kaum\|kein` |
| `brut_waben` | `numeric NULL` | **beobachteter Brutumfang** (Anzahl Brutwaben; getrennt von `voelker.brutwaben`=Beuten-Config). `CHECK (… is null or … >= 0)` |
| **Stärke** | | |
| `staerke_wabengassen` | `numeric NULL` | besetzte Wabengassen; App schätzt ~1000 Bienen/Gasse. `CHECK (… is null or … >= 0)` |
| **F — Futter** | | |
| `futter_kg` | `numeric NULL` | Schätzung. `CHECK (… is null or … >= 0)` |
| `pollen` | `text NULL` | CHECK: `viel\|mittel\|wenig\|kein` |
| **P — Platz** | | |
| `platz` | `text NULL` | CHECK: `ok\|eng\|honigraum_noetig\|zu_gross` |
| **Verhalten (Selektion → 4.17)** | | |
| `sanftmut` | `int NULL` | `CHECK (… is null or … between 1 and 4)` |
| `wabensitz` | `int NULL` | `CHECK (… is null or … between 1 and 4)` |
| **G — Gesundheit** | | |
| `auffaelligkeiten` | `text[] NOT NULL DEFAULT '{}'` | **DB-CHECK: `auffaelligkeiten <@ ARRAY[…whitelist…]::text[]`** (jedes Element aus der Whitelist). Whitelist: `kalkbrut\|sackbrut\|faulbrut_verdacht\|sauerbrut_verdacht\|ruhr\|raeuberei\|wachsmotte\|varroa_sichtbar\|kahlflug`. `faulbrut_verdacht`/`sauerbrut_verdacht` = **meldepflichtige Brutseuchen** (Recherche 14) → später 4.14-Meldepflicht-Engine. |
| **Handeln** | | |
| `massnahmen` | `text NULL` | Freitext |
| `naechste_durchsicht_am` | `date NULL` | einfache Empfehlung (kein `tasks`-Modul) |
| **Medien/Notiz** | | |
| `foto_urls` | `text[] NOT NULL DEFAULT '{}'` | **Storage-PFADE** (`<betrieb_id>/<inspection_id>/<datei>`), keine öffentlichen URLs. Anzeige via Signed-URL. |
| `notiz` | `text NULL` | |
| + audit | | |

**Pflicht:** nur `volk_id` + `durchgefuehrt_am`. Alles andere optional.

**Index:** `create index idx_inspections_volk_datum on public.inspections (betrieb_id, volk_id, durchgefuehrt_am desc)` — deckt die Volk-Timeline **und** den Komposit-FK `(betrieb_id, volk_id)` als führende Spalten (⇒ **kein** separater `(volk_id)`-Index nötig, kein `unindexed_foreign_keys`-Advisor).

### 4.2 View `v_letzte_durchsichten` (für Völkerliste, kein N+1)

PostgREST/supabase-dart kann **kein** `DISTINCT ON`. Deshalb eine DB-View:

```sql
create view public.v_letzte_durchsichten with (security_invoker = true) as
  select distinct on (volk_id) *
  from public.inspections
  order by volk_id, durchgefuehrt_am desc, created_at desc;
```
`security_invoker = true` ⇒ die RLS der Basistabelle `inspections` gilt für die/den aufrufende:n Nutzer:in (keine eigene Policy nötig, keine Umgehung). Die Völkerliste liest **einen** Query aus dieser View und mappt nach `volk_id`.

### 4.3 Storage-Bucket `inspection-photos` (PRIVAT)

- Bucket **`inspection-photos`** mit **`public = false`** (KEIN public read — anders als `construction-photos`, weil Brutbild/Krankheitsfotos Gesundheitsdaten sind).
- **4 Policies auf `storage.objects`** für diesen Bucket:
  - **SELECT** (Lesen): Mitglied des Betriebs — erstes Pfadsegment ist eine `betrieb_id`, in der der/die Aufrufer:in Mitglied ist (nach dem **B02-Muster** `auth_sel_*` mit `<betrieb_id>/`-Pfad-Scoping + UUID-Regex-Guard).
  - **INSERT/UPDATE/DELETE** (Schreiben): `private.kann_schreiben(((storage.foldername(name))[1])::uuid)` — exakt das **A10-Muster** (UUID-Regex-Guard vor dem Cast).
- **Anzeige:** Gateway erzeugt bei Bedarf eine **Signed-URL** (`createSignedUrl(pfad, ablaufSekunden)`); es werden nur Pfade persistiert.
- Pfadkonvention: `<betrieb_id>/<inspection_id>/<datei>`.

## 5. Ableitungen (reine Logik, kein DB-Feld)

- **`bienenSchaetzung(wabengassen)`** → `~1000 × wabengassen` (Richtwert Dadant, Recherche 11). Reine Dart-Funktion, unit-testbar; nur Anzeige.
- **Weiselrichtigkeit-Hinweis:** `stifte_gesehen == true` ⇒ UI-Hinweis „spricht für weiselrichtig". `weiselzustand` wird trotzdem explizit gesetzt — keine Auto-Ableitung.

## 6. App-Schicht (`lib/features/durchsicht/`)

Nach dem 4.2-Muster (Gateway-Interface + Supabase- + Fake-Impl, Riverpod `AsyncNotifier` ohne Codegen):

```
features/durchsicht/
  domain/        durchsicht.dart (Modell + Enums/Whitelist) · bienen_schaetzung.dart (reine Funktion)
                 durchsicht_gateway.dart (Interface)
  data/          supabase_durchsicht_gateway.dart · fake_durchsicht_gateway.dart
  presentation/  providers/durchsicht_provider.dart
                 pages/durchsicht_form_page.dart · durchsicht_detail_page.dart
                 widgets/durchsicht_timeline.dart · durchsicht_karte.dart
```

- **Gateway-Methoden:** `fuerVolk(volkId)` (absteigend nach `durchgefuehrt_am`), `letzteJeVolk()` (liest `v_letzte_durchsichten`), `speichern(Durchsicht)` (insert/update), `loeschen(id)`, `fotoHochladen(betriebId, inspectionId, bytes, name) → Pfad`, `fotoSignedUrl(pfad) → URL`, `fotoEntfernen(pfad)`.
  - **Foto-Lifecycle (Löschpflicht):** `loeschen(id)` entfernt **zuerst** die Storage-Objekte aller `foto_urls` (best-effort `storage.remove`), dann die Zeile. Einzelfoto-Entfernen im Edit-Flow analog. Beim **Volk-Hard-Delete** (Fehleingabe) kaskadiert die DB die `inspections`-Zeilen — die zugehörigen Storage-Objekte bleiben zurück; das ist als **best-effort-Restrisiko** in §10 dokumentiert (serverseitige Orphan-Bereinigung liefert 4.25).
  - **Fehler-Mapping** wie 4.2 (`PostgrestException` → Klartext, **keine stillen `catch`→`[]`**). `auffaelligkeiten`/`foto_urls` als `text[]` (leere Liste = `[]`, nicht `null`).
  - **Whitelist-Validierung** von `auffaelligkeiten` bereits im Domain-Konstruktor/Gateway (die DB-CHECK ist die harte Absicherung, die App-Filterung die freundliche).
- **State:** (a) `durchsichtenFuerVolkProvider = AsyncNotifierProvider.family<…, List<Durchsicht>, String>` (volle Timeline je Volk). (b) `letzteDurchsichtenProvider` (AsyncNotifier, liest `v_letzte_durchsichten` in **einem** Query, kein N+1). Schreibaktionen invalidieren `durchsichtenFuerVolkProvider(volkId)` **und** `letzteDurchsichtenProvider`. **Beide müssen in `AuthController._datenNeuLaden()`** (`ref.invalidate(durchsichtenFuerVolkProvider)` invalidiert alle Family-Instanzen; `ref.invalidate(letzteDurchsichtenProvider)`).
- **Rollen:** `viewer` sieht die Timeline read-only; „+ Durchsicht"/Edit/Löschen nur bei `darfSchreibenProvider`.

### Screens & Andocken
1. **Volk-Detailseite (4.2):** Platzhalter „Verlauf" → **`DurchsichtTimeline`** (kompakte `DurchsichtKarte`n: Datum, `weiselzustand`-Chip, Stärke, Kern-Auffälligkeiten, `massnahmen`-Snippet), „+ Durchsicht"-Button (schreibberechtigt), Tap → `durchsicht_detail_page`. Empty-State „Noch keine Durchsicht".
2. **`/voelker/:id/durchsicht`** (neu): vollflächiges Formular in Abschnitten (Kontext → Weisel → Brut/Stärke → Futter/Platz → Verhalten → Gesundheit → Massnahmen → Foto/Notiz). Große Tap-Ziele; Slider für `sanftmut`/`wabensitz`; Choice-Chips für Enums; Multi-Select-Chips für `auffaelligkeiten`; Foto-Picker. `durchgefuehrt_am` client-seitig (Default heute). Speichern → zurück, Provider invalidiert.
3. **`/voelker/:id/durchsicht/:did`** (neu): Vollansicht + Bearbeiten (Formular vorbefüllt per Objekt-Übergabe) + Löschen (schreibberechtigt, Bestätigung, räumt Fotos mit).
4. **Völkerliste (4.2, `volk_card.dart`):** dezente Zeile „zuletzt gesehen: vor X Tagen" / „noch nie" aus `letzteDurchsichtenProvider`.

Routen als Unterrouten von `/voelker/:id` in `app_router.dart` (Shell bleibt, kein neuer Tab).

## 7. Migrationen & Rollout

| # | Inhalt |
|---|---|
| `D01` | `inspections` + `unique(betrieb_id,id)` + Komposit-FK `(betrieb_id, volk_id)→voelker ON DELETE CASCADE` + alle CHECKs (inkl. `auffaelligkeiten <@`-Whitelist, Nicht-Negativ, 1–4) + RLS/Trigger/Grants + Timeline-Index + **View `v_letzte_durchsichten` (security_invoker)** |
| `D02` | Storage: Bucket `inspection-photos` **`public=false`** (`insert into storage.buckets … on conflict do nothing`) + **SELECT-Policy (Mitglied, B02-Muster)** + 3 Write-Policies (`<betrieb_id>/`-Pfad, A10-Muster) |

Jede Migration: Datei unter `supabase/migrations/` **und** via MCP `apply_migration`; Kopf-Kommentar; **Rollback-DO-SQL-Test**; `get_advisors(security)` → **0 neue Findings** (kein neuer SECURITY-DEFINER-RPC; die View ist `security_invoker`).

**Kein Ops-Seed. Kein Errcode-Block** (reines CRUD; Integrität via FK/CHECK/RLS).

**Deploy:** `pubspec` `version:` → **1.10.0+28**, `bash deploy.sh`.

## 8. Tests

**SQL (Rollback-DO je Migration):**
- Mandanten-Isolation: fremder Betrieb sieht/schreibt keine `inspections`.
- Same-Tenant-FK: Insert mit fremdem/erfundenem `volk_id` → FK-Fehler (23503), identisch zu nicht existierender UUID.
- CHECK-Verletzungen: `weiselzustand`/`brutbild`/`pollen`/`platz`/`weiselzellen`; `sanftmut`/`wabensitz` außerhalb 1–4; Nicht-Negativ; **`auffaelligkeiten` mit unbekanntem Flag → CHECK-Fehler**.
- **`ON DELETE CASCADE`:** Test-Volk + Durchsicht anlegen, Volk hart löschen → Durchsicht weg (Transaktion, Rollback).
- **View:** `v_letzte_durchsichten` liefert je `volk_id` genau die neueste Zeile (mehrere Durchsichten anlegen, prüfen).
- `betrieb_id`/`created_by` nicht fälschbar.
- Storage: Bucket ist `public=false`; Policies existieren (Namen). Funktionaler Upload/Signed-URL/Remove in der Live-Verifikation.

**Dart:** `bienenSchaetzung()` (0/1/… Gassen); Model-Roundtrip `fromJson`/`toInsertJson` inkl. `text[]` + Enums + **Whitelist-Filter** (unbekanntes Flag wird verworfen); `FakeDurchsichtGateway` (speichern/fuerVolk absteigend/letzteJeVolk/loeschen inkl. Foto-Remove-Aufruf); Provider-Test (Schreibaktion invalidiert Family-Instanz + `letzteDurchsichtenProvider`); **Provider-Test: nach signOut/signIn ist der Durchsichts-Cache invalidiert**; Rollen-Gating (viewer read-only). `flutter analyze` sauber, alle Tests grün.

## 9. Erweiterungspunkte (bewusst offen)

| Punkt | Für |
|---|---|
| `naechste_durchsicht_am` | 4.4 Aufgaben/Kalender (echte `tasks`) |
| `sanftmut`/`wabensitz`/`brut_waben`/Weiseldaten | 4.17 Zucht (Selektionsbewertung je Volk/Saison) |
| `auffaelligkeiten` (inkl. `faulbrut_verdacht`/`sauerbrut_verdacht`) | 4.14 Gesundheit (Katalog + Diagnose-Journal + **Meldepflicht-Engine**) |
| `staerke_wabengassen`, `platz` | 4.5 Behandlung (Schwarmkontrolle), 4.7 Honigraum |
| `foto_urls` (privat, Pfade) + Storage-Orphans | 4.25 Medien-Galerie + serverseitige Orphan-Bereinigung |
| `unique(betrieb_id,id)` | Same-Tenant-Kind-FKs künftiger Module auf `inspections` |

## 10. Risiken & offene Punkte

- **Foto-Upload-Helfer ist KEIN wiederverwendbarer Baustein:** Im Bestand liegt die Upload-/Remove-Logik inline in `material_detail_page.dart` (`storage.from(bucket).upload/remove`, `createSignedUrl`/`getPublicUrl`). Der Plan **extrahiert einen kleinen gemeinsamen Storage-Helfer** (oder implementiert die vier Foto-Methoden im Durchsicht-Gateway nach diesem Muster) — nicht „vorhandenen Helfer aufrufen". Bild-Plugin (`image_picker`/`file_picker`) wird nur wiederverwendet (kein Neu-Add → kein `flutter clean`-Gotcha).
- **Storage-Orphans beim Volk-Hard-Delete:** `ON DELETE CASCADE` löscht die `inspections`-Zeilen, nicht die Storage-Objekte. `loeschen(id)` räumt Fotos aktiv ab (Löschpflicht); der reine Hard-Delete-Pfad eines Volks ist Fehleingabe-only und hinterlässt best-effort Orphans → 4.25 liefert serverseitige Bereinigung. In §10 bewusst als Restrisiko akzeptiert.
- **Signed-URL-Ablauf:** kurze Gültigkeit (z. B. 1 h); die Timeline lädt Vorschaubilder bei Bedarf — kein Persistieren der Signed-URL.
- **`text[]`-Handhabung** (supabase-dart): `auffaelligkeiten`/`foto_urls` als `List<String>`; leere Liste `[]`, nicht `null`.
- **Record-only** ist bewusst: kein Auto-Update von `voelker.gesundheitsstatus`/`koenigin_id` aus einer Durchsicht.
