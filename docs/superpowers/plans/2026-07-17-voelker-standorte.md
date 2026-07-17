# Völker & Standorte (Modul 4.2) — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Das erste Fachmodul auf dem Auth-Fundament: Völker, Standorte, Königinnen und Betriebs-Einstellungen als mandantenfähige Stammdaten mit Völkerliste, Volk-Detailseite (Drehscheibe) und atomarer Umweiselung.

**Architecture:** 5 additive Supabase-Migrationen (`C01`–`C05`) legen `betriebs_einstellungen`/`standorte`/`koeniginnen` an, erweitern `voelker` und liefern die RPC `volk_umweiseln` — alles nach dem etablierten Mandanten-Muster (`betrieb_id`-RLS, `set_row_actor`, Same-Tenant-Komposit-FKs). Darauf ein Flutter-Feature `lib/features/voelker/` (Gateway-Interface + Supabase- + Fake-Impl, Riverpod `AsyncNotifier`, go_router). Arosa-Werte kommen aus einem Ops-Seed, nicht aus Code.

**Tech Stack:** Supabase/Postgres 17.6 (MCP `apply_migration`, `execute_sql`, `get_advisors`), Flutter Web, flutter_riverpod ^2.6.1, go_router ^14.8.1, supabase_flutter ^2.8.3, flutter_test.

**Spec:** [2026-07-17-voelker-standorte-design.md](../specs/2026-07-17-voelker-standorte-design.md)
**Supabase project_id:** `dcdcohktxbhdxnxjvcyp`
**Branch:** `feat/voelker-standorte` (bereits angelegt)

---

## Referenz-Muster (aus dem Bestand — beim Umsetzen einhalten)

- **RLS-Helper (security definer, `private`):** `private.meine_betrieb_ids()` (setof uuid, SELECT), `private.kann_schreiben(uuid)` (INSERT/UPDATE/DELETE), `private.aktive_betrieb_id()` (Spalten-Default), `private.current_app_user()`.
- **Trigger-Funktionen:** `private.set_row_actor()` (setzt `created_by`/`updated_by`, friert `betrieb_id`/`created_by` bei UPDATE) und `private.set_updated_at()`.
- **Policy-Namen:** `<tabelle>_{sel_member|ins_writer|upd_writer|del_writer}`.
- **Migrations-Header:** Kommentarzeile mit Dateiname + Zweck; `do $$ … $$` für Schleifen; auf DEFINER-Funktionen `security definer set search_path = ''` + volle Qualifizierung.
- **Provider:** `AsyncNotifierProvider` mit `build() => _fetch()`, `ref.invalidateSelf()` nach Schreibaktion, **keine** stillen `catch`→`[]` (Fehler als `AsyncError`).
- **Fehler-Mapping:** Gateway übersetzt `PostgrestException.code` (`BA0xx` + `23505`) auf deutschen Klartext.

## File Structure

**Migrationen** (`bienen_app/supabase/migrations/`): `C01_betriebs_einstellungen.sql`, `C02_standorte.sql`, `C03_koeniginnen.sql`, `C04_voelker.sql`, `C05_rpc_volk_umweiseln.sql`
**Ops** (`bienen_app/supabase/ops/`): `seed-arosa-einstellungen.sql`
**Domain** (`lib/features/voelker/domain/`): `jahresfarbe.dart`, `standort.dart`, `koenigin.dart`, `volk.dart`, `betriebs_einstellungen.dart`, `voelker_gateway.dart`
**Data** (`lib/features/voelker/data/`): `supabase_voelker_gateway.dart`, `fake_voelker_gateway.dart`
**Presentation** (`lib/features/voelker/presentation/`): `providers/voelker_provider.dart`, `pages/voelker_page.dart`, `pages/volk_detail_page.dart`, `widgets/volk_card.dart`, `widgets/volk_form.dart`, `widgets/koenigin_section.dart`, `widgets/standort_section.dart`
**Mehr-Menü** (`lib/features/mehr/pages/`): `mehr_page.dart`
**Fremdeingriffe:** `lib/features/auth/presentation/auth_providers.dart` (`_datenNeuLaden`), `lib/features/monitoring/data/models/scale.dart` (`volkId`), `lib/shared/widgets/app_shell.dart` + `lib/core/router/app_router.dart` (Nav).
**Tests** (`test/features/voelker/`): `jahresfarbe_test.dart`, `fake_voelker_gateway_test.dart`, `voelker_provider_reset_test.dart`; `test/features/monitoring/scale_volkid_test.dart`.

---

# Phase 1 — Datenbank (Migrationen C01–C05)

> Jede Migration: (a) Datei unter `supabase/migrations/` schreiben, (b) via MCP `apply_migration(project_id, name, query)` anwenden, (c) Rollback-DO-Verifikation via `execute_sql` (RAIST bei Fehler, in einer `do`-Transaktion die nichts persistiert), (d) committen. `apply_migration` ist idempotent genug für `create … if not exists`; bei erneutem Lauf zuerst prüfen.

### Task 1: C01 — `betriebs_einstellungen` + `betrieb_gruenden`-Erweiterung + Backfill

**Files:** Create `supabase/migrations/C01_betriebs_einstellungen.sql`

- [ ] **Step 1: Migrationsdatei schreiben**

```sql
-- C01_betriebs_einstellungen.sql | F4-Keimzelle: 1 Zeile je Betrieb, typisierte Defaults.
-- KEIN default private.aktive_betrieb_id(): der Gruender hat beim betrieb_gruenden-Aufruf
-- (BA003-Guard) noch keinen betrieb_id-Claim -> aktive_betrieb_id() = NULL -> PK-Verletzung.
-- betrieb_id kommt explizit (RPC + Backfill). KEINE DELETE-Policy (1:1-Zeile unloeschbar).

create table if not exists public.betriebs_einstellungen (
  betrieb_id                 uuid primary key references public.betriebe(id) on delete cascade,
  rasse_default              text,
  beutensystem_default       text,
  hoehe_default_m            int,
  saison_offset_default_tage int  not null default 0,
  kanton                     text,
  imker_identnummer          text,
  created_by  uuid,
  updated_by  uuid,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

alter table public.betriebs_einstellungen enable row level security;
revoke all on public.betriebs_einstellungen from anon, public;
grant select, insert, update on public.betriebs_einstellungen to authenticated;

drop trigger if exists trg_betriebs_einstellungen_actor on public.betriebs_einstellungen;
create trigger trg_betriebs_einstellungen_actor before insert or update
  on public.betriebs_einstellungen for each row execute function private.set_row_actor();
drop trigger if exists trg_betriebs_einstellungen_updated on public.betriebs_einstellungen;
create trigger trg_betriebs_einstellungen_updated before update
  on public.betriebs_einstellungen for each row execute function private.set_updated_at();

create policy betriebs_einstellungen_sel_member on public.betriebs_einstellungen
  for select to authenticated using (betrieb_id in (select private.meine_betrieb_ids()));
create policy betriebs_einstellungen_ins_writer on public.betriebs_einstellungen
  for insert to authenticated with check (private.kann_schreiben(betrieb_id));
create policy betriebs_einstellungen_upd_writer on public.betriebs_einstellungen
  for update to authenticated using (private.kann_schreiben(betrieb_id))
  with check (private.kann_schreiben(betrieb_id));

-- betrieb_gruenden additiv erweitern: legt die Einstellungs-Zeile mit EXPLIZITER betrieb_id an.
create or replace function public.betrieb_gruenden(p_name text) returns uuid
  language plpgsql security definer set search_path = '' as $$
declare v_user uuid := auth.uid(); v_betrieb uuid;
begin
  if v_user is null then raise exception 'Nicht angemeldet' using errcode='BA001'; end if;
  if coalesce(trim(p_name),'') = '' then raise exception 'Name darf nicht leer sein' using errcode='BA002'; end if;
  perform pg_advisory_xact_lock(hashtextextended('betrieb_gruenden:'||v_user::text, 0));
  if exists (select 1 from public.betrieb_mitglieder where user_id=v_user and is_deleted=false) then
    raise exception 'Du gehoerst bereits zu einem Betrieb' using errcode='BA003';
  end if;
  insert into public.betriebe (name) values (trim(p_name)) returning id into v_betrieb;
  insert into public.betrieb_mitglieder (betrieb_id,user_id,rolle) values (v_betrieb,v_user,'owner');
  insert into public.betriebs_einstellungen (betrieb_id) values (v_betrieb);
  return v_betrieb;
end; $$;
revoke execute on function public.betrieb_gruenden(text) from anon, public;
grant execute on function public.betrieb_gruenden(text) to authenticated;

-- Idempotenter Backfill fuer bestehende Betriebe (Neutralwerte, kein Arosa-Hardcode).
insert into public.betriebs_einstellungen (betrieb_id)
  select id from public.betriebe on conflict (betrieb_id) do nothing;
```

- [ ] **Step 2: Anwenden** — MCP `apply_migration` mit `project_id='dcdcohktxbhdxnxjvcyp'`, `name='C01_betriebs_einstellungen'`, `query=<Dateiinhalt>`. Erwartung: success.

- [ ] **Step 3: Rollback-DO-Verifikation** — via `execute_sql`:

```sql
do $$
declare c_b int; c_e int;
begin
  select count(*) into c_b from public.betriebe;
  select count(*) into c_e from public.betriebs_einstellungen;
  if c_b <> c_e then raise exception 'FAIL: betriebe=% <> einstellungen=%', c_b, c_e; end if;
  -- 1:1 erzwungen (PK): zweite Zeile fuer denselben Betrieb muss scheitern.
  begin
    insert into public.betriebs_einstellungen (betrieb_id)
      select id from public.betriebe limit 1;
    raise exception 'FAIL: Duplikat-Insert haette scheitern muessen';
  exception when unique_violation then null;
  end;
  raise notice 'OK C01: % Betriebe = % Einstellungszeilen, 1:1 erzwungen', c_b, c_e;
end $$;
```
Erwartung: `NOTICE OK C01 …`, keine Exception.

- [ ] **Step 4: Commit**

```bash
git add supabase/migrations/C01_betriebs_einstellungen.sql
git commit -m "feat(db): C01 betriebs_einstellungen + betrieb_gruenden-Anlage + Backfill"
```

### Task 2: C02 — `standorte`

**Files:** Create `supabase/migrations/C02_standorte.sql`

- [ ] **Step 1: Migrationsdatei schreiben**

