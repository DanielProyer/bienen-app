-- H01_aufgaben.sql | Aufgaben & Kalender (Modul 4.4). Operative Arbeitsplanung:
-- normale CRUD via RLS (KEIN RPC, KEIN Soft-Delete, keine Errcodes — kein Journal/Nachweis).
-- Regel-Vorschlaege (quelle='regel') dedupen ueber partiellen Unique-Index (nulls not distinct):
-- eine angenommene ODER uebersprungene Zeile unterdrueckt den Vorschlag dauerhaft.
-- volk-FK ON DELETE CASCADE (Planung darf mit dem Volk verschwinden), standort SET NULL (spaltenqualifiziert).

create table if not exists public.aufgaben (
  id uuid primary key default gen_random_uuid(),
  titel text not null check (length(titel) between 1 and 200),
  beschreibung text,
  kategorie text not null check (kategorie in
    ('durchsicht','behandlung','fuetterung','schutz','werkstatt','verwaltung','sonstiges')),
  faellig_am date not null,
  prioritaet text not null default 'normal' check (prioritaet in ('hoch','normal','niedrig')),
  status text not null default 'offen' check (status in ('offen','erledigt','uebersprungen')),
  erledigt_am timestamptz,
  volk_id uuid,
  standort_id uuid,
  quelle text not null default 'manuell' check (quelle in ('manuell','regel')),
  regel_key text,
  saison_jahr int,
  betrieb_id uuid not null default private.aktive_betrieb_id()
    references public.betriebe(id) on delete cascade,
  created_by uuid, updated_by uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (betrieb_id, id),
  constraint aufgaben_volk_fk foreign key (betrieb_id, volk_id)
    references public.voelker (betrieb_id, id) on delete cascade,
  constraint aufgaben_standort_fk foreign key (betrieb_id, standort_id)
    references public.standorte (betrieb_id, id) on delete set null (standort_id),
  constraint aufgaben_erledigt_chk check ((status = 'erledigt') = (erledigt_am is not null)),
  constraint aufgaben_regel_chk check ((quelle = 'regel') = (regel_key is not null)),
  constraint aufgaben_saison_chk check ((quelle = 'regel') = (saison_jahr is not null))
);
alter table public.aufgaben enable row level security;
revoke all on public.aufgaben from anon, public;
grant select, insert, update, delete on public.aufgaben to authenticated;

create unique index if not exists aufgaben_regel_dedup on public.aufgaben
  (betrieb_id, regel_key, saison_jahr, volk_id, faellig_am) nulls not distinct
  where quelle = 'regel';
create index if not exists idx_aufgaben_status_faellig
  on public.aufgaben (betrieb_id, status, faellig_am);
create index if not exists idx_aufgaben_volk on public.aufgaben (betrieb_id, volk_id);

drop trigger if exists trg_aufgaben_actor on public.aufgaben;
create trigger trg_aufgaben_actor before insert or update
  on public.aufgaben for each row execute function private.set_row_actor();
drop trigger if exists trg_aufgaben_updated on public.aufgaben;
create trigger trg_aufgaben_updated before update
  on public.aufgaben for each row execute function private.set_updated_at();

drop policy if exists aufgaben_sel_member on public.aufgaben;
create policy aufgaben_sel_member on public.aufgaben
  for select to authenticated using (betrieb_id in (select private.meine_betrieb_ids()));
drop policy if exists aufgaben_ins_writer on public.aufgaben;
create policy aufgaben_ins_writer on public.aufgaben
  for insert to authenticated with check (private.kann_schreiben(betrieb_id));
drop policy if exists aufgaben_upd_writer on public.aufgaben;
create policy aufgaben_upd_writer on public.aufgaben
  for update to authenticated using (private.kann_schreiben(betrieb_id))
  with check (private.kann_schreiben(betrieb_id));
drop policy if exists aufgaben_del_writer on public.aufgaben;
create policy aufgaben_del_writer on public.aufgaben
  for delete to authenticated using (private.kann_schreiben(betrieb_id));
