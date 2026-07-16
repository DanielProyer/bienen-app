-- bootstrap-owner.sql | EINMALIG, nach der Betriebs-Gruendung des Owners.
-- KEIN Migrationsfile (laufzeit-abhaengige betrieb_id). Idempotent: mehrfaches
-- Ausfuehren ist harmlos (WHERE betrieb_id IS NULL trifft dann 0 Zeilen).
--
-- Reihenfolge je Tabelle ist verbindlich:
--   LOCK (schliesst das Insert-Race) -> UPDATE ... WHERE betrieb_id IS NULL
--   -> DEFAULT setzen -> NOT NULL setzen.
-- Der DEFAULT private.aktive_betrieb_id() liest den JWT-Claim und kommt NUR auf die
-- 6 user-getriebenen Tabellen. weight_readings/scale_alerts bekommen KEINEN Default:
-- dort fuellt der BEFORE-INSERT-Trigger aus scales.betrieb_id (Service-Role-Cron
-- hat kein auth.uid()).

do $$
declare
  v_betrieb uuid;
  t text;
begin
  -- betrieb_id zur Laufzeit aufloesen (E-Mail nur hier, als Parameter gedacht).
  select m.betrieb_id into v_betrieb
    from auth.users u
    join public.betrieb_mitglieder m on m.user_id = u.id and m.is_deleted = false
   where lower(u.email) = lower('dani.proyer@gmail.com')
     and m.rolle = 'owner'
   order by m.created_at
   limit 1;
  if v_betrieb is null then
    raise exception 'Kein owner-Betrieb gefunden — hat sich der Owner registriert UND gegruendet?';
  end if;

  -- 1) Alle 8 Tabellen: Lock + mengenbasierter Backfill.
  foreach t in array array['materials','material_purchases','weight_readings','scales',
                           'scale_alerts','funkstationen','voelker','construction_steps'] loop
    execute format('lock table public.%I in access exclusive mode', t);
    execute format('update public.%I set betrieb_id = $1 where betrieb_id is null', t)
      using v_betrieb;
  end loop;

  -- 2) DEFAULT nur auf die 6 user-getriebenen Tabellen.
  foreach t in array array['materials','material_purchases','scales',
                           'funkstationen','voelker','construction_steps'] loop
    execute format(
      'alter table public.%I alter column betrieb_id set default private.aktive_betrieb_id()', t);
  end loop;

  -- 3) NOT NULL auf alle 8 (jetzt garantiert befuellt).
  foreach t in array array['materials','material_purchases','weight_readings','scales',
                           'scale_alerts','funkstationen','voelker','construction_steps'] loop
    execute format('alter table public.%I alter column betrieb_id set not null', t);
  end loop;

  raise notice 'Bootstrap fertig fuer betrieb_id=%', v_betrieb;
end $$;
