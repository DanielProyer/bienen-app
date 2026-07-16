# Auth-Fundament — Plan 1 von 3: DB-Fundament (Migration A) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Das mandantenfähige DB-Fundament additiv und nicht-brechend anlegen: Tenancy-Schema, security-definer-RLS-Helper, JWT-Claim-Auth-Hook, RPCs (Gründung + Einladungen), `betrieb_id` auf den 8 Bestandstabellen — mit strikten `authenticated`-Policies **zusätzlich** zu den bestehenden `public`-Policies, sodass die Live-App unverändert weiterläuft.

**Architecture:** Muster 1:1 aus dem Schwesterprojekt KMU Tool 2 (`tenants→betriebe`, `memberships→betrieb_mitglieder`, `custom_access_token`-Auth-Hook, `betrieb_gruenden`/Einladungs-RPCs), auf die Bienen-Domäne + Rollen owner/editor/viewer gemappt. Gegenüber KMU Tool 2 gehärtet: alle `SECURITY DEFINER`-Funktionen mit `SET search_path = ''` + voll schema-qualifizierten Namen (pg_temp-sicher), `set_row_actor`-Trigger für nicht-fälschbares `created_by/updated_by`.

**Tech Stack:** Supabase Postgres 17.6 (Projekt `dcdcohktxbhdxnxjvcyp`, Region eu-west-1). Migrationen als SQL-Files unter `bienen_app/supabase/migrations/` **und** angewendet via Supabase-MCP `apply_migration`. Tests als `execute_sql`-Rollback-DO-Blöcke mit `set local role authenticated` + `set local request.jwt.claims` / `app.current_user_id`-GUC. Advisor-Gate via `get_advisors(security)`.

**Referenz-SQL (verbindliche Blaupause, NICHT verändern — nur lesen):**
- `D:\Projekte\KMU Tool 2\04_Entwicklung\backend\migrations\0001_init_tenancy.sql`, `0003_supabase_auth_adapter.sql`, `0004_fix_rls_recursion.sql`, `0005_kunden_auftraege.sql`, `0011_powersync_fundament.sql`, `0012_onboarding.sql`, `0013_auth_ausbau.sql`

**Konventionen für JEDE Aufgabe (gelten durchgehend):**
- SQL zuerst als Datei unter `bienen_app/supabase/migrations/<name>.sql` schreiben (Git-Versionierung), dann via MCP `apply_migration({project_id:'dcdcohktxbhdxnxjvcyp', name:'<name>', query:<file-inhalt>})` anwenden.
- `project_id` ist überall `dcdcohktxbhdxnxjvcyp`.
- Jede `SECURITY DEFINER`-Funktion: `set search_path = ''` + voll qualifizierte Objektnamen (`public.*`, `auth.uid()`, `'owner'::public.betrieb_rolle`, `extensions.digest` …). pg_catalog-Builtins (`now()`, `coalesce`, `gen_random_uuid()`, Operatoren) müssen NICHT qualifiziert werden.
- Nach RPC-/Funktions-Tasks: `get_advisors(security)` → es dürfen **0 neue** `function_search_path_mutable`/`rls_disabled_in_public` erscheinen.
- Commit nach jeder Aufgabe auf Branch `feat/auth-fundament`.

---

## File Structure

- `bienen_app/supabase/migrations/A01_basis.sql` — schema `private`, `pgcrypto`, `current_app_user`, `set_updated_at`
- `bienen_app/supabase/migrations/A02_tenancy_tabellen.sql` — enum + 4 Tenancy-Tabellen + Indizes + RLS-enable
- `bienen_app/supabase/migrations/A03_rls_helper.sql` — `meine_betrieb_ids`/`rolle_im_betrieb`/`ist_mitglied`/`kann_schreiben`/`aktive_betrieb_id`/`teilt_betrieb` + Grants
- `bienen_app/supabase/migrations/A04_profil_trigger.sql` — `handle_new_auth_user` (nur Profil)
- `bienen_app/supabase/migrations/A05_auth_hook.sql` — `custom_access_token` + `supabase_auth_admin`-Grants/Policy
- `bienen_app/supabase/migrations/A06_rpcs.sql` — `betrieb_gruenden`, `eigener_betrieb_als_owner`, `mitglied_einladen`, `einladung_annehmen`, `einladung_widerrufen`, `team_mitglieder`, `enforce_last_owner`
- `bienen_app/supabase/migrations/A07_tenancy_rls.sql` — RLS-Policies auf betriebe/profiles/betrieb_mitglieder/einladungen
- `bienen_app/supabase/migrations/A08_fachtabellen_spalten.sql` — `betrieb_id`/`created_by`/`updated_by` + Trigger auf den 8 Tabellen
- `bienen_app/supabase/migrations/A09_fachtabellen_rls.sql` — additive `authenticated`-Policies auf den 8 Tabellen
- `bienen_app/supabase/migrations/A10_storage.sql` — additive `authenticated`-Storage-Write-Policies + Listing
- `bienen_app/supabase/migrations/A11_haertung.sql` — vorbestehende Funktionen härten + Advisor-Gate

---

## Task 1: Basis (Schema `private`, pgcrypto, `current_app_user`, `set_updated_at`)

**Files:**
- Create: `bienen_app/supabase/migrations/A01_basis.sql`

- [ ] **Step 1: Migration-Datei schreiben**

```sql
-- A01_basis.sql | Fundament-Basis: private-Schema, pgcrypto, Session-User, updated_at
-- pgcrypto liegt bei Supabase im Schema "extensions" (fuer digest/gen_random_bytes, A06).
create extension if not exists pgcrypto with schema extensions;

create schema if not exists private;
revoke all on schema private from public;
grant usage on schema private to authenticated;

-- Session-User provider-agnostisch: GUC (fuer SQL-Rollback-Tests) + auth.uid()-Fallback.
create or replace function private.current_app_user() returns uuid
  language sql stable set search_path = '' as $$
  select coalesce(
    nullif(current_setting('app.current_user_id', true), '')::uuid,
    auth.uid()
  );
$$;
revoke all on function private.current_app_user() from public, anon;
grant execute on function private.current_app_user() to authenticated;

-- updated_at-Setzer fuer die neuen Tenancy-Tabellen.
create or replace function private.set_updated_at() returns trigger
  language plpgsql set search_path = '' as $$
begin new.updated_at = now(); return new; end; $$;
```

- [ ] **Step 2: Anwenden**

MCP: `apply_migration({project_id:'dcdcohktxbhdxnxjvcyp', name:'A01_basis', query:<inhalt A01_basis.sql>})`
Erwartet: success.

- [ ] **Step 3: Verifizieren**

MCP `execute_sql`:
```sql
select
  has_schema_privilege('authenticated','private','USAGE') as auth_usage,
  has_schema_privilege('anon','private','USAGE')          as anon_usage,
  exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
         where n.nspname='private' and p.proname='current_app_user') as fn_ok;
```
Erwartet: `auth_usage=true, anon_usage=false, fn_ok=true`.

- [ ] **Step 4: Commit**

```bash
git add bienen_app/supabase/migrations/A01_basis.sql
git commit -m "feat(auth): A01 Basis (private-Schema, pgcrypto, current_app_user)"
```

---

## Task 2: Tenancy-Tabellen (Enum + betriebe/profiles/betrieb_mitglieder/einladungen)

**Files:**
- Create: `bienen_app/supabase/migrations/A02_tenancy_tabellen.sql`

- [ ] **Step 1: Migration-Datei schreiben**

