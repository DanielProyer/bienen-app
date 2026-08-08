-- T01_sprach_karten.sql | Spracheingabe: der Uebungsstoff des Trainings.
-- Muster aus R01 (recherche_fotos). Buchstabe T, weil S01-S04 in der
-- Tonmitschnitt-Spec fuer durchsicht_aufnahmen reserviert sind.
--
-- person_id ist NULLABLE und das ist Absicht: Die Startliste gilt fuer alle im
-- Betrieb, eine aus einem Verhoerer entstandene Karte gehoert zu einer Stimme.
create table if not exists public.sprach_karten (
  id uuid primary key default gen_random_uuid(),
  betrieb_id uuid not null default private.aktive_betrieb_id()
    references public.betriebe(id) on delete cascade,
  person_id uuid,
  art text not null check (art in ('wort','satz')),
  soll_text text not null check (length(btrim(soll_text)) > 0),
  pruefbegriffe text[] not null default '{}',
  herkunft text not null default 'eigen' check (herkunft in ('start','verhoerer','eigen')),
  aktiv boolean not null default true,
  created_by uuid, updated_by uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
alter table public.sprach_karten enable row level security;
revoke all on public.sprach_karten from anon, public;
grant select, insert, update, delete on public.sprach_karten to authenticated;

-- Leseweg des Drills: aktive Karten des Betriebs, eigene und allgemeine.
create index if not exists idx_sprach_karten_stapel
  on public.sprach_karten (betrieb_id, aktiv, person_id);

drop trigger if exists trg_sprach_karten_actor on public.sprach_karten;
create trigger trg_sprach_karten_actor before insert or update
  on public.sprach_karten for each row execute function private.set_row_actor();
drop trigger if exists trg_sprach_karten_updated on public.sprach_karten;
create trigger trg_sprach_karten_updated before update
  on public.sprach_karten for each row execute function private.set_updated_at();

-- Sichtbar sind allgemeine Karten (person_id is null) und die eigenen.
drop policy if exists sprach_karten_sel on public.sprach_karten;
create policy sprach_karten_sel on public.sprach_karten
  for select to authenticated using (
    betrieb_id in (select private.meine_betrieb_ids())
    and (person_id is null or person_id = private.current_app_user())
  );
drop policy if exists sprach_karten_ins on public.sprach_karten;
create policy sprach_karten_ins on public.sprach_karten
  for insert to authenticated with check (
    private.kann_schreiben(betrieb_id)
    and (person_id is null or person_id = private.current_app_user())
  );
drop policy if exists sprach_karten_upd on public.sprach_karten;
create policy sprach_karten_upd on public.sprach_karten
  for update to authenticated
  using (private.kann_schreiben(betrieb_id)
    and (person_id is null or person_id = private.current_app_user()))
  with check (private.kann_schreiben(betrieb_id)
    and (person_id is null or person_id = private.current_app_user()));
drop policy if exists sprach_karten_del on public.sprach_karten;
create policy sprach_karten_del on public.sprach_karten
  for delete to authenticated using (
    private.kann_schreiben(betrieb_id)
    and (person_id is null or person_id = private.current_app_user())
  );

-- ROLLBACK: drop table if exists public.sprach_karten;
