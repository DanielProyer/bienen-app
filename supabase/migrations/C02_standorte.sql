-- C02_standorte.sql | Standort-Stammdaten mit kantonalen Registrierungsfeldern.
-- KEIN tvd_betriebsnummer (Bienenstaende werden nicht in der TVD registriert, Recherche 19).
-- unique(betrieb_id,id) als Ziel fuer die Same-Tenant-Komposit-FK aus voelker (C04).

create table if not exists public.standorte (
  id            uuid primary key default gen_random_uuid(),
  name          text not null,
  adresse       text,
  parzelle      text,
  gps_lat       numeric,
  gps_lng       numeric,
  hoehe_m       int,
  kanton        text,
  amtliche_standnummer text,
  inspektionskreis     text,
  status        text not null default 'besetzt'
                  check (status in ('besetzt','unbesetzt','aufgeloest')),
  aufgeloest_am date,
  trachtnotiz   text,
  sperrbezirk   boolean not null default false,
  notes         text,
  sort_order    int not null default 0,
  betrieb_id    uuid not null default private.aktive_betrieb_id()
                  references public.betriebe(id) on delete cascade,
  created_by uuid, updated_by uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (betrieb_id, id)
);

alter table public.standorte enable row level security;
revoke all on public.standorte from anon, public;
grant select, insert, update, delete on public.standorte to authenticated;
create index if not exists idx_standorte_betrieb_sort on public.standorte (betrieb_id, sort_order);

drop trigger if exists trg_standorte_actor on public.standorte;
create trigger trg_standorte_actor before insert or update
  on public.standorte for each row execute function private.set_row_actor();
drop trigger if exists trg_standorte_updated on public.standorte;
create trigger trg_standorte_updated before update
  on public.standorte for each row execute function private.set_updated_at();

drop policy if exists standorte_sel_member on public.standorte;
create policy standorte_sel_member on public.standorte
  for select to authenticated using (betrieb_id in (select private.meine_betrieb_ids()));
drop policy if exists standorte_ins_writer on public.standorte;
create policy standorte_ins_writer on public.standorte
  for insert to authenticated with check (private.kann_schreiben(betrieb_id));
drop policy if exists standorte_upd_writer on public.standorte;
create policy standorte_upd_writer on public.standorte
  for update to authenticated using (private.kann_schreiben(betrieb_id))
  with check (private.kann_schreiben(betrieb_id));
drop policy if exists standorte_del_writer on public.standorte;
create policy standorte_del_writer on public.standorte
  for delete to authenticated using (private.kann_schreiben(betrieb_id));
