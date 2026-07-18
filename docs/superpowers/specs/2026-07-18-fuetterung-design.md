# Design-Spec: Fütterung (Modul 4.6) — Fütterungs-Log + Winterfutter-Ziel + Material + Bio-Nachweis

**Stand:** 2026-07-18 · **Status:** Entwurf (Brainstorming abgeschlossen) · **Modell:** Fable 5 (DB/RLS/Mandanten + Bio-Nachweis)
**Grundlage:** [Funktionsumfang-Scope](2026-07-11-app-funktionsumfang-scope.md) §4.6 · [App-Implikationen](../../imkerei-fachwissen-app-implikationen.md) · Fachwissen: `../../../imkerei/02_Recherche/18` (Bio/Knospe: erlaubte Futtermittel, Timing), `02` (Jahresablauf alpin: Auffütter-Fenster, Zielvorrat)
**Baut auf:** 4.2 „Völker & Standorte" (`betriebs_einstellungen`/F4-Keimzelle, Volk-Detailseite als Drehscheibe), 4.5 „Behandlungen" (RPC-Sammel­erfassung + Material-Kopplung — 4.6 ist dessen **Zwilling auf Bio-Nachweis-Niveau**).

---

## 1. Zweck

Der **Fütterungs-Log** je Volk als **Bio-Nachweis** (Knospe/Bio Suisse: lückenlose Futterdokumentation) plus **Winterfutter-Ziel-Tracking** (Auffütterung gegen ein mandantenfähiges kg-Ziel) und **atomare Lager-Abbuchung** des Futtermittels. Kernnutzen: nachvollziehbare Fütterungshistorie (Auffütterung/Reiz/Notfütterung), ein Fortschrittsbalken „X / 22 kg aufgefüttert" je Volk, Bio-Konformitäts-Warnung bei Nicht-Bio-Futter.

**Realitätscheck:** Herbst 2026 = 1 Volk, alpin (1570 m) → enges Auffütter-Fenster (Abschluss ~KW 37 / 10. Sept.), Winterfutter entscheidet über die Überwinterung. UI schlicht, Datenmodell auf 32/64. **YAGNI für die UI, nicht für die Bio-Nachweis-Spur.**

**Abgrenzung zu 4.5:** Fütterung ist ein **Bio-Nachweis** (Knospe-Zertifizierung), **kein** federal TAMV-Tierarzneimittel-Pflichtjournal. Deshalb **Soft-Delete + Storno statt** der vollen Unveränderlichkeits-Maschinerie von 4.5 (kein `RESTRICT`, kein Immutable-Trigger) — proportional zur rechtlichen Anforderung.

## 2. Scope

### In Scope
- Tabelle `fuetterungen` (Bio-Nachweis-Log) + `betriebs_einstellungen` um `winterfutter_ziel_kg` erweitert.
- RPC `fuetterung_erfassen` (atomar: N Einträge je Volk + Lager-Abbuchung + Validierung).
- Flutter-Feature `lib/features/fuetterung/`: Erfassungs-Formular (Sammelfütterung), **Winterfutter-Fortschrittsbalken**, Andocken an die Volk-Detailseite.
- **Material-Kopplung** (Futtermittel aus `materials` → `stock_qty`-Abbuchung).
- **Bio-Warn-Gelb** (Nicht-Bio-Futter auf einem Bio-Volk).
- **Soft-Delete/Storno** (kein Hard-Delete → Bio-Audit-Spur).