```sql
-- A02_tenancy_tabellen.sql | Mandanten-Fundament (Muster KMU 0001/0013), Bienen-Domaene.
create type public.betrieb_rolle as enum ('owner','editor','viewer');

create table public.betriebe (
  id         uuid primary key default gen_random_uuid(),
  name       text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  is_deleted boolean not null default false
);
create trigger trg_betriebe_updated before update on public.betriebe
  for each row execute function private.set_updated_at();

-- Spiegel von auth.users (id = auth.users.id); Anzeige "Geaendert von X".
create table public.profiles (
  id           uuid primary key references auth.users(id) on delete cascade,
  email        text,
  display_name text,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);
create trigger trg_profiles_updated before update on public.profiles
  for each row execute function private.set_updated_at();

create table public.betrieb_mitglieder (
  id         uuid primary key default gen_random_uuid(),
  betrieb_id uuid not null references public.betriebe(id) on delete cascade,
  user_id    uuid not null references public.profiles(id) on delete cascade,
  rolle      public.betrieb_rolle not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  is_deleted boolean not null default false,
  unique (betrieb_id, user_id)
);
create trigger trg_betrieb_mitglieder_updated before update on public.betrieb_mitglieder
  for each row execute function private.set_updated_at();
create index idx_mitglieder_betrieb on public.betrieb_mitglieder (betrieb_id);
create index idx_mitglieder_user    on public.betrieb_mitglieder (user_id);

-- Code-basierte Einladung: NUR der SHA-256-Hash wird gespeichert.
create table public.einladungen (
  id             uuid primary key default gen_random_uuid(),
  betrieb_id     uuid not null references public.betriebe(id) on delete cascade,
  email          text not null,
  rolle          public.betrieb_rolle not null,
  code_hash      text not null,
  status         text not null default 'offen'
                 check (status in ('offen','angenommen','widerrufen')),
  ablauf_am      timestamptz not null default now() + interval '7 days',
  eingeladen_von uuid,
  angenommen_von uuid,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);
create trigger trg_einladungen_updated before update on public.einladungen
  for each row execute function private.set_updated_at();
create index idx_einladungen_betrieb on public.einladungen (betrieb_id);
create unique index idx_einladungen_code on public.einladungen (code_hash);
-- Nie zwei OFFENE Einladungen an dieselbe (normalisierte) Adresse pro Betrieb.
create unique index idx_einladungen_offen_pro_email
  on public.einladungen (betrieb_id, lower(email)) where status = 'offen';

alter table public.betriebe           enable row level security;
alter table public.profiles           enable row level security;
alter table public.betrieb_mitglieder enable row level security;
alter table public.einladungen        enable row level security;
```

- [ ] **Step 2: Anwenden** — `apply_migration(name:'A02_tenancy_tabellen', query:<inhalt>)`. Erwartet: success.

- [ ] **Step 3: Verifizieren**

```sql
select
  (select count(*) from pg_tables where schemaname='public'
     and tablename in ('betriebe','profiles','betrieb_mitglieder','einladungen')) as tabellen,
  (select count(*) from pg_class c join pg_namespace n on n.oid=c.relnamespace
     where n.nspname='public'
       and c.relname in ('betriebe','profiles','betrieb_mitglieder','einladungen')
       and c.relrowsecurity) as rls_aktiv,
  (select array_agg(enumlabel order by enumsortorder) from pg_enum e
     join pg_type t on t.oid=e.enumtypid where t.typname='betrieb_rolle') as rollen;
```
Erwartet: `tabellen=4, rls_aktiv=4, rollen={owner,editor,viewer}`.

- [ ] **Step 4: Commit**

```bash
git add bienen_app/supabase/migrations/A02_tenancy_tabellen.sql
git commit -m "feat(auth): A02 Tenancy-Tabellen (betriebe/profiles/betrieb_mitglieder/einladungen)"
```

---

## Task 3: RLS-Helper (security-definer, bricht Rekursion) + Grants

**Files:**
- Create: `bienen_app/supabase/migrations/A03_rls_helper.sql`

- [ ] **Step 1: Migration-Datei schreiben**

```sql
-- A03_rls_helper.sql | RLS-Helper. meine_betrieb_ids/rolle/ist_mitglied/kann_schreiben
-- sind SECURITY DEFINER (lesen betrieb_mitglieder ohne RLS -> keine Rekursion; A04-Muster
-- aus KMU). aktive_betrieb_id liest den JWT-Claim (kein DB-Read, kein definer noetig).

create or replace function private.meine_betrieb_ids() returns setof uuid
  language sql stable security definer set search_path = '' as $$
  select bm.betrieb_id from public.betrieb_mitglieder bm
   where bm.user_id = private.current_app_user() and bm.is_deleted = false;
$$;

create or replace function private.ist_mitglied(b_id uuid) returns boolean
  language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.betrieb_mitglieder bm
    where bm.betrieb_id = b_id and bm.user_id = private.current_app_user()
      and bm.is_deleted = false);
$$;

create or replace function private.rolle_im_betrieb(b_id uuid) returns public.betrieb_rolle
  language sql stable security definer set search_path = '' as $$
  select bm.rolle from public.betrieb_mitglieder bm
   where bm.betrieb_id = b_id and bm.user_id = private.current_app_user()
     and bm.is_deleted = false
   order by bm.created_at limit 1;
$$;

create or replace function private.kann_schreiben(b_id uuid) returns boolean
  language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.betrieb_mitglieder bm
    where bm.betrieb_id = b_id and bm.user_id = private.current_app_user()
      and bm.is_deleted = false
      and bm.rolle in ('owner'::public.betrieb_rolle,'editor'::public.betrieb_rolle));
$$;

create or replace function private.teilt_betrieb(other_user uuid) returns boolean
  language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.betrieb_mitglieder m1
    join public.betrieb_mitglieder m2 on m1.betrieb_id = m2.betrieb_id
    where m1.user_id = private.current_app_user() and m1.is_deleted = false
      and m2.user_id = other_user and m2.is_deleted = false);
$$;

-- Aktiver Betrieb aus dem JWT-Claim (deterministisch, kein Membership-LIMIT-1).
create or replace function private.aktive_betrieb_id() returns uuid
  language sql stable set search_path = '' as $$
  select nullif(auth.jwt() #>> '{app_metadata,betrieb_id}', '')::uuid;
$$;

-- Grants: nur authenticated darf aufrufen (RLS-Policies laufen als aufrufende Rolle).
do $$
declare fn text;
begin
  foreach fn in array array[
    'private.meine_betrieb_ids()', 'private.ist_mitglied(uuid)',
    'private.rolle_im_betrieb(uuid)', 'private.kann_schreiben(uuid)',
    'private.teilt_betrieb(uuid)', 'private.aktive_betrieb_id()'
  ] loop
    execute format('revoke all on function %s from public, anon', fn);
    execute format('grant execute on function %s to authenticated', fn);
  end loop;
end $$;
```

- [ ] **Step 2: Anwenden** — `apply_migration(name:'A03_rls_helper', query:<inhalt>)`. Erwartet: success.

- [ ] **Step 3: Test schreiben & ausführen (Rekursions-Freiheit + Rollen-Logik)**

MCP `execute_sql` (Setup-Daten in einer Transaktion, dann Rollback):
```sql
do $$
declare b1 uuid; b2 uuid; u1 uuid := gen_random_uuid(); u2 uuid := gen_random_uuid();
begin
  insert into public.betriebe (name) values ('T1') returning id into b1;
  insert into public.betriebe (name) values ('T2') returning id into b2;
  insert into auth.users (id, email) values (u1,'u1@test.ch'),(u2,'u2@test.ch');
  insert into public.profiles (id,email) values (u1,'u1@test.ch'),(u2,'u2@test.ch') on conflict (id) do nothing;
  insert into public.betrieb_mitglieder (betrieb_id,user_id,rolle)
    values (b1,u1,'owner'),(b1,u2,'viewer');
  -- Als u1 (owner) simulieren:
  perform set_config('app.current_user_id', u1::text, true);
  assert (select count(*) from private.meine_betrieb_ids()) = 1, 'u1 hat 1 Betrieb';
  assert private.ist_mitglied(b1) = true,  'u1 Mitglied b1';
  assert private.ist_mitglied(b2) = false, 'u1 nicht in b2';
  assert private.kann_schreiben(b1) = true, 'owner darf schreiben';
  assert private.rolle_im_betrieb(b1) = 'owner', 'u1 rolle owner';
  -- Als u2 (viewer):
  perform set_config('app.current_user_id', u2::text, true);
  assert private.kann_schreiben(b1) = false, 'viewer darf NICHT schreiben';
  assert private.ist_mitglied(b1) = true, 'u2 Mitglied b1';
  perform set_config('app.current_user_id', '', true);
  raise exception 'ROLLBACK_OK';  -- erzwingt Rollback, kein Test-Muell bleibt
exception when others then
  if sqlerrm <> 'ROLLBACK_OK' then raise; end if;
end $$;
```
Erwartet: Der Block endet mit `ROLLBACK_OK` (alle Assertions bestanden); keine anderen Fehler.

