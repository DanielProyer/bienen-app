# Decision-Log — App-Schiene (Bienen Arosa)

Chronik der **App-Entscheide** (neueste zuerst). Format: **Datum — Entscheid** · Begründung · Konsequenz. Imkerei-Fachentscheide: `../../imkerei/decision-log.md`. Nachgeführt bei Arbeitsschluss.

---

## 2026-07-17 — Modul 4.2 „Völker & Standorte" live (v1.9.0)

Erstes Fachmodul auf dem Auth-Fundament. Spec→Plan→Umsetzung (Fable 5), subagent-getrieben, 3-fach reviewt (adversariales Design-Review: 43 Findings/36 eingearbeitet; + Spec- und Code-Qualitäts-Review je Milestone; + holistischer End-Review). 45/45 Tests, live deployed.

- **D-12 · Betriebs-Defaults in eigener `betriebs_einstellungen` (1:1 je Betrieb)** statt Spalten auf `betriebe` — F4-Keimzelle, trennt Identität von Konfiguration. Arosa = Daten (Ops-Seed), kein Code. *Gotcha:* KEIN `default aktive_betrieb_id()` — der Gründer hat beim `betrieb_gruenden` noch keinen JWT-Claim → NULL → PK-Verletzung; die RPC übergibt `betrieb_id` **explizit** + Backfill für Bestandsbetriebe.
- **D-13 · Königin als eigene Entität** (`koeniginnen`) mit Zuordnungs-Spur (`volk_id`/`zugeordnet_am`/`ersetzt_am`) statt Feldern am Volk — nur so Umweiselung **mit Historie** + 4.17-Anschluss. `voelker.koenigin_id` = aktueller Zeiger + BA022-Basis; Historien-Spur wird **ausschliesslich vom RPC** `volk_umweiseln` geschrieben.
- **D-14 · Rasse/Linie an der Königin, nicht am Volk** — die Königin bestimmt die Volksgenetik; nach Umweiselung sonst falsch. `voelker.rasse` (+ `'Buckfast'`-Hardcode) gedroppt.
- **D-15 · Same-Tenant-Integrität via Komposit-FKs** (`unique(betrieb_id,id)` + FK auf `(betrieb_id, fk_id)` mit `on delete set null (spalte)`) — FK-Prüfungen umgehen RLS; einfache FKs hätten Cross-Betrieb-Verknüpfungen (+ Existenz-Orakel + fremder `updated_by`) erlaubt. Bestandslücke `scales.volk_id` mitgehärtet.
- **D-16 · Errcode-Registry:** BA001–BA013 = Auth-Fundament, **BA020+ = Modul 4.2** (BA010/BA012 waren live doppelt belegt). Je Modul ein neuer Zehnerblock; Prüfschritt `grep BA0` vor neuen RPCs.
- **D-17 · Königin↔Volk 1:1 als DB-Garantie** (partieller Unique-Index `voelker(koenigin_id) where … not null`) — BA022 galt vorher nur im RPC, der CRUD-Pfad umging sie.
- **D-18 · Navigation:** „Völker" wird Haupttab (Drehscheibe); „Recherche"/„Entscheidungen" ins „Mehr"-Menü.
- **Gotcha (App):** (1) Neue Daten-Provider MÜSSEN in `AuthController._datenNeuLaden()` invalidiert werden — sonst Fremd-Mandanten-Cache nach Login-Wechsel. (2) Formular-Dropdowns: Stammdaten vor dem Öffnen `await …provider.future` (AsyncNotifier liefert beim ersten `read` noch `AsyncLoading` → leere Dropdowns). (3) PostgREST-Relation-Select nutzt die FK-**Constraint-Namen** (`voelker_koenigin_fk`/`voelker_standort_fk`).

## 2026-07-16 — Auth-Fundament live (Rollout & Cutover)

- **Cutover vollzogen:** Das Fundament ist scharf. `anon` hat **keinen** Zugriff mehr (Policies + Table-Grants entzogen); ab jetzt gilt echte Mandanten-Isolation über die `authenticated`-RLS. Owner = Daniel (`dani.proyer@gmail.com`), Betrieb **„Imkerei-Projekt Arosa"** (`1c84d5dd-…`). App **v1.8.1** live.
- **Erkenntnis (Gotcha, wichtig):** Der Custom-Access-Token-Hook setzt Custom-Claims in die **JWT-Claims**, NICHT in `auth.users.raw_app_meta_data`. Client-seitig MUSS man den Claim aus dem **dekodierten Access-Token** lesen (`jwtPayload()`), nicht aus `session.user.appMetadata`. Sonst „ohneBetrieb"-Dauerschleife. → Regressionstest vorhanden.
- **Erkenntnis:** Ein `betrieb_id`-einfrierender UPDATE-Trigger (`set_row_actor`) und ein Backfill (`UPDATE … WHERE betrieb_id IS NULL`) beißen sich. Lösung: nur einfrieren, wenn bereits gesetzt (`coalesce(old, new)`) — Migration A13.
- **Config-Lehre:** Supabase-**Site URL** ≠ Redirect-Allowlist. Der Bestätigungslink nutzt die Site URL; bleibt sie auf `localhost:3000`, geht der Link ins Leere (die E-Mail wird server-seitig trotzdem bestätigt).
- **Offen/vorgemerkt:** Leaked-Password-Protection aktivieren; Lorena einladen wenn bereit.

