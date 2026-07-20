-- J01_phaenologie_beobachtungen.sql | Phänologie-Beobachtungen (Baustein C, Keimzelle 4.20).
-- Je Betrieb/Jahr/Anker EINE beobachtete Zeigerpflanzen-Blüte. Normale CRUD via RLS (kein RPC,
-- kein Soft-Delete, keine Errcodes). Betriebs-Ebene (kein standort_id) — Promotion auf Per-Standort
-- ist NICHT rein additiv (Unique-Rework + NULL-Distinct-/Fallback-Entscheid), siehe decision-log.
-- CHECK immutable + bindet blueh_am ans jahr (make_date) → dump/restore-sicher, keine Zukunfts-/Jahr-Drift.

create table if not exists public.phaenologie_beobachtungen (
  id uuid primary key default gen_random_uuid(),
  jahr int not null,
  anker text not null check (anker in ('fruehjahr','tracht')),
  indikator_key text not null,
  blueh_am date not null,
  betrieb_id uuid not null default private.aktive_betrieb_id()
    references public.betriebe(id) on delete cascade,
  created_by uuid, updated_by uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (betrieb_id, jahr, anker),
  constraint phaeno_jahr_chk check (jahr between 2020 and 2100),
  constraint phaeno_blueh_im_jahr_chk
    check (blueh_am >= make_date(jahr,1,1) and blueh_am <= make_date(jahr,12,31))
);
alter table public.phaenologie_beobachtungen enable row level security;
revoke all on public.phaenologie_beobachtungen from anon, public;
grant select, insert, update, delete on public.phaenologie_beobachtungen to authenticated;

drop trigger if exists trg_phaeno_actor on public.phaenologie_beobachtungen;
create trigger trg_phaeno_actor before insert or update
  on public.phaenologie_beobachtungen for each row execute function private.set_row_actor();
drop trigger if exists trg_phaeno_updated on public.phaenologie_beobachtungen;
create trigger trg_phaeno_updated before update
  on public.phaenologie_beobachtungen for each row execute function private.set_updated_at();

drop policy if exists phaeno_sel_member on public.phaenologie_beobachtungen;
create policy phaeno_sel_member on public.phaenologie_beobachtungen
  for select to authenticated using (betrieb_id in (select private.meine_betrieb_ids()));
drop policy if exists phaeno_ins_writer on public.phaenologie_beobachtungen;
create policy phaeno_ins_writer on public.phaenologie_beobachtungen
  for insert to authenticated with check (private.kann_schreiben(betrieb_id));
drop policy if exists phaeno_upd_writer on public.phaenologie_beobachtungen;
create policy phaeno_upd_writer on public.phaenologie_beobachtungen
  for update to authenticated using (private.kann_schreiben(betrieb_id))
  with check (private.kann_schreiben(betrieb_id));
drop policy if exists phaeno_del_writer on public.phaenologie_beobachtungen;
create policy phaeno_del_writer on public.phaenologie_beobachtungen
  for delete to authenticated using (private.kann_schreiben(betrieb_id));

-- ROLLBACK (Ops, kein Migrationsfile): drop table public.phaenologie_beobachtungen;
