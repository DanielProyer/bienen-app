-- P02_altpfad_policy_fix.sql | Fix der Alt-Pfad-Policy aus P01.
--
-- BUG (von P01): In
--   exists (select 1 from public.materials m
--            where m.id::text = (storage.foldername(name))[1] ...)
-- band Postgres das unqualifizierte `name` an **materials.name** (die innere
-- Tabelle hat Vorrang), NICHT an storage.objects.name. Die Bedingung verglich
-- also die Material-ID mit dem Material-NAMEN und war immer falsch
-- -> die 26 Produktfotos waren nach P01 nicht mehr lesbar (grauer Platzhalter).
--
-- Ein isolierter Test mit einem Literal statt der Spalte verdeckt diesen Bug —
-- Policies mit korrelierter Subquery immer als Rolle `authenticated` gegen die
-- echte Tabelle pruefen (siehe Verifikation unten).
--
-- FIX: aeussere Spalte explizit als objects.name qualifizieren.
drop policy if exists auth_sel_material_media_altpfad on storage.objects;

create policy auth_sel_material_media_altpfad on storage.objects
  for select to authenticated
  using (
    bucket_id = 'material-media'
    and exists (
      select 1 from public.materials m
       where m.id::text = (storage.foldername(objects.name))[1]
         and private.ist_mitglied(m.betrieb_id)
    )
  );

-- VERIFIKATION (als echte Rolle, nicht als Superuser!):
--   select set_config('request.jwt.claims',
--     json_build_object('sub','<user_id>','role','authenticated')::text, true);
--   set local role authenticated;
--   select count(*) from storage.objects where bucket_id='material-media';
--   -> erwartet 26 (vor dem Fix: 0)
--
-- ROLLBACK: drop policy auth_sel_material_media_altpfad on storage.objects;
--           (Ohne Policy sind die 26 Alt-Objekte fuer niemanden lesbar.)
