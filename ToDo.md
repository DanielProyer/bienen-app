# ToDo — Bienen Arosa

**Stand:** 2026-07-18 · **Phase:** P1-Fachmodule · **App-Version:** 1.11.0+29 (live)
**Aktueller Fokus:** ✅ **Modul 4.5 „Behandlungen (Varroa/Gesundheit)" LIVE** (v1.11.0) — TAMV-Behandlungsjournal (amtlich, revisionssicher) + Varroa-Milbendiagnose + methodenbewusstes Cockpit, angedockt an die Volk-Detailseite, atomare Lager-Abbuchung. **Nächster Fokus:** (4) **Fütterung 4.6** (Winterfutter-Ziel, Bio-Nachweis) + Monitoring-Ausbau 4.9.

> Lebende Status-Liste der **App-Schiene** (Arbeitsschluss-Methode, siehe `CLAUDE.md` + `../CLAUDE.md`). App-Roadmap: `docs/roadmap-app.md` · App-Entscheide: `docs/decision-log.md` · Specs/Pläne: `docs/superpowers/`. Die **Imkerei-Schiene** (Fachwissen, Fahrplan, Material, Bau) liegt in `../imkerei/`.

---

## ✅ Erledigt — Session 2026-07-18 (Modul 4.5 Behandlungen Varroa/Gesundheit)

