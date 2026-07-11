# Design-Spec: Auth-&-Rollen-Fundament (mandantenfähig)

**Datum:** 2026-07-11 · **Status:** Entwurf (zur Freigabe durch Daniel) · **Phase:** P1-Fundament
**Grundlage:** [Funktionsumfang-Scope](2026-07-11-app-funktionsumfang-scope.md) §2 + Fundament-Module · adversariales Review (52 bestätigte Findings) · **Blaupause KMU Tool 2** (Schwesterprojekt, Migrationen 0001–0025, im Review gehärtet).

---

## 1. Ziel & Abgrenzung

**Ziel:** Das Sicherheits-/Mandanten-Fundament der Bienen-App bauen: **Auth (E-Mail+Passwort)**, **Rollen owner/editor/viewer**, **RLS-Härtung**, `betriebe`/`betrieb_mitglieder`, **Einladungsmechanismus** und **Migration der 8 Bestandstabellen auf `betrieb_id`** — strikt mandantenfähig, keine Arosa-Hardcodes. Nur Daniels Owner-Account wird real provisioniert; Lorena ist *invite-ready* (Mechanismus fertig, aber nicht aktiviert); Gast/viewer kommt später.

**Leitentscheidung (mit Daniel, 2026-07-11):** Das Fundament wird **1:1 an die erprobten, review-gehärteten Muster von KMU Tool 2** angelehnt (JWT-Claim-Tenancy, `betrieb_gruenden`-RPC, code-basierte Einladungen, security-definer-RLS-Helper, Migrations-/Review-Disziplin). Das gibt **ein konsistentes Auth-Modell über Daniels Projekte** und erlaubt Muster-/SQL-Wiederverwendung. Bienen behält seine **Domänennamen** (`betriebe`, `betrieb_mitglieder`, Rollen owner/editor/viewer) — nur die *Muster* kommen aus KMU Tool 2.

**Login-Art (mit Daniel, 2026-07-11):** **E-Mail + Passwort mit Bestätigungs-Mail** (wie KMU Tool 2). Damit wird E-Mail **nur bei Registrierung + Passwort-Reset** gebraucht, nicht bei jedem Login → der eingebaute Supabase-Mailer (2 Mails/h) reicht, **kein Custom-SMTP nötig**. (Die frühere Magic-Link/OTP-Idee ist damit verworfen; sie hätte zwingend Custom-SMTP + einen `index.html`-Token-Fix gebraucht.)

### Bewusst NICHT in diesem Task (bleibt Folge-Specs)
Backup/Restore (F1) · Soft-Delete/Aufbewahrung/EXIF-Stripping (F2) · Benachrichtigungs-Engine (F3) · Settings-UI (F4) · vollständiger Onboarding-Assistent (F5, über die minimale Gründung hinaus) · MFA/aal2/Reauth (KMU Tool 2 hat es in 0013; Bienen vertagt) · viewer-Aktivierung · volles Audit-Log · **Storno-Prinzip/Soft-Delete auf den 8 Fachtabellen** (Bienen behält vorerst die bestehenden Hard-Deletes; is_deleted nur auf den Tenancy-Tabellen, wo die Helper es brauchen).

---

## 2. Ausgangszustand (verifiziert am Live-Projekt `dcdcohktxbhdxnxjvcyp`)

- Region `eu-west-1` (EU), Postgres 17.6, Status ACTIVE_HEALTHY.
- **8 Tabellen, alle RLS-enabled, aber nur `public`-Policies (`qual/with_check = true`)** → jeder mit dem Anon-Key kann lesen/schreiben/löschen. Das ist die zu schließende Lücke.
- Bestandsdaten (nicht an `74` orientieren — Review-Finding): `materials` 52, `construction_steps` 22, sowie **Demo-Sensordaten** `weight_readings` ~151, `scales` ~1, `scale_alerts` ~1. Backfill daher strikt über `WHERE betrieb_id IS NULL`.
- Storage: 3 **public** Buckets (`construction-photos`, `material-media`, `material-receipts`), Schreiben ebenfalls `public`; App zeigt Fotos über **public URLs** (Spaltenwert).
- App heute: **kein Auth**, direkte Anon-Queries; Provider fallen bei Fehler auf lokale Seed-Daten zurück; `materials`-Provider **seedet die DB automatisch, falls leer** (muss weg — Mandanten-Leck).
- Edge Function `sync-scale-data` (Cron, **noch nicht deployed**, HiveWatch-Hardware 2027) schreibt künftig `weight_readings`/`scale_alerts` mit dem **Service-Role-Key** (bypasst RLS, **kein `auth.uid()`**).