### Bewusst NICHT in Scope (Begründung)
| Ausgeschlossen | Warum |
|---|---|
| **Voll-Revisionssicherheit (RESTRICT/Immutable-Trigger)** | Fütterung ist Bio-Nachweis, kein federal Pflichtjournal — Soft-Delete + Storno ist proportional. Die harte Maschinerie bleibt 4.5 vorbehalten. |
| **Bio-Fenster-/Timing-Warnung** (Auffütterung nach Stichtag, „<15 T vor Tracht") | Braucht den `saison_offset` (Höhe/Phänologie) → Modul 4.4 Kalender / 4.23. Hier nur die **klare** Bio-Warnung (Nicht-Bio-Futter). |
| **Blockier-Rot Bio-Regel-Engine** | 4.23 Bio-Layer. Hier nur Warn-Gelb (allow save). |
| **Lieferschein-/Beleg-Upload zum Bio-Zertifikat** | 4.25 Medien / 4.23. `bio_zertifiziert` (bool) genügt für v1; der Upload dockt später an. |
| **Futtervorrat aus der Waage** (Gewichts-Schätzung Restfutter) | 4.9 Monitoring (HiveWatch-Gewicht). Hier zählt nur die **erfasste** Auffütterung, nicht das gewogene Restfutter. |
| **Konfigurierbares Auffütter-Fenster / Ziel-UI (F4)** | `winterfutter_ziel_kg` ist als Betriebsparameter angelegt (Default 22); die Settings-UI kommt mit F4. Fenster-Start (1. Juli) vorerst Fachdefault. |

## 3. Getroffene Entscheide

1. **Zuschnitt = Voll (4.5-Zwilling):** Log + Winterfutter-Ziel-Fortschritt + Material-Kopplung + Bio-Warnung, angedockt an die Volk-Detailseite.
2. **Journal-Integrität = Bio-Nachweis-Niveau:** **Soft-Delete + Storno** (`is_storniert`/`storno_grund`/`storno_am`), **kein Hard-Delete** (keine DELETE-Policy → Bio-Audit-Spur), **kein Immutable-Trigger**, Edit auf DB-Ebene erlaubt. **Insert dennoch nur via RPC** (keine INSERT-Policy) — das garantiert die atomare Lager-Abbuchung + Sammelfütterungs-Validierung. Korrektur in der v1-UI = **Storno + Neueintrag** (Lager-Konsistenz).
3. **Winterfutter-Ziel in `betriebs_einstellungen`** (F4-Tabelle aus 4.2), `winterfutter_ziel_kg numeric NOT NULL default 22` (Recherche 18/02: Dadant-Zielvorrat 22–25 kg). Mandantenfähig, **kein Arosa-Hardcode**.
4. **Nur `auffuetterung` zählt fürs Winterziel** — Reiz-/Notfütterung sind eigene Zwecke, bauen aber keinen Wintervorrat auf (fachlich korrekt).
5. **Bio-Warnung = Warn-Gelb** bei `!bio_zertifiziert` auf einem nicht-konventionellen Volk (auf die Multi-Select-Auswahl bezogen, wie 4.5). Blockier-Rot + Timing-Fenster sind 4.23/4.4.

## 4. Datenmodell

Mandanten-Muster (`betrieb_id NOT NULL DEFAULT private.aktive_betrieb_id()`, Audit, `set_row_actor`/`set_updated_at`, `revoke anon/public`+`grant authenticated`, Enums text+CHECK, `unique(betrieb_id,id)`). Same-Tenant-Komposit-FKs (D-15).

### 4.1 `betriebs_einstellungen` erweitern
Additive Spalte `winterfutter_ziel_kg numeric NOT NULL default 22` (backfillt die bestehende Arosa-Zeile auf 22). Wird vom `BetriebsEinstellungen`-Modell (4.2) gelesen.

### 4.2 `fuetterungen` (Bio-Nachweis-Log)

| Spalte | Typ | Notiz |
|---|---|---|
| `id` | `uuid PK` | |
| `volk_id` | `uuid NOT NULL` | Komposit-FK → `voelker`, **`ON DELETE CASCADE`** (kein federal Pflichtjournal — Volk-Hard-Delete darf miträumen) |
| `durchgefuehrt_am` | `date NOT NULL DEFAULT current_date` | |
| `zweck` | `text NOT NULL` | CHECK `auffuetterung\|reizfuetterung\|notfuetterung` |
| `futterart` | `text NOT NULL` | CHECK `zuckersirup\|zuckerwasser\|futterteig\|futterwaben\|eigener_honig\|sonstige` (physische Form) |
| `bio_zertifiziert` | `boolean NOT NULL DEFAULT false` | Bio-Status (Recherche 18); steuert die Warn-Gelb-Prüfung |
| `menge_kg` | `numeric NOT NULL` | CHECK `> 0` |
| `material_id` | `uuid NULL` | Komposit-FK → `materials(betrieb_id,id)` **`ON DELETE SET NULL (material_id)`** (Lager-Kopplung) |
| `verantwortliche_person` | `text NULL` | App füllt mit dem handelnden Mitglied vor |
| `is_storniert` | `boolean NOT NULL DEFAULT false` | Soft-Delete |
| `storno_grund` | `text NULL` | Pflicht bei Storno (CHECK) |
| `storno_am` | `date NULL` | beim Storno gesetzt (Gateway); `updated_at` liefert die Server-Wahrheit |
| `notiz` | `text NULL` | |
| + audit | | |

**CHECK:** `is_storniert = false OR (storno_grund is not null and storno_am is not null)`.
**RLS:** `fuetterungen_sel_member` (SELECT) + `fuetterungen_upd_writer` (UPDATE, Storno/Edit). **KEINE INSERT-Policy** (Insert nur via RPC → atomare Lager-Abbuchung) und **KEINE DELETE-Policy** (Soft-Delete). *Bewusst kein Immutable-Trigger (anders als 4.5).*
Index `(betrieb_id, volk_id, durchgefuehrt_am desc)` (deckt die FK `(betrieb_id, volk_id)` führend ab); FK-Index `(betrieb_id, material_id)`.

### 4.3 RPC `fuetterung_erfassen` (security definer — der Schreibpfad)

```
fuetterung_erfassen(
  p_volk_ids uuid[], p_durchgefuehrt_am date, p_zweck text, p_futterart text,
  p_menge_kg numeric, p_bio_zertifiziert boolean,
  p_material_id uuid default null, p_verantwortliche_person text default null, p_notiz text default null
) → int   -- Anzahl real erzeugter Einträge (= distinct Völker)
```
- `SECURITY DEFINER`, `SET search_path = ''`, volle Qualifizierung; `revoke … from anon, public` + `grant … to authenticated`.
- **Guard zuerst:** `p_volk_ids is null or cardinality = 0` → **`BA041`**.
- **Völker-Validierung** (einheitliche `BA041`-Meldung, kein Existenz-Orakel): alle gefunden (`count(distinct id)` = distinct-Eingabe), genau ein Betrieb, `kann_schreiben(v_betrieb)` — sonst `BA041`.
- **Pflichtfelder `BA040`:** `p_durchgefuehrt_am is null OR p_zweck is null OR p_futterart is null OR p_menge_kg is null OR p_menge_kg <= 0`.
- **Material-Tenancy `BA042`:** `p_material_id` gesetzt und gehört nicht zu `v_betrieb`.
- **Ablauf (atomar):** `insert … select distinct unnest(p_volk_ids)` mit **`betrieb_id := v_betrieb` explizit**; `get diagnostics v_n = row_count`; falls `p_material_id`: `update materials set stock_qty = stock_qty - coalesce(p_menge_kg,0) * v_n where id = p_material_id and betrieb_id = v_betrieb`; `return v_n`.
- **Storno/Edit** laufen als normales `UPDATE` (RLS `upd_writer`); Storno setzt `is_storniert=true`, `storno_grund`, `storno_am`. **Kein** Lager-Rückbuchen.

**Errcode-Registry:** BA001–013 Auth · BA020–029 = 4.2 · BA030–039 = 4.5 · **BA040–049 = Modul 4.6** (BA040 Pflichtfeld, BA041 Völker, BA042 Material-Tenancy).

## 5. Ableitungen (reine Logik, Dart)

- **`winterfutterKg(fuetterungen, jahr)` → double:** Σ `menge_kg` über die nicht-stornierten Einträge mit `zweck == 'auffuetterung'` und `durchgefuehrt_am >= DateTime(jahr, 7, 1)` (Auffütter-Saison ab 1. Juli). Reiz-/Notfütterung zählen **nicht**. Fenster-Start als Konstante (später F4-konfigurierbar).
- **`winterfutterProzent(kg, zielKg)` → double** (null-sicher, `zielKg <= 0` → 0): `min(1, kg / zielKg)` für den Balken.
- **Bio-Helper `istBioFutter(bioZertifiziert)`** bzw. die Banner-Regel: Warnung, wenn `!bioZertifiziert` und mindestens ein selektiertes Volk `bioStatus != 'konventionell'`.
- **`futterartLabels` / `zweckLabels`** als Dart-Konstanten (Anzeige).

## 6. App-Schicht (`lib/features/fuetterung/`)

```
domain/       futterart.dart (Enums+Labels+Bio-Helper) · fuetterung.dart (Modell)
              winterfutter.dart (reine Funktionen) · fuetterung_gateway.dart
data/         supabase_fuetterung_gateway.dart · fake_fuetterung_gateway.dart
presentation/ providers/fuetterung_provider.dart
              pages/fuetterung_form_page.dart
              widgets/fuetterung_section.dart · winterfutter_balken.dart
```

- **Gateway:** `fuetterungenFuerVolk(volkId)` (inkl. stornierte, absteigend) · **`fuetterungErfassen({volkIds, …, materialId})`** (RPC) · `fuetterungStornieren(id, grund)`. Fehler-Mapping `BA040–042` + `PostgrestException` → Klartext; keine stillen Fallbacks.
- **State:** Family-Provider `fuetterungenFuerVolkProvider(volkId)`. Sammel-Erfassung über `fuetterungAktionenProvider` → invalidiert **jede** beteiligte Volk-Family **+ `materialListProvider`** (D-18-Gotcha, wie 4.5). **Provider in `AuthController._datenNeuLaden()`.** `viewer` read-only.
- **UI — neue Sektion „Fütterung" auf der Volk-Detailseite** (unter „Varroa & Behandlung"):
  1. **Winterfutter-Balken** (`winterfutter_balken.dart`): liest `fuetterungenFuerVolkProvider(volkId)` **und** `betriebsEinstellungenProvider` (Ziel) → Fortschritt „X.X / 22 kg (Y %)"; grün ab Ziel erreicht, sonst amber; Hinweis „Ziel noch nicht erreicht".
  2. Button (schreibberechtigt) „Fütterung erfassen" → `fuetterung_form_page`.
  3. Kompakte Liste letzte Fütterungen (Zweck-Chip · `menge_kg` · Futterart; **storniert = durchgestrichen** + Grund; Storno-Button für Schreibberechtigte).
