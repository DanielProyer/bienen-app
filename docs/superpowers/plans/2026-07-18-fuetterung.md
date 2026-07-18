# Fütterung — Modul 4.6 — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fütterungs-Log (Bio-Nachweis) je Volk + Winterfutter-Ziel-Fortschrittsbalken + atomare Lager-Abbuchung, angedockt an die Volk-Detailseite.

**Architecture:** Zwilling von 4.5 auf Bio-Nachweis-Niveau: `fuetterungen`-Tabelle (Soft-Delete/Storno, **kein** Immutable-Trigger, aber volk-FK `RESTRICT` + keine INSERT/DELETE-Policy) + RPC `fuetterung_erfassen` (distinct/ROW_COUNT/BA040-042). `betriebs_einstellungen` bekommt `winterfutter_ziel_kg`. Flutter-Feature `lib/features/fuetterung/` nach dem 4.5-Muster.

**Tech Stack:** Supabase (Postgres 15, RLS, security definer), Flutter Web, Riverpod AsyncNotifier (ohne Codegen), go_router (Hash).

**Grundlage:** Spec v2 `docs/superpowers/specs/2026-07-18-fuetterung-design.md` (13 Review-Funde eingearbeitet, u.a. M1 RESTRICT, M2 Saison-Anker, M3 menge_pro_volk_kg). Fachwissen: `../imkerei/02_Recherche/18` (Bio), `02` (alpin).

**Errcode-Registry (Block 4.6 = BA040–049):** BA040 Pflichtfeld/Enum · BA041 Völker · BA042 Material-Tenancy. *(Kein BA034-Äquivalent — 4.6 hat bewusst keinen Immutable-Trigger.)*

**Muster-Referenzen (der Zwilling 4.5, frisch live):** `supabase/migrations/E01_behandlungen.sql`/`E02_rpc_behandlung_erfassen.sql`, `lib/features/behandlung/` (domain/data/presentation komplett analog). `lib/features/voelker/domain/betriebs_einstellungen.dart` (Modell erweitern), `lib/features/voelker/presentation/pages/volk_detail_page.dart` (Andockpunkt), `lib/features/auth/presentation/auth_providers.dart:72` (`_datenNeuLaden`, `betriebsEinstellungenProvider` steht schon drin).

> **Migrationen F01/F02 wendet der Controller (nicht ein Subagent) via `apply_migration` auf die Produktion an** — nach erneuter Freigabe für die 4.6-DB. Dart-Tasks (3+) subagent-getrieben.

---

## Dateistruktur

| Datei | Verantwortung |
|---|---|
| `supabase/migrations/F01_fuetterungen.sql` | `betriebs_einstellungen.winterfutter_ziel_kg` + `fuetterungen`-Tabelle |
| `supabase/migrations/F02_rpc_fuetterung_erfassen.sql` | RPC `fuetterung_erfassen` + Grants |
| `lib/features/fuetterung/domain/futterart.dart` | Futterart/Zweck-Enums (Labels) |
| `lib/features/fuetterung/domain/winterfutter.dart` | reine Funktionen `winterfutterKg` (Saison-Anker) / `winterfutterProzent` + Konstante |
| `lib/features/fuetterung/domain/fuetterung.dart` | Modell `Fuetterung` |
| `lib/features/fuetterung/domain/fuetterung_gateway.dart` | abstraktes Gateway + `FuetterungFehler` |
| `lib/features/fuetterung/data/fake_fuetterung_gateway.dart` | In-Memory-Fake (distinct-Insert, Lager-Sim, BA040-042) |
| `lib/features/fuetterung/data/supabase_fuetterung_gateway.dart` | Supabase-Impl (RPC + CRUD) |
| `lib/features/fuetterung/presentation/providers/fuetterung_provider.dart` | Family-Provider + `FuetterungAktionen` |
| `lib/features/fuetterung/presentation/widgets/winterfutter_balken.dart` | Fortschrittsbalken |
| `lib/features/fuetterung/presentation/widgets/fuetterung_section.dart` | Andock-Card |
| `lib/features/fuetterung/presentation/pages/fuetterung_form_page.dart` | Erfassungs-Formular (Sammelfütterung) |
| `lib/features/voelker/domain/betriebs_einstellungen.dart` | (modify) `winterfutterZielKg` |
| `lib/features/voelker/presentation/pages/volk_detail_page.dart` | (modify) `FuetterungSection` andocken |
| `lib/core/router/app_router.dart` | (modify) Route `fuetterung` |
| `lib/features/auth/presentation/auth_providers.dart` | (modify) neuen Family-Provider in `_datenNeuLaden` |
| `pubspec.yaml` | (modify) `version: 1.12.0+30` |

---

## Task 1: Migration F01 — Tabelle + Ziel-Spalte (Controller-Task, Produktion)

**Files:**
- Create: `supabase/migrations/F01_fuetterungen.sql`

- [ ] **Step 1: Datei schreiben**

```sql
-- F01_fuetterungen.sql | Fütterungs-Log (Bio-Nachweis) + Winterfutter-Ziel.
-- fuetterungen: Soft-Delete/Storno (KEIN Immutable-Trigger, anders als 4.5), aber volk-FK RESTRICT
--   (M1: schützt die Audit-Spur auch übers Elternvolk) + keine INSERT/DELETE-Policy (Insert nur via RPC F02).
-- betriebs_einstellungen: winterfutter_ziel_kg (F4-Parameter, Default 22, CHECK > 0).
-- Errcodes BA040-049 = Modul 4.6.

alter table public.betriebs_einstellungen
  add column if not exists winterfutter_ziel_kg numeric not null default 22
    check (winterfutter_ziel_kg > 0);

create table if not exists public.fuetterungen (
  id uuid primary key default gen_random_uuid(),
  volk_id uuid not null,
  durchgefuehrt_am date not null default current_date,
  zweck text not null check (zweck in ('auffuetterung','reizfuetterung','notfuetterung')),
  futterart text not null
    check (futterart in ('zuckersirup','zuckerwasser','futterteig','futterwaben','honig','sonstige')),
  bio_zertifiziert boolean not null default false,
  menge_pro_volk_kg numeric not null check (menge_pro_volk_kg > 0),
  material_id uuid,
  verantwortliche_person text,
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
  constraint fuetterungen_volk_fk
    foreign key (betrieb_id, volk_id) references public.voelker (betrieb_id, id) on delete restrict,
  constraint fuetterungen_material_fk
    foreign key (betrieb_id, material_id) references public.materials (betrieb_id, id)
    on delete set null (material_id),
  constraint fuetterungen_storno_chk
    check (is_storniert = false or (storno_grund is not null and storno_am is not null)),
  constraint fuetterungen_storno_datum_chk
    check (storno_am is null or storno_am >= durchgefuehrt_am)
);
alter table public.fuetterungen enable row level security;
revoke all on public.fuetterungen from anon, public;
-- KEIN insert (nur via RPC F02), KEIN delete (Soft-Delete):
grant select, update on public.fuetterungen to authenticated;
create index if not exists idx_fuetterungen_volk_datum
  on public.fuetterungen (betrieb_id, volk_id, durchgefuehrt_am desc);
create index if not exists idx_fuetterungen_material
  on public.fuetterungen (betrieb_id, material_id);

drop trigger if exists trg_fuetterungen_actor on public.fuetterungen;
create trigger trg_fuetterungen_actor before insert or update
  on public.fuetterungen for each row execute function private.set_row_actor();
drop trigger if exists trg_fuetterungen_updated on public.fuetterungen;
create trigger trg_fuetterungen_updated before update
  on public.fuetterungen for each row execute function private.set_updated_at();

drop policy if exists fuetterungen_sel_member on public.fuetterungen;
create policy fuetterungen_sel_member on public.fuetterungen
  for select to authenticated using (betrieb_id in (select private.meine_betrieb_ids()));
drop policy if exists fuetterungen_upd_writer on public.fuetterungen;
create policy fuetterungen_upd_writer on public.fuetterungen
  for update to authenticated using (private.kann_schreiben(betrieb_id))
  with check (private.kann_schreiben(betrieb_id));
-- BEWUSST keine fuetterungen_ins_* und keine fuetterungen_del_* Policy.
```

- [ ] **Step 2: Migration anwenden**

Controller ruft `apply_migration` mit `name: "F01_fuetterungen"` und obigem SQL auf Projekt `dcdcohktxbhdxnxjvcyp`. Erwartet: Erfolg.

- [ ] **Step 3: Rollback-DO-Test — RESTRICT, CHECKs, Ziel-Default**