---

## 3. Architektur (Muster aus KMU Tool 2, auf Bienen-Domäne gemappt)

### 3.1 Namens-Mapping

| KMU Tool 2 | Bienen | Zweck |
|---|---|---|
| `tenants` | `betriebe` | Mandanten-Klammer |
| `app_users` | `profiles` | Spiegel von `auth.users` (id = auth.users.id, email) |
| `memberships` | `betrieb_mitglieder` | (betrieb_id, user_id) + rolle + is_deleted |
| `app_role` | `betrieb_rolle` | Enum **owner / editor / viewer** |
| `einladungen` | `einladungen` | Code-basierte Einladung (nur Hash gespeichert) |
| `current_app_user()` | `current_app_user()` | Session-User (GUC + `auth.uid()`-Fallback) |
| `current_tenant_ids()` | `meine_betrieb_ids()` | setof uuid, security-definer (bricht RLS-Rekursion) |
| `custom_access_token` | `custom_access_token` | Auth-Hook: `app_metadata.betrieb_id` + `.rolle` in den JWT |
| `betrieb_gruenden` | `betrieb_gruenden` | atomare Selbst-Gründung Betrieb+Owner-Mitgliedschaft |
| `mitglied_einladen`/`einladung_annehmen`/`einladung_widerrufen` | gleich | Einladungs-RPCs |

### 3.2 Rollenmodell

| Rolle | Rechte |
|---|---|
| **owner** | alles + Mitglieder einladen/entfernen/Rollen ändern, Betrieb-Stammdaten | (KMU-Analog: `geschaeftsfuehrer`) |
| **editor** | alle Fachdaten anlegen/ändern/löschen; **keine** Mitgliederverwaltung |
| **viewer** | nur lesen (ab 2027 aktiviert) |

`private.kann_schreiben(betrieb_id)` = `rolle_im_betrieb(betrieb_id) in ('owner','editor')`.

### 3.3 Tenant-Kontext über JWT-Claim (Kernmuster)

Der **aktive Betrieb** eines Nutzers steht als servergesetzter Claim `app_metadata.betrieb_id` (+ `app_metadata.rolle`) im JWT — gesetzt vom **Custom-Access-Token-Hook** (Muster KMU Tool 2 0011/0013). Vorteile:

