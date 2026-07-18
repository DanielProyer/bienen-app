# Design-Spec: Gesundheit/Schädlinge (Modul 4.14) — Katalog + Diagnose-Journal + Meldepflicht

**Stand:** 2026-07-18 · **Status:** Entwurf (Brainstorming abgeschlossen) · **Modell:** Fable 5 (DB/RLS/Mandanten + CH-Meldepflicht)
**Grundlage:** [Funktionsumfang-Scope](2026-07-11-app-funktionsumfang-scope.md) §4.14 · [App-Implikationen](../../imkerei-fachwissen-app-implikationen.md) §4.14 · Fachwissen: `../../../imkerei/02_Recherche/14` (Bienengesundheit/Krankheiten CH, TSV-Rechtskategorien, Meldeweg GR)
**Baut auf:** 4.2 „Völker & Standorte" (Volk-Detailseite = Drehscheibe), 4.3 „Durchsicht" (`auffaelligkeiten`-Flags + privater Foto-Bucket/`FotoSpeicher`), 4.5/4.6 (Fachmodul-Muster).

---

## 1. Zweck

Ein **Krankheits-/Schädlings-Katalog** (CH-relevant, mit Rechtskategorie) plus ein **Diagnose-/Gesundheits-Journal je Volk** und ein **Meldepflicht-Hinweis** für die anzeigepflichtigen Seuchen (AFB/EFB u. a.). Kernnutzen: aus einer Beobachtung (auch aus einer 4.3-Durchsicht mit `faulbrut_verdacht`) wird eine **formale, nachvollziehbare Diagnose** mit Status-/Melde-Verfolgung; bei einer meldepflichtigen Seuche zeigt die App **prominent und sofort** die gesetzliche Pflicht (Bieneninspektor GR kontaktieren, Volk geschlossen halten).

**Realitätscheck:** Volk 1 kommt am 19.07.2026 (Live-Betrieb). Die Meldepflicht gilt **ab Volk 1** und **schon beim Verdacht** (Art. 61 TSV) — deshalb ist der Meldepflicht-Hinweis der höchste Nutzen des Moduls. Datenmodell auf 32/64, UI schlicht. Der Waage fehlt noch → 4.14 statt 4.9.

**Abgrenzung:** 4.14 ist ein **schlankerer Verwandter von 4.6** — Soft-Delete/Storno/`RESTRICT` (Bestandeskontroll-Spur), **aber ohne RPC/Material/Sammelerfassung** (eine Diagnose je Volk, kein Lager, keine Atomarität). Die volle **Sperrbezirk-/Fristen-/Sanierungs-Engine** (Radien 2 km/1 km, 30-Tage-Kontrolle) ist **4.23** — hier nur der Melde-**Hinweis**.

## 2. Scope

### In Scope
- **Katalog** `krankheit.dart` (Dart-Fachkonstante, CH-relevant, mandantenfähig).
- Tabelle `gesundheitsereignisse` (Diagnose-Journal je Volk, Bestandeskontroll-Niveau).
- Privater Storage-Bucket `health-photos` (Krankheitsbilder, Signed-URL).
- Flutter-Feature `lib/features/gesundheit/`: Diagnose-Formular, Gesundheits-Section + **Meldepflicht-Banner**, Andocken an die Volk-Detailseite.
- **4.3-Andocken:** Shortcut „Diagnose erfassen" aus einer Durchsichts-`auffaelligkeit`.
- **Soft-Delete/Storno + volk-FK `RESTRICT`** (Melde-/Gesundheits-Spur überdauert Löschversuche + Volk-Abgang).

