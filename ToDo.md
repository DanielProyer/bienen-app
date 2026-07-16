# ToDo — Bienen Arosa

**Stand:** 2026-07-16 · **Phase:** P1-Fundament ✅ abgeschlossen · **App-Version:** 1.8.1+26 (live)
**Aktueller Fokus:** ✅ **Auth-&-Rollen-Fundament KOMPLETT & LIVE** (Plan 1+2+3). Echte Mandanten-Isolation aktiv, `anon` ausgesperrt; Daniel = Owner von „Imkerei-Projekt Arosa". **Nächster Fokus: P1-Fachmodule** → (1) Völker & Standorte.

> Lebende Status-Liste der **App-Schiene** (Arbeitsschluss-Methode, siehe `CLAUDE.md` + `../CLAUDE.md`). App-Roadmap: `docs/roadmap-app.md` · App-Entscheide: `docs/decision-log.md` · Specs/Pläne: `docs/superpowers/`. Die **Imkerei-Schiene** (Fachwissen, Fahrplan, Material, Bau) liegt in `../imkerei/`.

---

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
- [ ] **🟢 Leaked-Password-Protection aktivieren** — Dashboard → Authentication → Password Security (Advisor-Empfehlung, gerade bei Passwort-Login sinnvoll). Klein.
- [ ] **🟡 Lorena einladen**, wann Daniel bereit ist — Konto → „Mitglied einladen" (E-Mail + Rolle editor) → Code an Lorena. Mechanismus fertig & getestet, aktuell 0 offene Einladungen.
- [ ] **🟡 P1-Fachmodul (1): Völker & Standorte** — Spec → Plan → Umsetzung (nach dem bewährten Muster). Erstes echtes Fachmodul auf dem Fundament.

## 🔵 Danach (P1-Fachmodule, Reihenfolge laut Roadmap)

Völker & Standorte → Durchsicht/Stockkarte → Behandlungen+Varroa → Fütterung + Monitoring-Ausbau → Kosten-Dashboard (Quick-Win) → Volk-Ausfall + Wachs-Basis + Kontakt-Hub → Karten-/Wetter-Basis → Wissensdatenbank (iterativ). Details: `docs/roadmap-app.md`.

## Backlog / offene Punkte (aus Memory/Scope)

- [ ] Honigverarbeitungs-Inhalt in der App mit Daniel konkretisieren (Richtwerte → real), spätestens Frühling 2027 (`memory/todo-honigverarbeitung-review-fruehling-2027.md`).
- [ ] 4 Schutz-Platzhalter im Material (gekauft) — Produkt/Details von Daniel nachtragen.
