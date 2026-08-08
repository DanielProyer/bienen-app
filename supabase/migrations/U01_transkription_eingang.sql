-- U01_transkription_eingang.sql | Durchreiche-Bucket fuer die Erkennung.
--
-- WARUM: Bisher ging die Tonaufnahme im Koerper der Anfrage an die Edge
-- Function. Das scheitert bei langen Aufnahmen aus zwei Gruenden zugleich:
--
--  1. Die 150-Sekunden-Grenze von Supabase umfasst den UPLOAD, nicht erst die
--     Bearbeitung. Gemessen: 9,65 MB ueber eine langsame Leitung -> 504 nach
--     165 s, ohne dass ein Erkenner ueberhaupt angefangen haette. Dieselbe
--     Datei mit 120 KB -> Antwort nach 0,28 s.
--  2. Bei drei Anbietern ging dieselbe Datei DREIMAL ueber die Leitung.
--
-- Neuer Weg: Der Browser laedt die Datei EINMAL hierher (ueber eine signierte
-- Upload-Adresse, die die Function ausstellt), und die Function holt sie
-- danach im Rechenzentrum ab. Damit enthaelt das Zeitfenster keine
-- Mobilfunkstrecke mehr.
--
-- KEINE Policies fuer `authenticated`: Auf diesen Bucket greift ausschliesslich
-- die Function mit dem Service-Key zu. Der Browser kommt nur ueber die
-- signierte Adresse hinein, die fuer genau einen Pfad gilt und ablaeuft — er
-- braucht dafuer weder Login noch Leserecht. Damit ist der Bucket von aussen
-- vollstaendig dicht, obwohl ihn eine Seite ohne Anmeldung benutzt.
insert into storage.buckets (id, name, public)
  values ('transkription-eingang', 'transkription-eingang', false)
  on conflict (id) do nothing;

-- ROLLBACK:
--   delete from storage.objects where bucket_id = 'transkription-eingang';
--   delete from storage.buckets where id = 'transkription-eingang';
