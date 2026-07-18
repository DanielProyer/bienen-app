# Design-Spec: Gesundheit/Schädlinge (Modul 4.14) — Katalog + Diagnose-Journal + Meldepflicht

**Stand:** 2026-07-18 · **Status:** Entwurf v2 (nach adversarialem Review, 18 Funde → 12 Maßnahmen) · **Modell:** Fable 5 (DB/RLS/Mandanten + CH-Meldepflicht)
**Grundlage:** [Funktionsumfang-Scope](2026-07-11-app-funktionsumfang-scope.md) §4.14 · [App-Implikationen](../../imkerei-fachwissen-app-implikationen.md) §4.14 · Fachwissen: `../../../imkerei/02_Recherche/14` (Bienengesundheit/Krankheiten CH, TSV-Rechtskategorien, Meldeweg)
**Baut auf:** 4.2 (Volk-Detailseite = Drehscheibe), 4.3 (`auffaelligkeiten`-Flags + privater Foto-Bucket/`FotoSpeicher`), 4.5/4.6 (Fachmodul-Muster).

> **Review-Historie:** v1 wurde von 4 adversarialen Lupen + Skeptiker geprüft (21 Funde → 18 bestätigt/teilweise). Die Architektur-Grundsätze wurden **bestätigt** (Soft-Delete ohne Immutable ist proportional; Katalog als Dart-const ist richtig). v2 arbeitet die Funde ein — folgenschwer: **M1** GR-Hardcode aus den universellen Fachdaten entfernt, **M2** CHECK `status=gemeldet ⇒ gemeldet_am`, **M8** Rechtskategorie ist national (bleibt Dart-const), **M4** Katalog-Vollständigkeit (Vergiftung/Tracheenmilbe).

---

## 1. Zweck

Ein **Krankheits-/Schädlings-Katalog** (CH-relevant, mit Rechtskategorie) plus ein **Diagnose-/Gesundheits-Journal je Volk** und ein **Meldepflicht-Hinweis** für die anzeigepflichtigen Seuchen (AFB/EFB u. a.). Kernnutzen: aus einer Beobachtung (auch aus einer 4.3-Durchsicht mit `faulbrut_verdacht`) wird eine **formale, nachvollziehbare Diagnose** mit Status-/Melde-Verfolgung; bei einer meldepflichtigen Seuche zeigt die App **prominent und sofort** die gesetzliche Pflicht (**zuständigen kantonalen Bieneninspektor** kontaktieren, Volk geschlossen halten; nationale BGD-Hotline 0800 274 274 für fachliche Begleitung).

**Realitätscheck:** Volk 1 kommt am 19.07.2026 (Live-Betrieb). Die Meldepflicht gilt **ab Volk 1** und **schon beim Verdacht** (Art. 61 TSV) — deshalb ist der Meldepflicht-Hinweis der höchste Nutzen des Moduls. Datenmodell auf 32/64, UI schlicht. Der Waage fehlt noch → 4.14 statt 4.9.

**Abgrenzung:** 4.14 ist ein **schlankerer Verwandter von 4.6** — Soft-Delete/Storno/`RESTRICT` (Bestandeskontroll-Spur), **ohne RPC/Material/Sammelerfassung** (eine Diagnose je Volk). Die volle **Sperrbezirk-/Fristen-/Sanierungs-Engine** (Radien 2 km/1 km, 30-Tage-Kontrolle) ist **4.23** — hier nur der Melde-**Hinweis**.

## 2. Scope

### In Scope
- **Katalog** `krankheit.dart` (Dart-Fachkonstante, CH-relevant, **kanton-neutral**, mandantenfähig).
- Tabelle `gesundheitsereignisse` (Diagnose-Journal je Volk, Bestandeskontroll-Niveau).
- Privater Storage-Bucket `health-photos` (Krankheitsbilder, Signed-URL).
- Flutter-Feature `lib/features/gesundheit/`: Diagnose-Formular, Gesundheits-Section + **Meldepflicht-Banner (mit Rechtsauskunft-Disclaimer)**, Andocken an die Volk-Detailseite.
- **4.3-Andocken:** krankheitsscharfer Shortcut „Diagnose erfassen" aus einer Durchsichts-`auffaelligkeit`.
- **Soft-Delete/Storno + volk-FK `RESTRICT`** (Melde-/Gesundheits-Spur überdauert Löschversuche + Volk-Abgang).

