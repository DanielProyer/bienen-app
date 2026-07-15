-- A10_storage.sql | Storage additiv haerten: authenticated-Write-Policies mit
-- <betrieb_id>/-Pfad-Scoping ZUSAETZLICH zu den bestehenden public-Write-Policies.
-- Downloads bleiben public (Foto-Anzeige). public-Write-Policies droppt erst der
-- Cutover (Plan 3). Pfadkonvention ab jetzt: '<betrieb_id>/...'.

-- Helper-Ausdruck: erstes Pfadsegment ist eine betrieb_id, in der der User schreiben darf.
-- (storage.foldername(name))[1] = erstes Segment; kanonischer UUID-Regex-Guard vor dem Cast
-- (nur Strings, die der ::uuid-Cast garantiert akzeptiert -> sauberes Deny statt 22P02).
do $$
declare bkt text;
begin
  foreach bkt in array array['construction-photos','material-media','material-receipts'] loop
    execute format($p$
      create policy %I on storage.objects for insert to authenticated
      with check (bucket_id = %L
        and (storage.foldername(name))[1] ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
        and private.kann_schreiben(((storage.foldername(name))[1])::uuid))
    $p$, 'auth_ins_'||replace(bkt,'-','_'), bkt);
    execute format($p$
      create policy %I on storage.objects for update to authenticated
      using (bucket_id = %L
        and (storage.foldername(name))[1] ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
        and private.kann_schreiben(((storage.foldername(name))[1])::uuid))
      with check (bucket_id = %L
        and (storage.foldername(name))[1] ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
        and private.kann_schreiben(((storage.foldername(name))[1])::uuid))
    $p$, 'auth_upd_'||replace(bkt,'-','_'), bkt, bkt);
    execute format($p$
      create policy %I on storage.objects for delete to authenticated
      using (bucket_id = %L
        and (storage.foldername(name))[1] ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
        and private.kann_schreiben(((storage.foldername(name))[1])::uuid))
    $p$, 'auth_del_'||replace(bkt,'-','_'), bkt);
  end loop;
end $$;
-- Hinweis: private-USAGE + kann_schreiben-EXECUTE fuer authenticated sind aus A01/A03 vorhanden.
