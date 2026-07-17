-- D01_inspections.sql | Durchsicht/Stockkarte je Volk. Same-Tenant-Komposit-FK auf voelker
-- (ON DELETE CASCADE; voelker wird normal per Status aufgeloest, nicht hart geloescht).
-- View v_letzte_durchsichten (security_invoker) fuer die Voelkerliste (PostgREST kann kein distinct on).

create table if not exists public.inspections (
  id uuid primary key default gen_random_uuid(),
  volk_id uuid not null,
  durchgefuehrt_am date not null default current_date,
  wetter text,
  temperatur_c numeric,
  dauer_min int check (dauer_min is null or dauer_min >= 0),
  weiselzustand text check (weiselzustand in ('weiselrichtig','weisellos','drohnenbruetig','unsicher')),
  koenigin_gesehen boolean not null default false,
  stifte_gesehen boolean not null default false,
  weiselzellen text check (weiselzellen in ('keine','spielnaepfchen','schwarmzellen','nachschaffungszellen')),
  weiselzellen_anzahl int check (weiselzellen_anzahl is null or weiselzellen_anzahl >= 0),
  brutbild text check (brutbild in ('geschlossen','lueckig','bunt','kaum','kein')),
  brut_waben numeric check (brut_waben is null or brut_waben >= 0),
  staerke_wabengassen numeric check (staerke_wabengassen is null or staerke_wabengassen >= 0),
  futter_kg numeric check (futter_kg is null or futter_kg >= 0),
  pollen text check (pollen in ('viel','mittel','wenig','kein')),
  platz text check (platz in ('ok','eng','honigraum_noetig','zu_gross')),
  sanftmut int check (sanftmut is null or sanftmut between 1 and 4),
  wabensitz int check (wabensitz is null or wabensitz between 1 and 4),
  auffaelligkeiten text[] not null default '{}'
    check (auffaelligkeiten <@ array['kalkbrut','sackbrut','faulbrut_verdacht','sauerbrut_verdacht',
                                     'ruhr','raeuberei','wachsmotte','varroa_sichtbar','kahlflug']::text[]),
  massnahmen text,
  naechste_durchsicht_am date,
  foto_urls text[] not null default '{}',
  notiz text,
  betrieb_id uuid not null default private.aktive_betrieb_id()
    references public.betriebe(id) on delete cascade,
  created_by uuid, updated_by uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (betrieb_id, id),
  constraint inspections_volk_fk
    foreign key (betrieb_id, volk_id) references public.voelker (betrieb_id, id) on delete cascade
);

alter table public.inspections enable row level security;
revoke all on public.inspections from anon, public;
grant select, insert, update, delete on public.inspections to authenticated;
create index if not exists idx_inspections_volk_datum
  on public.inspections (betrieb_id, volk_id, durchgefuehrt_am desc);

drop trigger if exists trg_inspections_actor on public.inspections;
create trigger trg_inspections_actor before insert or update
  on public.inspections for each row execute function private.set_row_actor();
drop trigger if exists trg_inspections_updated on public.inspections;
create trigger trg_inspections_updated before update
  on public.inspections for each row execute function private.set_updated_at();

drop policy if exists inspections_sel_member on public.inspections;
create policy inspections_sel_member on public.inspections
  for select to authenticated using (betrieb_id in (select private.meine_betrieb_ids()));
drop policy if exists inspections_ins_writer on public.inspections;
create policy inspections_ins_writer on public.inspections
  for insert to authenticated with check (private.kann_schreiben(betrieb_id));
drop policy if exists inspections_upd_writer on public.inspections;
create policy inspections_upd_writer on public.inspections
  for update to authenticated using (private.kann_schreiben(betrieb_id))
  with check (private.kann_schreiben(betrieb_id));
drop policy if exists inspections_del_writer on public.inspections;
create policy inspections_del_writer on public.inspections
  for delete to authenticated using (private.kann_schreiben(betrieb_id));

drop view if exists public.v_letzte_durchsichten;
create view public.v_letzte_durchsichten with (security_invoker = true) as
  select distinct on (volk_id) *
  from public.inspections
  order by volk_id, durchgefuehrt_am desc, created_at desc;