- [x] ✓ **Modul 4.5 „Behandlungen (Varroa/Gesundheit)" LIVE** (v1.11.0+29). Brainstorming → Spec v2 → **adversariales Multi-Agent-Review (6 Lupen, 41 Funde → 33 eingearbeitet)** → Plan → subagent-getriebene Umsetzung (3 Buckets) + finaler Code-Review. **flutter analyze sauber, 72/72 Tests** (+19 neue), live.
  - **DB (Produktion, E01/E02):** `varroa_kontrollen` (Milbendiagnose, normale CRUD, CASCADE) + `behandlungen` (**amtliches TAMV-Journal, revisionssicher**) + `materials` `unique(betrieb_id,id)`. RPC `behandlung_erfassen` (einziger Schreibpfad: `distinct` Völker → je eine Zeile, Lager-Abbuchung aus `ROW_COUNT`, `betrieb_id` explizit, BA030–033). Advisor: genau 1 erwartete neue 0029 (RPC), sonst 0.
  - **Revisionssicherheit (Review-Kritik K1, DB-erzwungen ab Eintrag 1):** FK `volk_id` **`ON DELETE RESTRICT`** (Volk mit Journal hart-löschsicher — sonst hätte die `voelker_del_writer`-Policy via CASCADE das Journal umgangen, TAMV Art. 29); **keine INSERT-Policy** (Insert nur via RPC), **keine DELETE-Policy**; BEFORE-UPDATE-Trigger `behandlungen_schutz` (Kernfelder unveränderlich, Einweg-Storno, server-seitiges `storno_am`, BA034); `material_id` **`ON DELETE SET NULL (material_id)`** spaltenqualifiziert.
  - **App:** `lib/features/behandlung/` (Domain: Wirkstoff+Bio-Whitelist, methodenbewusste Ampel [Gemüll=Milben/Tag, Puderzucker=Befall-%], Modelle, Gateway/Fake/Supabase; Provider mit Sammel-Invalidierung ALLER beteiligten Volk-Families + `materialListProvider`). UI: **VarroaCockpit** (fl_chart, Behandlungs-Marker ohne stornierte, Ampel-Chip, Höhen-Caveat), `BehandlungSection` an der Volk-Detailseite, Milbendiagnose- + Behandlungs-Formular (Sammel-Multi-Select, Material-Kopplung, Bio-Warnbanner auf Auswahl, volle TAMV-Felder inkl. Charge/Wartefrist/Aussentemp).
  - **Review-Kernpunkte eingearbeitet:** K1 CASCADE→RESTRICT; RPC-Härtung (distinct/ROW_COUNT/betrieb_id explizit); Thymol = **bio-konform** (nicht „grenzwertig"); methodenbewusste Ampel; Bio-Banner auf Multi-Select-Auswahl; finaler Review: Journal-Ladefehler-Maskierung gefixt, Formular-Vollständigkeit (TAMV-Felder).
  - Docs: `docs/superpowers/specs/2026-07-17-behandlungen-varroa-design.md` (v2), `…/plans/2026-07-18-behandlungen-varroa.md`.

## ✅ Erledigt — Session 2026-07-17 (Modul 4.3 Durchsicht/Stockkarte)

- [x] ✓ **Modul 4.3 „Durchsicht/Stockkarte" LIVE** (v1.10.0+28). Spec → Plan → subagent-getriebene Umsetzung, 4-fach reviewt (Design-Review 25 Findings/14 eingearbeitet + Spec/Qualität je Milestone + holistischer End-Review), 53/53 Tests.
  - **DB (Produktion, D01/D02):** `inspections` (5 Kernfragen W-B-F-P-G + Kontext/Foto, Same-Tenant-Komposit-FK `(betrieb_id,volk_id)→voelker ON DELETE CASCADE`, `auffaelligkeiten <@`-Whitelist inkl. `faulbrut_verdacht`/`sauerbrut_verdacht`), View `v_letzte_durchsichten` (`security_invoker`), **privater** Bucket `inspection-photos` (Signed-URL, `<betrieb_id>/`-Pfad). Advisor sauber.
  - **App:** `lib/features/durchsicht/` (Domain/Gateway/Fake/Provider, geführtes Formular, Timeline in der Volk-Detailseite, Detailansicht mit Foto-Thumbnails). `FotoSpeicher`-Helfer (`lib/core/storage/`). Andocken: „Verlauf"-Sektion → echte Timeline, `VolkCard` → „zuletzt gesehen". Record-only (mutiert `voelker` nicht). Foto-Löschpflicht beim Löschen.
  - Design-Review-Kernpunkte: privater statt public Bucket (Gesundheitsdaten), Foto-Pfade statt URLs, DB-CHECK-Whitelist, `brut_waben`/Faulbrut-Flags, View statt `distinct on`.

## ✅ Erledigt — Session 2026-07-17 (Modul 4.2 Völker & Standorte)

- [x] ✓ **Modul 4.2 „Völker & Standorte" LIVE** (v1.9.0+27). Spec (`docs/superpowers/specs/2026-07-17-…`) → Plan (`…/plans/2026-07-17-…`) → subagent-getriebene Umsetzung, 3-fach reviewt, 45/45 Tests, deployed.
  - **DB (Produktion, C01–C05):** `betriebs_einstellungen` (F4-Keimzelle, `betrieb_gruenden`-Anlage + Backfill), `standorte`, `koeniginnen` (Register + Zuordnungs-Historie), `voelker` erweitert & aufgeräumt (`rasse`/`standort`/`koenigin_jahr` gedroppt, `'Buckfast'`-Hardcode weg), RPC `volk_umweiseln`. Same-Tenant-Komposit-FKs (inkl. `scales.volk_id`-Härtung), Advisor sauber. Ops-Seed Arosa.
  - **App:** `lib/features/voelker/` (Domain/Gateway/Fake/Provider, Völkerliste, Volk-Detailseite als Drehscheibe, Formulare, Umweiseln inkl. weisellos). `Scale.volkId` + `scaleFuerVolkProvider`. Nav-Umbau: „Völker" Haupttab, „Recherche"/„Entscheidungen" ins „Mehr"-Menü. Auth-Cache-Fix (`_datenNeuLaden`).
  - Design-Review (Multi-Agent, 43 Findings/36 eingearbeitet): u. a. Königin↔Volk-Historie, Same-Tenant-FKs, Errcode-Kollision BA020+, `tvd_betriebsnummer` gestrichen (gibt's für Bienen nicht), Rasse an die Königin.

## ✅ Erledigt — Session 2026-07-11 (Auth-Fundament-Planung)

- [x] ✓ **Scope finalisiert** — alle 8 offenen Fragen beantwortet; strategische Weichen (vollwertig ersetzen · pragmatischer Mix · max 8 bis 2030 · strikt mandantenfähig/keine Arosa-Hardcodes). Spec: `docs/superpowers/specs/2026-07-11-app-funktionsumfang-scope.md` (commit `0b5d03a`).
- [x] ✓ **Auth-Fundament-Spec** (freigegeben) — `docs/superpowers/specs/2026-07-11-auth-fundament-design.md` (commit `a399426`). E-Mail+Passwort-Login, JWT-Claim-Tenancy, code-basierte Einladungen, RLS-Härtung, betrieb_id-Migration der 8 Bestandstabellen, gestufter ausfallfreier Rollout.
- [x] ✓ **An KMU Tool 2 ausgerichtet** — Login von Magic-Link/OTP → **E-Mail+Passwort** geändert (löst SMTP-Blocker); Muster (betrieb_gruenden-RPC, JWT-Claim-Auth-Hook, RLS-Recursion-Helper, Migrations-/Review-Disziplin) 1:1 übernommen, auf Bienen-Domäne gemappt.
- [x] ✓ **Adversariales Design-Review** (Multi-Agent, ultracode) — 52 bestätigte Findings (10 Blocker), alle in die Spec eingearbeitet.
- [x] ✓ **Plan 1 (DB-Fundament, Migration A)** — `docs/superpowers/plans/2026-07-11-auth-fundament-1-db.md` (commit `2ccb22d`). 11 additive, nicht-brechende Migrationen (A01–A11) je mit Rollback-DO-Test + Advisor-Gate. **Adversarialer SQL-Review** gegen die Live-Schema (3 Test-/Härtungs-Bugs gefunden & gefixt).
- [x] ✓ **Arbeitsschluss-Infrastruktur** angelegt (2026-07-11), **2026-07-16 in zwei Schienen getrennt** — SHARED-Dach `../CLAUDE.md` + `bienen_app/CLAUDE.md` (App) + `../imkerei/CLAUDE.md` (Imkerei); je eigene ToDo/Roadmap/Decision-Log/Memory.

---

- [x] ✓ **Plan 1 (DB-Fundament) AUSGEFÜHRT** (2026-07-11, Produktions-DB `dcdcohktxbhdxnxjvcyp`) — Migrationen **A01–A12** deployed, jede mit Rollback-DO-Test + Advisor-Gate:
  - A01 `private`-Schema/pgcrypto/`current_app_user` · A02 enum + `betriebe`/`profiles`/`betrieb_mitglieder`/`einladungen` · A03 security-definer-RLS-Helper (rekursionsfrei verifiziert)
  - A04 `handle_new_auth_user` (nur Profil) · A05 `custom_access_token`-Auth-Hook (betrieb_id/rolle-Claim) · A06 RPCs (`betrieb_gruenden`, Einladungen, `team_mitglieder`, `enforce_last_owner`) · A07 Tenancy-RLS
  - A08 `betrieb_id`/`created_by`/`updated_by` + Trigger auf den 8 Tabellen · A09 additive `authenticated`-Policies · A10 Storage (`<betrieb_id>/`-Pfad) · A11 `update_updated_at` gehärtet
  - **A12 (Zusatz aus dem Advisor-Gate):** `handle_new_auth_user` von anon/authenticated entzogen (war per Default-Grant als RPC exponiert).
  - **Verifiziert:** Mandanten-Isolation greift (Fremd-Insert/-Select blockiert) · Doppelgründung + letzter-Owner (Degradierung **und** Soft-Delete) werfen BA0xx · `created_by`/`betrieb_id` nicht fälschbar · **Live-App unverändert** (anon sieht weiterhin alle 52 materials) · Advisor: `function_search_path_mutable`/`rls_enabled_no_policy`/0028 = **0**.
  - Commits `306259b`, `5306aa1`, `39321c6`.

- [x] ✓ **Plan 2 (App-Auth-Schicht) UMGESETZT** (2026-07-11) — `docs/superpowers/plans/2026-07-11-auth-fundament-2-app.md`, alle 10 Aufgaben. **analyze sauber, 34/34 Tests grün** (vorher: 2 Analyzer-Fehler + 1 roter Test im Repo).
  - `features/auth/`: Domain (`Rolle`/`AuthSession`/`AuthGateway` mit `Angemeldet`/`OhneBetrieb`/`KeineSession`) · `AuthStatus`-Gate · `SupabaseAuthGateway` (liest `betrieb_id`/`rolle` aus dem JWT-Claim, mappt BA0xx+AuthException auf Klartext) · `FakeAuthGateway` (Tests ohne Netz) · `AuthController` (refreshSession nach Gründung/Einladung, Daten-Provider-Invalidierung).
  - Screens: Login · Registrieren · Mail-bestätigen · Onboarding (`betrieb_gruenden`) · Einladungs-Code · Konto (Rolle, Logout, Einladen mit **einmalig** sichtbarem Code). Konto-Einstieg in der Dashboard-AppBar.
  - Router-Gate: `laden`→Splash (navigiert bewusst nicht), `abgemeldet`→/login, `ohneBetrieb`→/onboarding.
  - Härtungen: `materials`-Auto-Seed **entfernt** (hätte jedem Mandanten Arosa-Daten untergeschoben) · stille `catch`→Seed/`[]`-Fallbacks entfernt (maskierten RLS-/Auth-Fehler) · tote Arosa-`_seedData` gelöscht · `<betrieb_id>/`-Storage-Pfade · `index.html`-Auth-Callback-Guard.
  - Vorab-Fix: veralteter `construction_progress_test` repariert (`progressFor` public, testet jetzt die Bereichs-Trennung).
  - Commits `f641530`, `d990012`, `5a4e…`, `1e7…`, gepusht.

- [x] ✓ **Plan 3 (Rollout & Cutover) UMGESETZT** (2026-07-16) — `docs/superpowers/plans/2026-07-11-auth-fundament-3-rollout.md`. Auth-Hook aktiviert, Release **v1.8.0→1.8.1**, Owner-Account + Betrieb, Bootstrap (227 Zeilen), Test-Gate, Cutover B01+B02. **Live-verifiziert** (Material/Bau/Waage/Logout-Login funktionieren). Details unten.
  - **2 Live-Bugs gefunden & gefixt** (nur real gegen die Prod-App sichtbar): (a) `betrieb_id`-Claim wurde aus `user.appMetadata` statt aus dem JWT gelesen → App hing in „ohneBetrieb" (`v1.8.1`, `jwtPayload()` + Regressionstest). (b) `set_row_actor` fror `betrieb_id` bei JEDEM UPDATE ein → Bootstrap-Backfill wirkungslos (`A13`, coalesce).
  - **Config-Stolperstein:** Site URL stand auf `localhost:3000` → Bestätigungslink ging ins Leere (E-Mail wurde trotzdem server-seitig bestätigt). Behoben.
  - Advisor: alle `rls_policy_always_true` + `public_bucket_allows_listing` weg; keine `rls_initplan`-Warnung. Rollback-Netz: `supabase/ops/rollback-public-policies.sql`.

## 🔴 OFFEN — als Nächstes
- [ ] **🟡 P1-Fachmodul (4): Fütterung 4.6** — Spec → Plan → Umsetzung. Winterfutter-Ziel (Default 22 kg), Bio-Nachweis; koppelt an Material-Verbrauch (wie 4.5). Danach Monitoring-Ausbau 4.9.
- [ ] **🟢 Leaked-Password-Protection aktivieren** — Dashboard → Authentication → Password Security (Advisor-Empfehlung, gerade bei Passwort-Login sinnvoll). Klein.
- [ ] **🟡 Lorena einladen**, wann Daniel bereit ist — Konto → „Mitglied einladen" (E-Mail + Rolle editor) → Code an Lorena. Mechanismus fertig & getestet, aktuell 0 offene Einladungen.
- [ ] **🟢 Module 4.2 + 4.3 + 4.5 im Browser klick-testen** (Deploy-Preview war headless nicht renderbar): 4.2 (Volk/Königin/Umweiseln/Standort/Nav „Mehr"), 4.3 (Durchsicht → Timeline, Foto → Thumbnail, „zuletzt gesehen", Löschen), **4.5 (Milbendiagnose → Cockpit-Kurve/Ampel-Chip; Behandlung erfassen → Liste + Lager sinkt; Storno → durchgestrichen; Bio-Warnbanner)**. Bei Auffälligkeiten melden.

## 🔵 Danach (P1-Fachmodule, Reihenfolge laut Roadmap)

Völker & Standorte → Durchsicht/Stockkarte → Behandlungen+Varroa → Fütterung + Monitoring-Ausbau → Kosten-Dashboard (Quick-Win) → Volk-Ausfall + Wachs-Basis + Kontakt-Hub → Karten-/Wetter-Basis → Wissensdatenbank (iterativ). Details: `docs/roadmap-app.md`.

## Backlog / offene Punkte (aus Memory/Scope)

- [ ] Honigverarbeitungs-Inhalt in der App mit Daniel konkretisieren (Richtwerte → real), spätestens Frühling 2027 (`memory/todo-honigverarbeitung-review-fruehling-2027.md`).
- [ ] 4 Schutz-Platzhalter im Material (gekauft) — Produkt/Details von Daniel nachtragen.