Controller führt via `execute_sql` aus:

```sql
do $$
declare v_b uuid := '1c84d5dd-d22e-4bce-bba9-5e861b2f4aa4'; v_volk uuid; v_f uuid;
begin
  insert into public.voelker (betrieb_id, name, status) values (v_b, 'F01-TEST-VOLK', 'aktiv') returning id into v_volk;

  insert into public.fuetterungen (betrieb_id, volk_id, durchgefuehrt_am, zweck, futterart, bio_zertifiziert, menge_pro_volk_kg)
    values (v_b, v_volk, current_date, 'auffuetterung', 'zuckersirup', true, 5) returning id into v_f;

  -- RESTRICT: Volk mit Log darf nicht hart geloescht werden
  begin
    delete from public.voelker where id = v_volk;
    raise exception 'FEHLER: voelker-Delete trotz Log erlaubt';
  exception when foreign_key_violation then null;
  end;

  -- CHECK: menge_pro_volk_kg <= 0
  begin
    insert into public.fuetterungen (betrieb_id, volk_id, durchgefuehrt_am, zweck, futterart, menge_pro_volk_kg)
      values (v_b, v_volk, current_date, 'auffuetterung', 'zuckersirup', 0);
    raise exception 'FEHLER: menge <= 0 erlaubt';
  exception when check_violation then null;
  end;

  -- CHECK: ungueltiges zweck-Enum
  begin
    insert into public.fuetterungen (betrieb_id, volk_id, durchgefuehrt_am, zweck, futterart, menge_pro_volk_kg)
      values (v_b, v_volk, current_date, 'quatsch', 'zuckersirup', 5);
    raise exception 'FEHLER: ungueltiges zweck erlaubt';
  exception when check_violation then null;
  end;

  -- CHECK: storno_am < durchgefuehrt_am
  begin
    update public.fuetterungen set is_storniert = true, storno_grund = 'x', storno_am = current_date - 1 where id = v_f;
    raise exception 'FEHLER: storno_am vor durchgefuehrt_am erlaubt';
  exception when check_violation then null;
  end;

  -- Storno korrekt
  update public.fuetterungen set is_storniert = true, storno_grund = 'Testfehler', storno_am = current_date where id = v_f;

  -- Ziel-Default 22 vorhanden
  if (select winterfutter_ziel_kg from public.betriebs_einstellungen where betrieb_id = v_b) is null then
    raise exception 'FEHLER: winterfutter_ziel_kg fehlt';
  end if;

  raise exception 'ROLLBACK_OK';
exception when others then
  if sqlerrm = 'ROLLBACK_OK' then return; end if;
  raise;
end $$;
```
Erwartet: kein Fehler.

- [ ] **Step 4: Advisor-Gate**

`get_advisors(type: "security")` → 0 neue Findings ggü. dem Stand vor F01 (keine neue Definer-Funktion in F01; die FK-Indizes verhindern `unindexed_foreign_keys`).

- [ ] **Step 5: Commit**

```bash
git add supabase/migrations/F01_fuetterungen.sql
git commit -m "feat(4.6): F01 fuetterungen (Bio-Log, volk-FK RESTRICT, Soft-Delete) + winterfutter_ziel_kg"
```

---

## Task 2: Migration F02 — RPC `fuetterung_erfassen` (Controller-Task, Produktion)

**Files:**
- Create: `supabase/migrations/F02_rpc_fuetterung_erfassen.sql`

- [ ] **Step 1: Datei schreiben**

```sql
-- F02_rpc_fuetterung_erfassen.sql | Einziger Schreibpfad in den Fütterungs-Log.
-- distinct Voelker -> je 1 Zeile; Lager-Abbuchung menge_pro_volk_kg × ROW_COUNT; betrieb_id explizit.
-- BA040 Pflichtfeld/Enum (Enums IN der RPC geprueft -> kein roher 23514), BA041 Voelker, BA042 Material.

create or replace function public.fuetterung_erfassen(
  p_volk_ids uuid[],
  p_durchgefuehrt_am date,
  p_zweck text,
  p_futterart text,
  p_menge_pro_volk_kg numeric,
  p_bio_zertifiziert boolean,
  p_material_id uuid default null,
  p_verantwortliche_person text default null,
  p_notiz text default null
) returns int
  language plpgsql security definer set search_path = '' as $$
declare
  v_betrieb uuid; v_betriebe uuid[]; v_found int; v_n int;
begin
  if p_volk_ids is null or cardinality(p_volk_ids) = 0 then
    raise exception 'Keine Voelker angegeben' using errcode='BA041';
  end if;

  select array_agg(distinct betrieb_id), count(distinct id) into v_betriebe, v_found
    from public.voelker where id = any(p_volk_ids);
  if v_found is null
     or v_found <> cardinality(array(select distinct unnest(p_volk_ids)))
     or coalesce(array_length(v_betriebe,1),0) <> 1 then
    raise exception 'Volk nicht gefunden oder gehoert nicht zu deinem Betrieb' using errcode='BA041';
  end if;
  v_betrieb := v_betriebe[1];
  if not private.kann_schreiben(v_betrieb) then
    raise exception 'Keine Schreibberechtigung fuer diesen Betrieb' using errcode='BA041';
  end if;

  if p_durchgefuehrt_am is null
     or p_zweck not in ('auffuetterung','reizfuetterung','notfuetterung')
     or p_futterart not in ('zuckersirup','zuckerwasser','futterteig','futterwaben','honig','sonstige')
     or p_menge_pro_volk_kg is null or p_menge_pro_volk_kg <= 0 then
    raise exception 'Pflichtfeld fehlt oder ungueltig (Datum, Zweck, Futterart, Menge)' using errcode='BA040';
  end if;

  if p_material_id is not null
     and not exists (select 1 from public.materials where id = p_material_id and betrieb_id = v_betrieb) then
    raise exception 'Material gehoert nicht zu deinem Betrieb' using errcode='BA042';
  end if;

  insert into public.fuetterungen (
    betrieb_id, volk_id, durchgefuehrt_am, zweck, futterart, bio_zertifiziert,
    menge_pro_volk_kg, material_id, verantwortliche_person, notiz)
  select v_betrieb, x.volk_id, p_durchgefuehrt_am, p_zweck, p_futterart, p_bio_zertifiziert,
    p_menge_pro_volk_kg, p_material_id, p_verantwortliche_person, p_notiz
  from (select distinct unnest(p_volk_ids) as volk_id) x;

  get diagnostics v_n = row_count;

  if p_material_id is not null then
    update public.materials set stock_qty = stock_qty - coalesce(p_menge_pro_volk_kg, 0) * v_n
      where id = p_material_id and betrieb_id = v_betrieb;
  end if;

  return v_n;
end; $$;

revoke execute on function public.fuetterung_erfassen(
  uuid[], date, text, text, numeric, boolean, uuid, text, text) from anon, public;
grant execute on function public.fuetterung_erfassen(
  uuid[], date, text, text, numeric, boolean, uuid, text, text) to authenticated;
```

- [ ] **Step 2: Migration anwenden**

`apply_migration` mit `name: "F02_rpc_fuetterung_erfassen"`. Erwartet: Erfolg.

- [ ] **Step 3: Rollback-DO-Test — distinct, Abbuchung, BA040-042, Enum**

