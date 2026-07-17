# Design-Spec: Völker & Standorte (Modul 4.2) — Stammdaten-Kern

**Stand:** 2026-07-17 · **Status:** freigegeben (Brainstorming) · **Modell:** Fable 5 (DB/RLS/mandantenkritisch)
**Grundlage:** [Funktionsumfang-Scope](2026-07-11-app-funktionsumfang-scope.md) §4.2 · [App-Implikationen aus der Imkerei-Recherche](../../imkerei-fachwissen-app-implikationen.md) · Fachwissen: `../../../imkerei/02_Recherche/10`, `12`, `13`, `19`

---

## 1. Zweck

Das erste echte Fachmodul auf dem Auth-Fundament. **Jedes Volk wird ein Datensatz**, an dem später alles hängt (Durchsicht, Behandlung, Fütterung, Ernte, Waage, Bestandeskontrolle). Dazu die zwei Entitäten, ohne die ein Volk ab Volk 1 unvollständig ist: der **Standort** (TVD-/Bestandeskontroll-Pflichtfelder) und die **Königin** (Selektions- und Zuchtbasis).

**Realitätscheck:** Herbst 2026 = **1 Volk**, 2027 = 2, bis 2030 max. 8. Das **Datenmodell** wird auf 32/64 ausgelegt, die **UI** bewusst schlicht gehalten. YAGNI gilt für Bedienoberfläche, nicht für Datenintegrität.

## 2. Scope

### In Scope
- Neue Tabellen `betriebs_einstellungen`, `standorte`, `koeniginnen`; `voelker` erweitern + aufräumen.
- Flutter-Feature `lib/features/voelker/`: Völkerliste, Volk-Detailseite (Drehscheibe), Formulare, Umweiselung.
- Jahresfarbe-Ableitung, Umweiselungs-RPC, RLS + Tests + Advisor-Gate.

### Bewusst NICHT in Scope (Begründung)
| Ausgeschlossen | Warum |
|---|---|
| **Ampel-Status** (Weiselrichtigkeit, Varroa-Last, Futterstand) | Speist sich aus 4.3/4.5/4.6 — Tabellen existieren nicht. Erst sinnvoll, wenn es Daten gibt. |
| **Ereignis-Timeline** | Dito. Wird als **Erweiterungspunkt** vorbereitet (Platzhalter-Sektion), damit 4.3/4.5 andocken statt umbauen. |
| **QR-/NFC-Etikett, Sammelaktionen (Bulk)** | YAGNI bei 1–8 Völkern. Sinnvoll ab ~32. |
| **Zuchtbuch voll** (Umlarv-Kalender, Leistungsprüfung, Pedigree-UI) | Modul 4.17, P3 (ab 2028). Das Datenmodell hält den Anschluss offen (`mutter_koenigin_id`). |
| **Restliche F4-Settings** (Varroa-Schwellen, Winterfutter-Soll, Fristen) | Nur die von 4.2 benötigten Parameter jetzt; `betriebs_einstellungen` ist die Keimzelle. |

## 3. Getroffene Entscheide

1. **Zuschnitt = Stammdaten-Kern.** Ampel/Timeline als vorbereitete Erweiterungspunkte statt Halbfertig-Bau.
2. **Betriebs-Defaults in eigener `betriebs_einstellungen`-Tabelle** (1:1 je Betrieb, typisierte Spalten) statt Spalten auf `betriebe` — hält Identität und Konfiguration getrennt und ist die F4-Keimzelle.
3. **Königin als eigene Entität** (nicht Felder am Volk) — nur so ist die **Umweiselung mit Historie** abbildbar und 4.17 anschlussfähig.

## 4. Datenmodell

Alle neuen Tabellen folgen dem etablierten Mandanten-Muster:
- `betrieb_id uuid NOT NULL DEFAULT private.aktive_betrieb_id()`
- `created_by`/`updated_by uuid`, `created_at`/`updated_at timestamptz DEFAULT now()`
- Trigger `set_row_actor` (setzt Aktor, friert `betrieb_id` via `coalesce` ein) + `update_updated_at`
- RLS (Policy-Namen nach Bestandsschema `<tabelle>_{sel_member|ins_writer|upd_writer|del_writer}`):
  - `SELECT`: `betrieb_id IN (SELECT private.meine_betrieb_ids())`
  - `INSERT`: `WITH CHECK private.kann_schreiben(betrieb_id)`
  - `UPDATE`: `USING` + `WITH CHECK private.kann_schreiben(betrieb_id)`
  - `DELETE`: `USING private.kann_schreiben(betrieb_id)`