### Bewusst NICHT in Scope (Begründung)
| Ausgeschlossen | Warum |
|---|---|
| **Sperrbezirk-/Fristen-/Sanierungs-Engine** (Radien 2 km/1 km, 30-Tage-Kontrolle, Standort-Sperrstatus, versionierte Referenzdaten) | Modul 4.23 (Recht) / F4. Hier nur der Melde-**Hinweis** (Warn-Banner). |
| **Immutable-Trigger / RPC / Sammel-Diagnose / Material-Kopplung** | Eine Diagnose ist je Volk, ohne Lager/Atomarität — normaler Insert via Policy genügt. Soft-Delete deckt die Integrität. |
| **Geführter Diagnose-Entscheidungsbaum** (offen vs. verdeckelt, Streichholz-/Schnelltest-Assistent) | P3-Ausbau. v1: Katalog liefert Leitsymptome + Sofortmaßnahme als Text; der Imker entscheidet. |
| **Labor-Auftrags-Workflow** (Probenversand, Ergebnis-Tracking, Sperre der Charge) | 4.23/4.15. v1: nur ein `labor_eingesandt`-Flag. |
| **Seuchen-Charge-Sperre** (AFB-/EFB-Volk → Honig/Wachs sperren) | 4.15 Ausfall / 4.23. |
| **Vespa-velutina-Neobiota-Zweig als eigenes Modul** (Fund-Meldung, Nest-Tracking) | P3. v1: als Katalog-Eintrag mit Melde-Hinweis (asiatischehornisse.ch) abgebildet. |
| **Blockier-Rot / erzwungene Meldung** | Der Banner **weist hin** (Warn), erzwingt nichts — der Imker meldet selbst. |

## 3. Getroffene Entscheide

1. **Zuschnitt = Voll:** Katalog + Diagnose-Journal + Meldepflicht-Hinweis + Andocken (inkl. 4.3-Shortcut).
2. **Journal-Integrität = Bestandeskontroll-Spur:** **Soft-Delete + Storno** (`is_storniert`/`storno_grund`/`storno_am`), **kein Hard-Delete** (keine DELETE-Policy) — ein meldepflichtiges AFB/EFB-Ereignis darf nicht spurlos verschwinden. **volk-FK `ON DELETE RESTRICT`** (Ereignis überdauert einen Volk-Abgang). **Kein Immutable-Trigger, kein RPC** (proportional, kein federal Pflichtjournal wie 4.5). Insert normal via `ins_writer`-Policy; Korrektur per Edit oder Storno.
3. **Katalog = Dart-Fachkonstante** (`krankheit.dart`, wie `wirkstoff.dart`/`futterart.dart`) — CH-relevante Krankheiten/Schädlinge, **kein DB-Seed, kein Arosa-Hardcode**. Betriebsübergreifende Stammdaten, für alle Mandanten identisch. (F4/4.23 könnte später `rechtskategorie`/Radien pro Betrieb überschreiben.)
4. **Meldepflicht = Warn-Hinweis, keine Engine:** Bei einer `zu_bekaempfen`-Krankheit (AFB/EFB/Kleiner Beutenkäfer/Tropilaelaps) zeigt die App **prominent** die gesetzliche Pflicht (Verdacht genügt → Bieneninspektor GR, Volk geschlossen halten). Der `neobiota_meldung`-Zweig (Vespa velutina) verweist auf asiatischehornisse.ch. `zu_ueberwachen` (Varroose) = milder Info-Hinweis (kein Einzelfall-Melden). Kein Zwang, keine Fristen-Automatik (4.23).
5. **4.3 und 4.14 komplementär:** die 4.3-`auffaelligkeiten` bleiben der **Schnellflag** in der Durchsicht; 4.14 ist die **formale Diagnose** mit Melde-/Status-Verfolgung. Die Gesundheits-Section verlinkt beide (Flag → Diagnose-Shortcut), ersetzt 4.3 aber nicht.

## 4. Datenmodell

### 4.1 Katalog `krankheit.dart` (Dart-Fachkonstante)

