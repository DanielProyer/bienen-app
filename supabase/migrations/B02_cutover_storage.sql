-- B02_cutover_storage.sql | Storage-Cutover.
-- (a) public-Policies droppen (die authenticated-Write-Policies aus A10 mit
--     <betrieb_id>/-Pfad-Scoping uebernehmen).
-- (b) Statt der breiten public-SELECT/Listing-Policies eine mandanten-scoped
--     authenticated-SELECT: behebt Advisor 0025 (Bucket-Listing) UND erhaelt
--     uploadBinary(upsert:true) (braucht SELECT auf das Objekt). Downloads laufen
--     ueber die public URL an RLS vorbei -> Foto-Anzeige unberuehrt.
do $$
declare p record;
begin
  for p in select policyname from pg_policies
            where schemaname='storage' and tablename='objects' and roles='{public}'
  loop
    execute format('drop policy %I on storage.objects', p.policyname);
  end loop;
end $$;

do $$
declare bkt text;
begin
  foreach bkt in array array['construction-photos','material-media','material-receipts'] loop
    execute format($p$
      create policy %I on storage.objects for select to authenticated
      using (bucket_id = %L
        and (storage.foldername(name))[1] ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
        and private.ist_mitglied(((storage.foldername(name))[1])::uuid))
    $p$, 'auth_sel_'||replace(bkt,'-','_'), bkt);
  end loop;
end $$;