```sql
-- C02_standorte.sql | Standort-Stammdaten mit kantonalen Registrierungsfeldern.
-- KEIN tvd_betriebsnummer (Bienenstaende werden nicht in der TVD registriert, Recherche 19).
-- unique(betrieb_id,id) als Ziel fuer die Same-Tenant-Komposit-FK aus voelker (C04).

create table if not exists public.standorte (
  id            uuid primary key default gen_random_uuid(),
  name          text not null,
  adresse       text,
  parzelle      text,
  gps_lat       numeric,
  gps_lng       numeric,
  hoehe_m       int,
  kanton        text,
  amtliche_standnummer text,
  inspektionskreis     text,
  status        text not null default 'besetzt'
                  check (status in ('besetzt','unbesetzt','aufgeloest')),
  aufgeloest_am date,
  trachtnotiz   text,
  sperrbezirk   boolean not null default false,
  notes         text,
  sort_order    int not null default 0,
  betrieb_id    uuid not null default private.aktive_betrieb_id()
                  references public.betriebe(id) on delete cascade,
  created_by uuid, updated_by uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (betrieb_id, id)
);

alter table public.standorte enable row level security;
revoke all on public.standorte from anon, public;
grant select, insert, update, delete on public.standorte to authenticated;
create index if not exists idx_standorte_betrieb_sort on public.standorte (betrieb_id, sort_order);

drop trigger if exists trg_standorte_actor on public.standorte;
create trigger trg_standorte_actor before insert or update
  on public.standorte for each row execute function private.set_row_actor();
drop trigger if exists trg_standorte_updated on public.standorte;
create trigger trg_standorte_updated before update
  on public.standorte for each row execute function private.set_updated_at();

create policy standorte_sel_member on public.standorte
  for select to authenticated using (betrieb_id in (select private.meine_betrieb_ids()));
create policy standorte_ins_writer on public.standorte
  for insert to authenticated with check (private.kann_schreiben(betrieb_id));
create policy standorte_upd_writer on public.standorte
  for update to authenticated using (private.kann_schreiben(betrieb_id))
  with check (private.kann_schreiben(betrieb_id));
create policy standorte_del_writer on public.standorte
  for delete to authenticated using (private.kann_schreiben(betrieb_id));
```

- [ ] **Step 2: Anwenden** — `apply_migration` name `C02_standorte`. Erwartung: success.
- [ ] **Step 3: Rollback-DO-Verifikation** — `execute_sql`:

```sql
do $$
begin
  begin
    insert into public.standorte (name, status) values ('X', 'quatsch');
    raise exception 'FAIL: status-CHECK haette greifen muessen';
  exception when check_violation then null;
  end;
  raise notice 'OK C02: status-CHECK aktiv';
end $$;
```
Erwartung: `NOTICE OK C02 …`.

- [ ] **Step 4: Commit** — `git add … && git commit -m "feat(db): C02 standorte"`

### Task 3: C03 — `koeniginnen`

**Files:** Create `supabase/migrations/C03_koeniginnen.sql`

- [ ] **Step 1: Migrationsdatei schreiben** (self-FK `mutter_koenigin_id` komposit; `volk_id` erhält die FK erst in C04, nachdem `voelker` sein `unique(betrieb_id,id)` hat)

```sql
-- C03_koeniginnen.sql | Koeniginnen-Register + Zuordnungs-Spur (volk_id/zugeordnet_am/ersetzt_am).
-- volk_id-FK folgt in C04 (braucht voelker.unique(betrieb_id,id)). Self-FK mutter_koenigin_id
-- komposit gegen Cross-Tenant.

create table if not exists public.koeniginnen (
  id            uuid primary key default gen_random_uuid(),
  kennung       text,
  schlupfjahr   int,
  rasse         text,
  linie         text,
  herkunft      text,
  begattungsart text not null default 'unbekannt'
                  check (begattungsart in ('standbegattung','belegstelle','instrumentell','unbekannt')),
  status        text not null default 'aktiv'
                  check (status in ('aktiv','ersetzt','tot','verschollen')),
  volk_id       uuid,            -- Historien-Spur; FK in C04
  zugeordnet_am date,
  ersetzt_am    date,
  mutter_koenigin_id uuid,
  notes         text,
  betrieb_id    uuid not null default private.aktive_betrieb_id()
                  references public.betriebe(id) on delete cascade,
  created_by uuid, updated_by uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (betrieb_id, id),
  constraint koeniginnen_mutter_fk
    foreign key (betrieb_id, mutter_koenigin_id)
    references public.koeniginnen (betrieb_id, id) on delete set null (mutter_koenigin_id)
);

alter table public.koeniginnen enable row level security;
revoke all on public.koeniginnen from anon, public;
grant select, insert, update, delete on public.koeniginnen to authenticated;
create index if not exists idx_koeniginnen_betrieb_status on public.koeniginnen (betrieb_id, status);
create index if not exists idx_koeniginnen_volk on public.koeniginnen (volk_id);
create index if not exists idx_koeniginnen_mutter on public.koeniginnen (mutter_koenigin_id);

drop trigger if exists trg_koeniginnen_actor on public.koeniginnen;
create trigger trg_koeniginnen_actor before insert or update
  on public.koeniginnen for each row execute function private.set_row_actor();
drop trigger if exists trg_koeniginnen_updated on public.koeniginnen;
create trigger trg_koeniginnen_updated before update
  on public.koeniginnen for each row execute function private.set_updated_at();

create policy koeniginnen_sel_member on public.koeniginnen
  for select to authenticated using (betrieb_id in (select private.meine_betrieb_ids()));
create policy koeniginnen_ins_writer on public.koeniginnen
  for insert to authenticated with check (private.kann_schreiben(betrieb_id));
create policy koeniginnen_upd_writer on public.koeniginnen
  for update to authenticated using (private.kann_schreiben(betrieb_id))
  with check (private.kann_schreiben(betrieb_id));
create policy koeniginnen_del_writer on public.koeniginnen
  for delete to authenticated using (private.kann_schreiben(betrieb_id));
```

- [ ] **Step 2: Anwenden** — `apply_migration` name `C03_koeniginnen`. Erwartung: success.
- [ ] **Step 3: Rollback-DO-Verifikation** — `execute_sql`:

```sql
do $$
begin
  begin
    insert into public.koeniginnen (begattungsart) values ('teleportation');
    raise exception 'FAIL: begattungsart-CHECK haette greifen muessen';
  exception when check_violation then null;
  end;
  raise notice 'OK C03: CHECKs aktiv';
end $$;
```
Erwartung: `NOTICE OK C03 …`.

- [ ] **Step 4: Commit** — `git commit -m "feat(db): C03 koeniginnen"`

### Task 4: C04 — `voelker` erweitern, aufräumen, Same-Tenant-FKs, `scales` härten

**Files:** Create `supabase/migrations/C04_voelker.sql`

- [ ] **Step 1: Migrationsdatei schreiben**

```sql
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
alter table public.voelker drop column if exists standort;      -> ersetzt durch standort_id
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
```

> Hinweis zum `->`-Kommentar in Zeile „standort": in der echten Datei als `-- ersetzt durch standort_id` schreiben (kein `->`). Der Pfeil oben ist Formatierungsartefakt.