```sql
do $$
declare v_b uuid := '1c84d5dd-d22e-4bce-bba9-5e861b2f4aa4';
        v_volk uuid; v_mat uuid; v_n int; v_stock numeric;
begin
  perform set_config('app.current_user_id', '57255790-4f56-4c76-bc1d-03f65967e032', true);
  insert into public.voelker (betrieb_id, name, status) values (v_b, 'F02-TEST-VOLK', 'aktiv') returning id into v_volk;
  insert into public.materials (betrieb_id, name, category, unit, is_consumable, stock_qty, status, bereich)
    values (v_b, 'F02-TEST-ZUCKER', 'Fuetterung', 'kg', true, 100, 'gekauft', 'imkerei') returning id into v_mat;

  -- Duplikat [v,v] -> 1 Zeile, einfache Abbuchung (5 kg)
  v_n := public.fuetterung_erfassen(
    p_volk_ids := array[v_volk, v_volk], p_durchgefuehrt_am := current_date,
    p_zweck := 'auffuetterung', p_futterart := 'zuckersirup', p_menge_pro_volk_kg := 5,
    p_bio_zertifiziert := true, p_material_id := v_mat);
  if v_n <> 1 then raise exception 'FEHLER: Duplikat erzeugte % Zeilen', v_n; end if;
  select stock_qty into v_stock from public.materials where id = v_mat;
  if v_stock <> 95 then raise exception 'FEHLER: Abbuchung falsch (%, erwartet 95)', v_stock; end if;
  if (select betrieb_id from public.fuetterungen where volk_id = v_volk limit 1) <> v_b then
    raise exception 'FEHLER: betrieb_id nicht aus dem Volk abgeleitet';
  end if;

  -- BA040: ungueltiges zweck (RPC faengt Enum ab -> BA040, nicht roher 23514)
  begin
    perform public.fuetterung_erfassen(p_volk_ids := array[v_volk], p_durchgefuehrt_am := current_date,
      p_zweck := 'quatsch', p_futterart := 'zuckersirup', p_menge_pro_volk_kg := 5, p_bio_zertifiziert := true);
    raise exception 'FEHLER: BA040 (Enum) nicht ausgeloest';
  exception when sqlstate 'BA040' then null; end;

  -- BA040: menge <= 0
  begin
    perform public.fuetterung_erfassen(p_volk_ids := array[v_volk], p_durchgefuehrt_am := current_date,
      p_zweck := 'auffuetterung', p_futterart := 'zuckersirup', p_menge_pro_volk_kg := 0, p_bio_zertifiziert := true);
    raise exception 'FEHLER: BA040 (menge) nicht ausgeloest';
  exception when sqlstate 'BA040' then null; end;

  -- BA041: leeres Array
  begin
    perform public.fuetterung_erfassen(p_volk_ids := array[]::uuid[], p_durchgefuehrt_am := current_date,
      p_zweck := 'auffuetterung', p_futterart := 'zuckersirup', p_menge_pro_volk_kg := 5, p_bio_zertifiziert := true);
    raise exception 'FEHLER: BA041 nicht ausgeloest';
  exception when sqlstate 'BA041' then null; end;

  -- BA042: fremdes Material
  begin
    perform public.fuetterung_erfassen(p_volk_ids := array[v_volk], p_durchgefuehrt_am := current_date,
      p_zweck := 'auffuetterung', p_futterart := 'zuckersirup', p_menge_pro_volk_kg := 5, p_bio_zertifiziert := true,
      p_material_id := gen_random_uuid());
    raise exception 'FEHLER: BA042 nicht ausgeloest';
  exception when sqlstate 'BA042' then null; end;

  raise exception 'ROLLBACK_OK';
exception when others then
  if sqlerrm = 'ROLLBACK_OK' then return; end if;
  raise;
end $$;
```
Erwartet: kein Fehler.

- [ ] **Step 4: Advisor-Gate**

`get_advisors(type: "security")` → genau **1 erwartete neue 0029** (RPC `fuetterung_erfassen`, security definer callable by authenticated — gewollt, wie `behandlung_erfassen`), sonst 0 neue.

- [ ] **Step 5: Commit**

```bash
git add supabase/migrations/F02_rpc_fuetterung_erfassen.sql
git commit -m "feat(4.6): F02 RPC fuetterung_erfassen (distinct/ROW_COUNT, BA040-042)"
```

---

## Task 3: Domain — `futterart.dart` (Enums)

**Files:**
- Create: `lib/features/fuetterung/domain/futterart.dart`
- Test: `test/features/fuetterung/futterart_test.dart`

- [ ] **Step 1: Test schreiben**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:bienen_app/features/fuetterung/domain/futterart.dart';

void main() {
  test('Futterart-Werte haben alle ein Label', () {
    for (final w in Futterart.werte) {
      expect(Futterart.labels[w], isNotNull, reason: w);
    }
    expect(Futterart.werte, contains('honig'));
    expect(Futterart.werte, isNot(contains('eigener_honig')));
  });
  test('Zweck-Werte haben alle ein Label', () {
    for (final w in Zweck.werte) {
      expect(Zweck.labels[w], isNotNull, reason: w);
    }
    expect(Zweck.werte, containsAll(['auffuetterung', 'reizfuetterung', 'notfuetterung']));
  });
}
```

- [ ] **Step 2: Test ausführen (rot)**

Run: `flutter test test/features/fuetterung/futterart_test.dart`
Expected: FAIL (URI fehlt).

- [ ] **Step 3: Implementierung schreiben**

```dart
/// Physische Futterform (DB-CHECK-Whitelist). Bio-Status separat via `bio_zertifiziert`.
class Futterart {
  static const werte = <String>[
    'zuckersirup', 'zuckerwasser', 'futterteig', 'futterwaben', 'honig', 'sonstige',
  ];
  static const labels = <String, String>{
    'zuckersirup': 'Zuckersirup',
    'zuckerwasser': 'Zuckerwasser (Sirup selbst)',
    'futterteig': 'Futterteig',
    'futterwaben': 'Futterwaben',
    'honig': 'Honig',
    'sonstige': 'Sonstige',
  };
}

/// Fütterungszweck. Nur `auffuetterung` zählt fürs Winterfutter-Ziel.
class Zweck {
  static const werte = <String>['auffuetterung', 'reizfuetterung', 'notfuetterung'];
  static const labels = <String, String>{
    'auffuetterung': 'Auffütterung',
    'reizfuetterung': 'Reizfütterung',
    'notfuetterung': 'Notfütterung',
  };
}
```

- [ ] **Step 4: Test ausführen (grün) + Commit**

Run: `flutter test test/features/fuetterung/futterart_test.dart`
Expected: PASS (2 Tests).

```bash
git add lib/features/fuetterung/domain/futterart.dart test/features/fuetterung/futterart_test.dart
git commit -m "feat(4.6): Futterart/Zweck-Enums"
```

---

## Task 4: Domain — `winterfutter.dart` (Saison-Σ, reine Funktionen)

**Files:**
- Create: `lib/features/fuetterung/domain/winterfutter.dart`
- Test: `test/features/fuetterung/winterfutter_test.dart`

*(Hinweis: `winterfutter.dart` importiert das `Fuetterung`-Modell aus Task 5. Reihenfolge: Task 5 zuerst umsetzen ist zulässig — der Test hier referenziert `Fuetterung`. Falls dieser Task vor Task 5 läuft, zieht der Implementer das `Fuetterung`-Modell aus Task 5 vor.)*

- [ ] **Step 1: Test schreiben**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:bienen_app/features/fuetterung/domain/fuetterung.dart';
import 'package:bienen_app/features/fuetterung/domain/winterfutter.dart';

Fuetterung _f(String zweck, DateTime am, num kg, {bool storniert = false}) => Fuetterung(
      id: 'x', volkId: 'v1', durchgefuehrtAm: am, zweck: zweck, futterart: 'zuckersirup',
      bioZertifiziert: true, mengeProVolkKg: kg, isStorniert: storniert);

void main() {
  test('winterfutterKg summiert nur nicht-stornierte Auffütterung der Saison', () {
    final list = [
      _f('auffuetterung', DateTime(2026, 8, 1), 10),
      _f('auffuetterung', DateTime(2026, 9, 1), 8),
      _f('reizfuetterung', DateTime(2026, 8, 15), 1), // zaehlt nicht
      _f('notfuetterung', DateTime(2026, 8, 20), 2), // zaehlt nicht
      _f('auffuetterung', DateTime(2026, 8, 5), 5, storniert: true), // storniert
    ];
    // Stichtag im Herbst 2026 -> Saison ab 1.7.2026
    expect(winterfutterKg(list, stichtag: DateTime(2026, 9, 15)), 18.0);
  });

  test('Saison-Anker: im Januar zählt die Vorjahres-Herbst-Auffütterung noch (Balken != 0)', () {
    final list = [_f('auffuetterung', DateTime(2026, 9, 1), 12)];
    // Stichtag 15. Jan 2027, Monat < 7 -> Saisonstart 1.7.2026 -> Sept.-Eintrag zaehlt
    expect(winterfutterKg(list, stichtag: DateTime(2027, 1, 15)), 12.0);
  });

  test('vor dem Saisonstart liegende Auffütterung zählt nicht', () {
    final list = [_f('auffuetterung', DateTime(2026, 6, 30), 9)]; // vor 1.7.2026
    expect(winterfutterKg(list, stichtag: DateTime(2026, 9, 15)), 0.0);
  });

  test('winterfutterProzent null-/0-Ziel-sicher + Clamp', () {
    expect(winterfutterProzent(11, 22), closeTo(0.5, 0.001));
    expect(winterfutterProzent(30, 22), 1.0); // Clamp
    expect(winterfutterProzent(5, 0), 0.0);
  });
}
```

- [ ] **Step 2: Test ausführen (rot)**

