-- T04_sprach_korrekturen.sql | Spracheingabe: die gelernten Lautvarianten.
-- Setzt S03 der Tonmitschnitt-Spec um. Personenbezogen wie O01 —
-- Daniel und Lorena sprechen unterschiedlich (D-98b).
--
-- `treffer` zaehlt, wie oft derselbe Verhoerer beobachtet wurde. Erst ab der
-- Lernschwelle (2, siehe lernschwelle.dart) wird `aktiv` gesetzt; darunter ist
-- die Zeile nur eine Beobachtung.
create table if not exists public.sprach_korrekturen (
  id uuid primary key default gen_random_uuid(),
  betrieb_id uuid not null default private.aktive_betrieb_id()
    references public.betriebe(id) on delete cascade,
  person_id uuid not null,
  falsch text not null check (length(btrim(falsch)) > 0),
  richtig text not null check (length(btrim(richtig)) > 0),
  treffer integer not null default 1 check (treffer >= 1),
  quelle text not null default 'training' check (quelle in ('training','durchsicht','manuell')),
  aktiv boolean not null default false,
  zuletzt_am timestamptz not null default now(),
  created_by uuid, updated_by uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (betrieb_id, person_id, falsch)
);
alter table public.sprach_korrekturen enable row level security;
revoke all on public.sprach_korrekturen from anon, public;
grant select, insert, update, delete on public.sprach_korrekturen to authenticated;

create index if not exists idx_sprach_korrekturen_aktiv
  on public.sprach_korrekturen (betrieb_id, person_id, aktiv);

drop trigger if exists trg_sprach_korrekturen_actor on public.sprach_korrekturen;
create trigger trg_sprach_korrekturen_actor before insert or update
  on public.sprach_korrekturen for each row execute function private.set_row_actor();
drop trigger if exists trg_sprach_korrekturen_updated on public.sprach_korrekturen;
create trigger trg_sprach_korrekturen_updated before update
  on public.sprach_korrekturen for each row execute function private.set_updated_at();

drop policy if exists sprach_korrekturen_sel on public.sprach_korrekturen;
create policy sprach_korrekturen_sel on public.sprach_korrekturen
  for select to authenticated
  using (person_id = private.current_app_user() and private.ist_mitglied(betrieb_id));
drop policy if exists sprach_korrekturen_ins on public.sprach_korrekturen;
create policy sprach_korrekturen_ins on public.sprach_korrekturen
  for insert to authenticated
  with check (person_id = private.current_app_user() and private.ist_mitglied(betrieb_id));
drop policy if exists sprach_korrekturen_upd on public.sprach_korrekturen;
create policy sprach_korrekturen_upd on public.sprach_korrekturen
  for update to authenticated
  using (person_id = private.current_app_user() and private.ist_mitglied(betrieb_id))
  with check (person_id = private.current_app_user() and private.ist_mitglied(betrieb_id));
-- Loeschen erlaubt: eine falsch gelernte Regel muss verschwinden koennen,
-- sonst schleppt man sie jahrelang mit. Wie in T02 bewusst OHNE ist_mitglied —
-- auch nach einem Austritt muss man das, was die App ueber die eigene
-- Aussprache gelernt hat, entfernen koennen.
drop policy if exists sprach_korrekturen_del on public.sprach_korrekturen;
create policy sprach_korrekturen_del on public.sprach_korrekturen
  for delete to authenticated
  using (person_id = private.current_app_user());

-- ROLLBACK: drop table if exists public.sprach_korrekturen;
