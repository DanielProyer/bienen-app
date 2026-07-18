-- G02_storage_health_photos.sql | PRIVATER Bucket (Krankheitsfotos = Gesundheitsdaten).
-- SELECT nur Mitglied (private.ist_mitglied); Write nur kann_schreiben. Anzeige via createSignedUrl.

insert into storage.buckets (id, name, public)
  values ('health-photos', 'health-photos', false)
  on conflict (id) do nothing;

drop policy if exists auth_sel_health_photos on storage.objects;
create policy auth_sel_health_photos on storage.objects for select to authenticated
  using (bucket_id = 'health-photos'
    and (storage.foldername(name))[1] ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
    and private.ist_mitglied(((storage.foldername(name))[1])::uuid));

drop policy if exists auth_ins_health_photos on storage.objects;
create policy auth_ins_health_photos on storage.objects for insert to authenticated
  with check (bucket_id = 'health-photos'
    and (storage.foldername(name))[1] ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
    and private.kann_schreiben(((storage.foldername(name))[1])::uuid));

drop policy if exists auth_upd_health_photos on storage.objects;
create policy auth_upd_health_photos on storage.objects for update to authenticated
  using (bucket_id = 'health-photos'
    and (storage.foldername(name))[1] ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
    and private.kann_schreiben(((storage.foldername(name))[1])::uuid))
  with check (bucket_id = 'health-photos'
    and (storage.foldername(name))[1] ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
    and private.kann_schreiben(((storage.foldername(name))[1])::uuid));

drop policy if exists auth_del_health_photos on storage.objects;
create policy auth_del_health_photos on storage.objects for delete to authenticated
  using (bucket_id = 'health-photos'
    and (storage.foldername(name))[1] ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
    and private.kann_schreiben(((storage.foldername(name))[1])::uuid));