- **`fuetterung_form_page`** (Vollseite, Rollen-Guard im `build`, `context.mounted`-Checks, Dropdown-Prewarming `await …future`): **Völker-Multi-Select** (Default aktuelles Volk); Datum; **Zweck**-Chips (Auffütterung/Reiz/Not); **Futterart**-Dropdown; **Bio-zertifiziert**-Switch; **Menge (kg)**; **Material-Dropdown** (`materialListProvider`, `is_consumable`, `bereich='imkerei'`); Verantwortliche:r (vorbefüllt). **Bio-Warnbanner (gelb)** wenn `!bio_zertifiziert` UND ≥1 selektiertes Volk `bioStatus != 'konventionell'`. Speichern → `fuetterungErfassen`. Pflichtfeld-Validierung client **und** hart in RPC.

## 7. Migrationen & Rollout

| # | Inhalt |
|---|---|
| `F01` | `betriebs_einstellungen.winterfutter_ziel_kg` (Default 22); `fuetterungen` (Komposit-FKs, CHECKs, RLS **ohne INSERT/DELETE-Policy**, Trigger, Grants, Indizes) |
| `F02` | RPC `fuetterung_erfassen` + Grants |

Jede Migration: Datei (`supabase/migrations/`) + MCP `apply_migration`; Kopf-Kommentar; **Rollback-DO-Test**; `get_advisors(security)` → genau **1 erwartete neue 0029** (RPC `fuetterung_erfassen`, wie `behandlung_erfassen`), sonst 0. **Kein Ops-Seed** (Default 22 genügt). `materials.unique(betrieb_id,id)` existiert schon (E01) → FK-Ziel wiederverwendbar.

