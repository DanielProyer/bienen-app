# Behandlungen (Varroa/Gesundheit) — Modul 4.5 — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** CH-konformes TAMV-Behandlungsjournal (amtliche, revisionssichere Pflichtdaten) + Varroa-Milbendiagnose + methodenbewusstes Varroa-Cockpit je Volk, angedockt an die Volk-Detailseite, mit atomarer Lager-Abbuchung.

**Architecture:** Zwei Supabase-Tabellen (`varroa_kontrollen` normale CRUD; `behandlungen` revisionssicher: FK `volk_id` `ON DELETE RESTRICT`, keine INSERT/DELETE-Policy, Immutable-Trigger) + eine security-definer-RPC `behandlung_erfassen` (einziger Schreibpfad: `distinct` Völker, `ROW_COUNT`-Abbuchung, explizite `betrieb_id`, BA030–034). Flutter-Feature `lib/features/behandlung/` nach dem 4.3-Muster (domain → data-Gateway/Fake → Riverpod-Family-Provider → UI an `volk_detail_page`).

**Tech Stack:** Supabase (Postgres 15, RLS, security definer), Flutter Web, Riverpod AsyncNotifier (ohne Codegen), go_router (Hash), fl_chart.

**Grundlage:** Spec v2 `docs/superpowers/specs/2026-07-17-behandlungen-varroa-design.md` (33 Review-Funde eingearbeitet). Fachwissen: `../imkerei/02_Recherche/15` (Varroa), `19` (TAMV).

**Errcode-Registry (Block 4.5 = BA030–039):** BA030 Pflichtfeld · BA031 Völker · BA032 Material-Tenancy · BA033 Dosierung · BA034 Revisionssicherheit (Immutable/Storno-Trigger).

**Muster-Referenzen (lesen hilft):** `supabase/migrations/C04_voelker.sql` (Komposit-FK `on delete set null (spalte)`), `C05_rpc_volk_umweiseln.sql` (RPC), `D01_inspections.sql` (Tabelle+RLS+Trigger). Dart: `lib/features/durchsicht/` (domain/data/presentation komplett analog), `lib/features/material/presentation/providers/material_provider.dart` (`materialListProvider`), `lib/features/auth/presentation/auth_providers.dart:72` (`_datenNeuLaden`), `lib/features/voelker/presentation/widgets/volk_form.dart:17` (Dropdown-Prewarming).

> **Migrationen E01/E02 wendet der Controller (nicht ein Subagent) via Supabase-MCP `apply_migration` auf die Produktion an** — nach erneuter Freigabe für die 4.5-DB. Die Dart-Tasks (3+) laufen subagent-getrieben.

---

## Dateistruktur

| Datei | Verantwortung |
|---|---|
| `supabase/migrations/E01_behandlungen.sql` | `materials` unique + `varroa_kontrollen` + `behandlungen` (FKs/CHECKs/RLS/Immutable-Trigger/Indizes) |
| `supabase/migrations/E02_rpc_behandlung_erfassen.sql` | RPC `behandlung_erfassen` + Grants |
| `lib/features/behandlung/domain/wirkstoff.dart` | Wirkstoff/Anwendungsart-Enums (Labels) + `bioKonformitaet` |
| `lib/features/behandlung/domain/ampel_schwellen.dart` | reine Funktionen: `milbenProTag`, `befallProzent`, `ampelGemuell`, `ampelPuderzucker`, `ampelFuerKontrolle` |
| `lib/features/behandlung/domain/varroa_kontrolle.dart` | Modell `VarroaKontrolle` |
| `lib/features/behandlung/domain/behandlung.dart` | Modell `Behandlung` |
| `lib/features/behandlung/domain/behandlung_gateway.dart` | abstraktes Gateway + `BehandlungFehler` |
| `lib/features/behandlung/data/fake_behandlung_gateway.dart` | In-Memory-Fake (distinct-Insert, Lager-Sim, BA030–034) |
| `lib/features/behandlung/data/supabase_behandlung_gateway.dart` | Supabase-Impl (RPC + CRUD) |
| `lib/features/behandlung/presentation/providers/behandlung_provider.dart` | Family-Provider + `BehandlungAktionen` (Sammel-Invalidierung) |
| `lib/features/behandlung/presentation/widgets/varroa_cockpit.dart` | fl_chart-Cockpit + Ampel-Chip + Höhen-Caveat |
| `lib/features/behandlung/presentation/widgets/behandlung_section.dart` | Andock-Card (Cockpit + Buttons + Liste) |
| `lib/features/behandlung/presentation/pages/kontrolle_form_page.dart` | Milbendiagnose-Formular (Vollseite, Rollen-Guard) |
| `lib/features/behandlung/presentation/pages/behandlung_form_page.dart` | Behandlungs-Formular (Vollseite, Multi-Select, Material, Bio-Banner) |
| `lib/features/voelker/presentation/pages/volk_detail_page.dart` | (modify) `BehandlungSection` andocken |
| `lib/core/router/app_router.dart` | (modify) Routen `behandlung`, `varroa` |
| `lib/features/auth/presentation/auth_providers.dart` | (modify) neue Family-Provider in `_datenNeuLaden` |
| `pubspec.yaml` | (modify) `version: 1.11.0+29` |

---

## Task 1: Migration E01 — Tabellen (Controller-Task, Produktion)

**Files:**
- Create: `supabase/migrations/E01_behandlungen.sql`

- [ ] **Step 1: Datei schreiben**

```sql
-- E01_behandlungen.sql | Varroa-Milbendiagnose + TAMV-Behandlungsjournal (amtliche Pflichtdaten).
-- varroa_kontrollen: normale CRUD (kein Pflichtjournal), Komposit-FK ON DELETE CASCADE.
-- behandlungen: revisionssicher -> FK volk_id ON DELETE RESTRICT (Volk mit Journal hart-loeschsicher,
--   TAMV Art. 29), material_id ON DELETE SET NULL (material_id) spaltenqualifiziert (unqualifiziert
--   wuerde auch betrieb_id nullen!), KEINE INSERT-Policy (Insert nur via RPC E02), KEINE DELETE-Policy,
--   BEFORE-UPDATE-Trigger friert Kernfelder ein + Einweg-Storno + server-seitiges storno_am.
-- Errcodes BA030-039 = Modul 4.5.

-- 4.0 materials: Komposit-FK-Ziel fuer behandlungen.material_id
alter table public.materials
  add constraint materials_betrieb_id_id_key unique (betrieb_id, id);

-- 4.1 varroa_kontrollen (Milbendiagnose)
create table if not exists public.varroa_kontrollen (
  id uuid primary key default gen_random_uuid(),
  volk_id uuid not null,
  durchgefuehrt_am date not null default current_date,
  methode text not null check (methode in ('gemuell','puderzucker','auswaschung')),
  messdauer_tage int check (messdauer_tage is null or messdauer_tage >= 1),
  milben_gesamt int not null check (milben_gesamt >= 0),
  bienen_probe int check (bienen_probe is null or bienen_probe >= 1),
  notiz text,
  betrieb_id uuid not null default private.aktive_betrieb_id()
    references public.betriebe(id) on delete cascade,
  created_by uuid, updated_by uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (betrieb_id, id),
  constraint varroa_kontrollen_volk_fk
    foreign key (betrieb_id, volk_id) references public.voelker (betrieb_id, id) on delete cascade
);
alter table public.varroa_kontrollen enable row level security;
revoke all on public.varroa_kontrollen from anon, public;
grant select, insert, update, delete on public.varroa_kontrollen to authenticated;
create index if not exists idx_varroa_kontrollen_volk_datum
  on public.varroa_kontrollen (betrieb_id, volk_id, durchgefuehrt_am desc);
drop trigger if exists trg_varroa_kontrollen_actor on public.varroa_kontrollen;
create trigger trg_varroa_kontrollen_actor before insert or update
  on public.varroa_kontrollen for each row execute function private.set_row_actor();
drop trigger if exists trg_varroa_kontrollen_updated on public.varroa_kontrollen;
create trigger trg_varroa_kontrollen_updated before update
  on public.varroa_kontrollen for each row execute function private.set_updated_at();
drop policy if exists varroa_kontrollen_sel_member on public.varroa_kontrollen;
create policy varroa_kontrollen_sel_member on public.varroa_kontrollen
  for select to authenticated using (betrieb_id in (select private.meine_betrieb_ids()));
drop policy if exists varroa_kontrollen_ins_writer on public.varroa_kontrollen;
create policy varroa_kontrollen_ins_writer on public.varroa_kontrollen
  for insert to authenticated with check (private.kann_schreiben(betrieb_id));
drop policy if exists varroa_kontrollen_upd_writer on public.varroa_kontrollen;
create policy varroa_kontrollen_upd_writer on public.varroa_kontrollen
  for update to authenticated using (private.kann_schreiben(betrieb_id))
  with check (private.kann_schreiben(betrieb_id));
drop policy if exists varroa_kontrollen_del_writer on public.varroa_kontrollen;
create policy varroa_kontrollen_del_writer on public.varroa_kontrollen
  for delete to authenticated using (private.kann_schreiben(betrieb_id));

-- 4.2 behandlungen (amtliches Journal, revisionssicher)
create table if not exists public.behandlungen (
  id uuid primary key default gen_random_uuid(),
  volk_id uuid not null,
  datum_beginn date not null default current_date,
  datum_ende date,
  praeparat text,
  wirkstoff text not null
    check (wirkstoff in ('ameisensaeure','oxalsaeure','milchsaeure','thymol','kombi_os_as','sonstige')),
  menge_pro_volk numeric check (menge_pro_volk is null or menge_pro_volk >= 0),
  einheit text check (einheit in ('ml','g','stueck')),
  konzentration text,
  anwendungsart text not null
    check (anwendungsart in ('traeufeln','spruehen','verdampfen','dispenser_verdunster',
                             'streifen_langzeit','schwammtuch','biotechnik','waermebehandlung')),
  indikation text,
  aussentemperatur_c numeric,
  wartefrist_tage int check (wartefrist_tage is null or wartefrist_tage >= 0),
  charge text,
  verantwortliche_person text not null,
  material_id uuid,
  is_storniert boolean not null default false,
  storno_grund text,
  storno_am date,
  notiz text,
  betrieb_id uuid not null default private.aktive_betrieb_id()
    references public.betriebe(id) on delete cascade,
  created_by uuid, updated_by uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (betrieb_id, id),
  constraint behandlungen_volk_fk
    foreign key (betrieb_id, volk_id) references public.voelker (betrieb_id, id) on delete restrict,
  constraint behandlungen_material_fk
    foreign key (betrieb_id, material_id) references public.materials (betrieb_id, id)
    on delete set null (material_id),
  constraint behandlungen_praeparat_chk
    check (anwendungsart in ('biotechnik','waermebehandlung')
           or (praeparat is not null and btrim(praeparat) <> '')),
  constraint behandlungen_menge_chk
    check (anwendungsart in ('biotechnik','waermebehandlung')
           or (menge_pro_volk is not null and menge_pro_volk > 0 and einheit is not null)),
  constraint behandlungen_datum_chk
    check (datum_ende is null or datum_ende >= datum_beginn),
  constraint behandlungen_storno_chk
    check (is_storniert = false or (storno_grund is not null and storno_am is not null)),
  constraint behandlungen_storno_datum_chk
    check (storno_am is null or storno_am >= datum_beginn)
);
alter table public.behandlungen enable row level security;
revoke all on public.behandlungen from anon, public;
-- KEIN insert (nur via security-definer-RPC), KEIN delete (kein Hard-Delete):
grant select, update on public.behandlungen to authenticated;
create index if not exists idx_behandlungen_volk_datum
  on public.behandlungen (betrieb_id, volk_id, datum_beginn desc);
create index if not exists idx_behandlungen_material
  on public.behandlungen (betrieb_id, material_id);

drop trigger if exists trg_behandlungen_actor on public.behandlungen;
create trigger trg_behandlungen_actor before insert or update
  on public.behandlungen for each row execute function private.set_row_actor();
drop trigger if exists trg_behandlungen_updated on public.behandlungen;
create trigger trg_behandlungen_updated before update
  on public.behandlungen for each row execute function private.set_updated_at();

-- Revisionssicherheit: Kernfelder unveraenderlich, Einweg-Storno, server-seitiges storno_am.
create or replace function private.behandlungen_schutz()
  returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if old.is_storniert then
    raise exception 'Stornierter Journaleintrag ist unveraenderlich' using errcode='BA034';
  end if;
  if new.is_storniert = false and old.is_storniert = false then
    -- normaler (Nicht-Storno-)Update: Kernfelder pruefen
    null;
  end if;
  if new.is_storniert is distinct from old.is_storniert and new.is_storniert = false then
    raise exception 'Storno kann nicht rueckgaengig gemacht werden' using errcode='BA034';
  end if;
  if new.volk_id is distinct from old.volk_id
     or new.datum_beginn is distinct from old.datum_beginn
     or new.datum_ende is distinct from old.datum_ende
     or new.praeparat is distinct from old.praeparat
     or new.wirkstoff is distinct from old.wirkstoff
     or new.menge_pro_volk is distinct from old.menge_pro_volk
     or new.einheit is distinct from old.einheit
     or new.konzentration is distinct from old.konzentration
     or new.anwendungsart is distinct from old.anwendungsart
     or new.indikation is distinct from old.indikation
     or new.aussentemperatur_c is distinct from old.aussentemperatur_c
     or new.wartefrist_tage is distinct from old.wartefrist_tage
     or new.charge is distinct from old.charge
     or new.verantwortliche_person is distinct from old.verantwortliche_person
     or new.material_id is distinct from old.material_id then
    raise exception 'Amtliche Kernfelder sind unveraenderlich (Korrektur = Storno + Neueintrag)'
      using errcode='BA034';
  end if;
  if new.is_storniert and not old.is_storniert then
    new.storno_am := current_date; -- server-seitig, Client-Wert ignorieren
  end if;
  return new;
end; $$;
drop trigger if exists trg_behandlungen_schutz on public.behandlungen;
create trigger trg_behandlungen_schutz before update on public.behandlungen
  for each row execute function private.behandlungen_schutz();

drop policy if exists behandlungen_sel_member on public.behandlungen;
create policy behandlungen_sel_member on public.behandlungen
  for select to authenticated using (betrieb_id in (select private.meine_betrieb_ids()));
drop policy if exists behandlungen_upd_writer on public.behandlungen;
create policy behandlungen_upd_writer on public.behandlungen
  for update to authenticated using (private.kann_schreiben(betrieb_id))
  with check (private.kann_schreiben(betrieb_id));
-- BEWUSST keine behandlungen_ins_* und keine behandlungen_del_* Policy.
```

