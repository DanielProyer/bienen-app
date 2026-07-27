-- Q01_backup_schema.sql | Schema-Auskunft fuer das Offsite-Backup.
--
-- WARUM: `scripts/backup.mjs` (Repo bienen-backup) liest die Tabellenliste
-- bewusst aus dem Schema und nicht aus einer gepflegten Liste — sonst faellt
-- eine neu angelegte Tabelle stillschweigend aus dem Backup. Bisherige Quelle
-- war die PostgREST-OpenAPI-Spec unter `GET /rest/v1/`. Dieser Endpunkt ist
-- aber service_role-only; gemessen am Projekt (2026-07-27):
--   anon-Key            -> 401 "Only the `service_role` API key can be used"
--   sb_publishable-Key  -> 401 "Secret API key required"
-- Damit haengt das Backup an genau einem Key-Typ. Diese Funktion loest die
-- Kopplung: sie liefert dieselbe Information (Tabelle -> Spalten) ueber einen
-- normalen RPC-Aufruf.
--
-- Rueckgabe absichtlich Tabelle+Spalten (nicht nur Namen): das Skript erkennt
-- an der Spalte `betrieb_id`, welche Tabellen betriebsbezogen sind, und
-- gruppiert das Backup danach.
--
-- Nur BASE TABLE, keine Views: Views sind abgeleitet, im Backup redundant und
-- haben teils keinen stabilen Sortierschluessel. (Das Backup ist noch nie
-- gelaufen, es gehen also keine bestehenden Dateien verloren.)
--
-- KEINE Mandantendaten: ausschliesslich Metadaten (Tabellen-/Spaltennamen).
-- Deshalb auch kein betrieb_id-Filter — es gibt nichts zu isolieren.

create or replace function public.backup_schema()
returns table (tabelle text, spalten text[])
language sql
security definer
set search_path = ''
stable
as $$
  select c.table_name::text,
         array_agg(c.column_name::text order by c.column_name)
    from information_schema.columns c
    join information_schema.tables t
      on t.table_schema = c.table_schema
     and t.table_name  = c.table_name
   where c.table_schema = 'public'
     and t.table_type   = 'BASE TABLE'
   group by c.table_name
$$;

comment on function public.backup_schema() is
  'Tabelle -> Spalten (public, nur BASE TABLE) fuer das Offsite-Backup. '
  'Ersetzt GET /rest/v1/, das service_role-only ist. Nur Metadaten.';

-- Rechte: NUR service_role. Die App braucht diese Auskunft nicht (ihr
-- client-seitiger Export kennt seine Tabellen), und ein Grant ohne Bedarf ist
-- ein Grant zu viel — auch wenn hier nur Metadaten flossen. Weicht bewusst
-- vom Hausmuster "grant to authenticated" ab.
--
-- ACHTUNG (Fund bei der Verifikation, siehe Q02): `revoke ... from anon, public`
-- reicht NICHT. Supabase vergibt per Default-Privileges ein EIGENES
-- EXECUTE-Grant an `authenticated`; das ueberlebt ein revoke von PUBLIC.
-- Nach Q01 allein konnte `authenticated` die Funktion aufrufen. Deshalb hier
-- authenticated explizit mitentziehen.
revoke execute on function public.backup_schema() from anon, authenticated, public;
grant  execute on function public.backup_schema() to service_role;

-- VERIFIKATION (als service_role, so wie der Backup-Lauf):
--   select count(*) from public.backup_schema();
--     -> erwartet: Anzahl BASE TABLEs in public (2026-07-27: 20)
--   select tabelle from public.backup_schema()
--    where 'betrieb_id' = any(spalten) order by 1;
--     -> erwartet: die betriebsbezogenen Fachtabellen
--   Gegenprobe, dass anon NICHT darf:
--     set local role anon; select public.backup_schema();  -> permission denied
--
-- ROLLBACK: drop function public.backup_schema();
--           (Danach braucht backup.mjs wieder GET /rest/v1/ und damit einen
--            Legacy-service_role-Key.)
