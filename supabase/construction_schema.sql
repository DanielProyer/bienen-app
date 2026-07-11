-- Bienen App: Construction (Bienenstand-Bau) Schema
-- Fortschritt je Bauschritt (abgehakt, Notiz, Foto). Die fachlichen Inhalte
-- (Anleitung, Zeichnungen, Soll) liegen statisch im App-Code
-- (lib/features/construction/data/models/build_step_content.dart), verbunden
-- über step_key.

create table if not exists construction_steps (
  id uuid primary key default gen_random_uuid(),
  step_key text not null unique,   -- doppelbalken, rechteck, ... (siehe kBuildSteps)
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

create trigger construction_steps_updated_at
  before update on construction_steps
  for each row execute function update_updated_at();

-- Seed: 12 Bauschritte in Reihenfolge
insert into construction_steps (step_key, sort_order) values
('doppelbalken',0),('rechteck',1),('erdschrauben',2),('pfosten',3),
('nivellierbolzen',4),('nivellieren',5),('platten_zuschnitt',6),('platten_montage',7),
('oel',8),('waagen_beuten',9),('endabnahme',10),('nachkontrolle',11);

-- Storage-Bucket für Baufotos (public); Fotos werden als <step_key>.jpg abgelegt
insert into storage.buckets (id, name, public)
values ('construction-photos', 'construction-photos', true)
on conflict (id) do nothing;

create policy "Public read construction photos" on storage.objects
  for select using (bucket_id = 'construction-photos');
create policy "Public upload construction photos" on storage.objects
  for insert with check (bucket_id = 'construction-photos');
create policy "Public update construction photos" on storage.objects
  for update using (bucket_id = 'construction-photos');
