# 💻 App-Schiene — Bienen Arosa (Flutter Web + Supabase)

Die App bildet die Imkerei ab. Ziel: **vollständige, CH-/GR-konforme, mandantenfähige Imkerei-Betriebssoftware** (spätere Vermarktung möglich → **keine Arosa-Hardcodes**). Gemeinsames Dach + Ablage-Routing + Supabase-Refs stehen in `../CLAUDE.md` (SHARED).

## Fachwissen liegt in der Imkerei-Schiene — dort nachschlagen

Die App braucht Imkerei-Fachwissen, aber es **wohnt in der Imkerei-Schiene** (die Imkerei baut das Wissen auf, die App konsumiert es). Bei fachlichen Features **dort nachschlagen** (Datei-Zugriff ist universell):

- `../imkerei/02_Recherche/` — alpiner Jahresablauf (1570 m), Varroa-Konzept, Dadant, Bienenrassen, Stockwaagen, Honigschleudern, CH-/GR-Recht, Bienenstand-/Schleuderraum-Recherche, Einkaufsliste.
- `../imkerei/03_Bienenstand/` — Bau-Quelldokumente (Bauanleitung, Checkliste, Fotos).
- `../imkerei/roadmap-imkerei.md` — der Betriebs-Fahrplan (welches Modul wann real gebraucht wird).

**Neue fachliche Recherche gehört in die Imkerei-Schiene** (siehe Ablage-Routing im SHARED-Dach) — nicht ins App-Repo. Im Feature nur einen Verweis darauf setzen.

## Lebende Doku (App-Schiene)

| Datei | Zweck |
|---|---|
| `ToDo.md` | App-Status (erledigt/offen/nächster Schritt) |
| `docs/roadmap-app.md` | App-/Software-Roadmap (26 Module, Phasen P1–P4) |
| `docs/decision-log.md` | App-Entscheide (Chronik) |
| `docs/superpowers/specs/` · `plans/` | Brainstorming-Specs & Implementierungs-Pläne |
| Memory (App-Schiene) | Durable App-Fakten (Supabase-Tabellen, Auth-Fundament, Deploy, Gotchas) |

## Konventionen (verbindlich)

- **Sprache:** Deutsch. Bei Unklarheiten nachfragen.
- **Mandantenfähig & keine Arosa-Hardcodes** (Standort/Rasse/E-Mail/Defaults = Daten, nicht Code).
- **Auth-/Mandanten-Muster an KMU Tool 2 ausgerichtet** (JWT-Claim-Tenancy, `betrieb_gruenden`-RPC, code-basierte Einladungen, security-definer-RLS-Helper). Login = **E-Mail + Passwort**. Fundament **live** (siehe Memory).
- **DB-Migrationen (Disziplin aus KMU Tool 2):** nummerierte SQL-Files unter `supabase/migrations/` **und** via Supabase-MCP `apply_migration`; Kopf-Kommentar, stabile errcodes (`BA0xx`), `revoke execute … from anon, public` + `grant … to authenticated`, `SET search_path = ''` + volle Qualifizierung auf DEFINER-Funktionen, Rollback-DO-SQL-Tests, `get_advisors(security)` → 0 neue Findings. Ops-Skripte (Bootstrap/Rollback) unter `supabase/ops/` (kein Migrationsfile).
- **Neue Fach-Tabellen:** immer `betrieb_id uuid NOT NULL` (Default `private.aktive_betrieb_id()`) + `created_by`/`updated_by` + RLS-Muster (SELECT=Mitglied, Schreiben=owner/editor) + `set_row_actor`-Trigger. RLS ist NICHT mehr `public`.
- **Deploy:** MANUELL via `bash deploy.sh` (kein Auto-Deploy). Vorher `version:` bumpen + auf `master` committen. `main.dart.js` wird pro Version cache-gebustet.
- **Tech:** Flutter Web (3.41.x), Riverpod AsyncNotifier (ohne Codegen), Go Router (Hash-Routing), supabase_flutter, fl_chart. Feature-based (`core/`, `features/`, `shared/`).

## Modell-/Aufwandsstrategie & Arbeitsschluss

Siehe SHARED-Dach `../CLAUDE.md`. Kurz: DB/RLS/Mandanten-kritisch → Fable 5 hoch/ultracode; Routine-UI → Opus 4.8 tief. Am Session-Ende die Arbeitsschluss-Methode für die App-Schiene abarbeiten.
