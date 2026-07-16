-- A07_tenancy_rls.sql | RLS auf betriebe/profiles/betrieb_mitglieder/einladungen.
-- Schreiben auf betriebe/betrieb_mitglieder/einladungen NUR via DEFINER-RPCs
-- (bewusst KEINE authenticated-INSERT-Policy -> kein Selbst-Insert in fremde Betriebe).

-- betriebe: sehen = Mitglied; aendern = owner.
create policy betriebe_select on public.betriebe for select to authenticated
  using (id in (select private.meine_betrieb_ids()));
create policy betriebe_update_owner on public.betriebe for update to authenticated
  using (private.rolle_im_betrieb(id) = 'owner')
  with check (private.rolle_im_betrieb(id) = 'owner');

-- profiles: self + Betriebskollegen lesen; nur eigene Zeile aendern.
create policy profiles_select on public.profiles for select to authenticated
  using (id = (select auth.uid()) or private.teilt_betrieb(id));
create policy profiles_update_self on public.profiles for update to authenticated
  using (id = (select auth.uid())) with check (id = (select auth.uid()));
-- email immutabel: nur display_name per Client aenderbar.
revoke update on public.profiles from authenticated;
grant update (display_name) on public.profiles to authenticated;

-- betrieb_mitglieder: sehen = eigener Betrieb; aendern/loeschen = NUR owner
-- (nie kann_schreiben -> sonst Self-Escalation). Insert nur via DEFINER-RPCs.
create policy betrieb_mitglieder_select on public.betrieb_mitglieder for select to authenticated
  using (betrieb_id in (select private.meine_betrieb_ids()));
create policy betrieb_mitglieder_update_owner on public.betrieb_mitglieder for update to authenticated
  using (private.rolle_im_betrieb(betrieb_id) = 'owner')
  with check (private.rolle_im_betrieb(betrieb_id) = 'owner');
create policy betrieb_mitglieder_delete_owner on public.betrieb_mitglieder for delete to authenticated
  using (private.rolle_im_betrieb(betrieb_id) = 'owner');

-- einladungen: nur owner des Betriebs sieht sie; Schreiben nur via DEFINER-RPCs.
create policy einladungen_select_owner on public.einladungen for select to authenticated
  using (private.rolle_im_betrieb(betrieb_id) = 'owner');