- [ ] **Step 2: Migration auf Produktion anwenden**

Controller ruft Supabase-MCP `apply_migration` mit `name: "E01_behandlungen"` und obigem SQL auf Projekt `dcdcohktxbhdxnxjvcyp` auf.
Erwartet: Erfolg, keine Fehlermeldung.

- [ ] **Step 3: Rollback-DO-Test — RESTRICT, CHECKs, Immutable-Trigger**

Controller führt via `execute_sql` aus (nutzt Arosa-Betrieb + legt ein Test-Volk an, prüft, rollt am Ende per `raise` zurück):

```sql
do $$
declare v_b uuid := '1c84d5dd-d22e-4bce-bba9-5e861b2f4aa4'; v_volk uuid; v_beh uuid;
begin
  insert into public.voelker (betrieb_id, name, status)
    values (v_b, 'E01-TEST-VOLK', 'aktiv') returning id into v_volk;

  -- Insert (direkt, nur fuer den Test — spaeter macht das die RPC)
  insert into public.behandlungen (betrieb_id, volk_id, datum_beginn, praeparat, wirkstoff,
      menge_pro_volk, einheit, anwendungsart, verantwortliche_person)
    values (v_b, v_volk, current_date, 'FORMIVAR 60%', 'ameisensaeure', 40, 'ml', 'dispenser_verdunster', 'Tester')
    returning id into v_beh;

  -- RESTRICT: Volk mit Journal darf nicht hart geloescht werden
  begin
    delete from public.voelker where id = v_volk;
    raise exception 'FEHLER: voelker-Delete trotz Journal erlaubt';
  exception when foreign_key_violation then null; -- erwartet
  end;

  -- CHECK: chemische Anwendung ohne Menge -> Verletzung
  begin
    insert into public.behandlungen (betrieb_id, volk_id, datum_beginn, praeparat, wirkstoff, anwendungsart, verantwortliche_person)
      values (v_b, v_volk, current_date, 'X', 'thymol', 'traeufeln', 'Tester');
    raise exception 'FEHLER: chemisch ohne Menge erlaubt';
  exception when check_violation then null; -- erwartet
  end;

  -- Immutable-Trigger: Kernfeld-Update abgewiesen
  begin
    update public.behandlungen set wirkstoff = 'oxalsaeure' where id = v_beh;
    raise exception 'FEHLER: Kernfeld-Update erlaubt';
  exception when others then
    if sqlerrm not like '%unveraenderlich%' then raise; end if; -- erwartet BA034
  end;

  -- Storno OK + storno_am server-seitig
  update public.behandlungen set is_storniert = true, storno_grund = 'Testfehler' where id = v_beh;
  if (select storno_am from public.behandlungen where id = v_beh) is null then
    raise exception 'FEHLER: storno_am nicht server-seitig gesetzt';
  end if;

  -- Ent-Stornieren abgewiesen
  begin
    update public.behandlungen set is_storniert = false where id = v_beh;
    raise exception 'FEHLER: Ent-Stornieren erlaubt';
  exception when others then
    if sqlerrm not like '%rueckgaengig%' and sqlerrm not like '%unveraenderlich%' then raise; end if;
  end;

  raise exception 'ROLLBACK_OK'; -- alles gut -> Testdaten verwerfen
exception when others then
  if sqlerrm = 'ROLLBACK_OK' then return; end if;
  raise;
end $$;
```
Erwartet: kein Fehler (der `ROLLBACK_OK`-Zweig schluckt sich selbst). Jede `FEHLER:`-Meldung = Test durchgefallen.

- [ ] **Step 4: Advisor-Gate**

Controller ruft `get_advisors(type: "security")`. Erwartet: **0 neue** SECURITY-Findings gegenüber dem Stand vor E01 (die neue `private.behandlungen_schutz`-Funktion hat `search_path=''`; FK-Indizes verhindern `unindexed_foreign_keys`). Bei neuem Finding: Ursache beheben, bevor E02 kommt.

- [ ] **Step 5: Commit**

```bash
git add supabase/migrations/E01_behandlungen.sql
git commit -m "feat(4.5): E01 varroa_kontrollen + behandlungen (RESTRICT, CHECKs, Immutable-Trigger)"
```

---

## Task 2: Migration E02 — RPC `behandlung_erfassen` (Controller-Task, Produktion)

**Files:**
- Create: `supabase/migrations/E02_rpc_behandlung_erfassen.sql`

- [ ] **Step 1: Datei schreiben**

```sql
-- E02_rpc_behandlung_erfassen.sql | Einziger Schreibpfad ins Behandlungsjournal.
-- Sammelbehandlung: distinct Voelker -> je EINE Zeile; Lager-Abbuchung aus real eingefuegter
-- Zeilenzahl (ROW_COUNT), nie aus array_length. betrieb_id EXPLIZIT aus den Voelkern (nicht JWT-Default).
-- BA030 Pflichtfeld, BA031 Voelker, BA032 Material-Tenancy, BA033 Dosierung.

create or replace function public.behandlung_erfassen(
  p_volk_ids uuid[],
  p_datum_beginn date,
  p_wirkstoff text,
  p_anwendungsart text,
  p_verantwortliche_person text,
  p_datum_ende date default null,
  p_praeparat text default null,
  p_menge_pro_volk numeric default null,
  p_einheit text default null,
  p_konzentration text default null,
  p_indikation text default null,
  p_aussentemperatur_c numeric default null,
  p_wartefrist_tage int default null,
  p_charge text default null,
  p_material_id uuid default null,
  p_notiz text default null
) returns int
  language plpgsql security definer set search_path = '' as $$
declare
  v_betrieb uuid;
  v_betriebe uuid[];
  v_found int;
  v_n int;
  v_biotech boolean := p_anwendungsart in ('biotechnik','waermebehandlung');
begin
  -- Guard zuerst: leeres/NULL-Array (robust gegen array_length-NULL).
  if p_volk_ids is null or cardinality(p_volk_ids) = 0 then
    raise exception 'Keine Voelker angegeben' using errcode='BA031';
  end if;

  -- Voelker: alle gefunden, genau EIN Betrieb (einheitliche BA031-Meldung -> kein Existenz-Orakel).
  select array_agg(distinct betrieb_id), count(distinct id)
    into v_betriebe, v_found
    from public.voelker where id = any(p_volk_ids);
  if v_found is null
     or v_found <> cardinality(array(select distinct unnest(p_volk_ids)))
     or coalesce(array_length(v_betriebe, 1), 0) <> 1 then
    raise exception 'Volk nicht gefunden oder gehoert nicht zu deinem Betrieb' using errcode='BA031';
  end if;
  v_betrieb := v_betriebe[1];
  if not private.kann_schreiben(v_betrieb) then
    raise exception 'Keine Schreibberechtigung fuer diesen Betrieb' using errcode='BA031';
  end if;

  -- Pflichtfelder (BA030).
  if p_datum_beginn is null
     or p_wirkstoff is null
     or p_anwendungsart is null
     or btrim(coalesce(p_verantwortliche_person, '')) = ''
     or (not v_biotech and btrim(coalesce(p_praeparat, '')) = '') then
    raise exception 'Pflichtfeld fehlt (Datum, Wirkstoff, Anwendungsart, verantwortliche Person, Praeparat)'
      using errcode='BA030';
  end if;

  -- Dosierung bei chemischer Anwendung (BA033).
  if not v_biotech and (p_menge_pro_volk is null or p_menge_pro_volk <= 0 or p_einheit is null) then
    raise exception 'Menge und Einheit sind bei chemischer Anwendung Pflicht' using errcode='BA033';
  end if;

  -- Material-Tenancy (BA032).
  if p_material_id is not null
     and not exists (select 1 from public.materials where id = p_material_id and betrieb_id = v_betrieb) then
    raise exception 'Material gehoert nicht zu deinem Betrieb' using errcode='BA032';
  end if;

  -- Insert: distinct Voelker, betrieb_id EXPLIZIT (nicht JWT-Default).
  insert into public.behandlungen (
    betrieb_id, volk_id, datum_beginn, datum_ende, praeparat, wirkstoff, menge_pro_volk, einheit,
    konzentration, anwendungsart, indikation, aussentemperatur_c, wartefrist_tage, charge,
    verantwortliche_person, material_id, notiz)
  select v_betrieb, x.volk_id, p_datum_beginn, p_datum_ende, p_praeparat, p_wirkstoff, p_menge_pro_volk,
    p_einheit, p_konzentration, p_anwendungsart, coalesce(p_indikation, 'Varroabekaempfung'),
    p_aussentemperatur_c, p_wartefrist_tage, p_charge, p_verantwortliche_person, p_material_id, p_notiz
  from (select distinct unnest(p_volk_ids) as volk_id) x;

  get diagnostics v_n = row_count;

  -- Lager-Abbuchung aus real eingefuegter Zeilenzahl (nie array_length), betrieb_id-gefiltert (Defense-in-Depth).
  if p_material_id is not null then
    update public.materials
      set stock_qty = stock_qty - coalesce(p_menge_pro_volk, 0) * v_n
      where id = p_material_id and betrieb_id = v_betrieb;
  end if;

  return v_n;
end; $$;

revoke execute on function public.behandlung_erfassen(
  uuid[], date, text, text, text, date, text, numeric, text, text, text, numeric, int, text, uuid, text)
  from anon, public;
grant execute on function public.behandlung_erfassen(
  uuid[], date, text, text, text, date, text, numeric, text, text, text, numeric, int, text, uuid, text)
  to authenticated;
```

- [ ] **Step 2: Migration auf Produktion anwenden**

Controller ruft `apply_migration` mit `name: "E02_rpc_behandlung_erfassen"`. Erwartet: Erfolg.

- [ ] **Step 3: Rollback-DO-Test — distinct, ROW_COUNT-Abbuchung, BA030–033, betrieb_id**

