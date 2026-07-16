-- B01_cutover_tabellen.sql | CUTOVER (brechend): die alten {public}-Policies der 8
-- Bestandstabellen droppen. Danach gelten ausschliesslich die strikten
-- authenticated-Policies aus A09 -> echte Mandanten-Isolation.
-- Voraussetzung: Bootstrap-Backfill + NOT NULL gelaufen, Test-Gate gruen.
do $$
declare p record;
begin
  for p in select schemaname, tablename, policyname
             from pg_policies
            where schemaname = 'public'
              and roles = '{public}'
              and tablename in ('materials','material_purchases','weight_readings','scales',
                                'scale_alerts','funkstationen','voelker','construction_steps')
  loop
    execute format('drop policy %I on %I.%I', p.policyname, p.schemaname, p.tablename);
  end loop;
end $$;

-- Defense-in-Depth: anon braucht auf den Fachtabellen gar nichts mehr (App ist gated,
-- der Cron laeuft als service_role). RLS wuerde ohnehin blocken — der Grant war die
-- zweite Haelfte des Lochs.
revoke all on public.materials, public.material_purchases, public.weight_readings,
  public.scales, public.scale_alerts, public.funkstationen, public.voelker,
  public.construction_steps from anon;
