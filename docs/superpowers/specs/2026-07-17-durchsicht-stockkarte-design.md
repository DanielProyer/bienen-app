# Design-Spec: Durchsicht/Stockkarte (Modul 4.3) — Kern-Durchsicht

**Stand:** 2026-07-17 · **Status:** Entwurf (Brainstorming abgeschlossen) · **Modell:** Fable 5 (DB/RLS/mandantenkritisch)
**Grundlage:** [Funktionsumfang-Scope](2026-07-11-app-funktionsumfang-scope.md) §4.3 · [App-Implikationen](../../imkerei-fachwissen-app-implikationen.md) · Fachwissen: `../../../imkerei/02_Recherche/11` (Durchsicht, fünf Kernfragen), `10` (Brut/Weisel), `13`/`15` (Auffälligkeiten)
**Baut auf:** Modul 4.2 „Völker & Standorte" (v1.9.0) — die Volk-Detailseite hat eine vorbereitete Platzhalter-Sektion „Verlauf", an die 4.3 andockt.

---

## 1. Zweck

Die **digitale Stockkarte statt Papier**: pro Volk strukturierte, datierte Durchsichts-Einträge, am Stand mit wenigen Taps erfassbar. Die Durchsicht ist die **Beobachtung** (Weisel-, Brut-, Futter-, Platz-, Gesundheitszustand) — sie speist die Volk-Timeline und liefert später (4.17) Selektionsdaten. Sie ist der erste echte **Ereignis-Lieferant** für die 4.2-Drehscheibe.

**Realitätscheck:** Herbst 2026 = 1 Volk. Datenmodell auf 32/64 auslegen, UI schlicht. **YAGNI für die Bedienoberfläche, nicht für Datenintegrität.**

## 2. Scope

### In Scope
- Neue Tabelle `inspections` + Storage-Bucket `inspection-photos`.
- Flutter-Feature `lib/features/durchsicht/`: geführtes Durchsichts-Formular (vollflächige Seite), Timeline in der Volk-Detailseite, Durchsichts-Detailansicht.
- Zwei kleine Eingriffe in 4.2 (Andockstellen): „Verlauf"-Sektion → echte Timeline; `VolkCard` → „letzte Durchsicht vor X Tagen".
- Foto-Upload je Durchsicht (bestehendes Media-Muster).

### Bewusst NICHT in Scope (Begründung)
| Ausgeschlossen | Warum |
|---|---|
| **Echte Folge-Aufgaben (`tasks`)** | Modul 4.4 (Aufgaben/Kalender) existiert nicht. Statt „erzeugt `tasks`" nur ein einfaches Empfehlungsdatum `naechste_durchsicht_am` am Eintrag. |
| **Spracheingabe** | Feld-Komfort; nachrüstbar auf das `notiz`/`massnahmen`-Freitextfeld. |
| **Offline-Feld-Bedienung (PWA-Outbox)** | Eigenes Querschnittsthema (F3/PWA-Härtung), betrifft alle Module. |
| **Konfigurierbare Feldsätze (HiveTracks)** | Bei 1–8 Völkern YAGNI; ein fester, fachlich fundierter Feldsatz ist klarer und schneller. |
| **Auto-Mutation des Volks** | Eine Durchsicht ändert `voelker` **nicht** (kein Auto-Umweiseln/Statusflip). „weisellos" wird sichtbar; Handeln läuft über die 4.2-Aktionen. |
| **Tiefe Krankheits-Diagnose / Meldepflicht** | Modul 4.14. Hier nur `auffaelligkeiten` als Schnell-Flags. |
| **Behandlung/Varroa-Messung** | Modul 4.5. `auffaelligkeiten` enthält höchstens `varroa_sichtbar` als Beobachtung, keine Zählung/Behandlung. |

## 3. Getroffene Entscheide

1. **Zuschnitt = Kern-Durchsicht** (strukturierte Erfassung + Timeline + Foto); Voice/Offline/Config-Felder/echte `tasks` später.
2. **Foto jetzt mit rein** über das bestehende Media-Muster (eigener Bucket, `<betrieb_id>/`-Pfad).
3. **Timeline in der Detailseite statt neuem Nav-Tab** (die Bottom-Nav ist gerade erst auf 6 Tabs austariert); Formular als **vollflächige Seite** (viele Felder), nicht Bottom-Sheet.
4. **Record-only:** Durchsicht = Beobachtung, keine Seiteneffekte auf `voelker`.

## 4. Datenmodell

