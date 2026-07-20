# Betriebsprofil & Generator-Ausbau — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Betriebsprofil (F4-Settings-Seite mit 3 Strategie-Weichen) editierbar machen und den Aufgaben-Generator (4.4) konfigurierbar + fachlich korrekt ausbauen (Timing-Härtung, ~10 neue/geänderte Regeln), inkl. 4.6-futterart-Konzentration.

**Architecture:** Additive Migrationen I01 (betriebs_einstellungen +3 Flags) / I02 (fuetterungen futterart-Whitelist + RPC). Generator bleibt im Fenster+Offset-Modell; Strategie-Flags gaten Regeln, `beschreibungFuer` formt die Sommerbehandlung. Settings-Seite via direktem `.eq('betrieb_id')`-Update (RLS `kann_schreiben`).

**Tech Stack:** Flutter Web, Riverpod (ohne Codegen), Go Router (Hash), supabase_flutter, PostgreSQL 15.

**Spec:** `docs/superpowers/specs/2026-07-20-betriebsprofil-generator-ausbau-design.md` (v2, nach adversarialem Review). Branch: `feat/betriebsprofil-generator` (existiert). Version am Ende: **1.16.0+37**.

**Kern-Entscheide (v2, Review):** `sommerbehandlung_1` bleibt UNVERÄNDERT (kalenderfix); nur `gemuelldiagnose_sommer` wird offset (Basis 6.6.–20.6.). Neue Herbst-Regeln offset=**nein**. `honigernte_sommer` offset=**nein**. Generator-Param `einstellungen` mit Default `const BetriebsEinstellungen.leer()` (sonst brechen 14 Bestandstests).

**Bestehende Bausteine (verifiziert, NICHT neu bauen):** `betriebs_einstellungen` (C01, +winterfutter_ziel_kg aus F01; UPDATE-Policy `betriebs_einstellungen_upd_writer` existiert); `fuetterungen`-CHECK heisst `fuetterungen_futterart_check`, Tabelle ist **leer** (0 Zeilen); RPC `fuetterung_erfassen` (F02) validiert `p_futterart` gegen die alte Whitelist; `BetriebsEinstellungen.leer()` ist `const`; Generator + `AufgabenVorschlag` in [saison_regeln.dart](../../lib/features/aufgaben/domain/saison_regeln.dart); `_ausVorschlag`/`vorschlaegeProvider` in [aufgaben_provider.dart](../../lib/features/aufgaben/presentation/providers/aufgaben_provider.dart); `VoelkerGateway.einstellungen()` + `EinstellungenNotifier` (read-only) in voelker.

**Migrations-/Prod-Freigabe:** I01 und I02 gehen auf Produktion `dcdcohktxbhdxnxjvcyp` — **beim Ausführungs-Start explizit einholen.**

---

## File-Struktur (Ziel)
```
supabase/migrations/I01_betriebs_einstellungen_strategie.sql        (neu)
supabase/migrations/I02_fuetterungen_futterart_konzentration.sql    (neu)
lib/features/voelker/domain/betriebs_einstellungen.dart             (Modify: +3 Felder, toUpdateJson)
lib/features/voelker/domain/voelker_gateway.dart                   (Modify: einstellungenSpeichern)
lib/features/voelker/data/fake_voelker_gateway.dart               (Modify)
lib/features/voelker/data/supabase_voelker_gateway.dart          (Modify)
lib/features/voelker/presentation/providers/voelker_provider.dart (Modify: EinstellungenNotifier.speichern)
lib/features/einstellungen/domain/winterfutter_warnung.dart       (neu: pure Warnschwelle)
lib/features/einstellungen/pages/einstellungen_page.dart          (neu)
lib/features/fuetterung/domain/futterart.dart                     (Modify)
lib/features/aufgaben/domain/saison_regeln.dart                   (Modify: gross)
lib/features/aufgaben/presentation/providers/aufgaben_provider.dart (Modify)
lib/features/aufgaben/presentation/widgets/vorschlag_karte.dart   (Modify, optional)
lib/features/projekt/pages/projekt_page.dart                      (Modify: Kachel)
lib/core/router/app_router.dart                                  (Modify: /einstellungen)
+ Tests
```

---

### Task 1: Migration I01 schreiben (Datei)

**Files:** Create `supabase/migrations/I01_betriebs_einstellungen_strategie.sql`

- [ ] **Step 1: SQL-Datei schreiben**
```sql
-- I01_betriebs_einstellungen_strategie.sql | 3 Strategie-Weichen fürs Betriebsprofil (F4).
-- Additiv (Spalten), Defaults = Arosa-tauglich (1 Ernte, Ameisensäure, keine Vermehrung).
-- UPDATE-Policy existiert bereits (C01 betriebs_einstellungen_upd_writer). Column-Grant-Härtung:
-- amtliche Felder (imker_identnummer/kanton) aus dem App-Schreibpfad halten.

alter table public.betriebs_einstellungen
  add column if not exists anzahl_ernten int not null default 1
    check (anzahl_ernten in (1, 2)),
  add column if not exists sommerbehandlung_methode text not null default 'ameisensaeure'
    check (sommerbehandlung_methode in ('ameisensaeure', 'biotechnisch', 'beide')),
  add column if not exists vermehrung_aktiv boolean not null default false;

-- Compliance-Härtung: UPDATE der App auf die 5 editierbaren Spalten beschränken
-- (amtliche Felder imker_identnummer/kanton bleiben ausserhalb; Ops/Service-Role bypasst Grants).
revoke update on public.betriebs_einstellungen from authenticated;
grant update (saison_offset_default_tage, winterfutter_ziel_kg,
              anzahl_ernten, sommerbehandlung_methode, vermehrung_aktiv)
  on public.betriebs_einstellungen to authenticated;

-- ROLLBACK (Ops):
--   revoke update (...) on public.betriebs_einstellungen from authenticated;
--   grant update on public.betriebs_einstellungen to authenticated;
--   alter table public.betriebs_einstellungen
--     drop column vermehrung_aktiv, drop column sommerbehandlung_methode, drop column anzahl_ernten;
```