Const-Liste `Krankheit`-Einträge; je Eintrag: `key`, `label`, `rechtskategorie`, `stadium`, `leitsymptome` (kurz), `sofortmassnahme` (kurz), `meldehinweis` (bei meldepflichtigen). Enums:
- `rechtskategorie`: `zu_bekaempfen | zu_ueberwachen | nicht_meldepflichtig | neobiota_meldung` (verifiziert Recherche 14 §2.2, TSV SR 916.401).
- `stadium`: `offene_brut | verdeckelte_brut | adulte_bienen | waben_lager | mehrere`.

Einträge (CH-relevant):

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
| `vespa_velutina` | Asiatische Hornisse | **neobiota_meldung** (asiatischehornisse.ch) |
| `sonstige` | Sonstige/unklar | nicht_meldepflichtig |

Leitsymptome/Sofortmaßnahme/Meldehinweis je Eintrag: fachlich aus Recherche 14 (AFB: eingesunkene/durchlöcherte Deckel, fadenziehende Streichholzprobe, Geruch → Volk geschlossen halten, **nichts umhängen**, sofort Inspektor; EFB: verkrümmte/vergilbte offene Larven, säuerlich → Inspektor; usw.). Helper: **`istMeldepflichtig(key)`** = `rechtskategorie in {zu_bekaempfen, neobiota_meldung}`; **`rechtskategorieVon(key)`**, **`katalogEintrag(key)`**.

### 4.2 `gesundheitsereignisse` (Diagnose-Journal je Volk)

Mandanten-Muster (`betrieb_id NOT NULL DEFAULT private.aktive_betrieb_id()`, Audit, `set_row_actor`/`set_updated_at`, `revoke anon/public`+`grant authenticated`, Enums text+CHECK, `unique(betrieb_id,id)`). Same-Tenant-Komposit-FK (D-15).

| Spalte | Typ | Notiz |
|---|---|---|
| `id` | `uuid PK` | |
| `volk_id` | `uuid NOT NULL` | Komposit-FK → `voelker` **`ON DELETE RESTRICT`** |
| `festgestellt_am` | `date NOT NULL DEFAULT current_date` | |
| `krankheit` | `text NOT NULL` | CHECK gegen Katalog-Keys (`afb\|efb\|kleiner_beutenkaefer\|tropilaelaps\|varroa\|kalkbrut\|steinbrut\|sackbrut\|nosema\|ruhr\|viren\|wachsmotte\|braula\|vespa_velutina\|sonstige`) |
| `schweregrad` | `text NULL` | CHECK `leicht\|mittel\|schwer` |
| `status` | `text NOT NULL DEFAULT 'verdacht'` | CHECK `verdacht\|bestaetigt\|gemeldet\|in_behandlung\|saniert\|ausgeheilt\|erloschen` |
| `gemeldet_am` | `date NULL` | wann an den Inspektor gemeldet |
| `labor_eingesandt` | `boolean NOT NULL DEFAULT false` | Probe ans Labor (ZBF/apiservice) |
| `foto_urls` | `text[] NOT NULL DEFAULT '{}'` | Storage-**Pfade** (Bucket `health-photos`, Signed-URL) |
| `massnahme` | `text NULL` | ergriffene Maßnahme |
| `verantwortliche_person` | `text NULL` | App füllt vor |
| `notiz` | `text NULL` | |
| `is_storniert` | `boolean NOT NULL DEFAULT false` | Soft-Delete |
| `storno_grund` | `text NULL` | Pflicht bei Storno (CHECK) |
| `storno_am` | `date NULL` | beim Storno gesetzt (Gateway); `updated_at`/`updated_by` = Server-Wahrheit |
| + audit | | |

**CHECKs:**
- `is_storniert = false OR (storno_grund is not null and storno_am is not null)`
- `storno_am is null OR storno_am >= festgestellt_am`
- `gemeldet_am is null OR gemeldet_am >= festgestellt_am`

**RLS:** `gesundheitsereignisse_sel_member` (SELECT) + `gesundheitsereignisse_ins_writer` (INSERT) + `gesundheitsereignisse_upd_writer` (UPDATE, Edit/Storno). **KEINE DELETE-Policy** (Soft-Delete → Melde-/Gesundheits-Spur). *Kein Immutable-Trigger, kein RPC.* Index `(betrieb_id, volk_id, festgestellt_am desc)`.