- [ ] **Step 4: Advisor-Gate**

MCP `get_advisors({project_id:'dcdcohktxbhdxnxjvcyp', type:'security'})`
Erwartet: keine NEUE `function_search_path_mutable`-Warnung für `private.*`.

- [ ] **Step 5: Commit**

```bash
git add bienen_app/supabase/migrations/A03_rls_helper.sql
git commit -m "feat(auth): A03 RLS-Helper (security-definer, search_path='')"
```

---

## Task 4: `handle_new_auth_user`-Trigger (nur Profil, ausfallsicher)

**Files:**
- Create: `bienen_app/supabase/migrations/A04_profil_trigger.sql`

- [ ] **Step 1: Migration-Datei schreiben**

```sql
-- A04_profil_trigger.sql | Beim Supabase-Signup automatisch profiles-Zeile.
-- BEWUSST minimal: kein Invitation-Claim hier (entkoppelt, A06 einladung_annehmen),
-- damit ein Fehler NIE den Signup blockiert ("Database error saving new user").
create or replace function public.handle_new_auth_user() returns trigger
  language plpgsql security definer set search_path = '' as $$
begin
  insert into public.profiles (id, email, display_name)
  values (new.id, new.email,
          coalesce(new.raw_user_meta_data ->> 'display_name', new.email))
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_auth_user();
```

- [ ] **Step 2: Anwenden** — `apply_migration(name:'A04_profil_trigger', query:<inhalt>)`. Erwartet: success.

- [ ] **Step 3: Test (Signup legt Profil an, idempotent)**

```sql
do $$
declare u uuid := gen_random_uuid();
begin
  insert into auth.users (id, email) values (u, 'neu@test.ch');
  assert exists(select 1 from public.profiles where id=u and email='neu@test.ch'), 'Profil angelegt';
  -- zweiter Insert derselben id (on conflict) darf nicht crashen
  insert into public.profiles (id,email) values (u,'neu@test.ch') on conflict (id) do nothing;
  raise exception 'ROLLBACK_OK';
exception when others then if sqlerrm <> 'ROLLBACK_OK' then raise; end if;
end $$;
```
Erwartet: endet mit `ROLLBACK_OK`.

- [ ] **Step 4: Commit**

```bash
git add bienen_app/supabase/migrations/A04_profil_trigger.sql
git commit -m "feat(auth): A04 handle_new_auth_user (nur Profil)"
```

---

## Task 5: Auth-Hook `custom_access_token` (JWT-Claim `betrieb_id`+`rolle`)

**Files:**
- Create: `bienen_app/supabase/migrations/A05_auth_hook.sql`

- [ ] **Step 1: Migration-Datei schreiben**

```sql
-- A05_auth_hook.sql | Custom Access Token Hook (Muster KMU 0011/0013):
-- setzt app_metadata.betrieb_id + app_metadata.rolle der aeltesten Mitgliedschaft.
-- MUSS im Dashboard unter Auth > Hooks aktiviert werden (Config-Schritt in Plan 3).
create or replace function public.custom_access_token(event jsonb) returns jsonb
  language plpgsql stable set search_path = '' as $$
declare
  v_betrieb uuid;
  v_rolle public.betrieb_rolle;
  claims jsonb;
begin
  select bm.betrieb_id, bm.rolle into v_betrieb, v_rolle
    from public.betrieb_mitglieder bm
   where bm.user_id = (event ->> 'user_id')::uuid and bm.is_deleted = false
   order by bm.created_at   -- deterministisch: aelteste Mitgliedschaft gewinnt
   limit 1;                 -- Pilot: genau eine Mitgliedschaft pro Nutzer
  claims := coalesce(event -> 'claims', '{}'::jsonb);
  if v_betrieb is not null then
    if jsonb_typeof(claims -> 'app_metadata') is distinct from 'object' then
      claims := jsonb_set(claims, '{app_metadata}', '{}'::jsonb);
    end if;
    claims := jsonb_set(claims, '{app_metadata,betrieb_id}', to_jsonb(v_betrieb::text));
    claims := jsonb_set(claims, '{app_metadata,rolle}',      to_jsonb(v_rolle::text));
  end if;
  return jsonb_set(event, '{claims}', claims);
end;
$$;

-- Nur der Auth-Server ruft den Hook auf; er hat KEIN bypassrls -> Grant + Policy noetig.
grant usage on schema public to supabase_auth_admin;
grant execute on function public.custom_access_token(jsonb) to supabase_auth_admin;
revoke execute on function public.custom_access_token(jsonb) from authenticated, anon, public;
grant select on table public.betrieb_mitglieder to supabase_auth_admin;
create policy betrieb_mitglieder_auth_admin_select on public.betrieb_mitglieder
  for select to supabase_auth_admin using (true);
```

- [ ] **Step 2: Anwenden** — `apply_migration(name:'A05_auth_hook', query:<inhalt>)`. Erwartet: success.

- [ ] **Step 3: Test (Hook setzt Claim)**

```sql
do $$
declare b uuid; u uuid := gen_random_uuid(); res jsonb;
begin
  insert into public.betriebe (name) values ('HookT') returning id into b;
  insert into auth.users (id,email) values (u,'hook@test.ch');
  insert into public.profiles (id,email) values (u,'hook@test.ch') on conflict (id) do nothing;
  insert into public.betrieb_mitglieder (betrieb_id,user_id,rolle) values (b,u,'owner');
  res := public.custom_access_token(jsonb_build_object(
           'user_id', u::text, 'claims', '{}'::jsonb));
  assert (res #>> '{claims,app_metadata,betrieb_id}') = b::text, 'betrieb_id-Claim gesetzt';
  assert (res #>> '{claims,app_metadata,rolle}') = 'owner', 'rolle-Claim gesetzt';
  -- Produktionspfad absichern: execute_sql laeuft als postgres/bypassrls und kann
  -- supabase_auth_admin NICHT per SET ROLE annehmen -> der Grant/Policy-Pfad, den der
  -- Auth-Server (rolbypassrls=false) real braucht, wird STATISCH geprueft (sonst
  -- bliebe der Test gruen, obwohl der Hook in Produktion leere Claims lieferte).
  assert has_schema_privilege('supabase_auth_admin','public','USAGE'),
         'supabase_auth_admin fehlt USAGE auf schema public';
  assert has_function_privilege('supabase_auth_admin','public.custom_access_token(jsonb)','EXECUTE'),
         'supabase_auth_admin fehlt EXECUTE auf custom_access_token';
  assert has_table_privilege('supabase_auth_admin','public.betrieb_mitglieder','SELECT'),
         'supabase_auth_admin fehlt SELECT auf betrieb_mitglieder';
  assert exists (select 1 from pg_policies
           where schemaname='public' and tablename='betrieb_mitglieder'
             and policyname='betrieb_mitglieder_auth_admin_select'
             and 'supabase_auth_admin' = any(roles)),
         'Policy betrieb_mitglieder_auth_admin_select fuer supabase_auth_admin fehlt';
  raise exception 'ROLLBACK_OK';
exception when others then if sqlerrm <> 'ROLLBACK_OK' then raise; end if;
end $$;
```
Erwartet: endet mit `ROLLBACK_OK`.