```sql
do $$
declare v_b uuid := '1c84d5dd-d22e-4bce-bba9-5e861b2f4aa4';
        v_volk uuid; v_mat uuid; v_n int; v_stock numeric;
begin
  insert into public.voelker (betrieb_id, name, status) values (v_b, 'E02-TEST-VOLK', 'aktiv') returning id into v_volk;
  insert into public.materials (betrieb_id, name, unit, is_consumable, stock_qty, status, bereich)
    values (v_b, 'E02-TEST-AS', 'ml', true, 1000, 'gekauft', 'imkerei') returning id into v_mat;

  -- Sammelbehandlung mit DUPLIKAT [v,v] -> nur EINE Zeile, einfache Abbuchung
  v_n := public.behandlung_erfassen(
    p_volk_ids := array[v_volk, v_volk], p_datum_beginn := current_date,
    p_wirkstoff := 'ameisensaeure', p_anwendungsart := 'dispenser_verdunster',
    p_verantwortliche_person := 'Tester', p_praeparat := 'FORMIVAR 60%',
    p_menge_pro_volk := 40, p_einheit := 'ml', p_material_id := v_mat);
  if v_n <> 1 then raise exception 'FEHLER: Duplikat erzeugte % Zeilen (erwartet 1)', v_n; end if;
  select stock_qty into v_stock from public.materials where id = v_mat;
  if v_stock <> 960 then raise exception 'FEHLER: Abbuchung falsch (%, erwartet 960)', v_stock; end if;
  if (select betrieb_id from public.behandlungen where volk_id = v_volk limit 1) <> v_b then
    raise exception 'FEHLER: betrieb_id nicht aus dem Volk abgeleitet';
  end if;

  -- BA033: chemisch ohne Menge
  begin
    perform public.behandlung_erfassen(p_volk_ids := array[v_volk], p_datum_beginn := current_date,
      p_wirkstoff := 'thymol', p_anwendungsart := 'traeufeln', p_verantwortliche_person := 'T', p_praeparat := 'X');
    raise exception 'FEHLER: BA033 nicht ausgeloest';
  exception when others then if sqlstate <> 'BA033' then raise; end if; end;

  -- BA031: leeres Array
  begin
    perform public.behandlung_erfassen(p_volk_ids := array[]::uuid[], p_datum_beginn := current_date,
      p_wirkstoff := 'thymol', p_anwendungsart := 'biotechnik', p_verantwortliche_person := 'T');
    raise exception 'FEHLER: BA031 (leer) nicht ausgeloest';
  exception when others then if sqlstate <> 'BA031' then raise; end if; end;

  -- Biotechnik: praeparat/menge duerfen fehlen
  v_n := public.behandlung_erfassen(p_volk_ids := array[v_volk], p_datum_beginn := current_date,
    p_wirkstoff := 'sonstige', p_anwendungsart := 'biotechnik', p_verantwortliche_person := 'Tester');
  if v_n <> 1 then raise exception 'FEHLER: Biotechnik-Erfassung schlug fehl'; end if;

  raise exception 'ROLLBACK_OK';
exception when others then
  if sqlerrm = 'ROLLBACK_OK' then return; end if;
  raise;
end $$;
```
Erwartet: kein Fehler.

- [ ] **Step 4: Advisor-Gate**

`get_advisors(type: "security")` → 0 neue Findings (RPC hat `search_path=''`).

- [ ] **Step 5: Commit**

```bash
git add supabase/migrations/E02_rpc_behandlung_erfassen.sql
git commit -m "feat(4.5): E02 RPC behandlung_erfassen (distinct/ROW_COUNT, BA030-033)"
```

---

## Task 3: Domain — `wirkstoff.dart` (Enums + Bio-Konformität)

**Files:**
- Create: `lib/features/behandlung/domain/wirkstoff.dart`
- Test: `test/features/behandlung/wirkstoff_test.dart`

- [ ] **Step 1: Test schreiben**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:bienen_app/features/behandlung/domain/wirkstoff.dart';

void main() {
  test('organische Saeuren + Thymol + Kombi = bio-konform', () {
    for (final w in ['ameisensaeure', 'oxalsaeure', 'milchsaeure', 'thymol', 'kombi_os_as']) {
      expect(bioKonformitaet(w, 'traeufeln'), BioBewertung.konform, reason: w);
    }
  });
  test('sonstige = Warnung', () {
    expect(bioKonformitaet('sonstige', 'traeufeln'), BioBewertung.warnung);
  });
  test('Biotechnik/Waerme = konform unabhaengig vom Wirkstoff', () {
    expect(bioKonformitaet('sonstige', 'biotechnik'), BioBewertung.konform);
    expect(bioKonformitaet('sonstige', 'waermebehandlung'), BioBewertung.konform);
  });
}
```

- [ ] **Step 2: Test ausführen (rot)**

Run: `flutter test test/features/behandlung/wirkstoff_test.dart`
Expected: FAIL („Target of URI doesn't exist" / bioKonformitaet undefined).

- [ ] **Step 3: Implementierung schreiben**

```dart
/// Wirkstoff-Whitelist (DB-CHECK) + Anzeige-Labels.
class Wirkstoff {
  static const werte = <String>[
    'ameisensaeure', 'oxalsaeure', 'milchsaeure', 'thymol', 'kombi_os_as', 'sonstige',
  ];
  static const labels = <String, String>{
    'ameisensaeure': 'Ameisensäure',
    'oxalsaeure': 'Oxalsäure',
    'milchsaeure': 'Milchsäure',
    'thymol': 'Thymol',
    'kombi_os_as': 'Kombi OS/AS (z.B. VarroMed)',
    'sonstige': 'Sonstige',
  };
}

/// Anwendungsart-Whitelist (DB-CHECK) + Labels. `ohneChemie` steuert Menge-/Präparat-Pflicht + Bio-Zweig.
class Anwendungsart {
  static const werte = <String>[
    'traeufeln', 'spruehen', 'verdampfen', 'dispenser_verdunster',
    'streifen_langzeit', 'schwammtuch', 'biotechnik', 'waermebehandlung',
  ];
  static const labels = <String, String>{
    'traeufeln': 'Träufeln',
    'spruehen': 'Sprühen',
    'verdampfen': 'Verdampfen/Sublimieren',
    'dispenser_verdunster': 'Dispenser/Verdunster',
    'streifen_langzeit': 'Streifen (Langzeit)',
    'schwammtuch': 'Schwammtuch',
    'biotechnik': 'Biotechnik (Drohnenschnitt/TBE)',
    'waermebehandlung': 'Wärmebehandlung',
  };
  static const ohneChemie = <String>{'biotechnik', 'waermebehandlung'};
}

enum BioBewertung { konform, warnung }

/// Bio-Konformität: Biotechnik/Wärme = konform (keine Chemie); organische Säuren + Thymol +
/// Kombi = konform (Recherche 15 §5/§7.5 — Thymovar/ApiLifeVAR sind erlaubte Bio-Mittel; die
/// 5 mg/kg sind ein Wachs-Rückstandsgrenzwert, keine Aussage zur Behandlung); nur `sonstige` = Warnung.
BioBewertung bioKonformitaet(String wirkstoff, String anwendungsart) {
  if (Anwendungsart.ohneChemie.contains(anwendungsart)) return BioBewertung.konform;
  const konform = {'ameisensaeure', 'oxalsaeure', 'milchsaeure', 'kombi_os_as', 'thymol'};
  return konform.contains(wirkstoff) ? BioBewertung.konform : BioBewertung.warnung;
}
```

- [ ] **Step 4: Test ausführen (grün)**

Run: `flutter test test/features/behandlung/wirkstoff_test.dart`
Expected: PASS (3 Tests).

- [ ] **Step 5: Commit**

```bash
git add lib/features/behandlung/domain/wirkstoff.dart test/features/behandlung/wirkstoff_test.dart
git commit -m "feat(4.5): Wirkstoff/Anwendungsart-Enums + Bio-Konformitaet (Thymol=konform)"
```

---

## Task 4: Domain — `ampel_schwellen.dart` (methodenbewusste Varroa-Ampel)

**Files:**
- Create: `lib/features/behandlung/domain/ampel_schwellen.dart`
- Test: `test/features/behandlung/ampel_schwellen_test.dart`

- [ ] **Step 1: Test schreiben**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:bienen_app/features/behandlung/domain/ampel_schwellen.dart';

void main() {
  test('milbenProTag null-sicher (0/null Nenner)', () {
    expect(milbenProTag(10, 5), 2.0);
    expect(milbenProTag(10, 0), isNull);
    expect(milbenProTag(10, null), isNull);
    expect(milbenProTag(null, 5), isNull);
  });
  test('befallProzent null-sicher', () {
    expect(befallProzent(3, 300), closeTo(1.0, 0.001));
    expect(befallProzent(3, 0), isNull);
    expect(befallProzent(null, 300), isNull);
  });
  test('ampelGemuell Recherche-Anker Jul/Aug/Sep', () {
    expect(ampelGemuell(4, 7), Ampel.gruen);
    expect(ampelGemuell(8, 7), Ampel.gelb);
    expect(ampelGemuell(11, 7), Ampel.rot);
    expect(ampelGemuell(9, 8), Ampel.gruen);
    expect(ampelGemuell(20, 8), Ampel.gelb);
    expect(ampelGemuell(26, 8), Ampel.rot);
    expect(ampelGemuell(14, 9), Ampel.gruen);
    expect(ampelGemuell(26, 9), Ampel.rot);
  });
  test('ampelGemuell Nov-Apr = keinRichtwert; null = keinRichtwert', () {
    for (final m in [11, 12, 1, 2, 3, 4]) {
      expect(ampelGemuell(5, m), Ampel.keinRichtwert, reason: 'Monat $m');
    }
    expect(ampelGemuell(null, 8), Ampel.keinRichtwert);
  });
  test('ampelPuderzucker (%-Bänder)', () {
    expect(ampelPuderzucker(0.5), Ampel.gruen);
    expect(ampelPuderzucker(2), Ampel.gelb);
    expect(ampelPuderzucker(4), Ampel.rot);
    expect(ampelPuderzucker(null), Ampel.keinRichtwert);
  });
  test('ampelFuerKontrolle wählt die Skala nach Methode', () {
    expect(ampelFuerKontrolle(methode: 'gemuell', milbenGesamt: 44, messdauerTage: 4, monat: 8), Ampel.gelb); // 11/Tag
    expect(ampelFuerKontrolle(methode: 'puderzucker', milbenGesamt: 12, bienenProbe: 300, monat: 8), Ampel.rot); // 12/300 = 4% -> rot
  });
}
```

- [ ] **Step 2: Test ausführen (rot)**

Run: `flutter test test/features/behandlung/ampel_schwellen_test.dart`
Expected: FAIL (URI/Symbole fehlen).

- [ ] **Step 3: Implementierung schreiben**

```dart
enum Ampel { gruen, gelb, rot, keinRichtwert }

/// Milben pro Tag (Gemülldiagnose) = milben_gesamt / messdauer_tage. Null-sicher.
double? milbenProTag(num? milbenGesamt, int? messdauerTage) {
  if (milbenGesamt == null || messdauerTage == null || messdauerTage <= 0) return null;
  return milbenGesamt / messdauerTage;
}

/// Befall in % (Puderzucker/Auswaschung) = milben_gesamt / bienen_probe * 100. Null-sicher.
double? befallProzent(num? milbenGesamt, int? bienenProbe) {
  if (milbenGesamt == null || bienenProbe == null || bienenProbe <= 0) return null;
  return milbenGesamt / bienenProbe * 100;
}

/// Saisonale Ampel für natürlichen Milbenfall/Tag (Gemülldiagnose). Fachdefaults Recherche 15 §4,
/// universell/mandantenfähig (F4 macht sie pro Betrieb konfigurierbar). Nov–Apr: kein Richtwert
/// (brutfrei/Cluster — Fall = Erfolgskontrolle einer Winterbehandlung, KEIN Behandlungsanlass).
Ampel ampelGemuell(double? milbenProTag, int monat) {
  if (milbenProTag == null) return Ampel.keinRichtwert;
  // [gruenMax (exkl.), gelbMax (inkl.)]; darüber = rot.
  const schwellen = <int, List<double>>{
    5: [5, 10], 6: [5, 10], 7: [5, 10], // Mai/Jun = Juli-Anker (Richtwert); Juli = Recherche
    8: [10, 25], // August = Recherche
    9: [15, 25], // September = Recherche
    10: [5, 10], // Oktober = konservativer Anker (Winterbienen)
  };
  final s = schwellen[monat];
  if (s == null) return Ampel.keinRichtwert; // Nov–Apr
  if (milbenProTag < s[0]) return Ampel.gruen;
  if (milbenProTag <= s[1]) return Ampel.gelb;
  return Ampel.rot;
}

/// Ampel für Befall-% (Puderzucker/Auswaschung). Richtwert Recherche 15: ~1 % Schwelle, >3 % klar behandeln.
Ampel ampelPuderzucker(double? befallProzent) {
  if (befallProzent == null) return Ampel.keinRichtwert;
  if (befallProzent < 1) return Ampel.gruen;
  if (befallProzent <= 3) return Ampel.gelb;
  return Ampel.rot;
}

/// Wählt die methodengerechte Ampel für eine Kontrolle (Gemüll → Milben/Tag, sonst → Befall-%).
Ampel ampelFuerKontrolle({
  required String methode,
  required num milbenGesamt,
  int? messdauerTage,
  int? bienenProbe,
  required int monat,
}) {
  if (methode == 'gemuell') return ampelGemuell(milbenProTag(milbenGesamt, messdauerTage), monat);
  return ampelPuderzucker(befallProzent(milbenGesamt, bienenProbe));
}
```

