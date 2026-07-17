# Design-Spec: Behandlungen (Varroa & Gesundheit) (Modul 4.5) — Pflicht-Kern + Material + Cockpit

**Stand:** 2026-07-17 · **Status:** Entwurf (Brainstorming abgeschlossen) · **Modell:** Fable 5 (DB/RLS/**amtliche Pflichtdaten**)
**Grundlage:** [Funktionsumfang-Scope](2026-07-11-app-funktionsumfang-scope.md) §4.5 · [App-Implikationen](../../imkerei-fachwissen-app-implikationen.md) · Fachwissen: `../../../imkerei/02_Recherche/15` (Varroa: Monitoring, Schwellen, Wirkstoffe), `19` (TAMV-Behandlungsjournal), `14` (Gesundheit)
**Baut auf:** 4.2 „Völker & Standorte" (v1.9.0), 4.3 „Durchsicht" (v1.10.0) — die Volk-Detailseite ist die Drehscheibe; `materials` (Lager) existiert; `auffaelligkeiten.varroa_sichtbar` (4.3) verweist hierher.

---

## 1. Zweck

Das **CH-konforme Behandlungsjournal** (TAMV, Pflicht für Bienen seit 1.7.2022 — „Kein Tierarzneimittel ohne Journaleintrag") plus **Varroa-Milbendiagnose** und ein **Varroa-Cockpit** je Volk. Kernnutzen: lückenlose, amtsfähige Dokumentation jeder Behandlung; Befalls-Monitoring mit saisonaler Ampel; Bio-Konformitäts-Warnung; automatische Lager-Abbuchung des Wirkstoffs.

**Realitätscheck:** Herbst 2026 = 1 Volk, alpin (1570 m) → enges, verschobenes Behandlungsfenster, was die lückenlose Journalführung besonders wichtig macht. Datenmodell auf 32/64, UI schlicht. **YAGNI für die UI, nicht für Datenintegrität/Recht.**

## 2. Scope

### In Scope
- Zwei Tabellen: `varroa_kontrollen` (Milbendiagnose) + `behandlungen` (TAMV-Journal); `materials` → `unique(betrieb_id,id)`.
- RPC `behandlung_erfassen` (atomar: N Journaleinträge je Volk + Lager-Abbuchung + Pflichtfeld-/Tenancy-Validierung).
- Flutter-Feature `lib/features/behandlung/`: Milbendiagnose-Formular, Behandlungs-Formular (Sammelbehandlung), **Varroa-Cockpit** (fl_chart) + Ampel, Andocken an die Volk-Detailseite.
- **Material-Kopplung** (Wirkstoff aus `materials` → `stock_qty`-Abbuchung).
- **Bio-Wirkstoff-Whitelist-Warnung** (Warn-Gelb).
- **Amtliche Nicht-Löschbarkeit** des Journals (Soft-Delete/Storno, kein Hard-Delete).

### Bewusst NICHT in Scope (Begründung)
| Ausgeschlossen | Warum |
|---|---|
| **PDF/CSV-Export (BLV-Layout), Tierarzneimittel-Inventarliste** | Modul 4.23 (Recht & Rückverfolgbarkeit). Die Daten entstehen hier, der revisionssichere Export dort. |
| **Wartefrist-Erntestopp** | 4.7 Ernte existiert nicht. `wartefrist_tage` wird erfasst; der Ernte-Block kommt mit 4.7. |
| **Behandlungs-Trigger-Engine / Kalender-Erinnerungen** | Modul 4.4 (Aufgaben/Kalender). |
| **Blockier-Rot Bio-Regel-Engine** | 4.23 Bio-Layer. Hier nur Warn-Gelb (allow save). |
| **Konfigurierbare Schwellen/Wirkstoff-Whitelist pro Betrieb (F4)** | Fachdefaults als Dart-Konstante (universell, mandantenfähig); F4 macht sie später konfigurierbar. |
| **Storno-Rückbuchung aufs Lager** | Bewusst nicht: der Wirkstoff wurde ggf. angewendet; Lager korrigiert der Imker manuell. |

## 3. Getroffene Entscheide

1. **Zuschnitt = Pflicht-Kern + Material-Kopplung + Cockpit** (Export/Trigger/Inventar/Ernte-Stopp später).
2. **Zwei getrennte Tabellen:** Diagnose (`varroa_kontrollen`, normale CRUD) vs. Journal (`behandlungen`, Pflichtdaten).
3. **Sammelbehandlung → ein Journaleintrag je Volk:** die RPC nimmt `volk_ids[]` und legt N Einträge an (TAMV-korrekt je Volk), bucht das Lager **einmal** ab.
4. **Amtliche Nicht-Löschbarkeit:** `behandlungen` hat **keine DELETE-Policy** (Hard-Delete via API unmöglich) → 3-Jahres-Aufbewahrung (TAMV Art. 29) auf DB-Ebene erzwungen. Korrektur = **Storno** (`is_storniert`+Grund, bleibt sichtbar) oder Edit. **Insert nur via RPC** (keine INSERT-Policy → jeder Journaleintrag ist validiert + atomar). `varroa_kontrollen` (kein Pflichtjournal) = normale CRUD.
5. **Bio-Warnung = Warn-Gelb** (nicht blockieren): der Imker entscheidet; Blockier-Rot ist 4.23.

## 4. Datenmodell

Beide Tabellen: Mandanten-Muster (`betrieb_id NOT NULL DEFAULT private.aktive_betrieb_id()`, Audit, `set_row_actor`/`set_updated_at`, `revoke anon/public`+`grant authenticated`, Enums als text+CHECK, `unique(betrieb_id,id)`). **Same-Tenant-Komposit-FK** `(betrieb_id, volk_id) → voelker(betrieb_id,id) ON DELETE CASCADE`.

### 4.0 Vorbereitung: `materials.unique(betrieb_id, id)`
`materials` (52 Zeilen, `id` PK, `betrieb_id NOT NULL`) bekommt `unique(betrieb_id, id)` als Ziel für die Komposit-FK von `behandlungen.material_id`. Additiv, kein Datenrisiko (`id` ist bereits eindeutig).

### 4.1 `varroa_kontrollen` (Milbendiagnose — normale CRUD)

| Spalte | Typ | Notiz |
|---|---|---|
| `id` | `uuid PK` | |
| `volk_id` | `uuid NOT NULL` | Komposit-FK → `voelker`, `ON DELETE CASCADE` |
| `durchgefuehrt_am` | `date NOT NULL DEFAULT current_date` | App setzt client-seitig |
| `methode` | `text NOT NULL` | CHECK: `gemuell\|puderzucker\|auswaschung` |
| `messdauer_tage` | `int NULL` | Gemüll: über wie viele Tage die Windel zählte; `CHECK >=1` |
| `milben_gesamt` | `int NOT NULL` | `CHECK >=0` |
| `bienen_probe` | `int NULL` | Puderzucker/Auswaschung: Anzahl Bienen (~300); `CHECK >=1` |
| `notiz` | `text NULL` | |
| + audit | | |
→ App leitet ab (nicht gespeichert): **Milben/Tag** = `milben_gesamt / messdauer_tage` (Gemüll); **Befall-%** = `milben_gesamt / bienen_probe × 100` (Puderzucker/Auswaschung). RLS: `sel/ins/upd/del`. Index `(betrieb_id, volk_id, durchgefuehrt_am desc)`.

### 4.2 `behandlungen` (TAMV-Behandlungsjournal — amtliche Pflichtdaten)

| Spalte | Typ | Notiz |
|---|---|---|
| `id` | `uuid PK` | |
| `volk_id` | `uuid NOT NULL` | Komposit-FK → `voelker`, `ON DELETE CASCADE` |
| `datum_beginn` | `date NOT NULL DEFAULT current_date` | TAMV Pflicht |
| `datum_ende` | `date NULL` | mehrtägige Anwendung |
| `praeparat` | `text NOT NULL` | Handelsname (TAMV Pflicht; RPC prüft ≠ leer) |
| `wirkstoff` | `text NOT NULL` | CHECK: `ameisensaeure\|oxalsaeure\|milchsaeure\|thymol\|kombi_os_as\|sonstige` |
| `menge_pro_volk` | `numeric NULL` | ml/g je Volk; `CHECK >=0`. App verlangt Wert außer bei `biotechnik` |
| `einheit` | `text NULL` | CHECK: `ml\|g\|stueck` |
| `konzentration` | `text NULL` | z. B. „3,5 %", „60 %" |
| `anwendungsart` | `text NULL` | CHECK: `traeufeln\|spruehen\|verdampfen\|dispenser_verdunster\|streifen_langzeit\|schwammtuch\|biotechnik\|waermebehandlung` |
| `indikation` | `text NULL` | Freitext, Default „Varroabekämpfung" |
| `aussentemperatur_c` | `numeric NULL` | AS temperaturkritisch (alpin) |
| `wartefrist_tage` | `int NULL` | `CHECK >=0`; Ernte-Stopp später (4.7) |
| `charge` | `text NULL` | Charge/Ablaufdatum des Präparats |
| `verantwortliche_person` | `text NULL` | wer behandelt hat |
| `material_id` | `uuid NULL` | Komposit-FK → `materials(betrieb_id,id) ON DELETE SET NULL` (der Wirkstoff als Lager-Material) |
| `is_storniert` | `boolean NOT NULL DEFAULT false` | Storno statt Löschen |
| `storno_grund` | `text NULL` | |
| `storno_am` | `date NULL` | |
| `notiz` | `text NULL` | |
| + audit | | |

**RLS (bewusst asymmetrisch):** `behandlungen_sel_member` (SELECT) + `behandlungen_upd_writer` (UPDATE, für Edit/Storno). **KEINE INSERT-Policy** (Insert nur über die security-definer-RPC) und **KEINE DELETE-Policy** (Hard-Delete unmöglich → Aufbewahrung erzwungen). Index `(betrieb_id, volk_id, datum_beginn desc)`; FK-Index `material_id`.

### 4.3 RPC `behandlung_erfassen` (security definer — der Pflicht-Schreibpfad)

```
behandlung_erfassen(
  p_volk_ids uuid[], p_datum_beginn date, p_datum_ende date,
  p_praeparat text, p_wirkstoff text, p_menge_pro_volk numeric, p_einheit text,
  p_konzentration text, p_anwendungsart text, p_indikation text,
  p_aussentemperatur_c numeric, p_wartefrist_tage int, p_charge text,
  p_verantwortliche_person text, p_material_id uuid, p_notiz text
) → int   -- Anzahl erzeugter Journaleinträge
```
- `SECURITY DEFINER`, `SET search_path = ''`, volle Qualifizierung; `revoke … from anon, public` + `grant … to authenticated`.
- **Validierung:** `trim(p_praeparat)=''` OR `p_wirkstoff` fehlt OR `p_datum_beginn` fehlt → **`BA030`**. `p_volk_ids` leer / ein Volk nicht gefunden / gemischte Betriebe / kein Schreibrecht → **`BA031`**. `p_material_id` gesetzt und gehört nicht zum selben Betrieb → **`BA032`**.
- **Ablauf (atomar):** Betrieb aus den Völkern ableiten (`kann_schreiben`); **ein `insert … select unnest(p_volk_ids)`** legt N Zeilen an; falls `p_material_id`: `update materials set stock_qty = stock_qty - coalesce(p_menge_pro_volk,0) * array_length(p_volk_ids,1) where id = p_material_id`.
- **Edit/Storno** laufen als normales `UPDATE` (RLS `upd_writer`); Storno setzt `is_storniert=true`, `storno_grund`, `storno_am`. **Kein** Lager-Rückbuchen.

**Errcode-Registry:** BA001–013 Auth · BA020–029 = 4.2 · **BA030–039 = Modul 4.5**.

## 5. Ableitungen (reine Logik, Dart-Konstanten — mandantenfähig)

- **`milbenProTag(milbenGesamt, messdauerTage)`** und **`befallProzent(milbenGesamt, bienenProbe)`** — reine Funktionen.
- **`ampelStatus(milbenProTag, monat)` → grün/gelb/rot** aus saisonalen Fachdefaults (Recherche 15, natürlicher Fall/Tag Gemülldiagnose):

| Monat | grün | gelb | rot |
|---|---|---|---|
| Juli | < 5 | 5–10 | > 10 |
| August | < 10 | 10–25 | > 25 |
| September | < 15 | 15–25 | > 25 |
| übrige Monate | Nachbar-Anker als Richtwert (Mai/Juni≈Juli, Okt≈Sep, Nov–Apr: > ~1/Tag = auffällig) | | |

Als Dart-`const`-Tabelle (Monat→Schwellen), **kein** Arosa-Hardcode (universelle Fachwerte); F4 macht sie später pro Betrieb konfigurierbar. Richtwerte — vor betrieblichen Entscheiden mit apiservice/Tino Hassler kalibrieren.
- **Bio-Whitelist `bioKonformitaet(wirkstoff, anwendungsart)` → `konform | grenzwertig | warnung`:** ist `anwendungsart ∈ {biotechnik, waermebehandlung}` (keine Chemie) → **konform** (unabhängig vom Wirkstoff, der dann i. d. R. `sonstige` ist); sonst nach Wirkstoff: `ameisensaeure/oxalsaeure/milchsaeure/kombi_os_as` = **konform**; **`thymol` = grenzwertig** (reichert sich im Wachs an, Bio-Suisse-Grenzwert 5 mg/kg → Warn-Gelb); `sonstige` = **warnung**. Die UI zeigt bei `grenzwertig`/`warnung` das gelbe Banner (nicht blockierend).

## 6. App-Schicht (`lib/features/behandlung/`)

```
features/behandlung/
  domain/        varroa_kontrolle.dart · behandlung.dart · wirkstoff.dart (Enum+Bio-Whitelist)
                 ampel_schwellen.dart (reine Funktionen + const) · behandlung_gateway.dart
  data/          supabase_behandlung_gateway.dart · fake_behandlung_gateway.dart
  presentation/  providers/behandlung_provider.dart
                 pages/kontrolle_form_page.dart · behandlung_form_page.dart
                 widgets/varroa_cockpit.dart · behandlung_section.dart
```

- **Gateway:** `kontrollenFuerVolk(volkId)` · `behandlungenFuerVolk(volkId)` (inkl. stornierte, sortiert) · `kontrolleSpeichern`/`kontrolleLoeschen` · **`behandlungErfassen({volkIds, …, materialId})`** (RPC) · `behandlungBearbeiten(Behandlung)` · `behandlungStornieren(id, grund)`. Fehler-Mapping `BA030–032` + `PostgrestException` → Klartext; keine stillen Fallbacks.
- **State:** Family-Provider `kontrollenFuerVolkProvider(volkId)`, `behandlungenFuerVolkProvider(volkId)`. Schreibaktionen invalidieren die Family **und `materialListProvider`** (Lager geändert). **Beide neuen Provider in `AuthController._datenNeuLaden()`.** `viewer` read-only.
- **UI — neue Sektion „Varroa & Behandlung" auf der Volk-Detailseite** (unter „Verlauf"):
  1. **Varroa-Cockpit** (`fl_chart`): Milben/Tag-Verlauf aus `varroa_kontrollen` (Linie), **Behandlungs-Marker** (senkrechte Linien am `datum_beginn`), **Ampel-Schwellenband** der Saison. Darüber ein **Ampel-Chip** (aktueller Befall aus letzter Kontrolle) + Hinweis „Behandlung empfohlen" bei Rot.
  2. Buttons (schreibberechtigt): „Milbendiagnose" → `kontrolle_form_page`, „Behandlung" → `behandlung_form_page`.
  3. Kompakte Liste letzte Kontrollen + Behandlungen (Wirkstoff-Chip; **storniert = durchgestrichen** + Grund).
- **Formulare (vollflächige Seiten, Rollen-Guard im `build`, `context.mounted`-Checks):**
  - *Milbendiagnose:* Methode-Chips → passende Felder; Live „X Milben/Tag" bzw. „Y % Befall" + Ampel.
  - *Behandlung:* **Völker-Multi-Select** (Default aktuelles Volk); Datum(bereich); Präparat; Wirkstoff-Chips; Menge/Volk + Einheit; Konzentration; Anwendungsart; Aussentemp; Wartefrist; Charge; Verantwortliche:r; **Material-Dropdown** (aus `materialListProvider`, `is_consumable`, `bereich='imkerei'`); **Bio-Warnbanner (gelb)** wenn `!istBioKonform` und `volk.bioStatus != 'konventionell'`. Speichern → `behandlungErfassen`. Pflichtfeld-Validierung client + hart in RPC/DB.
  - *Bearbeiten/Stornieren:* aus der Liste; Storno mit Grund-Dialog.

## 7. Migrationen & Rollout

| # | Inhalt |
|---|---|
| `E01` | `materials.unique(betrieb_id,id)`; `varroa_kontrollen` + `behandlungen` (Tabellen, Komposit-FKs, CHECKs, Soft-Delete, RLS — **`behandlungen` ohne INSERT/DELETE-Policy**, Trigger/Grants/Indizes) |
| `E02` | RPC `behandlung_erfassen` + Grants |

Jede Migration: Datei + MCP `apply_migration`; Kopf-Kommentar; **Rollback-DO-Test**; `get_advisors(security)` → nur die **eine** erwartete neue 0029-Zeile (RPC), sonst 0 neue Findings. **Kein Ops-Seed.**

**Deploy:** `version:` → **1.11.0+29**, `bash deploy.sh` (stehende Freigabe).

## 8. Tests

**SQL (Rollback-DO):**
- Mandanten-Isolation (fremder Betrieb sieht/schreibt nichts).
- Komposit-FK: fremdes/erfundenes `volk_id`/`material_id` → FK-Fehler.
- CHECK-Verletzungen (`methode`/`wirkstoff`/`anwendungsart`/`einheit`; Nicht-Negativ).
- **RPC `behandlung_erfassen`:** legt N Zeilen an (Sammelbehandlung), bucht `stock_qty` korrekt (−`menge×N`), wirft `BA030`/`BA031`/`BA032`.
- **Kein Hard-Delete auf `behandlungen`** (direktes DELETE scheitert mangels Policy); **kein direkter INSERT** (scheitert mangels Policy); Storno-UPDATE funktioniert; Edit-UPDATE funktioniert.
- `betrieb_id`/`created_by` nicht fälschbar; `ON DELETE CASCADE`.

**Dart:** `milbenProTag`/`befallProzent`/`ampelStatus` (Saison-Grenzen, Division durch 0/null); `istBioKonform` (alle Wirkstoffe); Model-Roundtrips; `FakeBehandlungGateway` (Sammel-Insert + simulierte Lager-Buchung + `BA030`-Validierung + Storno); Provider-Test (Schreibaktion invalidiert Family **und** `materialListProvider`); **signOut invalidiert den Cache**; Rollen-Gating. `flutter analyze` sauber, alle grün.

## 9. Erweiterungspunkte (bewusst offen)

| Punkt | Für |
|---|---|
| `behandlungen` (append-only, Storno) + `varroa_kontrollen` | 4.23 revisionssicherer BLV-Export + Tierarzneimittel-Inventar |
| `wartefrist_tage` | 4.7 Ernte (Wartefrist-Erntestopp) |
| Ampel-Schwellen + Wirkstoff-Whitelist (Dart-const) | F4 Settings (pro Betrieb konfigurierbar) |
| Behandlungs-/Diagnose-Fenster | 4.4 Kalender (Trigger-Engine) |
| Bio-Warn-Gelb | 4.23 Bio-Layer (Blockier-Rot Regel-Engine) |
| `varroa_sichtbar` (4.3) | Verweis/Vorschlag „Milbendiagnose anlegen" |

## 10. Risiken & offene Punkte

- **Insert-nur-via-RPC:** Da `behandlungen` keine INSERT-Policy hat, MUSS jeder Journaleintrag über `behandlung_erfassen` laufen (der Fake-Gateway bildet das nach). Direkter `.from('behandlungen').insert()` würde an RLS scheitern — bewusst.
- **Lager-Buchung nicht-atomar mit Storno/Edit:** Insert bucht ab; Storno/Edit buchen **nicht** zurück (der Wirkstoff wurde ggf. verbraucht). Bewusst; der Imker korrigiert das Lager sonst manuell. In §10 als Restrisiko akzeptiert.
- **`stock_qty` kann negativ werden** (Über-Erfassung) — kein Clamp; die bestehende Nachkauf-/Bestandslogik zeigt das an. Bewusst.
- **Ampel-Schwellen/Wirkstoff-Whitelist sind Fachdefaults (Richtwerte)** — universell, kein Arosa-Hardcode; mit Fachstelle kalibrieren; F4 macht sie konfigurierbar.
- **`voelker`-Hard-Delete mit Journal:** `ON DELETE CASCADE` würde Journaleinträge mitlöschen. Volk-Hard-Delete ist Fehleingabe-only (4.2: Abgang = Status); die echte Aufbewahrungs-Härtung gegen Volk-Löschung ist ein F2-Thema (Löschsperre) — hier per CASCADE + „kein Hard-Delete des Journals selbst" abgedeckt; als offener F2-Punkt vermerkt.
- **Record-Kopplung Diagnose↔Behandlung (Wirkungsgrad vorher/nachher):** die Daten liegen vor (Kontrollen vor/nach einer Behandlung); die explizite Wirkungsgrad-Auswertung ist ein Cockpit-/4.22-Thema, hier nur visuell im Chart.