- [ ] **Step 4: Commit**

```bash
git add bienen_app/supabase/migrations/A05_auth_hook.sql
git commit -m "feat(auth): A05 custom_access_token Auth-Hook (betrieb_id/rolle-Claim)"
```

---

## Task 6: RPCs (Gründung, Einladungen, Team, Owner-Guard, letzter-Owner-Schutz)

**Files:**
- Create: `bienen_app/supabase/migrations/A06_rpcs.sql`

- [ ] **Step 1: Migration-Datei schreiben**

```sql
-- A06_rpcs.sql | Selbst-Gruendung + code-basierte Einladungen (Muster KMU 0012/0013).
-- Stabile errcodes BA0xx (Client matcht Codes, nie Prosa). DEFINER umgeht das RLS-Henne-Ei.

-- Owner-Guard: Betrieb des Aufrufers + Owner-Pruefung.
create or replace function public.eigener_betrieb_als_owner() returns uuid
  language plpgsql stable set search_path = '' as $$
declare v_betrieb uuid; v_rolle public.betrieb_rolle;
begin
  select bm.betrieb_id, bm.rolle into v_betrieb, v_rolle
    from public.betrieb_mitglieder bm
   where bm.user_id = auth.uid() and bm.is_deleted = false
   order by bm.created_at limit 1;
  if v_betrieb is null then raise exception 'Kein Betrieb zugeordnet' using errcode='BA004'; end if;
  if v_rolle <> 'owner' then
    raise exception 'Nur Owner duerfen Mitglieder verwalten' using errcode='BA010';
  end if;
  return v_betrieb;
end; $$;
revoke execute on function public.eigener_betrieb_als_owner() from anon, public;
grant execute on function public.eigener_betrieb_als_owner() to authenticated;

-- Selbst-Gruendung: atomar Betrieb + owner-Mitgliedschaft.
create or replace function public.betrieb_gruenden(p_name text) returns uuid
  language plpgsql security definer set search_path = '' as $$
declare v_user uuid := auth.uid(); v_betrieb uuid;
begin
  if v_user is null then raise exception 'Nicht angemeldet' using errcode='BA001'; end if;
  if coalesce(trim(p_name),'') = '' then raise exception 'Name darf nicht leer sein' using errcode='BA002'; end if;
  perform pg_advisory_xact_lock(hashtextextended('betrieb_gruenden:'||v_user::text, 0));
  if exists (select 1 from public.betrieb_mitglieder where user_id=v_user and is_deleted=false) then
    raise exception 'Du gehoerst bereits zu einem Betrieb' using errcode='BA003';
  end if;
  insert into public.betriebe (name) values (trim(p_name)) returning id into v_betrieb;
  insert into public.betrieb_mitglieder (betrieb_id,user_id,rolle) values (v_betrieb,v_user,'owner');
  return v_betrieb;
end; $$;
revoke execute on function public.betrieb_gruenden(text) from anon, public;
grant execute on function public.betrieb_gruenden(text) to authenticated;

-- Einladen: erzeugt 12-Zeichen-Code (Crockford-Base32), speichert NUR den Hash,
-- gibt Klartext EINMALIG zurueck. Owner kann editor/viewer einladen.
create or replace function public.mitglied_einladen(p_email text, p_rolle public.betrieb_rolle)
  returns text language plpgsql security definer set search_path = '' as $$
declare
  v_betrieb uuid; v_email text := lower(trim(p_email));
  v_code text := ''; v_alphabet constant text := '0123456789ABCDEFGHJKMNPQRSTVWXYZ';
  v_bytes bytea; i int;
begin
  v_betrieb := public.eigener_betrieb_als_owner();  -- BA004/BA010
  if v_email = '' or position('@' in v_email) = 0 then
    raise exception 'E-Mail fehlt oder ist ungueltig' using errcode='BA012';
  end if;
  if p_rolle is null or p_rolle not in ('editor'::public.betrieb_rolle,'viewer'::public.betrieb_rolle) then
    raise exception 'Diese Rolle kann nicht eingeladen werden' using errcode='BA010';
  end if;
  update public.einladungen set status='widerrufen'
    where betrieb_id=v_betrieb and lower(email)=v_email and status='offen';
  v_bytes := extensions.gen_random_bytes(12);
  for i in 0..11 loop
    v_code := v_code || substr(v_alphabet, (get_byte(v_bytes,i) % 32) + 1, 1);
  end loop;
  insert into public.einladungen (betrieb_id,email,rolle,code_hash,eingeladen_von)
    values (v_betrieb, v_email, p_rolle,
            encode(extensions.digest(v_code,'sha256'),'hex'), auth.uid());
  return substr(v_code,1,4)||'-'||substr(v_code,5,4)||'-'||substr(v_code,9,4);
end; $$;
revoke execute on function public.mitglied_einladen(text, public.betrieb_rolle) from anon, public;
grant execute on function public.mitglied_einladen(text, public.betrieb_rolle) to authenticated;

-- Annehmen: DEFINER (Aufrufer ist noch membership-los). Eigentumsnachweis via auth.email().
create or replace function public.einladung_annehmen(p_code text)
  returns void language plpgsql security definer set search_path = '' as $$
declare
  v_user uuid := auth.uid(); v_email text := lower(coalesce(auth.email(),''));
  v_norm text := upper(replace(replace(trim(p_code),'-',''),' ',''));
  v_einladung public.einladungen%rowtype;
begin
  if v_user is null then raise exception 'Nicht angemeldet' using errcode='BA001'; end if;
  select * into v_einladung from public.einladungen
    where code_hash = encode(extensions.digest(v_norm,'sha256'),'hex');
  if v_einladung.id is null or v_einladung.status <> 'offen' or v_einladung.ablauf_am < now() then
    raise exception 'Einladungs-Code ungueltig oder abgelaufen' using errcode='BA007';
  end if;
  if lower(v_einladung.email) <> v_email then
    raise exception 'Dieses Konto gehoert nicht zur eingeladenen E-Mail' using errcode='BA008';
  end if;
  perform pg_advisory_xact_lock(hashtextextended('betrieb_gruenden:'||v_user::text, 0));
  if exists (select 1 from public.betrieb_mitglieder where user_id=v_user and is_deleted=false) then
    raise exception 'Du gehoerst bereits zu einem Betrieb' using errcode='BA009';
  end if;
  update public.einladungen set status='angenommen', angenommen_von=v_user
    where id=v_einladung.id and status='offen';
  if not found then raise exception 'Einladungs-Code ungueltig oder abgelaufen' using errcode='BA007'; end if;
  insert into public.betrieb_mitglieder (betrieb_id,user_id,rolle)
    values (v_einladung.betrieb_id, v_user, v_einladung.rolle);
end; $$;
revoke execute on function public.einladung_annehmen(text) from anon, public;
grant execute on function public.einladung_annehmen(text) to authenticated;

create or replace function public.einladung_widerrufen(p_id uuid)
  returns void language plpgsql security definer set search_path = '' as $$
declare v_betrieb uuid;
begin
  v_betrieb := public.eigener_betrieb_als_owner();
  update public.einladungen set status='widerrufen'
    where id=p_id and betrieb_id=v_betrieb and status='offen';
  if not found then raise exception 'Einladung nicht gefunden oder nicht mehr offen' using errcode='BA007'; end if;
end; $$;
revoke execute on function public.einladung_widerrufen(uuid) from anon, public;
grant execute on function public.einladung_widerrufen(uuid) to authenticated;

-- Team-Liste inkl. E-Mail (jedes Mitglied sieht sein Team).
create or replace function public.team_mitglieder()
  returns table (user_id uuid, email text, rolle public.betrieb_rolle, created_at timestamptz)
  language plpgsql stable security definer set search_path = '' as $$
declare v_betrieb uuid;
begin
  select bm.betrieb_id into v_betrieb from public.betrieb_mitglieder bm
    where bm.user_id = auth.uid() and bm.is_deleted = false
    order by bm.created_at limit 1;
  if v_betrieb is null then raise exception 'Kein Betrieb zugeordnet' using errcode='BA004'; end if;
  return query
    select bm.user_id, p.email, bm.rolle, bm.created_at
      from public.betrieb_mitglieder bm
      join public.profiles p on p.id = bm.user_id
     where bm.betrieb_id = v_betrieb and bm.is_deleted = false
     order by bm.created_at;
end; $$;
revoke execute on function public.team_mitglieder() from anon, public;
grant execute on function public.team_mitglieder() to authenticated;

-- Schutz gegen verwaisten Betrieb: letzter owner nicht entfernbar/degradierbar.
create or replace function private.enforce_last_owner() returns trigger
  language plpgsql security definer set search_path = '' as $$
declare v_betrieb uuid; v_owner_count int;
begin
  if tg_op = 'DELETE' then
    if old.rolle <> 'owner' then return old; end if;
    if not exists (select 1 from public.betriebe b where b.id = old.betrieb_id) then
      return old;  -- Cascade-Loeschung des Betriebs: durchlassen
    end if;
    v_betrieb := old.betrieb_id;
  else -- UPDATE
    -- Guard greift, wenn eine AKTIVE owner-Zeile ihren Aktiv-owner-Status verliert —
    -- egal ob durch Rollen-Degradierung ODER Soft-Delete (is_deleted false->true).
    if not (old.rolle = 'owner' and old.is_deleted = false) then return new; end if;  -- war kein aktiver Owner
    if new.rolle = 'owner' and new.is_deleted = false then return new; end if;         -- bleibt aktiver Owner
    v_betrieb := old.betrieb_id;
  end if;
  select count(*) into v_owner_count from public.betrieb_mitglieder m
    where m.betrieb_id = v_betrieb and m.rolle = 'owner' and m.is_deleted = false
      and not (m.betrieb_id = old.betrieb_id and m.user_id = old.user_id);
  if v_owner_count = 0 then
    raise exception 'Letzter Owner des Betriebs kann nicht entfernt/degradiert werden'
      using errcode = 'BA013';
  end if;
  return case when tg_op='DELETE' then old else new end;
end; $$;
create trigger trg_enforce_last_owner
  before update or delete on public.betrieb_mitglieder
  for each row execute function private.enforce_last_owner();
```