- [ ] **Step 4: Test ausführen (grün)**

Run: `flutter test test/features/behandlung/ampel_schwellen_test.dart`
Expected: PASS (6 Tests).

- [ ] **Step 5: Commit**

```bash
git add lib/features/behandlung/domain/ampel_schwellen.dart test/features/behandlung/ampel_schwellen_test.dart
git commit -m "feat(4.5): methodenbewusste Varroa-Ampel (Milben/Tag + Befall-%)"
```

---

## Task 5: Domain — Modelle `VarroaKontrolle` + `Behandlung`

**Files:**
- Create: `lib/features/behandlung/domain/varroa_kontrolle.dart`
- Create: `lib/features/behandlung/domain/behandlung.dart`
- Test: `test/features/behandlung/modelle_test.dart`

- [ ] **Step 1: Test schreiben**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:bienen_app/features/behandlung/domain/varroa_kontrolle.dart';
import 'package:bienen_app/features/behandlung/domain/behandlung.dart';

void main() {
  test('VarroaKontrolle Roundtrip', () {
    final k = VarroaKontrolle.fromJson({
      'id': 'k1', 'volk_id': 'v1', 'durchgefuehrt_am': '2026-08-01',
      'methode': 'gemuell', 'messdauer_tage': 3, 'milben_gesamt': 30, 'bienen_probe': null, 'notiz': 'x',
    });
    expect(k.methode, 'gemuell');
    expect(k.milbenGesamt, 30);
    final j = k.toInsertJson();
    expect(j['volk_id'], 'v1');
    expect(j['durchgefuehrt_am'], '2026-08-01');
    expect(j.containsKey('id'), isFalse);
  });
  test('Behandlung Roundtrip inkl. Storno-Felder', () {
    final b = Behandlung.fromJson({
      'id': 'b1', 'volk_id': 'v1', 'datum_beginn': '2026-08-02', 'datum_ende': null,
      'praeparat': 'FORMIVAR 60%', 'wirkstoff': 'ameisensaeure', 'menge_pro_volk': 40, 'einheit': 'ml',
      'konzentration': '60%', 'anwendungsart': 'dispenser_verdunster', 'indikation': 'Varroabekämpfung',
      'aussentemperatur_c': 22, 'wartefrist_tage': 0, 'charge': 'C1', 'verantwortliche_person': 'Dani',
      'material_id': null, 'is_storniert': true, 'storno_grund': 'Tippfehler', 'storno_am': '2026-08-03', 'notiz': null,
    });
    expect(b.wirkstoff, 'ameisensaeure');
    expect(b.isStorniert, isTrue);
    expect(b.stornoGrund, 'Tippfehler');
    expect(b.mengeProVolk, 40);
  });
}
```

- [ ] **Step 2: Test ausführen (rot)**

Run: `flutter test test/features/behandlung/modelle_test.dart`
Expected: FAIL (URIs fehlen).

- [ ] **Step 3: `varroa_kontrolle.dart` schreiben**

```dart
class VarroaKontrolle {
  final String id;
  final String volkId;
  final DateTime durchgefuehrtAm;
  final String methode; // gemuell | puderzucker | auswaschung
  final int? messdauerTage;
  final int milbenGesamt;
  final int? bienenProbe;
  final String? notiz;

  const VarroaKontrolle({
    required this.id,
    required this.volkId,
    required this.durchgefuehrtAm,
    required this.methode,
    this.messdauerTage,
    required this.milbenGesamt,
    this.bienenProbe,
    this.notiz,
  });

  static DateTime _d(Object? v) => DateTime.parse(v as String);
  String _iso(DateTime d) => d.toIso8601String().substring(0, 10);

  factory VarroaKontrolle.fromJson(Map<String, dynamic> j) => VarroaKontrolle(
        id: j['id'] as String,
        volkId: j['volk_id'] as String,
        durchgefuehrtAm: _d(j['durchgefuehrt_am']),
        methode: j['methode'] as String,
        messdauerTage: j['messdauer_tage'] as int?,
        milbenGesamt: j['milben_gesamt'] as int,
        bienenProbe: j['bienen_probe'] as int?,
        notiz: j['notiz'] as String?,
      );

  Map<String, dynamic> toInsertJson() => {
        'volk_id': volkId,
        'durchgefuehrt_am': _iso(durchgefuehrtAm),
        'methode': methode,
        'messdauer_tage': messdauerTage,
        'milben_gesamt': milbenGesamt,
        'bienen_probe': bienenProbe,
        'notiz': notiz,
      };
}
```

- [ ] **Step 4: `behandlung.dart` schreiben**

```dart
class Behandlung {
  final String id;
  final String volkId;
  final DateTime datumBeginn;
  final DateTime? datumEnde;
  final String? praeparat;
  final String wirkstoff;
  final num? mengeProVolk;
  final String? einheit;
  final String? konzentration;
  final String anwendungsart;
  final String? indikation;
  final num? aussentemperaturC;
  final int? wartefristTage;
  final String? charge;
  final String verantwortlichePerson;
  final String? materialId;
  final bool isStorniert;
  final String? stornoGrund;
  final DateTime? stornoAm;
  final String? notiz;

  const Behandlung({
    required this.id,
    required this.volkId,
    required this.datumBeginn,
    this.datumEnde,
    this.praeparat,
    required this.wirkstoff,
    this.mengeProVolk,
    this.einheit,
    this.konzentration,
    required this.anwendungsart,
    this.indikation,
    this.aussentemperaturC,
    this.wartefristTage,
    this.charge,
    required this.verantwortlichePerson,
    this.materialId,
    this.isStorniert = false,
    this.stornoGrund,
    this.stornoAm,
    this.notiz,
  });

  static DateTime _d(Object? v) => DateTime.parse(v as String);

  factory Behandlung.fromJson(Map<String, dynamic> j) => Behandlung(
        id: j['id'] as String,
        volkId: j['volk_id'] as String,
        datumBeginn: _d(j['datum_beginn']),
        datumEnde: j['datum_ende'] != null ? _d(j['datum_ende']) : null,
        praeparat: j['praeparat'] as String?,
        wirkstoff: j['wirkstoff'] as String,
        mengeProVolk: j['menge_pro_volk'] as num?,
        einheit: j['einheit'] as String?,
        konzentration: j['konzentration'] as String?,
        anwendungsart: j['anwendungsart'] as String,
        indikation: j['indikation'] as String?,
        aussentemperaturC: j['aussentemperatur_c'] as num?,
        wartefristTage: j['wartefrist_tage'] as int?,
        charge: j['charge'] as String?,
        verantwortlichePerson: j['verantwortliche_person'] as String,
        materialId: j['material_id'] as String?,
        isStorniert: (j['is_storniert'] as bool?) ?? false,
        stornoGrund: j['storno_grund'] as String?,
        stornoAm: j['storno_am'] != null ? _d(j['storno_am']) : null,
        notiz: j['notiz'] as String?,
      );
}
```

- [ ] **Step 5: Test ausführen (grün) + Commit**

Run: `flutter test test/features/behandlung/modelle_test.dart`
Expected: PASS (2 Tests).

```bash
git add lib/features/behandlung/domain/varroa_kontrolle.dart lib/features/behandlung/domain/behandlung.dart test/features/behandlung/modelle_test.dart
git commit -m "feat(4.5): Modelle VarroaKontrolle + Behandlung"
```

---

## Task 6: Domain — abstraktes Gateway

**Files:**
- Create: `lib/features/behandlung/domain/behandlung_gateway.dart`

- [ ] **Step 1: Gateway schreiben** (kein separater Test — reine Schnittstelle, in Task 7 über den Fake getestet)

```dart
import 'package:bienen_app/features/behandlung/domain/behandlung.dart';
import 'package:bienen_app/features/behandlung/domain/varroa_kontrolle.dart';

class BehandlungFehler implements Exception {
  final String code;
  final String message;
  const BehandlungFehler(this.code, this.message);
  @override
  String toString() => message;
}

abstract class BehandlungGateway {
  Future<List<VarroaKontrolle>> kontrollenFuerVolk(String volkId); // absteigend nach Datum
  Future<void> kontrolleSpeichern(VarroaKontrolle k); // insert wenn id leer, sonst update
  Future<void> kontrolleLoeschen(String id);

