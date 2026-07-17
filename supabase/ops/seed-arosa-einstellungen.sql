-- seed-arosa-einstellungen.sql | Ops (KEIN Migrationsfile). Setzt das Arosa-Profil auf die
-- von C01 angelegte betriebs_einstellungen-Zeile. Arosa = Daten, nicht Code. Idempotent.
update public.betriebs_einstellungen set
  rasse_default              = 'Buckfast',
  beutensystem_default       = 'Dadant Blatt 10er',
  hoehe_default_m            = 1570,
  saison_offset_default_tage = 42,
  kanton                     = 'GR'
where betrieb_id = '1c84d5dd-d22e-4bce-bba9-5e861b2f4aa4';  -- Imkerei-Projekt Arosa
