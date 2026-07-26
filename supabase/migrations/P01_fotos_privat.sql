-- P01_fotos_privat.sql | F2 Teil 1: keine Fotos ohne Login.
-- Die drei Buckets waren public=true; damit liefert /storage/v1/object/public/...
-- OHNE Login aus und umgeht die RLS-Policies vollstaendig.
-- Nachgewiesen vor der Migration: HTTP 200 auf eine Foto-URL ohne Session.
update storage.buckets set public = false
 where name in ('material-media','material-receipts','construction-photos');

-- ALT-LAST: 28 Objekte in material-media liegen unter <material_id>/… statt
-- <betrieb_id>/… (Befuellung vor der Praefix-Haertung). Ein Umzug per SQL ist
-- NICHT sicher (storage.objects.name ist der Backend-Schluessel; Umbenennen
-- wuerde die Dateien ins Leere zeigen lassen). Diese Policy erreicht dasselbe
-- Schutzziel ohne Datenbewegung: Lesen nur fuer Mitglieder des Betriebs, dem
-- das Material gehoert. Darf entfallen, sobald die Alt-Objekte umgezogen sind.
create policy auth_sel_material_media_altpfad on storage.objects
  for select to authenticated
  using (
    bucket_id = 'material-media'
    and exists (
      select 1 from public.materials m
       where m.id::text = (storage.foldername(name))[1]
         and private.ist_mitglied(m.betrieb_id)
    )
  );

-- Signed-URLs entstehen zur Laufzeit -> gespeichert wird der PFAD (konsistent
-- zu inspections.foto_urls und wissen_fotos.storage_path).
update public.materials
   set photo_urls = (
     select array_agg(regexp_replace(u,
       '^https?://[^/]+/storage/v1/object/public/material-media/', ''))
       from unnest(photo_urls) u)
 where photo_urls is not null and array_length(photo_urls, 1) > 0;

-- ROLLBACK: update storage.buckets set public = true where name in
--             ('material-media','material-receipts','construction-photos');
--           drop policy auth_sel_material_media_altpfad on storage.objects;
--           update public.materials set photo_urls = (select array_agg(
--             'https://dcdcohktxbhdxnxjvcyp.supabase.co/storage/v1/object/public/material-media/' || u)
--             from unnest(photo_urls) u)
--            where photo_urls is not null and array_length(photo_urls,1) > 0;
