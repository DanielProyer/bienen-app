# Auth-Fundament — Plan 3 von 3: Rollout & Cutover Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Das Fundament scharf schalten: Dashboard-Config → App-Release → Daniels Owner-Account + Betriebs-Gründung → Bootstrap-Backfill (227 Zeilen) → **Pflicht-Test-Gate** → Cutover (public-Policies droppen, `anon` entziehen) → Live-Verifikation. Danach gilt echte Mandanten-Isolation.

**Architecture:** Der Cutover ist der einzige **brechende** Schritt. Reihenfolge ist verbindlich: Config **vor** Login (sonst kein `betrieb_id`-Claim), Backfill **vor** `NOT NULL`, Test-Gate **vor** dem Policy-Drop (die public-Policies maskieren bis dahin jeden Fehler). Rollback ist in Sekunden möglich.

**Voraussetzungen:** Plan 1 (A01–A12) **live** ✓ · Plan 2 (App-Auth-Schicht) implementiert, `flutter analyze` + `flutter test` grün.

**Tech Stack:** Supabase (`dcdcohktxbhdxnxjvcyp`), Supabase-MCP (`apply_migration`/`execute_sql`/`get_advisors`), Flutter-Web-Deploy via `bash deploy.sh`.

**Verifizierter Ausgangszustand (2026-07-11):**
- Zu backfillende Zeilen: **227** — `materials` 52 · `construction_steps` 22 · `weight_readings` **151** · `scales` 1 · `scale_alerts` 1 · (`material_purchases`/`funkstationen`/`voelker` = 0). **Nie an einer festen Zahl orientieren — immer `WHERE betrieb_id IS NULL`.**
- `betriebe` = 0 · `auth.users` = 0 · `profiles` = 0 (keine Testreste).
- Zu droppende `{public}`-Policies: **20** auf den 8 Tabellen + **7** auf `storage.objects`.

---

## File Structure

- `bienen_app/supabase/ops/bootstrap-owner.sql` — **Ops-Skript, KEIN Migrationsfile** (hängt an Daniels erst zur Laufzeit bekannter `auth.uid()`; E-Mail als Parameter → nicht mandantenfähig-reproduzierbar, gehört nicht in die Migrations-Historie)
- `bienen_app/supabase/ops/rollback-public-policies.sql` — Sofort-Rollback des Cutovers
- `bienen_app/supabase/migrations/B01_cutover_tabellen.sql` — public-Policies droppen + `anon` entziehen
- `bienen_app/supabase/migrations/B02_cutover_storage.sql` — Storage: public-Write droppen, Listing → mandanten-scoped
- Geändert: `bienen_app/pubspec.yaml` (version), `ToDo.md`, `docs/roadmap-app.md`, `docs/decision-log.md`

---

## Task 1: Supabase-Dashboard-Config (manuell — Daniel)

> Diese Schritte sind **nicht** per MCP/Migration automatisierbar. Ohne sie funktioniert Login/Claim nicht.

**Files:** keine (Dashboard).

- [ ] **Step 1: Auth-Hook aktivieren (KRITISCH)**

Dashboard → **Authentication → Hooks** → *Customize Access Token (JWT) Claims* → Enable → Postgres Function: **`public.custom_access_token`** → Save.
**Ohne diesen Schritt** trägt der JWT nie `app_metadata.betrieb_id` → die App bleibt nach der Gründung dauerhaft in `ohneBetrieb`.

- [ ] **Step 2: E-Mail-Bestätigung + Passwort-Policy**

Dashboard → **Authentication → Providers → Email**: „Confirm email" = **AN** · Minimum password length = **8** · „Enable sign ups" = **AN lassen** (Lorena muss sich für ihre Einladung selbst registrieren können).

- [ ] **Step 3: URL-Konfiguration**

Dashboard → **Authentication → URL Configuration**:
- Site URL: `https://danielproyer.github.io/bienen-app/` (exakt, **mit** Trailing Slash)
- Additional Redirect URLs: `https://danielproyer.github.io/bienen-app/` **und** `https://danielproyer.github.io/bienen-app/**`

- [ ] **Step 4: Verifizieren**