- **Performant:** RLS/Defaults lesen den Claim (oder `meine_betrieb_ids()` einmal pro Query als Set), keine Pro-Zeile-Mitgliedschafts-Subqueries (Review-Finding „RLS-Performance").
- **Deterministisch:** Der Hook wählt `order by created_at limit 1` (älteste Mitgliedschaft) — löst die „`current_betrieb_id()` nicht-deterministisch"-Findings.
- **Mandantenfähig:** Ein späterer Betriebs-Umschalter setzt einfach einen anderen aktiven Betrieb; das Fundament ist darauf ausgelegt.

**App-Kopplung:** Nach `betrieb_gruenden`/`einladung_annehmen` ruft die App `refreshSession()` → neuer JWT trägt den Claim → `AuthStatus` wechselt auf `angemeldet`.

---

## 4. Datenmodell

Alle neuen Tabellen: `id uuid pk default gen_random_uuid()`, `created_at`, `updated_at` (+ `set_updated_at`-Trigger), Tenancy-Tabellen zusätzlich `is_deleted boolean not null default false`.

### 4.1 Tenancy (Migration A)

```
create type betrieb_rolle as enum ('owner','editor','viewer');

betriebe            (id, name, created_at, updated_at, is_deleted)
profiles            (id = auth.users.id, email, display_name, created_at, updated_at)
betrieb_mitglieder  (id, betrieb_id fk→betriebe on delete cascade,
                     user_id fk→profiles on delete cascade,
                     rolle betrieb_rolle, created_at, updated_at, is_deleted,
                     unique(betrieb_id,user_id))
                     + index(betrieb_id), index(user_id)
einladungen         (id, betrieb_id fk→betriebe on delete cascade,
                     email text, rolle betrieb_rolle, code_hash text,
                     status text default 'offen' check in (offen|angenommen|widerrufen),
                     ablauf_am timestamptz default now()+interval '7 days',
                     eingeladen_von uuid, angenommen_von uuid, created_at, updated_at)
                     + unique index(code_hash)
                     + PARTIAL unique index(betrieb_id, lower(email)) where status='offen'
```

`einladungen.email` wird beim Anlegen **`lower(trim(...))`** normalisiert (Case-Insensitivität — Review-Finding). Es wird **nur der SHA-256-Hash** des 12-Zeichen-Codes gespeichert (Crockford-Base32, Format `XXXX-XXXX-XXXX`), Klartext nur einmalig aus dem RPC zurück.

### 4.2 Migration der 8 Bestandstabellen (Migration A, additiv)

Jede der 8 Tabellen (`materials`, `material_purchases`, `weight_readings`, `scales`, `scale_alerts`, `funkstationen`, `voelker`, `construction_steps`) erhält:

- `betrieb_id uuid` — **zunächst NULLABLE, ohne Default** (Default/NOT NULL erst im Bootstrap, §7.3) + Index.
- `created_by uuid`, `updated_by uuid` (NULLABLE — Service-Role-Writes ohne User).
- Werte werden **serverseitig per Trigger** gesetzt (nicht per DEFAULT, nicht Client-vertrauend — Review-Finding „created_by spoofbar").

**`betrieb_id`-Herkunft (finale Strategie, löst 3 Review-Blocker):**

- **6 user-getriebene Tabellen** (`materials`, `material_purchases`, `voelker`, `scales`, `funkstationen`, `construction_steps`): Default `private.aktive_betrieb_id()` **aus dem JWT-Claim** (deterministisch, kein Membership-LIMIT-1). Die App *kann* `betrieb_id` explizit mitgeben (empfohlen, macht späteren Betriebs-Wechsel trivial), muss es aber für die Bestandsinserts nicht → minimale App-Änderung.
- **2 maschinelle Zeitreihen** (`weight_readings`, `scale_alerts`): **KEIN** Default. Stattdessen `private.set_betrieb_id_from_scale()` **BEFORE INSERT**-Trigger, der `betrieb_id` aus `scale_id → scales.betrieb_id` ableitet (bei `scale_alerts` mit nullbarer `scale_id`: Fallback über `weight_reading_id`, sonst `RAISE EXCEPTION`). → funktioniert für den **Service-Role-Cron ohne `auth.uid()`** und schließt den 2027-Blocker strukturell.

---

## 5. Funktionen, Auth-Hook & RPCs (security-definer, gehärtet)

**Härtungs-Konvention (Bienen härtet ggü. KMU Tool 2 nach — Review-Finding #1):** Jede `SECURITY DEFINER`-Funktion bekommt **`SET search_path = ''`** (leer) **und voll schema-qualifizierte Objektnamen** (`public.betrieb_mitglieder`, `auth.uid()`, `'owner'::public.betrieb_rolle` …). Das ist pg_temp-sicher (KMU Tool 2 nutzt `= public`, was den pg_temp-Vektor offen lässt) und advisor-clean. → als Backport für KMU Tool 2 empfohlen (siehe §10).

### 5.1 Basis-Helper

- `private.current_app_user() → uuid` (STABLE): `coalesce(nullif(current_setting('app.current_user_id', true),'')::uuid, auth.uid())` — provider-agnostisch + **in SQL-Rollback-Tests simulierbar** (GUC setzen).
- `private.meine_betrieb_ids() → setof uuid` (**SECURITY DEFINER**, STABLE): `select betrieb_id from public.betrieb_mitglieder where user_id = private.current_app_user() and is_deleted = false`. Bricht die RLS-Rekursion (definer umgeht RLS auf `betrieb_mitglieder`).
- `private.aktive_betrieb_id() → uuid` (STABLE): liest `app_metadata.betrieb_id` aus `auth.jwt()`. Quelle des `betrieb_id`-Defaults.
- `private.rolle_im_betrieb(b_id uuid) → betrieb_rolle`, `private.ist_mitglied(b_id) → bool`, `private.kann_schreiben(b_id) → bool` (owner|editor), `private.teilt_betrieb(other_user uuid) → bool` — alle SECURITY DEFINER `set search_path=''`.
- **Grants:** `grant usage on schema private to authenticated`; pro Helper `revoke all … from public, anon; grant execute … to authenticated`. (private-Schema NICHT in PostgREST exposen.)

### 5.2 Trigger

- `public.handle_new_auth_user()` (DEFINER, on `auth.users` insert): legt **nur** `profiles`-Zeile an (`on conflict (id) do nothing`). **Kein Invitation-Claim hier** (entkoppelt — Review-Blocker), keine sonstige Logik → kann Login/Signup nie mit „Database error saving new user" blockieren.
- `private.set_row_actor()` (BEFORE INSERT/UPDATE, alle 8 Tabellen): erzwingt `created_by`/`updated_by = current_app_user()`, hält `created_by`/`created_at`/`betrieb_id` bei UPDATE **immutabel** (Review-Findings „created_by spoofbar", „betrieb_id auf UPDATE nicht eingefroren"). Setzt `updated_at = now()`.
- `private.set_betrieb_id_from_scale()` (BEFORE INSERT, `weight_readings`+`scale_alerts`): §4.2.
- `private.enforce_last_owner()` (BEFORE UPDATE/DELETE, `betrieb_mitglieder`): verhindert Entfernen/Degradieren des **letzten owners**, mit Cascade-Ausnahme (Review-Finding). *(low, defense-in-depth)*

### 5.3 Auth-Hook (JWT-Claim)

`public.custom_access_token(event jsonb) → jsonb` (Muster KMU 0011/0013): liest `betrieb_id + rolle` der ältesten Mitgliedschaft (`order by created_at limit 1`, `is_deleted=false`) und setzt `app_metadata.betrieb_id` + `app_metadata.rolle`. `jsonb_typeof`-Guard für `app_metadata`. **Grants:** nur `supabase_auth_admin` (execute + `grant usage on schema public` + `select on betrieb_mitglieder` + eine `betrieb_mitglieder`-select-Policy für `supabase_auth_admin`, weil diese Rolle **kein bypassrls** hat). Von `authenticated/anon/public` revoked.
**Config-Schritt:** Hook im Dashboard unter *Auth → Hooks → Custom Access Token* auf `public.custom_access_token` zeigen lassen (§8).

### 5.4 RPCs (DEFINER, stabile errcodes `BA0xx`, `revoke anon/public` + `grant authenticated`)

- `public.betrieb_gruenden(p_name text) → uuid`: Guards (BA001 nicht angemeldet, BA002 Name leer, BA003 bereits Mitglied), **advisory-xact-lock** (`'betrieb_gruenden:'||uid`) gegen Doppel-Tap, atomar `betriebe` → `betrieb_mitglieder(owner)`. (KMU-Muster 0012.)
- `public.mitglied_einladen(p_email text, p_rolle betrieb_rolle) → text`: nur **owner** (Guard-Helper `eigener_betrieb_als_owner()`), normalisiert E-Mail, ersetzt bestehende offene Einladung, erzeugt Code, speichert Hash, gibt Klartext einmalig zurück. (KMU-Muster 0013; **ohne** den MFA/Reauth-Guard.)
- `public.einladung_annehmen(p_code text)`: DEFINER (Aufrufer ist noch membership-los → RLS würde blocken). Normalisiert+hasht Code, prüft `status='offen'` + nicht abgelaufen + **`einladung.email = auth.email()`** (Eigentumsnachweis), **gleicher advisory-lock** wie `betrieb_gruenden` (Ein-Betrieb-Invariante über Kreuz), atomarer `offen→angenommen`-Übergang, `insert betrieb_mitglieder`.
- `public.einladung_widerrufen(p_id uuid)`: nur owner.
- `public.team_mitglieder() → table(user_id,email,rolle,created_at)`: DEFINER, jedes Mitglied sieht sein Team.

---

## 6. RLS-Policies

**Muster (KMU 0005), `TO authenticated`, `(select auth.uid())`/Set-Form:**

### 6.1 Die 8 Fachtabellen
- **SELECT:** `using (betrieb_id in (select private.meine_betrieb_ids()))` — Set-Form, einmal materialisiert (performant auf `weight_readings`).
- **INSERT:** `with check (private.kann_schreiben(betrieb_id))` (owner|editor).
- **UPDATE:** `using (private.kann_schreiben(betrieb_id)) with check (private.kann_schreiben(betrieb_id))` (WITH CHECK zwingend; `betrieb_id`-Immutabilität zusätzlich per `set_row_actor`-Trigger).
- **DELETE:** `using (private.kann_schreiben(betrieb_id))` — Bienen behält vorerst Hard-Delete (App hat Lösch-Funktionen; volles Storno = F2).
- Index auf `betrieb_id` je Tabelle.

### 6.2 Tenancy-Tabellen
- `betriebe`: SELECT `id in (select meine_betrieb_ids())`; UPDATE nur owner; **kein** INSERT/DELETE für `authenticated` (nur via `betrieb_gruenden`-DEFINER — Review-Blocker „Selbst-Insert").
- `betrieb_mitglieder`: SELECT `betrieb_id in (select meine_betrieb_ids())`; **kein** direktes INSERT für `authenticated`; UPDATE/DELETE **nur owner** (USING+WITH CHECK `rolle_im_betrieb='owner'`, nie `kann_schreiben` → sonst Self-Escalation). Alle legitimen Inserts laufen über DEFINER-RPCs.
- `profiles`: SELECT `id = (select auth.uid()) or private.teilt_betrieb(id)` (kein world-weites E-Mail-Harvesting — Review-Finding); UPDATE nur eigene Zeile; kein Client-INSERT/DELETE (nur `handle_new_auth_user`). `email` immutabel via Spalten-Grant (`grant update(display_name)`).
- `einladungen`: SELECT nur owner des Betriebs; **kein** INSERT/UPDATE/DELETE für `authenticated` (nur DEFINER-RPCs).

### 6.3 Storage (3 Buckets)
- **Migration A (additiv):** `TO authenticated` Write-Policies (INSERT/UPDATE, `material-media` zusätzlich DELETE) je Bucket, die die heutigen public-Rechte spiegeln, mit **Pfad-Scoping** `(storage.foldername(name))[1]::uuid` + `private.kann_schreiben(...)`. **Pfadkonvention `<betrieb_id>/…` ab jetzt** (Review-Finding: heute `<id>.jpg`/statische `stepKey.jpg` → Cross-Tenant-Kollision). App-Upload-Pfade (construction/material/receipts) mit `betrieb_id` präfixen.
- **SELECT/Listing:** öffentliche Listing-Policy je Bucket durch `TO authenticated`-SELECT ersetzen (behebt Advisor „Public Bucket Allows Listing", erhält `upsert`-Overwrite); **Downloads bleiben** über public URL (Foto-Anzeige unberührt).
- **Cutover (Migration B):** public-Write-Policies droppen.
- Private Buckets + signed URLs (v.a. `material-receipts` = Finanzbelege) = **F2**, bewusst dokumentierte Schuld.

---

## 7. Gestufter, ausfallfreier Rollout

Grundannahme verifiziert: Rolle `public` schließt `authenticated` ein, mehrere PERMISSIVE-Policies je Kommando werden **ge-OR-t** → strikte Policies **zusätzlich** zu den public-Policies brechen nichts, bis die public-Policies gedroppt werden.

### 7.1 Migration A — Schema & Policies (additiv, nicht brechend)
Enum, Tenancy-Tabellen, `einladungen`, alle Helper/Trigger/Auth-Hook/RPCs, `betrieb_id`(nullable)/`created_by`/`updated_by` + Trigger auf den 8 Tabellen, **neue authenticated-RLS-Policies zusätzlich zu den bestehenden public-Policies**, additive Storage-Write-Policies. **Keine** E-Mail, **keine** uid, **kein** Betrieb, **kein** Backfill hier (reproduzierbar/CI-fähig, mandantenfähig — Review-Finding „E-Mail nicht in Migration hardcoden").

### 7.2 App-Release (E-Mail+Passwort-Auth)
Login-Gate deployen (§9). Danach: **Daniel registriert sich** (E-Mail+Passwort) → bestätigt E-Mail → loggt sich ein → `AuthStatus.ohneBetrieb` → `/onboarding` → **`betrieb_gruenden('Imkerei Arosa')`** → owner-Mitgliedschaft → `refreshSession()` (JWT trägt jetzt `betrieb_id`-Claim).

### 7.3 Bootstrap (einmaliges, idempotentes Ops-Skript — KEIN Migrationsfile)
Nach Daniels Gründung, in **einer Transaktion pro Tabelle mit `LOCK … ACCESS EXCLUSIVE`** (schließt das Insert-Race — Review-Finding):
```
-- pro Tabelle t (alle 8):
lock table public.t in access exclusive mode;
update public.t set betrieb_id = :arosa_id where betrieb_id is null;   -- IS NULL, nicht "74"
alter table public.t alter column betrieb_id set default private.aktive_betrieb_id();  -- (6 user-Tabellen)
alter table public.t alter column betrieb_id set not null;
```
`:arosa_id` = die von `betrieb_gruenden` erzeugte Betrieb-UUID (bzw. per `select id from betriebe where name='Imkerei Arosa'`). Vorher-Assertion: `select count(*) … where betrieb_id is null` muss 0 sein. **`materials`-Auto-Seed vorher aus dem Code entfernen** (sonst schreibt jeder leere Mandant Arosa-Daten). Bestehende Storage-Objekte optional nach `<arosa_id>/…` umziehen + `*_url`-Spalten nachziehen (oder Alt-URLs public lesbar lassen, neue Uploads scoped).

### 7.4 Cutover (Migration B — brechend, nach Test-Gate)
**Pflicht-Test VOR dem Drop** (Review-Finding „Cutover kann Daniel aussperren"): in einer Transaktion die `authenticated`-Rolle simulieren und Lese-/Schreibpfad prüfen, dann `rollback`:
```
begin; set local role authenticated;
set local request.jwt.claims = '{"sub":"<DANIEL_UUID>","role":"authenticated","app_metadata":{"betrieb_id":"<AROSA_UUID>","rolle":"owner"}}';
select private.aktive_betrieb_id(), private.ist_mitglied(private.aktive_betrieb_id()), private.kann_schreiben(private.aktive_betrieb_id());
-- SELECT-Counts aller 8 Tabellen == Gesamtzeilen; Probe-INSERT je Kern-Tabelle; rollback;
```
Freigabekriterium erfüllt → dann: **public-Policies der 8 Tabellen + public-Storage-Write-Policies droppen**; zusätzlich **`revoke insert/update/delete on public.<8 tables> from anon`** (Defense-in-Depth — Review-Finding). Rollback-Skript (die public-`create policy`-Statements) bereithalten. Ein echter DB-Lockout ist unmöglich (Dashboard/service_role umgehen RLS), betroffen wäre nur die App.

---

## 8. Supabase-Dashboard-Konfiguration (Config-Checkliste, kein Migrations-Artefakt)

1. **Custom Access Token Hook** aktivieren → `public.custom_access_token` (sonst kein `betrieb_id`-Claim → App sieht nichts).
2. **Auth → Providers → Email:** „Confirm email" **an** (Bestätigungs-Mail). Passwort-Mindestlänge/Policy setzen.
3. **Site URL / Redirect URLs:** `https://danielproyer.github.io/bienen-app/` (exakt, mit Trailing Slash) + Wildcard `…/bienen-app/**` — für den Bestätigungs-/Reset-Link-Rücksprung.
4. Eingebauter Mailer genügt (E-Mail nur bei Registrierung/Reset). *(Custom-SMTP später optional, wenn Nutzerzahl steigt.)*
5. Nach Migration A: **`get_advisors(security)`** — keine `function_search_path_mutable`/`rls_disabled_in_public`-Warnung; „0 neue Advisors" als Freigabekriterium.

---

## 9. App-Seite (Flutter, Muster KMU Tool 2 `features/auth`)

**Architektur (spiegelt KMU Tool 2):**
- `AuthGateway` (Interface) + `SupabaseAuthGateway` + `FakeAuthGateway` (für Tests). Methoden: `currentSession()`, `signIn(email,password)`, `signUp(email,password) → bool` (Bestätigung ausstehend?), `refreshSession()`, `signOut()`.
- `AuthErgebnis` sealed: `Angemeldet(session)` · `OhneBetrieb` · `KeineSession`. **Membership-los ist ein Zustand, kein Fehler.**
- `AuthStatus { laden, abgemeldet, ohneBetrieb, angemeldet }` + `AuthState` (trägt Session, `betrieb_id`/`rolle` aus dem JWT-Claim). *(MfaLage aus KMU Tool 2 wird weggelassen — MFA out of scope.)*
- Provider: `authStateProvider` (auf `onAuthStateChange`), `currentBetriebIdProvider`/`currentRolleProvider` (aus `app_metadata`-Claim).

**Screens:** Login (E-Mail+Passwort) · Registrieren (Umschalter „Neu hier? Betrieb registrieren") · „Bestätige deine E-Mail" (Resend mit Cooldown) · Onboarding (`betrieb_gruenden`) · **„Einladungs-Code eingeben"** (`einladung_annehmen`) · Logout im Shell-Menü.

**Router-Gate (go_router, Review-Finding „Bounce/Loop"):** `refreshListenable` auf `onAuthStateChange`; `laden` → Splash (`return null`, **nicht** navigieren); `abgemeldet` → `/login`; `ohneBetrieb` → `/onboarding`; `angemeldet` → App. Kein `usePathUrlStrategy` (GitHub Pages hat keinen SPA-404-Fallback → Hash-Routing bleiben).

**Daten-Provider an Auth binden (Review-Blocker „AsyncNotifier cachen Anon-/Seed-Daten"):**
- Ein eager beobachteter `authSyncProvider` invalidiert bei `signedIn`/`signedOut`/`userUpdated` (NICHT bei `tokenRefreshed`) alle Daten-Provider (`materialListProvider`, `materialPurchasesProvider`, `construction…`, `monitoring…`).
- `materials`-Provider: **Auto-Seed entfernen**; `catch` reicht Fehler als `AsyncError` durch (Retry-UI) statt still `_seedData` (Mandanten-Leck); leeres RLS-Ergebnis ≠ „DB leer".
- `betrieb_id` bei Inserts: Default `aktive_betrieb_id()` deckt Bestandsinserts; neue Insert-Stellen geben `betrieb_id` aus `currentBetriebIdProvider` explizit mit.
- Foto-Uploads: Pfad `<betrieb_id>/…` (construction/material/receipts), Lösch-/URL-Parsing an das Zusatzsegment anpassen.

**`index.html` (defensive Härtung):** Der Versions-Redirect verwirft Query/Hash. Bei E-Mail+Passwort ist das für den **Login** irrelevant (kein URL-Token), kann aber den **Bestätigungs-Link-Rücksprung** treffen → Redirect überspringen, wenn Auth-Callback-Parameter (`?code`/`error`) vorhanden sind (bzw. Query/Hash erhalten). *(Weniger kritisch als bei Magic-Link, aber billig und sauber.)*

---

## 10. Lorena & Provisionierung

- **Nur Daniel** wird real: Registrierung → `betrieb_gruenden('Imkerei Arosa')` → owner. Der Betriebsname ist **Daten** (in Settings später änderbar), kein Hardcode.
- **Lorena — invite-ready, NICHT aktiviert:** Der Mechanismus (`mitglied_einladen`/`einladung_annehmen`) ist fertig & getestet, aber **ihre Einladung wird jetzt NICHT erstellt**. Wenn die App so weit ist: Daniel ruft `mitglied_einladen('lorena@…','editor')` → Code → an Lorena → sie registriert sich + gibt Code ein → editor. **Ich brauche ihre E-Mail jetzt nicht.**
- **Gast/viewer:** später (Rolle existiert, Aktivierung out of scope).

**Härtung ggü. KMU Tool 2 (empfohlener Backport):** (a) `search_path = ''` + volle Qualifizierung statt `= public` auf den RLS-kritischen DEFINER-Funktionen (pg_temp-Vektor); (b) `set_row_actor`-Trigger für nicht-fälschbares `created_by/updated_by`. → als separate Aufgabe in KMU Tool 2 vormerken.

---

## 11. Abdeckung der Review-Findings (Auszug Blocker/High)

| Finding | Adressiert durch |
|---|---|
| DEFINER ohne `search_path` (pg_temp-Hijack) | §5 Härtungs-Konvention `= ''` + Qualifizierung |
| `NOT NULL DEFAULT current_betrieb_id()` bricht Service-Cron | §4.2 `set_betrieb_id_from_scale`-Trigger; JWT-Claim-Default statt Membership-Lookup |
| Selbst-Insert in `betrieb_mitglieder`/`betriebe` | §6.2 keine authenticated-INSERT-Policy; nur DEFINER-RPCs |
| Einladungs-Claim im `handle_new_user` (OTP-Problem) | §5.2 Trigger nur Profil; Claim per `einladung_annehmen`-RPC (Code + `auth.email()`) |
| Exception in `handle_new_user` blockt Login | §5.2 minimaler, idempotenter Trigger |
| `index.html` verwirft Auth-Token | §9 entfällt für Passwort-Login; defensive Härtung für Bestätigungs-Link |
| AsyncNotifier cachen Anon-/Seed-Daten | §9 `authSyncProvider`-Invalidierung + Auto-Seed weg |
| Mailer 2/h → Aussperrung | §1 Login = E-Mail+Passwort → Mail nur bei Registrierung/Reset |
| EXECUTE/USAGE-Grants auf `private` | §5.1 `grant usage on schema private` + per-Funktion grant/revoke |
| RLS-Performance (Zeitreihen) | §6.1 Set-Form `betrieb_id in (select meine_betrieb_ids())` |
| `current_betrieb_id()` nicht-deterministisch | §3.3 JWT-Claim `order by created_at limit 1` |
| E-Mail-Case beim Claim | §4.1 `lower(trim())` + `auth.email()`-Vergleich |
| Cutover-Aussperrung | §7.4 verpflichtender authenticated-Rollen-Test vor Drop |
| Backfill an fixer Zahl „74" | §7.3 `WHERE betrieb_id IS NULL` + ACCESS-EXCLUSIVE-Lock |
| Storage cross-tenant | §6.3 `<betrieb_id>/`-Pfad + Membership-scoped Write-Policies |
| verwaister Betrieb (letzter owner) | §5.2 `enforce_last_owner`-Trigger |

---

## 12. Migrations-/Review-Disziplin (aus KMU Tool 2)

- Jede Migration mit **Kopf-Kommentar** (was + Review-Fixes), stabile **errcodes** (`BA0xx`, Client matcht Codes nie Prosa), `revoke execute … from anon, public` + `grant … to authenticated` auf jeder RPC, `set search_path` auf jeder Funktion.
- **Rollback-DO-SQL-Tests** je RPC/Policy (Erfolg + Fehlerpfade + errcode), Simulation via `set local request.jwt.claims` / `app.current_user_id`-GUC.
- **Advisor-Gate:** `get_advisors(security)` nach jeder Migration → 0 neue Findings.
- Anwendung über Supabase `apply_migration` (Bienen-Mechanismus); Bootstrap-DATEN strikt getrennt als Ops-Skript.
- Deploy der App wie immer via `bash deploy.sh` (Cache-Busting).