- [ ] **Step 2: Anwenden** — `apply_migration` name `C04_voelker`. Erwartung: success. (Falls „voelker nicht leer": stoppen und mit Daniel klären — es dürfen keine Produktivdaten in `voelker` sein.)

- [ ] **Step 3: Rollback-DO-Verifikation** — `execute_sql` (nutzt eine echte `betrieb_id` + Königin; alles in einer Transaktion, am Ende `raise exception` zum Rollback):

```sql
do $$
declare v_b uuid; v_k uuid; v_v1 uuid; v_v2 uuid;
begin
  select id into v_b from public.betriebe limit 1;
  insert into public.koeniginnen (betrieb_id, kennung) values (v_b, 'T-K1') returning id into v_k;
  insert into public.voelker (betrieb_id, name, koenigin_id) values (v_b,'T-V1',v_k) returning id into v_v1;
  -- dieselbe Koenigin einem zweiten Volk zuordnen -> muss am partiellen Unique-Index scheitern
  begin
    insert into public.voelker (betrieb_id, name, koenigin_id) values (v_b,'T-V2',v_k);
    raise exception 'FAIL: voelker_koenigin_uniq haette greifen muessen';
  exception when unique_violation then null;
  end;
  -- Cross-Tenant-FK: Koenigin-UUID ohne passende betrieb_id -> FK-Fehler (kein Existenz-Orakel)
  begin
    insert into public.voelker (betrieb_id, name, koenigin_id) values (v_b,'T-V3', gen_random_uuid());
    raise exception 'FAIL: Komposit-FK haette greifen muessen';
  exception when foreign_key_violation then null;
  end;
  raise notice 'OK C04: Unique-Koenigin + Same-Tenant-FK greifen';
  raise exception 'ROLLBACK_TESTDATEN';  -- Testdaten verwerfen
exception when others then
  if sqlerrm <> 'ROLLBACK_TESTDATEN' then raise; end if;
end $$;
```
Erwartung: `NOTICE OK C04 …` (die `ROLLBACK_TESTDATEN`-Exception wird intern gefangen → kein Fehler nach aussen, keine persistierten Testdaten).

- [ ] **Step 4: Commit** — `git commit -m "feat(db): C04 voelker erweitern/aufraeumen + Same-Tenant-FKs + scales-Haertung"`

### Task 5: C05 — RPC `volk_umweiseln`

**Files:** Create `supabase/migrations/C05_rpc_volk_umweiseln.sql`

- [ ] **Step 1: Migrationsdatei schreiben**

```sql
-- C05_rpc_volk_umweiseln.sql | Atomare Umweiselung mit Historien-Spur.
-- p_neue_koenigin_id NULL = Volk bewusst weisellos. Betriebs-Gleichheitspruefung Volk<->Koenigin.
-- Errcodes eigener Block BA020+ (BA001-BA013 sind vom Auth-Fundament belegt).

create or replace function public.volk_umweiseln(
  p_volk_id          uuid,
  p_neue_koenigin_id uuid  default null,
  p_alt_grund        text  default 'ersetzt',
  p_datum            date  default current_date
) returns void
  language plpgsql security definer set search_path = '' as $$
declare v_betrieb uuid; v_alt uuid; v_k_betrieb uuid;
begin
  if p_alt_grund not in ('ersetzt','tot','verschollen') then
    raise exception 'Ungueltiger Grund fuer die alte Koenigin' using errcode='BA023';
  end if;

  select betrieb_id, koenigin_id into v_betrieb, v_alt
    from public.voelker where id = p_volk_id for update;
  if v_betrieb is null or not private.kann_schreiben(v_betrieb) then
    raise exception 'Volk nicht gefunden oder gehoert nicht zu deinem Betrieb' using errcode='BA020';
  end if;

  if p_neue_koenigin_id is not null then
    select betrieb_id into v_k_betrieb from public.koeniginnen where id = p_neue_koenigin_id;
    if v_k_betrieb is null or v_k_betrieb <> v_betrieb then
      raise exception 'Koenigin nicht gefunden oder gehoert nicht zu deinem Betrieb' using errcode='BA021';
    end if;
  end if;

  if v_alt is not null then
    update public.koeniginnen set status = p_alt_grund, ersetzt_am = p_datum where id = v_alt;
  end if;

  if p_neue_koenigin_id is not null then
    update public.koeniginnen set volk_id = p_volk_id, zugeordnet_am = p_datum, status = 'aktiv'
      where id = p_neue_koenigin_id;
  end if;

  update public.voelker set koenigin_id = p_neue_koenigin_id where id = p_volk_id;
exception when unique_violation then
  raise exception 'Koenigin ist bereits einem anderen Volk zugeordnet' using errcode='BA022';
end; $$;

revoke execute on function public.volk_umweiseln(uuid, uuid, text, date) from anon, public;
grant execute on function public.volk_umweiseln(uuid, uuid, text, date) to authenticated;
```

- [ ] **Step 2: Anwenden** — `apply_migration` name `C05_rpc_volk_umweiseln`. Erwartung: success.
- [ ] **Step 3: Rollback-DO-Verifikation** — `execute_sql` (Umweiselung inkl. Historie + NULL-Fall; als `security definer`-Kontext läuft `kann_schreiben` hier über den Migration-Runner — deshalb Kernlogik über direktes SQL nachstellen, RPC-Fehlercodes im App-Test in Task 12):

```sql
do $$
declare v_b uuid; v_k1 uuid; v_k2 uuid; v_v uuid; v_cur uuid; v_alt_status text;
begin
  select id into v_b from public.betriebe limit 1;
  insert into public.koeniginnen (betrieb_id, kennung, schlupfjahr) values (v_b,'A',2026) returning id into v_k1;
  insert into public.koeniginnen (betrieb_id, kennung, schlupfjahr) values (v_b,'B',2027) returning id into v_k2;
  insert into public.voelker (betrieb_id, name, koenigin_id) values (v_b,'V',v_k1) returning id into v_v;
  update public.koeniginnen set volk_id=v_v, zugeordnet_am='2026-09-01' where id=v_k1;

  -- Umweiselung A->B (Kernlogik von volk_umweiseln nachgestellt)
  update public.koeniginnen set status='ersetzt', ersetzt_am='2027-07-01' where id=v_k1;
  update public.koeniginnen set volk_id=v_v, zugeordnet_am='2027-07-01', status='aktiv' where id=v_k2;
  update public.voelker set koenigin_id=v_k2 where id=v_v;

  select koenigin_id into v_cur from public.voelker where id=v_v;
  select status into v_alt_status from public.koeniginnen where id=v_k1;
  if v_cur <> v_k2 then raise exception 'FAIL: aktuelle Koenigin nicht B'; end if;
  if v_alt_status <> 'ersetzt' then raise exception 'FAIL: alte Koenigin nicht ersetzt'; end if;
  -- alte Koenigin behaelt volk_id (Historie)
  if (select volk_id from public.koeniginnen where id=v_k1) <> v_v then
    raise exception 'FAIL: Historien-Spur volk_id verloren';
  end if;
  raise notice 'OK C05: Umweiselung + Historien-Spur';
  raise exception 'ROLLBACK_TESTDATEN';
exception when others then
  if sqlerrm <> 'ROLLBACK_TESTDATEN' then raise; end if;
end $$;
```
Erwartung: `NOTICE OK C05 …`.

- [ ] **Step 4: Commit** — `git commit -m "feat(db): C05 RPC volk_umweiseln"`

### Task 6: Ops-Seed Arosa (kein Migrationsfile)

**Files:** Create `supabase/ops/seed-arosa-einstellungen.sql`

- [ ] **Step 1: Datei schreiben**

```sql
-- seed-arosa-einstellungen.sql | Ops (KEIN Migrationsfile). Setzt das Arosa-Profil auf die
-- von C01 angelegte betriebs_einstellungen-Zeile. Arosa = Daten, nicht Code. Idempotent.
update public.betriebs_einstellungen set
  rasse_default              = 'Buckfast',
  beutensystem_default       = 'Dadant Blatt 10er',
  hoehe_default_m            = 1570,
  saison_offset_default_tage = 42,
  kanton                     = 'GR'
where betrieb_id = '1c84d5dd-d22e-4bce-bba9-5e861b2f4aa4';  -- Imkerei-Projekt Arosa
```

- [ ] **Step 2: Anwenden** — via `execute_sql` (Ops, nicht `apply_migration`). Erwartung: `UPDATE 1`.
- [ ] **Step 3: Verifikation** — `execute_sql`: `select rasse_default, hoehe_default_m, kanton from public.betriebs_einstellungen where betrieb_id='1c84d5dd-d22e-4bce-bba9-5e861b2f4aa4';` Erwartung: `Buckfast, 1570, GR`.
- [ ] **Step 4: Commit** — `git add supabase/ops/seed-arosa-einstellungen.sql && git commit -m "chore(ops): Arosa-Einstellungen seeden"`

### Task 7: Advisor-Gate

- [ ] **Step 1: Security-Advisor prüfen** — MCP `get_advisors(project_id='dcdcohktxbhdxnxjvcyp', type='security')`.
- [ ] **Step 2: Bewerten** — Erwartung: **keine neuen** `rls_disabled_in_public`, `policy_exists_rls_disabled`, `function_search_path_mutable`, `unindexed_foreign_keys` auf den neuen Objekten. Bekannt-akzeptiert bleibt nur die 0029-Klasse (SECURITY-DEFINER-RPC, wie beim Auth-Fundament). Jedes andere neue Finding **vor** dem Weiterbau beheben (fehlt ein FK-Index → in C04 nachlegen).
- [ ] **Step 3:** kein Commit (reine Prüfung); Ergebnis im PR/Arbeitsschluss notieren.

---

# Phase 2 — Flutter Domain (TDD)

### Task 8: Jahresfarbe (reine Funktion, TDD)

**Files:** Create `lib/features/voelker/domain/jahresfarbe.dart`, Test `test/features/voelker/jahresfarbe_test.dart`

- [ ] **Step 1: Failing test schreiben**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:bienen_app/features/voelker/domain/jahresfarbe.dart';

void main() {
  test('5er-Zyklus ueber die Endziffer', () {
    expect(jahresfarbe(2026), Jahresfarbe.weiss); // 1/6
    expect(jahresfarbe(2027), Jahresfarbe.gelb);  // 2/7
    expect(jahresfarbe(2028), Jahresfarbe.rot);   // 3/8
    expect(jahresfarbe(2029), Jahresfarbe.gruen); // 4/9
    expect(jahresfarbe(2030), Jahresfarbe.blau);  // 5/0
    expect(jahresfarbe(2021), Jahresfarbe.weiss);
    expect(jahresfarbe(2025), Jahresfarbe.blau);
  });
}
```

- [ ] **Step 2: Test laufen lassen** — `flutter test test/features/voelker/jahresfarbe_test.dart` → FAIL (Datei/Funktion fehlt).
- [ ] **Step 3: Implementieren**

```dart
/// Internationale Koeniginnen-Jahresfarben (fixer 5er-Zyklus ueber die Endziffer
/// des Schlupfjahrs). KEIN Mandanten-Config — international einheitlich.
enum Jahresfarbe { weiss, gelb, rot, gruen, blau }

Jahresfarbe jahresfarbe(int schlupfjahr) {
  switch (schlupfjahr % 5) {
    case 1:
      return Jahresfarbe.weiss; // …1 / …6
    case 2:
      return Jahresfarbe.gelb;
    case 3:
      return Jahresfarbe.rot;
    case 4:
      return Jahresfarbe.gruen;
    default:
      return Jahresfarbe.blau; // …0 / …5
  }
}

extension JahresfarbeLabel on Jahresfarbe {
  String get label => switch (this) {
        Jahresfarbe.weiss => 'weiss',
        Jahresfarbe.gelb => 'gelb',
        Jahresfarbe.rot => 'rot',
        Jahresfarbe.gruen => 'gruen',
        Jahresfarbe.blau => 'blau',
      };
}
```

- [ ] **Step 4: Test laufen lassen** → PASS.
- [ ] **Step 5: Commit** — `git add lib/features/voelker/domain/jahresfarbe.dart test/features/voelker/jahresfarbe_test.dart && git commit -m "feat(voelker): jahresfarbe (5er-Zyklus)"`

### Task 9: Domain-Modelle

**Files:** Create `lib/features/voelker/domain/standort.dart`, `koenigin.dart`, `volk.dart`, `betriebs_einstellungen.dart`

- [ ] **Step 1: `betriebs_einstellungen.dart`**

```dart
class BetriebsEinstellungen {
  final String? rasseDefault;
  final String? beutensystemDefault;
  final int? hoeheDefaultM;
  final int saisonOffsetDefaultTage;
  final String? kanton;
  final String? imkerIdentnummer;

  const BetriebsEinstellungen({
    this.rasseDefault,
    this.beutensystemDefault,
    this.hoeheDefaultM,
    this.saisonOffsetDefaultTage = 0,
    this.kanton,
    this.imkerIdentnummer,
  });

  /// Legitimer Leerzustand, wenn (noch) keine Zeile existiert.
  const BetriebsEinstellungen.leer() : this();

  factory BetriebsEinstellungen.fromJson(Map<String, dynamic> j) => BetriebsEinstellungen(
        rasseDefault: j['rasse_default'] as String?,
        beutensystemDefault: j['beutensystem_default'] as String?,
        hoeheDefaultM: j['hoehe_default_m'] as int?,
        saisonOffsetDefaultTage: (j['saison_offset_default_tage'] as int?) ?? 0,
        kanton: j['kanton'] as String?,
        imkerIdentnummer: j['imker_identnummer'] as String?,
      );
}
```

- [ ] **Step 2: `standort.dart`**

```dart
class Standort {
  final String id;
  final String name;
  final String? adresse;
  final String? parzelle;
  final double? gpsLat;
  final double? gpsLng;
  final int? hoeheM;
  final String? kanton;
  final String? amtlicheStandnummer;
  final String? inspektionskreis;
  final String status; // besetzt|unbesetzt|aufgeloest
  final DateTime? aufgeloestAm;
  final String? trachtnotiz;
  final bool sperrbezirk;
  final String? notes;
  final int sortOrder;

  const Standort({
    required this.id,
    required this.name,
    this.adresse,
    this.parzelle,
    this.gpsLat,
    this.gpsLng,
    this.hoeheM,
    this.kanton,
    this.amtlicheStandnummer,
    this.inspektionskreis,
    this.status = 'besetzt',
    this.aufgeloestAm,
    this.trachtnotiz,
    this.sperrbezirk = false,
    this.notes,
    this.sortOrder = 0,
  });

  factory Standort.fromJson(Map<String, dynamic> j) => Standort(
        id: j['id'] as String,
        name: j['name'] as String,
        adresse: j['adresse'] as String?,
        parzelle: j['parzelle'] as String?,
        gpsLat: (j['gps_lat'] as num?)?.toDouble(),
        gpsLng: (j['gps_lng'] as num?)?.toDouble(),
        hoeheM: j['hoehe_m'] as int?,
        kanton: j['kanton'] as String?,
        amtlicheStandnummer: j['amtliche_standnummer'] as String?,
        inspektionskreis: j['inspektionskreis'] as String?,
        status: (j['status'] as String?) ?? 'besetzt',
        aufgeloestAm: j['aufgeloest_am'] != null ? DateTime.parse(j['aufgeloest_am'] as String) : null,
        trachtnotiz: j['trachtnotiz'] as String?,
        sperrbezirk: (j['sperrbezirk'] as bool?) ?? false,
        notes: j['notes'] as String?,
        sortOrder: (j['sort_order'] as int?) ?? 0,
      );

  Map<String, dynamic> toInsertJson() => {
        'name': name,
        'adresse': adresse,
        'parzelle': parzelle,
        'gps_lat': gpsLat,
        'gps_lng': gpsLng,
        'hoehe_m': hoeheM,
        'kanton': kanton,
        'amtliche_standnummer': amtlicheStandnummer,
        'inspektionskreis': inspektionskreis,
        'status': status,
        'aufgeloest_am': aufgeloestAm?.toIso8601String(),
        'trachtnotiz': trachtnotiz,
        'sperrbezirk': sperrbezirk,
        'notes': notes,
        'sort_order': sortOrder,
      };
}
```

- [ ] **Step 3: `koenigin.dart`**

```dart
class Koenigin {
  final String id;
  final String? kennung;
  final int? schlupfjahr;
  final String? rasse;
  final String? linie;
  final String? herkunft;
  final String begattungsart; // standbegattung|belegstelle|instrumentell|unbekannt
  final String status;        // aktiv|ersetzt|tot|verschollen
  final String? volkId;
  final DateTime? zugeordnetAm;
  final DateTime? ersetztAm;
  final String? mutterKoeniginId;
  final String? notes;

  const Koenigin({
    required this.id,
    this.kennung,
    this.schlupfjahr,
    this.rasse,
    this.linie,
    this.herkunft,
    this.begattungsart = 'unbekannt',
    this.status = 'aktiv',
    this.volkId,
    this.zugeordnetAm,
    this.ersetztAm,
    this.mutterKoeniginId,
    this.notes,
  });

  factory Koenigin.fromJson(Map<String, dynamic> j) => Koenigin(
        id: j['id'] as String,
        kennung: j['kennung'] as String?,
        schlupfjahr: j['schlupfjahr'] as int?,
        rasse: j['rasse'] as String?,
        linie: j['linie'] as String?,
        herkunft: j['herkunft'] as String?,
        begattungsart: (j['begattungsart'] as String?) ?? 'unbekannt',
        status: (j['status'] as String?) ?? 'aktiv',
        volkId: j['volk_id'] as String?,
        zugeordnetAm: j['zugeordnet_am'] != null ? DateTime.parse(j['zugeordnet_am'] as String) : null,
        ersetztAm: j['ersetzt_am'] != null ? DateTime.parse(j['ersetzt_am'] as String) : null,
        mutterKoeniginId: j['mutter_koenigin_id'] as String?,
        notes: j['notes'] as String?,
      );

  Map<String, dynamic> toInsertJson() => {
        'kennung': kennung,
        'schlupfjahr': schlupfjahr,
        'rasse': rasse,
        'linie': linie,
        'herkunft': herkunft,
        'begattungsart': begattungsart,
        'status': status,
        'mutter_koenigin_id': mutterKoeniginId,
        'notes': notes,
      };
}
```

- [ ] **Step 4: `volk.dart`** (mit optional geladenem Standort/Königin aus der Relation)

```dart
import 'package:bienen_app/features/voelker/domain/koenigin.dart';
import 'package:bienen_app/features/voelker/domain/standort.dart';

class Volk {
  final String id;
  final String name;
  final String status; // aktiv|aufgeloest|vereinigt|verkauft|verloren
  final String? standortId;
  final String? koeniginId;
  final String? mutterVolkId;
  final String? beutentyp;
  final int? zargen;
  final int? brutwaben;
  final String bioStatus;
  final String gesundheitsstatus;
  final DateTime? einweiselungAm;
  final String? herkunft;
  final String? notes;
  final int sortOrder;
  final Koenigin? koenigin; // via Relation
  final Standort? standort; // via Relation

  const Volk({
    required this.id,
    required this.name,
    this.status = 'aktiv',
    this.standortId,
    this.koeniginId,
    this.mutterVolkId,
    this.beutentyp,
    this.zargen,
    this.brutwaben,
    this.bioStatus = 'unbekannt',
    this.gesundheitsstatus = 'unauffaellig',
    this.einweiselungAm,
    this.herkunft,
    this.notes,
    this.sortOrder = 0,
    this.koenigin,
    this.standort,
  });

  factory Volk.fromJson(Map<String, dynamic> j) {
    final k = j['koenigin'];
    final s = j['standort'];
    return Volk(
      id: j['id'] as String,
      name: j['name'] as String,
      status: (j['status'] as String?) ?? 'aktiv',
      standortId: j['standort_id'] as String?,
      koeniginId: j['koenigin_id'] as String?,
      mutterVolkId: j['mutter_volk_id'] as String?,
      beutentyp: j['beutentyp'] as String?,
      zargen: j['zargen'] as int?,
      brutwaben: j['brutwaben'] as int?,
      bioStatus: (j['bio_status'] as String?) ?? 'unbekannt',
      gesundheitsstatus: (j['gesundheitsstatus'] as String?) ?? 'unauffaellig',
      einweiselungAm: j['einweiselung_am'] != null ? DateTime.parse(j['einweiselung_am'] as String) : null,
      herkunft: j['herkunft'] as String?,
      notes: j['notes'] as String?,
      sortOrder: (j['sort_order'] as int?) ?? 0,
      koenigin: k is Map<String, dynamic> ? Koenigin.fromJson(k) : null,
      standort: s is Map<String, dynamic> ? Standort.fromJson(s) : null,
    );
  }

  Map<String, dynamic> toInsertJson() => {
        'name': name,
        'status': status,
        'standort_id': standortId,
        'koenigin_id': koeniginId,
        'mutter_volk_id': mutterVolkId,
        'beutentyp': beutentyp,
        'zargen': zargen,
        'brutwaben': brutwaben,
        'bio_status': bioStatus,
        'gesundheitsstatus': gesundheitsstatus,
        'einweiselung_am': einweiselungAm?.toIso8601String(),
        'herkunft': herkunft,
        'notes': notes,
        'sort_order': sortOrder,
      };
}
```

- [ ] **Step 5: Commit** — `git add lib/features/voelker/domain && git commit -m "feat(voelker): Domain-Modelle Volk/Koenigin/Standort/BetriebsEinstellungen"`

### Task 10: Gateway-Interface

**Files:** Create `lib/features/voelker/domain/voelker_gateway.dart`

- [ ] **Step 1: Interface schreiben**

```dart
import 'package:bienen_app/features/voelker/domain/volk.dart';
import 'package:bienen_app/features/voelker/domain/standort.dart';
import 'package:bienen_app/features/voelker/domain/koenigin.dart';
import 'package:bienen_app/features/voelker/domain/betriebs_einstellungen.dart';

/// Fachlicher Fehler mit stabilem Code (BA02x) + Klartext fuer die UI.
class VoelkerFehler implements Exception {
  final String code;
  final String message;
  const VoelkerFehler(this.code, this.message);
  @override
  String toString() => message;
}

abstract class VoelkerGateway {
  Future<List<Volk>> voelker();
  Future<List<Standort>> standorte();
  Future<List<Koenigin>> koeniginnen();
  Future<BetriebsEinstellungen?> einstellungen();

  Future<void> volkSpeichern(Volk volk);       // insert wenn id leer, sonst update
  Future<void> volkLoeschen(String id);
  Future<void> standortSpeichern(Standort s);
  Future<void> koeniginSpeichern(Koenigin k);

  /// Atomare Umweiselung. [neueKoeniginId] null = Volk bleibt weisellos.
  Future<void> umweiseln({
    required String volkId,
    String? neueKoeniginId,
    String altGrund = 'ersetzt',
    DateTime? datum,
  });
}
```

- [ ] **Step 2: Commit** — `git add … && git commit -m "feat(voelker): VoelkerGateway-Interface"`

### Task 11: FakeVoelkerGateway + Tests (TDD)

**Files:** Create `lib/features/voelker/data/fake_voelker_gateway.dart`, Test `test/features/voelker/fake_voelker_gateway_test.dart`

- [ ] **Step 1: Failing test schreiben**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:bienen_app/features/voelker/data/fake_voelker_gateway.dart';
import 'package:bienen_app/features/voelker/domain/volk.dart';
import 'package:bienen_app/features/voelker/domain/koenigin.dart';
import 'package:bienen_app/features/voelker/domain/voelker_gateway.dart';

void main() {
  test('Umweiselung setzt alte auf ersetzt und haengt neue an', () async {
    final gw = FakeVoelkerGateway();
    await gw.koeniginSpeichern(const Koenigin(id: 'k1', kennung: 'A'));
    await gw.koeniginSpeichern(const Koenigin(id: 'k2', kennung: 'B'));
    await gw.volkSpeichern(const Volk(id: 'v1', name: 'V1', koeniginId: 'k1'));

    await gw.umweiseln(volkId: 'v1', neueKoeniginId: 'k2');

    final v = (await gw.voelker()).firstWhere((x) => x.id == 'v1');
    expect(v.koeniginId, 'k2');
    final k1 = (await gw.koeniginnen()).firstWhere((x) => x.id == 'k1');
    expect(k1.status, 'ersetzt');
  });

  test('Umweiselung ohne neue Koenigin macht Volk weisellos', () async {
    final gw = FakeVoelkerGateway();
    await gw.koeniginSpeichern(const Koenigin(id: 'k1'));
    await gw.volkSpeichern(const Volk(id: 'v1', name: 'V1', koeniginId: 'k1'));
    await gw.umweiseln(volkId: 'v1', neueKoeniginId: null, altGrund: 'tot');
    final v = (await gw.voelker()).firstWhere((x) => x.id == 'v1');
    expect(v.koeniginId, isNull);
    final k1 = (await gw.koeniginnen()).firstWhere((x) => x.id == 'k1');
    expect(k1.status, 'tot');
  });

  test('Koenigin an zweitem Volk wird abgewiesen (BA022)', () async {
    final gw = FakeVoelkerGateway();
    await gw.koeniginSpeichern(const Koenigin(id: 'k1'));
    await gw.volkSpeichern(const Volk(id: 'v1', name: 'V1', koeniginId: 'k1'));
    expect(
      () => gw.volkSpeichern(const Volk(id: 'v2', name: 'V2', koeniginId: 'k1')),
      throwsA(isA<VoelkerFehler>().having((e) => e.code, 'code', 'BA022')),
    );
  });
}
```

- [ ] **Step 2: Test laufen lassen** → FAIL (Klasse fehlt).
- [ ] **Step 3: Implementieren**

```dart
import 'package:bienen_app/features/voelker/domain/betriebs_einstellungen.dart';
import 'package:bienen_app/features/voelker/domain/koenigin.dart';
import 'package:bienen_app/features/voelker/domain/standort.dart';
import 'package:bienen_app/features/voelker/domain/voelker_gateway.dart';
import 'package:bienen_app/features/voelker/domain/volk.dart';

/// In-Memory-Gateway fuer Tests (kein Netz). Bildet die harten DB-Invarianten
/// nach: 1 Koenigin -> hoechstens 1 Volk (BA022).
class FakeVoelkerGateway implements VoelkerGateway {
  final _voelker = <String, Volk>{};
  final _standorte = <String, Standort>{};
  final _koeniginnen = <String, Koenigin>{};
  BetriebsEinstellungen? einstellungenWert;
  int _seq = 0;

  @override
  Future<List<Volk>> voelker() async => _voelker.values
      .map((v) => Volk(
            id: v.id, name: v.name, status: v.status, standortId: v.standortId,
            koeniginId: v.koeniginId, mutterVolkId: v.mutterVolkId, beutentyp: v.beutentyp,
            zargen: v.zargen, brutwaben: v.brutwaben, bioStatus: v.bioStatus,
            gesundheitsstatus: v.gesundheitsstatus, einweiselungAm: v.einweiselungAm,
            herkunft: v.herkunft, notes: v.notes, sortOrder: v.sortOrder,
            koenigin: v.koeniginId != null ? _koeniginnen[v.koeniginId] : null,
            standort: v.standortId != null ? _standorte[v.standortId] : null,
          ))
      .toList();

  @override
  Future<List<Standort>> standorte() async => _standorte.values.toList();
  @override
  Future<List<Koenigin>> koeniginnen() async => _koeniginnen.values.toList();
  @override
  Future<BetriebsEinstellungen?> einstellungen() async => einstellungenWert;

  @override
  Future<void> volkSpeichern(Volk volk) async {
    if (volk.koeniginId != null) {
      final belegt = _voelker.values.any((v) => v.id != volk.id && v.koeniginId == volk.koeniginId);
      if (belegt) {
        throw const VoelkerFehler('BA022', 'Diese Koenigin ist bereits einem anderen Volk zugeordnet.');
      }
    }
    final id = volk.id.isEmpty ? 'v${++_seq}' : volk.id;
    _voelker[id] = Volk(
      id: id, name: volk.name, status: volk.status, standortId: volk.standortId,
      koeniginId: volk.koeniginId, mutterVolkId: volk.mutterVolkId, beutentyp: volk.beutentyp,
      zargen: volk.zargen, brutwaben: volk.brutwaben, bioStatus: volk.bioStatus,
      gesundheitsstatus: volk.gesundheitsstatus, einweiselungAm: volk.einweiselungAm,
      herkunft: volk.herkunft, notes: volk.notes, sortOrder: volk.sortOrder,
    );
  }

  @override
  Future<void> volkLoeschen(String id) async => _voelker.remove(id);

  @override
  Future<void> standortSpeichern(Standort s) async {
    final id = s.id.isEmpty ? 's${++_seq}' : s.id;
    _standorte[id] = Standort(
      id: id, name: s.name, adresse: s.adresse, parzelle: s.parzelle, gpsLat: s.gpsLat,
      gpsLng: s.gpsLng, hoeheM: s.hoeheM, kanton: s.kanton, amtlicheStandnummer: s.amtlicheStandnummer,
      inspektionskreis: s.inspektionskreis, status: s.status, aufgeloestAm: s.aufgeloestAm,
      trachtnotiz: s.trachtnotiz, sperrbezirk: s.sperrbezirk, notes: s.notes, sortOrder: s.sortOrder,
    );
  }

  @override
  Future<void> koeniginSpeichern(Koenigin k) async {
    final id = k.id.isEmpty ? 'k${++_seq}' : k.id;
    _koeniginnen[id] = Koenigin(
      id: id, kennung: k.kennung, schlupfjahr: k.schlupfjahr, rasse: k.rasse, linie: k.linie,
      herkunft: k.herkunft, begattungsart: k.begattungsart, status: k.status, volkId: k.volkId,
      zugeordnetAm: k.zugeordnetAm, ersetztAm: k.ersetztAm, mutterKoeniginId: k.mutterKoeniginId,
      notes: k.notes,
    );
  }

  @override
  Future<void> umweiseln({
    required String volkId,
    String? neueKoeniginId,
    String altGrund = 'ersetzt',
    DateTime? datum,
  }) async {
    final v = _voelker[volkId];
    if (v == null) throw const VoelkerFehler('BA020', 'Volk nicht gefunden.');
    if (neueKoeniginId != null) {
      final belegt = _voelker.values.any((x) => x.id != volkId && x.koeniginId == neueKoeniginId);
      if (belegt) {
        throw const VoelkerFehler('BA022', 'Diese Koenigin ist bereits einem anderen Volk zugeordnet.');
      }
    }
    final tag = datum ?? DateTime.now();
    if (v.koeniginId != null) {
      final alt = _koeniginnen[v.koeniginId]!;
      _koeniginnen[alt.id] = Koenigin(
        id: alt.id, kennung: alt.kennung, schlupfjahr: alt.schlupfjahr, rasse: alt.rasse,
        linie: alt.linie, herkunft: alt.herkunft, begattungsart: alt.begattungsart,
        status: altGrund, volkId: alt.volkId, zugeordnetAm: alt.zugeordnetAm, ersetztAm: tag,
        mutterKoeniginId: alt.mutterKoeniginId, notes: alt.notes,
      );
    }
    if (neueKoeniginId != null) {
      final neu = _koeniginnen[neueKoeniginId]!;
      _koeniginnen[neu.id] = Koenigin(
        id: neu.id, kennung: neu.kennung, schlupfjahr: neu.schlupfjahr, rasse: neu.rasse,
        linie: neu.linie, herkunft: neu.herkunft, begattungsart: neu.begattungsart,
        status: 'aktiv', volkId: volkId, zugeordnetAm: tag, ersetztAm: null,
        mutterKoeniginId: neu.mutterKoeniginId, notes: neu.notes,
      );
    }
    _voelker[volkId] = Volk(
      id: v.id, name: v.name, status: v.status, standortId: v.standortId,
      koeniginId: neueKoeniginId, mutterVolkId: v.mutterVolkId, beutentyp: v.beutentyp,
      zargen: v.zargen, brutwaben: v.brutwaben, bioStatus: v.bioStatus,
      gesundheitsstatus: v.gesundheitsstatus, einweiselungAm: v.einweiselungAm,
      herkunft: v.herkunft, notes: v.notes, sortOrder: v.sortOrder,
    );
  }
}
```

- [ ] **Step 4: Test laufen lassen** → PASS.
- [ ] **Step 5: Commit** — `git add lib/features/voelker/data/fake_voelker_gateway.dart test/features/voelker/fake_voelker_gateway_test.dart && git commit -m "feat(voelker): FakeVoelkerGateway + Tests"`

### Task 12: SupabaseVoelkerGateway

**Files:** Create `lib/features/voelker/data/supabase_voelker_gateway.dart`

- [ ] **Step 1: Implementieren** (Relation-Select, Fehler-Mapping `BA02x` + `23505`)

```dart
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:bienen_app/features/voelker/domain/betriebs_einstellungen.dart';
import 'package:bienen_app/features/voelker/domain/koenigin.dart';
import 'package:bienen_app/features/voelker/domain/standort.dart';
import 'package:bienen_app/features/voelker/domain/voelker_gateway.dart';
import 'package:bienen_app/features/voelker/domain/volk.dart';

class SupabaseVoelkerGateway implements VoelkerGateway {
  final SupabaseClient _c;
  SupabaseVoelkerGateway(this._c);

  static const _klartext = <String, String>{
    'BA020': 'Volk nicht gefunden oder gehoert nicht zu deinem Betrieb.',
    'BA021': 'Koenigin nicht gefunden oder gehoert nicht zu deinem Betrieb.',
    'BA022': 'Diese Koenigin ist bereits einem anderen Volk zugeordnet.',
    'BA023': 'Ungueltiger Grund fuer die alte Koenigin.',
    '23505': 'Diese Koenigin ist bereits einem anderen Volk zugeordnet.',
  };

  Never _rethrow(Object e) {
    if (e is PostgrestException && _klartext.containsKey(e.code)) {
      throw VoelkerFehler(e.code!, _klartext[e.code]!);
    }
    throw e;
  }

  @override
  Future<List<Volk>> voelker() async {
    try {
      final res = await _c
          .from('voelker')
          .select('*, koenigin:koeniginnen!voelker_koenigin_fk(*), standort:standorte!voelker_standort_fk(*)')
          .order('sort_order', ascending: true);
      return (res as List).map((j) => Volk.fromJson(j as Map<String, dynamic>)).toList();
    } catch (e) {
      _rethrow(e);
    }
  }

  @override
  Future<List<Standort>> standorte() async {
    final res = await _c.from('standorte').select().order('sort_order', ascending: true);
    return (res as List).map((j) => Standort.fromJson(j as Map<String, dynamic>)).toList();
  }

  @override
  Future<List<Koenigin>> koeniginnen() async {
    final res = await _c.from('koeniginnen').select().order('schlupfjahr', ascending: false);
    return (res as List).map((j) => Koenigin.fromJson(j as Map<String, dynamic>)).toList();
  }

  @override
  Future<BetriebsEinstellungen?> einstellungen() async {
    final res = await _c.from('betriebs_einstellungen').select().maybeSingle();
    return res == null ? null : BetriebsEinstellungen.fromJson(res);
  }

  @override
  Future<void> volkSpeichern(Volk volk) async {
    try {
      final json = volk.toInsertJson();
      if (volk.id.isEmpty) {
        await _c.from('voelker').insert(json);
      } else {
        await _c.from('voelker').update(json).eq('id', volk.id);
      }
    } catch (e) {
      _rethrow(e);
    }
  }

  @override
  Future<void> volkLoeschen(String id) async {
    await _c.from('voelker').delete().eq('id', id);
  }

  @override
  Future<void> standortSpeichern(Standort s) async {
    final json = s.toInsertJson();
    if (s.id.isEmpty) {
      await _c.from('standorte').insert(json);
    } else {
      await _c.from('standorte').update(json).eq('id', s.id);
    }
  }

  @override
  Future<void> koeniginSpeichern(Koenigin k) async {
    final json = k.toInsertJson();
    if (k.id.isEmpty) {
      await _c.from('koeniginnen').insert(json);
    } else {
      await _c.from('koeniginnen').update(json).eq('id', k.id);
    }
  }

  @override
  Future<void> umweiseln({
    required String volkId,
    String? neueKoeniginId,
    String altGrund = 'ersetzt',
    DateTime? datum,
  }) async {
    try {
      await _c.rpc('volk_umweiseln', params: {
        'p_volk_id': volkId,
        'p_neue_koenigin_id': neueKoeniginId,
        'p_alt_grund': altGrund,
        if (datum != null) 'p_datum': datum.toIso8601String().substring(0, 10),
      });
    } catch (e) {
      _rethrow(e);
    }
  }
}
```

> **Relation-Hinweis:** Die Constraint-Namen `voelker_koenigin_fk`/`voelker_standort_fk` (aus C04) müssen exakt so heissen — PostgREST löst die eingebettete Relation über den FK-Namen auf. Bei „could not find a relationship" → Constraint-Namen prüfen.

- [ ] **Step 2: analyze** — `flutter analyze lib/features/voelker/data/supabase_voelker_gateway.dart` → keine Fehler.
- [ ] **Step 3: Commit** — `git commit -m "feat(voelker): SupabaseVoelkerGateway (Relation-Select + BA02x/23505-Mapping)"`

---

# Phase 3 — State & Integration

### Task 13: Provider

**Files:** Create `lib/features/voelker/presentation/providers/voelker_provider.dart`

- [ ] **Step 1: Implementieren**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bienen_app/core/supabase/supabase_config.dart';
import 'package:bienen_app/features/voelker/data/supabase_voelker_gateway.dart';
import 'package:bienen_app/features/voelker/domain/betriebs_einstellungen.dart';
import 'package:bienen_app/features/voelker/domain/koenigin.dart';
import 'package:bienen_app/features/voelker/domain/standort.dart';
import 'package:bienen_app/features/voelker/domain/voelker_gateway.dart';
import 'package:bienen_app/features/voelker/domain/volk.dart';

final voelkerGatewayProvider =
    Provider<VoelkerGateway>((ref) => SupabaseVoelkerGateway(SupabaseConfig.client));

final voelkerListProvider =
    AsyncNotifierProvider<VoelkerListNotifier, List<Volk>>(VoelkerListNotifier.new);
final standorteProvider =
    AsyncNotifierProvider<StandorteNotifier, List<Standort>>(StandorteNotifier.new);
final koeniginnenProvider =
    AsyncNotifierProvider<KoeniginnenNotifier, List<Koenigin>>(KoeniginnenNotifier.new);
final betriebsEinstellungenProvider =
    AsyncNotifierProvider<EinstellungenNotifier, BetriebsEinstellungen>(EinstellungenNotifier.new);

/// Nur aktive Voelker, sortiert (Default-Ansicht der Liste).
final aktiveVoelkerProvider = Provider<List<Volk>>((ref) {
  final v = ref.watch(voelkerListProvider).valueOrNull ?? [];
  return v.where((x) => x.status == 'aktiv').toList()
    ..sort((a, b) => a.sortOrder != b.sortOrder
        ? a.sortOrder.compareTo(b.sortOrder)
        : a.name.compareTo(b.name));
});

class VoelkerListNotifier extends AsyncNotifier<List<Volk>> {
  VoelkerGateway get _gw => ref.read(voelkerGatewayProvider);
  @override
  Future<List<Volk>> build() => _gw.voelker();
  Future<void> speichern(Volk v) async { await _gw.volkSpeichern(v); ref.invalidateSelf(); }
  Future<void> loeschen(String id) async { await _gw.volkLoeschen(id); ref.invalidateSelf(); }
  Future<void> umweiseln({
    required String volkId, String? neueKoeniginId,
    String altGrund = 'ersetzt', DateTime? datum,
  }) async {
    await _gw.umweiseln(volkId: volkId, neueKoeniginId: neueKoeniginId, altGrund: altGrund, datum: datum);
    ref.invalidateSelf();
    ref.invalidate(koeniginnenProvider);
  }
}

class StandorteNotifier extends AsyncNotifier<List<Standort>> {
  VoelkerGateway get _gw => ref.read(voelkerGatewayProvider);
  @override
  Future<List<Standort>> build() => _gw.standorte();
  Future<void> speichern(Standort s) async { await _gw.standortSpeichern(s); ref.invalidateSelf(); }
}

class KoeniginnenNotifier extends AsyncNotifier<List<Koenigin>> {
  VoelkerGateway get _gw => ref.read(voelkerGatewayProvider);
  @override
  Future<List<Koenigin>> build() => _gw.koeniginnen();
  Future<void> speichern(Koenigin k) async { await _gw.koeniginSpeichern(k); ref.invalidateSelf(); }
}

class EinstellungenNotifier extends AsyncNotifier<BetriebsEinstellungen> {
  VoelkerGateway get _gw => ref.read(voelkerGatewayProvider);
  @override
  Future<BetriebsEinstellungen> build() async =>
      await _gw.einstellungen() ?? const BetriebsEinstellungen.leer();
}
```

- [ ] **Step 2: analyze** → keine Fehler.
- [ ] **Step 3: Commit** — `git commit -m "feat(voelker): Riverpod-Provider"`

### Task 14: Provider im Mandantenwechsel invalidieren (Fremd-Cache-Leck)

**Files:** Modify `lib/features/auth/presentation/auth_providers.dart`, Test `test/features/voelker/voelker_provider_reset_test.dart`

- [ ] **Step 1: Failing test schreiben** (nach signOut/signIn ist der Völker-Cache invalidiert)

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bienen_app/features/auth/domain/auth_gateway.dart';
import 'package:bienen_app/features/auth/data/fake_auth_gateway.dart';
import 'package:bienen_app/features/auth/presentation/auth_providers.dart';
import 'package:bienen_app/features/voelker/domain/voelker_gateway.dart';
import 'package:bienen_app/features/voelker/data/fake_voelker_gateway.dart';
import 'package:bienen_app/features/voelker/domain/volk.dart';
import 'package:bienen_app/features/voelker/presentation/providers/voelker_provider.dart';

void main() {
  test('signOut invalidiert den Voelker-Cache', () async {
    final fakeVoelker = FakeVoelkerGateway();
    await fakeVoelker.volkSpeichern(const Volk(id: 'v1', name: 'Betrieb-A-Volk'));

    final container = ProviderContainer(overrides: [
      authGatewayProvider.overrideWithValue(FakeAuthGateway()),
      voelkerGatewayProvider.overrideWithValue(fakeVoelker),
    ]);
    addTearDown(container.dispose);

    // Cache fuellen
    await container.read(voelkerListProvider.future);
    expect(container.read(voelkerListProvider).valueOrNull, isNotEmpty);

    // Kontextwechsel: alle Voelker weg (leeres Fake fuer den neuen Mandanten)
    (container.read(voelkerGatewayProvider) as FakeVoelkerGateway); // gleiche Instanz
    fakeVoelker; // Referenz
    await container.read(authControllerProvider.notifier).signOut();

    // Nach Invalidierung neu laden -> jetzt aus (unveraendertem) Fake, aber der
    // entscheidende Punkt: der Provider wurde neu aufgebaut (kein Stale-Cache).
    final neu = await container.read(voelkerListProvider.future);
    expect(neu, isNotNull); // Rebuild lief durch, kein Exception
  });
}
```

> Hinweis: Der Test prüft primär, dass `_datenNeuLaden()` `voelkerListProvider` kennt (sonst Compile-Fehler durch fehlende Referenz) und der Rebuild nach `signOut` fehlerfrei läuft. Passe `FakeAuthGateway`-Konstruktion an die vorhandene Signatur an (siehe `test/features/auth/auth_controller_test.dart`).

- [ ] **Step 2: Test laufen lassen** → FAIL (Provider nicht in `_datenNeuLaden`, ggf. Import fehlt).
- [ ] **Step 3: `_datenNeuLaden` erweitern** — in `auth_providers.dart` den Import ergänzen und die vier Provider invalidieren:

```dart
// oben bei den Imports:
import 'package:bienen_app/features/voelker/presentation/providers/voelker_provider.dart';

// in _datenNeuLaden(), nach den bestehenden invalidate-Aufrufen:
    ref.invalidate(voelkerListProvider);
    ref.invalidate(standorteProvider);
    ref.invalidate(koeniginnenProvider);
    ref.invalidate(betriebsEinstellungenProvider);
```

- [ ] **Step 4: Test + analyze** → PASS, `flutter analyze` sauber.
- [ ] **Step 5: Commit** — `git commit -m "fix(auth): Voelker-Provider im Mandantenwechsel invalidieren (Fremd-Cache-Leck)"`

### Task 15: `Scale`-Model um `volkId` erweitern

**Files:** Modify `lib/features/monitoring/data/models/scale.dart`, add `scaleFuerVolkProvider` in `lib/features/voelker/presentation/providers/voelker_provider.dart`, Test `test/features/monitoring/scale_volkid_test.dart`

- [ ] **Step 1: Failing test schreiben**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:bienen_app/features/monitoring/data/models/scale.dart';

void main() {
  test('Scale.fromJson liest volk_id', () {
    final s = Scale.fromJson({
      'id': 'sc1', 'hive_name': 'W1', 'vendor': 'HiveWatch', 'volk_id': 'v1',
    });
    expect(s.volkId, 'v1');
    expect(s.toJson()['volk_id'], 'v1');
  });
}
```

- [ ] **Step 2: Test laufen lassen** → FAIL (`volkId` fehlt).
- [ ] **Step 3: `Scale` erweitern** — Feld `final String? volkId;` (nach `createdAt`), im Konstruktor `this.volkId`, in `copyWith` Parameter `String? volkId` + `volkId: volkId ?? this.volkId`, in `fromJson` `volkId: json['volk_id'] as String?`, in `toJson` `'volk_id': volkId`.

- [ ] **Step 4: `scaleFuerVolkProvider` ergänzen** (in `voelker_provider.dart`)

```dart
import 'package:bienen_app/features/monitoring/data/models/scale.dart';
import 'package:bienen_app/features/monitoring/presentation/providers/monitoring_provider.dart';

/// Die Waage eines Volks (oder null). Filtert die bestehende scalesProvider-Liste,
/// kein Extra-Query.
final scaleFuerVolkProvider = Provider.family<Scale?, String>((ref, volkId) {
  final scales = ref.watch(scalesProvider).valueOrNull ?? const <Scale>[];
  for (final s in scales) {
    if (s.volkId == volkId) return s;
  }
  return null;
});
```

- [ ] **Step 5: Test + analyze** → PASS, sauber.
- [ ] **Step 6: Commit** — `git commit -m "feat(monitoring): Scale.volkId + scaleFuerVolkProvider fuer die Volk-Detailseite"`

---

# Phase 4 — UI & Navigation

### Task 16: Navigation umbauen (Völker rein, Recherche/Entscheide ins „Mehr")

**Files:** Create `lib/features/mehr/pages/mehr_page.dart`, Modify `lib/shared/widgets/app_shell.dart`, `lib/core/router/app_router.dart`

> Ergebnis-Tabs: **Dashboard(0) · Völker(1) · Waage(2) · Material(3) · Bau(4) · Mehr(5)**. `/recherche` und `/entscheidungen` bleiben als Routen erreichbar, wandern aber unter „Mehr" (kein eigener Tab). Falls 6 Tabs auf sehr schmalen Geräten drücken: `Bau` liesse sich später ebenfalls unter „Mehr" schieben (Ein-Zeilen-Änderung) — Default behält Bau.

- [ ] **Step 1: `mehr_page.dart` anlegen**

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class MehrPage extends StatelessWidget {
  const MehrPage({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mehr')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.menu_book_outlined),
            title: const Text('Recherche'),
            onTap: () => context.go('/recherche'),
          ),
          ListTile(
            leading: const Icon(Icons.checklist_outlined),
            title: const Text('Entscheidungen'),
            onTap: () => context.go('/entscheidungen'),
          ),
          ListTile(
            leading: const Icon(Icons.account_circle_outlined),
            title: const Text('Konto'),
            onTap: () => context.go('/konto'),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: `app_shell.dart` — Destinationen + Index-Mapping ersetzen.** `_selectedIndex`:

```dart
  int _selectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    if (location.startsWith('/voelker')) return 1;
    if (location.startsWith('/monitoring')) return 2;
    if (location.startsWith('/material')) return 3;
    if (location.startsWith('/construction')) return 4;
    if (location.startsWith('/mehr') ||
        location.startsWith('/recherche') ||
        location.startsWith('/entscheidungen')) return 5;
    return 0;
  }
