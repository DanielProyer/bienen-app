-- L01_volk_bewertungen.sql | Volk-Bewertung (Baustein D2a, Modul 4.17). 6 BGD-Achsen (1-4) je Volk/Saison.
-- Normale CRUD via RLS. Saison = year(bewertet_am), NICHT gespeichert. Kein Ranking in v1.
create table if not exists public.volk_bewertungen (
  id uuid primary key default gen_random_uuid(),
  volk_id uuid not null,
  koenigin_id uuid,                        -- Zuordnungs-Referenz z. Bewertungszeitpunkt (SET NULL)
  bewertet_am date not null,
  sanftmut smallint not null check (sanftmut between 1 and 4),
  wabensitz smallint not null check (wabensitz between 1 and 4),
  schwarmtraegheit smallint not null check (schwarmtraegheit between 1 and 4),
  brutbild smallint not null check (brutbild between 1 and 4),
  volksstaerke smallint not null check (volksstaerke between 1 and 4),
  gesundheit smallint not null check (gesundheit between 1 and 4),
  notiz text,
  betrieb_id uuid not null default private.aktive_betrieb_id()
    references public.betriebe(id) on delete cascade,
  created_by uuid, updated_by uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (betrieb_id, id),
  constraint bewertung_volk_fk foreign key (betrieb_id, volk_id)
    references public.voelker (betrieb_id, id) on delete cascade,
  constraint bewertung_koenigin_fk foreign key (betrieb_id, koenigin_id)
    references public.koeniginnen (betrieb_id, id) on delete set null (koenigin_id)
);
alter table public.volk_bewertungen enable row level security;
revoke all on public.volk_bewertungen from anon, public;
grant select, insert, update, delete on public.volk_bewertungen to authenticated;
create index if not exists idx_bewertung_volk on public.volk_bewertungen (betrieb_id, volk_id);
create index if not exists idx_bewertung_koenigin on public.volk_bewertungen (betrieb_id, koenigin_id);

drop trigger if exists trg_bewertung_actor on public.volk_bewertungen;
create trigger trg_bewertung_actor before insert or update
  on public.volk_bewertungen for each row execute function private.set_row_actor();
drop trigger if exists trg_bewertung_updated on public.volk_bewertungen;
create trigger trg_bewertung_updated before update
  on public.volk_bewertungen for each row execute function private.set_updated_at();

drop policy if exists bewertung_sel_member on public.volk_bewertungen;
create policy bewertung_sel_member on public.volk_bewertungen
  for select to authenticated using (betrieb_id in (select private.meine_betrieb_ids()));
drop policy if exists bewertung_ins_writer on public.volk_bewertungen;
create policy bewertung_ins_writer on public.volk_bewertungen
  for insert to authenticated with check (private.kann_schreiben(betrieb_id));
drop policy if exists bewertung_upd_writer on public.volk_bewertungen;
create policy bewertung_upd_writer on public.volk_bewertungen
  for update to authenticated using (private.kann_schreiben(betrieb_id)) with check (private.kann_schreiben(betrieb_id));
drop policy if exists bewertung_del_writer on public.volk_bewertungen;
create policy bewertung_del_writer on public.volk_bewertungen
  for delete to authenticated using (private.kann_schreiben(betrieb_id));