MCP `execute_sql`:
```sql
select 'hook-funktion da' as check,
       exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
              where n.nspname='public' and p.proname='custom_access_token') as ok
union all
select 'auth_admin darf hook ausfuehren',
       has_function_privilege('supabase_auth_admin','public.custom_access_token(jsonb)','EXECUTE');
```
Erwartet: beide `true`. *(Ob der Hook im Dashboard aktiviert ist, zeigt sich endgültig in Task 3 — dort wird der Claim im echten JWT geprüft.)*

---

## Task 2: App-Release (Login-Gate live schalten)

**Files:** Modify: `bienen_app/pubspec.yaml`

- [ ] **Step 1: Branch mergen**

```bash
cd bienen_app
git checkout master && git pull
git merge --no-ff feat/auth-fundament -m "feat(auth): Auth-Fundament (DB + App-Schicht)"
```

- [ ] **Step 2: Version bumpen**

`pubspec.yaml`: `version: 1.7.2+24` → **`version: 1.8.0+25`** (Minor: neues Auth-Fundament).

- [ ] **Step 3: Committen + deployen**

```bash
git add pubspec.yaml && git commit -m "chore: version 1.8.0+25 (Auth-Fundament)"
git push origin master
bash deploy.sh
```
*(`deploy.sh` baut, cache-bustet `main.dart.js?v=1.8.0` und deployt auf gh-pages.)*

- [ ] **Step 4: Verifizieren**

`https://danielproyer.github.io/bienen-app/` neu laden → es erscheint der **Login-Screen** (nicht das Dashboard).
**Wichtig:** Ab hier ist die App gated — die Daten sind aber noch da (public-Policies aktiv). Kein Datenverlust.

---

## Task 3: Daniels Owner-Account + Betriebs-Gründung

**Files:** keine (App-UI).

- [ ] **Step 1: Registrieren**

In der Live-App: „Neu hier? Betrieb registrieren" → **dani.proyer@gmail.com** + Passwort (≥ 8 Zeichen, im Passwortmanager sichern) → Bestätigungs-Mail abwarten → Link klicken.

- [ ] **Step 2: Anmelden + gründen**

Login → App landet in **`ohneBetrieb`** → `/onboarding` → Name: **`Imkerei Arosa`** → „Betrieb gruenden".
*(Der Name ist Daten, kein Hardcode — später in den Settings änderbar.)*

- [ ] **Step 3: Verifizieren — der JWT-Claim MUSS da sein**

MCP `execute_sql`:
```sql
select u.email, p.id as user_id, b.id as betrieb_id, b.name, m.rolle
  from auth.users u
  join public.profiles p on p.id = u.id
  join public.betrieb_mitglieder m on m.user_id = u.id and m.is_deleted = false
  join public.betriebe b on b.id = m.betrieb_id
 where lower(u.email) = 'dani.proyer@gmail.com';
```
Erwartet: **genau 1 Zeile**, `rolle = owner`, `name = Imkerei Arosa`. Die `betrieb_id` **notieren** — sie ist der Parameter für Task 4.

Zusätzlich **in der App** prüfen: Konto-Seite zeigt Rolle „Inhaber". Falls die App nach der Gründung in `ohneBetrieb` hängt → **Auth-Hook (Task 1 Step 1) ist nicht aktiv** → dort nachziehen, dann in der App neu anmelden.

---

## Task 4: Bootstrap — Backfill + NOT NULL/Default

**Files:** Create: `bienen_app/supabase/ops/bootstrap-owner.sql`

> **Warum kein Migrationsfile:** Der Backfill hängt an einer erst zur Laufzeit bekannten `betrieb_id` und an Daniels E-Mail. In `supabase/migrations/` wäre er weder reproduzierbar (frischer Branch/CI hat keinen Daniel) noch mandantenfähig (E-Mail-Hardcode). Deshalb: einmaliges, idempotentes Ops-Skript.

- [ ] **Step 1: Ops-Skript schreiben**