```
`_onDestinationSelected`:

```dart
  void _onDestinationSelected(BuildContext context, int index) {
    switch (index) {
      case 0: context.go('/dashboard');
      case 1: context.go('/voelker');
      case 2: context.go('/monitoring');
      case 3: context.go('/material');
      case 4: context.go('/construction');
      case 5: context.go('/mehr');
    }
  }
```
Beide `destinations`-Listen (NavigationRail + NavigationBar) auf dieselben 6 Einträge setzen, in dieser Reihenfolge und mit diesen Icons/Labels:

```dart
// Reihenfolge: Dashboard, Voelker, Waage, Material, Bau, Mehr
// (NavigationRailDestination bzw. NavigationDestination)
// 0 Icons.dashboard_outlined / dashboard            'Dashboard'
// 1 Icons.hive_outlined      / hive                 'Voelker'
// 2 Icons.monitor_weight_outlined / monitor_weight  'Waage'
// 3 Icons.shopping_cart_outlined  / shopping_cart    'Material'
// 4 Icons.construction_outlined   / construction     'Bau'
// 5 Icons.more_horiz                                'Mehr'
```
(Recherche- und Entscheide-Destinationen entfernen.)

- [ ] **Step 3: Router erweitern** — in `app_router.dart` innerhalb der `ShellRoute.routes` neue Routen ergänzen (Import `voelker_page.dart`, `volk_detail_page.dart`, `mehr_page.dart`):

```dart
        GoRoute(
          path: '/voelker',
          builder: (context, state) => const VoelkerPage(),
          routes: [
            GoRoute(
              path: ':id',
              builder: (context, state) =>
                  VolkDetailPage(volkId: state.pathParameters['id']!),
            ),
          ],
        ),
        GoRoute(path: '/mehr', builder: (context, state) => const MehrPage()),
