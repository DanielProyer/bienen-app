-- Bienen App: Supabase Schema
-- Run this in the Supabase SQL Editor

-- Materials table
create table if not exists materials (
  id uuid primary key default gen_random_uuid(),
  category text not null,
  name text not null,
  description text,
  quantity int default 1,
  unit text,
  price_chf decimal(10,2),
  supplier text,
  supplier_url text,
  phase int not null default 1,
  status text default 'offen' check (status in ('offen', 'bestellt', 'geliefert')),
  notes text,
  sort_order int default 0,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- Enable RLS
alter table materials enable row level security;

-- Allow public read/write for now (no auth yet)
create policy "Allow public read" on materials for select using (true);
create policy "Allow public insert" on materials for insert with check (true);
create policy "Allow public update" on materials for update using (true);
create policy "Allow public delete" on materials for delete using (true);

-- Auto-update updated_at
create or replace function update_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

create trigger materials_updated_at
  before update on materials
  for each row execute function update_updated_at();

-- Seed data
insert into materials (category, name, description, quantity, unit, price_chf, supplier, phase, status, sort_order) values
('Beute', 'Komplettbeute DB Halbzargen Hochboden', 'Inkl. Blechdeckel, Brutzarge, 2 Honighalbzargen, Hochboden, Absperrgitter', 2, 'Stk', 469.00, 'Wespi', 1, 'offen', 1),
('Beute', 'Zusätzliche Honighalbzargen DB', 'Reserve/Erweiterung', 2, 'Stk', 40.00, 'Wespi', 1, 'offen', 2),
('Beute', 'Futtertrog Nicot DB', 'Kunststoff-Fütterer', 2, 'Stk', 25.00, 'bienenbeuten.ch', 1, 'offen', 3),
('Beute', 'Rähmchen Brut DB (Hoffmann)', 'Gedrahtet, Reserve', 20, 'Stk', 2.10, 'Wespi', 1, 'offen', 4),
('Beute', 'Rähmchen Honig DB Halbrahmen', 'Reserve', 20, 'Stk', 1.80, 'Wespi', 1, 'offen', 5),
('Beute', 'Mittelwände DB Brutraum', null, 2, 'kg', 24.00, 'Wespi', 1, 'offen', 6),
('Beute', 'Mittelwände DB Honigraum', null, 2, 'kg', 24.00, 'Wespi', 1, 'offen', 7),
('Schutz', 'Imkerjacke mit Schleier', 'Baumwolle/Mesh', 2, 'Stk', 107.00, 'Wespi', 1, 'offen', 10),
('Schutz', 'Imkerhandschuhe Leder', 'Schafleder mit Stulpe', 2, 'Paar', 17.60, 'imkereiausruester.ch', 1, 'offen', 11),
('Werkzeug', 'Stockmeissel Schweizer Modell', 'Maxant Easy, Edelstahl', 1, 'Stk', 7.90, 'beetec', 1, 'offen', 20),
('Werkzeug', 'Smoker Dadant gross', 'Edelstahl, gebürstet', 1, 'Stk', 85.00, 'Wespi', 1, 'offen', 21),
('Werkzeug', 'Abkehrbesen', 'Weiche Borsten', 1, 'Stk', 5.90, 'beetec', 1, 'offen', 22),
('Werkzeug', 'Wabenzange Classic', null, 1, 'Stk', 8.90, 'imkereiausruester.ch', 1, 'offen', 23),
('Werkzeug', 'Einlöttrafo BPS Basic', '12-19V', 1, 'Stk', 59.80, 'imkereiausruester.ch', 1, 'offen', 24),
('Honigverarbeitung', 'Honigschleuder Logar 20/8 Radial', '20 Halbrahmen, Motorantrieb', 1, 'Stk', 1900.00, 'Logar', 2, 'offen', 30),
('Honigverarbeitung', 'Entdeckelungsgabel Edelstahl', null, 1, 'Stk', 33.50, 'Wespi', 2, 'offen', 31),
('Honigverarbeitung', 'Doppelsieb Edelstahl', 'Ø 240mm', 1, 'Stk', 45.00, 'bienenbeuten.ch', 2, 'offen', 32),
('Honigverarbeitung', 'Abfüllbehälter Edelstahl 25kg', 'Mit Quetschhahn', 1, 'Stk', 240.00, 'Wespi', 2, 'offen', 33),
('Honigverarbeitung', 'Refraktometer', 'Wassergehaltsmessung', 1, 'Stk', 69.00, 'Wespi', 2, 'offen', 34),
('Varroa', 'Nassenheider Professional Verdunster', 'Doppelpack', 1, 'Set', 29.00, 'Wespi', 1, 'offen', 40),
('Varroa', 'FORMIVAR 60% Ameisensäure', '1 Liter', 1, 'Fl', 30.50, 'Wespi', 1, 'offen', 41),
('Varroa', 'Oxalsäure-Dihydrat 75g', 'Winterbehandlung', 1, 'Pkg', 34.50, 'Wespi', 1, 'offen', 42),
('Fütterung', 'Futtersirup Apiinvert 16 kg', 'Bag-in-Box, Herbstauffütterung', 2, 'Box', 27.20, 'imkereiausruester.ch', 1, 'offen', 50),
('Fütterung', 'Apifonda Futterteig 2.5 kg', 'Frühjahrsstimulation', 1, 'Pkg', 7.00, 'imkereiausruester.ch', 1, 'offen', 51),
('Sonstiges', 'Beutenständer Metall', 'Robust', 2, 'Stk', 125.00, 'FAIE.ch', 1, 'offen', 60),
('Sonstiges', 'Mäuseschutzgitter', 'Fluglochschutz', 2, 'Stk', 8.00, 'Wespi', 1, 'offen', 61),
('Sonstiges', 'Stockwaage digital', 'LoRa-Übertragung', 1, 'Stk', 150.00, 'beenli', 2, 'offen', 62);
