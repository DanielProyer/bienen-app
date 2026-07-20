-- I01_betriebs_einstellungen_strategie.sql | 3 Strategie-Weichen fürs Betriebsprofil (F4).
-- Additiv (Spalten), Defaults = Arosa-tauglich (1 Ernte, Ameisensäure, keine Vermehrung).
-- UPDATE-Policy existiert bereits (C01 betriebs_einstellungen_upd_writer). Column-Grant-Härtung:
-- amtliche Felder (imker_identnummer/kanton) aus dem App-Schreibpfad halten.

alter table public.betriebs_einstellungen
  add column if not exists anzahl_ernten int not null default 1
    check (anzahl_ernten in (1, 2)),
  add column if not exists sommerbehandlung_methode text not null default 'ameisensaeure'
    check (sommerbehandlung_methode in ('ameisensaeure', 'biotechnisch', 'beide')),
  add column if not exists vermehrung_aktiv boolean not null default false;

-- Compliance-Härtung: UPDATE der App auf die 5 editierbaren Spalten beschränken
-- (amtliche Felder imker_identnummer/kanton bleiben ausserhalb; Ops/Service-Role bypasst Grants).
revoke update on public.betriebs_einstellungen from authenticated;
grant update (saison_offset_default_tage, winterfutter_ziel_kg,
              anzahl_ernten, sommerbehandlung_methode, vermehrung_aktiv)
  on public.betriebs_einstellungen to authenticated;

-- ROLLBACK (Ops):
--   revoke update (...) on public.betriebs_einstellungen from authenticated;
--   grant update on public.betriebs_einstellungen to authenticated;
--   alter table public.betriebs_einstellungen
--     drop column vermehrung_aktiv, drop column sommerbehandlung_methode, drop column anzahl_ernten;
