-- C04_voelker.sql | voelker: neue Spalten/FKs/CHECKs, Drops (rasse/standort/koenigin_jahr),
-- status NOT NULL+CHECK, partieller Unique-Index auf koenigin_id. Same-Tenant-Komposit-FKs.
-- Haertet zugleich die Bestandsluecke scales.volk_id.

-- Leer-Guard: Drops nur zulaessig, weil voelker leer ist.
do $$ begin
  if (select count(*) from public.voelker) > 0 then
    raise exception 'voelker nicht leer (% Zeilen) — C04 abgebrochen', (select count(*) from public.voelker);
  end if;
end $$;

-- (a) neue Spalten
alter table public.voelker add column if not exists standort_id uuid;
alter table public.voelker add column if not exists koenigin_id uuid;
alter table public.voelker add column if not exists mutter_volk_id uuid;
alter table public.voelker add column if not exists beutentyp text;
alter table public.voelker add column if not exists zargen int;
alter table public.voelker add column if not exists brutwaben int;
alter table public.voelker add column if not exists bio_status text not null default 'unbekannt'
  check (bio_status in ('bio','umstellung','konventionell','unbekannt'));
alter table public.voelker add column if not exists gesundheitsstatus text not null default 'unauffaellig'
  check (gesundheitsstatus in ('unauffaellig','beobachtung','krank','sperre'));

-- (b) status haerten (Spalte existiert bereits, nullable, ohne CHECK; Tabelle leer)
alter table public.voelker alter column status set default 'aktiv';
alter table public.voelker alter column status set not null;
alter table public.voelker add constraint voelker_status_check
  check (status in ('aktiv','aufgeloest','vereinigt','verkauft','verloren'));

-- (c) Aufraeumen (Hardcode/Altlast) — Tabelle leer, kein Code referenziert die Spalten
alter table public.voelker drop column if exists rasse;         -- Rasse gehoert an die Koenigin
alter table public.voelker drop column if exists standort;      -- ersetzt durch standort_id
alter table public.voelker drop column if exists koenigin_jahr; -- ersetzt durch koeniginnen.schlupfjahr

-- (d) Same-Tenant-Integritaet: Zielschluessel + Komposit-FKs
alter table public.voelker add constraint voelker_betrieb_id_uniq unique (betrieb_id, id);

alter table public.voelker add constraint voelker_standort_fk
  foreign key (betrieb_id, standort_id) references public.standorte (betrieb_id, id)
  on delete set null (standort_id);
alter table public.voelker add constraint voelker_koenigin_fk
  foreign key (betrieb_id, koenigin_id) references public.koeniginnen (betrieb_id, id)
  on delete set null (koenigin_id);
alter table public.voelker add constraint voelker_mutter_fk
  foreign key (betrieb_id, mutter_volk_id) references public.voelker (betrieb_id, id)
  on delete set null (mutter_volk_id);

-- koeniginnen.volk_id-FK jetzt nachziehen (voelker.unique(betrieb_id,id) existiert nun)
alter table public.koeniginnen add constraint koeniginnen_volk_fk
  foreign key (betrieb_id, volk_id) references public.voelker (betrieb_id, id)
  on delete set null (volk_id);

-- scales.volk_id-Bestandsluecke schliessen (scales hat betrieb_id)
alter table public.scales drop constraint if exists scales_volk_id_fkey;
alter table public.scales add constraint scales_volk_id_fkey
  foreign key (betrieb_id, volk_id) references public.voelker (betrieb_id, id)
  on delete set null (volk_id);

-- (e) Koenigin 1:1 zum Volk als DB-Garantie (deckt CRUD-Pfad + RPC-Race)
create unique index if not exists voelker_koenigin_uniq
  on public.voelker (koenigin_id) where koenigin_id is not null;

-- (f) FK-fuehrende Indizes (sonst unindexed_foreign_keys-Advisor)
create index if not exists idx_voelker_standort on public.voelker (standort_id);
create index if not exists idx_voelker_mutter on public.voelker (mutter_volk_id);