- [ ] **Step 2: Anwenden** — `apply_migration(name:'A06_rpcs', query:<inhalt>)`. Erwartet: success.

- [ ] **Step 3: Test (Gründung + Einladung + Annehmen End-to-End, simulierte JWTs)**

```sql
do $$
declare u_owner uuid := gen_random_uuid(); u_editor uuid := gen_random_uuid();
        v_betrieb uuid; v_code text;
begin
  insert into auth.users (id,email) values (u_owner,'owner@test.ch'),(u_editor,'editor@test.ch');
  insert into public.profiles (id,email) values (u_owner,'owner@test.ch'),(u_editor,'editor@test.ch') on conflict (id) do nothing;
  -- Gruendung als u_owner:
  perform set_config('request.jwt.claims', json_build_object('sub',u_owner)::text, true);
  v_betrieb := public.betrieb_gruenden('Imkerei Test');
  assert (select rolle from public.betrieb_mitglieder where betrieb_id=v_betrieb and user_id=u_owner)='owner', 'owner angelegt';
  -- Doppelgruendung -> BA003:
  begin v_betrieb := public.betrieb_gruenden('Zweiter'); assert false,'haette BA003 werfen muessen';
  exception when others then assert sqlstate='BA003','Doppelgruendung BA003'; end;
  -- Einladung fuer editor@test.ch:
  v_code := public.mitglied_einladen('EDITOR@test.ch','editor');   -- Case-insensitive
  assert v_code ~ '^[0-9A-Z]{4}-[0-9A-Z]{4}-[0-9A-Z]{4}$', 'Code-Format';
  assert (select count(*) from public.einladungen where lower(email)='editor@test.ch' and status='offen')=1,'1 offene Einladung';
  -- Annehmen als u_editor:
  perform set_config('request.jwt.claims', json_build_object('sub',u_editor,'email','editor@test.ch')::text, true);
  perform public.einladung_annehmen(v_code);
  assert (select rolle from public.betrieb_mitglieder where betrieb_id=v_betrieb and user_id=u_editor)='editor','editor beigetreten';
  assert (select status from public.einladungen where lower(email)='editor@test.ch')='angenommen','Einladung angenommen';
  -- Falsche E-Mail -> BA008 (neuer Code, anderes Konto):
  perform set_config('request.jwt.claims', json_build_object('sub',u_owner)::text, true);
  v_code := public.mitglied_einladen('fremd@test.ch','viewer');
  perform set_config('request.jwt.claims', json_build_object('sub',u_editor,'email','editor@test.ch')::text, true);
  begin perform public.einladung_annehmen(v_code); assert false,'haette BA008/BA009 werfen muessen';
  exception when others then assert sqlstate in ('BA008','BA009'),'falsche Mail/schon Mitglied'; end;
  perform set_config('request.jwt.claims','', true);
  raise exception 'ROLLBACK_OK';
exception when others then if sqlerrm <> 'ROLLBACK_OK' then raise; end if;
end $$;
```
Erwartet: endet mit `ROLLBACK_OK`.

- [ ] **Step 4: Test (letzter Owner geschützt)**

```sql
do $$
declare b uuid; u uuid := gen_random_uuid();
begin
  insert into public.betriebe (name) values ('LO') returning id into b;
  insert into auth.users (id,email) values (u,'lo@test.ch');
  insert into public.profiles (id,email) values (u,'lo@test.ch') on conflict (id) do nothing;
  insert into public.betrieb_mitglieder (betrieb_id,user_id,rolle) values (b,u,'owner');
  -- (a) Rollen-Degradierung des letzten Owners -> BA013
  begin
    update public.betrieb_mitglieder set rolle='editor' where betrieb_id=b and user_id=u;
    assert false, 'Degradierung haette BA013 werfen muessen';
  exception when others then assert sqlstate='BA013','letzter owner degradieren BA013'; end;
  -- (b) Soft-Delete des letzten Owners -> BA013
  begin
    update public.betrieb_mitglieder set is_deleted=true where betrieb_id=b and user_id=u;
    assert false, 'Soft-Delete haette BA013 werfen muessen';
  exception when others then assert sqlstate='BA013','letzter owner soft-delete BA013'; end;
  raise exception 'ROLLBACK_OK';
exception when others then if sqlerrm <> 'ROLLBACK_OK' then raise; end if;
end $$;
```
Erwartet: endet mit `ROLLBACK_OK`.

- [ ] **Step 5: Advisor-Gate** — `get_advisors(type:'security')`. Erwartet: keine neue `function_search_path_mutable`.

- [ ] **Step 6: Commit**

```bash
git add bienen_app/supabase/migrations/A06_rpcs.sql
git commit -m "feat(auth): A06 RPCs (betrieb_gruenden, Einladungen, team, last-owner-guard)"
```

---

## Task 7: RLS-Policies auf den Tenancy-Tabellen

**Files:**
- Create: `bienen_app/supabase/migrations/A07_tenancy_rls.sql`

- [ ] **Step 1: Migration-Datei schreiben**