- Enums als `text` + `CHECK` (migrationsfreundlicher als PG-Enums, folgt dem Bestandsstil).

### 4.1 `betriebs_einstellungen` (neu, 1 Zeile je Betrieb)

| Spalte | Typ | Notiz |
|---|---|---|
| `betrieb_id` | `uuid PK` → `betriebe(id) ON DELETE CASCADE` | zugleich PK **und** FK → erzwingt 1:1 |
| `rasse_default` | `text NULL` | z. B. „Buckfast" — **Daten, kein Code** |
| `beutensystem_default` | `text NULL` | z. B. „Dadant Blatt 10er" |
| `hoehe_m` | `int NULL` | Standard-Höhe des Betriebs (Standort kann abweichen) |
| `saison_offset_tage` | `int NOT NULL DEFAULT 0` | alpine Phänologie-Verschiebung; 0 = Flachland-Normal |
| `kanton` | `text NULL` | Steuerfeld für spätere Formulare/Fristen/Kontakte |
| + audit | | |

**Auto-Anlage:** `betrieb_gruenden` legt die Zeile mit Neutralwerten an (`saison_offset_tage = 0`, Rest `NULL`). **Kein Arosa-Default im Code.**

### 4.2 `standorte` (neu)

| Spalte | Typ | Notiz |
|---|---|---|
| `id` | `uuid PK DEFAULT gen_random_uuid()` | |
| `name` | `text NOT NULL` | |
| `gps_lat`, `gps_lng` | `numeric NULL` | einfache Koordinaten (PostGIS: YAGNI) |
| `hoehe_m` | `int NULL` | überschreibt Betriebs-Höhe für diesen Stand |
| `amtliche_standnummer` | `text NULL` | GR-Standnummer (Plakette) |
| `tvd_betriebsnummer` | `text NULL` | |
| `inspektionskreis` | `text NULL` | |
| `trachtnotiz` | `text NULL` | |
| `sperrbezirk` | `boolean NOT NULL DEFAULT false` | AFB/EFB-Flag |
| `notes`, `sort_order` | `text` / `int DEFAULT 0` | |
| + audit | | |

### 4.3 `koeniginnen` (neu)

| Spalte | Typ | Notiz |
|---|---|---|
| `id` | `uuid PK DEFAULT gen_random_uuid()` | |
| `kennung` | `text NULL` | Nummer/Zeichen des Imkers |
| `schlupfjahr` | `int NULL` | **Quelle der Jahresfarbe** (nicht gespeichert) |
| `herkunft` | `text NULL` | z. B. „Tino Hassler, Maladers" |
| `begattungsart` | `text NOT NULL DEFAULT 'unbekannt'` | CHECK: `standbegattung\|belegstelle\|instrumentell\|unbekannt` |
| `status` | `text NOT NULL DEFAULT 'aktiv'` | CHECK: `aktiv\|ersetzt\|tot\|verschollen` |
| `mutter_koenigin_id` | `uuid NULL` → `koeniginnen(id) ON DELETE SET NULL` | Stammbaum-Anschluss für 4.17 |
| `notes` | `text NULL` | |
| + audit | | |

### 4.4 `voelker` (erweitern — Tabelle ist **leer**, keine Datenmigration)

**Neu:**

| Spalte | Typ | Notiz |
|---|---|---|
| `standort_id` | `uuid NULL` → `standorte(id) ON DELETE SET NULL` | Stand löschen darf Völker nicht löschen |
| `koenigin_id` | `uuid NULL` → `koeniginnen(id) ON DELETE SET NULL` | **aktuelle** Königin |
| `mutter_volk_id` | `uuid NULL` → `voelker(id) ON DELETE SET NULL` | Ableger-Herkunft (4.16-Anschluss) |
| `beutentyp` | `text NULL` | **kein** DB-Default; App belegt beim Anlegen aus `betriebs_einstellungen.beutensystem_default` vor (editierbar) |
| `zargen` | `int NULL` | |
| `brutwaben` | `int NULL` | |
| `bio_status` | `text NOT NULL DEFAULT 'unbekannt'` | CHECK: `bio\|umstellung\|konventionell\|unbekannt` |
| `gesundheitsstatus` | `text NOT NULL DEFAULT 'unauffaellig'` | CHECK: `unauffaellig\|beobachtung\|krank\|sperre` |

