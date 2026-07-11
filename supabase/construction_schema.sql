-- Bienen App: Construction (Bienenstand-Bau) Schema
-- Tabelle für die Bau-Checkliste + Foto-Dokumentation

create table if not exists construction_steps (
  id uuid primary key default gen_random_uuid(),
  phase text not null,           -- vorbereitung | einkauf | bau | abnahme | nachkontrolle
  foto_code text not null,       -- F00..F18
  title text not null,
  soll text,
  sort_order int default 0,
  is_done boolean default false,
  note text,
  photo_url text,
  photo_taken_at timestamptz,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

alter table construction_steps enable row level security;

create policy "Allow public read" on construction_steps for select using (true);
create policy "Allow public insert" on construction_steps for insert with check (true);
create policy "Allow public update" on construction_steps for update using (true);
create policy "Allow public delete" on construction_steps for delete using (true);

-- update_updated_at() existiert bereits (materials); Trigger wiederverwenden
create trigger construction_steps_updated_at
  before update on construction_steps
  for each row execute function update_updated_at();

-- Seed: 19 Foto-/Kontrollpunkte (F00-F18)
insert into construction_steps (phase, foto_code, title, soll, sort_order) values
('vorbereitung','F00','Standort vor Baubeginn (Übersicht Fläche + Ausrichtung Südost)', null, 0),
('einkauf','F01','Eingekauftes Material komplett ausgelegt (Vollständigkeits-Beleg)', null, 1),
('bau','F02','Beide fertigen Doppelbalken, Stossversatz sichtbar','Stösse liegen nie übereinander; Balken gerade, kein Verzug', 2),
('bau','F03','Angezeichnetes Rechteck 2000×400 mit Massband','Beinabstand 2000 mm, Balkenachse 400 mm, Diagonalen gleich', 3),
('bau','F04','Alle 4 Erdschrauben gesetzt (Übersicht)','Positionen = Rechteck aus Schritt 2', 4),
('bau','F05','Wasserwaage an einer Hülse (Lot-Beleg)','Jede Erdschraube lotrecht', 5),
('bau','F06','Durchbolzter Pfosten im U-FIX (Detail)','Pfosten fest, grob gleiche Oberkante', 6),
('bau','F07','Nivellier-Bolzen im Pfostenkopf (Detail)','Schraube leichtgängig, Scheibe plan, ±25 mm frei', 7),
('bau','F08','Laser-/Wasserwaagen-Kontrolle auf dem Balken','Balken waagerecht längs UND quer; Kontermuttern fest', 8),
('bau','F09','Schwerlast-Winkel montiert (Detail)','Je Balken 2 Winkel, 8 gesamt', 9),
('bau','F10','Platte mit versiegelten Kanten + Entwässerungslöchern','Kanten rundum versiegelt; Löcher Ø 8 mm', 10),
('bau','F11','Alle 4 Platten montiert (Gesamtansicht)','Völkerabstand ≈ 265 mm, Plattenlücke ~160 mm', 11),
('bau','F12','Wasserwaage auf einer Platte','Jede Platte waagerecht (Waagengenauigkeit)', 12),
('bau','F13','Fertig behandelter, getrockneter Stand','Kein blankes Hirnholz', 13),
('bau','F14','Waage auf Platte (vor Beute)','Reihenfolge Platte → Waage → Beute', 14),
('bau','F15','Fertiger Stand mit 4 Beuten, Fluglöcher Südost','Beutenboden ≈ 44 cm', 15),
('abnahme','F16','Übersicht Endzustand','Keine Durchbiegung sichtbar (< 0,5 mm bei Vollvolk)', 16),
('abnahme','F17','Detail Nivellierung/Kontermutter (Abnahme-Beleg)','Kontermuttern fest', 17),
('nachkontrolle','F18','Nach dem Nachnivellieren (Datum im Dateinamen)','Wieder exakt waagerecht; keine losen Verbindungen', 18);

-- Storage-Bucket für Baufotos (public)
insert into storage.buckets (id, name, public)
values ('construction-photos', 'construction-photos', true)
on conflict (id) do nothing;

create policy "Public read construction photos" on storage.objects
  for select using (bucket_id = 'construction-photos');
create policy "Public upload construction photos" on storage.objects
  for insert with check (bucket_id = 'construction-photos');
create policy "Public update construction photos" on storage.objects
  for update using (bucket_id = 'construction-photos');
