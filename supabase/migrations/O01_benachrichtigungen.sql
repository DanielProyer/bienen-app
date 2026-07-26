-- O01_benachrichtigungen.sql | F3: taeglicher Ueberblick via Telegram.
-- Aktiviert erstmals pg_cron + pg_net auf dieser DB.
create extension if not exists pg_cron;
-- pg_net ins extensions-Schema (nicht public) — sonst Advisor extension_in_public.
-- pg_net ist NICHT relocatable, aber seine Funktionen leben ohnehin im eigenen
-- `net`-Schema (net.http_post), daher bleibt der Cron-Aufruf unten unveraendert.
create extension if not exists pg_net with schema extensions;

create table if not exists public.benachrichtigungs_einstellungen (
  id uuid primary key default gen_random_uuid(),
  betrieb_id uuid not null default private.aktive_betrieb_id()
    references public.betriebe(id) on delete cascade,
  user_id uuid not null,
  kanal text not null default 'telegram' check (kanal in ('telegram')),
  telegram_chat_id text,
  aktiv boolean not null default false,
  sende_stunde smallint not null default 6 check (sende_stunde between 0 and 23),
  zeitzone text not null default 'Europe/Zurich',
  zuletzt_gesendet_am date,
  created_by uuid,
  updated_by uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (betrieb_id, user_id)
);

alter table public.benachrichtigungs_einstellungen enable row level security;

-- ABWEICHUNG vom Hausmuster ("Mitglied sieht alles"): eine Chat-ID ist
-- personenbezogen. Nur die EIGENE Zeile ist les- und schreibbar.
create policy ben_select_eigene on public.benachrichtigungs_einstellungen
  for select to authenticated
  using (user_id = private.current_app_user() and private.ist_mitglied(betrieb_id));
create policy ben_insert_eigene on public.benachrichtigungs_einstellungen
  for insert to authenticated
  with check (user_id = private.current_app_user() and private.ist_mitglied(betrieb_id));
create policy ben_update_eigene on public.benachrichtigungs_einstellungen
  for update to authenticated
  using (user_id = private.current_app_user() and private.ist_mitglied(betrieb_id))
  with check (user_id = private.current_app_user() and private.ist_mitglied(betrieb_id));
-- Bewusst KEINE delete-policy: Einstellungen werden deaktiviert, nicht geloescht.

create trigger trg_benachrichtigungen_actor
  before insert or update on public.benachrichtigungs_einstellungen
  for each row execute function private.set_row_actor();
create trigger trg_benachrichtigungen_updated
  before update on public.benachrichtigungs_einstellungen
  for each row execute function private.set_updated_at();

-- Stuendlicher Wecker. Die Function entscheidet, ob JETZT gesendet wird
-- (Zeitzone + sende_stunde + zuletzt_gesendet_am) — ein fester UTC-Termin
-- wuerde durch Sommer-/Winterzeit zweimal jaehrlich um eine Stunde verrutschen.
-- Laeuft ins Leere (404), bis die Edge Function deployt + das Vault-Secret
-- 'cron_shared_secret' gesetzt ist; pg_net verwirft Fehler ohne Nebenwirkung.
select cron.schedule('ueberblick-stuendlich', '5 * * * *', $cron$
  select net.http_post(
    url := 'https://dcdcohktxbhdxnxjvcyp.supabase.co/functions/v1/taeglicher-ueberblick',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-cron-secret', coalesce(
        (select decrypted_secret from vault.decrypted_secrets where name = 'cron_shared_secret'), '')
    ),
    body := '{}'::jsonb
  );
$cron$);

-- ROLLBACK: select cron.unschedule('ueberblick-stuendlich');
--           drop table public.benachrichtigungs_einstellungen;
--           (Extensions pg_cron/pg_net bewusst NICHT zurueckdrehen.)