**Aufräumen (Hardcode-/Altlast-Beseitigung):**
- `ALTER COLUMN rasse DROP DEFAULT` — der `'Buckfast'`-Default ist ein Arosa-Hardcode. Rasse kommt beim Anlegen aus `betriebs_einstellungen.rasse_default` (App-seitig vorbelegt, editierbar).
- `DROP COLUMN standort` (Freitext) → ersetzt durch `standort_id`.
- `DROP COLUMN koenigin_jahr` → ersetzt durch `koeniginnen.schlupfjahr`.
- **Vorbedingung:** beide Spalten sind unbenutzt (Tabelle leer, kein `voelker`-Feature im Code). Im Plan als expliziter Prüfschritt (`grep`) vor dem Drop.

**Bestehend & unverändert:** `id`, `name NOT NULL`, `rasse`, `herkunft`, `einweiselung_am`, `status` (Default `'aktiv'`), `notes`, `sort_order`, audit. `scales.volk_id` verweist bereits auf `voelker` — Waage-Verknüpfung steht.

**Indizes:** `voelker(betrieb_id, standort_id)`, `voelker(betrieb_id, koenigin_id)`, `koeniginnen(betrieb_id, status)`, `standorte(betrieb_id, sort_order)`.

## 5. Jahresfarbe

Fixer internationaler 5er-Zyklus über die **Endziffer** des Schlupfjahrs — **kein Mandanten-Config**, keine DB-Spalte:

| Endziffer | 1/6 | 2/7 | 3/8 | 4/9 | 5/0 |
|---|---|---|---|---|---|
| Farbe | **weiss** | **gelb** | **rot** | **grün** | **blau** |

→ 2026 = weiss · 2027 = gelb · 2028 = rot · 2029 = grün · 2030 = blau.

Reine Dart-Funktion `jahresfarbe(int schlupfjahr) → Jahresfarbe` in der Domain-Schicht. Vollständig unit-testbar, kein DB-/Netzzugriff. *(Quelle: `imkerei/02_Recherche/11`, `12` — Fable-verifiziert.)*

## 6. Umweiselung (RPC `volk_umweiseln`)

Umweiseln muss **atomar** sein: alte Königin auf `ersetzt`, neue verknüpfen. Zwei Einzel-Writes könnten ein Volk königinlos zurücklassen.

```
volk_umweiseln(p_volk_id uuid, p_neue_koenigin_id uuid) → void
```
- `SECURITY DEFINER`, `SET search_path = ''`, alle Objekte voll qualifiziert.
- `REVOKE EXECUTE ... FROM anon, public` · `GRANT EXECUTE ... TO authenticated`.
- Prüft über `private.kann_schreiben()`, dass Volk **und** Königin zum schreibberechtigten Betrieb des Aufrufers gehören.
- Ablauf: alte `voelker.koenigin_id` (falls vorhanden) → `koeniginnen.status = 'ersetzt'`; `voelker.koenigin_id = p_neue_koenigin_id`. Eine Transaktion.

**Fehlercodes (Serie `BA0xx`, stabil):**

| Code | Bedeutung |
|---|---|
| `BA010` | Volk nicht gefunden oder gehört nicht zu deinem Betrieb |
| `BA011` | Königin nicht gefunden oder gehört nicht zu deinem Betrieb |
| `BA012` | Königin ist bereits einem anderen Volk zugeordnet |

## 7. App-Schicht (`lib/features/voelker/`)

Nach dem Muster von `construction`/`material` + der Gateway-Trennung aus `auth`:

```
features/voelker/
  domain/        volk.dart · standort.dart · koenigin.dart · betriebs_einstellungen.dart
                 jahresfarbe.dart (reine Funktion) · voelker_gateway.dart (Interface)
  data/          supabase_voelker_gateway.dart · fake_voelker_gateway.dart
  presentation/  providers/voelker_provider.dart
                 pages/voelker_page.dart · volk_detail_page.dart
                 widgets/volk_card.dart · koenigin_section.dart · standort_section.dart · volk_form.dart
```