### 4.3 Storage-Bucket `health-photos`
Privater Bucket (`public=false`), SELECT=`private.ist_mitglied`, Write=`private.kann_schreiben`, `<betrieb_id>/`-Pfad, UUID-Regex-Guard — **exakt das D02-Muster** (`inspection-photos`). `foto_urls` speichert **Pfade**, Anzeige via `createSignedUrl` (`FotoSpeicher`-Helfer aus 4.3, mit `'health-photos'` instanziiert). Löschen einer Diagnose ist Soft-Delete (Storno) → Fotos bleiben erhalten (Bestandeskontroll-Spur); echtes Storage-Aufräumen erst bei 4.25/F2.

## 5. Ableitungen (reine Logik, Dart)

- **`istMeldepflichtig(krankheitKey) → bool`** = `rechtskategorie ∈ {zu_bekaempfen, neobiota_meldung}`.
- **`durchsichtFlagZuKrankheit(flag) → key?`** (4.3-Andocken): `faulbrut_verdacht→afb`, `sauerbrut_verdacht→efb`, `kalkbrut→kalkbrut`, `sackbrut→sackbrut`, `varroa_sichtbar→varroa`, `ruhr→ruhr`, `wachsmotte→wachsmotte`; `raeuberei`/`kahlflug` → `null` (keine Krankheit).
- **`istAktiv(ereignis) → bool`** = `!isStorniert && status ∉ {saniert, ausgeheilt, erloschen}`.
- **Banner-Regel (Volk-Detailseite):** roter „Meldepflicht aktiv"-Banner, wenn es ein `ereignis` mit `istAktiv && rechtskategorieVon(krankheit) == zu_bekaempfen` gibt (Text aus Katalog-`meldehinweis`). `neobiota_meldung` (Vespa) → eigener Hinweis (asiatischehornisse.ch); `zu_ueberwachen` → kein roter Banner.

## 6. App-Schicht (`lib/features/gesundheit/`)

```
domain/       krankheit.dart (Katalog + Helper) · gesundheitsereignis.dart (Modell) · gesundheit_gateway.dart
data/         supabase_gesundheit_gateway.dart · fake_gesundheit_gateway.dart
presentation/ providers/gesundheit_provider.dart
              pages/gesundheit_form_page.dart
              widgets/gesundheit_section.dart · meldepflicht_banner.dart
```

- **Gateway:** `ereignisseFuerVolk(volkId)` (inkl. stornierte, absteigend) · `speichern(Gesundheitsereignis)` (insert wenn id leer, sonst Edit) · `stornieren(id, grund)` · Foto-Helfer (`FotoSpeicher('health-photos')`: `hochladen`/`signedUrl`/`entfernen`). Fehler-Mapping `PostgrestException` → Klartext; keine stillen Fallbacks.
- **State:** Family-Provider `gesundheitFuerVolkProvider(volkId)` (non-autoDispose). Schreibaktionen `invalidateSelf()`. Abgeleitet: `aktiveMeldepflichtProvider(volkId)` (reine Ableitung aus der Family: aktive `zu_bekaempfen`-Ereignisse für den Banner). **`gesundheitFuerVolkProvider` in `AuthController._datenNeuLaden()`** (Fremd-Mandanten-Cache). `viewer` read-only.
- **UI — Sektion „Gesundheit" auf der Volk-Detailseite** (unter „Fütterung"):
  1. **Meldepflicht-Banner (rot)** ganz oben, wenn ein aktives `zu_bekaempfen`-Ereignis vorliegt (Krankheit + Katalog-Meldehinweis).
  2. **4.3-Andocken:** meldet die letzte Durchsicht (`letzteDurchsichtMapProvider`, 4.3) eine gesundheitsrelevante `auffaelligkeit` ohne passendes aktives Ereignis → dezenter Hinweis + Shortcut „als Diagnose erfassen" (Krankheit via `durchsichtFlagZuKrankheit` vorbefüllt).
  3. Button „Diagnose erfassen" → `gesundheit_form_page`.
  4. Kompakte Liste (Krankheits-Chip **farbcodiert nach Rechtskategorie**: rot=zu_bekämpfen, orange=zu_überwachen, lila=neobiota, grau=nicht; Status + Datum; **storniert = durchgestrichen** + Grund; Storno-Button für Schreibberechtigte).