### Bewusst NICHT in Scope (Begründung)
| Ausgeschlossen | Warum |
|---|---|
| **Sperrbezirk-/Fristen-/Sanierungs-Engine** (Radien 2 km/1 km, 30-Tage-Kontrolle, Standort-Sperrstatus) | Modul 4.23 (Recht) / F4. Hier nur der Melde-**Hinweis**. |
| **Immutable-Trigger / RPC / Sammel-Diagnose / Material-Kopplung** | Eine Diagnose je Volk, ohne Lager/Atomarität — normaler Insert via Policy genügt. Soft-Delete + vollständige CHECKs decken die Integrität (Review-bestätigt: 4.5-Härte wäre Over-Engineering). |
| **Inspektor-Kontakt-Feld in den Betriebsstammdaten** | v1: Katalog liefert den **generischen** Melde-Text; der **konkrete** kantonale Inspektor-Kontakt kommt via 4.23/F4 (Erweiterungspunkt §9) — **nicht** über einen GR-Hardcode überbrückt. |
| **Geführter Diagnose-Entscheidungsbaum** (offen vs. verdeckelt, Streichholz-/Schnelltest-Assistent) | P3. v1: Katalog liefert Leitsymptome + Sofortmaßnahme als Text. |
| **Labor-Auftrags-Workflow** (Probenversand/Ergebnis-Tracking) | 4.23/4.15. v1: nur ein `labor_eingesandt`-Flag. |
| **Seuchen-Charge-Sperre** (AFB-/EFB-Volk → Honig/Wachs sperren) | 4.15 Ausfall / 4.23. |
| **Vespa-velutina-Neobiota-Zweig als Modul** (Fund-Meldung, Nest-Tracking) | P3. v1: Katalog-Eintrag mit Melde-Hinweis (asiatischehornisse.ch). |
| **Varroa→4.5-Behandlungs-Shortcut** | §9 vertagt (Symmetrie zum 4.3-Shortcut). v1: Prosaverweis „behandeln via Behandlungen". |
| **Blockier-Rot / erzwungene Meldung** | Der Banner **weist hin** (Warn), erzwingt nichts. |

## 3. Getroffene Entscheide

