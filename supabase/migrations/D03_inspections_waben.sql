-- D03_inspections_waben.sql | Waben-Beobachtungen je Durchsicht (geführte Durchsicht, Modul 4.3-Ausbau).
alter table public.inspections add column if not exists waben jsonb;
alter table public.inspections drop constraint if exists inspections_waben_chk;
alter table public.inspections add constraint inspections_waben_chk
  check (waben is null or jsonb_typeof(waben) = 'array');
-- View mit `select *` friert die Spaltenliste zur Erstellzeit ein → waben käme nie mit. Identisch neu bauen:
drop view if exists public.v_letzte_durchsichten;
create view public.v_letzte_durchsichten with (security_invoker = true) as
  select distinct on (volk_id) *
  from public.inspections
  order by volk_id, durchgefuehrt_am desc, created_at desc;
-- ROLLBACK: drop constraint inspections_waben_chk; alter table inspections drop column waben;