- [ ] **Step 2: Commit**
```bash
git add supabase/migrations/I01_betriebs_einstellungen_strategie.sql
git commit -m "feat(db): I01 betriebs_einstellungen +3 Strategie-Weichen + Column-Grant-Härtung"
```

---

### Task 2: I01 auf Produktion anwenden + verifizieren

**Voraussetzung: Prod-Migrations-Freigabe eingeholt.** Via MCP `apply_migration` (Name `i01_betriebs_einstellungen_strategie`, SQL aus Task 1).

- [ ] **Step 1: `apply_migration` ausführen** (SQL aus Task 1).

- [ ] **Step 2: DO-Test (execute_sql)** — Defaults + CHECK + Column-Grant.
```sql
do $$
declare v_b uuid := '1c84d5dd-d22e-4bce-bba9-5e861b2f4aa4';
begin
  perform set_config('app.current_user_id', '57255790-cd8b-4177-a24d-fd0e6bf975a2', true);
  -- Defaults vorhanden?
  perform 1 from public.betriebs_einstellungen
    where betrieb_id = v_b and anzahl_ernten = 1
      and sommerbehandlung_methode = 'ameisensaeure' and vermehrung_aktiv = false;
  if not found then raise exception 'Defaults fehlen'; end if;
  -- CHECK greift?
  begin
    update public.betriebs_einstellungen set anzahl_ernten = 3 where betrieb_id = v_b;
    raise exception 'CHECK anzahl_ernten griff nicht';
  exception when check_violation then null; end;
  raise notice 'I01 DO-Tests OK';
end $$;
```
Expected: `I01 DO-Tests OK`, keine Exception.

- [ ] **Step 3: Column-Grant prüfen (execute_sql)**
```sql
select string_agg(column_name, ',' order by column_name) as spalten
from information_schema.role_column_grants
where grantee = 'authenticated' and table_name = 'betriebs_einstellungen' and privilege_type = 'UPDATE';
```
Expected: genau `anzahl_ernten,saison_offset_default_tage,sommerbehandlung_methode,vermehrung_aktiv,winterfutter_ziel_kg` (imker_identnummer/kanton NICHT enthalten).

- [ ] **Step 4: Advisors** — `get_advisors(type='security')` → 0 neue Findings.

---

### Task 3: Migration I02 schreiben (Datei)

**Files:** Create `supabase/migrations/I02_fuetterungen_futterart_konzentration.sql`

- [ ] **Step 1: SQL-Datei schreiben** (Backfill → CHECK-Wechsel → RPC create-or-replace, atomar im Transaktions-File)
```sql
-- I02_fuetterungen_futterart_konzentration.sql | futterart-Whitelist um Konzentrationen erweitern.
-- fuetterungen ist LEER (0 Zeilen verifiziert) -> Backfill trifft 0 Zeilen (keine Bio-Nachweis-Zeile
-- wird umgeschrieben). UPDATE by design erlaubt (F01: kein Immutable-Trigger). Constraint-Name
-- fuetterungen_futterart_check (pg_constraint verifiziert). RPC F02 MUSS mit (einzige Schreibpforte).

-- 1) Backfill (idempotent, 0 Zeilen erwartet)
update public.fuetterungen set futterart = 'zuckerwasser_3_2' where futterart = 'zuckerwasser';
update public.fuetterungen set futterart = 'invertsirup'     where futterart = 'zuckersirup';

-- 2) CHECK auf neue Whitelist
alter table public.fuetterungen drop constraint if exists fuetterungen_futterart_check;
alter table public.fuetterungen add constraint fuetterungen_futterart_check
  check (futterart in ('zuckerwasser_1_1','zuckerwasser_3_2','invertsirup',
                       'futterteig','futterwaben','honig','sonstige'));

-- 3) RPC-Enumvalidierung mitziehen (Signatur/Grants unverändert; create or replace erhält Grants)
create or replace function public.fuetterung_erfassen(
  p_volk_ids uuid[], p_durchgefuehrt_am date, p_zweck text, p_futterart text,
  p_menge_pro_volk_kg numeric, p_bio_zertifiziert boolean,
  p_material_id uuid default null, p_verantwortliche_person text default null, p_notiz text default null
) returns int language plpgsql security definer set search_path = '' as $$
declare v_betrieb uuid; v_betriebe uuid[]; v_found int; v_n int;
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
     or p_futterart not in ('zuckerwasser_1_1','zuckerwasser_3_2','invertsirup','futterteig','futterwaben','honig','sonstige')
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

-- ROLLBACK (Ops): reverse-UPDATE (3_2->zuckerwasser, invertsirup->zuckersirup) + alten CHECK + F02 aus F02.sql.
```

- [ ] **Step 2: Commit**
```bash
git add supabase/migrations/I02_fuetterungen_futterart_konzentration.sql
git commit -m "feat(db): I02 fuetterungen futterart-Konzentration (+ RPC F02 mitgezogen)"
```

---

### Task 4: I02 auf Produktion anwenden + verifizieren

- [ ] **Step 1: `apply_migration`** (Name `i02_fuetterungen_futterart_konzentration`, SQL aus Task 3).

- [ ] **Step 2: DO-Test (execute_sql)** — neuer Wert via RPC ok, alter Wert abgelehnt.
```sql
do $$
declare v_b uuid := '1c84d5dd-d22e-4bce-bba9-5e861b2f4aa4'; v_volk uuid;
begin
  perform set_config('app.current_user_id', '57255790-cd8b-4177-a24d-fd0e6bf975a2', true);
  select id into v_volk from public.voelker where betrieb_id = v_b limit 1;
  -- neuer Wert akzeptiert:
  perform public.fuetterung_erfassen(array[v_volk], current_date, 'auffuetterung',
    'zuckerwasser_3_2', 5, false);
  -- alter Wert abgelehnt (BA040):
  begin
    perform public.fuetterung_erfassen(array[v_volk], current_date, 'auffuetterung', 'zuckerwasser', 5, false);
    raise exception 'Alter futterart-Wert wurde faelschlich akzeptiert';
  exception when others then
    if sqlstate <> 'BA040' then raise; end if;
  end;
  -- Aufräumen (Testzeile hart entfernen — Ausnahme im DO-Block, kein App-Pfad):
  delete from public.fuetterungen where volk_id = v_volk and futterart = 'zuckerwasser_3_2' and menge_pro_volk_kg = 5;
  raise notice 'I02 DO-Tests OK';
end $$;
```
Expected: `I02 DO-Tests OK`. (Hinweis: `fuetterung_erfassen` bucht Material nur bei `p_material_id`; hier null → kein Lager-Effekt.)

