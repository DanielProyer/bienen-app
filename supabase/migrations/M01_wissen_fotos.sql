-- M01_wissen_fotos.sql | Wissensdatenbank: eigene Beispiel-Fotos je Betrieb (Modul 4.21).
-- Privater Bucket + mandantenfähige Tabelle. Muster: L01 (Tabelle) + G02 (Bucket/Storage).
-- wissen_key ist bewusst OHNE FK (Katalog lebt in Dart-const). storage_path-CHECK = Defense-in-Depth.
create table if not exists public.wissen_fotos (
  id uuid primary key default gen_random_uuid(),
  wissen_key text not null check (length(btrim(wissen_key)) > 0),
  storage_path text not null check (storage_path like (betrieb_id::text || '/%')),
  beschriftung text,
  betrieb_id uuid not null default private.aktive_betrieb_id()
    references public.betriebe(id) on delete cascade,
  created_by uuid, updated_by uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (betrieb_id, id)
);
alter table public.wissen_fotos enable row level security;
revoke all on public.wissen_fotos from anon, public;
grant select, insert, update, delete on public.wissen_fotos to authenticated;
create index if not exists idx_wissen_fotos_key on public.wissen_fotos (betrieb_id, wissen_key);

drop trigger if exists trg_wissen_fotos_actor on public.wissen_fotos;
create trigger trg_wissen_fotos_actor before insert or update
  on public.wissen_fotos for each row execute function private.set_row_actor();
drop trigger if exists trg_wissen_fotos_updated on public.wissen_fotos;
create trigger trg_wissen_fotos_updated before update
  on public.wissen_fotos for each row execute function private.set_updated_at();

drop policy if exists wissen_fotos_sel_member on public.wissen_fotos;
create policy wissen_fotos_sel_member on public.wissen_fotos
  for select to authenticated using (betrieb_id in (select private.meine_betrieb_ids()));
drop policy if exists wissen_fotos_ins_writer on public.wissen_fotos;
create policy wissen_fotos_ins_writer on public.wissen_fotos
  for insert to authenticated with check (private.kann_schreiben(betrieb_id));
drop policy if exists wissen_fotos_upd_writer on public.wissen_fotos;
create policy wissen_fotos_upd_writer on public.wissen_fotos
  for update to authenticated using (private.kann_schreiben(betrieb_id)) with check (private.kann_schreiben(betrieb_id));
drop policy if exists wissen_fotos_del_writer on public.wissen_fotos;
create policy wissen_fotos_del_writer on public.wissen_fotos
  for delete to authenticated using (private.kann_schreiben(betrieb_id));

insert into storage.buckets (id, name, public)
  values ('wissen-photos', 'wissen-photos', false)
  on conflict (id) do nothing;

drop policy if exists auth_sel_wissen_photos on storage.objects;
create policy auth_sel_wissen_photos on storage.objects for select to authenticated
  using (bucket_id = 'wissen-photos'
    and (storage.foldername(name))[1] ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
    and private.ist_mitglied(((storage.foldername(name))[1])::uuid));
drop policy if exists auth_ins_wissen_photos on storage.objects;
create policy auth_ins_wissen_photos on storage.objects for insert to authenticated
  with check (bucket_id = 'wissen-photos'
    and (storage.foldername(name))[1] ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
    and private.kann_schreiben(((storage.foldername(name))[1])::uuid));
drop policy if exists auth_upd_wissen_photos on storage.objects;
create policy auth_upd_wissen_photos on storage.objects for update to authenticated
  using (bucket_id = 'wissen-photos'
    and (storage.foldername(name))[1] ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
    and private.kann_schreiben(((storage.foldername(name))[1])::uuid))
  with check (bucket_id = 'wissen-photos'
    and (storage.foldername(name))[1] ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
    and private.kann_schreiben(((storage.foldername(name))[1])::uuid));
drop policy if exists auth_del_wissen_photos on storage.objects;
create policy auth_del_wissen_photos on storage.objects for delete to authenticated
  using (bucket_id = 'wissen-photos'
    and (storage.foldername(name))[1] ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
    and private.kann_schreiben(((storage.foldername(name))[1])::uuid));

-- ROLLBACK (vollständig):
--   drop policy if exists auth_sel_wissen_photos on storage.objects;
--   drop policy if exists auth_ins_wissen_photos on storage.objects;
--   drop policy if exists auth_upd_wissen_photos on storage.objects;
--   drop policy if exists auth_del_wissen_photos on storage.objects;
--   delete from storage.objects where bucket_id = 'wissen-photos';
--   delete from storage.buckets where id = 'wissen-photos';
--   drop table if exists public.wissen_fotos;
