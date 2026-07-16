-- A13_actor_trigger_backfill_fix.sql | Fix fuer set_row_actor (aus A08).
-- Problem: `new.betrieb_id := old.betrieb_id` friert betrieb_id bei JEDEM UPDATE
-- ein und machte damit den Bootstrap-Backfill (UPDATE ... SET betrieb_id=<wert>
-- WHERE betrieb_id IS NULL) wirkungslos -> SET NOT NULL scheiterte.
-- Fix: nur einfrieren, wenn betrieb_id BEREITS gesetzt ist (coalesce). Ein noch
-- NULLes darf befuellt werden (Bootstrap). Nach dem Bootstrap (NOT NULL + Default)
-- ist betrieb_id immer gesetzt -> immer eingefroren -> Spoofing-Schutz unveraendert.
create or replace function private.set_row_actor() returns trigger
  language plpgsql security definer set search_path = '' as $$
begin
  if tg_op = 'INSERT' then
    new.created_by := private.current_app_user();
    new.updated_by := private.current_app_user();
  else -- UPDATE
    new.created_by := old.created_by;                          -- created_by immutabel
    new.betrieb_id := coalesce(old.betrieb_id, new.betrieb_id); -- einfrieren SOBALD gesetzt
    new.updated_by := private.current_app_user();
  end if;
  return new;
end; $$;
