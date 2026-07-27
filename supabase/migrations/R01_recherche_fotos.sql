-- R01_recherche_fotos.sql | Recherchen: eigene Fotos je Betrieb, an ein Kapitel gehängt.
-- Privater Bucket + mandantenfähige Tabelle. Muster 1:1 aus M01 (wissen_fotos).
--
-- Zwei bewusste Abweichungen von M01:
--  * `anker` haelt die Sprungmarke des Kapitels (siehe markdown_anker.dart), damit
--    ein Foto DORT erscheint, wo es hingehoert — nicht in einer Galerie am Ende.
--    Nullable: ein Foto ohne Kapitelbezug bleibt moeglich und landet am Dokumentende.
--  * `recherche_key` ist der Dateiname ohne Endung (z. B. '30_Varroa_Bildzaehlung_Automatisierung').
--    Wie `wissen_key` bewusst OHNE FK — die Dokumentliste lebt in Assets/Dart, nicht in der DB.
-- storage_path-CHECK = Defense-in-Depth zusaetzlich zu den Storage-Policies.
create table if not exists public.recherche_fotos (
  id uuid primary key default gen_random_uuid(),
  recherche_key text not null check (length(btrim(recherche_key)) > 0),
  anker text,
  storage_path text not null check (storage_path like (betrieb_id::text || '/%')),
  beschriftung text,
  betrieb_id uuid not null default private.aktive_betrieb_id()
    references public.betriebe(id) on delete cascade,
  created_by uuid, updated_by uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (betrieb_id, id)
);
alter table public.recherche_fotos enable row level security;
revoke all on public.recherche_fotos from anon, public;
grant select, insert, update, delete on public.recherche_fotos to authenticated;
-- Leseweg der Ansicht: alle Fotos eines Dokuments, gruppiert nach Kapitel.
create index if not exists idx_recherche_fotos_key
  on public.recherche_fotos (betrieb_id, recherche_key, anker);

drop trigger if exists trg_recherche_fotos_actor on public.recherche_fotos;
create trigger trg_recherche_fotos_actor before insert or update
  on public.recherche_fotos for each row execute function private.set_row_actor();
drop trigger if exists trg_recherche_fotos_updated on public.recherche_fotos;
create trigger trg_recherche_fotos_updated before update
  on public.recherche_fotos for each row execute function private.set_updated_at();

drop policy if exists recherche_fotos_sel_member on public.recherche_fotos;
create policy recherche_fotos_sel_member on public.recherche_fotos
  for select to authenticated using (betrieb_id in (select private.meine_betrieb_ids()));
drop policy if exists recherche_fotos_ins_writer on public.recherche_fotos;
create policy recherche_fotos_ins_writer on public.recherche_fotos
  for insert to authenticated with check (private.kann_schreiben(betrieb_id));
drop policy if exists recherche_fotos_upd_writer on public.recherche_fotos;
create policy recherche_fotos_upd_writer on public.recherche_fotos
  for update to authenticated using (private.kann_schreiben(betrieb_id)) with check (private.kann_schreiben(betrieb_id));
drop policy if exists recherche_fotos_del_writer on public.recherche_fotos;
create policy recherche_fotos_del_writer on public.recherche_fotos
  for delete to authenticated using (private.kann_schreiben(betrieb_id));

insert into storage.buckets (id, name, public)
  values ('recherche-photos', 'recherche-photos', false)
  on conflict (id) do nothing;

drop policy if exists auth_sel_recherche_photos on storage.objects;
create policy auth_sel_recherche_photos on storage.objects for select to authenticated
  using (bucket_id = 'recherche-photos'
    and (storage.foldername(name))[1] ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
    and private.ist_mitglied(((storage.foldername(name))[1])::uuid));
drop policy if exists auth_ins_recherche_photos on storage.objects;
create policy auth_ins_recherche_photos on storage.objects for insert to authenticated
  with check (bucket_id = 'recherche-photos'
    and (storage.foldername(name))[1] ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
    and private.kann_schreiben(((storage.foldername(name))[1])::uuid));
drop policy if exists auth_upd_recherche_photos on storage.objects;
create policy auth_upd_recherche_photos on storage.objects for update to authenticated
  using (bucket_id = 'recherche-photos'
    and (storage.foldername(name))[1] ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
    and private.kann_schreiben(((storage.foldername(name))[1])::uuid))
  with check (bucket_id = 'recherche-photos'
    and (storage.foldername(name))[1] ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
    and private.kann_schreiben(((storage.foldername(name))[1])::uuid));
drop policy if exists auth_del_recherche_photos on storage.objects;
create policy auth_del_recherche_photos on storage.objects for delete to authenticated
  using (bucket_id = 'recherche-photos'
    and (storage.foldername(name))[1] ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
    and private.kann_schreiben(((storage.foldername(name))[1])::uuid));

-- ROLLBACK (vollständig):
--   drop policy if exists auth_sel_recherche_photos on storage.objects;
--   drop policy if exists auth_ins_recherche_photos on storage.objects;
--   drop policy if exists auth_upd_recherche_photos on storage.objects;
--   drop policy if exists auth_del_recherche_photos on storage.objects;
--   delete from storage.objects where bucket_id = 'recherche-photos';
--   delete from storage.buckets where id = 'recherche-photos';
--   drop table if exists public.recherche_fotos;