- **`gesundheit_form_page`** (Vollseite, Rollen-Guard im `build`, `context.mounted`-Checks, optionaler vorbefüllter Krankheit-Key aus dem Shortcut): Krankheits-Auswahl (aus dem Katalog, **gruppiert nach Rechtskategorie**); `festgestellt_am`; Schweregrad; Status; `gemeldet_am` (sichtbar bei Status=gemeldet); Labor-Switch; Maßnahme; Verantwortliche:r (vorbefüllt); Notiz; **Fotos** (aufnehmen/anzeigen wie 4.3-Detailseite). **Live-Meldepflicht-Banner (rot)** sobald eine `zu_bekaempfen`-Krankheit gewählt ist (`meldehinweis` + `sofortmassnahme` aus dem Katalog); `neobiota_meldung` → Hinweis asiatischehornisse.ch; `zu_ueberwachen`/`nicht_meldepflichtig` → nur die Katalog-Kurzinfo. Speichern → Family-Notifier.

## 7. Migrationen & Rollout

| # | Inhalt |
|---|---|
| `G01` | `gesundheitsereignisse` (Komposit-FK `volk_id` `RESTRICT`, CHECKs, RLS `sel/ins/upd` **ohne DELETE-Policy**, Trigger, Grants, Index) |
| `G02` | Privater Bucket `health-photos` (D02-Muster: `public=false`, SELECT=`ist_mitglied`, Write=`kann_schreiben`, `<betrieb_id>/`-Pfad, UUID-Regex-Guard) |

Jede Migration: Datei (`supabase/migrations/`) + MCP `apply_migration`; Kopf-Kommentar; **Rollback-DO-Test**; `get_advisors(security)` → **0 neue Findings** (kein RPC → keine 0029; privater Bucket mit sauberen Policies löst nichts aus). **Kein Ops-Seed** (Katalog ist Dart). **Keine neuen Errcodes** (reines CRUD, wie 4.3).

**App:** neuer Family-Provider in `_datenNeuLaden`.
**Deploy:** `version:` → **1.13.0+31**, `bash deploy.sh` (stehende Freigabe).

## 8. Tests

**SQL (Rollback-DO):**
- Mandanten-Isolation (fremder Betrieb sieht/schreibt nichts).
- Komposit-FK: fremdes/erfundenes `volk_id` → FK-Fehler.
- **volk-FK `RESTRICT`:** Volk mit Gesundheitsereignis hart löschen scheitert.
- CHECK: `krankheit`/`schweregrad`/`status`-Whitelist; Storno-Vollständigkeit; `storno_am < festgestellt_am` scheitert; `gemeldet_am < festgestellt_am` scheitert.
- **Kein Hard-DELETE** (keine Policy); Storno-UPDATE + normaler Insert (via Policy) funktionieren.
- `betrieb_id`/`created_by` nicht fälschbar.

**Dart:** `istMeldepflichtig` + `rechtskategorieVon` je Katalog-Key (AFB/EFB/Käfer/Tropilaelaps=zu_bekämpfen, Varroa=zu_überwachen, Kalkbrut/Sackbrut/…=nicht, Vespa=neobiota); `durchsichtFlagZuKrankheit` (faulbrut_verdacht→afb, sauerbrut_verdacht→efb, raeuberei/kahlflug→null); `istAktiv` (storniert/geschlossene Status ausgeschlossen); Modell-Roundtrip; `FakeGesundheitGateway` (Insert/Edit/Storno, kein Hard-Delete); Provider-Test (`aktiveMeldepflichtProvider` liefert nur aktive `zu_bekaempfen`); **signOut invalidiert Cache**; Meldepflicht-Banner-Logik; Rollen-Gating. `flutter analyze` sauber, alle grün.

