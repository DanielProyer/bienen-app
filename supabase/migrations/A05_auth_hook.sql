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