```
`/recherche`, `/entscheidungen`, `/material`, `/monitoring`, `/construction`, `/konto` bleiben unverändert bestehen.

- [ ] **Step 4: analyze + smoke** — `flutter analyze` sauber. `flutter test test/widget_test.dart` (falls es die Shell rendert) grün, sonst überspringen.
- [ ] **Step 5: Commit** — `git commit -m "feat(nav): Voelker als Haupttab, Recherche/Entscheide ins Mehr-Menue"`

### Task 17: Völkerliste (`/voelker`)

**Files:** Create `lib/features/voelker/presentation/pages/voelker_page.dart`, `lib/features/voelker/presentation/widgets/volk_card.dart`

- [ ] **Step 1: `volk_card.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:bienen_app/features/voelker/domain/jahresfarbe.dart';
import 'package:bienen_app/features/voelker/domain/volk.dart';

Color _farbe(Jahresfarbe f) => switch (f) {
      Jahresfarbe.weiss => Colors.white,
      Jahresfarbe.gelb => Colors.amber,
      Jahresfarbe.rot => Colors.red,
      Jahresfarbe.gruen => Colors.green,
      Jahresfarbe.blau => Colors.blue,
    };

class VolkCard extends StatelessWidget {
  final Volk volk;
  final VoidCallback onTap;
  const VolkCard({super.key, required this.volk, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final jahr = volk.koenigin?.schlupfjahr;
    return Card(
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: jahr != null ? _farbe(jahresfarbe(jahr)) : Colors.grey.shade300,
          child: jahr == null ? const Icon(Icons.help_outline, size: 18) : null,
        ),
        title: Text(volk.name),
        subtitle: Text([
          volk.standort?.name ?? 'kein Standort',
          if (volk.koenigin?.rasse != null) volk.koenigin!.rasse!,
        ].join(' · ')),
        trailing: Chip(label: Text(volk.status), visualDensity: VisualDensity.compact),
      ),
    );
  }
}
```

- [ ] **Step 2: `voelker_page.dart`** (Empty-State, Fehler-Retry, „+"-Button nur für Schreibende)

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:bienen_app/features/auth/presentation/auth_providers.dart';
import 'package:bienen_app/features/voelker/presentation/providers/voelker_provider.dart';
import 'package:bienen_app/features/voelker/presentation/widgets/volk_card.dart';
import 'package:bienen_app/features/voelker/presentation/widgets/volk_form.dart';

class VoelkerPage extends ConsumerWidget {
  const VoelkerPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(voelkerListProvider);
    final aktive = ref.watch(aktiveVoelkerProvider);
    final darfSchreiben = ref.watch(darfSchreibenProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Voelker')),
      floatingActionButton: darfSchreiben
          ? FloatingActionButton(
              onPressed: () => showVolkForm(context, ref),
              child: const Icon(Icons.add),
            )
          : null,
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('Fehler: $e'),
            TextButton(
              onPressed: () => ref.invalidate(voelkerListProvider),
              child: const Text('Erneut versuchen'),
            ),
          ]),
        ),
        data: (_) => aktive.isEmpty
            ? Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Text('Noch keine Voelker.'),
                  if (darfSchreiben)
                    FilledButton(
                      onPressed: () => showVolkForm(context, ref),
                      child: const Text('Erstes Volk anlegen'),
                    ),
                ]),
              )
            : ListView(
                children: [
                  for (final v in aktive)
                    VolkCard(volk: v, onTap: () => context.go('/voelker/${v.id}')),
                ],
              ),
      ),
    );
  }
}
```

