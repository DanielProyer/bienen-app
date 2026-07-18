-- G01_gesundheitsereignisse.sql | Diagnose-/Gesundheits-Journal je Volk (Bestandeskontroll-Spur).
-- Soft-Delete/Storno (KEIN Immutable-Trigger, KEIN RPC), volk-FK ON DELETE RESTRICT, keine DELETE-Policy.
-- krankheit-CHECK = 17 Katalog-Keys (Dart-Paritaet via Test, M3). status=gemeldet erzwingt gemeldet_am
-- (M2: einzige DB-Invariante, da kein RPC-Gatekeeper). Keine neuen Errcodes.

create table if not exists public.gesundheitsereignisse (
  id uuid primary key default gen_random_uuid(),
  volk_id uuid not null,
  festgestellt_am date not null default current_date,
  krankheit text not null check (krankheit in (
    'afb','efb','kleiner_beutenkaefer','tropilaelaps','varroa','kalkbrut','steinbrut','sackbrut',
    'nosema','ruhr','viren','wachsmotte','braula','tracheenmilbe','vergiftung','vespa_velutina','sonstige')),
  schweregrad text check (schweregrad in ('leicht','mittel','schwer')),
  status text not null default 'verdacht'
    check (status in ('verdacht','bestaetigt','gemeldet','in_behandlung','saniert','ausgeheilt','erloschen')),
  gemeldet_am date,
  labor_eingesandt boolean not null default false,
  foto_urls text[] not null default '{}',
  massnahme text,
  verantwortliche_person text,
  notiz text,
  is_storniert boolean not null default false,
  storno_grund text,
  storno_am date,
  betrieb_id uuid not null default private.aktive_betrieb_id()
    references public.betriebe(id) on delete cascade,
  created_by uuid, updated_by uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (betrieb_id, id),
  constraint gesundheitsereignisse_volk_fk
    foreign key (betrieb_id, volk_id) references public.voelker (betrieb_id, id) on delete restrict,
  constraint gesundheitsereignisse_storno_chk
    check (is_storniert = false or (storno_grund is not null and storno_am is not null)),
  constraint gesundheitsereignisse_gemeldet_chk
    check (status <> 'gemeldet' or gemeldet_am is not null),
  constraint gesundheitsereignisse_storno_datum_chk
    check (storno_am is null or storno_am >= festgestellt_am),
  constraint gesundheitsereignisse_gemeldet_datum_chk
    check (gemeldet_am is null or gemeldet_am >= festgestellt_am),
  constraint gesundheitsereignisse_zukunft_chk
    check (festgestellt_am <= current_date and (gemeldet_am is null or gemeldet_am <= current_date))
);
alter table public.gesundheitsereignisse enable row level security;
revoke all on public.gesundheitsereignisse from anon, public;
grant select, insert, update on public.gesundheitsereignisse to authenticated;
create index if not exists idx_gesundheitsereignisse_volk_datum
  on public.gesundheitsereignisse (betrieb_id, volk_id, festgestellt_am desc);

drop trigger if exists trg_gesundheitsereignisse_actor on public.gesundheitsereignisse;
create trigger trg_gesundheitsereignisse_actor before insert or update
  on public.gesundheitsereignisse for each row execute function private.set_row_actor();
drop trigger if exists trg_gesundheitsereignisse_updated on public.gesundheitsereignisse;
create trigger trg_gesundheitsereignisse_updated before update
  on public.gesundheitsereignisse for each row execute function private.set_updated_at();

drop policy if exists gesundheitsereignisse_sel_member on public.gesundheitsereignisse;
create policy gesundheitsereignisse_sel_member on public.gesundheitsereignisse
  for select to authenticated using (betrieb_id in (select private.meine_betrieb_ids()));
drop policy if exists gesundheitsereignisse_ins_writer on public.gesundheitsereignisse;
create policy gesundheitsereignisse_ins_writer on public.gesundheitsereignisse
  for insert to authenticated with check (private.kann_schreiben(betrieb_id));
drop policy if exists gesundheitsereignisse_upd_writer on public.gesundheitsereignisse;
create policy gesundheitsereignisse_upd_writer on public.gesundheitsereignisse
  for update to authenticated using (private.kann_schreiben(betrieb_id))
  with check (private.kann_schreiben(betrieb_id));
-- BEWUSST keine DELETE-Policy (Soft-Delete).
