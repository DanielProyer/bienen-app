# Decision-Log — Bienen Arosa

Chronik getroffener Entscheide (neueste zuerst). Format: **Datum — Entscheid** · Begründung · Konsequenz. Nachgeführt bei Arbeitsschluss.

---

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

## Frühere Entscheide (aus Memory, 2026-07-11 festgehalten)

- **Rasse: Buckfast** (via Tino Hassler, Maladers).
- **Lieferanten:** Imkerhof Maienfeld (Material) + HiveWatch (Stockwaage). Material-Präferenz: **Qualität & Langlebigkeit vor Preis**.
- **Beutensystem:** Dadant Blatt 10er in Holz.
- **Deploy manuell** via `deploy.sh` (kein Auto-Deploy); Cache-Busting gelöst.
- **Bau-Entscheid:** durchgehende 2,8-m-Doppelbalken (statt gestückelt) — strukturell besser.