- [ ] **Step 3: Advisors** — `get_advisors(type='security')` → 0 neue Findings (RPC bleibt SECURITY DEFINER wie zuvor).

---

### Task 5: `BetriebsEinstellungen`-Modell erweitern

**Files:** Modify `lib/features/voelker/domain/betriebs_einstellungen.dart` · Test `test/features/voelker/betriebs_einstellungen_test.dart`

- [ ] **Step 1: Failing Test**
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:bienen_app/features/voelker/domain/betriebs_einstellungen.dart';

void main() {
  test('fromJson liest Strategie-Flags; Defaults bei fehlend', () {
    final e = BetriebsEinstellungen.fromJson({
      'saison_offset_default_tage': 42, 'winterfutter_ziel_kg': 22,
      'anzahl_ernten': 2, 'sommerbehandlung_methode': 'biotechnisch', 'vermehrung_aktiv': true,
    });
    expect(e.anzahlErnten, 2);
    expect(e.sommerbehandlungMethode, 'biotechnisch');
    expect(e.vermehrungAktiv, true);
    const leer = BetriebsEinstellungen.leer();
    expect(leer.anzahlErnten, 1);
    expect(leer.sommerbehandlungMethode, 'ameisensaeure');
    expect(leer.vermehrungAktiv, false);
  });
  test('toUpdateJson enthält genau die 5 editierbaren Felder', () {
    const e = BetriebsEinstellungen(saisonOffsetDefaultTage: 42, winterfutterZielKg: 22,
      anzahlErnten: 1, sommerbehandlungMethode: 'beide', vermehrungAktiv: false);
    final j = e.toUpdateJson();
    expect(j.keys.toSet(), {'saison_offset_default_tage', 'winterfutter_ziel_kg',
      'anzahl_ernten', 'sommerbehandlung_methode', 'vermehrung_aktiv'});
    expect(j['sommerbehandlung_methode'], 'beide');
  });
}
```

- [ ] **Step 2: Run — muss scheitern.** `flutter test test/features/voelker/betriebs_einstellungen_test.dart` → FAIL (Felder fehlen).

- [ ] **Step 3: Modell erweitern** (die 3 Felder + Konstruktor-Defaults + fromJson + toUpdateJson ans bestehende `BetriebsEinstellungen` anfügen):
```dart
  // NEU als Felder:
  final int anzahlErnten;
  final String sommerbehandlungMethode;
  final bool vermehrungAktiv;
  // im const-Konstruktor ergänzen:
  //   this.anzahlErnten = 1,
  //   this.sommerbehandlungMethode = 'ameisensaeure',
  //   this.vermehrungAktiv = false,
  // in fromJson ergänzen:
  //   anzahlErnten: (j['anzahl_ernten'] as int?) ?? 1,
  //   sommerbehandlungMethode: (j['sommerbehandlung_methode'] as String?) ?? 'ameisensaeure',
  //   vermehrungAktiv: (j['vermehrung_aktiv'] as bool?) ?? false,
  // NEU:
  Map<String, dynamic> toUpdateJson() => {
        'saison_offset_default_tage': saisonOffsetDefaultTage,
        'winterfutter_ziel_kg': winterfutterZielKg,
        'anzahl_ernten': anzahlErnten,
        'sommerbehandlung_methode': sommerbehandlungMethode,
        'vermehrung_aktiv': vermehrungAktiv,
      };
```

- [ ] **Step 4: Run — grün.** `flutter test test/features/voelker/betriebs_einstellungen_test.dart` → PASS (2).

- [ ] **Step 5: Commit**
```bash
git add lib/features/voelker/domain/betriebs_einstellungen.dart test/features/voelker/betriebs_einstellungen_test.dart
git commit -m "feat(voelker): BetriebsEinstellungen +3 Strategie-Flags + toUpdateJson"
```

---

### Task 6: `Futterart` neu (Konzentrationen) + Paritäts-Test

**Files:** Modify `lib/features/fuetterung/domain/futterart.dart` · Test `test/features/fuetterung/futterart_test.dart`

- [ ] **Step 1: Failing Test** (Parität zur DB-/RPC-Whitelist als hartkodierte Referenz — wie 4.14; Kommentar mahnt Sync mit I02/F02)
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:bienen_app/features/fuetterung/domain/futterart.dart';

void main() {
  // Muss identisch zu I02-CHECK UND F02-RPC-Whitelist sein (Drift-Schutz).
  const dbUndRpc = {'zuckerwasser_1_1','zuckerwasser_3_2','invertsirup','futterteig','futterwaben','honig','sonstige'};
  test('Futterart.werte == DB-CHECK == RPC-Whitelist', () {
    expect(Futterart.werte.toSet(), dbUndRpc);
  });
  test('jeder Wert hat ein Label', () {
    for (final w in Futterart.werte) { expect(Futterart.labels[w], isNotNull); }
  });
}
```

- [ ] **Step 2: Run — muss scheitern.** FAIL (alte Werte).

- [ ] **Step 3: `Futterart` ersetzen**
```dart
/// Physische Futterform (DB-CHECK-Whitelist, Sync mit I02 + RPC F02). Bio-Status separat.
class Futterart {
  static const werte = <String>[
    'zuckerwasser_1_1', 'zuckerwasser_3_2', 'invertsirup', 'futterteig', 'futterwaben', 'honig', 'sonstige',
  ];
  static const labels = <String, String>{
    'zuckerwasser_1_1': 'Zuckerwasser 1:1 (anfüttern)',
    'zuckerwasser_3_2': 'Zuckerwasser 3:2 (Winterfutter)',
    'invertsirup': 'Invertsirup (Apiinvert)',
    'futterteig': 'Futterteig',
    'futterwaben': 'Futterwaben',
    'honig': 'Honig',
    'sonstige': 'Sonstige',
  };
}
// `Zweck`-Klasse unverändert lassen.
```