**App:** `BetriebsEinstellungen`-Modell (4.2) um `winterfutterZielKg` (fromJson, Default 22) erweitern.
**Deploy:** `version:` → **1.12.0+30**, `bash deploy.sh` (stehende Freigabe).

## 8. Tests

**SQL (Rollback-DO):**
- Mandanten-Isolation (fremder Betrieb sieht/schreibt nichts).
- Komposit-FK: fremdes/erfundenes `volk_id`/`material_id` → FK-Fehler.
- CHECK: `zweck`/`futterart`-Whitelist, `menge_kg > 0`, Storno-Vollständigkeit.
- **RPC `fuetterung_erfassen`:** `[v,v]` → **1 Zeile** (distinct); Abbuchung `stock_qty − menge_kg × ROW_COUNT`; `betrieb_id` aus dem Volk (nicht JWT); wirft `BA040`/`BA041`/`BA042`; `p_volk_ids = NULL`/`{}` → BA041 (kein `stock_qty`-Schaden).
- **Kein direkter INSERT** (keine Policy) und **kein Hard-DELETE** (keine Policy); Storno-UPDATE funktioniert.
- `winterfutter_ziel_kg`-Default 22 auf einer neuen `betriebs_einstellungen`-Zeile.
- `betrieb_id`/`created_by` nicht fälschbar.