Run: `flutter test test/features/fuetterung/winterfutter_test.dart`
Expected: FAIL (URIs fehlen).

- [ ] **Step 3: Implementierung schreiben**

```dart
import 'package:bienen_app/features/fuetterung/domain/fuetterung.dart';

/// Auffütter-Saison beginnt am 1. Juli (Nordhalbkugel-Fachdefault; F4 überschreibt später).
const kAuffuetterSaisonStartMonat = 7;

/// Σ Produktmasse (kg) der nicht-stornierten Auffütterungen der laufenden Saison.
/// Saison-Anker IN der Funktion gekapselt (M2): bei Monat < 7 startet die Saison im Vorjahr
/// (1.7.X–30.6.X+1), sonst würde der Balken von Januar bis Juni fälschlich auf 0 fallen.
/// Vergleich rein auf Datumsebene (kein UTC-Shift — durchgefuehrt_am ist ein PG `date`).
double winterfutterKg(List<Fuetterung> fuetterungen, {required DateTime stichtag}) {
  final saisonStartJahr =
      stichtag.month < kAuffuetterSaisonStartMonat ? stichtag.year - 1 : stichtag.year;
  final saisonStart = DateTime(saisonStartJahr, kAuffuetterSaisonStartMonat, 1);
  var summe = 0.0;
  for (final f in fuetterungen) {
    if (f.isStorniert || f.zweck != 'auffuetterung') continue;
    if (f.durchgefuehrtAm.isBefore(saisonStart)) continue;
    summe += f.mengeProVolkKg.toDouble();
  }
  return summe;
}

/// Fortschritt 0..1 (null-/0-Ziel-sicher, Clamp auf 1).
double winterfutterProzent(double kg, double zielKg) {
  if (zielKg <= 0) return 0;
  final p = kg / zielKg;
  return p > 1 ? 1 : p;
}
```

- [ ] **Step 4: Test ausführen (grün) + Commit**

Run: `flutter test test/features/fuetterung/winterfutter_test.dart`
Expected: PASS (4 Tests).

```bash
git add lib/features/fuetterung/domain/winterfutter.dart test/features/fuetterung/winterfutter_test.dart
git commit -m "feat(4.6): winterfutterKg (Saison-Anker) + winterfutterProzent"
```

---

## Task 5: Domain — Modell `Fuetterung`

**Files:**
- Create: `lib/features/fuetterung/domain/fuetterung.dart`
- Test: `test/features/fuetterung/fuetterung_model_test.dart`

- [ ] **Step 1: Test schreiben**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:bienen_app/features/fuetterung/domain/fuetterung.dart';

void main() {
  test('Fuetterung Roundtrip inkl. Storno-Felder', () {
    final f = Fuetterung.fromJson({
      'id': 'f1', 'volk_id': 'v1', 'durchgefuehrt_am': '2026-08-01', 'zweck': 'auffuetterung',
      'futterart': 'zuckersirup', 'bio_zertifiziert': true, 'menge_pro_volk_kg': 5,
      'material_id': null, 'verantwortliche_person': 'Dani',
      'is_storniert': true, 'storno_grund': 'Tippfehler', 'storno_am': '2026-08-02', 'notiz': null,
    });
    expect(f.zweck, 'auffuetterung');
    expect(f.mengeProVolkKg, 5);
    expect(f.bioZertifiziert, isTrue);
    expect(f.isStorniert, isTrue);
    expect(f.stornoGrund, 'Tippfehler');
  });
}
```

- [ ] **Step 2: Test ausführen (rot)**

Run: `flutter test test/features/fuetterung/fuetterung_model_test.dart`
Expected: FAIL (URI fehlt).

- [ ] **Step 3: Implementierung schreiben**

```dart
class Fuetterung {
  final String id;
  final String volkId;
  final DateTime durchgefuehrtAm;
  final String zweck;
  final String futterart;
  final bool bioZertifiziert;
  final num mengeProVolkKg;
  final String? materialId;
  final String? verantwortlichePerson;
  final bool isStorniert;
  final String? stornoGrund;
  final DateTime? stornoAm;
  final String? notiz;

  const Fuetterung({
    required this.id,
    required this.volkId,
    required this.durchgefuehrtAm,
    required this.zweck,
    required this.futterart,
    required this.bioZertifiziert,
    required this.mengeProVolkKg,
    this.materialId,
    this.verantwortlichePerson,
    this.isStorniert = false,
    this.stornoGrund,
    this.stornoAm,
    this.notiz,
  });

  static DateTime _d(Object? v) => DateTime.parse(v as String);

  factory Fuetterung.fromJson(Map<String, dynamic> j) => Fuetterung(
        id: j['id'] as String,
        volkId: j['volk_id'] as String,
        durchgefuehrtAm: _d(j['durchgefuehrt_am']),
        zweck: j['zweck'] as String,
        futterart: j['futterart'] as String,
        bioZertifiziert: (j['bio_zertifiziert'] as bool?) ?? false,
        mengeProVolkKg: j['menge_pro_volk_kg'] as num,
        materialId: j['material_id'] as String?,
        verantwortlichePerson: j['verantwortliche_person'] as String?,
        isStorniert: (j['is_storniert'] as bool?) ?? false,
        stornoGrund: j['storno_grund'] as String?,
        stornoAm: j['storno_am'] != null ? _d(j['storno_am']) : null,
        notiz: j['notiz'] as String?,
      );
}
```

- [ ] **Step 4: Test ausführen (grün) + Commit**

Run: `flutter test test/features/fuetterung/fuetterung_model_test.dart`
Expected: PASS (1 Test).

```bash
git add lib/features/fuetterung/domain/fuetterung.dart test/features/fuetterung/fuetterung_model_test.dart
git commit -m "feat(4.6): Modell Fuetterung"
```

---

## Task 6: Domain — abstraktes Gateway

**Files:**
- Create: `lib/features/fuetterung/domain/fuetterung_gateway.dart`

- [ ] **Step 1: Gateway schreiben** (in Task 8 über den Fake getestet)

```dart
import 'package:bienen_app/features/fuetterung/domain/fuetterung.dart';

class FuetterungFehler implements Exception {
  final String code;
  final String message;
  const FuetterungFehler(this.code, this.message);
  @override
  String toString() => message;
}

