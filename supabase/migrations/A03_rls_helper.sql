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