`bienen_app/supabase/ops/bootstrap-owner.sql`:
```sql
-- bootstrap-owner.sql | EINMALIG, nach der Betriebs-Gruendung des Owners.
-- KEIN Migrationsfile (laufzeit-abhaengige betrieb_id). Idempotent: mehrfaches
-- Ausfuehren ist harmlos (WHERE betrieb_id IS NULL trifft dann 0 Zeilen).
--
-- Reihenfolge je Tabelle ist verbindlich:
--   LOCK (schliesst das Insert-Race) -> UPDATE ... WHERE betrieb_id IS NULL
--   -> DEFAULT setzen -> NOT NULL setzen.
-- Der DEFAULT private.aktive_betrieb_id() liest den JWT-Claim und kommt NUR auf die
-- 6 user-getriebenen Tabellen. weight_readings/scale_alerts bekommen KEINEN Default:
-- dort fuellt der BEFORE-INSERT-Trigger aus scales.betrieb_id (Service-Role-Cron
-- hat kein auth.uid()).

do $$
declare
  v_betrieb uuid;
  t text;
begin
  -- betrieb_id zur Laufzeit aufloesen (E-Mail nur hier, als Parameter gedacht).
  select m.betrieb_id into v_betrieb
    from auth.users u
    join public.betrieb_mitglieder m on m.user_id = u.id and m.is_deleted = false
   where lower(u.email) = lower('dani.proyer@gmail.com')
     and m.rolle = 'owner'
   order by m.created_at
   limit 1;
  if v_betrieb is null then
    raise exception 'Kein owner-Betrieb gefunden — hat sich der Owner registriert UND gegruendet?';
  end if;

  -- 1) Alle 8 Tabellen: Lock + mengenbasierter Backfill + NOT NULL.
  foreach t in array array['materials','material_purchases','weight_readings','scales',
                           'scale_alerts','funkstationen','voelker','construction_steps'] loop
    execute format('lock table public.%I in access exclusive mode', t);
    execute format('update public.%I set betrieb_id = $1 where betrieb_id is null', t)
      using v_betrieb;
  end loop;

  -- 2) DEFAULT nur auf die 6 user-getriebenen Tabellen.
  foreach t in array array['materials','material_purchases','scales',
                           'funkstationen','voelker','construction_steps'] loop
    execute format(
      'alter table public.%I alter column betrieb_id set default private.aktive_betrieb_id()', t);
  end loop;

  -- 3) NOT NULL auf alle 8 (jetzt garantiert befuellt).
  foreach t in array array['materials','material_purchases','weight_readings','scales',
                           'scale_alerts','funkstationen','voelker','construction_steps'] loop
    execute format('alter table public.%I alter column betrieb_id set not null', t);
  end loop;

  raise notice 'Bootstrap fertig fuer betrieb_id=%', v_betrieb;
end $$;
```

- [ ] **Step 2: Vorbedingung prüfen**

MCP `execute_sql`:
```sql
select count(*) as owner_betriebe
  from auth.users u
  join public.betrieb_mitglieder m on m.user_id=u.id and m.is_deleted=false and m.rolle='owner'
 where lower(u.email)='dani.proyer@gmail.com';
```
Erwartet: **1**. Bei 0 → **STOPP**, Task 3 nachholen.

- [ ] **Step 3: Ausführen**

MCP `execute_sql` mit dem kompletten `do $$ ... $$;`-Block aus Step 1.
Erwartet: success (Notice mit der betrieb_id).

- [ ] **Step 4: Verifizieren**

```sql
select 'null-betrieb_id (muss 0)' as check,
       (select count(*) from public.materials where betrieb_id is null)
     + (select count(*) from public.construction_steps where betrieb_id is null)
     + (select count(*) from public.scales where betrieb_id is null)
     + (select count(*) from public.weight_readings where betrieb_id is null)
     + (select count(*) from public.scale_alerts where betrieb_id is null)
     + (select count(*) from public.material_purchases where betrieb_id is null)
     + (select count(*) from public.funkstationen where betrieb_id is null)
     + (select count(*) from public.voelker where betrieb_id is null) as wert
union all
select 'not-null gesetzt (muss 8)',
       (select count(*) from information_schema.columns
         where table_schema='public' and column_name='betrieb_id' and is_nullable='NO'
           and table_name in ('materials','material_purchases','weight_readings','scales',
                'scale_alerts','funkstationen','voelker','construction_steps'))
union all
select 'defaults gesetzt (muss 6)',
       (select count(*) from information_schema.columns
         where table_schema='public' and column_name='betrieb_id'
           and column_default like '%aktive_betrieb_id%');
```
Erwartet: `0` · `8` · `6`. Bei Abweichung → **STOPP**, nicht zum Cutover.

- [ ] **Step 5: Commit**