1. **Zuschnitt = Voll:** Katalog + Diagnose-Journal + Meldepflicht-Hinweis + Andocken (inkl. 4.3-Shortcut).
2. **Journal-Integrität = Bestandeskontroll-Spur:** **Soft-Delete + Storno**, **kein Hard-Delete** (keine DELETE-Policy), **volk-FK `ON DELETE RESTRICT`**. **Kein Immutable-Trigger, kein RPC** (proportional, kein federal TAMV-Journal wie 4.5). **Weil der Insert ohne RPC-Gatekeeper läuft, ist die CHECK-Schicht die einzige DB-Invarianten-Erzwingung → sie muss vollständig sein** (v. a. `status=gemeldet ⇒ gemeldet_am`, M2).
3. **Katalog = Dart-Fachkonstante** (`krankheit.dart`, wie `wirkstoff.dart`/`futterart.dart`) — CH-relevant, **betriebsübergreifend identisch, kanton-neutral, kein DB-Seed, kein Arosa-Hardcode**. Die TSV-`rechtskategorie` ist **Bundesrecht = national** → sie bleibt **dauerhaft** Dart-const (M8). Kanton-/tenant-spezifisch sind nur der **Inspektor-Kontakt** (Betriebsstammdaten, 4.23/F4) und die **Sperr-Radien** (4.23) — nicht die Rechtskategorie.
4. **Meldepflicht = Warn-Hinweis (mit Disclaimer), keine Engine:** Bei einer `zu_bekaempfen`-Krankheit (AFB/EFB/Kleiner Beutenkäfer/Tropilaelaps) zeigt die App **prominent** die Pflicht (Verdacht genügt → **zuständigen kantonalen Bieneninspektor** kontaktieren, Volk geschlossen halten, **keine** Eigen-Probeneinsendung). Der `neobiota_meldung`-Zweig (Vespa velutina) verweist auf asiatischehornisse.ch; `zu_ueberwachen` (Varroose) = milder Info-Hinweis. **Jeder Melde-Hinweis trägt einen Rechtsauskunft-Disclaimer** („ohne Gewähr — verbindlich ist die zuständige Fachstelle / BLV", M9). Kein Zwang, keine Fristen-Automatik (4.23).
5. **4.3 und 4.14 komplementär:** die 4.3-`auffaelligkeiten` bleiben der **Schnellflag**; 4.14 ist die **formale Diagnose** mit Melde-/Status-Verfolgung. Der Shortcut ist **krankheitsscharf** (M6): je gesundheitsrelevantem Flag der letzten Durchsicht ein Hinweis, wenn kein aktives Ereignis derselben Krankheit existiert.

## 4. Datenmodell

### 4.1 Katalog `krankheit.dart` (Dart-Fachkonstante)

Const-Liste `Krankheit`-Einträge; je Eintrag: `key`, `label`, `rechtskategorie`, `stadium`, `leitsymptome`, `sofortmassnahme`, `meldehinweis` (kanton-neutral). Enums:
- `rechtskategorie`: `zu_bekaempfen | zu_ueberwachen | nicht_meldepflichtig | neobiota_meldung` (verifiziert Recherche 14 §2.2, TSV SR 916.401).
- `stadium`: `offene_brut | verdeckelte_brut | adulte_bienen | waben_lager | mehrere`.

Einträge (CH-relevant, **17 Keys**):

| key | label | rechtskategorie |
|---|---|---|
| `afb` | Amerikanische Faulbrut | **zu_bekaempfen** (Meldepflicht ab Verdacht) |
| `efb` | Europäische Sauerbrut | **zu_bekaempfen** (Meldepflicht ab Verdacht) |
| `kleiner_beutenkaefer` | Kleiner Beutenkäfer (Aethina tumida) | **zu_bekaempfen** |
| `tropilaelaps` | Tropilaelaps-Milben | **zu_bekaempfen** |
| `varroa` | Varroose | **zu_ueberwachen** (kein Einzelfall-Melden; behandeln via 4.5) |
| `kalkbrut` | Kalkbrut | nicht_meldepflichtig |
| `steinbrut` | Steinbrut (Aspergillus) | nicht_meldepflichtig |
| `sackbrut` | Sackbrut | nicht_meldepflichtig |
| `nosema` | Nosemose | nicht_meldepflichtig |
| `ruhr` | Ruhr / Durchfall | nicht_meldepflichtig |
| `viren` | Viruserkrankungen (DWV/ABPV/CBPV) | nicht_meldepflichtig |
| `wachsmotte` | Wachsmotte | nicht_meldepflichtig |
| `braula` | Bienenlaus (Braula coeca) | nicht_meldepflichtig |
| `tracheenmilbe` | Tracheenmilbe (Acarapis woodi) | nicht_meldepflichtig |
| `vergiftung` | Vergiftung (PSM) | nicht_meldepflichtig (TSV), **eigener Melde-/Aktionspfad** |
| `vespa_velutina` | Asiatische Hornisse | **neobiota_meldung** (asiatischehornisse.ch) |
| `sonstige` | Sonstige/unklar | nicht_meldepflichtig |

**Fachliche Textkerne** (aus Recherche 14 — im Plan pro Eintrag vollständig, hier die kritischen):
- `afb`/`efb`: eingesunkene/durchlöcherte Deckel bzw. verkrümmte offene Larven → **Volk geschlossen halten, NICHTS umhängen, zuständigen Bieneninspektor melden, KEINE Eigen-Probeneinsendung** (§19.6: Inspektor nimmt amtlich Probe).
- `steinbrut`: **Arbeitsschutz!** Aspergillus ist humanpathogen → „Handschuhe + FFP2/FFP3-Maske, Sporen nicht einatmen, befallene Waben entsorgen" (M5, §6/§19.1).
- `sackbrut`: **AFB-Verwechslungsgefahr** (verdeckelte, eingesunkene Brut) → „Streichholz-/Fadenzugprobe; im Zweifel wie AFB melden" (M5, §7/§19.2). Wichtig, weil der rote Banner bei `sackbrut` nicht feuert.
- `vergiftung`: „schlagartiges Massensterben, gesunde Brut" → **eigener meldehinweis:** „Verdacht Bienenvergiftung → sofort **BGD 0800 274 274 / Agroscope**, Proben (tote Bienen + verdächtige Pflanze/Feld) ziehen **vor** Regen (kurzes Nachweisfenster)" — **nicht** primär der Inspektor.
- `vespa_velutina`: „Fund (Tier/Nest) mit Foto + Standort über **asiatischehornisse.ch** melden; Nester NICHT selbst entfernen".

Helper: **`istMeldepflichtig(key)`** = `rechtskategorie ∈ {zu_bekaempfen, neobiota_meldung}`; **`rechtskategorieVon(key)`**, **`katalogEintrag(key)`**, **`krankheitKeys`** (Set, = Single-Source für den DB-CHECK-Paritätstest, M3).

### 4.2 `gesundheitsereignisse` (Diagnose-Journal je Volk)

Mandanten-Muster (`betrieb_id NOT NULL DEFAULT private.aktive_betrieb_id()`, Audit, `set_row_actor`/`set_updated_at`, `revoke anon/public`+`grant authenticated`, Enums text+CHECK, `unique(betrieb_id,id)`). Same-Tenant-Komposit-FK (D-15).

| Spalte | Typ | Notiz |
|---|---|---|
| `id` | `uuid PK` | |
| `volk_id` | `uuid NOT NULL` | Komposit-FK → `voelker` **`ON DELETE RESTRICT`** |
| `festgestellt_am` | `date NOT NULL DEFAULT current_date` | |
| `krankheit` | `text NOT NULL` | CHECK gegen die 17 Katalog-Keys |
| `schweregrad` | `text NULL` | CHECK `leicht\|mittel\|schwer` |
| `status` | `text NOT NULL DEFAULT 'verdacht'` | CHECK `verdacht\|bestaetigt\|gemeldet\|in_behandlung\|saniert\|ausgeheilt\|erloschen` |
| `gemeldet_am` | `date NULL` | wann an den Inspektor gemeldet |
| `labor_eingesandt` | `boolean NOT NULL DEFAULT false` | |
| `foto_urls` | `text[] NOT NULL DEFAULT '{}'` | Storage-**Pfade** (Bucket `health-photos`, `<betrieb_id>/<volk_id>/…`, Signed-URL) |
| `massnahme` / `verantwortliche_person` / `notiz` | `text NULL` | App füllt Person vor |
| `is_storniert` / `storno_grund` / `storno_am` | Soft-Delete | |
| + audit | | |

**CHECKs:**
- `is_storniert = false OR (storno_grund is not null and storno_am is not null)`
- **`status <> 'gemeldet' OR gemeldet_am IS NOT NULL`** (M2 — der formale Melde-Zustand trägt sein Datum; einzige DB-Erzwingung, da kein RPC)
- `storno_am is null OR storno_am >= festgestellt_am`
- `gemeldet_am is null OR gemeldet_am >= festgestellt_am`
- `festgestellt_am <= current_date` und `gemeldet_am is null OR gemeldet_am <= current_date` (M7 — keine Zukunftsdatierung eines Gesundheitsereignisses)

**RLS:** `sel_member` + `ins_writer` + `upd_writer` (Edit/Storno). **KEINE DELETE-Policy** (Soft-Delete → Melde-/Gesundheits-Spur). *Kein Immutable-Trigger, kein RPC.* Index `(betrieb_id, volk_id, festgestellt_am desc)` (deckt die FK `(betrieb_id, volk_id)` führend ab).

### 4.3 Storage-Bucket `health-photos`
Privater Bucket (`public=false`), SELECT=`private.ist_mitglied`, Write=`private.kann_schreiben`, **Pfad `<betrieb_id>/<volk_id>/…`** (M6/D-19: eine neue Diagnose hat beim Upload noch keine id → `gruppeId = volk_id`; RLS greift ohnehin nur aufs erste Segment `betrieb_id`), UUID-Regex-Guard — **exakt das D02-Muster** (`inspection-photos`). `foto_urls` = **Pfade**, Anzeige via `createSignedUrl`. Helfer: **`FotoSpeicher(client, 'health-photos')`** (Zwei-Argument-Signatur, wie 4.3). Storno löscht die Zeile nicht → Fotos bleiben (Bestandeskontroll-Spur).

## 5. Ableitungen (reine Logik, Dart)

- **`istMeldepflichtig(krankheitKey) → bool`** = `rechtskategorie ∈ {zu_bekaempfen, neobiota_meldung}`.
- **`durchsichtFlagZuKrankheit(flag) → key?`**: `faulbrut_verdacht→afb`, `sauerbrut_verdacht→efb`, `kalkbrut→kalkbrut`, `sackbrut→sackbrut`, `varroa_sichtbar→varroa`, `ruhr→ruhr`, `wachsmotte→wachsmotte`; `raeuberei`/`kahlflug` → `null`.
- **`istAktiv(ereignis) → bool`** = `!isStorniert && status ∉ {saniert, ausgeheilt, erloschen}`.
- **Banner-Regel (Volk-Detailseite):** roter „Meldepflicht aktiv"-Banner, wenn es ein `ereignis` mit `istAktiv && rechtskategorieVon(krankheit) == zu_bekaempfen` gibt (Text = Katalog-`meldehinweis` + Disclaimer). `neobiota_meldung` → eigener Hinweis (asiatischehornisse.ch); `zu_ueberwachen` → kein roter Banner.
- **4.3-Nudge-Regel (M6, krankheitsscharf):** für **jedes** gesundheitsrelevante Flag der letzten Durchsicht (`letzteDurchsichtMapProvider`, 4.3) mit `durchsichtFlagZuKrankheit(flag) != null` **und ohne** aktives Ereignis derselben `krankheit` → ein Hinweis + Shortcut, der genau diesen Key vorbefüllt. Reine Ableitung aus `gesundheitFuerVolkProvider` (watch) → nicht stale. (`auffaelligkeiten` ist `text[]` → mehrere Nudges möglich.)

## 6. App-Schicht (`lib/features/gesundheit/`)

```
domain/       krankheit.dart (Katalog + Helper) · gesundheitsereignis.dart (Modell) · gesundheit_gateway.dart
data/         supabase_gesundheit_gateway.dart · fake_gesundheit_gateway.dart
presentation/ providers/gesundheit_provider.dart
              pages/gesundheit_form_page.dart
              widgets/gesundheit_section.dart · meldepflicht_banner.dart
```

- **Gateway:** `ereignisseFuerVolk(volkId)` (inkl. stornierte, absteigend) · `speichern(Gesundheitsereignis)` (insert wenn id leer, sonst Edit) · `stornieren(id, grund)` · Foto-Helfer (`hochladen`/`signedUrl`/`entfernen` via `FotoSpeicher(client, 'health-photos')`, `gruppeId = volkId`). Fehler-Mapping `PostgrestException` → Klartext.
- **State:** Family-Provider `gesundheitFuerVolkProvider(volkId)` (non-autoDispose). Schreibaktionen `invalidateSelf()`. Abgeleitet: `aktiveMeldepflichtProvider(volkId)` (aktive `zu_bekaempfen`-Ereignisse, `ref.watch` auf die Family → refresht nach Storno/Status). **`gesundheitFuerVolkProvider` in `AuthController._datenNeuLaden()`.** `viewer` read-only.
- **UI — Sektion „Gesundheit" auf der Volk-Detailseite** (unter „Fütterung"):
  1. **Meldepflicht-Banner (rot)** ganz oben bei aktivem `zu_bekaempfen`-Ereignis (Krankheit + Katalog-`meldehinweis` + **Rechtsauskunft-Disclaimer** „ohne Gewähr — verbindlich ist die Fachstelle / BLV").
  2. **4.3-Andocken (krankheitsscharf, §5):** je offenem gesundheitsrelevantem Durchsichts-Flag ohne passendes aktives Ereignis ein dezenter Hinweis + Shortcut. (Bewusste Grenze: hängt an der **letzten** Durchsicht — §10.)
  3. Button „Diagnose erfassen" → `gesundheit_form_page`.
  4. Kompakte Liste (Krankheits-Chip **farbcodiert nach Rechtskategorie**: rot=zu_bekämpfen, orange=zu_überwachen, lila=neobiota, grau=nicht; Status + Datum; **storniert = durchgestrichen**; Storno-Button für Schreibberechtigte).
- **`gesundheit_form_page`** (Vollseite, Rollen-Guard im `build`, `context.mounted`-Checks, optionaler vorbefüllter Krankheit-Key): Krankheits-Auswahl (aus dem Katalog, **gruppiert nach Rechtskategorie**); `festgestellt_am`; Schweregrad; Status; `gemeldet_am` (**Pflicht wenn Status=gemeldet** — clientseitig + DB-CHECK); Labor-Switch; Maßnahme; Verantwortliche:r (vorbefüllt); Notiz; **Fotos** (aufnehmen/anzeigen wie 4.3). **Live-Meldepflicht-Banner (rot + Disclaimer)** bei `zu_bekaempfen`-Wahl (`meldehinweis` + `sofortmassnahme`); `neobiota_meldung` → Hinweis asiatischehornisse.ch; sonst Katalog-Kurzinfo (bei `vergiftung` mit ihrem eigenen Aktionspfad). Speichern → Family-Notifier.

## 7. Migrationen & Rollout

| # | Inhalt |
|---|---|
| `G01` | `gesundheitsereignisse` (Komposit-FK `volk_id` `RESTRICT`, **alle CHECKs inkl. `status=gemeldet⇒gemeldet_am` und Zukunfts-Guard**, `krankheit`-Whitelist = 17 Katalog-Keys, RLS `sel/ins/upd` **ohne DELETE-Policy**, Trigger, Grants, Index) |
| `G02` | Privater Bucket `health-photos` (D02-Muster) |

Jede Migration: Datei + `apply_migration`; Kopf-Kommentar; **Rollback-DO-Test**; `get_advisors(security)` → **0 neue Findings** (kein RPC → keine 0029). **Kein Ops-Seed. Keine neuen Errcodes** (reines CRUD).
- **Katalog↔CHECK-Parität (M3):** die `krankheit`-CHECK-Whitelist dupliziert die Dart-Katalog-Keys. **Checklist-Regel:** neuer Katalog-Key ⇒ **paired G-Migration**, die den CHECK erweitert. Ein Dart-Test (§8) hält beide Seiten synchron. *(Häufigster Fall — Umkategorisierung einer bestehenden Krankheit — ist reine `rechtskategorie`-Pflege ohne Migration, da `rechtskategorie` nicht im CHECK steht.)*

**App:** neuer Family-Provider in `_datenNeuLaden`.
**Deploy:** `version:` → **1.13.0+31**, `bash deploy.sh` (stehende Freigabe).

## 8. Tests

**SQL (Rollback-DO):**
- Mandanten-Isolation; Komposit-FK (fremdes `volk_id` → FK-Fehler).
- **volk-FK `RESTRICT`:** Volk mit Gesundheitsereignis hart löschen scheitert.
- CHECK: `krankheit`/`schweregrad`/`status`-Whitelist; Storno-Vollständigkeit; **`status='gemeldet'` ohne `gemeldet_am` scheitert (M2)**; `storno_am`/`gemeldet_am < festgestellt_am` scheitert; **Zukunftsdatum `festgestellt_am`/`gemeldet_am` scheitert (M7)**.
- **Kein Hard-DELETE** (keine Policy); Storno-UPDATE + normaler Insert (via Policy) funktionieren; `betrieb_id`/`created_by` nicht fälschbar.

**Dart:** `istMeldepflichtig` + `rechtskategorieVon` je Katalog-Key (AFB/EFB/Käfer/Tropilaelaps=zu_bekämpfen, Varroa=zu_überwachen, Kalkbrut/…/Vergiftung/Tracheenmilbe=nicht, Vespa=neobiota); **Katalog↔CHECK-Paritätstest (M3):** `krankheitKeys` == migrierte CHECK-Whitelist; `durchsichtFlagZuKrankheit` (faulbrut_verdacht→afb, raeuberei/kahlflug→null); `istAktiv`; Modell-Roundtrip; **`FakeGesundheitGateway`** (Insert/Edit/Storno + **Foto-Helfer als No-Op/In-Memory-Pfadliste**, Storno erhält `foto_urls`, kein Hard-Delete); Provider-Test (`aktiveMeldepflichtProvider` nur aktive `zu_bekaempfen`); **signOut invalidiert Cache**; Meldepflicht-Banner- + 4.3-Nudge-Logik; Rollen-Gating. `flutter analyze` sauber, alle grün.

## 9. Erweiterungspunkte (bewusst offen)

| Punkt | Für |
|---|---|
| **Inspektor-Kontakt-Feld in Betriebsstammdaten** (kanton-/tenant-spezifisch) | 4.23/F4 — der Banner nennt dann den konkreten zuständigen Inspektor statt nur den generischen Text (M1/M8) |
| Sperr-Radien (2 km/1 km) + Fristen/Sanierungs-Status | 4.23 Sperrbezirk-Engine (kantonal konfigurierbar) |
| `gesundheitsereignisse` (Soft-Delete-Spur, `status`/`gemeldet_am`) | 4.23 revisionssicherer Export + Fristen-Wächter |
| `labor_eingesandt` | 4.23/4.15 Labor-Auftrags-Workflow |
| `krankheit == afb/efb` + Status | 4.15 Ausfall/Seuchen-Charge-Sperre |
| **Varroa-Diagnose → 4.5-Behandlungs-Shortcut** (Symmetrie zum 4.3-Shortcut) | vertagt; v1 = Prosaverweis (4.5 ist live, JETZT bespielbar, aber kein v1-Muss) |
| `vespa_velutina` / `vergiftung` | P3 eigene Melde-Zweige (asiatischehornisse.ch/APINELLA; BGD/Agroscope-Probenversand) |
| Katalog + Diagnose | P3 geführter Entscheidungsbaum (offen vs. verdeckelt, Schnelltest) + Standkoffer-Checkliste |
| `foto_urls` (Bucket `health-photos`) | 4.25 serverseitiges Storage-Aufräumen |

## 10. Risiken & offene Punkte

- **Kein Immutable-Trigger / Edit erlaubt:** ein Schreibberechtigter kann Kernfelder nachträglich ändern — nur über `updated_at`/`updated_by` nachvollziehbar. Akzeptiert (Bestandeskontroll-Spur, kein federal TAMV-Journal; Review-bestätigt: proportional). Die vollständige CHECK-Schicht (inkl. M2) hält die einzige DB-seitige Invariante geschlossen. Volle Revisionssicherheit → 4.23.
- **Meldepflicht ist Hinweis, kein Zwang:** der Banner (mit Disclaimer) weist auf die Pflicht hin, erzwingt/protokolliert die Meldung aber nicht (kein Fristen-Wächter). Die verbindliche Melde-/Sperr-Automatik ist 4.23; bis dahin liegt die tatsächliche Meldung beim Imker.
- **Katalog-Rechtskategorien = verifizierte Richtwerte** (Recherche 14, TSV SR 916.401): AFB Art. 269 ff., EFB Art. 273 ff. — Artikelnummern (Fassung 01.01.2026) mit fedlex/Bieneninspektor final bestätigen. **Nicht in UI-Feldern** (die UI zeigt den Melde-Hinweis + Disclaimer, keine Artikelnummern). `rechtskategorie` ist **national** (Bundesrecht) → dauerhaft universelle Dart-const; kanton-/tenant-spezifisch sind nur Inspektor-Kontakt + Radien (§9).
- **`storno_am`/`gemeldet_am` client-gesetzt** (kein Trigger, bewusst leicht); CHECKs verhindern grobe Fehl-/Rück-/Vorwärtsdatierung, `updated_at` = Server-Wahrheit.
- **`volk_id` `RESTRICT`:** ein Volk mit Gesundheitsereignis lässt sich nicht hart löschen — Abgang via `voelker.status`. Konsistent mit 4.5/4.6.
- **4.3-Nudge hängt nur an der LETZTEN Durchsicht:** ein meldepflichtiger Flag aus einer früheren Durchsicht ohne Folge-Diagnose verliert den Shortcut, sobald eine spätere (unauffällige) Durchsicht existiert. Bewusste Grenze (Komfort); der Banner speist sich aus echten Diagnosen (unberührt), der manuelle „Diagnose erfassen"-Button bleibt Fallback.
- **Überlappung 4.3 ↔ 4.14 bewusst:** dieselbe Beobachtung kann als Flag **und** Diagnose existieren; der krankheitsscharfe Shortcut mindert Doppelerfassung. Die formale Diagnose ist der maßgebliche Bestandeskontroll-Datensatz.
- **Foto-Orphans:** durch volk-FK `RESTRICT` + Soft-Delete gibt es **keinen** Volk-Hard-Delete-Pfad, der `foto_urls` verwaisen ließe. Der einzige (transiente) Orphan ist ein im Formular hochgeladenes, dann nicht gespeichertes/entferntes Foto — via `FotoSpeicher.entfernen` abgefangen (identisch zu 4.3).
