-- A11_haertung.sql | Vorbestehende, advisor-geflaggte Funktion search_path pinnen.
-- Ermittelt via pg_proc: einzige Fundstelle ist public.update_updated_at().
-- Body ist ein reiner updated_at-Setzer (new.updated_at = now(); return new;) OHNE
-- Tabellen-Referenzen -> search_path = '' ist sicher (bricht nichts).
alter function public.update_updated_at() set search_path = '';