```sql
-- A07_tenancy_rls.sql | RLS auf betriebe/profiles/betrieb_mitglieder/einladungen.
-- Schreiben auf betriebe/betrieb_mitglieder/einladungen NUR via DEFINER-RPCs
-- (bewusst KEINE authenticated-INSERT-Policy -> kein Selbst-Insert in fremde Betriebe).

-- betriebe: sehen = Mitglied; aendern = owner.
create policy betriebe_select on public.betriebe for select to authenticated
  using (id in (select private.meine_betrieb_ids()));
create policy betriebe_update_owner on public.betriebe for update to authenticated
  using (private.rolle_im_betrieb(id) = 'owner')
  with check (private.rolle_im_betrieb(id) = 'owner');

-- profiles: self + Betriebskollegen lesen; nur eigene Zeile aendern.
create policy profiles_select on public.profiles for select to authenticated
  using (id = (select auth.uid()) or private.teilt_betrieb(id));
create policy profiles_update_self on public.profiles for update to authenticated
  using (id = (select auth.uid())) with check (id = (select auth.uid()));
-- email immutabel: nur display_name per Client aenderbar.
revoke update on public.profiles from authenticated;
grant update (display_name) on public.profiles to authenticated;

-- betrieb_mitglieder: sehen = eigener Betrieb; aendern/loeschen = NUR owner
-- (nie kann_schreiben -> sonst Self-Escalation). Insert nur via DEFINER-RPCs.
create policy betrieb_mitglieder_select on public.betrieb_mitglieder for select to authenticated
  using (betrieb_id in (select private.meine_betrieb_ids()));
create policy betrieb_mitglieder_update_owner on public.betrieb_mitglieder for update to authenticated
  using (private.rolle_im_betrieb(betrieb_id) = 'owner')
  with check (private.rolle_im_betrieb(betrieb_id) = 'owner');
create policy betrieb_mitglieder_delete_owner on public.betrieb_mitglieder for delete to authenticated
  using (private.rolle_im_betrieb(betrieb_id) = 'owner');

-- einladungen: nur owner des Betriebs sieht sie; Schreiben nur via DEFINER-RPCs.
create policy einladungen_select_owner on public.einladungen for select to authenticated
  using (private.rolle_im_betrieb(betrieb_id) = 'owner');
```

- [ ] **Step 2: Anwenden** — `apply_migration(name:'A07_tenancy_rls', query:<inhalt>)`. Erwartet: success.

- [ ] **Step 3: Test (Isolation + kein Selbst-Insert)**

```sql
do $$
declare bA uuid; uA uuid := gen_random_uuid(); uX uuid := gen_random_uuid();
begin
  insert into public.betriebe (name) values ('A') returning id into bA;
  insert into auth.users (id,email) values (uA,'a@test.ch'),(uX,'x@test.ch');
  insert into public.profiles (id,email) values (uA,'a@test.ch'),(uX,'x@test.ch') on conflict (id) do nothing;
  insert into public.betrieb_mitglieder (betrieb_id,user_id,rolle) values (bA,uA,'owner');
  -- uX ist Fremder: darf sich NICHT selbst als owner in bA eintragen.
  set local role authenticated;
  perform set_config('request.jwt.claims', json_build_object('sub',uX,'role','authenticated')::text, true);
  begin
    insert into public.betrieb_mitglieder (betrieb_id,user_id,rolle) values (bA,uX,'owner');
    assert false, 'Fremder Selbst-Insert haette scheitern muessen (RLS)';
  exception when insufficient_privilege or others then null; -- erwartet: RLS blockt
  end;
  -- uX sieht Betrieb A nicht:
  assert (select count(*) from public.betriebe where id=bA) = 0, 'uX sieht bA nicht';
  reset role;
  perform set_config('request.jwt.claims','', true);
  raise exception 'ROLLBACK_OK';
exception when others then if sqlerrm <> 'ROLLBACK_OK' then raise; end if;
end $$;
```
Erwartet: endet mit `ROLLBACK_OK`. (Hinweis: `set local role authenticated` + `request.jwt.claims` gelten nur innerhalb der Transaktion; `reset role` vor dem erzwungenen Rollback.)

- [ ] **Step 4: Advisor-Gate** — `get_advisors(type:'security')`. Erwartet: keine neue `rls_disabled_in_public` (alle 4 Tenancy-Tabellen haben RLS + ≥1 Policy).

- [ ] **Step 5: Commit**

```bash
git add bienen_app/supabase/migrations/A07_tenancy_rls.sql
git commit -m "feat(auth): A07 RLS-Policies Tenancy-Tabellen"
```

---

## Task 8: `betrieb_id`/`created_by`/`updated_by` + Trigger auf den 8 Bestandstabellen

**Files:**
- Create: `bienen_app/supabase/migrations/A08_fachtabellen_spalten.sql`

- [ ] **Step 1: Migration-Datei schreiben**

```sql
-- A08_fachtabellen_spalten.sql | betrieb_id (NULLABLE, ohne Default), created_by/updated_by
-- + Trigger auf allen 8 Bestandstabellen. NOT NULL/Default erst im Bootstrap (Plan 3).

-- (a) Spalten + Indizes fuer alle 8 Tabellen.
do $$
declare t text;
begin
  foreach t in array array['materials','material_purchases','weight_readings','scales',
                           'scale_alerts','funkstationen','voelker','construction_steps'] loop
    execute format('alter table public.%I add column if not exists betrieb_id uuid', t);
    execute format('alter table public.%I add column if not exists created_by uuid', t);
    execute format('alter table public.%I add column if not exists updated_by uuid', t);
    execute format('create index if not exists idx_%s_betrieb on public.%I (betrieb_id)', t, t);
  end loop;
end $$;

-- (b) Actor-Trigger: created_by/updated_by serverseitig erzwingen (nicht Client-spoofbar),
-- created_by + betrieb_id bei UPDATE immutabel. Fasst NUR die drei Spalten an, die A08
-- auf ALLE 8 Tabellen legt (created_by/updated_by/betrieb_id) — NICHT created_at/updated_at,
-- weil scales/weight_readings/scale_alerts/material_purchases kein updated_at (und die
-- Zeitreihen kein created_at) haben; updated_at bleibt den bestehenden updated_at-Triggern
-- ueberlassen. SECURITY DEFINER, damit auch der aktuelle anon-Pfad (vor Cutover) ohne
-- private-Grant funktioniert; auth.uid()/current_app_user() liest weiterhin den echten
-- Request-User.
create or replace function private.set_row_actor() returns trigger
  language plpgsql security definer set search_path = '' as $$
begin
  if tg_op = 'INSERT' then
    new.created_by := private.current_app_user();
    new.updated_by := private.current_app_user();
  else -- UPDATE
    new.created_by := old.created_by;      -- created_by immutabel
    new.betrieb_id := old.betrieb_id;      -- betrieb_id einfrieren
    new.updated_by := private.current_app_user();
  end if;
  return new;
end; $$;

-- (c) betrieb_id-Ableitung fuer die maschinellen Zeitreihen aus der Waage
-- (Service-Role-Cron ohne auth.uid()). KEIN RAISE in der nullable-Phase; die
-- NOT-NULL-Constraint (Bootstrap) sichert es hart ab.
create or replace function private.set_wr_betrieb() returns trigger
  language plpgsql security definer set search_path = '' as $$
begin
  if new.betrieb_id is null and new.scale_id is not null then
    select s.betrieb_id into new.betrieb_id from public.scales s where s.id = new.scale_id;
  end if;
  return new;
end; $$;
create or replace function private.set_sa_betrieb() returns trigger
  language plpgsql security definer set search_path = '' as $$
begin
  if new.betrieb_id is null and new.scale_id is not null then
    select s.betrieb_id into new.betrieb_id from public.scales s where s.id = new.scale_id;
  end if;
  if new.betrieb_id is null and new.weight_reading_id is not null then
    select wr.betrieb_id into new.betrieb_id
      from public.weight_readings wr where wr.id = new.weight_reading_id;
  end if;
  return new;
end; $$;

-- (d) Actor-Trigger anhaengen (alle 8). Bestehende updated_at-Trigger bleiben unangetastet
-- (set_row_actor fasst updated_at NICHT an) -> kein Doppel-Set, kein Bruch auf Tabellen
-- ohne updated_at.
do $$
declare t text;
begin
  foreach t in array array['materials','material_purchases','weight_readings','scales',
                           'scale_alerts','funkstationen','voelker','construction_steps'] loop
    execute format('drop trigger if exists trg_%s_actor on public.%I', t, t);
    execute format('create trigger trg_%s_actor before insert or update on public.%I '
                || 'for each row execute function private.set_row_actor()', t, t);
  end loop;
end $$;
create trigger trg_wr_betrieb before insert on public.weight_readings
  for each row execute function private.set_wr_betrieb();
create trigger trg_sa_betrieb before insert on public.scale_alerts
  for each row execute function private.set_sa_betrieb();
```