## 9. Erweiterungspunkte (bewusst offen)

| Punkt | Für |
|---|---|
| `gesundheitsereignisse` (Soft-Delete-Spur, `status`/`gemeldet_am`) | 4.23 Sperrbezirk-/Fristen-/Sanierungs-Engine (Radien 2 km/1 km, 30-Tage-Kontrolle, Standort-Sperrstatus) + revisionssicherer Export |
| `labor_eingesandt` | 4.23/4.15 Labor-Auftrags-Workflow (Probenversand, Ergebnis, Charge-Sperre) |
| Katalog-`rechtskategorie`/Radien | F4 (pro Betrieb/Kanton überschreibbar) — Kanton als Steuerfeld |
| `krankheit == afb/efb` + Status | 4.15 Ausfall/Seuchen-Charge-Sperre (Honig/Wachs sperren) |
| `vespa_velutina` | P3 Neobiota-Zweig (Fund-Meldung, Nest-Tracking, asiatischehornisse.ch/APINELLA) |
| Katalog + Diagnose | P3 geführter Entscheidungsbaum (offen vs. verdeckelt, Streichholz-/Schnelltest) + Standkoffer-Checkliste |
| `foto_urls` (Bucket `health-photos`) | 4.25 serverseitiges Storage-Aufräumen (Soft-Delete lässt Fotos bewusst stehen) |

## 10. Risiken & offene Punkte

- **Kein Immutable-Trigger / Edit erlaubt:** ein Schreibberechtigter kann Kernfelder nachträglich ändern — nur über `updated_at`/`updated_by` nachvollziehbar. Akzeptiert (Bestandeskontroll-Spur, kein federal TAMV-Journal); die volle Revisionssicherheit kommt mit 4.23.
- **Meldepflicht ist Hinweis, kein Zwang:** der Banner weist auf die gesetzliche Pflicht hin, erzwingt/protokolliert die Meldung aber nicht (kein Fristen-Wächter). Die verbindliche Melde-/Sperr-Automatik ist 4.23 — bis dahin liegt die tatsächliche Meldung beim Imker.
- **Katalog-Rechtskategorien sind verifizierte Richtwerte** (Recherche 14, TSV SR 916.401, BLV/Kanton GR): AFB Art. 269 ff., EFB Art. 273 ff. — Artikelnummern der Fassung 01.01.2026 mit fedlex/Bieneninspektor GR final bestätigen. Universelle Fachdefaults, kein Arosa-Hardcode; F4 macht sie später kantonsabhängig.
- **`storno_am`/`gemeldet_am` client-gesetzt** (kein Trigger, bewusst leicht); CHECKs verhindern die grobe Fehl-/Rückdatierung, `updated_at` liefert die Server-Wahrheit.
- **`volk_id` `RESTRICT`:** ein Volk mit Gesundheitsereignis (auch stornierten) lässt sich nicht hart löschen — Abgang via `voelker.status`. Konsistent mit 4.5/4.6.
- **Überlappung 4.3 ↔ 4.14 bewusst:** dieselbe Beobachtung kann als 4.3-Flag **und** 4.14-Diagnose existieren. Der Shortcut mindert Doppelerfassung, verhindert sie aber nicht; die formale Diagnose ist der maßgebliche Bestandeskontroll-Datensatz.
- **Fotos bleiben bei Storno erhalten** (Bestandeskontroll-Spur) → potenziell Storage-Reste bei „echtem" Volk-Hard-Delete-Umweg; 4.25 räumt serverseitig nach.