`inspections` folgt dem etablierten Mandanten-Muster:
- `betrieb_id uuid NOT NULL DEFAULT private.aktive_betrieb_id()` + `created_by`/`updated_by` + `created_at`/`updated_at`.
- Trigger `set_row_actor` + `set_updated_at`.
- RLS-Policies `inspections_{sel_member|ins_writer|upd_writer|del_writer}` (SELECT = Mitglied, Schreiben = owner/editor), `revoke all from anon, public` + `grant select,insert,update,delete to authenticated`.
- Enums als `text` + `CHECK`.
- **Same-Tenant-Integrität:** `volk_id` ist Komposit-FK auf `voelker(betrieb_id, id)` (§4.0 der 4.2-Spec) — verhindert Cross-Betrieb-Durchsichten.

### 4.1 Tabelle `inspections`

| Spalte | Typ | Notiz |
|---|---|---|
| `id` | `uuid PK DEFAULT gen_random_uuid()` | |
| `volk_id` | `uuid NOT NULL` | Komposit-FK `(betrieb_id, volk_id) → voelker(betrieb_id, id) ON DELETE CASCADE` |
| `durchgefuehrt_am` | `date NOT NULL DEFAULT current_date` | |
| **Kontext** | | |
| `wetter` | `text NULL` | Freitext (z. B. „sonnig, 18°") |
| `temperatur_c` | `numeric NULL` | |
| `dauer_min` | `int NULL` | |
| **W — Weisel** | | |
| `weiselzustand` | `text NULL` | CHECK: `weiselrichtig\|weisellos\|drohnenbruetig\|unsicher` |
| `koenigin_gesehen` | `boolean NOT NULL DEFAULT false` | |
| `stifte_gesehen` | `boolean NOT NULL DEFAULT false` | frische Eier = Weiselrichtig-Indiz |
| `weiselzellen` | `text NULL` | CHECK: `keine\|spielnaepfchen\|schwarmzellen\|nachschaffungszellen` |
| `weiselzellen_anzahl` | `int NULL` | |
| **B — Brut** | | |
| `brutbild` | `text NULL` | CHECK: `geschlossen\|lueckig\|bunt\|kaum\|kein` |
| **Stärke** | | |
| `staerke_wabengassen` | `numeric NULL` | besetzte Wabengassen; App schätzt ~1000 Bienen/Gasse |
| **F — Futter** | | |
| `futter_kg` | `numeric NULL` | Schätzung |
| `pollen` | `text NULL` | CHECK: `viel\|mittel\|wenig\|kein` |
| **P — Platz** | | |
| `platz` | `text NULL` | CHECK: `ok\|eng\|honigraum_noetig\|zu_gross` |
| **Verhalten (Selektion, später 4.17)** | | |
| `sanftmut` | `int NULL` | CHECK: `sanftmut between 1 and 4` |
| `wabensitz` | `int NULL` | CHECK: `wabensitz between 1 and 4` |
| **G — Gesundheit** | | |
| `auffaelligkeiten` | `text[] NOT NULL DEFAULT '{}'` | Schnell-Flags: `kalkbrut\|ruhr\|raeuberei\|wachsmotte\|varroa_sichtbar\|kahlflug` (App-seitig gegen Whitelist validiert; tiefe Diagnose = 4.14) |
| **Handeln** | | |
| `massnahmen` | `text NULL` | Freitext, was getan wurde |
| `naechste_durchsicht_am` | `date NULL` | einfache Empfehlung (kein `tasks`-Modul) |
| **Medien/Notiz** | | |
| `foto_urls` | `text[] NOT NULL DEFAULT '{}'` | Bucket `inspection-photos`, Pfad `<betrieb_id>/…` |
| `notiz` | `text NULL` | |
| + audit | | |

**Pflicht:** nur `volk_id` + `durchgefuehrt_am`. Alles andere optional (Schnell-Durchsicht erfasst nur das Gesehene).

**Index:** `create index idx_inspections_volk_datum on public.inspections (betrieb_id, volk_id, durchgefuehrt_am desc)` (Timeline). Zusätzlich `create index idx_inspections_volk on public.inspections (volk_id)` (FK-Index gegen `unindexed_foreign_keys`).

> **`auffaelligkeiten` als `text[]` ohne DB-CHECK:** Postgres-CHECKs auf Array-Elemente sind umständlich; die Whitelist wird **App-seitig** validiert (Gateway lässt nur bekannte Flags durch). Der Katalog ist bewusst schlank und wächst mit 4.14.

### 4.2 Storage-Bucket `inspection-photos`

- Bucket **`inspection-photos`**, **public read** (Foto-Anzeige ohne Signed-URL, wie `construction-photos`).
- **3 authenticated-Write-Policies** (insert/update/delete) exakt nach dem A10-Muster: `bucket_id='inspection-photos'` UND erstes Pfadsegment ist eine `betrieb_id`, in der der Aufrufer schreiben darf (`private.kann_schreiben(((storage.foldername(name))[1])::uuid)`), mit UUID-Regex-Guard.
- Pfadkonvention: `<betrieb_id>/<inspection_id oder uuid>/<datei>`.

## 5. Ableitungen (reine Logik, kein DB-Feld)

- **`bienenSchaetzung(wabengassen)`** → `~1000 × wabengassen` (Richtwert Dadant, Recherche 11). Reine Dart-Funktion, unit-testbar; nur Anzeige, nicht gespeichert.
- **Weiselrichtigkeit-Hinweis:** `stifte_gesehen == true` ⇒ UI-Hinweis „spricht für weiselrichtig". Der/die Imker:in setzt `weiselzustand` trotzdem explizit — keine Auto-Ableitung ins Feld.

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

- **Gateway:** `fuerVolk(volkId)` (absteigend nach `durchgefuehrt_am`), `speichern(Durchsicht)` (insert wenn `id` leer, sonst update), `loeschen(id)`, `fotoHochladen(betriebId, bytes, name)` → URL (Bucket `inspection-photos`, Pfad `<betrieb_id>/…`, wiederverwendet den bestehenden Upload-Helfer aus dem Material-/Construction-Feature). **Fehler-Mapping** wie 4.2 (`PostgrestException` → Klartext, **keine stillen `catch`→`[]`**). `auffaelligkeiten`/`foto_urls` als `text[]`.
- **Whitelist-Validierung:** `auffaelligkeiten` wird im Gateway (oder Domain-Konstruktor) gegen die bekannte Menge gefiltert, bevor geschrieben wird.
- **State:** (a) `durchsichtenFuerVolkProvider = AsyncNotifierProvider.family<…, List<Durchsicht>, String>` (Key = `volkId`, **volle** Timeline für die Detailseite). (b) `letzteDurchsichtenProvider` (AsyncNotifier, **EIN** Query über den ganzen Betrieb: je `volk_id` die neueste Durchsicht — **kein N+1**; die Völkerliste/`VolkCard` liest das gemappt nach `volkId`). Schreibaktionen invalidieren `durchsichtenFuerVolkProvider(volkId)` **und** `letzteDurchsichtenProvider`. **Alle Durchsichts-Provider müssen in `AuthController._datenNeuLaden()`** invalidiert werden (4.2-Gotcha: `ref.invalidate(durchsichtenFuerVolkProvider)` invalidiert alle Family-Instanzen; `ref.invalidate(letzteDurchsichtenProvider)`).
- **Rollen:** `viewer` sieht die Timeline read-only; „+ Durchsicht"/Edit/Löschen nur bei `darfSchreibenProvider`.

### Screens & Andocken
1. **Volk-Detailseite (4.2, `volk_detail_page.dart`):** Die Platzhalter-Sektion „Verlauf — kommt mit Durchsicht/Behandlung" wird zur **`DurchsichtTimeline`** — kompakte `DurchsichtKarte`n (Datum, `weiselzustand`-Chip, Stärke, Kern-Auffälligkeiten, `massnahmen`-Snippet), „+ Durchsicht"-Button (schreibberechtigt), Tap → `durchsicht_detail_page`. Empty-State „Noch keine Durchsicht".
2. **`/voelker/:id/durchsicht`** (neu, `durchsicht_form_page`): vollflächiges, in Abschnitte gegliedertes Formular (Kontext → Weisel → Brut/Stärke → Futter/Platz → Verhalten → Gesundheit → Massnahmen → Foto/Notiz). Große Tap-Ziele; Slider für `sanftmut`/`wabensitz`; Choice-Chips für Enums; Multi-Select-Chips für `auffaelligkeiten`; Foto-Picker. Speichern → zurück zur Detailseite, Timeline invalidiert.
3. **`/voelker/:id/durchsicht/:did`** (neu, `durchsicht_detail_page`): Vollansicht eines Eintrags + Bearbeiten (öffnet das Formular vorbefüllt) + Löschen (schreibberechtigt, mit Bestätigung).
4. **Völkerliste (4.2, `volk_card.dart`):** dezente Zeile „zuletzt gesehen: vor X Tagen" / „noch nie" aus `letzteDurchsichtenProvider` (nach `volkId` gemappt).

Routen als Unterrouten von `/voelker/:id` in `app_router.dart` (Shell bleibt, kein neuer Tab).

## 7. Migrationen & Rollout

| # | Inhalt |
|---|---|
| `D01` | `inspections` + Komposit-FK `(betrieb_id, volk_id)→voelker ON DELETE CASCADE` + CHECKs + RLS/Trigger/Grants + Indizes |
| `D02` | Storage: Bucket `inspection-photos` (public read) + 3 authenticated-Write-Policies (`<betrieb_id>/`-Pfad, A10-Muster) |

Jede Migration: Datei unter `supabase/migrations/` **und** via MCP `apply_migration`; Kopf-Kommentar; **Rollback-DO-SQL-Test**; `get_advisors(security)` → **0 neue Findings** (kein neuer SECURITY-DEFINER-RPC → keine neue 0029-Zeile).

**Kein Ops-Seed** (keine betriebsspezifischen Startwerte nötig). **Kein Errcode-Block** (reines CRUD; Integrität via FK/CHECK/RLS).

**Deploy:** `pubspec` `version:` → **1.10.0+28**, `bash deploy.sh` (manuell).

## 8. Tests

**SQL (Rollback-DO je Migration):**
- Mandanten-Isolation: fremder Betrieb sieht/schreibt keine `inspections`.
- Same-Tenant-FK: Insert mit fremdem/erfundenem `volk_id` → FK-Fehler (23503), identisch zu nicht existierender UUID (kein Existenz-Orakel).
- CHECK-Verletzungen: `weiselzustand`/`brutbild`/`pollen`/`platz`/`weiselzellen`/`sanftmut`(1–4)/`wabensitz`(1–4).
- **`ON DELETE CASCADE`:** Test-Volk + Durchsicht anlegen, Volk hart löschen → Durchsicht ist weg (Transaktion, Rollback).
- `betrieb_id`/`created_by` nicht fälschbar (Trigger friert ein).
- Storage: (soweit über SQL prüfbar) Bucket existiert + Policies vorhanden; funktionaler Upload-Test in der Live-Verifikation.

**Dart:** `bienenSchaetzung()` (Randfälle 0/1/… Gassen); Model-Roundtrip `fromJson`/`toInsertJson` inkl. `text[]` + Enums + Whitelist-Filter für `auffaelligkeiten`; `FakeDurchsichtGateway` (speichern/fuerVolk absteigend/loeschen); Provider-Test (Schreibaktion invalidiert die richtige Family-Instanz); **Provider-Test: nach signOut/signIn ist der Durchsichts-Cache invalidiert**; Rollen-Gating (viewer read-only). `flutter analyze` sauber, alle Tests grün.

## 9. Erweiterungspunkte (bewusst offen)

| Punkt | Für |
|---|---|
| `naechste_durchsicht_am` | 4.4 Aufgaben/Kalender (wird später echte `tasks` erzeugen statt nur Datum) |
| `sanftmut`/`wabensitz`/Brut-/Weiseldaten | 4.17 Zucht (Selektionsbewertung je Volk/Saison) |
| `auffaelligkeiten` | 4.14 Gesundheit (Katalog + Diagnose-Journal + Meldepflicht) |
| `staerke_wabengassen`, `platz` | 4.5 Behandlung (Schwarmkontrolle), 4.7 Honigraum |
| `foto_urls` | 4.25 Medien-/Foto-Verwaltung (zentrale Galerie) |
| `durchsicht_form_page`-Abschnitte | Spracheingabe, konfigurierbare Felder |

## 10. Risiken & offene Punkte

- **Foto-Upload-Helfer wiederverwenden:** Der Plan muss den realen bestehenden Upload-Pfad (Bucket-Insert + `<betrieb_id>/`-Pfad) aus dem Material-/Construction-Feature identifizieren und wiederverwenden, statt neu zu bauen — inkl. `flutter clean`-Gotcha bei Bild-Plugins (falls `image_picker`/`file_picker` neu ginge; wird nur wiederverwendet).
- **`text[]`-Handhabung** (supabase-dart): `auffaelligkeiten`/`foto_urls` als List<String> lesen/schreiben; leere Liste = `{}`, nicht `null`.
- **Bucket-Erstellung** ist eine Storage-Operation (nicht klassisches DDL) — im Plan als expliziter Schritt (via `storage.buckets`-Insert oder Management-API), danach die Policies.
- **Timeline-Performance** bei 32/64 Völkern × vielen Durchsichten: der Index `(betrieb_id, volk_id, durchgefuehrt_am desc)` deckt die Volk-Timeline; die Völkerliste nutzt `letzteDurchsichtenProvider` (ein Query, neueste je `volk_id`) statt N Family-Loads. Der Plan hält die konkrete „latest per volk"-Query fest (z. B. `distinct on (volk_id) … order by volk_id, durchgefuehrt_am desc`).
- **Record-only** ist bewusst: kein Auto-Update von `voelker.gesundheitsstatus`/`koenigin_id` aus einer Durchsicht.