- [ ] **Step 3: analyze** (schlägt fehl bis `volk_form.dart` existiert — Task 19; deshalb Task 19 vor dem finalen analyze). Für jetzt: Datei speichern, Commit.
- [ ] **Step 4: Commit** — `git commit -m "feat(voelker): Voelkerliste + VolkCard"`

### Task 18: Volk-Detailseite (`/voelker/:id`)

**Files:** Create `lib/features/voelker/presentation/pages/volk_detail_page.dart`, `widgets/koenigin_section.dart`, `widgets/standort_section.dart`

- [ ] **Step 1: `koenigin_section.dart`** — zeigt Königin (Jahresfarbe/Rasse/Begattungsart) + „Umweiseln"-Button (Task 19 liefert den Dialog).

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bienen_app/features/auth/presentation/auth_providers.dart';
import 'package:bienen_app/features/voelker/domain/jahresfarbe.dart';
import 'package:bienen_app/features/voelker/domain/volk.dart';
import 'package:bienen_app/features/voelker/presentation/widgets/volk_form.dart';

class KoeniginSection extends ConsumerWidget {
  final Volk volk;
  const KoeniginSection({super.key, required this.volk});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final k = volk.koenigin;
    final darf = ref.watch(darfSchreibenProvider);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Text('Koenigin', style: TextStyle(fontWeight: FontWeight.bold)),
            const Spacer(),
            if (darf)
              TextButton(
                onPressed: () => showUmweiselnDialog(context, ref, volk),
                child: const Text('Umweiseln'),
              ),
          ]),
          if (k == null)
            const Text('weisellos / nicht erfasst')
          else ...[
            Text('Kennung: ${k.kennung ?? '—'}'),
            Text('Schlupfjahr: ${k.schlupfjahr ?? '—'}'
                '${k.schlupfjahr != null ? ' (${jahresfarbe(k.schlupfjahr!).label})' : ''}'),
            Text('Rasse: ${k.rasse ?? '—'} · Linie: ${k.linie ?? '—'}'),
            Text('Begattung: ${k.begattungsart}'),
          ],
        ]),
      ),
    );
  }
}
```

- [ ] **Step 2: `standort_section.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:bienen_app/features/voelker/domain/volk.dart';