- [ ] **Step 4: Run — grün.** PASS (2).

- [ ] **Step 5: Analyse** — `flutter analyze lib/features/fuetterung` → No issues (Dropdown liest `Futterart.werte`/`labels` automatisch).

- [ ] **Step 6: Commit**
```bash
git add lib/features/fuetterung/domain/futterart.dart test/features/fuetterung/futterart_test.dart
git commit -m "feat(fuetterung): futterart Konzentrations-Whitelist + Paritätstest"
```

---

### Task 7: Generator — `SaisonRegel` Gating-Felder + `AufgabenVorschlag.beschreibung` + `beschreibungFuer` + Signatur

**Files:** Modify `lib/features/aufgaben/domain/saison_regeln.dart` · Test `test/features/aufgaben/generator_test.dart` (ergänzen)

- [ ] **Step 1: Failing Tests** (Gating + beschreibungFuer + Default-Param)
```dart
// Zusätzliche Imports oben ergänzen:
// import 'package:bienen_app/features/voelker/domain/betriebs_einstellungen.dart';

  test('Gating: jungvoelker_bilden nur bei vermehrung_aktiv', () {
    const ohne = BetriebsEinstellungen.leer(); // vermehrung=false
    const mit = BetriebsEinstellungen(vermehrungAktiv: true);
    final vOhne = anstehendeVorschlaege(stichtag: DateTime(2026, 6, 1), saisonOffsetTage: 0,
        regelAufgaben: const [], anzahlAktiveVoelker: 1, einstellungen: ohne);
    final vMit = anstehendeVorschlaege(stichtag: DateTime(2026, 6, 1), saisonOffsetTage: 0,
        regelAufgaben: const [], anzahlAktiveVoelker: 1, einstellungen: mit);
    expect(vOhne.map((x) => x.regel.key), isNot(contains('jungvoelker_bilden')));
    expect(vMit.map((x) => x.regel.key), contains('jungvoelker_bilden'));
  });

  test('Gating: honigernte_sommer nur bei anzahl_ernten=2', () {
    const eins = BetriebsEinstellungen.leer(); // anzahl_ernten=1
    const zwei = BetriebsEinstellungen(anzahlErnten: 2);
    final v1 = anstehendeVorschlaege(stichtag: DateTime(2026, 7, 5), saisonOffsetTage: 0,
        regelAufgaben: const [], anzahlAktiveVoelker: 1, einstellungen: eins);
    final v2 = anstehendeVorschlaege(stichtag: DateTime(2026, 7, 5), saisonOffsetTage: 0,
        regelAufgaben: const [], anzahlAktiveVoelker: 1, einstellungen: zwei);
    expect(v1.map((x) => x.regel.key), isNot(contains('honigernte_sommer')));
    expect(v2.map((x) => x.regel.key), contains('honigernte_sommer'));
  });

  test('beschreibungFuer: sommerbehandlung_1 je Methode', () {
    final r = kSaisonRegeln.firstWhere((x) => x.key == 'sommerbehandlung_1');
    expect(beschreibungFuer(r, const BetriebsEinstellungen(sommerbehandlungMethode: 'ameisensaeure')),
        contains('Ameisensäure'));
    expect(beschreibungFuer(r, const BetriebsEinstellungen(sommerbehandlungMethode: 'biotechnisch')),
        contains('biotechnisch'));
    // andere Regel: unverändert
    final d = kSaisonRegeln.firstWhere((x) => x.key == 'drohnenschnitt');
    expect(beschreibungFuer(d, const BetriebsEinstellungen.leer()), d.beschreibung);
  });

  test('AufgabenVorschlag trägt aufgelöste beschreibung', () {
    final v = anstehendeVorschlaege(stichtag: DateTime(2026, 7, 25), saisonOffsetTage: 0,
        regelAufgaben: const [], anzahlAktiveVoelker: 1,
        einstellungen: const BetriebsEinstellungen(sommerbehandlungMethode: 'biotechnisch'));
    final sb = v.firstWhere((x) => x.regel.key == 'sommerbehandlung_1');
    expect(sb.beschreibung, contains('biotechnisch'));
  });

  test('Default-Parameter hält Alt-Aufrufe kompilierbar (ohne einstellungen)', () {
    final v = anstehendeVorschlaege(stichtag: DateTime(2026, 6, 1), saisonOffsetTage: 0,
        regelAufgaben: const [], anzahlAktiveVoelker: 1);
    expect(v, isNotEmpty);
  });
```

- [ ] **Step 2: Run — muss scheitern.** FAIL (`einstellungen`/`beschreibungFuer`/`beschreibung` fehlen).

