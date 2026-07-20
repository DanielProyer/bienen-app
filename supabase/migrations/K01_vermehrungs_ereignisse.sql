-- K01_vermehrungs_ereignisse.sql | Vermehrungs-Event-Ketten (Baustein D1, Modul 4.16).
-- Startereignis + relative Fristen; Ketten-Schritte materialisieren als aufgaben (quelle='ereignis').
create table if not exists public.vermehrungs_ereignisse (
  id uuid primary key default gen_random_uuid(),
  methode text not null check (methode in
    ('kunstschwarm','koeniginnen_kunstschwarm','brutableger','flugling')),
  erstellt_am date not null,
  stammvolk_id uuid,
  jungvolk_id uuid,
  os_bei_erstellung boolean not null default false,
  notiz text,
  betrieb_id uuid not null default private.aktive_betrieb_id()
    references public.betriebe(id) on delete cascade,
  created_by uuid, updated_by uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (betrieb_id, id),
  constraint vermehrung_stammvolk_fk foreign key (betrieb_id, stammvolk_id)
    references public.voelker (betrieb_id, id) on delete set null (stammvolk_id),
  constraint vermehrung_jungvolk_fk foreign key (betrieb_id, jungvolk_id)
    references public.voelker (betrieb_id, id) on delete set null (jungvolk_id)
);
alter table public.vermehrungs_ereignisse enable row level security;
revoke all on public.vermehrungs_ereignisse from anon, public;
grant select, insert, update, delete on public.vermehrungs_ereignisse to authenticated;
create index if not exists idx_vermehrung_stammvolk on public.vermehrungs_ereignisse (betrieb_id, stammvolk_id);
create index if not exists idx_vermehrung_jungvolk  on public.vermehrungs_ereignisse (betrieb_id, jungvolk_id);

drop trigger if exists trg_vermehrung_actor on public.vermehrungs_ereignisse;
create trigger trg_vermehrung_actor before insert or update
  on public.vermehrungs_ereignisse for each row execute function private.set_row_actor();
drop trigger if exists trg_vermehrung_updated on public.vermehrungs_ereignisse;
create trigger trg_vermehrung_updated before update
  on public.vermehrungs_ereignisse for each row execute function private.set_updated_at();

drop policy if exists vermehrung_sel_member on public.vermehrungs_ereignisse;
create policy vermehrung_sel_member on public.vermehrungs_ereignisse
  for select to authenticated using (betrieb_id in (select private.meine_betrieb_ids()));
drop policy if exists vermehrung_ins_writer on public.vermehrungs_ereignisse;
create policy vermehrung_ins_writer on public.vermehrungs_ereignisse
  for insert to authenticated with check (private.kann_schreiben(betrieb_id));
drop policy if exists vermehrung_upd_writer on public.vermehrungs_ereignisse;
create policy vermehrung_upd_writer on public.vermehrungs_ereignisse
  for update to authenticated using (private.kann_schreiben(betrieb_id)) with check (private.kann_schreiben(betrieb_id));
drop policy if exists vermehrung_del_writer on public.vermehrungs_ereignisse;
create policy vermehrung_del_writer on public.vermehrungs_ereignisse
  for delete to authenticated using (private.kann_schreiben(betrieb_id));

-- aufgaben-Erweiterung
alter table public.aufgaben add column if not exists ereignis_id uuid;
alter table public.aufgaben add column if not exists schritt_key text;
alter table public.aufgaben drop constraint if exists aufgaben_quelle_check;
alter table public.aufgaben add constraint aufgaben_quelle_check
  check (quelle in ('manuell','regel','ereignis'));
alter table public.aufgaben add constraint aufgaben_ereignis_fk
  foreign key (betrieb_id, ereignis_id) references public.vermehrungs_ereignisse (betrieb_id, id) on delete cascade;
alter table public.aufgaben add constraint aufgaben_ereignis_chk
  check ((quelle = 'ereignis') = (ereignis_id is not null and schritt_key is not null));
create unique index if not exists aufgaben_ereignis_dedup on public.aufgaben
  (betrieb_id, ereignis_id, schritt_key) where quelle = 'ereignis';
