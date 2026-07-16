-- rollback-public-policies.sql | NOTFALL: Cutover (B01/B02) rueckgaengig machen.
-- Exakt die 20 Tabellen- + 7 Storage-Policies, die vor dem Cutover bestanden
-- (aus pg_policies generiert). Plus anon-Grants zurueck.
create policy "Allow public delete" on public.construction_steps for DELETE to public using (true);
create policy "Allow public insert" on public.construction_steps for INSERT to public with check (true);
create policy "Allow public read"   on public.construction_steps for SELECT to public using (true);
create policy "Allow public update" on public.construction_steps for UPDATE to public using (true);
create policy "Allow public all"    on public.funkstationen for ALL to public using (true) with check (true);
create policy "Allow public delete" on public.material_purchases for DELETE to public using (true);
create policy "Allow public insert" on public.material_purchases for INSERT to public with check (true);
create policy "Allow public read"   on public.material_purchases for SELECT to public using (true);
create policy "Allow public update" on public.material_purchases for UPDATE to public using (true);
create policy "Allow public delete" on public.materials for DELETE to public using (true);
create policy "Allow public insert" on public.materials for INSERT to public with check (true);
create policy "Allow public read"   on public.materials for SELECT to public using (true);
create policy "Allow public update" on public.materials for UPDATE to public using (true);
create policy "Public write scale_alerts" on public.scale_alerts for ALL to public using (true);
create policy "Public read scale_alerts"  on public.scale_alerts for SELECT to public using (true);
create policy "Public write scales" on public.scales for ALL to public using (true);
create policy "Public read scales"  on public.scales for SELECT to public using (true);
create policy "Allow public all"    on public.voelker for ALL to public using (true) with check (true);
create policy "Public write weight_readings" on public.weight_readings for INSERT to public with check (true);
create policy "Public read weight_readings"  on public.weight_readings for SELECT to public using (true);
create policy material_media_all on storage.objects for ALL to public using ((bucket_id = 'material-media'::text)) with check ((bucket_id = 'material-media'::text));
create policy "Public upload construction photos" on storage.objects for INSERT to public with check ((bucket_id = 'construction-photos'::text));
create policy "Public upload receipts" on storage.objects for INSERT to public with check ((bucket_id = 'material-receipts'::text));
create policy "Public read construction photos" on storage.objects for SELECT to public using ((bucket_id = 'construction-photos'::text));
create policy "Public read receipts" on storage.objects for SELECT to public using ((bucket_id = 'material-receipts'::text));
create policy "Public update construction photos" on storage.objects for UPDATE to public using ((bucket_id = 'construction-photos'::text));
create policy "Public update receipts" on storage.objects for UPDATE to public using ((bucket_id = 'material-receipts'::text));
grant select, insert, update, delete on public.materials, public.material_purchases,
  public.weight_readings, public.scales, public.scale_alerts, public.funkstationen,
  public.voelker, public.construction_steps to anon;