- [ ] **Step 3: Implementieren** — in `saison_regeln.dart`:
(a) Import ergänzen: `import 'package:bienen_app/features/voelker/domain/betriebs_einstellungen.dart';`
(b) `SaisonRegel` um 2 Felder erweitern (Konstruktor-Defaults):
```dart
  final bool nurBeiVermehrung;
  final int? nurBeiAnzahlErnten;
  // im const-Konstruktor ergänzen:
  //   this.nurBeiVermehrung = false,
  //   this.nurBeiAnzahlErnten,
```
(c) `AufgabenVorschlag` um `final String beschreibung;` erweitern (+ `required this.beschreibung,` im Konstruktor).
(d) `beschreibungFuer` NEU:
```dart
/// Auflösung des Aufgabentexts je Betriebsstrategie (heute nur sommerbehandlung_1 nach Methode).
String beschreibungFuer(SaisonRegel r, BetriebsEinstellungen e) {
  if (r.key == 'sommerbehandlung_1') {
    switch (e.sommerbehandlungMethode) {
      case 'biotechnisch':
        return '1. Sommerbehandlung biotechnisch (Brutstopp/Bannwabe/komplette Brutentnahme) — Vorbereitung ab 1. Juli-Hälfte.';
      case 'beide':
        return '1. Sommerbehandlung: Ameisensäure ODER biotechnisch (Brutstopp/Bannwabe) — nach der Ernte, vor Ende Juli.';
      default: // ameisensaeure
        return '1. Sommerbehandlung mit Ameisensäure starten (vor Ende Juli, Temperaturfenster beachten).';
    }
  }
  return r.beschreibung;
}
```
(e) `anstehendeVorschlaege`-Signatur: Parameter ergänzen
```dart
  BetriebsEinstellungen einstellungen = const BetriebsEinstellungen.leer(),
```
(f) In der Regel-Schleife nach der `ebene==volk && anzahlAktiveVoelker==0`-Zeile die Gating-Prüfung einfügen:
```dart
    if (r.nurBeiVermehrung && !einstellungen.vermehrungAktiv) continue;
    if (r.nurBeiAnzahlErnten != null && einstellungen.anzahlErnten != r.nurBeiAnzahlErnten) continue;
```
(g) Beide `out.add(AufgabenVorschlag(...))`-Aufrufe um `beschreibung: beschreibungFuer(r, einstellungen),` ergänzen.

- [ ] **Step 4: Run — grün.** `flutter test test/features/aufgaben/generator_test.dart` → PASS (bestehende + neue).

- [ ] **Step 5: Commit**
```bash
git add lib/features/aufgaben/domain/saison_regeln.dart test/features/aufgaben/generator_test.dart
git commit -m "feat(aufgaben): Generator Gating-Felder + einstellungen-Param + beschreibungFuer"
```

---

### Task 8: Generator — Timing-Härtung + neue/geänderte Regeln

**Files:** Modify `lib/features/aufgaben/domain/saison_regeln.dart` · Test `test/features/aufgaben/generator_test.dart` + `saison_regeln_test.dart`

- [ ] **Step 1: Failing Tests** (Ordnungs-Invariante 1+2 Ernten, Herbst-offset=nein, Notbehandlung vorhanden)
```dart
  // Helfer: Fällig-Default (Fensterende) einer Regel bei gegebenem Offset ableiten
  DateTime faelligVon(String key, int offset, {BetriebsEinstellungen? e}) {
    // ganzes Jahr durchsuchen: erzeuge Vorschläge zu jedem Monat, nimm den ersten Match
    for (var m = 1; m <= 12; m++) {
      final vv = anstehendeVorschlaege(stichtag: DateTime(2026, m, 1), saisonOffsetTage: offset,
          regelAufgaben: const [], anzahlAktiveVoelker: 1,
          einstellungen: e ?? const BetriebsEinstellungen.leer());
      final hit = vv.where((x) => x.regel.key == key);
      if (hit.isNotEmpty) return hit.first.faelligAm;
    }
    throw StateError('Regel $key nie sichtbar (offset $offset)');
  }

  for (final off in [0, 42]) {
    test('Ordnungs-Invariante 1-Ernte (offset $off): Ernte <= Diagnose <= Behandlung', () {
      final ernte = faelligVon('honigernte', off);
      final diag = faelligVon('gemuelldiagnose_sommer', off);
      final beh = faelligVon('sommerbehandlung_1', off);
      expect(!ernte.isAfter(diag), isTrue, reason: 'Ernte $ernte > Diagnose $diag');
      expect(!diag.isAfter(beh), isTrue, reason: 'Diagnose $diag > Behandlung $beh');
    });
    test('Ordnungs-Invariante 2-Ernten (offset $off): 2.Ernte <= Behandlung', () {
      final e2 = BetriebsEinstellungen(anzahlErnten: 2);
      final sommer = faelligVon('honigernte_sommer', off, e: e2);
      final beh = faelligVon('sommerbehandlung_1', off, e: e2);
      expect(!sommer.isAfter(beh), isTrue, reason: '2.Ernte $sommer > Behandlung $beh');
    });
  }

  test('Herbst-Regeln offset=nein: bei offset 42 nicht nach Okt/Nov', () {
    for (final key in ['umweiselung_pruefen', 'serbelvoelker_herbst', 'wabenerneuerung_herbst']) {
      final r = kSaisonRegeln.firstWhere((x) => x.key == key);
      expect(r.offsetAnwenden, isFalse, reason: '$key muss kalenderfix sein');
    }
  });

  test('Notbehandlungs-Regel varroakontrolle_fruehsommer existiert', () {
    expect(kSaisonRegeln.map((r) => r.key), contains('varroakontrolle_fruehsommer'));
  });
```
Und in `saison_regeln_test.dart` die Regel-Anzahl anpassen (aktuell 25 → **36**: 11 neue Regeln, `gemuelldiagnose_sommer` ist geändert nicht neu) sowie den bestehenden „Kategorien = DB-CHECK-Werte"-/„kein Fenster über Jahreswechsel"-Test unverändert grün halten (die 3 kalenderfixen Herbst-Regeln + Jan-Regel überschreiten den Jahreswechsel NICHT).

- [ ] **Step 2: Run — muss scheitern.** FAIL.

