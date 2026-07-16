-- A09_fachtabellen_rls.sql | STRIKTE authenticated-Policies ZUSAETZLICH zu den
-- bestehenden public-Policies. Postgres OR-verknuepft permissive Policies je Kommando
-- -> nichts bricht, bis die public-Policies im Cutover (Plan 3) gedroppt werden.
-- SELECT: Mitglied (Set-Form, performant auf Zeitreihen). Schreiben: owner|editor.
do $$
declare t text;
begin
  foreach t in array array['materials','material_purchases','weight_readings','scales',
                           'scale_alerts','funkstationen','voelker','construction_steps'] loop
    execute format(
      'create policy %I on public.%I for select to authenticated '
      || 'using (betrieb_id in (select private.meine_betrieb_ids()))', t||'_sel_member', t);
    execute format(
      'create policy %I on public.%I for insert to authenticated '
      || 'with check (private.kann_schreiben(betrieb_id))', t||'_ins_writer', t);
    execute format(
      'create policy %I on public.%I for update to authenticated '
      || 'using (private.kann_schreiben(betrieb_id)) '
      || 'with check (private.kann_schreiben(betrieb_id))', t||'_upd_writer', t);
    execute format(
      'create policy %I on public.%I for delete to authenticated '
      || 'using (private.kann_schreiben(betrieb_id))', t||'_del_writer', t);
  end loop;
end $$;