```bash
git add supabase/ops/bootstrap-owner.sql
git commit -m "ops(auth): Bootstrap-Skript (Backfill 227 Zeilen + NOT NULL/Default)"
```

---

## Task 5: PFLICHT-Test-Gate — Cutover simulieren, bevor gedroppt wird

> Bis hierher **maskieren die public-Policies jeden Fehler** (sie werden mit den strikten Policies ge-OR-t). Dieser Test ist die **einzige** Möglichkeit, den Zustand *nach* dem Drop vorab zu sehen. Ohne bestandenes Gate: **nicht droppen.**

**Files:** keine.

- [ ] **Step 1: Als authenticated-Owner simulieren (in EINER Transaktion, mit Rollback)**

MCP `execute_sql` — `<DANIEL_UUID>` und `<AROSA_UUID>` aus Task 3 einsetzen:
```sql
do $$
declare v_uid uuid := '<DANIEL_UUID>'; v_betrieb uuid := '<AROSA_UUID>';
        t_mat int; t_con int; t_wr int;
        v_mat int; v_con int; v_wr int; v_probe uuid;
begin
  -- Gesamtzeilen VOR dem Rollenwechsel als postgres (RLS-frei) ermitteln.
  -- Bewusst NICHT gegen feste 52/22/151 pruefen: zwischen Deploy und Bootstrap
  -- kann Daniel Zeilen angelegt haben -> das Gate wuerde faelschlich rot.
  select count(*) into t_mat from public.materials;
  select count(*) into t_con from public.construction_steps;
  select count(*) into t_wr  from public.weight_readings;

  set local role authenticated;
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_uid, 'role','authenticated',
      'app_metadata', json_build_object('betrieb_id', v_betrieb::text, 'rolle','owner'))::text, true);

  -- 0) Sanity: Claim + Mitgliedschaft + Schreibrecht
  assert private.aktive_betrieb_id() = v_betrieb, 'aktive_betrieb_id aus Claim';
  assert private.ist_mitglied(v_betrieb), 'ist Mitglied';
  assert private.kann_schreiben(v_betrieb), 'darf schreiben';

  -- 1) Lesbarkeit: der Owner muss JEDE Zeile sehen (sichtbar == gesamt)
  select count(*) into v_mat from public.materials;
  select count(*) into v_con from public.construction_steps;
  select count(*) into v_wr  from public.weight_readings;
  assert v_mat = t_mat, format('materials sichtbar %s von %s', v_mat, t_mat);
  assert v_con = t_con, format('construction_steps sichtbar %s von %s', v_con, t_con);
  assert v_wr  = t_wr,  format('weight_readings sichtbar %s von %s', v_wr, t_wr);

  -- 2) Schreibpfad: Insert OHNE betrieb_id -> Default aus dem Claim muss greifen
  insert into public.voelker (name) values ('__cutover_probe__') returning id into v_probe;
  assert (select betrieb_id from public.voelker where id=v_probe) = v_betrieb,
         'Default aktive_betrieb_id() fuellt betrieb_id';

  reset role;
  perform set_config('request.jwt.claims','', true);
  raise exception 'ROLLBACK_OK';
exception when others then if sqlerrm <> 'ROLLBACK_OK' then raise; end if;
end $$;
```
**Freigabekriterium:** Block endet mit `ROLLBACK_OK` (leeres Ergebnis, kein Fehler). Jede Assertion-Meldung = **STOPP**.

- [ ] **Step 2: Rollback-Skript bereitlegen**