- [ ] **Step 3: Katalog anpassen** in `kSaisonRegeln`:
(a) `gemuelldiagnose_sommer` ersetzen (Fenster 6.6.–20.6., offset):
```dart
  SaisonRegel(key: 'gemuelldiagnose_sommer', titel: 'Gemülldiagnose nach Ernte',
      beschreibung: 'Milbenfall/Tag nach der Ernte messen — Entscheidungsgrundlage für die Sommerbehandlung.',
      kategorie: 'behandlung', ebene: RegelEbene.volk,
      startMonat: 6, startTag: 6, endMonat: 6, endTag: 20, offsetAnwenden: true, aktionRoute: 'varroa'),
```
(b) `wabenhygiene`-`beschreibung` erweitern: `'Alte, dunkle Waben ausscheiden; Boden tauschen oder reinigen. Ziel: 1/3 der Brutwaben pro Jahr erneuern (3-Jahres-Zyklus).'`
(c) `sommerbehandlung_1` **unverändert lassen** (Fenster 20.7.–15.8., kalenderfix) — der Text wird zur Laufzeit via `beschreibungFuer` aufgelöst.
(d) Folgende **neue** Regeln ergänzen (an passenden Stellen; Reihenfolge egal):
```dart
  SaisonRegel(key: 'fluglochunterlage_beobachten', titel: 'Fluglochunterlage wöchentlich beobachten',
      beschreibung: 'Windel einlegen und wöchentlich analysieren: Stummelflügel→Varroa, Kotspritzer→Nosema/Durchfall, Gemüllstreifen→Wintersitz (BGD 4.8).',
      kategorie: 'durchsicht', ebene: RegelEbene.volk,
      startMonat: 2, startTag: 1, endMonat: 3, endTag: 31, intervallTage: 7),
  SaisonRegel(key: 'serbelvoelker_fruehjahr', titel: 'Schwache/weisellose Völker beurteilen',
      beschreibung: 'Serbel-/weisellose Völker erkennen und mit Jungvölkern vereinen (BGD 4.7).',
      kategorie: 'durchsicht', ebene: RegelEbene.volk,
      startMonat: 3, startTag: 15, endMonat: 4, endTag: 20, offsetAnwenden: true),
  SaisonRegel(key: 'varroakontrolle_fruehsommer', titel: 'Milbenkontrolle Frühsommer (Notbehandlungs-Schwelle)',
      beschreibung: 'Natürlichen Milbenfall messen: Ende Mai >3 (bis 7 Optionen, >7 Notbehandlung), Juni/Juli >10 Milben/Tag → sofortige Notbehandlung (BGD 1.5.1/Varroakonzept).',
      kategorie: 'behandlung', ebene: RegelEbene.volk,
      startMonat: 5, startTag: 20, endMonat: 7, endTag: 5, offsetAnwenden: true, aktionRoute: 'varroa'),
  SaisonRegel(key: 'trachtluecke_notfuetterung', titel: 'Trachtlücke prüfen — bei Bedarf Notfütterung',
      beschreibung: 'Nektarengpass (Mitte Mai–Mitte Juli): Futtervorrat prüfen, bei Bedarf Futterteig geben (kein Zuckerwasser vor der Tracht).',
      kategorie: 'fuetterung', ebene: RegelEbene.volk,
      startMonat: 5, startTag: 25, endMonat: 7, endTag: 5, offsetAnwenden: true, aktionRoute: 'fuetterung'),
  SaisonRegel(key: 'jungvoelker_bilden', titel: 'Jungvölker/Ableger bilden (Zeitfenster)',
      beschreibung: 'Ableger/Kunstschwarm bilden — biotechnische Varroabremse; frühe Ableger (Juni) sind alpin vorzuziehen (BGD 1.4).',
      kategorie: 'durchsicht', ebene: RegelEbene.volk,
      startMonat: 5, startTag: 20, endMonat: 6, endTag: 30, offsetAnwenden: true, nurBeiVermehrung: true),
  SaisonRegel(key: 'koeniginnen_vermehren', titel: 'Königinnen vermehren (Nachschaffung)',
      beschreibung: 'Von guten Völkern nachziehen (MiniPlus/Laurenz); nur bei aktiver Vermehrung (BGD 4.6).',
      kategorie: 'durchsicht', ebene: RegelEbene.volk,
      startMonat: 5, startTag: 20, endMonat: 6, endTag: 30, offsetAnwenden: true, nurBeiVermehrung: true),
  SaisonRegel(key: 'honigernte_sommer', titel: '2. Honigernte (Sommer) — Reife prüfen',
      beschreibung: 'Sommertracht abschleudern (Verdeckelung/Wassergehalt prüfen) — vor der Sommerbehandlung.',
      kategorie: 'sonstiges', ebene: RegelEbene.volk,
      startMonat: 7, startTag: 1, endMonat: 7, endTag: 20, nurBeiAnzahlErnten: 2),
  SaisonRegel(key: 'umweiselung_pruefen', titel: 'Alte Königin ersetzen prüfen',
      beschreibung: 'Königinnen >2-jährig oder schwache Völker: Umweiselung mit begatteter Königin (letzte Möglichkeit vor Winter).',
      kategorie: 'durchsicht', ebene: RegelEbene.volk,
      startMonat: 8, startTag: 1, endMonat: 8, endTag: 31),
  SaisonRegel(key: 'wabenerneuerung_herbst', titel: 'Alte Brutwaben entnehmen (1/3-Ziel)',
      beschreibung: 'Dunkle Brutwaben ausscheiden/einschmelzen — Ziel 1/3 pro Jahr (3-Jahres-Zyklus, BGD 4.4).',
      kategorie: 'durchsicht', ebene: RegelEbene.volk,
      startMonat: 8, startTag: 15, endMonat: 9, endTag: 30),
  SaisonRegel(key: 'serbelvoelker_herbst', titel: 'Serbelvölker auflösen/abschwefeln',
      beschreibung: 'Aussichtslose Völker vor der Einwinterung auflösen/abschwefeln (BGD 4.7.2) — nicht in den Winter mitnehmen.',
      kategorie: 'durchsicht', ebene: RegelEbene.volk,
      startMonat: 9, startTag: 1, endMonat: 9, endTag: 30),
  SaisonRegel(key: 'winterbehandlung_erfolgskontrolle', titel: 'Winterbehandlung-Erfolgskontrolle (Totenfall)',
      beschreibung: 'Totenfall ~2 Wochen nach der Oxalsäure-Winterbehandlung zählen: >500 Milben → Winterbehandlung wiederholen (Sprühen/Verdampfen).',
      kategorie: 'behandlung', ebene: RegelEbene.volk,
      startMonat: 1, startTag: 1, endMonat: 1, endTag: 20, aktionRoute: 'varroa'),
```

- [ ] **Step 4: Run — grün.** `flutter test test/features/aufgaben/` → PASS (inkl. neuer Invarianten + angepasster Katalog-Anzahl).

