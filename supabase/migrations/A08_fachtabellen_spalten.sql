-- A08_fachtabellen_spalten.sql | betrieb_id (NULLABLE, ohne Default), created_by/updated_by
-- + Trigger auf allen 8 Bestandstabellen. NOT NULL/Default erst im Bootstrap (Plan 3).

-- (a) Spalten + Indizes fuer alle 8 Tabellen.
do $$
declare t text;
begin
  foreach t in array array['materials','material_purchases','weight_readings','scales',
                           'scale_alerts','funkstationen','voelker','construction_steps'] loop
    execute format('alter table public.%I add column if not exists betrieb_id uuid', t);
    execute format('alter table public.%I add column if not exists created_by uuid', t);
    execute format('alter table public.%I add column if not exists updated_by uuid', t);
    execute format('create index if not exists idx_%s_betrieb on public.%I (betrieb_id)', t, t);
  end loop;
end $$;

-- (b) Actor-Trigger: created_by/updated_by serverseitig erzwingen (nicht Client-spoofbar),
-- created_by + betrieb_id bei UPDATE immutabel. Fasst NUR die drei Spalten an, die A08
-- auf ALLE 8 Tabellen legt (created_by/updated_by/betrieb_id) — NICHT created_at/updated_at,
-- weil scales/weight_readings/scale_alerts/material_purchases kein updated_at (und die
-- Zeitreihen kein created_at) haben; updated_at bleibt den bestehenden updated_at-Triggern
-- ueberlassen. SECURITY DEFINER, damit auch der aktuelle anon-Pfad (vor Cutover) ohne
-- private-Grant funktioniert; auth.uid()/current_app_user() liest weiterhin den echten
-- Request-User.
create or replace function private.set_row_actor() returns trigger
  language plpgsql security definer set search_path = '' as $$
begin
  if tg_op = 'INSERT' then
    new.created_by := private.current_app_user();
    new.updated_by := private.current_app_user();
  else -- UPDATE
    new.created_by := old.created_by;      -- created_by immutabel
    new.betrieb_id := old.betrieb_id;      -- betrieb_id einfrieren
    new.updated_by := private.current_app_user();
  end if;
  return new;
end; $$;

-- (c) betrieb_id-Ableitung fuer die maschinellen Zeitreihen aus der Waage
-- (Service-Role-Cron ohne auth.uid()). KEIN RAISE in der nullable-Phase; die
-- NOT-NULL-Constraint (Bootstrap) sichert es hart ab.
create or replace function private.set_wr_betrieb() returns trigger
  language plpgsql security definer set search_path = '' as $$
begin
  if new.betrieb_id is null and new.scale_id is not null then
    select s.betrieb_id into new.betrieb_id from public.scales s where s.id = new.scale_id;
  end if;
  return new;
end; $$;
create or replace function private.set_sa_betrieb() returns trigger
  language plpgsql security definer set search_path = '' as $$
begin
  if new.betrieb_id is null and new.scale_id is not null then
    select s.betrieb_id into new.betrieb_id from public.scales s where s.id = new.scale_id;
  end if;
  if new.betrieb_id is null and new.weight_reading_id is not null then
    select wr.betrieb_id into new.betrieb_id
      from public.weight_readings wr where wr.id = new.weight_reading_id;
  end if;
  return new;
end; $$;

-- (d) Actor-Trigger anhaengen (alle 8). Bestehende updated_at-Trigger bleiben unangetastet
-- (set_row_actor fasst updated_at NICHT an) -> kein Doppel-Set, kein Bruch auf Tabellen
-- ohne updated_at.
do $$
declare t text;
begin
  foreach t in array array['materials','material_purchases','weight_readings','scales',
                           'scale_alerts','funkstationen','voelker','construction_steps'] loop
    execute format('drop trigger if exists trg_%s_actor on public.%I', t, t);
    execute format('create trigger trg_%s_actor before insert or update on public.%I '
                || 'for each row execute function private.set_row_actor()', t, t);
  end loop;
end $$;
drop trigger if exists trg_wr_betrieb on public.weight_readings;
create trigger trg_wr_betrieb before insert on public.weight_readings
  for each row execute function private.set_wr_betrieb();
drop trigger if exists trg_sa_betrieb on public.scale_alerts;
create trigger trg_sa_betrieb before insert on public.scale_alerts
  for each row execute function private.set_sa_betrieb();
