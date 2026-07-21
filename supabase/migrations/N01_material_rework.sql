-- N01_material_rework.sql | Material-Rework: Archiv-Flag, Standbau archivieren, Bestands-Korrektur, Kauf→Bestand-Trigger.
alter table public.materials add column if not exists archiviert boolean not null default false;

-- (1) Standbau raus aus dem aktiven Betrieb (reversibel).
update public.materials set archiviert = true where bereich = 'standbau';

-- (2) Bestands-Korrektur (fixt den Fehlalarm): Verbrauchsmaterial-Bestand aus der Kauf-Historie,
--     und wo gekauft aber keine Kauf-Menge erfasst ist, mind. auf den Mindestbestand.
update public.materials m
   set stock_qty = greatest(m.stock_qty, coalesce(
       (select sum(p.menge) from public.material_purchases p where p.material_id = m.id and p.menge is not null), 0))
 where m.is_consumable;
update public.materials m
   set stock_qty = m.min_qty
 where m.is_consumable and m.status = 'gekauft' and m.stock_qty < m.min_qty
   and not exists (select 1 from public.material_purchases p where p.material_id = m.id and p.menge is not null);

-- (3) Kauf → Bestand-Trigger (nur Verbrauchsmaterial, nur wenn menge gesetzt). Plain (INVOKER):
--     der Nutzer aktualisiert den Bestand seines eigenen Materials via seiner RLS-Schreibrechte.
create or replace function public.material_bestand_nachfuehren() returns trigger
  language plpgsql set search_path = '' as $$
begin
  if tg_op = 'INSERT' then
    if new.menge is not null then
      update public.materials set stock_qty = stock_qty + new.menge
        where id = new.material_id and is_consumable;
    end if;
  elsif tg_op = 'DELETE' then
    if old.menge is not null then
      update public.materials set stock_qty = greatest(0, stock_qty - old.menge)
        where id = old.material_id and is_consumable;
    end if;
  elsif tg_op = 'UPDATE' then
    update public.materials set stock_qty = greatest(0, stock_qty
        + coalesce(new.menge,0) - coalesce(old.menge,0))
      where id = new.material_id and is_consumable;
  end if;
  return null;
end $$;
drop trigger if exists trg_material_bestand on public.material_purchases;
create trigger trg_material_bestand after insert or update or delete
  on public.material_purchases for each row execute function public.material_bestand_nachfuehren();
-- ROLLBACK: drop trigger trg_material_bestand on public.material_purchases;
--           drop function public.material_bestand_nachfuehren();
--           alter table public.materials drop column archiviert;  (Bestands-/Standbau-Updates sind Daten, nicht reversibel per DDL)