`bienen_app/supabase/ops/rollback-public-policies.sql` (stellt den Vor-Cutover-Zustand in Sekunden wieder her):
```sql
-- rollback-public-policies.sql | NOTFALL: Cutover (B01/B02) rueckgaengig machen.
-- Exakt die 20 Tabellen- + 7 Storage-Policies, die vor dem Cutover bestanden.
create policy "Allow public delete" on public.construction_steps for DELETE to public using (true);
create policy "Allow public insert" on public.construction_steps for INSERT to public with check (true);
create policy "Allow public read"   on public.construction_steps for SELECT to public using (true);
create policy "Allow public update" on public.construction_steps for UPDATE to public using (true);
create policy "Allow public all"    on public.funkstationen for ALL to public using (true) with check (true);
create policy "Allow public delete" on public.material_purchases for DELETE to public using (true);
create policy "Allow public insert" on public.material_purchases for INSERT to public with check (true);
create policy "Allow public read"   on public.material_purchases for SELECT to public using (true);
create policy "Allow public update" on public.material_purchases for UPDATE to public using (true);
create policy "Allow public delete" on public.materials for DELETE to public using (true);
create policy "Allow public insert" on public.materials for INSERT to public with check (true);
create policy "Allow public read"   on public.materials for SELECT to public using (true);
create policy "Allow public update" on public.materials for UPDATE to public using (true);
create policy "Public write scale_alerts" on public.scale_alerts for ALL to public using (true);
create policy "Public read scale_alerts"  on public.scale_alerts for SELECT to public using (true);
create policy "Public write scales" on public.scales for ALL to public using (true);
create policy "Public read scales"  on public.scales for SELECT to public using (true);
create policy "Allow public all"    on public.voelker for ALL to public using (true) with check (true);
create policy "Public write weight_readings" on public.weight_readings for INSERT to public with check (true);
create policy "Public read weight_readings"  on public.weight_readings for SELECT to public using (true);
create policy material_media_all on storage.objects for ALL to public using ((bucket_id = 'material-media'::text)) with check ((bucket_id = 'material-media'::text));
create policy "Public upload construction photos" on storage.objects for INSERT to public with check ((bucket_id = 'construction-photos'::text));
create policy "Public upload receipts" on storage.objects for INSERT to public with check ((bucket_id = 'material-receipts'::text));
create policy "Public read construction photos" on storage.objects for SELECT to public using ((bucket_id = 'construction-photos'::text));
create policy "Public read receipts" on storage.objects for SELECT to public using ((bucket_id = 'material-receipts'::text));
create policy "Public update construction photos" on storage.objects for UPDATE to public using ((bucket_id = 'construction-photos'::text));
create policy "Public update receipts" on storage.objects for UPDATE to public using ((bucket_id = 'material-receipts'::text));
-- Grants zurueck (falls B01 sie entzogen hat):
grant select, insert, update, delete on public.materials, public.material_purchases,
  public.weight_readings, public.scales, public.scale_alerts, public.funkstationen,
  public.voelker, public.construction_steps to anon;
```

- [ ] **Step 3: Commit**

```bash
git add supabase/ops/rollback-public-policies.sql
git commit -m "ops(auth): Rollback-Skript fuer den Cutover"
```

---

## Task 6: Cutover B01 — public-Policies droppen + `anon` entziehen

> **Ab hier greift echte Mandanten-Isolation.** Nur ausführen, wenn Task 5 grün war.

**Files:** Create: `bienen_app/supabase/migrations/B01_cutover_tabellen.sql`

- [ ] **Step 1: Migration schreiben**

```sql
-- B01_cutover_tabellen.sql | CUTOVER (brechend): die alten {public}-Policies der 8
-- Bestandstabellen droppen. Danach gelten ausschliesslich die strikten
-- authenticated-Policies aus A09 -> echte Mandanten-Isolation.
-- Voraussetzung: Bootstrap-Backfill + NOT NULL gelaufen, Test-Gate gruen.
do $$
declare p record;
begin
  for p in select schemaname, tablename, policyname
             from pg_policies
            where schemaname = 'public'
              and roles = '{public}'
              and tablename in ('materials','material_purchases','weight_readings','scales',
                                'scale_alerts','funkstationen','voelker','construction_steps')
  loop
    execute format('drop policy %I on %I.%I', p.policyname, p.schemaname, p.tablename);
  end loop;
end $$;

-- Defense-in-Depth: anon braucht auf den Fachtabellen gar nichts mehr (App ist gated,
-- der Cron laeuft als service_role). RLS wuerde ohnehin blocken — der Grant war die
-- zweite Haelfte des Lochs.
revoke all on public.materials, public.material_purchases, public.weight_readings,
  public.scales, public.scale_alerts, public.funkstationen, public.voelker,
  public.construction_steps from anon;
```

- [ ] **Step 2: Anwenden**

MCP `apply_migration({project_id:'dcdcohktxbhdxnxjvcyp', name:'b01_cutover_tabellen', query:<inhalt>})`
Erwartet: success.

- [ ] **Step 3: Verifizieren — anon ist draussen, Owner sieht alles**