abstract class FuetterungGateway {
  Future<List<Fuetterung>> fuetterungenFuerVolk(String volkId); // inkl. stornierte, absteigend
  Future<int> fuetterungErfassen({
    required List<String> volkIds,
    required DateTime durchgefuehrtAm,
    required String zweck,
    required String futterart,
    required bool bioZertifiziert,
    required num mengeProVolkKg,
    String? materialId,
    String? verantwortlichePerson,
    String? notiz,
  }); // -> Anzahl erzeugter Eintraege
  Future<void> fuetterungStornieren(String id, String grund);
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/features/fuetterung/domain/fuetterung_gateway.dart
git commit -m "feat(4.6): abstraktes FuetterungGateway + FuetterungFehler"
```

---

## Task 7: `BetriebsEinstellungen`-Modell um `winterfutterZielKg` erweitern

**Files:**
- Modify: `lib/features/voelker/domain/betriebs_einstellungen.dart`
- Test: `test/features/fuetterung/betriebs_einstellungen_winterfutter_test.dart`

- [ ] **Step 1: Test schreiben**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:bienen_app/features/voelker/domain/betriebs_einstellungen.dart';

void main() {
  test('winterfutterZielKg aus JSON, Default 22 bei fehlend/leer', () {
    expect(BetriebsEinstellungen.fromJson({'winterfutter_ziel_kg': 24}).winterfutterZielKg, 24);
    expect(BetriebsEinstellungen.fromJson({}).winterfutterZielKg, 22);
    expect(const BetriebsEinstellungen.leer().winterfutterZielKg, 22);
  });
}
```

- [ ] **Step 2: Test ausführen (rot)**

Run: `flutter test test/features/fuetterung/betriebs_einstellungen_winterfutter_test.dart`
Expected: FAIL (`winterfutterZielKg` nicht definiert).

- [ ] **Step 3: Modell erweitern**

In `lib/features/voelker/domain/betriebs_einstellungen.dart`:
- Feld ergänzen (nach `imkerIdentnummer`): `final num winterfutterZielKg;`
- Konstruktor-Parameter ergänzen (mit Default): `this.winterfutterZielKg = 22,`
- In `fromJson` ergänzen: `winterfutterZielKg: (j['winterfutter_ziel_kg'] as num?) ?? 22,`

Ergebnis (vollständige Datei):

```dart
class BetriebsEinstellungen {
  final String? rasseDefault;
  final String? beutensystemDefault;
  final int? hoeheDefaultM;
  final int saisonOffsetDefaultTage;
  final String? kanton;
  final String? imkerIdentnummer;
  final num winterfutterZielKg;

  const BetriebsEinstellungen({
    this.rasseDefault,
    this.beutensystemDefault,
    this.hoeheDefaultM,
    this.saisonOffsetDefaultTage = 0,
    this.kanton,
    this.imkerIdentnummer,
    this.winterfutterZielKg = 22,
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
        winterfutterZielKg: (j['winterfutter_ziel_kg'] as num?) ?? 22,
      );
}
```

- [ ] **Step 4: Test ausführen (grün) + Commit**

Run: `flutter test test/features/fuetterung/betriebs_einstellungen_winterfutter_test.dart`
Expected: PASS (1 Test).

```bash
git add lib/features/voelker/domain/betriebs_einstellungen.dart test/features/fuetterung/betriebs_einstellungen_winterfutter_test.dart
git commit -m "feat(4.6): BetriebsEinstellungen.winterfutterZielKg (Default 22)"
```

---

## Task 8: Data — `FakeFuetterungGateway`

**Files:**
- Create: `lib/features/fuetterung/data/fake_fuetterung_gateway.dart`
- Test: `test/features/fuetterung/fake_fuetterung_gateway_test.dart`

- [ ] **Step 1: Test schreiben**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:bienen_app/features/fuetterung/data/fake_fuetterung_gateway.dart';
import 'package:bienen_app/features/fuetterung/domain/fuetterung_gateway.dart';

Future<int> erfasse(FakeFuetterungGateway g, {required List<String> volkIds, num menge = 5, String zweck = 'auffuetterung', String? material}) =>
    g.fuetterungErfassen(volkIds: volkIds, durchgefuehrtAm: DateTime(2026, 8, 1), zweck: zweck,
        futterart: 'zuckersirup', bioZertifiziert: true, mengeProVolkKg: menge, materialId: material);

void main() {
  test('Sammelfütterung: distinct Völker -> je 1 Zeile, Lager je Volk abgebucht', () async {
    final g = FakeFuetterungGateway()..lagerBestand['m1'] = 100;
    final n = await erfasse(g, volkIds: ['v1', 'v1', 'v2'], material: 'm1'); // Duplikat v1
    expect(n, 2);
    expect((await g.fuetterungenFuerVolk('v1')).length, 1);
    expect((await g.fuetterungenFuerVolk('v2')).length, 1);
    expect(g.lagerBestand['m1'], 100 - 5 * 2); // 90
  });

  test('BA041 bei leerem Array', () async {
    final g = FakeFuetterungGateway();
    expect(() => erfasse(g, volkIds: []),
        throwsA(isA<FuetterungFehler>().having((e) => e.code, 'code', 'BA041')));
  });

  test('BA040 bei ungültigem Zweck / Menge <= 0', () async {
    final g = FakeFuetterungGateway();
    expect(() => erfasse(g, volkIds: ['v1'], zweck: 'quatsch'),
        throwsA(isA<FuetterungFehler>().having((e) => e.code, 'code', 'BA040')));
    expect(() => erfasse(g, volkIds: ['v1'], menge: 0),
        throwsA(isA<FuetterungFehler>().having((e) => e.code, 'code', 'BA040')));
  });

  test('Storno ist terminal (BA040 bei zweitem Storno)', () async {
    final g = FakeFuetterungGateway();
    await erfasse(g, volkIds: ['v1']);
    final id = (await g.fuetterungenFuerVolk('v1')).first.id;
    await g.fuetterungStornieren(id, 'Fehler');
    expect((await g.fuetterungenFuerVolk('v1')).first.isStorniert, isTrue);
    expect(() => g.fuetterungStornieren(id, 'nochmal'),
        throwsA(isA<FuetterungFehler>().having((e) => e.code, 'code', 'BA040')));
  });
}
```

- [ ] **Step 2: Test ausführen (rot)**

Run: `flutter test test/features/fuetterung/fake_fuetterung_gateway_test.dart`
Expected: FAIL (Fake fehlt).

- [ ] **Step 3: Fake schreiben**

```dart
import 'package:bienen_app/features/fuetterung/domain/fuetterung.dart';
import 'package:bienen_app/features/fuetterung/domain/fuetterung_gateway.dart';
import 'package:bienen_app/features/fuetterung/domain/futterart.dart';

/// In-Memory-Fake, bildet die RPC-Semantik nach (distinct-Insert, Lager-Abbuchung × v_n,
/// BA040/041/042). Storno terminal (BA040), damit die Tests die Invarianten sehen.
class FakeFuetterungGateway implements FuetterungGateway {
  final _map = <String, Fuetterung>{};
  final lagerBestand = <String, double>{};
  int _seq = 0;

  List<Fuetterung> get _sort {
    final l = _map.values.toList();
    l.sort((a, b) => b.durchgefuehrtAm.compareTo(a.durchgefuehrtAm));
    return l;
  }

  @override
  Future<List<Fuetterung>> fuetterungenFuerVolk(String volkId) async =>
      _sort.where((f) => f.volkId == volkId).toList();

  @override
  Future<int> fuetterungErfassen({
    required List<String> volkIds,
    required DateTime durchgefuehrtAm,
    required String zweck,
    required String futterart,
    required bool bioZertifiziert,
    required num mengeProVolkKg,
    String? materialId,
    String? verantwortlichePerson,
    String? notiz,
  }) async {
    if (volkIds.isEmpty) throw const FuetterungFehler('BA041', 'Keine Völker angegeben');
    if (!Zweck.werte.contains(zweck) ||
        !Futterart.werte.contains(futterart) ||
        mengeProVolkKg <= 0) {
      throw const FuetterungFehler('BA040', 'Pflichtfeld fehlt oder ungültig');
    }
    final distinct = volkIds.toSet().toList();
    for (final v in distinct) {
      final id = 'f${++_seq}';
      _map[id] = Fuetterung(
        id: id, volkId: v, durchgefuehrtAm: durchgefuehrtAm, zweck: zweck, futterart: futterart,
        bioZertifiziert: bioZertifiziert, mengeProVolkKg: mengeProVolkKg, materialId: materialId,
        verantwortlichePerson: verantwortlichePerson, notiz: notiz,
      );
    }
    if (materialId != null && lagerBestand.containsKey(materialId)) {
      lagerBestand[materialId] = lagerBestand[materialId]! - mengeProVolkKg.toDouble() * distinct.length;
    }
    return distinct.length;
  }

  @override
  Future<void> fuetterungStornieren(String id, String grund) async {
    final f = _map[id];
    if (f == null) return;
    if (f.isStorniert) throw const FuetterungFehler('BA040', 'Storno ist terminal');
    _map[id] = Fuetterung(
      id: f.id, volkId: f.volkId, durchgefuehrtAm: f.durchgefuehrtAm, zweck: f.zweck,
      futterart: f.futterart, bioZertifiziert: f.bioZertifiziert, mengeProVolkKg: f.mengeProVolkKg,
      materialId: f.materialId, verantwortlichePerson: f.verantwortlichePerson,
      isStorniert: true, stornoGrund: grund, stornoAm: f.durchgefuehrtAm, notiz: f.notiz,
    );
  }
}
```

- [ ] **Step 4: Test ausführen (grün) + Commit**

Run: `flutter test test/features/fuetterung/fake_fuetterung_gateway_test.dart`
Expected: PASS (4 Tests).

```bash
git add lib/features/fuetterung/data/fake_fuetterung_gateway.dart test/features/fuetterung/fake_fuetterung_gateway_test.dart
git commit -m "feat(4.6): FakeFuetterungGateway (distinct/Lager/BA040-042)"
```

---

## Task 9: Data — `SupabaseFuetterungGateway`

**Files:**
- Create: `lib/features/fuetterung/data/supabase_fuetterung_gateway.dart`

- [ ] **Step 1: Implementierung schreiben** (Muster wie `supabase_behandlung_gateway.dart`)

```dart
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:bienen_app/features/fuetterung/domain/fuetterung.dart';
import 'package:bienen_app/features/fuetterung/domain/fuetterung_gateway.dart';

class SupabaseFuetterungGateway implements FuetterungGateway {
  final SupabaseClient _c;
  SupabaseFuetterungGateway(this._c);

  Never _rethrow(Object e) {
    if (e is PostgrestException && e.code != null) {
      throw FuetterungFehler(e.code!, e.message);
    }
    throw e;
  }