- [ ] **Step 5: Bestandstest-Audit** — im `generator_test.dart` alle Assertions zu `gemuelldiagnose_sommer` prüfen (neues Fenster 6.6.–20.6.); der „am 19.07."-Test zu `sommerbehandlung_1` bleibt (unverändert). Falls eine `gemuelldiagnose_sommer`-Assertion durch das neue Fenster kippt, Assertion an das neue Fenster koppeln (mit Kommentar).

- [ ] **Step 6: Commit**
```bash
git add lib/features/aufgaben/domain/saison_regeln.dart test/features/aufgaben/generator_test.dart test/features/aufgaben/saison_regeln_test.dart
git commit -m "feat(aufgaben): Timing-Härtung (gemuelldiagnose offset) + 10 Regeln (Herbst kalenderfix, Notbehandlung, 2.Ernte)"
```

---

### Task 9: `aufgaben_provider` — Generator mit `einstellungen`, Annahme-Pfad mit aufgelöstem Text

**Files:** Modify `lib/features/aufgaben/presentation/providers/aufgaben_provider.dart` · Test `test/features/aufgaben/aufgaben_provider_test.dart`

- [ ] **Step 1: Failing Test** (angenommene Aufgabe trägt den aufgelösten Text)
```dart
// Import ergänzen: BetriebsEinstellungen + saison_regeln
  test('vorschlagAnnehmen persistiert aufgelöste beschreibung (Methode biotechnisch)', () async {
    final gw = FakeAufgabenGateway();
    final c = ProviderContainer(overrides: [aufgabenGatewayProvider.overrideWithValue(gw)]);
    addTearDown(c.dispose);
    await c.read(aufgabenListProvider.future);
    final r = kSaisonRegeln.firstWhere((x) => x.key == 'sommerbehandlung_1');
    final v = AufgabenVorschlag(regel: r, fensterStart: DateTime(2026, 7, 20),
        fensterEnde: DateTime(2026, 8, 15), faelligAm: DateTime(2026, 8, 15), saisonJahr: 2026,
        beschreibung: 'BIOTECH-TEXT');
    await c.read(aufgabenListProvider.notifier).vorschlagAnnehmen(v, volkIds: ['volk1']);
    final rows = await gw.alle();
    expect(rows.single.beschreibung, 'BIOTECH-TEXT');
  });
```

- [ ] **Step 2: Run — muss scheitern.** FAIL (`AufgabenVorschlag.beschreibung` fehlt im Konstruktor-Aufruf bzw. `_ausVorschlag` liest noch `v.regel.beschreibung`).

- [ ] **Step 3: Implementieren**
(a) `_ausVorschlag`: `beschreibung: v.regel.beschreibung` → `beschreibung: v.beschreibung` (titel bleibt `v.regel.titel`).
(b) `vorschlaegeProvider`: den Generator-Aufruf um `einstellungen: einst,` ergänzen:
```dart
  return anstehendeVorschlaege(
    stichtag: DateTime.now(),
    saisonOffsetTage: einst.saisonOffsetDefaultTage,
    regelAufgaben: aufgaben.where((a) => a.quelle == 'regel').toList(),
    anzahlAktiveVoelker: aktive.length,
    einstellungen: einst,
  );
```

- [ ] **Step 4: Run — grün.** `flutter test test/features/aufgaben/aufgaben_provider_test.dart` → PASS.

- [ ] **Step 5: Commit**
```bash
git add lib/features/aufgaben/presentation/providers/aufgaben_provider.dart test/features/aufgaben/aufgaben_provider_test.dart
git commit -m "feat(aufgaben): Annahme-Pfad persistiert aufgelöste beschreibung; Generator mit einstellungen"
```

---

### Task 10: Einstellungen speichern (Gateway + Notifier)

**Files:** Modify `voelker_gateway.dart`, `fake_voelker_gateway.dart`, `supabase_voelker_gateway.dart`, `voelker_provider.dart` · Test `test/features/voelker/einstellungen_speichern_test.dart`

- [ ] **Step 1: Failing Test** (Fake-Gateway + Notifier)
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bienen_app/features/voelker/data/fake_voelker_gateway.dart';
import 'package:bienen_app/features/voelker/domain/betriebs_einstellungen.dart';
import 'package:bienen_app/features/voelker/presentation/providers/voelker_provider.dart';

void main() {
  test('EinstellungenNotifier.speichern ruft Gateway + invalidiert', () async {
    final gw = FakeVoelkerGateway();
    final c = ProviderContainer(overrides: [voelkerGatewayProvider.overrideWithValue(gw)]);
    addTearDown(c.dispose);
    await c.read(betriebsEinstellungenProvider.future);
    const neu = BetriebsEinstellungen(saisonOffsetDefaultTage: 42, winterfutterZielKg: 24,
        anzahlErnten: 2, sommerbehandlungMethode: 'beide', vermehrungAktiv: true);
    await c.read(betriebsEinstellungenProvider.notifier).speichern(neu);
    final wieder = await c.read(betriebsEinstellungenProvider.future);
    expect(wieder.anzahlErnten, 2);
    expect(wieder.vermehrungAktiv, true);
  });
}
```
(FakeVoelkerGateway ggf. um ein Feld `BetriebsEinstellungen? _einst` + `einstellungenSpeichern` erweitern, das `einstellungen()` zurückliefert.)

- [ ] **Step 2: Run — muss scheitern.** FAIL (`einstellungenSpeichern`/`speichern` fehlen).

- [ ] **Step 3: Implementieren**
(a) `VoelkerGateway` (abstract): `Future<void> einstellungenSpeichern(String betriebId, BetriebsEinstellungen e);`
(b) `SupabaseVoelkerGateway`:
```dart
  @override
  Future<void> einstellungenSpeichern(String betriebId, BetriebsEinstellungen e) async {
    await _c.from('betriebs_einstellungen').update(e.toUpdateJson()).eq('betrieb_id', betriebId);
  }