- **Gateway:** CRUD für die vier Objekte + `umweiseln()`. Völkerliste lädt Standort + Königin **in einem** Select mit Relation (kein N+1). Mappt `BA0xx`/`PostgrestException` auf Klartext — **keine stillen `catch`→`[]`-Fallbacks**.
- **State:** `voelkerListProvider`, `standorteProvider`, `koeniginnenProvider`, `betriebsEinstellungenProvider` (Riverpod `AsyncNotifier`, ohne Codegen). Schreibaktionen invalidieren gezielt.
- **Rollen:** `viewer` → read-only (Schreib-Buttons ausgeblendet); RLS bleibt die harte Grenze, die UI ist die freundliche.
- **Screens:**
  1. `/voelker` (neuer Nav-Tab „Völker"): Karten je Volk — Name, Standort, Königin-Jahresfarbe als Punkt, Status-Chip; Suche/Filter; Empty-State „Erstes Volk anlegen".
  2. `/voelker/:id` — **Drehscheibe**: Sektionen Stammdaten · Königin · Beute · Standort · Waage-Link + **Platzhalter-Sektion „Verlauf — kommt mit Durchsicht/Behandlung"** (Erweiterungspunkt für 4.3/4.5).
  3. Formulare als Bottom-Sheet/Dialog: Volk anlegen/bearbeiten (Rasse/Beute aus `betriebs_einstellungen` vorbelegt), Königin anlegen/zuordnen, **Umweiseln**, Standort verwalten.

## 8. Migrationen & Rollout

| # | Inhalt |
|---|---|
| `C01` | `betriebs_einstellungen` + RLS/Trigger + Auto-Anlage in `betrieb_gruenden` |
| `C02` | `standorte` + RLS/Trigger/Indizes |
| `C03` | `koeniginnen` + RLS/Trigger/CHECKs/Indizes |
| `C04` | `voelker`: neue Spalten/FKs/CHECKs/Indizes, `rasse`-Default entfernen, `standort` + `koenigin_jahr` droppen |
| `C05` | RPC `volk_umweiseln` + Grants |

Jede Migration: Datei unter `supabase/migrations/` **und** via MCP `apply_migration`; Kopf-Kommentar; **Rollback-DO-SQL-Test**; danach `get_advisors(security)` → **0 neue Findings**.

**Ops (keine Migration):** `supabase/ops/seed-arosa-einstellungen.sql` setzt für den Betrieb *Imkerei-Projekt Arosa*: `rasse_default='Buckfast'`, `beutensystem_default='Dadant Blatt 10er'`, `hoehe_m=1570`, `saison_offset_tage=42`, `kanton='GR'`. **Arosa ist Daten, kein Code.**

**Deploy:** `pubspec` `version:` bumpen → `bash deploy.sh` (manuell, wie immer).

## 9. Tests

**SQL (Rollback-DO je Migration):**
- Mandanten-Isolation: fremder Betrieb sieht/schreibt weder `standorte`, `koeniginnen` noch erweiterte `voelker`.
- `betrieb_id`/`created_by` nicht fälschbar (Trigger friert ein).
- `volk_umweiseln`: Erfolgsfall (alte → `ersetzt`, neue verknüpft) + `BA010`/`BA011`/`BA012`.
- `ON DELETE SET NULL`: Stand/Königin löschen lässt Völker leben.
- `betriebs_einstellungen`: Auto-Anlage bei `betrieb_gruenden`, 1:1 erzwungen.

**Dart:** `jahresfarbe()` (alle 10 Endziffern, inkl. 2026=weiss); Gateway gegen `FakeVoelkerGateway`; Provider-Tests; Rollen-Gating (viewer read-only). `flutter analyze` sauber, alle Tests grün.

## 10. Erweiterungspunkte (bewusst offen gelassen)

| Punkt | Für |
|---|---|
| Platzhalter-Sektion „Verlauf" auf der Detailseite | 4.3 Durchsicht, 4.5 Behandlungen, 4.6 Fütterung |
| `mutter_koenigin_id`, `begattungsart` | 4.17 Zucht (Stammbaum, Selektion) |
| `mutter_volk_id` | 4.16 Ableger/Schwärme |
| `standorte.sperrbezirk`, `amtliche_standnummer`, `tvd_betriebsnummer` | 4.23 Recht & Rückverfolgbarkeit, 4.14 Gesundheit |
| `betriebs_einstellungen` | F4 Settings (Varroa-Schwellen, Winterfutter-Soll, Fristen) |

## 11. Risiken & offene Punkte

- **Spalten-Drop (`standort`, `koenigin_jahr`):** nur zulässig, weil `voelker` leer und kein Code sie referenziert → **im Plan explizit per `grep` verifizieren**, bevor `C04` läuft.
- **`betrieb_gruenden` ändern** heißt, eine live genutzte RPC anfassen: additive Erweiterung, mit Rollback-Test; bestehende Betriebe erhalten ihre Zeile per Ops-Skript (idempotent).
- **Fachliche Richtwerte** (Höhe 1570 m, Offset 42 Tage) sind Betriebsdaten — der Saison-Offset ist ein Startwert und wird später anhand realer Beobachtung/Stockwaage kalibriert (`imkerei/02_Recherche/02`).
- **Jahresfarbe** ist bewusst **kein** Mandanten-Parameter (international fixer Zyklus) — Abweichung wäre ein Fehler, keine Konfiguration.