  @override
  Future<List<Fuetterung>> fuetterungenFuerVolk(String volkId) async {
    try {
      final res = await _c
          .from('fuetterungen')
          .select()
          .eq('volk_id', volkId)
          .order('durchgefuehrt_am', ascending: false);
      return (res as List).map((j) => Fuetterung.fromJson(j as Map<String, dynamic>)).toList();
    } catch (e) {
      _rethrow(e);
    }
  }

  String _iso(DateTime d) => d.toIso8601String().substring(0, 10);

  @override
  Future<int> fuetterungErfassen({
    required List<String> volkIds,
    required DateTime durchgefuehrtAm,
    required String zweck,
    required String futterart,
    required bool bioZertifiziert,
    required num mengeProVolkKg,
    String? materialId,
    String? verantwortlichePerson,
    String? notiz,
  }) async {
    try {
      final n = await _c.rpc('fuetterung_erfassen', params: {
        'p_volk_ids': volkIds,
        'p_durchgefuehrt_am': _iso(durchgefuehrtAm),
        'p_zweck': zweck,
        'p_futterart': futterart,
        'p_menge_pro_volk_kg': mengeProVolkKg,
        'p_bio_zertifiziert': bioZertifiziert,
        'p_material_id': materialId,
        'p_verantwortliche_person': verantwortlichePerson,
        'p_notiz': notiz,
      });
      return (n as num).toInt();
    } catch (e) {
      _rethrow(e);
    }
  }

  @override
  Future<void> fuetterungStornieren(String id, String grund) async {
    try {
      await _c.from('fuetterungen').update({
        'is_storniert': true,
        'storno_grund': grund,
        'storno_am': _iso(DateTime.now()),
      }).eq('id', id);
    } catch (e) {
      _rethrow(e);
    }
  }
}
```

- [ ] **Step 2: Analyze + Commit**

Run: `flutter analyze lib/features/fuetterung/data/supabase_fuetterung_gateway.dart`
Expected: No issues.

```bash
git add lib/features/fuetterung/data/supabase_fuetterung_gateway.dart
git commit -m "feat(4.6): SupabaseFuetterungGateway (RPC + CRUD)"
```

---

## Task 10: Presentation — Provider + Sammel-Invalidierung

**Files:**
- Create: `lib/features/fuetterung/presentation/providers/fuetterung_provider.dart`
- Test: `test/features/fuetterung/fuetterung_provider_test.dart`

- [ ] **Step 1: Test schreiben**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bienen_app/features/fuetterung/data/fake_fuetterung_gateway.dart';
import 'package:bienen_app/features/fuetterung/presentation/providers/fuetterung_provider.dart';

void main() {
  test('Sammelfütterung A+B invalidiert BEIDE Volk-Family-Instanzen', () async {
    final fake = FakeFuetterungGateway();
    final container = ProviderContainer(overrides: [
      fuetterungGatewayProvider.overrideWithValue(fake),
    ]);
    addTearDown(container.dispose);

    expect((await container.read(fuetterungenFuerVolkProvider('v1').future)).length, 0);
    expect((await container.read(fuetterungenFuerVolkProvider('v2').future)).length, 0);

    final n = await container.read(fuetterungAktionenProvider).erfassen(
          volkIds: ['v1', 'v2'], durchgefuehrtAm: DateTime(2026, 8, 1), zweck: 'auffuetterung',
          futterart: 'zuckersirup', bioZertifiziert: true, mengeProVolkKg: 5);
    expect(n, 2);

    expect((await container.read(fuetterungenFuerVolkProvider('v1').future)).length, 1);
    expect((await container.read(fuetterungenFuerVolkProvider('v2').future)).length, 1);
  });
}
```

- [ ] **Step 2: Test ausführen (rot)**

Run: `flutter test test/features/fuetterung/fuetterung_provider_test.dart`
Expected: FAIL (Provider fehlen).

- [ ] **Step 3: Provider schreiben**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bienen_app/core/supabase/supabase_config.dart';
import 'package:bienen_app/features/fuetterung/data/supabase_fuetterung_gateway.dart';
import 'package:bienen_app/features/fuetterung/domain/fuetterung.dart';
import 'package:bienen_app/features/fuetterung/domain/fuetterung_gateway.dart';
import 'package:bienen_app/features/material/presentation/providers/material_provider.dart';

final fuetterungGatewayProvider =
    Provider<FuetterungGateway>((ref) => SupabaseFuetterungGateway(SupabaseConfig.client));

final fuetterungenFuerVolkProvider =
    AsyncNotifierProvider.family<FuetterungenNotifier, List<Fuetterung>, String>(
        FuetterungenNotifier.new);

class FuetterungenNotifier extends FamilyAsyncNotifier<List<Fuetterung>, String> {
  FuetterungGateway get _gw => ref.read(fuetterungGatewayProvider);
  @override
  Future<List<Fuetterung>> build(String volkId) => _gw.fuetterungenFuerVolk(volkId);

  Future<void> stornieren(String id, String grund) async {
    await _gw.fuetterungStornieren(id, grund);
    ref.invalidateSelf();
  }
}

/// Sammelfütterung: erfasst N Völker in einem RPC-Aufruf und invalidiert JEDE beteiligte
/// Volk-Family plus `materialListProvider` (Lager geändert). Wie 4.5 (D-18/D-23-Gotcha).
final fuetterungAktionenProvider = Provider<FuetterungAktionen>((ref) => FuetterungAktionen(ref));

class FuetterungAktionen {
  final Ref _ref;
  FuetterungAktionen(this._ref);