```sql
-- (1) Keine {public}-Policies mehr auf den 8 Tabellen:
select count(*) as public_policies_uebrig from pg_policies
 where schemaname='public' and roles='{public}'
   and tablename in ('materials','material_purchases','weight_readings','scales',
                     'scale_alerts','funkstationen','voelker','construction_steps');
```
Erwartet: **0**.
```sql
-- (2) anon sieht NICHTS mehr:
do $$
declare n int;
begin
  set local role anon;
  select count(*) into n from public.materials;
  reset role;
  assert n = 0, format('anon sieht noch %s materials — Cutover unvollstaendig!', n);
  raise exception 'ROLLBACK_OK';
exception when others then if sqlerrm <> 'ROLLBACK_OK' then raise; end if;
end $$;
```
Erwartet: `ROLLBACK_OK`.
```sql
-- (3) Owner sieht weiterhin alles (Test-Gate aus Task 5 erneut, jetzt SCHARF):
--     -> denselben do-Block aus Task 5 Step 1 nochmals laufen lassen.
```
Erwartet: `ROLLBACK_OK`. **Falls (3) fehlschlägt → sofort `rollback-public-policies.sql` ausführen.**

- [ ] **Step 4: Commit**

```bash
git add supabase/migrations/B01_cutover_tabellen.sql
git commit -m "feat(auth): B01 Cutover - public-Policies gedroppt, anon entzogen"
```

---

## Task 7: Cutover B02 — Storage

**Files:** Create: `bienen_app/supabase/migrations/B02_cutover_storage.sql`

- [ ] **Step 1: Migration schreiben**

```sql
-- B02_cutover_storage.sql | Storage-Cutover.
-- (a) public-WRITE-Policies droppen (die authenticated-Write-Policies aus A10 mit
--     <betrieb_id>/-Pfad-Scoping uebernehmen).
-- (b) Die breiten public-SELECT/Listing-Policies durch mandanten-scoped
--     authenticated-SELECT ersetzen: behebt Advisor 0025 (Bucket-Listing) UND
--     erhaelt uploadBinary(upsert:true) — das braucht SELECT+UPDATE auf das Objekt.
--     Downloads laufen ueber die public URL an RLS vorbei -> Foto-Anzeige unberuehrt.
do $$
declare p record;
begin
  for p in select policyname from pg_policies
            where schemaname='storage' and tablename='objects' and roles='{public}'
  loop
    execute format('drop policy %I on storage.objects', p.policyname);
  end loop;
end $$;

do $$
declare bkt text;
begin
  foreach bkt in array array['construction-photos','material-media','material-receipts'] loop
    execute format($p$
      create policy %I on storage.objects for select to authenticated
      using (bucket_id = %L
        and (storage.foldername(name))[1] ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
        and private.ist_mitglied(((storage.foldername(name))[1])::uuid))
    $p$, 'auth_sel_'||replace(bkt,'-','_'), bkt);
  end loop;
end $$;
```

- [ ] **Step 2: Anwenden**

MCP `apply_migration({project_id:'dcdcohktxbhdxnxjvcyp', name:'b02_cutover_storage', query:<inhalt>})`
Erwartet: success.

- [ ] **Step 3: Verifizieren**

```sql
select
  (select count(*) from pg_policies where schemaname='storage' and tablename='objects'
     and roles='{public}') as public_uebrig,
  (select count(*) from pg_policies where schemaname='storage' and tablename='objects'
     and roles='{authenticated}') as auth_policies;
```
Erwartet: `public_uebrig = 0`, `auth_policies = 12` (3 Buckets × insert/update/delete aus A10 + select aus B02).

**Manuell in der App (Pflicht):** Ein Bauschritt-Foto neu aufnehmen → Upload landet unter `<betrieb_id>/…` und wird angezeigt. Ein **altes** Foto (Flachpfad) muss weiterhin sichtbar sein (public URL, RLS-unabhängig).

- [ ] **Step 4: Commit**

```bash
git add supabase/migrations/B02_cutover_storage.sql
git commit -m "feat(auth): B02 Storage-Cutover (public-Write weg, Listing mandanten-scoped)"
```

---

## Task 8: Live-Verifikation + Advisor

**Files:** keine.

- [ ] **Step 1: App durchklicken (angemeldet als Daniel)**