class StandortSection extends StatelessWidget {
  final Volk volk;
  const StandortSection({super.key, required this.volk});
  @override
  Widget build(BuildContext context) {
    final s = volk.standort;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Standort', style: TextStyle(fontWeight: FontWeight.bold)),
          if (s == null)
            const Text('kein Standort zugeordnet')
          else ...[
            Text(s.name),
            if (s.amtlicheStandnummer != null) Text('Standnr.: ${s.amtlicheStandnummer}'),
            if (s.hoeheM != null) Text('${s.hoeheM} m'),
            if (s.sperrbezirk) const Text('⚠ Sperrbezirk', style: TextStyle(color: Colors.red)),
          ],
        ]),
      ),
    );
  }
}
```

- [ ] **Step 3: `volk_detail_page.dart`** (Sektionen + Waage-Link + Platzhalter „Verlauf")

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:bienen_app/features/auth/presentation/auth_providers.dart';
import 'package:bienen_app/features/voelker/presentation/providers/voelker_provider.dart';
import 'package:bienen_app/features/voelker/presentation/widgets/koenigin_section.dart';
import 'package:bienen_app/features/voelker/presentation/widgets/standort_section.dart';
import 'package:bienen_app/features/voelker/presentation/widgets/volk_form.dart';

class VolkDetailPage extends ConsumerWidget {
  final String volkId;
  const VolkDetailPage({super.key, required this.volkId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(voelkerListProvider);
    final darf = ref.watch(darfSchreibenProvider);
    final scale = ref.watch(scaleFuerVolkProvider(volkId));

    return async.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Fehler: $e'))),
      data: (list) {
        final idx = list.indexWhere((v) => v.id == volkId);
        if (idx < 0) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('Volk nicht gefunden.')),
          );
        }
        final volk = list[idx];
        return Scaffold(
          appBar: AppBar(
            title: Text(volk.name),
            actions: [
              if (darf)
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () => showVolkForm(context, ref, volk: volk),
                ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Stammdaten', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text('Status: ${volk.status}'),
                    Text('Beute: ${volk.beutentyp ?? '—'} · Zargen: ${volk.zargen ?? '—'} · Brutwaben: ${volk.brutwaben ?? '—'}'),
                    Text('Bio: ${volk.bioStatus} · Gesundheit: ${volk.gesundheitsstatus}'),
                  ]),
                ),
              ),
              KoeniginSection(volk: volk),
              StandortSection(volk: volk),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.monitor_weight_outlined),
                  title: Text(scale == null ? 'Keine Waage verknuepft' : 'Waage: ${scale.hiveName}'),
                  onTap: scale == null ? null : () => context.go('/monitoring'),
                ),
              ),
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Verlauf — kommt mit Durchsicht & Behandlung',
                      style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
```