  Future<int> erfassen({
    required List<String> volkIds,
    required DateTime durchgefuehrtAm,
    required String zweck,
    required String futterart,
    required bool bioZertifiziert,
    required num mengeProVolkKg,
    String? materialId,
    String? verantwortlichePerson,
    String? notiz,
  }) async {
    final n = await _ref.read(fuetterungGatewayProvider).fuetterungErfassen(
          volkIds: volkIds, durchgefuehrtAm: durchgefuehrtAm, zweck: zweck, futterart: futterart,
          bioZertifiziert: bioZertifiziert, mengeProVolkKg: mengeProVolkKg, materialId: materialId,
          verantwortlichePerson: verantwortlichePerson, notiz: notiz,
        );
    for (final id in volkIds.toSet()) {
      _ref.invalidate(fuetterungenFuerVolkProvider(id));
    }
    _ref.invalidate(materialListProvider);
    return n;
  }
}
```

- [ ] **Step 4: Test ausführen (grün) + Commit**

Run: `flutter test test/features/fuetterung/fuetterung_provider_test.dart`
Expected: PASS (1 Test).

```bash
git add lib/features/fuetterung/presentation/providers/fuetterung_provider.dart test/features/fuetterung/fuetterung_provider_test.dart
git commit -m "feat(4.6): Family-Provider + FuetterungAktionen (Sammel-Invalidierung)"
```

---

## Task 11: Auth-Reload-Verdrahtung

**Files:**
- Modify: `lib/features/auth/presentation/auth_providers.dart`
- Test: `test/features/fuetterung/fuetterung_provider_reset_test.dart`

- [ ] **Step 1: Test schreiben**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bienen_app/features/auth/data/fake_auth_gateway.dart';
import 'package:bienen_app/features/auth/presentation/auth_providers.dart';
import 'package:bienen_app/features/fuetterung/data/fake_fuetterung_gateway.dart';
import 'package:bienen_app/features/fuetterung/presentation/providers/fuetterung_provider.dart';

void main() {
  test('signOut invalidiert den Fütterungs-Cache (kein Stale nach Mandantenwechsel)', () async {
    final fake = FakeFuetterungGateway();
    await fake.fuetterungErfassen(volkIds: ['v1'], durchgefuehrtAm: DateTime(2026, 8, 1),
        zweck: 'auffuetterung', futterart: 'zuckersirup', bioZertifiziert: true, mengeProVolkKg: 5);

    final container = ProviderContainer(overrides: [
      authGatewayProvider.overrideWithValue(FakeAuthGateway()),
      fuetterungGatewayProvider.overrideWithValue(fake),
    ]);
    addTearDown(container.dispose);

    final f0 = (await container.read(fuetterungenFuerVolkProvider('v1').future)).single;
    expect(f0.isStorniert, isFalse);

    // Backend aendert sich: Eintrag storniert.
    await fake.fuetterungStornieren(f0.id, 'weg');
    // Stale-Cache zeigt weiterhin nicht-storniert.
    expect(container.read(fuetterungenFuerVolkProvider('v1')).valueOrNull?.single.isStorniert, isFalse);

    // signOut -> _datenNeuLaden() muss fuetterungenFuerVolkProvider invalidieren.
    await container.read(authControllerProvider.notifier).signOut();
    expect(
      (await container.read(fuetterungenFuerVolkProvider('v1').future)).single.isStorniert,
      isTrue,
      reason: 'fuetterungenFuerVolkProvider nach signOut nicht invalidiert',
    );
  });
}
```

- [ ] **Step 2: `_datenNeuLaden` erweitern**

In `lib/features/auth/presentation/auth_providers.dart` den Import ergänzen:

```dart
import 'package:bienen_app/features/fuetterung/presentation/providers/fuetterung_provider.dart';
```

Und in `_datenNeuLaden()` (nach den Behandlungs-Invalidierungen) ergänzen:

```dart
    ref.invalidate(fuetterungenFuerVolkProvider);
```

- [ ] **Step 3: Test ausführen (grün) + Commit**

Run: `flutter test test/features/fuetterung/fuetterung_provider_reset_test.dart`
Expected: PASS.

```bash
git add lib/features/auth/presentation/auth_providers.dart test/features/fuetterung/fuetterung_provider_reset_test.dart
git commit -m "feat(4.6): Fütterungs-Provider in _datenNeuLaden (Fremd-Cache-Schutz)"
```

---

## Task 12: UI — `WinterfutterBalken`

**Files:**
- Create: `lib/features/fuetterung/presentation/widgets/winterfutter_balken.dart`

- [ ] **Step 1: Widget schreiben**

```dart
import 'package:flutter/material.dart';
import 'package:bienen_app/features/fuetterung/domain/fuetterung.dart';
import 'package:bienen_app/features/fuetterung/domain/winterfutter.dart';

/// Winterfutter-Fortschritt: Σ Auffütterung (Produktmasse) der laufenden Saison gegen das Ziel.
class WinterfutterBalken extends StatelessWidget {
  final List<Fuetterung> fuetterungen;
  final num zielKg;
  final DateTime stichtag;
  const WinterfutterBalken({
    super.key,
    required this.fuetterungen,
    required this.zielKg,
    required this.stichtag,
  });

  @override
  Widget build(BuildContext context) {
    final kg = winterfutterKg(fuetterungen, stichtag: stichtag);
    final prozent = winterfutterProzent(kg, zielKg.toDouble());
    final erreicht = kg >= zielKg;
    final color = erreicht ? Colors.green : Colors.amber.shade700;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Text('Winterfutter', style: TextStyle(fontWeight: FontWeight.bold)),
        const Spacer(),
        Text('${kg.toStringAsFixed(1)} / ${zielKg.toStringAsFixed(0)} kg (${(prozent * 100).round()} %)',
            style: TextStyle(color: color, fontWeight: FontWeight.bold)),
      ]),
      const SizedBox(height: 6),
      ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: LinearProgressIndicator(
          value: prozent, minHeight: 10,
          backgroundColor: Colors.grey.withAlpha(40), color: color),
      ),
      const SizedBox(height: 4),
      Text(
        erreicht
            ? 'Ziel erreicht.'
            : 'Ziel noch nicht erreicht — erfasste Produktmasse Auffütterung (Richtwert 22 kg; alpine Hochlage eher 24–25). Produktgewicht ≠ eingelagerter Vorrat.',
        style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.grey),
      ),
    ]);
  }
}
```

- [ ] **Step 2: Analyze + Commit**

Run: `flutter analyze lib/features/fuetterung/presentation/widgets/winterfutter_balken.dart`
Expected: No issues.

```bash
git add lib/features/fuetterung/presentation/widgets/winterfutter_balken.dart
git commit -m "feat(4.6): WinterfutterBalken (Fortschritt Auffütterung/Ziel)"
```

---

## Task 13: UI — `FuetterungSection` (Andock-Card)

**Files:**
- Create: `lib/features/fuetterung/presentation/widgets/fuetterung_section.dart`

- [ ] **Step 1: Widget schreiben**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:bienen_app/features/auth/presentation/auth_providers.dart';
import 'package:bienen_app/features/fuetterung/domain/futterart.dart';
import 'package:bienen_app/features/fuetterung/presentation/providers/fuetterung_provider.dart';
import 'package:bienen_app/features/fuetterung/presentation/widgets/winterfutter_balken.dart';
import 'package:bienen_app/features/voelker/presentation/providers/voelker_provider.dart';

class FuetterungSection extends ConsumerWidget {
  final String volkId;
  const FuetterungSection({super.key, required this.volkId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(fuetterungenFuerVolkProvider(volkId));
    final einst = ref.watch(betriebsEinstellungenProvider).valueOrNull;
    final darf = ref.watch(darfSchreibenProvider);
    final zielKg = einst?.winterfutterZielKg ?? 22;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Text('Fütterung', style: TextStyle(fontWeight: FontWeight.bold)),
            const Spacer(),
            if (darf)
              TextButton.icon(
                onPressed: () => context.go('/voelker/$volkId/fuetterung'),
                icon: const Icon(Icons.water_drop_outlined, size: 18),
                label: const Text('Fütterung erfassen')),
          ]),
          async.when(
            loading: () => const Padding(padding: EdgeInsets.all(8), child: LinearProgressIndicator()),
            error: (e, _) => Padding(padding: const EdgeInsets.all(8), child: Text('Fehler: $e')),
            data: (list) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              WinterfutterBalken(fuetterungen: list, zielKg: zielKg, stichtag: DateTime.now()),
              const Divider(),
              if (list.isEmpty)
                const Padding(padding: EdgeInsets.all(8), child: Text('Noch keine Fütterung.'))
              else
                for (final f in list.take(5))
                  ListTile(
                    dense: true,
                    leading: Icon(f.isStorniert ? Icons.cancel : Icons.water_drop_outlined,
                        color: f.isStorniert ? Colors.grey : null),
                    title: Text(
                      '${Zweck.labels[f.zweck] ?? f.zweck} · ${f.mengeProVolkKg} kg · ${Futterart.labels[f.futterart] ?? f.futterart}',
                      style: f.isStorniert
                          ? const TextStyle(decoration: TextDecoration.lineThrough, color: Colors.grey)
                          : null,
                    ),
                    subtitle: Text('${f.durchgefuehrtAm.day}.${f.durchgefuehrtAm.month}.${f.durchgefuehrtAm.year}'
                        '${f.bioZertifiziert ? ' · bio' : ''}'
                        '${f.isStorniert ? ' · storniert: ${f.stornoGrund ?? ''}' : ''}'),
                    trailing: (darf && !f.isStorniert)
                        ? IconButton(
                            icon: const Icon(Icons.cancel_outlined, size: 20),
                            tooltip: 'Stornieren',
                            onPressed: () => _storno(context, ref, f.id),
                          )
                        : null,
                  ),
            ]),
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
        title: const Text('Fütterung stornieren'),
        content: TextField(controller: ctrl, decoration: const InputDecoration(labelText: 'Grund')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Abbrechen')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('Stornieren')),
        ],
      ),
    );
    ctrl.dispose();
    if (grund == null || grund.isEmpty || !context.mounted) return;
    try {
      await ref.read(fuetterungenFuerVolkProvider(volkId).notifier).stornieren(id, grund);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Storno fehlgeschlagen: $e')));
      }
    }
  }
}
```

- [ ] **Step 2: Analyze + Commit**

Run: `flutter analyze lib/features/fuetterung/presentation/widgets/fuetterung_section.dart`
Expected: No issues.

```bash
git add lib/features/fuetterung/presentation/widgets/fuetterung_section.dart
git commit -m "feat(4.6): FuetterungSection (Balken + Button + Storno-Liste)"
```

---

## Task 14: UI — `FuetterungFormPage` (Sammelfütterung)

**Files:**
- Create: `lib/features/fuetterung/presentation/pages/fuetterung_form_page.dart`

- [ ] **Step 1: Seite schreiben**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:bienen_app/features/auth/presentation/auth_providers.dart';
import 'package:bienen_app/features/fuetterung/domain/futterart.dart';
import 'package:bienen_app/features/fuetterung/presentation/providers/fuetterung_provider.dart';
import 'package:bienen_app/features/material/presentation/providers/material_provider.dart';
import 'package:bienen_app/features/voelker/presentation/providers/voelker_provider.dart';

class FuetterungFormPage extends ConsumerStatefulWidget {
  final String volkId;
  const FuetterungFormPage({super.key, required this.volkId});
  @override
  ConsumerState<FuetterungFormPage> createState() => _FuetterungFormPageState();
}

class _FuetterungFormPageState extends ConsumerState<FuetterungFormPage> {
  late final Set<String> _volkIds = {widget.volkId};
  DateTime _datum = DateTime.now();
  String _zweck = 'auffuetterung';
  String _futterart = 'zuckersirup';
  bool _bio = true;
  final _menge = TextEditingController();
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
    _menge.dispose();
    _person.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!ref.watch(darfSchreibenProvider)) {
      return Scaffold(appBar: AppBar(title: const Text('Fütterung')),
          body: const Center(child: Text('Nur Lesezugriff.')));
    }
    final voelker = ref.watch(voelkerListProvider).valueOrNull ?? [];
    final materialien = (ref.watch(materialListProvider).valueOrNull ?? [])
        .where((m) => m.isConsumable && m.bereich == 'imkerei')
        .toList();

    final selektierte = voelker.where((v) => _volkIds.contains(v.id)).toList();
    final zeigeBioBanner = !_bio && selektierte.any((v) => v.bioStatus != 'konventionell');

    return Scaffold(
      appBar: AppBar(title: const Text('Fütterung erfassen')),
      body: !_geladen
          ? const Center(child: CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.all(16), children: [
              const Text('Völker (Sammelfütterung)', style: TextStyle(fontWeight: FontWeight.bold)),
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
              const SizedBox(height: 8),
              const Text('Zweck'),
              Wrap(spacing: 8, children: [
                for (final z in Zweck.werte)
                  ChoiceChip(
                    label: Text(Zweck.labels[z]!),
                    selected: _zweck == z,
                    onSelected: (_) => setState(() => _zweck = z),
                  ),
              ]),
              DropdownButtonFormField<String>(
                initialValue: _futterart,
                decoration: const InputDecoration(labelText: 'Futterart'),
                items: [for (final f in Futterart.werte) DropdownMenuItem(value: f, child: Text(Futterart.labels[f]!))],
                onChanged: (v) => setState(() => _futterart = v!),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Bio-zertifiziert'),
                value: _bio,
                onChanged: (v) => setState(() => _bio = v),
              ),
              TextField(controller: _menge, keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Menge PRO Volk (kg)')),
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
                      'Nicht bio-zertifiziertes Futter auf: ${selektierte.where((v) => v.bioStatus != 'konventionell').map((v) => v.name).join(', ')}',
                    )),
                  ]),
                ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _speichert ? null : _speichern,
                icon: const Icon(Icons.save),
                label: Text(_speichert ? 'Speichert…' : 'Fütterung speichern'),
              ),
            ]),
    );
  }

  Future<void> _speichern() async {
    final menge = num.tryParse(_menge.text.replaceAll(',', '.'));
    if (_volkIds.isEmpty || menge == null || menge <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Mindestens ein Volk und eine Menge > 0 nötig.')));
      return;
    }
    setState(() => _speichert = true);
    try {
      await ref.read(fuetterungAktionenProvider).erfassen(
            volkIds: _volkIds.toList(),
            durchgefuehrtAm: _datum,
            zweck: _zweck,
            futterart: _futterart,
            bioZertifiziert: _bio,
            mengeProVolkKg: menge,
            materialId: _materialId,
            verantwortlichePerson: _person.text.trim().isEmpty ? null : _person.text.trim(),
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

Run: `flutter analyze lib/features/fuetterung/presentation/pages/fuetterung_form_page.dart`
Expected: No issues.

```bash
git add lib/features/fuetterung/presentation/pages/fuetterung_form_page.dart
git commit -m "feat(4.6): FuetterungFormPage (Sammel-Multi-Select, Material, Bio-Banner)"
```

---

## Task 15: Verdrahtung — Detailseite andocken + Route

**Files:**
- Modify: `lib/features/voelker/presentation/pages/volk_detail_page.dart`
- Modify: `lib/core/router/app_router.dart`

- [ ] **Step 1: `FuetterungSection` in die Detailseite einfügen**

Import ergänzen:

```dart
import 'package:bienen_app/features/fuetterung/presentation/widgets/fuetterung_section.dart';
```

Im `ListView` direkt nach `BehandlungSection(volkId: volk.id),` einfügen:

```dart
              FuetterungSection(volkId: volk.id),