- [ ] **Step 2: Anwenden** — `apply_migration(name:'A08_fachtabellen_spalten', query:<inhalt>)`. Erwartet: success.

- [ ] **Step 3: Test (Spalten da; created_by wird gesetzt & ist immutabel; anon-Insert bricht nicht)**

```sql
do $$
declare u uuid := gen_random_uuid(); v_id uuid;
begin
  -- Spalten vorhanden auf allen 8?
  assert (select count(*) from information_schema.columns
          where table_schema='public' and column_name='betrieb_id'
            and table_name in ('materials','material_purchases','weight_readings','scales',
              'scale_alerts','funkstationen','voelker','construction_steps')) = 8, '8x betrieb_id';
  -- INSERT setzt created_by aus dem Request-User:
  perform set_config('request.jwt.claims', json_build_object('sub',u)::text, true);
  insert into public.voelker (name) values ('Testvolk') returning id into v_id;
  assert (select created_by from public.voelker where id=v_id) = u, 'created_by gesetzt';
  -- UPDATE friert created_by/betrieb_id ein:
  update public.voelker set name='Neu', created_by=gen_random_uuid(), betrieb_id=gen_random_uuid() where id=v_id;
  assert (select created_by from public.voelker where id=v_id) = u, 'created_by immutabel';
  assert (select betrieb_id from public.voelker where id=v_id) is null, 'betrieb_id nicht spoofbar (bleibt null)';
  perform set_config('request.jwt.claims','', true);
  raise exception 'ROLLBACK_OK';
exception when others then if sqlerrm <> 'ROLLBACK_OK' then raise; end if;
end $$;
```
Erwartet: endet mit `ROLLBACK_OK`.

- [ ] **Step 4: Commit**

```bash
git add bienen_app/supabase/migrations/A08_fachtabellen_spalten.sql
git commit -m "feat(auth): A08 betrieb_id/created_by/updated_by + Trigger (8 Tabellen)"
```

---

## Task 9: Additive `authenticated`-RLS-Policies auf den 8 Bestandstabellen

**Files:**
- Create: `bienen_app/supabase/migrations/A09_fachtabellen_rls.sql`

- [ ] **Step 1: Migration-Datei schreiben**

```sql
-- A09_fachtabellen_rls.sql | STRIKTE authenticated-Policies ZUSAETZLICH zu den
-- bestehenden public-Policies. Postgres OR-verknuepft permissive Policies je Kommando
-- -> nichts bricht, bis die public-Policies im Cutover (Plan 3) gedroppt werden.
-- SELECT: Mitglied (Set-Form, performant auf Zeitreihen). Schreiben: owner|editor.
do $$
declare t text;
begin
  foreach t in array array['materials','material_purchases','weight_readings','scales',
                           'scale_alerts','funkstationen','voelker','construction_steps'] loop
    execute format(
      'create policy %I on public.%I for select to authenticated '
      || 'using (betrieb_id in (select private.meine_betrieb_ids()))', t||'_sel_member', t);
    execute format(
      'create policy %I on public.%I for insert to authenticated '
      || 'with check (private.kann_schreiben(betrieb_id))', t||'_ins_writer', t);
    execute format(
      'create policy %I on public.%I for update to authenticated '
      || 'using (private.kann_schreiben(betrieb_id)) '
      || 'with check (private.kann_schreiben(betrieb_id))', t||'_upd_writer', t);
    execute format(
      'create policy %I on public.%I for delete to authenticated '
      || 'using (private.kann_schreiben(betrieb_id))', t||'_del_writer', t);
  end loop;
end $$;
```

- [ ] **Step 2: Anwenden** — `apply_migration(name:'A09_fachtabellen_rls', query:<inhalt>)`. Erwartet: success.

- [ ] **Step 3: Test (Bestehende App/anon-Pfad unverändert; authenticated-Mitglied sieht seine Zeilen)**

```sql
do $$
declare b uuid; u uuid := gen_random_uuid(); m_id uuid;
begin
  -- (1) anon sieht dank public-Policy weiterhin ALLE materials (52+):
  set local role anon;
  assert (select count(*) from public.materials) >= 52, 'anon sieht public-materials (nicht gebrochen)';
  reset role;
  -- (2) authenticated-Mitglied kann die neue Policy nutzen (Insert/Select/Update
  -- der eigenen Zeile). Cross-Tenant-/NULL-ISOLATION wird hier NICHT assertiert:
  -- die public-SELECT-Policy (qual=true) gilt bis zum Cutover auch fuer authenticated
  -- (OR-verknuepft) -> authenticated sieht vorerst weiterhin ALLE Zeilen. Die echte
  -- Isolation (`where betrieb_id is null = 0`) wird erst in Plan 3 nach dem Drop der
  -- public-Policies geprueft.
  insert into public.betriebe (name) values ('RLS9') returning id into b;
  insert into auth.users (id,email) values (u,'r9@test.ch');
  insert into public.profiles (id,email) values (u,'r9@test.ch') on conflict (id) do nothing;
  insert into public.betrieb_mitglieder (betrieb_id,user_id,rolle) values (b,u,'editor');
  insert into public.materials (category,name,betrieb_id) values ('X','M-b',b) returning id into m_id;
  set local role authenticated;
  perform set_config('request.jwt.claims',
    json_build_object('sub',u,'role','authenticated',
      'app_metadata', json_build_object('betrieb_id',b::text,'rolle','editor'))::text, true);
  assert (select count(*) from public.materials where id=m_id) = 1, 'editor sieht eigene Zeile';
  -- editor darf schreiben (neue INSERT/UPDATE-Policy greift):
  update public.materials set notes='ok' where id=m_id;
  assert (select notes from public.materials where id=m_id)='ok','editor darf updaten';
  reset role;
  perform set_config('request.jwt.claims','', true);
  raise exception 'ROLLBACK_OK';
exception when others then if sqlerrm <> 'ROLLBACK_OK' then raise; end if;
end $$;
```
Erwartet: endet mit `ROLLBACK_OK`.

- [ ] **Step 4: Commit**

```bash
git add bienen_app/supabase/migrations/A09_fachtabellen_rls.sql
git commit -m "feat(auth): A09 additive authenticated-RLS (8 Tabellen)"
```

---

## Task 10: Additive `authenticated`-Storage-Write-Policies + Listing

**Files:**
- Create: `bienen_app/supabase/migrations/A10_storage.sql`

- [ ] **Step 1: Vorab die heutigen Storage-Policies + Bucket-Namen bestätigen**

MCP `execute_sql`:
```sql
select policyname, cmd, roles from pg_policies where schemaname='storage' and tablename='objects' order by policyname;
```
Erwartet (Referenz): public INSERT/UPDATE für `construction-photos` + `material-receipts`, `material_media_all` (ALL) für `material-media`. Falls abweichend, die Policy-Namen in Step 2 anpassen.

- [ ] **Step 2: Migration-Datei schreiben**

