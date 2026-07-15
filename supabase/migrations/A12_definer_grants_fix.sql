-- A12_definer_grants_fix.sql | Advisor-Fund nach A11 (0028/0029):
-- public.handle_new_auth_user() ist eine reine TRIGGER-Funktion, war aber ueber den
-- Postgres-Default-Grant an PUBLIC via PostgREST (/rest/v1/rpc/) fuer anon+authenticated
-- aufrufbar. Der Trigger feuert unabhaengig von EXECUTE-Grants -> ersatzlos entziehen.
revoke all on function public.handle_new_auth_user() from public, anon, authenticated;

-- Bewusst NICHT entzogen (by design, dokumentiert):
--   betrieb_gruenden / mitglied_einladen / einladung_annehmen / einladung_widerrufen /
--   team_mitglieder bleiben fuer `authenticated` aufrufbar — sie SIND die Auth-API.
--   Advisor 0029 meldet das als Hinweis ("if that is not intentional"); es ist intentional.
--   Jede dieser RPCs traegt eigene Guards (auth.uid()-Null-Check, Owner-Check, BA0xx-errcodes)
--   und ist von anon/public entzogen.