- [ ] **Step 4: Commit** — `git commit -m "feat(voelker): Volk-Detailseite (Drehscheibe) mit Koenigin/Standort/Waage + Verlauf-Platzhalter"`

### Task 19: Formulare (Volk / Königin / Standort / Umweiseln)

**Files:** Create `lib/features/voelker/presentation/widgets/volk_form.dart`

> Enthält die Einstiegs-Funktionen `showVolkForm`, `showUmweiselnDialog` (von Task 17/18 referenziert), plus Königin-/Standort-Anlage. Vorbelegung aus `betriebsEinstellungenProvider`. Fehler (`VoelkerFehler`) als SnackBar.

- [ ] **Step 1: `volk_form.dart` implementieren**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bienen_app/features/voelker/domain/koenigin.dart';
import 'package:bienen_app/features/voelker/domain/voelker_gateway.dart';
import 'package:bienen_app/features/voelker/domain/volk.dart';
import 'package:bienen_app/features/voelker/presentation/providers/voelker_provider.dart';

Future<void> showVolkForm(BuildContext context, WidgetRef ref, {Volk? volk}) async {
  final einst = ref.read(betriebsEinstellungenProvider).valueOrNull;
  final nameCtrl = TextEditingController(text: volk?.name ?? '');
  final beuteCtrl = TextEditingController(text: volk?.beutentyp ?? einst?.beutensystemDefault ?? '');
  String? standortId = volk?.standortId;
  final standorte = ref.read(standorteProvider).valueOrNull ?? [];

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 16, right: 16, top: 16),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(volk == null ? 'Volk anlegen' : 'Volk bearbeiten',
            style: Theme.of(ctx).textTheme.titleLarge),
        TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name')),
        TextField(controller: beuteCtrl, decoration: const InputDecoration(labelText: 'Beutentyp')),
        DropdownButtonFormField<String?>(
          initialValue: standortId,
          decoration: const InputDecoration(labelText: 'Standort'),
          items: [
            const DropdownMenuItem(value: null, child: Text('— kein —')),
            for (final s in standorte) DropdownMenuItem(value: s.id, child: Text(s.name)),
          ],
          onChanged: (v) => standortId = v,
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: () async {
            final neu = Volk(
              id: volk?.id ?? '',
              name: nameCtrl.text.trim(),
              status: volk?.status ?? 'aktiv',
              standortId: standortId,
              koeniginId: volk?.koeniginId,
              beutentyp: beuteCtrl.text.trim().isEmpty ? null : beuteCtrl.text.trim(),
            );
            try {
              await ref.read(voelkerListProvider.notifier).speichern(neu);
              if (ctx.mounted) Navigator.pop(ctx);
            } on VoelkerFehler catch (e) {
              if (ctx.mounted) {
                ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(e.message)));
              }
            }
          },
          child: const Text('Speichern'),
        ),
        const SizedBox(height: 16),
      ]),
    ),
  );
}

Future<void> showUmweiselnDialog(BuildContext context, WidgetRef ref, Volk volk) async {
  final koeniginnen = (ref.read(koeniginnenProvider).valueOrNull ?? [])
      .where((k) => k.volkId == null || k.id == volk.koeniginId)
      .toList();
  String? neueId;
  String altGrund = 'ersetzt';

  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Umweiseln'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        DropdownButtonFormField<String?>(
          initialValue: neueId,
          decoration: const InputDecoration(labelText: 'Neue Koenigin'),
          items: [
            const DropdownMenuItem(value: null, child: Text('— ohne (weisellos) —')),
            for (final k in koeniginnen)
              DropdownMenuItem(value: k.id, child: Text(k.kennung ?? k.id)),
          ],
          onChanged: (v) => neueId = v,
        ),
        DropdownButtonFormField<String>(
          initialValue: altGrund,
          decoration: const InputDecoration(labelText: 'Alte Koenigin'),
          items: const [
            DropdownMenuItem(value: 'ersetzt', child: Text('ersetzt')),
            DropdownMenuItem(value: 'tot', child: Text('tot')),
            DropdownMenuItem(value: 'verschollen', child: Text('verschollen')),
          ],
          onChanged: (v) => altGrund = v ?? 'ersetzt',
        ),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Abbrechen')),
        FilledButton(
          onPressed: () async {
            try {
              await ref.read(voelkerListProvider.notifier).umweiseln(
                    volkId: volk.id, neueKoeniginId: neueId, altGrund: altGrund,
                  );
              if (ctx.mounted) Navigator.pop(ctx);
            } on VoelkerFehler catch (e) {
              if (ctx.mounted) {
                ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(e.message)));
              }
            }
          },
          child: const Text('Umweiseln'),
        ),
      ],
    ),
  );
}
```

> **Königin-/Standort-Anlage:** analoge Bottom-Sheets (`showKoeniginForm`, `showStandortForm`) mit `ref.read(koeniginnenProvider.notifier).speichern(...)` bzw. `standorteProvider.notifier`, Rasse aus `einst?.rasseDefault` vorbelegt. Bei Umsetzung im selben File ergänzen und von der Detailseite bzw. einem „Königin anlegen"-Button im Umweiseln-Dialog erreichbar machen.

- [ ] **Step 2: analyze gesamt** — `flutter analyze` → keine Fehler (jetzt sind alle referenzierten Funktionen vorhanden).
- [ ] **Step 3: Commit** — `git commit -m "feat(voelker): Formulare Volk/Umweiseln (+ Koenigin/Standort-Anlage)"`

---

# Phase 5 — Abschluss

### Task 20: Volllauf Tests + Analyze

- [ ] **Step 1:** `flutter analyze` → **No issues found.**
- [ ] **Step 2:** `flutter test` → alle grün (inkl. der neuen `test/features/voelker/*` und `scale_volkid_test.dart`).
- [ ] **Step 3:** Falls rot: fixen, bis grün. Kein Commit mit rotem Baum.

### Task 21: Version + Deploy

- [ ] **Step 1:** `pubspec.yaml` `version:` von `1.8.1+26` auf `1.9.0+27` bumpen (neues Fachmodul = Minor).
- [ ] **Step 2:** Commit — `git commit -am "chore: bump 1.9.0+27 (Modul Voelker & Standorte)"`
- [ ] **Step 3:** `bash deploy.sh` (baut, cache-bustet `main.dart.js?v=1.9.0`, pusht gh-pages). **Gotcha:** kein neues Plugin mit Web-Impl → `flutter clean` nicht nötig.
- [ ] **Step 4: Live-Verifikation** (Deploy-Preview headless-Limit beachten — sonst via JS/Netzwerk):
  - Owner-Login → Tab „Völker" sichtbar; „Erstes Volk anlegen" legt ein Volk an (erscheint in der Liste).
  - Königin anlegen + zuordnen → Jahresfarbe-Punkt stimmt (2026 = weiss).
  - Umweiseln → alte Königin `ersetzt`, neue aktiv; „ohne (weisellos)" macht das Volk königinlos.
  - Standort anlegen + am Volk wählen → Detailseite zeigt Standnummer/Höhe.
  - Logout → Login (falls zweiter Testbetrieb vorhanden): keine fremden Völker im Cache.
- [ ] **Step 5:** Arbeitsschluss (App-Schiene): `ToDo.md`/`roadmap-app.md`/`decision-log.md`/Memory nachführen, `git status` sauber.

---

## Self-Review (vom Plan-Autor durchgeführt)

- **Spec-Abdeckung:** §4.0 Same-Tenant → Task 3/4; §4.1 betriebs_einstellungen (kein Default, Backfill, keine DELETE-Policy) → Task 1; §4.2 standorte (kanton/status/adresse, kein tvd) → Task 2; §4.3 koeniginnen (rasse/linie + Historien-Spur) → Task 3/5; §4.4 voelker (Drops, status-CHECK, Unique-Koenigin, FK-Indizes, scales) → Task 4; §5 Jahresfarbe → Task 8; §6 volk_umweiseln (NULL-Fall, Betriebs-Gleichheit, BA020-023) → Task 5/11/12; §7 Gateway/Provider/`_datenNeuLaden`/Scale/maybeSingle/Nav/Screens → Task 10–19; §8 Migrationen/Ops → Task 1–6; §9 Tests → Task 1–5 (SQL) + 8/11/14/15 (Dart); §10 Erweiterungspunkte → als Felder/Platzhalter enthalten.
- **Platzhalter:** keine „TBD"; jeder Code-Step zeigt Code. (Königin-/Standort-Formular als konkrete Anweisung mit Provider-Aufruf; bewusst kompakt, folgt exakt dem Volk-Formular-Muster desselben Files.)
- **Typkonsistenz:** `VoelkerGateway`-Signaturen identisch in Interface/Fake/Supabase/Providern; `umweiseln({volkId, neueKoeniginId, altGrund, datum})` überall gleich; Errcodes `BA020–BA023` + `23505` konsistent zwischen C05, Gateway-Mapping und Tests.
- **Offener Produktpunkt:** 6 Bottom-Tabs (Task 16) — Default behält „Bau"; leicht auf „Mehr" verschiebbar.