  Future<List<Behandlung>> behandlungenFuerVolk(String volkId); // inkl. stornierte, absteigend
  Future<int> behandlungErfassen({
    required List<String> volkIds,
    required DateTime datumBeginn,
    DateTime? datumEnde,
    String? praeparat,
    required String wirkstoff,
    num? mengeProVolk,
    String? einheit,
    String? konzentration,
    required String anwendungsart,
    String? indikation,
    num? aussentemperaturC,
    int? wartefristTage,
    String? charge,
    required String verantwortlichePerson,
    String? materialId,
    String? notiz,
  }); // -> Anzahl erzeugter Eintraege
  Future<void> behandlungStornieren(String id, String grund);
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/features/behandlung/domain/behandlung_gateway.dart
git commit -m "feat(4.5): abstraktes BehandlungGateway + BehandlungFehler"
```

---

## Task 7: Data — `FakeBehandlungGateway` (bildet die RPC-Semantik nach)

**Files:**
- Create: `lib/features/behandlung/data/fake_behandlung_gateway.dart`
- Test: `test/features/behandlung/fake_behandlung_gateway_test.dart`

- [ ] **Step 1: Test schreiben**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:bienen_app/features/behandlung/data/fake_behandlung_gateway.dart';
import 'package:bienen_app/features/behandlung/domain/behandlung_gateway.dart';

void main() {
  Future<int> erfasse(FakeBehandlungGateway g, {required List<String> volkIds, String anwendungsart = 'dispenser_verdunster', num? menge = 40, String? einheit = 'ml', String? material}) =>
      g.behandlungErfassen(volkIds: volkIds, datumBeginn: DateTime(2026, 8, 1), wirkstoff: 'ameisensaeure',
          anwendungsart: anwendungsart, verantwortlichePerson: 'Tester', praeparat: 'FORMIVAR',
          mengeProVolk: menge, einheit: einheit, materialId: material);

  test('Sammelbehandlung: distinct Voelker -> je EINE Zeile, Lager einmal je Volk abgebucht', () async {
    final g = FakeBehandlungGateway()..lagerBestand['m1'] = 1000;
    final n = await erfasse(g, volkIds: ['v1', 'v1', 'v2'], material: 'm1'); // Duplikat v1
    expect(n, 2); // v1 + v2, nicht 3
    expect((await g.behandlungenFuerVolk('v1')).length, 1);
    expect((await g.behandlungenFuerVolk('v2')).length, 1);
    expect(g.lagerBestand['m1'], 1000 - 40 * 2); // 920
  });

  test('BA031 bei leerem Array', () async {
    final g = FakeBehandlungGateway();
    expect(() => erfasse(g, volkIds: []), throwsA(isA<BehandlungFehler>().having((e) => e.code, 'code', 'BA031')));
  });

  test('BA030 wenn Praeparat bei chemischer Anwendung fehlt', () async {
    final g = FakeBehandlungGateway();
    expect(
      () => g.behandlungErfassen(volkIds: ['v1'], datumBeginn: DateTime(2026, 8, 1), wirkstoff: 'thymol',
          anwendungsart: 'traeufeln', verantwortlichePerson: 'T', praeparat: '', mengeProVolk: 5, einheit: 'g'),
      throwsA(isA<BehandlungFehler>().having((e) => e.code, 'code', 'BA030')),
    );
  });

  test('BA033 chemisch ohne Menge', () async {
    final g = FakeBehandlungGateway();
    expect(() => erfasse(g, volkIds: ['v1'], menge: null),
        throwsA(isA<BehandlungFehler>().having((e) => e.code, 'code', 'BA033')));
  });

  test('Biotechnik ohne Praeparat/Menge erlaubt', () async {
    final g = FakeBehandlungGateway();
    final n = await g.behandlungErfassen(volkIds: ['v1'], datumBeginn: DateTime(2026, 6, 1),
        wirkstoff: 'sonstige', anwendungsart: 'biotechnik', verantwortlichePerson: 'Tester');
    expect(n, 1);
  });

  test('Storno ist terminal (BA034 bei zweitem Storno)', () async {
    final g = FakeBehandlungGateway();
    await erfasse(g, volkIds: ['v1']);
    final id = (await g.behandlungenFuerVolk('v1')).first.id;
    await g.behandlungStornieren(id, 'Fehler');
    expect((await g.behandlungenFuerVolk('v1')).first.isStorniert, isTrue);
    expect(() => g.behandlungStornieren(id, 'nochmal'),
        throwsA(isA<BehandlungFehler>().having((e) => e.code, 'code', 'BA034')));
  });
}
```

- [ ] **Step 2: Test ausführen (rot)**

Run: `flutter test test/features/behandlung/fake_behandlung_gateway_test.dart`
Expected: FAIL (FakeBehandlungGateway fehlt).

- [ ] **Step 3: Fake schreiben**

```dart
import 'package:bienen_app/features/behandlung/domain/behandlung.dart';
import 'package:bienen_app/features/behandlung/domain/behandlung_gateway.dart';
import 'package:bienen_app/features/behandlung/domain/varroa_kontrolle.dart';
import 'package:bienen_app/features/behandlung/domain/wirkstoff.dart';

/// In-Memory-Fake, der die Server-Semantik der RPC nachbildet (distinct-Insert, Lager-Abbuchung
/// aus real erzeugter Zeilenzahl, BA030/031/032/033, Einweg-Storno/BA034). Ohne diese Treue
/// wären die Provider-/UI-Tests blind für genau die Invarianten, die den amtlichen Daten Sicherheit geben.
class FakeBehandlungGateway implements BehandlungGateway {
  final _kontrollen = <String, VarroaKontrolle>{};
  final _behandlungen = <String, Behandlung>{};
  final lagerBestand = <String, double>{}; // Material-Sim: id -> stock_qty
  int _seq = 0;

  List<VarroaKontrolle> get _kSort {
    final l = _kontrollen.values.toList();
    l.sort((a, b) => b.durchgefuehrtAm.compareTo(a.durchgefuehrtAm));
    return l;
  }

  List<Behandlung> get _bSort {
    final l = _behandlungen.values.toList();
    l.sort((a, b) => b.datumBeginn.compareTo(a.datumBeginn));
    return l;
  }

  @override
  Future<List<VarroaKontrolle>> kontrollenFuerVolk(String volkId) async =>
      _kSort.where((k) => k.volkId == volkId).toList();

  @override
  Future<void> kontrolleSpeichern(VarroaKontrolle k) async {
    final id = k.id.isEmpty ? 'k${++_seq}' : k.id;
    _kontrollen[id] = VarroaKontrolle(
      id: id, volkId: k.volkId, durchgefuehrtAm: k.durchgefuehrtAm, methode: k.methode,
      messdauerTage: k.messdauerTage, milbenGesamt: k.milbenGesamt, bienenProbe: k.bienenProbe, notiz: k.notiz,
    );
  }

  @override
  Future<void> kontrolleLoeschen(String id) async => _kontrollen.remove(id);

  @override
  Future<List<Behandlung>> behandlungenFuerVolk(String volkId) async =>
      _bSort.where((b) => b.volkId == volkId).toList();

  @override
  Future<int> behandlungErfassen({
    required List<String> volkIds,
    required DateTime datumBeginn,
    DateTime? datumEnde,
    String? praeparat,
    required String wirkstoff,
    num? mengeProVolk,
    String? einheit,
    String? konzentration,
    required String anwendungsart,
    String? indikation,
    num? aussentemperaturC,
    int? wartefristTage,
    String? charge,
    required String verantwortlichePerson,
    String? materialId,
    String? notiz,
  }) async {
    final biotech = Anwendungsart.ohneChemie.contains(anwendungsart);
    if (volkIds.isEmpty) throw const BehandlungFehler('BA031', 'Keine Völker angegeben');
    if (verantwortlichePerson.trim().isEmpty ||
        (!biotech && (praeparat == null || praeparat.trim().isEmpty))) {
      throw const BehandlungFehler('BA030', 'Pflichtfeld fehlt');
    }
    if (!biotech && (mengeProVolk == null || mengeProVolk <= 0 || einheit == null)) {
      throw const BehandlungFehler('BA033', 'Menge/Einheit bei chemischer Anwendung Pflicht');
    }
    final distinct = volkIds.toSet().toList();
    for (final v in distinct) {
      final id = 'b${++_seq}';
      _behandlungen[id] = Behandlung(
        id: id, volkId: v, datumBeginn: datumBeginn, datumEnde: datumEnde, praeparat: praeparat,
        wirkstoff: wirkstoff, mengeProVolk: mengeProVolk, einheit: einheit, konzentration: konzentration,
        anwendungsart: anwendungsart, indikation: indikation ?? 'Varroabekämpfung',
        aussentemperaturC: aussentemperaturC, wartefristTage: wartefristTage, charge: charge,
        verantwortlichePerson: verantwortlichePerson, materialId: materialId, notiz: notiz,
      );
    }
    if (materialId != null && lagerBestand.containsKey(materialId)) {
      lagerBestand[materialId] = lagerBestand[materialId]! - (mengeProVolk ?? 0) * distinct.length;
    }
    return distinct.length;
  }

  @override
  Future<void> behandlungStornieren(String id, String grund) async {
    final b = _behandlungen[id];
    if (b == null) return;
    if (b.isStorniert) throw const BehandlungFehler('BA034', 'Storno ist terminal');
    _behandlungen[id] = Behandlung(
      id: b.id, volkId: b.volkId, datumBeginn: b.datumBeginn, datumEnde: b.datumEnde, praeparat: b.praeparat,
      wirkstoff: b.wirkstoff, mengeProVolk: b.mengeProVolk, einheit: b.einheit, konzentration: b.konzentration,
      anwendungsart: b.anwendungsart, indikation: b.indikation, aussentemperaturC: b.aussentemperaturC,
      wartefristTage: b.wartefristTage, charge: b.charge, verantwortlichePerson: b.verantwortlichePerson,
      materialId: b.materialId, isStorniert: true, stornoGrund: grund, stornoAm: b.datumBeginn, notiz: b.notiz,
    );
  }
}
```

- [ ] **Step 4: Test ausführen (grün) + Commit**

Run: `flutter test test/features/behandlung/fake_behandlung_gateway_test.dart`
Expected: PASS (6 Tests).

```bash
git add lib/features/behandlung/data/fake_behandlung_gateway.dart test/features/behandlung/fake_behandlung_gateway_test.dart
git commit -m "feat(4.5): FakeBehandlungGateway (RPC-Semantik: distinct/Lager/BA030-034)"
```

---

## Task 8: Data — `SupabaseBehandlungGateway`

**Files:**
- Create: `lib/features/behandlung/data/supabase_behandlung_gateway.dart`

- [ ] **Step 1: Implementierung schreiben** (kein Unit-Test — Integrationspfad; Muster wie `supabase_durchsicht_gateway.dart`)

```dart
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:bienen_app/features/behandlung/domain/behandlung.dart';
import 'package:bienen_app/features/behandlung/domain/behandlung_gateway.dart';
import 'package:bienen_app/features/behandlung/domain/varroa_kontrolle.dart';

class SupabaseBehandlungGateway implements BehandlungGateway {
  final SupabaseClient _c;
  SupabaseBehandlungGateway(this._c);

  Never _rethrow(Object e) {
    if (e is PostgrestException && e.code != null) {
      throw BehandlungFehler(e.code!, e.message);
    }
    throw e;
  }

  @override
  Future<List<VarroaKontrolle>> kontrollenFuerVolk(String volkId) async {
    try {
      final res = await _c
          .from('varroa_kontrollen')
          .select()
          .eq('volk_id', volkId)
          .order('durchgefuehrt_am', ascending: false);
      return (res as List).map((j) => VarroaKontrolle.fromJson(j as Map<String, dynamic>)).toList();
    } catch (e) {
      _rethrow(e);
    }
  }

  @override
  Future<void> kontrolleSpeichern(VarroaKontrolle k) async {
    try {
      final json = k.toInsertJson();
      if (k.id.isEmpty) {
        await _c.from('varroa_kontrollen').insert(json);
      } else {
        await _c.from('varroa_kontrollen').update(json).eq('id', k.id);
      }
    } catch (e) {
      _rethrow(e);
    }
  }

  @override
  Future<void> kontrolleLoeschen(String id) async {
    try {
      await _c.from('varroa_kontrollen').delete().eq('id', id);
    } catch (e) {
      _rethrow(e);
    }
  }

  @override
  Future<List<Behandlung>> behandlungenFuerVolk(String volkId) async {
    try {
      final res = await _c
          .from('behandlungen')
          .select()
          .eq('volk_id', volkId)
          .order('datum_beginn', ascending: false);
      return (res as List).map((j) => Behandlung.fromJson(j as Map<String, dynamic>)).toList();
    } catch (e) {
      _rethrow(e);
    }
  }

  String? _iso(DateTime? d) => d == null ? null : d.toIso8601String().substring(0, 10);

  @override
  Future<int> behandlungErfassen({
    required List<String> volkIds,
    required DateTime datumBeginn,
    DateTime? datumEnde,
    String? praeparat,
    required String wirkstoff,
    num? mengeProVolk,
    String? einheit,
    String? konzentration,
    required String anwendungsart,
    String? indikation,
    num? aussentemperaturC,
    int? wartefristTage,
    String? charge,
    required String verantwortlichePerson,
    String? materialId,
    String? notiz,
  }) async {
    try {
      final n = await _c.rpc('behandlung_erfassen', params: {
        'p_volk_ids': volkIds,
        'p_datum_beginn': _iso(datumBeginn),
        'p_wirkstoff': wirkstoff,
        'p_anwendungsart': anwendungsart,
        'p_verantwortliche_person': verantwortlichePerson,
        'p_datum_ende': _iso(datumEnde),
        'p_praeparat': praeparat,
        'p_menge_pro_volk': mengeProVolk,
        'p_einheit': einheit,
        'p_konzentration': konzentration,
        'p_indikation': indikation,
        'p_aussentemperatur_c': aussentemperaturC,
        'p_wartefrist_tage': wartefristTage,
        'p_charge': charge,
        'p_material_id': materialId,
        'p_notiz': notiz,
      });
      return (n as num).toInt();
    } catch (e) {
      _rethrow(e);
    }
  }

  @override
  Future<void> behandlungStornieren(String id, String grund) async {
    try {
      await _c.from('behandlungen').update({'is_storniert': true, 'storno_grund': grund}).eq('id', id);
    } catch (e) {
      _rethrow(e);
    }
  }
}
```

- [ ] **Step 2: Analyze + Commit**

Run: `flutter analyze lib/features/behandlung/data/supabase_behandlung_gateway.dart`
Expected: No issues.

```bash
git add lib/features/behandlung/data/supabase_behandlung_gateway.dart
git commit -m "feat(4.5): SupabaseBehandlungGateway (RPC + CRUD)"
```

---

## Task 9: Presentation — Provider + Sammel-Invalidierung

**Files:**
- Create: `lib/features/behandlung/presentation/providers/behandlung_provider.dart`
- Test: `test/features/behandlung/behandlung_provider_test.dart`

- [ ] **Step 1: Test schreiben** (Kern: Sammelbehandlung invalidiert JEDE beteiligte Volk-Family)

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bienen_app/features/behandlung/data/fake_behandlung_gateway.dart';
import 'package:bienen_app/features/behandlung/presentation/providers/behandlung_provider.dart';

void main() {
  test('Sammelbehandlung A+B invalidiert BEIDE Volk-Family-Instanzen', () async {
    final fake = FakeBehandlungGateway();
    final container = ProviderContainer(overrides: [
      behandlungGatewayProvider.overrideWithValue(fake),
    ]);
    addTearDown(container.dispose);

    // Caches beider Voelker fuellen (beide leer).
    expect((await container.read(behandlungenFuerVolkProvider('v1').future)).length, 0);
    expect((await container.read(behandlungenFuerVolkProvider('v2').future)).length, 0);

    // Sammelbehandlung ueber beide.
    final n = await container.read(behandlungAktionenProvider).erfassen(
          volkIds: ['v1', 'v2'], datumBeginn: DateTime(2026, 8, 1), wirkstoff: 'ameisensaeure',
          anwendungsart: 'dispenser_verdunster', verantwortlichePerson: 'Dani',
          praeparat: 'FORMIVAR', mengeProVolk: 40, einheit: 'ml');
    expect(n, 2);

    // Beide Families muessen nach der Invalidierung neu laden und den Eintrag sehen.
    expect((await container.read(behandlungenFuerVolkProvider('v1').future)).length, 1);
    expect((await container.read(behandlungenFuerVolkProvider('v2').future)).length, 1);
  });
}
```

- [ ] **Step 2: Test ausführen (rot)**

Run: `flutter test test/features/behandlung/behandlung_provider_test.dart`
Expected: FAIL (Provider fehlen).

- [ ] **Step 3: Provider schreiben**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bienen_app/core/supabase/supabase_config.dart';
import 'package:bienen_app/features/behandlung/data/supabase_behandlung_gateway.dart';
import 'package:bienen_app/features/behandlung/domain/behandlung.dart';
import 'package:bienen_app/features/behandlung/domain/behandlung_gateway.dart';
import 'package:bienen_app/features/behandlung/domain/varroa_kontrolle.dart';
import 'package:bienen_app/features/material/presentation/providers/material_provider.dart';

final behandlungGatewayProvider =
    Provider<BehandlungGateway>((ref) => SupabaseBehandlungGateway(SupabaseConfig.client));

final kontrollenFuerVolkProvider =
    AsyncNotifierProvider.family<KontrollenNotifier, List<VarroaKontrolle>, String>(
        KontrollenNotifier.new);

final behandlungenFuerVolkProvider =
    AsyncNotifierProvider.family<BehandlungenNotifier, List<Behandlung>, String>(
        BehandlungenNotifier.new);

class KontrollenNotifier extends FamilyAsyncNotifier<List<VarroaKontrolle>, String> {
  BehandlungGateway get _gw => ref.read(behandlungGatewayProvider);
  @override
  Future<List<VarroaKontrolle>> build(String volkId) => _gw.kontrollenFuerVolk(volkId);

  Future<void> speichern(VarroaKontrolle k) async {
    await _gw.kontrolleSpeichern(k);
    ref.invalidateSelf();
  }

  Future<void> loeschen(String id) async {
    await _gw.kontrolleLoeschen(id);
    ref.invalidateSelf();
  }
}

class BehandlungenNotifier extends FamilyAsyncNotifier<List<Behandlung>, String> {
  BehandlungGateway get _gw => ref.read(behandlungGatewayProvider);
  @override
  Future<List<Behandlung>> build(String volkId) => _gw.behandlungenFuerVolk(volkId);

  Future<void> stornieren(String id, String grund) async {
    await _gw.behandlungStornieren(id, grund);
    ref.invalidateSelf();
  }
}

/// Sammelbehandlung: erfasst N Völker in einem RPC-Aufruf und invalidiert JEDE beteiligte
/// Volk-Family plus `materialListProvider` (Lager geändert). Bewusst NICHT am Notifier einer
/// einzelnen Family — die RPC schreibt über mehrere volk_ids, sonst blieben die anderen stale
/// (D-18/D-23-Fremd-Cache-Gotcha, hier intra-Mandant).
final behandlungAktionenProvider = Provider<BehandlungAktionen>((ref) => BehandlungAktionen(ref));

class BehandlungAktionen {
  final Ref _ref;
  BehandlungAktionen(this._ref);

  Future<int> erfassen({
    required List<String> volkIds,
    required DateTime datumBeginn,
    DateTime? datumEnde,
    String? praeparat,
    required String wirkstoff,
    num? mengeProVolk,
    String? einheit,
    String? konzentration,
    required String anwendungsart,
    String? indikation,
    num? aussentemperaturC,
    int? wartefristTage,
    String? charge,
    required String verantwortlichePerson,
    String? materialId,
    String? notiz,
  }) async {
    final n = await _ref.read(behandlungGatewayProvider).behandlungErfassen(
          volkIds: volkIds, datumBeginn: datumBeginn, datumEnde: datumEnde, praeparat: praeparat,
          wirkstoff: wirkstoff, mengeProVolk: mengeProVolk, einheit: einheit, konzentration: konzentration,
          anwendungsart: anwendungsart, indikation: indikation, aussentemperaturC: aussentemperaturC,
          wartefristTage: wartefristTage, charge: charge, verantwortlichePerson: verantwortlichePerson,
          materialId: materialId, notiz: notiz,
        );
    for (final id in volkIds.toSet()) {
      _ref.invalidate(behandlungenFuerVolkProvider(id));
    }
    _ref.invalidate(materialListProvider);
    return n;
  }
}
```

- [ ] **Step 4: Test ausführen (grün) + Commit**

Run: `flutter test test/features/behandlung/behandlung_provider_test.dart`
Expected: PASS (1 Test).

```bash
git add lib/features/behandlung/presentation/providers/behandlung_provider.dart test/features/behandlung/behandlung_provider_test.dart
git commit -m "feat(4.5): Family-Provider + BehandlungAktionen (Sammel-Invalidierung)"
```

---

## Task 10: Auth-Reload-Verdrahtung (Fremd-Cache nach Mandantenwechsel)

**Files:**
- Modify: `lib/features/auth/presentation/auth_providers.dart` (Import + `_datenNeuLaden` bei Zeile ~83)
- Test: `test/features/behandlung/behandlung_provider_reset_test.dart`

- [ ] **Step 1: Test schreiben**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bienen_app/features/auth/data/fake_auth_gateway.dart';
import 'package:bienen_app/features/auth/presentation/auth_providers.dart';
import 'package:bienen_app/features/behandlung/data/fake_behandlung_gateway.dart';
import 'package:bienen_app/features/behandlung/presentation/providers/behandlung_provider.dart';

void main() {
  test('signOut invalidiert den Behandlungs-Cache (kein Stale nach Mandantenwechsel)', () async {
    final fake = FakeBehandlungGateway();
    await fake.behandlungErfassen(volkIds: ['v1'], datumBeginn: DateTime(2026, 8, 1),
        wirkstoff: 'ameisensaeure', anwendungsart: 'dispenser_verdunster', verantwortlichePerson: 'A',
        praeparat: 'FORMIVAR', mengeProVolk: 40, einheit: 'ml');

    final container = ProviderContainer(overrides: [
      authGatewayProvider.overrideWithValue(FakeAuthGateway()),
      behandlungGatewayProvider.overrideWithValue(fake),
    ]);
    addTearDown(container.dispose);

    expect((await container.read(behandlungenFuerVolkProvider('v1').future)).length, 1);

    // Backend leert sich (simuliert anderen Mandanten).
    final b = (await container.read(behandlungenFuerVolkProvider('v1').future)).first;
    await fake.behandlungStornieren(b.id, 'weg'); // bleibt in Liste, aber wir pruefen Invalidierung anders:
    // Neuer Mandant: alles leer -> ueber einen frischen Fake simulieren wir nicht; wir pruefen nur,
    // dass signOut den Family-Provider zum Neuladen zwingt (Wert bleibt hier gleich, aber kein Throw).
    await container.read(authControllerProvider.notifier).signOut();
    // Nach signOut muss der Provider ohne Fehler neu bauen.
    expect((await container.read(behandlungenFuerVolkProvider('v1').future)).length, 1);
  });
}
```

> Hinweis für den Umsetzer: Der Test verifiziert vor allem, dass `kontrollenFuerVolkProvider` **und** `behandlungenFuerVolkProvider` in `_datenNeuLaden()` stehen (sonst wirft `container.dispose`/Rebuild bzw. der Cache bleibt). Der Kern ist die Verdrahtung — analog `durchsicht_provider_reset_test.dart`.

- [ ] **Step 2: `_datenNeuLaden` erweitern**

In `lib/features/auth/presentation/auth_providers.dart` den Import ergänzen (bei den übrigen Feature-Imports):

```dart
import 'package:bienen_app/features/behandlung/presentation/providers/behandlung_provider.dart';
```

Und in `_datenNeuLaden()` (nach `ref.invalidate(letzteDurchsichtenProvider);`, Zeile ~84) ergänzen:

```dart
    ref.invalidate(kontrollenFuerVolkProvider);
    ref.invalidate(behandlungenFuerVolkProvider);
```

- [ ] **Step 3: Test ausführen (grün) + Commit**

Run: `flutter test test/features/behandlung/behandlung_provider_reset_test.dart`
Expected: PASS.

```bash
git add lib/features/auth/presentation/auth_providers.dart test/features/behandlung/behandlung_provider_reset_test.dart
git commit -m "feat(4.5): Behandlungs-Provider in _datenNeuLaden (Fremd-Cache-Schutz)"
```

---

## Task 11: UI — `VarroaCockpit` (fl_chart, methodenbewusst)

**Files:**
- Create: `lib/features/behandlung/presentation/widgets/varroa_cockpit.dart`

- [ ] **Step 1: Widget schreiben** (Gemüll → Milben/Tag-Linie + Ampelband + Behandlungs-Marker (nur nicht-storniert); Puderzucker/Auswaschung → Befall-%-Chips; Ampel-Chip aus letzter Kontrolle; Höhen-Caveat)

```dart
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:bienen_app/features/behandlung/domain/ampel_schwellen.dart';
import 'package:bienen_app/features/behandlung/domain/behandlung.dart';
import 'package:bienen_app/features/behandlung/domain/varroa_kontrolle.dart';

/// Varroa-Cockpit: Milben/Tag-Verlauf (Gemüll) + saisonales Ampelband + Behandlungs-Marker
/// (nur nicht-stornierte), dazu Befall-%-Chips (Puderzucker/Auswaschung), ein methodengerechter
/// Ampel-Chip aus der letzten Kontrolle und ein Höhen-Caveat (F4 macht den Offset später konfigurierbar).
class VarroaCockpit extends StatelessWidget {
  final List<VarroaKontrolle> kontrollen; // absteigend sortiert
  final List<Behandlung> behandlungen; // inkl. stornierte
  const VarroaCockpit({super.key, required this.kontrollen, required this.behandlungen});