## 2026-07-11 — Auth-Fundament & Ausrichtung

- **D-11 · Login = E-Mail + Passwort** (mit Bestätigungs-Mail). *Begründung:* wie KMU Tool 2; E-Mail nur bei Registrierung/Reset nötig → eingebauter Supabase-Mailer reicht, kein Custom-SMTP-Blocker. *Ersetzt* die frühere Magic-Link/OTP-Idee. *Konsequenz:* App-Auth-Schicht spiegelt KMU-`AuthGateway`.
- **D-10 · Fundament an KMU Tool 2 ausrichten** (Muster voll übernehmen). *Begründung:* erprobte, review-gehärtete Blaupause; ein konsistentes Auth-Modell über Daniels Projekte; Wiederverwendung. *Konsequenz:* JWT-Claim-Tenancy (`custom_access_token`-Hook), `betrieb_gruenden`-RPC, code-basierte Einladungen, security-definer-RLS-Helper, Migrations-/Review-Disziplin. Bienen behält eigene Domänennamen (`betriebe`/`betrieb_mitglieder`, owner/editor/viewer).
- **D-9 · Härtung ggü. KMU Tool 2:** DEFINER-Funktionen mit `SET search_path = ''` + volle Qualifizierung (pg_temp-sicher) statt `= public`; `set_row_actor`-Trigger für nicht-fälschbares `created_by/updated_by`. *Konsequenz:* empfohlener Backport nach KMU Tool 2.
- **D-8 · betrieb_id-Strategie:** 6 user-Tabellen mit Default `aktive_betrieb_id()` (JWT-Claim, deterministisch); 2 Sensor-Zeitreihen (`weight_readings`/`scale_alerts`) via `set_betrieb_id_from_scale`-Trigger. *Begründung:* löst Service-Role-Cron-Blocker (2027) + Nichtdeterminismus. *Konsequenz:* Cron crasht nicht an NOT NULL.
- **D-7 · Provisionierung:** nur Daniels owner-Account real (via Registrierung + `betrieb_gruenden` + SQL-Bootstrap); Lorena invite-ready aber nicht aktiviert; Gast/viewer später.
- **Prozess:** Arbeitsschluss-Methode + je eine App-/Projekt-Roadmap eingeführt (aus SBS Projer / KMU Tool 2).

## 2026-07-11 — Scope & Strategie (aus Funktionsumfang-Scope)

- **Ausrichtung: vollwertig ersetzen** — App wird vollständige, CH-/GR-konforme Betriebssoftware inkl. gesetzl. Behandlungsjournal + Bestandeskontrolle.
- **Vorgehen: pragmatischer Mix** — zuerst Auth+Rollen+RLS+Betrieb/Mitglieder, dann sofort Kernmodule mit RLS von Anfang an.
- **Roadmap: max. 8 Völker bis 2030**; Datenmodell/UI auf 32 (evtl. 64) auslegen, keine Hardcaps.
- **Mandantenfähig & vermarktbar** → strikt mehrmandantenfähig über `betriebe`, **keine Arosa-Hardcodes**.
- Backup (auto-Export + Keep-alive) · Datenschutz (Region EU, EXIF-Strip, amtl. Daten nur owner nach 3 J. hart löschbar) · Alerts (Telegram+E-Mail-Fallback) · Feld-Bedienung (Spracheingabe + QR/NFC) · Direktverkauf einplanen (P2) · Bio-Doku ab Volk 1 (Knospe später) · Wanderung vorerst weglassen · Winterfutter-Default 22 kg.

## Frühere App-Entscheide

- **Deploy manuell** via `deploy.sh` (kein Auto-Deploy); Cache-Busting über `main.dart.js?v=<version>` gelöst.

> **Imkerei-Entscheide** (Rasse Buckfast, Lieferanten, Beutensystem, Bau, Fahrplan) stehen jetzt in der Imkerei-Schiene: `../../imkerei/decision-log.md`.
