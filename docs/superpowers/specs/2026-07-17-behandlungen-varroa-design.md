# Design-Spec: Behandlungen (Varroa & Gesundheit) (Modul 4.5) — Pflicht-Kern + Material + Cockpit

**Stand:** 2026-07-17 · **Status:** Entwurf v2 (nach adversarialem Multi-Agent-Review, 33 Funde eingearbeitet) · **Modell:** Fable 5 (DB/RLS/**amtliche Pflichtdaten**)
**Grundlage:** [Funktionsumfang-Scope](2026-07-11-app-funktionsumfang-scope.md) §4.5 · [App-Implikationen](../../imkerei-fachwissen-app-implikationen.md) · Fachwissen: `../../../imkerei/02_Recherche/15` (Varroa: Monitoring, Schwellen, Wirkstoffe), `19` (TAMV-Behandlungsjournal), `14` (Gesundheit)
**Baut auf:** 4.2 „Völker & Standorte" (v1.9.0), 4.3 „Durchsicht" (v1.10.0) — die Volk-Detailseite ist die Drehscheibe; `materials` (Lager) existiert; `auffaelligkeiten.varroa_sichtbar` (4.3) verweist hierher.

> **Review-Historie:** v1 wurde von 6 adversarialen Lupen + Skeptiker-Gegenprüfung geprüft (41 Funde → 33 bestätigt/teilweise). v2 arbeitet alle ein; die folgenschweren Struktur­entscheide (FK-`RESTRICT`, spaltenqualifiziertes `SET NULL`, RPC-Härtung, Revisionssicherheit) sind hier bereits fixiert, damit der Plan sie nicht erst nachziehen muss.

---

## 1. Zweck

Das **CH-konforme Behandlungsjournal** (TAMV, Pflicht für Bienen seit 1.7.2022 — „Kein Tierarzneimittel ohne Journaleintrag") plus **Varroa-Milbendiagnose** und ein **Varroa-Cockpit** je Volk. Kernnutzen: lückenlose, **manipulationssichere** Dokumentation jeder Behandlung; Befalls-Monitoring mit saisonaler Ampel; Bio-Konformitäts-Warnung; automatische Lager-Abbuchung des Wirkstoffs.

**Realitätscheck:** Herbst 2026 = 1 Volk, alpin (1570 m) → enges, verschobenes Behandlungsfenster, was die lückenlose Journalführung besonders wichtig macht. Datenmodell auf 32/64, UI schlicht. **YAGNI für die UI, nicht für Datenintegrität/Recht** — deshalb wird die Revisionssicherheit (Nicht-Löschbarkeit, Einweg-Storno, unveränderliche Kernfelder) **ab dem ersten Eintrag** hart erzwungen, nicht auf ein späteres Modul vertagt (retroaktiv nicht heilbar).

## 2. Scope

### In Scope
- Zwei Tabellen: `varroa_kontrollen` (Milbendiagnose) + `behandlungen` (TAMV-Journal); `materials` → `unique(betrieb_id,id)`.
- RPC `behandlung_erfassen` (atomar: N Journaleinträge je **eindeutigem** Volk + Lager-Abbuchung + Pflichtfeld-/Tenancy-Validierung, `betrieb_id` explizit).
- Flutter-Feature `lib/features/behandlung/`: Milbendiagnose-Formular, Behandlungs-Formular (Sammelbehandlung), **Varroa-Cockpit** (fl_chart) + methodenbewusste Ampel, Andocken an die Volk-Detailseite.
- **Material-Kopplung** (Wirkstoff aus `materials` → `stock_qty`-Abbuchung).
- **Bio-Wirkstoff-Whitelist-Warnung** (Warn-Gelb).
- **Amtliche Nicht-Löschbarkeit + Revisionssicherheit** des Journals (FK-`RESTRICT`, keine DELETE-Policy, Einweg-Storno, unveränderliche Kernfelder).

### Bewusst NICHT in Scope (Begründung)
| Ausgeschlossen | Warum |
|---|---|
| **PDF/CSV-Export (BLV-Layout)** | Modul 4.23 (Recht & Rückverfolgbarkeit). Die revisionssicheren Daten entstehen hier, der Export dort. Tierart-Konstante `'Bienen'` siehe §9. |
| **TAMV-Tierarzneimittel-Inventarliste (Bezug/Entsorgung)** | Modul 4.23. **Achtung Compliance-Lücke (§10):** die Inventarliste (TAMV Art. 26–28: Bezugsdatum/-quelle, Menge, Entsorgung) ist eine gleichrangige JETZT-Pflicht; bis 4.23 führt der Imker sie **separat** (BLV-Papiervorlage). Die App bucht zwar `stock_qty` ab, liefert aber (noch) keinen amtsfähigen Bezugs-/Entsorgungsnachweis. |
| **Wartefrist-Erntestopp** | 4.7 Ernte existiert nicht. `wartefrist_tage` wird erfasst; der Ernte-Block kommt mit 4.7. |
| **Behandlungs-Trigger-Engine / Kalender-Erinnerungen** | Modul 4.4 (Aufgaben/Kalender). |
| **Blockier-Rot Bio-Regel-Engine + Wachs-Rückstands-Layer** | 4.23 Bio-Layer. Hier nur Warn-Gelb (allow save). |
| **Konfigurierbare Schwellen/Höhen-Offset/Wirkstoff-Whitelist pro Betrieb (F4)** | Fachdefaults als Dart-Konstante (universell, mandantenfähig); F4 macht sie später konfigurierbar. Interim: sichtbarer Höhen-Caveat im Cockpit (§6). |
| **Vollständige Änderungsversionierung (Audit-Diff-Export)** | 4.23. Hier: Kernfelder unveränderlich + Einweg-Storno (Buchungs-Storno-Muster) — die Historie bleibt lückenlos, nur ohne Diff-Export-UI. |

## 3. Getroffene Entscheide

1. **Zuschnitt = Pflicht-Kern + Material-Kopplung + Cockpit** (Export/Inventarliste/Trigger/Ernte-Stopp später).
2. **Zwei getrennte Tabellen:** Diagnose (`varroa_kontrollen`, normale CRUD, CASCADE erlaubt) vs. Journal (`behandlungen`, amtliche Pflichtdaten, `RESTRICT` + revisionssicher).
3. **Sammelbehandlung → ein Journaleintrag je *eindeutigem* Volk:** die RPC nimmt `volk_ids[]`, **dedupliziert** (`distinct`) und legt genau eine Zeile je Volk an (TAMV-korrekt); Lager wird aus der **real eingefügten Zeilenzahl** (`ROW_COUNT`) einmal abgebucht — nie doppelt, auch nicht bei Duplikaten im Array.
4. **Amtliche Nicht-Löschbarkeit + Revisionssicherheit (DB-erzwungen, ab Eintrag 1):**
   - **`behandlungen` hat keine DELETE-Policy** (Hard-Delete via API unmöglich).
   - **`behandlungen.(betrieb_id,volk_id) → voelker ON DELETE RESTRICT`** (nicht CASCADE!) — ein Volk mit Journal ist **hart-löschsicher**; Abgang läuft über `voelker.status`. Ohne das würde die vorhandene `voelker_del_writer`-Policy (A09) via CASCADE das Journal umgehen und die 3-Jahres-Aufbewahrung (TAMV Art. 29) brechen.
   - **Insert nur via RPC** (keine INSERT-Policy → jeder Eintrag validiert + atomar).
   - **Kernfelder unveränderlich, Einweg-Storno:** ein BEFORE-UPDATE-Trigger lässt nur `is_storniert` (nur `false→true`), `storno_grund`, `storno_am` (server-gesetzt) und `notiz` ändern; alle amtlichen Kernfelder sind nach Anlage eingefroren; ein stornierter Eintrag ist terminal. Korrektur = **Storno + Neueintrag** (Buchungs-Storno-Muster). So bleibt die Historie lückenlos und beweiskräftig.
   - `varroa_kontrollen` (kein Pflichtjournal) = normale CRUD, CASCADE erlaubt.
5. **Bio-Warnung = Warn-Gelb** (nicht blockieren): der Imker entscheidet; Blockier-Rot ist 4.23. **Thymol zählt als bio-konform** (Recherche 15 §5/§7.5 — Thymovar/ApiLifeVAR sind erlaubte Bio-Mittel; die 5 mg/kg sind ein *Wachs*-Rückstands­grenzwert, keine Aussage zur Behandlungs-Konformität). Nur `sonstige` (unbekannt/synthetisch) löst die Warnung aus.

## 4. Datenmodell

Beide Tabellen: Mandanten-Muster (`betrieb_id NOT NULL DEFAULT private.aktive_betrieb_id()`, Audit, `set_row_actor`/`set_updated_at`, `revoke anon/public`+`grant authenticated`, Enums als text+CHECK, `unique(betrieb_id,id)`). **Same-Tenant-Komposit-FK** auf `voelker(betrieb_id,id)` (D-15-Lehre: FK-Prüfung umgeht RLS).

### 4.0 Vorbereitung: `materials.unique(betrieb_id, id)`
`materials` (52 Zeilen, `id` PK, `betrieb_id NOT NULL`) bekommt `unique(betrieb_id, id)` als Ziel für die Komposit-FK von `behandlungen.material_id`. Additiv, kein Datenrisiko (`id` ist bereits eindeutig).

### 4.1 `varroa_kontrollen` (Milbendiagnose — normale CRUD)

| Spalte | Typ | Notiz |
|---|---|---|
| `id` | `uuid PK` | |
| `volk_id` | `uuid NOT NULL` | Komposit-FK → `voelker`, **`ON DELETE CASCADE`** (kein Pflichtjournal) |
| `durchgefuehrt_am` | `date NOT NULL DEFAULT current_date` | App setzt client-seitig |
| `methode` | `text NOT NULL` | CHECK: `gemuell\|puderzucker\|auswaschung` |
| `messdauer_tage` | `int NULL` | Gemüll: über wie viele Tage die Windel zählte; `CHECK (messdauer_tage is null or messdauer_tage >= 1)` |
| `milben_gesamt` | `int NOT NULL` | `CHECK >=0` |
| `bienen_probe` | `int NULL` | Puderzucker/Auswaschung: Anzahl Bienen (~300); `CHECK (bienen_probe is null or bienen_probe >= 1)` |
| `notiz` | `text NULL` | |
| + audit | | |
→ App leitet ab (nicht gespeichert, reine Funktionen §5): **Milben/Tag** = `milben_gesamt / messdauer_tage` (Gemüll); **Befall-%** = `milben_gesamt / bienen_probe × 100` (Puderzucker/Auswaschung). Die Ampel ist **methodenbewusst** (zwei Skalen, §5). RLS: `sel/ins/upd/del`. Index `(betrieb_id, volk_id, durchgefuehrt_am desc)`. *(Die Rohfelder sind gespeichert → serverseitige Sortierung/Abfrage bleibt möglich; nur die zwei abgeleiteten Kennzahlen liegen in der App.)*

### 4.2 `behandlungen` (TAMV-Behandlungsjournal — amtliche Pflichtdaten, revisionssicher)

| Spalte | Typ | Notiz |
|---|---|---|
| `id` | `uuid PK` | |
| `volk_id` | `uuid NOT NULL` | Komposit-FK → `voelker`, **`ON DELETE RESTRICT`** (Journal löschsicher!) |
| `datum_beginn` | `date NOT NULL DEFAULT current_date` | TAMV Pflicht |
| `datum_ende` | `date NULL` | mehrtägige Anwendung |
| `praeparat` | `text NULL` | Handelsname; **Pflicht außer bei Biotechnik/Wärme** (CHECK unten). Drohnenschnitt/TBE hat keinen Handelsnamen. |
| `wirkstoff` | `text NOT NULL` | CHECK: `ameisensaeure\|oxalsaeure\|milchsaeure\|thymol\|kombi_os_as\|sonstige`. Biotechnik/Wärme ⇒ `sonstige` (legitim). |
| `menge_pro_volk` | `numeric NULL` | ml/g je Volk; `CHECK (menge_pro_volk is null or menge_pro_volk >= 0)`. **Pflicht (>0) bei chemischer Anwendung** (CHECK unten). |
| `einheit` | `text NULL` | CHECK: `ml\|g\|stueck`. **Pflicht bei chemischer Anwendung** (an Menge gekoppelt). |
| `konzentration` | `text NULL` | z. B. „3,5 %", „60 %" |
| `anwendungsart` | `text NOT NULL` | CHECK: `traeufeln\|spruehen\|verdampfen\|dispenser_verdunster\|streifen_langzeit\|schwammtuch\|biotechnik\|waermebehandlung`. Steuert die Menge-/Präparat-Pflicht + Bio-Zweig. |
| `indikation` | `text NULL` | Freitext, Default „Varroabekämpfung" |
| `aussentemperatur_c` | `numeric NULL` | AS temperaturkritisch (alpin) |
| `wartefrist_tage` | `int NULL` | `CHECK >=0`; Ernte-Stopp später (4.7) |
| `charge` | `text NULL` | Charge/Ablaufdatum des Präparats |
| `verantwortliche_person` | `text NOT NULL` | wer behandelt hat (TAMV-Pflicht; App füllt mit dem handelnden Mitglied vor) |
| `material_id` | `uuid NULL` | Komposit-FK → `materials(betrieb_id,id)` **`ON DELETE SET NULL (material_id)`** (nur die FK-Spalte nullen — unqualifiziert würde PG auch `betrieb_id` nullen!) |
| `is_storniert` | `boolean NOT NULL DEFAULT false` | Einweg (`false→true`), terminal |
| `storno_grund` | `text NULL` | Pflicht bei Storno (CHECK) |
| `storno_am` | `date NULL` | **server-gesetzt** beim Storno (Trigger), nicht client |
| `notiz` | `text NULL` | |
| + audit | | |

**CHECK-Constraints (greifen INSERT *und* UPDATE, also auch den Edit-Pfad):**
- `praeparat`-Kopplung: `anwendungsart in ('biotechnik','waermebehandlung') OR (praeparat is not null and btrim(praeparat) <> '')`
- Menge/Einheit-Kopplung (spiegelt BA033): `anwendungsart in ('biotechnik','waermebehandlung') OR (menge_pro_volk is not null and menge_pro_volk > 0 and einheit is not null)`
- Datumsplausibilität: `datum_ende is null or datum_ende >= datum_beginn`
- Storno-Vollständigkeit: `is_storniert = false OR (storno_grund is not null and storno_am is not null)`
- Storno-Datum: `storno_am is null or storno_am >= datum_beginn`

**RLS (bewusst asymmetrisch):** `behandlungen_sel_member` (SELECT) + `behandlungen_upd_writer` (UPDATE, für Storno/Notiz). **KEINE INSERT-Policy** (Insert nur über die security-definer-RPC) und **KEINE DELETE-Policy** (Hard-Delete unmöglich).

**Revisionssicherheits-Trigger `behandlungen_immutable` (BEFORE UPDATE):**
- Ist `OLD.is_storniert = true` → **jede** Änderung abweisen (Storno terminal).
- `is_storniert` darf nur `false→true` (kein „Ent-Stornieren").
- Änderungen an amtlichen Kernfeldern (`volk_id, datum_beginn, datum_ende, praeparat, wirkstoff, menge_pro_volk, einheit, konzentration, anwendungsart, indikation, aussentemperatur_c, wartefrist_tage, charge, verantwortliche_person, material_id`) abweisen → nur `is_storniert, storno_grund, storno_am, notiz` sind mutabel.
- Beim Storno (`NEW.is_storniert = true and OLD.is_storniert = false`): `NEW.storno_am := current_date` **server-seitig** setzen (Client-Wert ignorieren).

Index `(betrieb_id, volk_id, datum_beginn desc)` (deckt zugleich die FK `(betrieb_id, volk_id)` führend ab); FK-Index `(betrieb_id, material_id)` (deckt die Material-Komposit-FK für den `unindexed_foreign_keys`-Advisor + effizienten SET-NULL-Reverse-Scan).

### 4.3 RPC `behandlung_erfassen` (security definer — der einzige Schreibpfad)

```
behandlung_erfassen(
  p_volk_ids uuid[], p_datum_beginn date, p_datum_ende date,
  p_praeparat text, p_wirkstoff text, p_menge_pro_volk numeric, p_einheit text,
  p_konzentration text, p_anwendungsart text, p_indikation text,
  p_aussentemperatur_c numeric, p_wartefrist_tage int, p_charge text,
  p_verantwortliche_person text, p_material_id uuid, p_notiz text
) → int   -- Anzahl real erzeugter Journaleinträge (= distinct Völker)
```
- `SECURITY DEFINER`, `SET search_path = ''`, volle Qualifizierung (`public.*`, `private.*`); `revoke … from anon, public` + `grant … to authenticated`.
- **Guard zuerst:** `if p_volk_ids is null or cardinality(p_volk_ids) = 0 then` → **`BA031`** (robust gegen NULL/leer, *vor* jeder `array_length`-Nutzung).
- **Völker-Validierung (einheitliche `BA031`-Meldung — kein Existenz-Orakel):**
  `select array_agg(distinct betrieb_id), count(distinct id) from public.voelker where id = any(p_volk_ids)` →
  gemischte/keine Betriebe (`array_length(v_betriebe,1) <> 1`) **oder** ein Volk nicht gefunden (`count(distinct id) <> cardinality(array(select distinct unnest(p_volk_ids)))`) → **`BA031`**;
  `v_betrieb := v_betriebe[1]`; `if not private.kann_schreiben(v_betrieb) then` → **`BA031`**.
- **Pflichtfeld-Validierung `BA030`:** `p_datum_beginn is null OR p_wirkstoff is null OR p_anwendungsart is null OR btrim(p_verantwortliche_person) = '' OR (p_anwendungsart not in ('biotechnik','waermebehandlung') AND (p_praeparat is null or btrim(p_praeparat) = ''))`.
- **Dosierungs-Validierung `BA033`:** `p_anwendungsart not in ('biotechnik','waermebehandlung') AND (p_menge_pro_volk is null OR p_menge_pro_volk <= 0 OR p_einheit is null)`.
- **Material-Tenancy `BA032`:** `p_material_id is not null` und kein `materials`-Satz mit `(betrieb_id=v_betrieb, id=p_material_id)`.
- **Ablauf (atomar, eine Transaktion):**
  1. `insert into public.behandlungen (betrieb_id, volk_id, …) select v_betrieb, x.volk_id, … from (select distinct unnest(p_volk_ids) as volk_id) x;` — **`betrieb_id := v_betrieb` EXPLIZIT** (nicht über den JWT-Default; sonst entkoppelt sich Schreib- von Prüfziel bei Mehrfach-Mitgliedschaft, D-12-Lehre) und **`distinct`** (kein Doppel-Eintrag).
  2. `get diagnostics v_n = row_count;`
  3. `if p_material_id is not null then update public.materials set stock_qty = stock_qty - coalesce(p_menge_pro_volk,0) * v_n where id = p_material_id and betrieb_id = v_betrieb; end if;` — Abbuchung aus der **real eingefügten** Zeilenzahl `v_n` (nie aus `array_length`), plus `betrieb_id`-Filter als Defense-in-Depth (RLS ist im Definer-Kontext aus).
  4. `return v_n;`
- **Edit/Storno** laufen als normales `UPDATE` (RLS `upd_writer`) und werden vom `behandlungen_immutable`-Trigger auf Storno/Notiz begrenzt; Storno setzt `is_storniert=true` + `storno_grund` (Client), `storno_am` (Trigger). **Kein** Lager-Rückbuchen (§10).

**Errcode-Registry:** BA001–013 Auth · BA020–029 = 4.2 · **BA030–039 = Modul 4.5** (BA030 Pflichtfeld, BA031 Völker, BA032 Material-Tenancy, BA033 Dosierung).

## 5. Ableitungen (reine Logik, Dart-Konstanten — mandantenfähig, universelle Fachdefaults)

- **`milbenProTag(milbenGesamt, messdauerTage)` / `befallProzent(milbenGesamt, bienenProbe)`** — reine Funktionen, **null-sicher**: bei `null`/`0`-Nenner → `null` (kein Chip, keine Ampel, keine Exception).
- **Methodenbewusste Ampel:**
  - `ampelGemuell(milbenProTag, monat)` — natürlicher Fall/Tag (Recherche 15 §4, Gemülldiagnose):

    | Monat | grün | gelb | rot |
    |---|---|---|---|
    | Mai/Jun | < 5 | 5–10 | > 10 | *(Anker Juli — Richtwert)* |
    | **Juli** | < 5 | 5–10 | > 10 | *(Recherche)* |
    | **August** | < 10 | 10–25 | > 25 | *(Recherche)* |
    | **September** | < 15 | 15–25 | > 25 | *(Recherche)* |
    | Oktober | < 5 | 5–10 | > 10 | *(konservativer Anker — Winterbienen)* |
    | Nov–Apr | `kein_richtwert` (neutral/grau) | | | *(brutfrei/Cluster — Fall = Erfolgskontrolle einer Winterbehandlung, KEIN Behandlungsanlass; Cockpit zeigt Caveat)* |

  - `ampelPuderzucker(befallProzent)` — Befall-% (Recherche 15: Sommer-Schwelle ~1 %, klar behandeln >3 %): `< 1` grün · `1–3` gelb · `> 3` rot.
  - `ampelStatus(kontrolle, monat)` wählt nach `methode` die passende Skala; `puderzucker`/`auswaschung` → `ampelPuderzucker`, `gemuell` → `ampelGemuell`.

  Als Dart-`const`-Tabellen (Monat→Schwellen, %-Bänder), **kein** Arosa-Hardcode. **Richtwerte** — vor betrieblichen Entscheiden mit apiservice/Fachstelle kalibrieren. F4 macht Schwellen + **Höhen-/Kalender-Offset** pro Betrieb konfigurierbar; bis dahin zeigt das Cockpit einen sichtbaren Höhen-Caveat (§6).
- **Bio-Whitelist `bioKonformitaet(wirkstoff, anwendungsart)` → `konform | warnung`:** ist `anwendungsart ∈ {biotechnik, waermebehandlung}` (keine Chemie) → **konform**; sonst nach Wirkstoff: `ameisensaeure/oxalsaeure/milchsaeure/kombi_os_as/thymol` = **konform**; `sonstige` = **warnung** (unbekannt/möglicherweise synthetisch). Nur `warnung` zeigt das gelbe Banner. *(Thymol ist bio-konform, s. Entscheid 5 — kein Cry-Wolf auf der alpinen Regelbehandlung.)*

## 6. App-Schicht (`lib/features/behandlung/`)

```
features/behandlung/
  domain/        varroa_kontrolle.dart · behandlung.dart · wirkstoff.dart (Enum+Bio-Whitelist)
                 ampel_schwellen.dart (reine Funktionen + const, beide Skalen) · behandlung_gateway.dart
  data/          supabase_behandlung_gateway.dart · fake_behandlung_gateway.dart
  presentation/  providers/behandlung_provider.dart
                 pages/kontrolle_form_page.dart · behandlung_form_page.dart
                 widgets/varroa_cockpit.dart · behandlung_section.dart
```

- **Gateway:** `kontrollenFuerVolk(volkId)` · `behandlungenFuerVolk(volkId)` (inkl. stornierte, sortiert) · `kontrolleSpeichern`/`kontrolleLoeschen` · **`behandlungErfassen({volkIds, …, materialId})`** (RPC) · `behandlungStornieren(id, grund)` (Edit = nur Notiz/Storno, keine Kernfeld-Bearbeitung, konsistent mit dem Immutable-Trigger). Fehler-Mapping `BA030–033` + `PostgrestException` (auch roher `23514`-CHECK → Klartext) → keine stillen Fallbacks.
- **State:** Family-Provider `kontrollenFuerVolkProvider(volkId)`, `behandlungenFuerVolkProvider(volkId)` (non-autoDispose). **Invalidierung nach Sammelbehandlung: für JEDE beteiligte volkId** `for (final id in volkIds) ref.invalidate(behandlungenFuerVolkProvider(id));` **plus einmal `materialListProvider`** (Lager geändert) — sonst bleiben Fremd-Volk-Instanzen stale (D-18/D-23-Gotcha, intra-Mandant). **Beide neuen Provider in `AuthController._datenNeuLaden()`.** `viewer` read-only.
- **UI — neue Sektion „Varroa & Behandlung" auf der Volk-Detailseite** (unter „Verlauf"):
  1. **Varroa-Cockpit** (`fl_chart`): **methodenbewusst** — Gemüll-Kontrollen als Milben/Tag-Linie + saisonales Ampelband; Puderzucker/Auswaschung als Befall-%-Punkte (separate Serie/abgesetzte Achse). **Behandlungs-Marker** (senkrechte Linien am `datum_beginn`) — **stornierte Behandlungen ausgeschlossen** (oder gestrichelt abgesetzt), damit die Vorher/Nachher-Ablesung nicht verfälscht wird. **Ampel-Chip** (letzte Kontrolle, methodengerecht; null-sicher = kein Chip ohne verwertbare Kennzahl). **Höhen-Caveat** sichtbar („höhenabhängig — im Gebirge Zeile ~4–6 Wochen später lesen; Fall nach Winterbehandlung = Erfolgskontrolle, kein Behandlungsanlass").
  2. Buttons (schreibberechtigt): „Milbendiagnose" → `kontrolle_form_page`, „Behandlung" → `behandlung_form_page`.
  3. Kompakte Liste letzte Kontrollen + Behandlungen (Wirkstoff-Chip; **storniert = durchgestrichen** + Grund).
- **Formulare (vollflächige Seiten, Rollen-Guard im `build`, `context.mounted`-Checks; Dropdowns vorwärmen: `await ref.read(materialListProvider.future)` + `voelkerListProvider.future` vor Render — D-18-Gotcha #2, Muster `volk_form.dart`):**
  - *Milbendiagnose:* Methode-Chips → passende Felder; Live „X Milben/Tag" bzw. „Y % Befall" + methodengerechte Ampel.
  - *Behandlung:* **Völker-Multi-Select** (Default aktuelles Volk); Datum(bereich); Präparat (Pflicht außer Biotechnik/Wärme); Wirkstoff-Chips; Menge/Volk + Einheit (Pflicht bei Chemie); Konzentration; Anwendungsart; Aussentemp; Wartefrist; Charge; **Verantwortliche:r** (vorbefüllt mit handelndem Mitglied); **Material-Dropdown** (aus `materialListProvider`, `is_consumable`, `bereich='imkerei'`); **Bio-Warnbanner (gelb)** wenn `bioKonformitaet == warnung` UND **mindestens ein selektiertes Volk** `bioStatus != 'konventionell'` (mit Nennung der betroffenen Völker) — nicht an einem Singular-Volk. Speichern → `behandlungErfassen`. Pflichtfeld-Validierung client **und** hart in RPC/DB.
  - *Stornieren:* aus der Liste, Grund-Dialog (Edit von Kernfeldern ist bewusst nicht vorgesehen — Korrektur = Storno + Neueintrag).

## 7. Migrationen & Rollout

| # | Inhalt |
|---|---|
| `E01` | `materials.unique(betrieb_id,id)`; `varroa_kontrollen` (CASCADE) + `behandlungen` (**FK volk_id `RESTRICT`**, **material_id `SET NULL (material_id)`**, alle CHECKs, Soft-Delete, RLS **ohne INSERT/DELETE-Policy**, **`behandlungen_immutable`-Trigger**, `set_row_actor`/`set_updated_at`, Grants, Indizes inkl. `(betrieb_id, material_id)`) |
| `E02` | RPC `behandlung_erfassen` (Guard, BA030–033, `distinct`+`ROW_COUNT`, explizite `betrieb_id`, `betrieb_id`-gefilterte Lagerbuchung) + Grants |

Jede Migration: Datei + MCP `apply_migration`; Kopf-Kommentar; **Rollback-DO-Test**; `get_advisors(security)` → **0 neue SECURITY-Findings** (der neue RPC ist erwartbar als 0029-Zeile; die FK-Indizes verhindern `unindexed_foreign_keys`-INFO). **Kein Ops-Seed.**

**Deploy:** `version:` → **1.11.0+29**, `bash deploy.sh` (stehende Freigabe).

## 8. Tests

**SQL (Rollback-DO):**
- Mandanten-Isolation (fremder Betrieb sieht/schreibt nichts).
- Komposit-FK: fremdes/erfundenes `volk_id`/`material_id` → FK-Fehler.
- CHECK-Verletzungen: `methode`/`wirkstoff`/`anwendungsart`/`einheit`; Nicht-Negativ; **praeparat-Kopplung**, **Menge/Einheit-Kopplung**, **`datum_ende < datum_beginn`**, **Storno-Vollständigkeit**.
- **RPC `behandlung_erfassen`:** legt N Zeilen an; **`[V,V]` erzeugt nur EINE Zeile + einfache Abbuchung** (distinct + ROW_COUNT); bucht `stock_qty` korrekt (−`menge×v_n`); `betrieb_id` = Völker-Betrieb (nicht JWT); wirft `BA030` (fehlendes Pflichtfeld inkl. leerer verantwortliche_person / fehlendes Präparat bei Chemie), `BA031` (leeres/NULL-Array, unbekanntes Volk, gemischte Betriebe, kein Schreibrecht), `BA032` (fremdes Material), `BA033` (Chemie ohne Menge/Einheit); **`p_volk_ids = NULL` und `{}`** → BA031 (kein `stock_qty`-Schaden); Lagerbuchung greift nur bei `betrieb_id = v_betrieb`.
- **Revisionssicherheit:** direktes `DELETE` auf `behandlungen` scheitert (keine Policy); **`voelker`-Hard-Delete bei vorhandenem Journal scheitert (RESTRICT)**; direkter INSERT scheitert (keine Policy); **Immutable-Trigger:** Kernfeld-UPDATE abgewiesen, Storno (`false→true`+Grund) ok, `storno_am` server-gesetzt, „Ent-Stornieren" (`true→false`) abgewiesen, UPDATE auf storniertem Eintrag abgewiesen.
- **Material-Delete** gegen referenzierenden Journaleintrag → `material_id` wird NULL, `betrieb_id` bleibt (SET NULL nur der FK-Spalte).
- `betrieb_id`/`created_by` nicht fälschbar.

**Dart:** `milbenProTag`/`befallProzent` (Division durch 0/null → null); `ampelGemuell` (alle 12 Monate inkl. Grenzwerte + `kein_richtwert` Nov–Apr), `ampelPuderzucker` (Bänder), `ampelStatus` (Methodenwahl, gemischte-Methoden-Reihe); `bioKonformitaet` (alle Wirkstoffe + biotechnik/waerme-Zweig, thymol=konform); Model-Roundtrips; `FakeBehandlungGateway` (**distinct**-Sammel-Insert + simulierte Lager-Buchung aus real erzeugter Zeilenzahl + `BA030/031/032/033`-Validierung + Einweg-Storno/Immutable); **Provider-Test: Sammelbehandlung A+B invalidiert beide Family-Instanzen UND `materialListProvider`**; Bio-Banner-Logik (Multi-Select, ≥1 nicht-konventionelles Volk); **signOut invalidiert den Cache**; Rollen-Gating; Dropdown-Prewarming (Erstöffnung zeigt gefüllte Dropdowns). `flutter analyze` sauber, alle grün.

## 9. Erweiterungspunkte (bewusst offen)

| Punkt | Für |
|---|---|
| `behandlungen` (Nicht-Löschbarkeit, Einweg-Storno, unveränderliche Kernfelder) + `varroa_kontrollen` | 4.23 revisionssicherer BLV-Export (+ Voll-Versionierung/Audit-Diff) + Tierarzneimittel-**Inventarliste** (Bezug/Entsorgung) |
| **Tierart = `'Bienen'`** | 4.23 BLV-Export-**Konstante** (kein Speicherfeld — für eine reine Imkerei-App konstant, aber im Export-Layout explizit benannt, damit vollständig) |
| `wartefrist_tage` | 4.7 Ernte (Wartefrist-Erntestopp) |
| Ampel-Schwellen + **Höhen-/Kalender-Offset** + Wirkstoff-Whitelist (Dart-const) | F4 Settings (pro Betrieb konfigurierbar) |
| Behandlungs-/Diagnose-Fenster | 4.4 Kalender (Trigger-Engine) |
| Bio-Warn-Gelb + Wachs-Rückstands-Layer (5 mg/kg Thymol) | 4.23 Bio-Layer (Blockier-Rot Regel-Engine) |
| `varroa_sichtbar` (4.3) | Verweis/Vorschlag „Milbendiagnose anlegen" |

## 10. Risiken & offene Punkte

- **Insert-nur-via-RPC:** `behandlungen` hat keine INSERT-Policy → jeder Journaleintrag MUSS über `behandlung_erfassen` (der Fake-Gateway bildet das inkl. distinct/Validierung nach). Bewusst.
- **service_role/superuser umgeht RLS+Policies+FK generell** — die DB-Level-Garantien (RESTRICT, keine DELETE-Policy, Immutable-Trigger) gelten für den `authenticated`-App-Pfad; ein Server-Role-Zugriff (Cron/Support) ist außerhalb dieses Modells und im Sicherheitsmodell dokumentiert.
- **Lager-Buchung nicht-atomar mit Storno/Edit:** Insert bucht ab; Storno **bucht nicht zurück** (der Wirkstoff wurde ggf. verbraucht). Bewusst; der Imker korrigiert das Lager sonst manuell.
- **Nebenläufige RPC-Aufrufe aufs selbe Material:** das `update … set stock_qty = stock_qty - x` ist als einzelnes UPDATE atomar (Row-Lock je Statement); kein Lost-Update bei parallelen Sammelbehandlungen. `stock_qty` **kann negativ** werden (Über-Erfassung) — kein Clamp; die Nachkauf-/Bestandslogik zeigt das an. Bewusst.
- **Einheiten-Mismatch:** `behandlungen.einheit` (`ml|g|stueck`, CHECK) vs. `materials.unit` (Freitext) — keine harte Kopplung. Weiche Formular-Warnung bei Abweichung; das amtliche Journal bleibt korrekt, nur der Lagerwert könnte bei inkompatibler Materialeinheit unpräzise werden. Restrisiko.
- **TAMV-Inventarliste (Bezug/Entsorgung) bis 4.23 nicht app-abgedeckt** (§2) — JETZT-Pflicht, die der Imker separat führt. Prüfen, ob `material_purchases` + Entsorgungs-Feld + Tierarzneimittel-Filter die Lücke früher schließt.
- **Ampel-Schwellen/Whitelist sind universelle Fachdefaults (Richtwerte)** — kein Arosa-Hardcode; Höhen-Offset ist F4, bis dahin Cockpit-Caveat. Mit Fachstelle kalibrieren.
- **Biotechnik im TAMV-Journal:** Drohnenschnitt/TBE/Wärme sind erfassbar (`praeparat` NULL erlaubt, `wirkstoff='sonstige'`, keine Menge-Pflicht) — sie sind streng genommen keine Tierarzneimittel, werden aber fürs lückenlose Varroa-Konzept miterfasst. Bewusst.
