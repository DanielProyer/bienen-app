-- T02_sprach_proben.sql | Spracheingabe: jede Aufnahme, plus privater Bucket.
--
-- PERSONENBEZOGEN wie benachrichtigungs_einstellungen (O01), nicht nach dem
-- ueblichen Mitglieder-Muster: Eine Sprachaufnahme ist die Stimme eines
-- Menschen und geht Kollegen desselben Betriebs nichts an.
--
-- soll_text wird als SCHNAPPSCHUSS gehalten, nicht nur ueber karte_id
-- verwiesen. Aendert sich die Karte spaeter, bleiben alte Messungen
-- auswertbar — sonst maesse man gegen einen Text, der beim Sprechen gar nicht
-- dastand.
create table if not exists public.sprach_proben (
  id uuid primary key default gen_random_uuid(),
  betrieb_id uuid not null default private.aktive_betrieb_id()
    references public.betriebe(id) on delete cascade,
  person_id uuid not null,
  karte_id uuid references public.sprach_karten(id) on delete set null,
  soll_text text not null default '',
  modus text not null check (modus in ('drill','frei')),
  storage_path text not null
    check (storage_path like (betrieb_id::text || '/' || person_id::text || '/%')),
  dauer_ms integer not null check (dauer_ms >= 0),
  groesse_b integer not null check (groesse_b >= 0),
  mime text not null default 'audio/webm',
  created_by uuid, updated_by uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  -- Zielpunkt fuer den zusammengesetzten Fremdschluessel aus T03. Ohne ihn
  -- laesst sich die betrieb_id einer Ergebniszeile nicht an die ihrer Probe
  -- ketten — sie koennte dann auf einen anderen Mandanten zeigen. Muster aus
  -- R01 (recherche_fotos).
  unique (betrieb_id, id)
);
alter table public.sprach_proben enable row level security;
revoke all on public.sprach_proben from anon, public;
grant select, insert, update, delete on public.sprach_proben to authenticated;

create index if not exists idx_sprach_proben_person
  on public.sprach_proben (betrieb_id, person_id, created_at desc);

drop trigger if exists trg_sprach_proben_actor on public.sprach_proben;
create trigger trg_sprach_proben_actor before insert or update
  on public.sprach_proben for each row execute function private.set_row_actor();
drop trigger if exists trg_sprach_proben_updated on public.sprach_proben;
create trigger trg_sprach_proben_updated before update
  on public.sprach_proben for each row execute function private.set_updated_at();

drop policy if exists sprach_proben_sel on public.sprach_proben;
create policy sprach_proben_sel on public.sprach_proben
  for select to authenticated
  using (person_id = private.current_app_user() and private.ist_mitglied(betrieb_id));
drop policy if exists sprach_proben_ins on public.sprach_proben;
create policy sprach_proben_ins on public.sprach_proben
  for insert to authenticated
  with check (person_id = private.current_app_user() and private.ist_mitglied(betrieb_id));
drop policy if exists sprach_proben_upd on public.sprach_proben;
create policy sprach_proben_upd on public.sprach_proben
  for update to authenticated
  using (person_id = private.current_app_user() and private.ist_mitglied(betrieb_id))
  with check (person_id = private.current_app_user() and private.ist_mitglied(betrieb_id));
-- Loeschen ist hier ausdruecklich erlaubt: "alle meine Trainingsdaten loeschen"
-- muss moeglich sein (Datenschutz), im Gegensatz zu O01.
--
-- BEWUSST OHNE ist_mitglied: Wer einen Betrieb verlaesst, verliert den Zugriff
-- auf dessen Daten — aber NIE das Recht, seine eigene Stimme zu loeschen.
-- Mit Mitgliedschaftspruefung waeren die Aufnahmen danach fuer niemanden mehr
-- erreichbar (Mitglieder sehen sie ohnehin nicht) und nur noch per
-- service_role zu entfernen. Bei einer Chat-ID (O01) waere das vertretbar, bei
-- Sprachaufnahmen nicht. person_id bindet weiterhin auf die eigenen Zeilen.
drop policy if exists sprach_proben_del on public.sprach_proben;
create policy sprach_proben_del on public.sprach_proben
  for delete to authenticated
  using (person_id = private.current_app_user());

insert into storage.buckets (id, name, public)
  values ('sprach-proben', 'sprach-proben', false)
  on conflict (id) do nothing;

-- Pfad <betrieb_id>/<person_id>/<uuid>.webm — BEIDE Ebenen werden geprueft.
-- Nur den Betrieb zu pruefen wuerde den personenbezogenen Schutz der Tabelle
-- auf dem Storage-Weg wieder aufheben.
drop policy if exists auth_sel_sprach_proben on storage.objects;
create policy auth_sel_sprach_proben on storage.objects for select to authenticated
  using (bucket_id = 'sprach-proben'
    and (storage.foldername(objects.name))[1] ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
    and private.ist_mitglied(((storage.foldername(objects.name))[1])::uuid)
    and (storage.foldername(objects.name))[2] = private.current_app_user()::text);
drop policy if exists auth_ins_sprach_proben on storage.objects;
create policy auth_ins_sprach_proben on storage.objects for insert to authenticated
  with check (bucket_id = 'sprach-proben'
    and (storage.foldername(objects.name))[1] ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
    and private.ist_mitglied(((storage.foldername(objects.name))[1])::uuid)
    and (storage.foldername(objects.name))[2] = private.current_app_user()::text);
-- Loeschen ohne ist_mitglied, aus demselben Grund wie bei der Tabelle: Die
-- eigene Stimme muss auch nach einem Austritt entfernbar bleiben. Die zweite
-- Pfadebene bindet weiterhin fest auf die eigene person_id.
drop policy if exists auth_del_sprach_proben on storage.objects;
create policy auth_del_sprach_proben on storage.objects for delete to authenticated
  using (bucket_id = 'sprach-proben'
    and (storage.foldername(objects.name))[2] = private.current_app_user()::text);

-- ROLLBACK:
--   drop policy if exists auth_sel_sprach_proben on storage.objects;
--   drop policy if exists auth_ins_sprach_proben on storage.objects;
--   drop policy if exists auth_del_sprach_proben on storage.objects;
--   delete from storage.objects where bucket_id = 'sprach-proben';
--   delete from storage.buckets where id = 'sprach-proben';
--   drop table if exists public.sprach_proben;