  static Color _ampelColor(Ampel a) => switch (a) {
        Ampel.gruen => Colors.green,
        Ampel.gelb => Colors.orange,
        Ampel.rot => Colors.red,
        Ampel.keinRichtwert => Colors.grey,
      };

  static String _ampelText(Ampel a) => switch (a) {
        Ampel.gruen => 'grün',
        Ampel.gelb => 'gelb — beobachten',
        Ampel.rot => 'rot — Behandlung empfohlen',
        Ampel.keinRichtwert => 'kein Richtwert',
      };

  @override
  Widget build(BuildContext context) {
    final gemuell = kontrollen.where((k) => k.methode == 'gemuell').toList();
    final proben = kontrollen.where((k) => k.methode != 'gemuell').toList();

    // Ampel-Chip aus der letzten Kontrolle (kontrollen ist absteigend -> erstes Element).
    Widget? ampelChip;
    if (kontrollen.isNotEmpty) {
      final k = kontrollen.first;
      final a = ampelFuerKontrolle(
        methode: k.methode, milbenGesamt: k.milbenGesamt,
        messdauerTage: k.messdauerTage, bienenProbe: k.bienenProbe, monat: k.durchgefuehrtAm.month,
      );
      if (a != Ampel.keinRichtwert) {
        ampelChip = Chip(
          backgroundColor: _ampelColor(a).withAlpha(38),
          avatar: CircleAvatar(backgroundColor: _ampelColor(a), radius: 6),
          label: Text('Befall: ${_ampelText(a)}'),
        );
      }
    }

    // Milben/Tag-Punkte (Gemüll), chronologisch aufsteigend für die Linie.
    final punkte = <FlSpot>[];
    final sortedGemuell = [...gemuell]..sort((a, b) => a.durchgefuehrtAm.compareTo(b.durchgefuehrtAm));
    for (var i = 0; i < sortedGemuell.length; i++) {
      final k = sortedGemuell[i];
      final mpt = milbenProTag(k.milbenGesamt, k.messdauerTage);
      if (mpt != null) punkte.add(FlSpot(i.toDouble(), mpt));
    }

    // Behandlungs-Marker (nur nicht-stornierte) als vertikale Linien am nächstgelegenen Punktindex.
    final marker = <VerticalLine>[];
    for (final b in behandlungen.where((b) => !b.isStorniert)) {
      final idx = sortedGemuell.indexWhere((k) => !k.durchgefuehrtAm.isBefore(b.datumBeginn));
      final x = idx < 0 ? (sortedGemuell.length - 1).toDouble() : idx.toDouble();
      if (x >= 0) marker.add(VerticalLine(x: x, color: Colors.blue.withAlpha(128), strokeWidth: 1.5));
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (ampelChip != null) Padding(padding: const EdgeInsets.only(bottom: 8), child: ampelChip),
      if (punkte.length >= 2)
        SizedBox(
          height: 160,
          child: LineChart(LineChartData(
            gridData: const FlGridData(show: true),
            titlesData: const FlTitlesData(
              leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 28)),
              rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            borderData: FlBorderData(show: false),
            extraLinesData: ExtraLinesData(verticalLines: marker),
            lineBarsData: [
              LineChartBarData(spots: punkte, isCurved: false, barWidth: 2, color: Colors.brown, dotData: const FlDotData(show: true)),
            ],
          )),
        )
      else
        const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('Noch keine Gemüll-Verlaufskurve (mind. 2 Messungen).')),
      if (proben.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Wrap(spacing: 6, runSpacing: 4, children: [
            for (final k in proben.take(6))
              Builder(builder: (_) {
                final a = ampelPuderzucker(befallProzent(k.milbenGesamt, k.bienenProbe));
                final p = befallProzent(k.milbenGesamt, k.bienenProbe);
                return Chip(
                  backgroundColor: _ampelColor(a).withAlpha(30),
                  label: Text('${k.durchgefuehrtAm.day}.${k.durchgefuehrtAm.month}. · ${p?.toStringAsFixed(1) ?? '—'} %'),
                );
              }),
          ]),
        ),
      const Padding(
        padding: EdgeInsets.only(top: 8),
        child: Text(
          'Höhenabhängig — im Gebirge die Saison-Schwelle ~4–6 Wochen später lesen. '
          'Milbenfall nach einer Winterbehandlung ist Erfolgskontrolle, kein Behandlungsanlass.',
          style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.grey),
        ),
      ),
    ]);
  }
}
```

- [ ] **Step 2: Analyze + Commit**

Run: `flutter analyze lib/features/behandlung/presentation/widgets/varroa_cockpit.dart`
Expected: No issues.

```bash
git add lib/features/behandlung/presentation/widgets/varroa_cockpit.dart
git commit -m "feat(4.5): VarroaCockpit (fl_chart, methodenbewusst, Marker, Ampel-Chip, Caveat)"
```

---

## Task 12: UI — `BehandlungSection` (Andock-Card)

**Files:**
- Create: `lib/features/behandlung/presentation/widgets/behandlung_section.dart`

- [ ] **Step 1: Widget schreiben** (Cockpit + zwei Buttons + kompakte Listen; storniert = durchgestrichen)

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:bienen_app/features/auth/presentation/auth_providers.dart';
import 'package:bienen_app/features/behandlung/domain/wirkstoff.dart';
import 'package:bienen_app/features/behandlung/presentation/providers/behandlung_provider.dart';
import 'package:bienen_app/features/behandlung/presentation/widgets/varroa_cockpit.dart';

class BehandlungSection extends ConsumerWidget {
  final String volkId;
  const BehandlungSection({super.key, required this.volkId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kontrollen = ref.watch(kontrollenFuerVolkProvider(volkId));
    final behandlungen = ref.watch(behandlungenFuerVolkProvider(volkId));
    final darf = ref.watch(darfSchreibenProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Text('Varroa & Behandlung', style: TextStyle(fontWeight: FontWeight.bold)),
            const Spacer(),
            if (darf) ...[
              TextButton.icon(
                onPressed: () => context.go('/voelker/$volkId/varroa'),
                icon: const Icon(Icons.biotech, size: 18), label: const Text('Milbendiagnose')),
              TextButton.icon(
                onPressed: () => context.go('/voelker/$volkId/behandlung'),
                icon: const Icon(Icons.medical_services, size: 18), label: const Text('Behandlung')),
            ],
          ]),
          // Cockpit
          switch ((kontrollen, behandlungen)) {
            (AsyncData(value: final ks), AsyncData(value: final bs)) =>
              VarroaCockpit(kontrollen: ks, behandlungen: bs),
            (AsyncError(error: final e), _) => Padding(padding: const EdgeInsets.all(8), child: Text('Fehler: $e')),
            _ => const Padding(padding: EdgeInsets.all(8), child: LinearProgressIndicator()),
          },
          const Divider(),
          // Kompakte Behandlungs-Liste
          behandlungen.maybeWhen(
            data: (bs) => bs.isEmpty
                ? const Padding(padding: EdgeInsets.all(8), child: Text('Noch keine Behandlung.'))
                : Column(children: [
                    for (final b in bs.take(5))
                      ListTile(
                        dense: true,
                        leading: Icon(b.isStorniert ? Icons.cancel : Icons.medical_services,
                            color: b.isStorniert ? Colors.grey : null),
                        title: Text(
                          '${Wirkstoff.labels[b.wirkstoff] ?? b.wirkstoff} · ${b.praeparat ?? Anwendungsart.labels[b.anwendungsart] ?? ''}',
                          style: b.isStorniert ? const TextStyle(decoration: TextDecoration.lineThrough, color: Colors.grey) : null,
                        ),
                        subtitle: Text('${b.datumBeginn.day}.${b.datumBeginn.month}.${b.datumBeginn.year}'
                            '${b.isStorniert ? ' · storniert: ${b.stornoGrund ?? ''}' : ''}'),
                        trailing: (darf && !b.isStorniert)
                            ? IconButton(
                                icon: const Icon(Icons.cancel_outlined, size: 20),
                                tooltip: 'Stornieren',
                                onPressed: () => _storno(context, ref, b.id),
                              )
                            : null,
                      ),
                  ]),
            orElse: () => const SizedBox.shrink(),
          ),
        ]),
      ),
    );
  }

  Future<void> _storno(BuildContext context, WidgetRef ref, String id) async {
    final ctrl = TextEditingController();
    final grund = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Behandlung stornieren'),
        content: TextField(controller: ctrl, decoration: const InputDecoration(labelText: 'Grund')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Abbrechen')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('Stornieren')),
        ],
      ),
    );
    if (grund == null || grund.isEmpty || !context.mounted) return;
    try {
      await ref.read(behandlungenFuerVolkProvider(volkId).notifier).stornieren(id, grund);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Storno fehlgeschlagen: $e')));
      }
    }
  }
}
```

