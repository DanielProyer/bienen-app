-- T03_sprach_ergebnisse.sql | Spracheingabe: je Probe x Anbieter x Wortliste eine Messung.
--
-- BEWUSST OHNE Eindeutigkeit ueber die Zeit. Eine zweite Messung derselben
-- Probe legt eine NEUE Zeile an, statt die erste zu ueberschreiben. Genau das
-- ist der Zweck dieser Tabelle: Ein neuer Anbieter oder eine neue
-- Modellgeneration wird gegen den vorhandenen Bestand gemessen, und die Frage
-- "war ElevenLabs im Januar besser als im Juli" beantworten Daten statt
-- Erinnerung.
create table if not exists public.sprach_ergebnisse (
  id uuid primary key default gen_random_uuid(),
  betrieb_id uuid not null default private.aktive_betrieb_id()
    references public.betriebe(id) on delete cascade,
  probe_id uuid not null references public.sprach_proben(id) on delete cascade,
  anbieter text not null check (length(btrim(anbieter)) > 0),
  modell text not null default '',
  mit_wortliste boolean not null,
  transkript text not null default '',
  treffer_quote numeric(5,4),
  wortfehlerrate numeric(6,4),
  dauer_ms integer,
  fehler text,
  gemessen_am timestamptz not null default now(),
  created_by uuid, updated_by uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
alter table public.sprach_ergebnisse enable row level security;
revoke all on public.sprach_ergebnisse from anon, public;
grant select, insert, update, delete on public.sprach_ergebnisse to authenticated;

create index if not exists idx_sprach_ergebnisse_probe
  on public.sprach_ergebnisse (probe_id, anbieter, gemessen_am desc);

drop trigger if exists trg_sprach_ergebnisse_actor on public.sprach_ergebnisse;
create trigger trg_sprach_ergebnisse_actor before insert or update
  on public.sprach_ergebnisse for each row execute function private.set_row_actor();
drop trigger if exists trg_sprach_ergebnisse_updated on public.sprach_ergebnisse;
create trigger trg_sprach_ergebnisse_updated before update
  on public.sprach_ergebnisse for each row execute function private.set_updated_at();

-- Die Berechtigung haengt an der PROBE, nicht an dieser Zeile.
-- Diese Tabelle sieht wie eine reine Messtabelle aus, enthaelt aber das
-- Transkript — also den Wortlaut des Gesagten. Waere sie nach dem
-- Mitglieder-Muster lesbar, koennte jedes Mitglied nachlesen, was ein anderes
-- gesprochen hat, und der Schutz auf sprach_proben waere wertlos.
create or replace function private.eigene_sprach_probe(p_probe_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.sprach_proben p
    where p.id = p_probe_id and p.person_id = private.current_app_user()
  );
$$;
revoke execute on function private.eigene_sprach_probe(uuid) from anon, authenticated, public;
grant execute on function private.eigene_sprach_probe(uuid) to authenticated;

drop policy if exists sprach_ergebnisse_sel on public.sprach_ergebnisse;
create policy sprach_ergebnisse_sel on public.sprach_ergebnisse
  for select to authenticated using (private.eigene_sprach_probe(probe_id));
drop policy if exists sprach_ergebnisse_ins on public.sprach_ergebnisse;
create policy sprach_ergebnisse_ins on public.sprach_ergebnisse
  for insert to authenticated with check (private.eigene_sprach_probe(probe_id));
drop policy if exists sprach_ergebnisse_upd on public.sprach_ergebnisse;
create policy sprach_ergebnisse_upd on public.sprach_ergebnisse
  for update to authenticated
  using (private.eigene_sprach_probe(probe_id))
  with check (private.eigene_sprach_probe(probe_id));
drop policy if exists sprach_ergebnisse_del on public.sprach_ergebnisse;
create policy sprach_ergebnisse_del on public.sprach_ergebnisse
  for delete to authenticated using (private.eigene_sprach_probe(probe_id));

-- ROLLBACK:
--   drop table if exists public.sprach_ergebnisse;
--   drop function if exists private.eigene_sprach_probe(uuid);