Dashboard · **Material** (52 Positionen sichtbar, Status ändern funktioniert) · **Bau** (22 Schritte, abhaken + Foto) · **Waage** (Demo-Daten/Chart) · Konto (Rolle „Inhaber", Logout).
Danach **Logout → Login** → Daten sind wieder da (prüft die Provider-Invalidierung aus Plan 2).

- [ ] **Step 2: Security-Advisor**

MCP `get_advisors({project_id:'dcdcohktxbhdxnxjvcyp', type:'security'})`
Erwartet **weg**: alle `rls_policy_always_true` · alle `public_bucket_allows_listing`.
Erwartet **verbleibend (akzeptiert, dokumentiert)**: `authenticated_security_definer_function_executable` für `betrieb_gruenden` / `mitglied_einladen` / `einladung_annehmen` / `einladung_widerrufen` / `team_mitglieder` — das **ist** die Auth-API (eigene Guards, `anon` entzogen).

- [ ] **Step 3: Performance-Advisor (Zeitreihen)**

MCP `get_advisors({project_id:'dcdcohktxbhdxnxjvcyp', type:'performance'})`
Auf `auth_rls_initplan`/`rls_initplan` bei `weight_readings` achten. Erwartet: keine — die SELECT-Policies nutzen die Set-Form `betrieb_id in (select private.meine_betrieb_ids())`, die einmal materialisiert wird.

---

## Task 9: Lorena vorbereiten (invite-ready, NICHT aktivieren)

**Files:** keine.

- [ ] **Step 1: Nur dokumentieren — jetzt NICHT ausführen**

Wenn die App so weit ist, erzeugt Daniel den Code auf der Konto-Seite („Mitglied einladen" → Lorenas E-Mail + Rolle **editor**) → Code **einmalig** sichtbar → an Lorena → sie registriert sich (E-Mail+Passwort) → „Ich habe einen Einladungs-Code" → Code eingeben → sie ist editor.
**Bewusst offen:** keine Einladung anlegen, solange die App nicht bereit ist (Scope-Vorgabe). Lorenas E-Mail wird erst dann gebraucht.

- [ ] **Step 2: Gegenprobe, dass nichts aktiviert wurde**

```sql
select count(*) as offene_einladungen from public.einladungen where status='offen';
```
Erwartet: **0**.

---

## Task 10: Arbeitsschluss (Doku nachführen)

**Files:** Modify: `ToDo.md`, `docs/roadmap-app.md`, `docs/decision-log.md`; Memory.

- [ ] **Step 1: Doku**

`ToDo.md`: Fundament auf ✓, nächster Fokus = P1-Fachmodule (Völker & Standorte).
`docs/roadmap-app.md`: Fundament-Zeile „Auth & Rollen" auf ✅ (Datum + Version 1.8.0).
`docs/decision-log.md`: Cutover-Datum + „ab jetzt echte Mandanten-Isolation; anon hat keinen Zugriff mehr".
Memory: Supabase-Abschnitt ergänzen (Tenancy-Tabellen, Auth-Hook aktiv, Login = E-Mail+Passwort, `betrieb_id` NOT NULL auf allen 8 Tabellen).

- [ ] **Step 2: Committen + pushen + Status**

```bash
git add -A && git commit -m "docs: Auth-Fundament abgeschlossen (Cutover live)"
git push origin master
git status   # sauberer Arbeitsbaum
```

---

## Abschluss Plan 3

**Erfolgskriterien:** Login-Gate live · Daniel = owner von „Imkerei Arosa" · alle 227 Bestandszeilen tragen `betrieb_id`, Spalte `NOT NULL` auf allen 8 Tabellen · `anon` hat **keinen** Zugriff mehr · Owner sieht/schreibt alles · Advisor ohne `rls_policy_always_true`/`public_bucket_allows_listing` · Lorena invite-ready, nicht aktiviert.

**Notfall:** `supabase/ops/rollback-public-policies.sql` stellt den Vor-Cutover-Zustand in Sekunden her. Ein echter DB-Lockout ist ausgeschlossen (Dashboard/`service_role` umgehen RLS).

**Danach:** P1-Fachmodule laut `docs/roadmap-app.md` — (1) Völker & Standorte, (2) Durchsicht/Stockkarte, (3) Behandlungen + Varroa, …