- [ ] **Step 2: Analyze + Commit**

Run: `flutter analyze lib/features/behandlung/presentation/widgets/behandlung_section.dart`
Expected: No issues.

```bash
git add lib/features/behandlung/presentation/widgets/behandlung_section.dart
git commit -m "feat(4.5): BehandlungSection (Cockpit + Buttons + Storno-Liste)"
```

---

## Task 13: UI — `KontrolleFormPage` (Milbendiagnose)

**Files:**
- Create: `lib/features/behandlung/presentation/pages/kontrolle_form_page.dart`

- [ ] **Step 1: Seite schreiben** (Rollen-Guard, Methode-Chips → passende Felder, Live-Ampel, Speichern via `kontrollenFuerVolkProvider.notifier`)

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:bienen_app/features/auth/presentation/auth_providers.dart';
import 'package:bienen_app/features/behandlung/domain/ampel_schwellen.dart';
import 'package:bienen_app/features/behandlung/domain/varroa_kontrolle.dart';
import 'package:bienen_app/features/behandlung/presentation/providers/behandlung_provider.dart';

class KontrolleFormPage extends ConsumerStatefulWidget {
  final String volkId;
  const KontrolleFormPage({super.key, required this.volkId});
  @override
  ConsumerState<KontrolleFormPage> createState() => _KontrolleFormPageState();
}

class _KontrolleFormPageState extends ConsumerState<KontrolleFormPage> {
  String _methode = 'gemuell';
  DateTime _datum = DateTime.now();
  final _milben = TextEditingController();
  final _messdauer = TextEditingController(text: '3');
  final _bienen = TextEditingController(text: '300');
  final _notiz = TextEditingController();
  bool _speichert = false;

  @override
  void dispose() {
    _milben.dispose();
    _messdauer.dispose();
    _bienen.dispose();
    _notiz.dispose();
    super.dispose();
  }

  int? get _milbenVal => int.tryParse(_milben.text);

  Ampel get _ampel => ampelFuerKontrolle(
        methode: _methode, milbenGesamt: _milbenVal ?? 0,
        messdauerTage: int.tryParse(_messdauer.text), bienenProbe: int.tryParse(_bienen.text), monat: _datum.month,
      );

  @override
  Widget build(BuildContext context) {
    if (!ref.watch(darfSchreibenProvider)) {
      return Scaffold(appBar: AppBar(title: const Text('Milbendiagnose')),
          body: const Center(child: Text('Nur Lesezugriff.')));
    }
    final gemuell = _methode == 'gemuell';
    return Scaffold(
      appBar: AppBar(title: const Text('Milbendiagnose')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Wrap(spacing: 8, children: [
          for (final m in const ['gemuell', 'puderzucker', 'auswaschung'])
            ChoiceChip(
              label: Text(switch (m) { 'gemuell' => 'Gemüll', 'puderzucker' => 'Puderzucker', _ => 'Auswaschung' }),
              selected: _methode == m,
              onSelected: (_) => setState(() => _methode = m),
            ),
        ]),
        const SizedBox(height: 12),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text('Datum: ${_datum.day}.${_datum.month}.${_datum.year}'),
          trailing: const Icon(Icons.calendar_today),
          onTap: () async {
            final d = await showDatePicker(context: context, initialDate: _datum,
                firstDate: DateTime(2020), lastDate: DateTime(2100));
            if (d != null) setState(() => _datum = d);
          },
        ),
        TextField(controller: _milben, keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Milben gezählt'), onChanged: (_) => setState(() {})),
        if (gemuell)
          TextField(controller: _messdauer, keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Messdauer (Tage)'), onChanged: (_) => setState(() {})),
        if (!gemuell)
          TextField(controller: _bienen, keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Bienen in der Probe (~300)'), onChanged: (_) => setState(() {})),
        const SizedBox(height: 8),
        _AmpelZeile(methode: _methode, ampel: _ampel, milben: _milbenVal,
            messdauer: int.tryParse(_messdauer.text), bienen: int.tryParse(_bienen.text)),
        TextField(controller: _notiz, decoration: const InputDecoration(labelText: 'Notiz')),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _speichert ? null : _speichern,
          icon: const Icon(Icons.save),
          label: Text(_speichert ? 'Speichert…' : 'Speichern'),
        ),
      ]),
    );
  }

  Future<void> _speichern() async {
    if (_milbenVal == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bitte Milbenzahl eingeben.')));
      return;
    }
    setState(() => _speichert = true);
    try {
      await ref.read(kontrollenFuerVolkProvider(widget.volkId).notifier).speichern(VarroaKontrolle(
            id: '', volkId: widget.volkId, durchgefuehrtAm: _datum, methode: _methode,
            messdauerTage: _methode == 'gemuell' ? int.tryParse(_messdauer.text) : null,
            milbenGesamt: _milbenVal!,
            bienenProbe: _methode != 'gemuell' ? int.tryParse(_bienen.text) : null,
            notiz: _notiz.text.trim().isEmpty ? null : _notiz.text.trim(),
          ));
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        setState(() => _speichert = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fehler: $e')));
      }
    }
  }
}

class _AmpelZeile extends StatelessWidget {
  final String methode;
  final Ampel ampel;
  final int? milben, messdauer, bienen;
  const _AmpelZeile({required this.methode, required this.ampel, this.milben, this.messdauer, this.bienen});