**Dart:** `winterfutterKg` (nur `auffuetterung`, Reiz/Not/storniert ausgeschlossen, Fenster-Grenze 1. Juli, Jahreswechsel), `winterfutterProzent` (0-Ziel, Clamp auf 1); `futterart`/Bio-Helper; Modell-Roundtrip; `FakeFuetterungGateway` (distinct-Sammel-Insert + Lager-Sim + `BA040/041/042` + Storno); Provider-Test (Sammelfütterung A+B invalidiert **beide** Families + `materialListProvider`); **signOut invalidiert Cache**; Rollen-Gating; Dropdown-Prewarming. `flutter analyze` sauber, alle grün.

## 9. Erweiterungspunkte (bewusst offen)

| Punkt | Für |
|---|---|
| `fuetterungen` (`bio_zertifiziert`, Soft-Delete-Spur) | 4.23 revisionssicherer BLV-/Knospe-Export (Fütterungsnachweis) + Bio-Regel-Engine (Blockier-Rot) |
| Lieferschein-/Beleg-Upload zu `bio_zertifiziert` | 4.25 Medien (privater Bucket, wie 4.3-Fotos) |
| Auffütter-Fenster-/Timing-Warnung (`saison_offset`, „<15 T vor Tracht") | 4.4 Kalender / 4.23 |
| `winterfutter_ziel_kg` + Fenster-Start | F4 Settings (pro Betrieb editierbar) |
| Restfutter-Schätzung aus Waage-Gewicht | 4.9 Monitoring |
| Bestandeskontroll-/Ein-Eintrag-drei-Nachweise-Bezug | 4.23 (Fütterung → Bio-Nachweis + Bestandeskontrolle) |

## 10. Risiken & offene Punkte

- **Insert-nur-via-RPC:** `fuetterungen` hat keine INSERT-Policy → jeder Eintrag MUSS über `fuetterung_erfassen` (der Fake-Gateway bildet distinct/Validierung nach). Bewusst.
- **Storno bucht nicht zurück:** wie 4.5 — das Futter wurde ggf. verbraucht; der Imker korrigiert das Lager sonst manuell. `storno_am` ist client-gesetzt (kein Trigger); `updated_at` liefert die Server-Wahrheit — für einen Bio-Nachweis (nicht federal) akzeptiert.
- **Einheiten-Mismatch:** `menge_kg` (kg) vs. `materials.unit` (Freitext) — wird ein in Säcken/Litern geführtes Material abgebucht, ist der Lagerwert unpräzise. Weiche Formular-Warnung optional; das Bio-Journal bleibt korrekt. Restrisiko (wie 4.5).
- **`stock_qty` kann negativ werden** (Über-Erfassung) — kein Clamp; die Nachkauflogik zeigt es an. Bewusst.
- **Fenster-Start (1. Juli) hartkodiert** — universeller Fachdefault (Auffütter-Saison), kein Arosa-Hardcode; F4 macht ihn später konfigurierbar. Bei sehr frühen/späten Regionen ggf. ungenau.
- **`volk_id` CASCADE:** ein Volk-Hard-Delete räumt den Fütterungs-Log mit weg. Bewusst (Fütterung ist Bio-Nachweis, kein federal Pflichtjournal wie 4.5; Volk-Hard-Delete ist Fehleingabe-only, Abgang = Status).
- **Bio-Warnung nur auf `bio_zertifiziert`:** die Timing-Komponente (Auffütterung zu spät für die Winterfestigkeit) fehlt bewusst (braucht `saison_offset` → 4.4/4.23).