```sql
-- A10_storage.sql | Storage additiv haerten: authenticated-Write-Policies mit
-- <betrieb_id>/-Pfad-Scoping ZUSAETZLICH zu den bestehenden public-Write-Policies.
-- Downloads bleiben public (Foto-Anzeige). public-Write-Policies droppt erst der
-- Cutover (Plan 3). Pfadkonvention ab jetzt: '<betrieb_id>/...'.

-- Helper-Ausdruck: erstes Pfadsegment ist eine betrieb_id, in der der User schreiben darf.
-- (storage.foldername(name))[1] = erstes Segment; Regex-Guard vor dem uuid-Cast.
do $$
declare bkt text;
begin
  foreach bkt in array array['construction-photos','material-media','material-receipts'] loop
    execute format($p$
      create policy %I on storage.objects for insert to authenticated
      with check (bucket_id = %L
        and (storage.foldername(name))[1] ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
        and private.kann_schreiben(((storage.foldername(name))[1])::uuid))
    $p$, 'auth_ins_'||replace(bkt,'-','_'), bkt);
    execute format($p$
      create policy %I on storage.objects for update to authenticated
      using (bucket_id = %L
        and (storage.foldername(name))[1] ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
        and private.kann_schreiben(((storage.foldername(name))[1])::uuid))
      with check (bucket_id = %L
        and (storage.foldername(name))[1] ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
        and private.kann_schreiben(((storage.foldername(name))[1])::uuid))
    $p$, 'auth_upd_'||replace(bkt,'-','_'), bkt, bkt);
    execute format($p$
      create policy %I on storage.objects for delete to authenticated
      using (bucket_id = %L
        and (storage.foldername(name))[1] ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
        and private.kann_schreiben(((storage.foldername(name))[1])::uuid))
    $p$, 'auth_del_'||replace(bkt,'-','_'), bkt);
  end loop;
end $$;
-- Hinweis: private-USAGE + kann_schreiben-EXECUTE fuer authenticated sind aus A01/A03 vorhanden.
```
> **Hinweis:** Die public-Listing-SELECT-Policies bleiben in Migration A bewusst unverändert (Foto-Anzeige über public URL läuft daran vorbei). Der Wechsel Listing→authenticated + Drop der public-Write-Policies passiert im Cutover (Plan 3), nachdem die App nur noch mit `<betrieb_id>/`-Pfaden hochlädt.

- [ ] **Step 3: Anwenden** — `apply_migration(name:'A10_storage', query:<inhalt>)`. Erwartet: success.

- [ ] **Step 4: Verifizieren**

```sql
select count(*) as neue_auth_policies from pg_policies
 where schemaname='storage' and tablename='objects' and roles = '{authenticated}';
```
Erwartet: `neue_auth_policies = 9` (3 Buckets × insert/update/delete).

- [ ] **Step 5: Commit**

```bash
git add bienen_app/supabase/migrations/A10_storage.sql
git commit -m "feat(auth): A10 additive authenticated-Storage-Write-Policies (betrieb_id-Pfad)"
```

---

## Task 11: Vorbestehende Funktionen härten + finales Advisor-Gate

**Files:**
- Create: `bienen_app/supabase/migrations/A11_haertung.sql`

- [ ] **Step 1: Vorbestehende, advisor-geflaggte Funktionen ermitteln**

MCP `execute_sql`:
```sql
select n.nspname, p.proname, pg_get_function_identity_arguments(p.oid) as args, p.proconfig
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace
 where n.nspname='public' and p.prosecdef is not null
   and (p.proconfig is null or not exists (
        select 1 from unnest(p.proconfig) c where c like 'search_path=%'))
 order by 2;
```
Erwartet: listet u.a. das vorbestehende `update_updated_at` (advisor `function_search_path_mutable`). Namen/Signaturen notieren.

- [ ] **Step 2: Migration-Datei schreiben (nur reine Funktionen ohne Tabellen-Refs sicher auf `''`)**

```sql
-- A11_haertung.sql | Vorbestehende, advisor-geflaggte Funktionen search_path pinnen.
-- NUR fuer Funktionen, deren Koerper KEINE unqualifizierten Tabellen referenziert
-- (updated_at-Setzer: nur new.updated_at = now()). Die konkreten Namen/Signaturen aus
-- Step 1 einsetzen. Beispiel fuer den typischen updated_at-Setzer:
alter function public.update_updated_at() set search_path = '';
-- Weitere in Step 1 gefundene reine Trigger-/Utility-Funktionen analog ergaenzen.
```
> **Hinweis:** Falls Step 1 eine Funktion zeigt, die Tabellen unqualifiziert referenziert, NICHT blind auf `''` setzen (würde brechen) — stattdessen `set search_path = public` verwenden oder in einer separaten, getesteten Änderung voll qualifizieren. Für dieses Fundament genügt das Pinnen der reinen updated_at-Setzer.

- [ ] **Step 3: Anwenden** — `apply_migration(name:'A11_haertung', query:<inhalt>)`. Erwartet: success.

- [ ] **Step 4: Finales Security-Advisor-Gate**

MCP `get_advisors({project_id:'dcdcohktxbhdxnxjvcyp', type:'security'})`
Erwartet: **0** `function_search_path_mutable` und **0** `rls_disabled_in_public` auf den in Plan 1 neu erstellten Objekten. Verbleibende Vorwarnungen dokumentieren, aber keine NEUE aus Plan 1.

- [ ] **Step 5: Gesamt-Rauchtest (alle 8 Tabellen als authenticated-Mitglied sichtbar & beschreibbar)**

```sql
do $$
declare b uuid; u uuid := gen_random_uuid();
begin
  insert into public.betriebe (name) values ('Smoke') returning id into b;
  insert into auth.users (id,email) values (u,'smoke@test.ch');
  insert into public.profiles (id,email) values (u,'smoke@test.ch') on conflict (id) do nothing;
  insert into public.betrieb_mitglieder (betrieb_id,user_id,rolle) values (b,u,'owner');
  set local role authenticated;
  perform set_config('request.jwt.claims',
    json_build_object('sub',u,'role','authenticated',
      'app_metadata', json_build_object('betrieb_id',b::text,'rolle','owner'))::text, true);
  -- Insert je Kern-Tabelle mit betrieb_id (Default aktive_betrieb_id() kommt erst im Bootstrap):
  insert into public.voelker (name, betrieb_id) values ('V', b);
  insert into public.materials (category,name,betrieb_id) values ('C','M', b);
  insert into public.construction_steps (step_key, betrieb_id) values ('smoke_'||gen_random_uuid()::text, b);
  assert (select count(*) from public.voelker where betrieb_id=b) = 1, 'voelker sichtbar';
  reset role;
  perform set_config('request.jwt.claims','', true);
  raise exception 'ROLLBACK_OK';
exception when others then if sqlerrm <> 'ROLLBACK_OK' then raise; end if;
end $$;
```
Erwartet: endet mit `ROLLBACK_OK`.

- [ ] **Step 6: Commit**

```bash
git add bienen_app/supabase/migrations/A11_haertung.sql
git commit -m "feat(auth): A11 Funktions-Haertung + finales Advisor-Gate"
```

---

## Abschluss Plan 1

Nach Task 11 ist das DB-Fundament vollständig, getestet und advisor-clean — **die Live-App läuft unverändert weiter** (public-Policies bestehen bis zum Cutover in Plan 3). Es existiert **noch kein Betrieb und kein Backfill** (kommt im Bootstrap, Plan 3, nach Daniels erstem Login).

**Nächste Pläne (nach Ausführung von Plan 1 zu schreiben):**
- **Plan 2 — App-Auth-Schicht (Flutter):** `AuthGateway`/`AuthStatus`/Router-Gate, Login/Register/Bestätigen/Onboarding/Einladungs-Code-Screens, Provider-Invalidierung, `materials`-Auto-Seed entfernen, `betrieb_id`/`<betrieb_id>/`-Upload-Pfade.
- **Plan 3 — Rollout & Cutover:** Dashboard-Config (Auth-Hook aktivieren, Confirm-Email, Site-URL), Daniels Bootstrap (`betrieb_gruenden` + Backfill `WHERE betrieb_id IS NULL` + NOT NULL/Default unter `ACCESS EXCLUSIVE`), authenticated-Rollen-Test-Gate, Migration B (public-Policies droppen + `revoke from anon`), Storage-Listing→authenticated.
