-- C01_betriebs_einstellungen.sql | F4-Keimzelle: 1 Zeile je Betrieb, typisierte Defaults.
-- KEIN default private.aktive_betrieb_id(): der Gruender hat beim betrieb_gruenden-Aufruf
-- (BA003-Guard) noch keinen betrieb_id-Claim -> aktive_betrieb_id() = NULL -> PK-Verletzung.
-- betrieb_id kommt explizit (RPC + Backfill). KEINE DELETE-Policy (1:1-Zeile unloeschbar).

create table if not exists public.betriebs_einstellungen (
  betrieb_id                 uuid primary key references public.betriebe(id) on delete cascade,
  rasse_default              text,
  beutensystem_default       text,
  hoehe_default_m            int,
  saison_offset_default_tage int  not null default 0,
  kanton                     text,
  imker_identnummer          text,
  created_by  uuid,
  updated_by  uuid,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

alter table public.betriebs_einstellungen enable row level security;
revoke all on public.betriebs_einstellungen from anon, public;
grant select, insert, update on public.betriebs_einstellungen to authenticated;

drop trigger if exists trg_betriebs_einstellungen_actor on public.betriebs_einstellungen;
create trigger trg_betriebs_einstellungen_actor before insert or update
  on public.betriebs_einstellungen for each row execute function private.set_row_actor();
drop trigger if exists trg_betriebs_einstellungen_updated on public.betriebs_einstellungen;
create trigger trg_betriebs_einstellungen_updated before update
  on public.betriebs_einstellungen for each row execute function private.set_updated_at();

drop policy if exists betriebs_einstellungen_sel_member on public.betriebs_einstellungen;
create policy betriebs_einstellungen_sel_member on public.betriebs_einstellungen
  for select to authenticated using (betrieb_id in (select private.meine_betrieb_ids()));
drop policy if exists betriebs_einstellungen_ins_writer on public.betriebs_einstellungen;
create policy betriebs_einstellungen_ins_writer on public.betriebs_einstellungen
  for insert to authenticated with check (private.kann_schreiben(betrieb_id));
drop policy if exists betriebs_einstellungen_upd_writer on public.betriebs_einstellungen;
create policy betriebs_einstellungen_upd_writer on public.betriebs_einstellungen
  for update to authenticated using (private.kann_schreiben(betrieb_id))
  with check (private.kann_schreiben(betrieb_id));

-- betrieb_gruenden additiv erweitern: legt die Einstellungs-Zeile mit EXPLIZITER betrieb_id an.
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
  insert into public.betriebs_einstellungen (betrieb_id) values (v_betrieb);
  return v_betrieb;
end; $$;
revoke execute on function public.betrieb_gruenden(text) from anon, public;
grant execute on function public.betrieb_gruenden(text) to authenticated;

-- Idempotenter Backfill fuer bestehende Betriebe (Neutralwerte, kein Arosa-Hardcode).
insert into public.betriebs_einstellungen (betrieb_id)
  select id from public.betriebe on conflict (betrieb_id) do nothing;