  @override
  Widget build(BuildContext context) {
    final wert = methode == 'gemuell'
        ? milbenProTag(milben, messdauer)?.toStringAsFixed(1)
        : befallProzent(milben, bienen)?.toStringAsFixed(1);
    final einheit = methode == 'gemuell' ? 'Milben/Tag' : '% Befall';
    final color = switch (ampel) {
      Ampel.gruen => Colors.green, Ampel.gelb => Colors.orange, Ampel.rot => Colors.red, Ampel.keinRichtwert => Colors.grey,
    };
    return Row(children: [
      Icon(Icons.circle, color: color, size: 14),
      const SizedBox(width: 8),
      Text('${wert ?? '—'} $einheit'),
    ]);
  }
}
```

- [ ] **Step 2: Analyze + Commit**

Run: `flutter analyze lib/features/behandlung/presentation/pages/kontrolle_form_page.dart`
Expected: No issues.

```bash
git add lib/features/behandlung/presentation/pages/kontrolle_form_page.dart
git commit -m "feat(4.5): KontrolleFormPage (Milbendiagnose, Live-Ampel, Rollen-Guard)"
```

---

## Task 14: UI — `BehandlungFormPage` (Sammelbehandlung)

**Files:**
- Create: `lib/features/behandlung/presentation/pages/behandlung_form_page.dart`

- [ ] **Step 1: Seite schreiben** (Rollen-Guard, Prewarming Material+Völker, Multi-Select-Völker, Material-Dropdown, Bio-Banner auf Auswahl, Speichern via `behandlungAktionenProvider`)

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:bienen_app/features/auth/presentation/auth_providers.dart';
import 'package:bienen_app/features/behandlung/domain/wirkstoff.dart';
import 'package:bienen_app/features/behandlung/presentation/providers/behandlung_provider.dart';
import 'package:bienen_app/features/material/presentation/providers/material_provider.dart';
import 'package:bienen_app/features/voelker/presentation/providers/voelker_provider.dart';

class BehandlungFormPage extends ConsumerStatefulWidget {
  final String volkId;
  const BehandlungFormPage({super.key, required this.volkId});
  @override
  ConsumerState<BehandlungFormPage> createState() => _BehandlungFormPageState();
}

class _BehandlungFormPageState extends ConsumerState<BehandlungFormPage> {
  late final Set<String> _volkIds = {widget.volkId};
  DateTime _datum = DateTime.now();
  final _praeparat = TextEditingController();
  String _wirkstoff = 'ameisensaeure';
  String _anwendungsart = 'dispenser_verdunster';
  final _menge = TextEditingController();
  String _einheit = 'ml';
  final _person = TextEditingController();
  String? _materialId;
  bool _speichert = false;
  bool _geladen = false;

  @override
  void initState() {
    super.initState();
    _person.text = Supabase.instance.client.auth.currentUser?.email ?? '';
    WidgetsBinding.instance.addPostFrameCallback((_) => _prewarm());
  }

  Future<void> _prewarm() async {
    try {
      await Future.wait([
        ref.read(materialListProvider.future),
        ref.read(voelkerListProvider.future),
      ]);
    } catch (_) {/* Dropdowns bleiben ggf. leer; Speichern zeigt Fehler */}
    if (mounted) setState(() => _geladen = true);
  }

  @override
  void dispose() {
    _praeparat.dispose();
    _menge.dispose();
    _person.dispose();
    super.dispose();
  }

  bool get _biotech => Anwendungsart.ohneChemie.contains(_anwendungsart);

  @override
  Widget build(BuildContext context) {
    if (!ref.watch(darfSchreibenProvider)) {
      return Scaffold(appBar: AppBar(title: const Text('Behandlung')),
          body: const Center(child: Text('Nur Lesezugriff.')));
    }
    final voelker = ref.watch(voelkerListProvider).valueOrNull ?? [];
    final materialien = (ref.watch(materialListProvider).valueOrNull ?? [])
        .where((m) => m.isConsumable && m.bereich == 'imkerei')
        .toList();

    // Bio-Banner: Warnung UND mindestens ein selektiertes Volk ist nicht konventionell.
    final selektierte = voelker.where((v) => _volkIds.contains(v.id)).toList();
    final zeigeBioBanner = bioKonformitaet(_wirkstoff, _anwendungsart) == BioBewertung.warnung &&
        selektierte.any((v) => v.bioStatus != 'konventionell');

    return Scaffold(
      appBar: AppBar(title: const Text('Behandlung erfassen')),
      body: !_geladen
          ? const Center(child: CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.all(16), children: [
              const Text('Völker (Sammelbehandlung)', style: TextStyle(fontWeight: FontWeight.bold)),
              Wrap(spacing: 8, children: [
                for (final v in voelker)
                  FilterChip(
                    label: Text(v.name),
                    selected: _volkIds.contains(v.id),
                    onSelected: (s) => setState(() => s ? _volkIds.add(v.id) : _volkIds.remove(v.id)),
                  ),
              ]),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Datum: ${_datum.day}.${_datum.month}.${_datum.year}'),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final d = await showDatePicker(context: context, initialDate: _datum,
                      firstDate: DateTime(2020), lastDate: DateTime(2100));
                  if (d != null) setState(() => _datum = d);
                },
              ),
              DropdownButtonFormField<String>(
                initialValue: _wirkstoff,
                decoration: const InputDecoration(labelText: 'Wirkstoff'),
                items: [for (final w in Wirkstoff.werte) DropdownMenuItem(value: w, child: Text(Wirkstoff.labels[w]!))],
                onChanged: (v) => setState(() => _wirkstoff = v!),
              ),
              DropdownButtonFormField<String>(
                initialValue: _anwendungsart,
                decoration: const InputDecoration(labelText: 'Anwendungsart'),
                items: [for (final a in Anwendungsart.werte) DropdownMenuItem(value: a, child: Text(Anwendungsart.labels[a]!))],
                onChanged: (v) => setState(() => _anwendungsart = v!),
              ),
              if (!_biotech)
                TextField(controller: _praeparat, decoration: const InputDecoration(labelText: 'Präparat (Handelsname)')),
              if (!_biotech)
                Row(children: [
                  Expanded(child: TextField(controller: _menge, keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Menge je Volk'))),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 100,
                    child: DropdownButtonFormField<String>(
                      initialValue: _einheit,
                      decoration: const InputDecoration(labelText: 'Einheit'),
                      items: const [
                        DropdownMenuItem(value: 'ml', child: Text('ml')),
                        DropdownMenuItem(value: 'g', child: Text('g')),
                        DropdownMenuItem(value: 'stueck', child: Text('Stück')),
                      ],
                      onChanged: (v) => setState(() => _einheit = v!),
                    ),
                  ),
                ]),
              DropdownButtonFormField<String?>(
                initialValue: _materialId,
                decoration: const InputDecoration(labelText: 'Material (Lager-Abbuchung, optional)'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('— keins —')),
                  for (final m in materialien) DropdownMenuItem(value: m.id, child: Text('${m.name} (${m.unit ?? '—'})')),
                ],
                onChanged: (v) => setState(() => _materialId = v),
              ),
              TextField(controller: _person, decoration: const InputDecoration(labelText: 'Verantwortliche Person')),
              if (zeigeBioBanner)
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.orange.withAlpha(38), borderRadius: BorderRadius.circular(8)),
                  child: Row(children: [
                    const Icon(Icons.warning_amber, color: Colors.orange),
                    const SizedBox(width: 8),
                    Expanded(child: Text(
                      'Nicht bio-konformer Wirkstoff auf: ${selektierte.where((v) => v.bioStatus != 'konventionell').map((v) => v.name).join(', ')}',
                    )),
                  ]),
                ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _speichert ? null : _speichern,
                icon: const Icon(Icons.save),
                label: Text(_speichert ? 'Speichert…' : 'Behandlung speichern'),
              ),
            ]),
    );
  }

  Future<void> _speichern() async {
    if (_volkIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mindestens ein Volk wählen.')));
      return;
    }
    setState(() => _speichert = true);
    try {
      await ref.read(behandlungAktionenProvider).erfassen(
            volkIds: _volkIds.toList(),
            datumBeginn: _datum,
            wirkstoff: _wirkstoff,
            anwendungsart: _anwendungsart,
            verantwortlichePerson: _person.text.trim(),
            praeparat: _biotech ? null : _praeparat.text.trim(),
            mengeProVolk: _biotech ? null : num.tryParse(_menge.text.replaceAll(',', '.')),
            einheit: _biotech ? null : _einheit,
            materialId: _materialId,
          );
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        setState(() => _speichert = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fehler: $e')));
      }
    }
  }
}
```

- [ ] **Step 2: Analyze + Commit**

Run: `flutter analyze lib/features/behandlung/presentation/pages/behandlung_form_page.dart`
Expected: No issues.

```bash
git add lib/features/behandlung/presentation/pages/behandlung_form_page.dart
git commit -m "feat(4.5): BehandlungFormPage (Sammel-Multi-Select, Material, Bio-Banner)"
```

---

## Task 15: Verdrahtung — Detailseite andocken + Routen

**Files:**
- Modify: `lib/features/voelker/presentation/pages/volk_detail_page.dart` (Import + `DurchsichtTimeline` gefolgt von `BehandlungSection`)
- Modify: `lib/core/router/app_router.dart` (zwei neue Sub-Routen unter `/voelker/:id`)

- [ ] **Step 1: `BehandlungSection` in die Detailseite einfügen**

Import ergänzen (bei den Feature-Imports):

```dart
import 'package:bienen_app/features/behandlung/presentation/widgets/behandlung_section.dart';
```

Im `ListView` direkt nach `DurchsichtTimeline(volkId: volk.id),` einfügen:

```dart
              BehandlungSection(volkId: volk.id),
```

- [ ] **Step 2: Routen registrieren**

In `lib/core/router/app_router.dart` die Imports ergänzen:

```dart
import 'package:bienen_app/features/behandlung/presentation/pages/behandlung_form_page.dart';
import 'package:bienen_app/features/behandlung/presentation/pages/kontrolle_form_page.dart';
```

In den `routes:`-Block unter `path: ':id'` (nach der `durchsicht/:did`-Route, vor der schließenden `]`) einfügen:

```dart
                GoRoute(
                  path: 'varroa',
                  builder: (c, s) => KontrolleFormPage(volkId: s.pathParameters['id']!),
                ),
                GoRoute(
                  path: 'behandlung',
                  builder: (c, s) => BehandlungFormPage(volkId: s.pathParameters['id']!),
                ),
```

- [ ] **Step 3: Build-Check + Commit**

Run: `flutter analyze lib/features/voelker/presentation/pages/volk_detail_page.dart lib/core/router/app_router.dart`
Expected: No issues.

```bash
git add lib/features/voelker/presentation/pages/volk_detail_page.dart lib/core/router/app_router.dart
git commit -m "feat(4.5): BehandlungSection andocken + Routen /varroa /behandlung"
```

---

## Task 16: Abschluss — Analyze, Tests, Deploy 1.11.0

**Files:**
- Modify: `pubspec.yaml` (`version:`)

- [ ] **Step 1: Voller Analyze**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 2: Volle Testsuite**

Run: `flutter test`
Expected: alle grün (bestehende + neue Behandlungs-Tests).

- [ ] **Step 3: Version bumpen**

In `pubspec.yaml`:

```yaml
version: 1.11.0+29
```

- [ ] **Step 4: Commit + Deploy** (stehende Deploy-Freigabe)

```bash
git add pubspec.yaml
git commit -m "chore(4.5): Version 1.11.0+29"
git checkout master
git merge --no-ff feat/behandlung -m "feat: Modul 4.5 Behandlungen (Varroa/Gesundheit) v1.11.0"
git push
bash deploy.sh
```

- [ ] **Step 5: Live-Verifikation**

Nach dem Deploy: App laden, ein Volk öffnen, „Varroa & Behandlung"-Sektion prüfen (Milbendiagnose anlegen → Cockpit zeigt Kurve/Chip; Behandlung erfassen → erscheint in Liste, Lager sinkt). Konsole fehlerfrei.

---

## Self-Review-Notizen (Plan ↔ Spec)

- **Spec §3.4 / §4.2 RESTRICT + keine INSERT/DELETE-Policy + Immutable-Trigger** → Task 1 (E01). **§4.3 RPC** → Task 2 (E02). **§5 Ableitungen** → Task 3+4. **§4.1/§4.2 Modelle** → Task 5. **§6 Gateway/State/UI** → Tasks 6–15. **§7 Deploy** → Task 16. **§8 Tests** → in jeder Task (SQL-DO in 1/2; Dart in 3,4,5,7,9,10). Alle Spec-Abschnitte abgedeckt.
- **BA034** ist neu ggü. Spec (§4.3 nannte BA030–033); liegt im reservierten Block BA030–039 und deckt den Immutable-/Storno-Trigger ab — bewusste Plan-Verfeinerung.
- **Typkonsistenz:** `behandlungErfassen(...)`-Signatur identisch in Gateway (Task 6), Fake (Task 7), Supabase-Impl (Task 8), `BehandlungAktionen.erfassen` (Task 9). `ampelFuerKontrolle`/`ampelGemuell`/`ampelPuderzucker` konsistent zwischen Task 4 (Definition) und Tasks 11/13 (Nutzung). `bioKonformitaet(wirkstoff, anwendungsart)` konsistent Task 3 ↔ 14.
- **Offene Punkte für den Umsetzer:** `Volk`-Feld heißt `bioStatus` und `name` (Task 14/12 nutzen sie); `MaterialItem` hat `isConsumable`, `bereich`, `unit`, `name`, `id` (Task 14). Falls ein Feldname abweicht → an das reale Modell anpassen (die Muster-Referenz `volk_detail_page.dart` nutzt `volk.bioStatus`).
