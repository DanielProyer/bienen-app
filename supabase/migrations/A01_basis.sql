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
