-- A02_tenancy_tabellen.sql | Mandanten-Fundament (Muster KMU 0001/0013), Bienen-Domaene.
create type public.betrieb_rolle as enum ('owner','editor','viewer');

create table public.betriebe (
  id         uuid primary key default gen_random_uuid(),
  name       text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  is_deleted boolean not null default false
);
create trigger trg_betriebe_updated before update on public.betriebe
  for each row execute function private.set_updated_at();

-- Spiegel von auth.users (id = auth.users.id); Anzeige "Geaendert von X".
create table public.profiles (
  id           uuid primary key references auth.users(id) on delete cascade,
  email        text,
  display_name text,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);
create trigger trg_profiles_updated before update on public.profiles
  for each row execute function private.set_updated_at();

create table public.betrieb_mitglieder (
  id         uuid primary key default gen_random_uuid(),
  betrieb_id uuid not null references public.betriebe(id) on delete cascade,
  user_id    uuid not null references public.profiles(id) on delete cascade,
  rolle      public.betrieb_rolle not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  is_deleted boolean not null default false,
  unique (betrieb_id, user_id)
);
create trigger trg_betrieb_mitglieder_updated before update on public.betrieb_mitglieder
  for each row execute function private.set_updated_at();
create index idx_mitglieder_betrieb on public.betrieb_mitglieder (betrieb_id);
create index idx_mitglieder_user    on public.betrieb_mitglieder (user_id);

-- Code-basierte Einladung: NUR der SHA-256-Hash wird gespeichert.
create table public.einladungen (
  id             uuid primary key default gen_random_uuid(),
  betrieb_id     uuid not null references public.betriebe(id) on delete cascade,
  email          text not null,
  rolle          public.betrieb_rolle not null,
  code_hash      text not null,
  status         text not null default 'offen'
                 check (status in ('offen','angenommen','widerrufen')),
  ablauf_am      timestamptz not null default now() + interval '7 days',
  eingeladen_von uuid,
  angenommen_von uuid,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);
create trigger trg_einladungen_updated before update on public.einladungen
  for each row execute function private.set_updated_at();
create index idx_einladungen_betrieb on public.einladungen (betrieb_id);
create unique index idx_einladungen_code on public.einladungen (code_hash);
-- Nie zwei OFFENE Einladungen an dieselbe (normalisierte) Adresse pro Betrieb.
create unique index idx_einladungen_offen_pro_email
  on public.einladungen (betrieb_id, lower(email)) where status = 'offen';

alter table public.betriebe           enable row level security;
alter table public.profiles           enable row level security;
alter table public.betrieb_mitglieder enable row level security;
alter table public.einladungen        enable row level security;