```

- [ ] **Step 2: Route registrieren**

In `lib/core/router/app_router.dart` den Import ergänzen:

```dart
import 'package:bienen_app/features/fuetterung/presentation/pages/fuetterung_form_page.dart';
```

Unter `/voelker/:id` (nach der `behandlung`-Route, vor der schließenden `]` der Sub-Routen) einfügen:

```dart
                GoRoute(
                  path: 'fuetterung',
                  builder: (c, s) => FuetterungFormPage(volkId: s.pathParameters['id']!),
                ),
```

- [ ] **Step 3: Build-Check + Commit**

Run: `flutter analyze lib/features/voelker/presentation/pages/volk_detail_page.dart lib/core/router/app_router.dart`
Expected: No issues.

```bash
git add lib/features/voelker/presentation/pages/volk_detail_page.dart lib/core/router/app_router.dart
git commit -m "feat(4.6): FuetterungSection andocken + Route /fuetterung"
```

---

## Task 16: Abschluss — Analyze, Tests, Deploy 1.12.0

**Files:**
- Modify: `pubspec.yaml`

- [ ] **Step 1: Voller Analyze**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 2: Volle Testsuite**

Run: `flutter test`
Expected: alle grün (bestehende + neue Fütterungs-Tests).

- [ ] **Step 3: Version bumpen**

In `pubspec.yaml`:

```yaml
version: 1.12.0+30
```

- [ ] **Step 4: Commit + Deploy** (stehende Deploy-Freigabe)

```bash
git add pubspec.yaml
git commit -m "chore(4.6): Version 1.12.0+30"
git checkout master
git merge --no-ff feat/fuetterung -m "feat: Modul 4.6 Fütterung v1.12.0"
git push origin master
bash deploy.sh
```

- [ ] **Step 5: Live-Verifikation**

Nach dem Deploy: App laden, ein Volk öffnen, „Fütterung"-Sektion prüfen (Fütterung erfassen → Balken steigt, Liste zeigt Eintrag, Lager sinkt; Storno → durchgestrichen; Bio-Switch aus + Bio-Volk → Warnbanner). Konsole fehlerfrei.

---

## Self-Review-Notizen (Plan ↔ Spec)

- **Spec-Abdeckung:** §4.1 winterfutter_ziel_kg → Task 1/7. §4.2 fuetterungen (RESTRICT/CHECKs/RLS) → Task 1. §4.3 RPC (BA040-042, Enum-Validierung) → Task 2. §5 winterfutterKg (Saison-Anker M2)/winterfutterProzent → Task 4. §6 Gateway/State/UI → Tasks 6,8,9,10,12,13,14. §6 Andocken → Task 15. §7 Deploy → Task 16. §8 Tests → in Tasks 1,2 (SQL) + 3,4,5,7,8,10,11 (Dart). Alle Abschnitte abgedeckt.
- **M1 RESTRICT** → Task 1 (FK + Rollback-Test). **M2 Saison-Anker** → Task 4 (in der Funktion gekapselt + Jahreswechsel-Test). **M3 menge_pro_volk_kg** → durchgängig (Spalte Task 1, RPC Task 2, Modell Task 5, Balken Task 4, Label Task 14, Semantik-Test Task 8/2).
- **Typkonsistenz:** `fuetterungErfassen(...)`-Signatur identisch in Gateway (6), Fake (8), Supabase (9), `FuetterungAktionen.erfassen` (10). `winterfutterKg(list, {required stichtag})` konsistent Task 4 ↔ 12. `Fuetterung`-Feldnamen (`mengeProVolkKg`, `bioZertifiziert`, `isStorniert`) konsistent Modell (5) ↔ Fake (8) ↔ winterfutter (4) ↔ UI (12/13).
- **Reihenfolge-Hinweis:** Task 4 (winterfutter) referenziert das `Fuetterung`-Modell aus Task 5 — bei subagent-getriebener Ausführung Task 5 vor Task 4 umsetzen (oder das Modell mitziehen). Im Plan bewusst so nummeriert, weil winterfutter die fachliche Kernlogik ist; der Umsetzer zieht `fuetterung.dart` bei Bedarf vor.
- **Muster-Referenz `.withAlpha(int)`** (nicht withOpacity/withValues), `initialValue:` bei DropdownButtonFormField, `Volk.bioStatus`/`name`, `MaterialItem.isConsumable/bereich/unit/name/id` — gegen die Codebasis verifiziert (identisch zu 4.5).
```