```
(c) `FakeVoelkerGateway`: internes Feld halten + `einstellungen()` liefert es; `einstellungenSpeichern` überschreibt es.
(d) `EinstellungenNotifier` (in voelker_provider.dart) um `speichern` erweitern:
```dart
  Future<void> speichern(BetriebsEinstellungen e) async {
    final betriebId = ref.read(currentBetriebIdProvider);
    if (betriebId == null) return;
    await ref.read(voelkerGatewayProvider).einstellungenSpeichern(betriebId, e);
    ref.invalidateSelf();
  }
```
(Import `currentBetriebIdProvider` aus `auth_providers.dart` ergänzen.)

- [ ] **Step 4: Run — grün.** PASS.

- [ ] **Step 5: Analyse** — `flutter analyze lib/features/voelker` → No issues.

- [ ] **Step 6: Commit**
```bash
git add lib/features/voelker test/features/voelker/einstellungen_speichern_test.dart
git commit -m "feat(voelker): Betriebs-Einstellungen speichern (Gateway .eq(betrieb_id) + Notifier)"
```

---

### Task 11: Warnschwelle-Helfer + Einstellungen-Seite + Route + Projekt-Kachel

**Files:** Create `lib/features/einstellungen/domain/winterfutter_warnung.dart`, `lib/features/einstellungen/pages/einstellungen_page.dart` · Modify `app_router.dart`, `projekt_page.dart` · Test `test/features/einstellungen/winterfutter_warnung_test.dart`

- [ ] **Step 1: Failing Test** (pure Warnschwelle)
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:bienen_app/features/einstellungen/domain/winterfutter_warnung.dart';

void main() {
  test('unter 20 kg = BGD-Warnung', () {
    expect(unterBgdMinimum(19.9), isTrue);
    expect(unterBgdMinimum(20), isFalse);
    expect(unterBgdMinimum(22), isFalse);
  });
}
```

- [ ] **Step 2: Run — muss scheitern.** FAIL.

- [ ] **Step 3: Helfer implementieren**
```dart
/// BGD-Minimum Winterfutter = 20 kg (Mittelland). Darunter → UI-Warnung.
const kBgdWinterfutterMinimumKg = 20;
bool unterBgdMinimum(num zielKg) => zielKg < kBgdWinterfutterMinimumKg;
```

- [ ] **Step 4: Run — grün.** PASS.

- [ ] **Step 5: `EinstellungenPage` implementieren** (`ConsumerStatefulWidget`, Muster `aufgabe_form_page.dart`):
- Rollen-Guard: `if (!ref.watch(darfSchreibenProvider))` → read-only Ansicht.
- Lädt `betriebsEinstellungenProvider` (hasValue-Guard), initialisiert lokale State-Felder einmal.
- Felder: Saison-Offset (`TextFormField` int, Hinweis „alpin ~+42"), Winterfutter-Ziel kg (`TextFormField` num; **wenn `unterBgdMinimum(wert)` → roter Hinweis „unter BGD-Minimum 20 kg"**), Anzahl Ernten (`SegmentedButton<int>` {1,2}), Sommerbehandlung-Methode (`SegmentedButton<String>` {ameisensaeure,biotechnisch,beide}), Vermehrung aktiv (`SwitchListTile`).
- Speichern-Button → `ref.read(betriebsEinstellungenProvider.notifier).speichern(BetriebsEinstellungen(...))` in try/catch (Snackbar); bei Erfolg `context.go('/projekt')` + Erfolg-Snackbar.

- [ ] **Step 6: Route + Kachel**
- `app_router.dart`: nach dem `/projekt`-GoRoute einfügen: `GoRoute(path: '/einstellungen', builder: (c, s) => const EinstellungenPage()),` (Import ergänzen).
- `projekt_page.dart`: im `_bereiche`-Record-Array eine Kachel ergänzen: `(icon: Icons.tune, titel: 'Betriebs-Einstellungen', sub: 'Saison-Offset · Ernten · Strategie', route: '/einstellungen')`.

- [ ] **Step 7: Analyse + Test** — `flutter analyze && flutter test` → No issues · alle grün.

- [ ] **Step 8: Commit**
```bash
git add lib/features/einstellungen lib/core/router/app_router.dart lib/features/projekt/pages/projekt_page.dart test/features/einstellungen
git commit -m "feat(einstellungen): Settings-Seite (Strategie-Weichen + 20-kg-Warnschwelle) + Projekt-Kachel"
```

---

### Task 12 (optional): VorschlagKarte zeigt Fenster statt Deadline

**Files:** Modify `lib/features/aufgaben/presentation/widgets/vorschlag_karte.dart`

- [ ] **Step 1:** In der Karte den Text `bis <fällig>` ersetzen durch `<fensterStart> – <fällig>` (beide via `DateFormat('dd.MM.')`); `vorschlag.fensterStart` ist vorhanden. Kein Test nötig (reine Anzeige).
- [ ] **Step 2: Analyse** — `flutter analyze lib/features/aufgaben` → No issues.
- [ ] **Step 3: Commit**
```bash
git add lib/features/aufgaben/presentation/widgets/vorschlag_karte.dart
git commit -m "feat(aufgaben): Vorschlag-Karte zeigt Fenster statt nur Deadline"
```

---

### Task 13: Abschluss — Version, Voll-Check, Merge, Deploy

- [ ] **Step 1: Version** — `pubspec.yaml`: `version: 1.16.0+37`
- [ ] **Step 2: Voll-Check** — `flutter analyze && flutter test` → No issues · alle PASS.
- [ ] **Step 3: Committen + mergen + pushen**
```bash
git add pubspec.yaml
git commit -m "chore: Version 1.16.0+37 (Betriebsprofil & Generator-Ausbau)"
git checkout master
git merge --no-ff feat/betriebsprofil-generator -m "feat: Betriebsprofil & Generator-Ausbau (v1.16.0)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
git push origin master   # ggf. Retry bei DNS
```
- [ ] **Step 4: Deploy** — `bash deploy.sh` → „✓ Live bestaetigt" (1.16.0).
- [ ] **Step 5: Live-Smoke** — `curl -s https://danielproyer.github.io/bienen-app/version.json` → `"version":"1.16.0"`.
