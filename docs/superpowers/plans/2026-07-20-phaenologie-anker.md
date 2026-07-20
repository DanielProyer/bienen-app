# Phänologischer Anker (Baustein C) — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Der Saison-Generator leitet Termine aus beobachteter Zeigerpflanzen-Blüte ab — Frühjahr über einen phänologischen Offset, die Sommer-Behandlungskette über Ketten-Verankerung an der beobachteten Honigernte — und behebt damit die alpine Sommer-Stauchung; ohne Beobachtung bleibt alles exakt wie v1.16.0.

**Architecture:** Neues Feature `lib/features/phaenologie/` (Katalog + Modell + Gateway-Trio + Provider) nach Muster `gesundheit/`. Migration **J01** (`phaenologie_beobachtungen`, normale CRUD, Muster H01). Der Generator (`saison_regeln.dart`) bekommt pro Regel `phase` (Offset-Override) bzw. `ankerRegelKey`+`ankerVersatz*` (Ketten-Anker), eine `effektiverOffset`-Funktion mit ±60-Klemme und ein rekursives `_effektivesFenster`. Import strikt einseitig `saison_regeln → phaenologie`. UI: Phänologie-Sektion auf `/einstellungen` (eigener Inline-Save) + Honigreinheit-Hinweis im Fütterungs-Formular.

**Tech Stack:** Flutter Web, Riverpod AsyncNotifier (ohne Codegen), Supabase (PostgREST upsert, RLS), Dart-Tests (`flutter test`).

**Spec:** `docs/superpowers/specs/2026-07-20-phaenologie-anker-design.md` (v2, freigegeben). **Branch:** `feat/phaenologie` (existiert).

---

## File Structure

| Datei | Verantwortung |
|---|---|
| `supabase/migrations/J01_phaenologie_beobachtungen.sql` | Tabelle (neu, Prod-freigabepflichtig) |
| `lib/features/phaenologie/domain/phaenologie.dart` | Katalog, `PhaenoAnker`, `indikatorVon`, `doyVon`, `kMaxOffsetTage`, Honigreinheit-Funktion (pure) |
| `lib/features/phaenologie/domain/beobachtung.dart` | `PhaenoBeobachtung` + fromJson/toUpsertJson (anker-Guard, ohne betrieb_id/id) |
| `lib/features/phaenologie/domain/phaenologie_gateway.dart` | abstraktes Gateway + `PhaenologieFehler` |
| `lib/features/phaenologie/data/fake_phaenologie_gateway.dart` | In-Memory-Fake |
| `lib/features/phaenologie/data/supabase_phaenologie_gateway.dart` | PostgREST upsert/select |
| `lib/features/phaenologie/presentation/providers/phaenologie_provider.dart` | Gateway-Provider + `phaenologieProvider` (AsyncNotifier) |
| `lib/features/phaenologie/presentation/widgets/phaenologie_sektion.dart` | Einstellungen-Sub-Widget (Inline-Save) |
| `lib/features/aufgaben/domain/saison_regeln.dart` | SaisonRegel-Felder + `effektiverOffset` + `_effektivesFenster` + `trachtFensterFuer` + Regel-Zuordnung + Signatur |
| `lib/features/aufgaben/presentation/providers/aufgaben_provider.dart` | `beobachtungen` durchreichen |
| `lib/features/auth/presentation/auth_providers.dart` | `phaenologieProvider` invalidieren |
| `lib/features/einstellungen/pages/einstellungen_page.dart` | Sektion einhängen |
| `lib/features/fuetterung/presentation/pages/fuetterung_form_page.dart` | Honigreinheit-Hinweis + Prewarm |

**Test-Dateien:** `test/features/phaenologie/phaenologie_test.dart`, `beobachtung_test.dart`, `phaenologie_gateway_test.dart`; Erweiterung `test/features/aufgaben/generator_test.dart` (Phänologie-Gruppe).

---

## Task 1: Migration J01 — `phaenologie_beobachtungen`

**Files:**
- Create: `supabase/migrations/J01_phaenologie_beobachtungen.sql`

- [ ] **Step 1: SQL-Migrationsfile schreiben** (Muster H01_aufgaben.sql; immutable jahr-gebundener CHECK, kein Zusatz-Index, kein RPC/Errcode)

```sql
-- J01_phaenologie_beobachtungen.sql | Phänologie-Beobachtungen (Baustein C, Keimzelle 4.20).
-- Je Betrieb/Jahr/Anker EINE beobachtete Zeigerpflanzen-Blüte. Normale CRUD via RLS (kein RPC,
-- kein Soft-Delete, keine Errcodes). Betriebs-Ebene (kein standort_id) — Promotion auf Per-Standort
-- ist NICHT rein additiv (Unique-Rework + NULL-Distinct-/Fallback-Entscheid), siehe decision-log.
-- CHECK immutable + bindet blueh_am ans jahr (make_date) → dump/restore-sicher, keine Zukunfts-/Jahr-Drift.

create table if not exists public.phaenologie_beobachtungen (
  id uuid primary key default gen_random_uuid(),
  jahr int not null,
  anker text not null check (anker in ('fruehjahr','tracht')),
  indikator_key text not null,
  blueh_am date not null,
  betrieb_id uuid not null default private.aktive_betrieb_id()
    references public.betriebe(id) on delete cascade,
  created_by uuid, updated_by uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (betrieb_id, jahr, anker),
  constraint phaeno_jahr_chk check (jahr between 2020 and 2100),
  constraint phaeno_blueh_im_jahr_chk
    check (blueh_am >= make_date(jahr,1,1) and blueh_am <= make_date(jahr,12,31))
);
alter table public.phaenologie_beobachtungen enable row level security;
revoke all on public.phaenologie_beobachtungen from anon, public;
grant select, insert, update, delete on public.phaenologie_beobachtungen to authenticated;

drop trigger if exists trg_phaeno_actor on public.phaenologie_beobachtungen;
create trigger trg_phaeno_actor before insert or update
  on public.phaenologie_beobachtungen for each row execute function private.set_row_actor();
drop trigger if exists trg_phaeno_updated on public.phaenologie_beobachtungen;
create trigger trg_phaeno_updated before update
  on public.phaenologie_beobachtungen for each row execute function private.set_updated_at();

drop policy if exists phaeno_sel_member on public.phaenologie_beobachtungen;
create policy phaeno_sel_member on public.phaenologie_beobachtungen
  for select to authenticated using (betrieb_id in (select private.meine_betrieb_ids()));
drop policy if exists phaeno_ins_writer on public.phaenologie_beobachtungen;
create policy phaeno_ins_writer on public.phaenologie_beobachtungen
  for insert to authenticated with check (private.kann_schreiben(betrieb_id));
drop policy if exists phaeno_upd_writer on public.phaenologie_beobachtungen;
create policy phaeno_upd_writer on public.phaenologie_beobachtungen
  for update to authenticated using (private.kann_schreiben(betrieb_id))
  with check (private.kann_schreiben(betrieb_id));
drop policy if exists phaeno_del_writer on public.phaenologie_beobachtungen;
create policy phaeno_del_writer on public.phaenologie_beobachtungen
  for delete to authenticated using (private.kann_schreiben(betrieb_id));

-- ROLLBACK (Ops, kein Migrationsfile): drop table public.phaenologie_beobachtungen;
```

- [ ] **Step 2: Migration auf Produktion anwenden** (⚠️ FREIGABEPFLICHTIG — nur nach expliziter User-Zustimmung für J01)

Via Supabase-MCP `apply_migration` (Projekt `dcdcohktxbhdxnxjvcyp`, name `J01_phaenologie_beobachtungen`, query = obiger SQL-Body).

- [ ] **Step 3: Migration verifizieren**

`list_tables` (Schema public) → `phaenologie_beobachtungen` existiert mit 4 Policies + 2 Triggern. `get_advisors(security)` → 0 neue Findings. Ein Katalog-Query auf `pg_constraint` bestätigt `phaeno_blueh_im_jahr_chk` + `phaeno_jahr_chk`.

- [ ] **Step 4: Commit**

```bash
git add supabase/migrations/J01_phaenologie_beobachtungen.sql
git commit -m "feat(phaenologie): Migration J01 phaenologie_beobachtungen"
```

---

## Task 2: Domain `phaenologie.dart` — Katalog + DOY + Honigreinheit (pure)

**Files:**
- Create: `lib/features/phaenologie/domain/phaenologie.dart`
- Test: `test/features/phaenologie/phaenologie_test.dart`

- [ ] **Step 1: Failing test schreiben**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:bienen_app/features/phaenologie/domain/phaenologie.dart';

void main() {
  test('Katalog-Invarianten: je Anker >=1, Defaults existieren + anker stimmt, referenzDoy 1..366', () {
    expect(indikatorenFuer(PhaenoAnker.fruehjahr), isNotEmpty);
    expect(indikatorenFuer(PhaenoAnker.tracht), isNotEmpty);
    final df = indikatorVon(kDefaultIndikatorFruehjahr);
    final dt = indikatorVon(kDefaultIndikatorTracht);
    expect(df?.anker, PhaenoAnker.fruehjahr);
    expect(dt?.anker, PhaenoAnker.tracht);
    for (final i in kIndikatorpflanzen) {
      expect(i.referenzDoy, inInclusiveRange(1, 366), reason: i.key);
    }
    expect(indikatorVon('gibtsnicht'), isNull);
  });

  test('doyVon: DST-immun, Schaltjahr-tolerant', () {
    expect(doyVon(DateTime(2026, 1, 1)), 1);
    expect(doyVon(DateTime(2026, 3, 15)), 74);   // Nicht-Schaltjahr: salweide-Referenz
    expect(doyVon(DateTime(2026, 6, 9)), 160);   // alpenrose-Referenz
    expect(doyVon(DateTime(2024, 2, 29)), 60);   // Schaltjahr kein Crash
    expect(doyVon(DateTime(2024, 3, 15)), 75);   // Schaltjahr: +1 nach 29.2.
  });

  test('honigreinheitHinweis: nur mit Fenster + gewarnter Futterart im Fenster', () {
    final fenster = (DateTime(2026, 6, 15), DateTime(2026, 7, 25));
    // kein Fenster -> nie
    expect(honigreinheitHinweis(futterart: 'invertsirup', zweck: 'auffuetterung',
        datum: DateTime(2026, 7, 1), trachtFenster: null), HonigreinheitHinweis.keiner);
    // Zucker (3:2) im Fenster -> Verfälschung
    expect(honigreinheitHinweis(futterart: 'zuckerwasser_3_2', zweck: 'auffuetterung',
        datum: DateTime(2026, 7, 1), trachtFenster: fenster), HonigreinheitHinweis.verfaelschung);
    // Notfütterung -> weicherer Hinweis
    expect(honigreinheitHinweis(futterart: 'invertsirup', zweck: 'notfuetterung',
        datum: DateTime(2026, 7, 1), trachtFenster: fenster), HonigreinheitHinweis.notfuetterung);
    // zuckerwasser_1_1 (Jungvolk-Anfüttern) -> kein Fehlalarm
    expect(honigreinheitHinweis(futterart: 'zuckerwasser_1_1', zweck: 'auffuetterung',
        datum: DateTime(2026, 7, 1), trachtFenster: fenster), HonigreinheitHinweis.keiner);
    // ausserhalb Fenster -> nie
    expect(honigreinheitHinweis(futterart: 'invertsirup', zweck: 'auffuetterung',
        datum: DateTime(2026, 9, 1), trachtFenster: fenster), HonigreinheitHinweis.keiner);
  });
}
```

- [ ] **Step 2: Test rot laufen lassen**

Run: `cd bienen_app && flutter test test/features/phaenologie/phaenologie_test.dart`
Expected: FAIL (Datei/Symbole existieren nicht).

- [ ] **Step 3: `phaenologie.dart` implementieren**

```dart
/// Phänologie-Fachkonstante (Muster krankheit.dart, pure, KEIN DB-Seed).
/// Importiert bewusst NICHT aufgaben/domain — die Abhängigkeit ist strikt einseitig
/// (saison_regeln.dart -> phaenologie.dart).
library;

enum PhaenoAnker { fruehjahr, tracht }

class Indikatorpflanze {
  final String key;
  final String name;
  final PhaenoAnker anker;
  /// Kalibrier-DOY am Referenzstandort (Mittelland-nah), bei dem Offset 0 die Basis-Regelfenster
  /// trifft. Als NICHT-SCHALTJAHR-DOY definiert (in Schaltjahren driftet der Offset für Anker nach
  /// dem 29.2. um max. 1 Tag — operativ vernachlässigbar). Richtwerte → Fachstellen-Check.
  final int referenzDoy;
  const Indikatorpflanze({required this.key, required this.name, required this.anker, required this.referenzDoy});
}

const kIndikatorpflanzen = <Indikatorpflanze>[
  // Frühjahr — treibt die Frühjahrs-/Aufbauregeln (Offset). Alle bis in Hochlagen beobachtbar.
  Indikatorpflanze(key: 'salweide',      name: 'Sal-Weide',            anker: PhaenoAnker.fruehjahr, referenzDoy: 74),  // ~15.3.
  Indikatorpflanze(key: 'kirschbluete',  name: 'Kirschblüte',          anker: PhaenoAnker.fruehjahr, referenzDoy: 110), // ~20.4.
  Indikatorpflanze(key: 'loewenzahn',    name: 'Löwenzahn',            anker: PhaenoAnker.fruehjahr, referenzDoy: 115), // ~25.4. (Default)
  // Tracht — treibt Honigernte + (per Kette) Varroa-Sommerbehandlung. Hochlagen-Zeiger zuerst.
  Indikatorpflanze(key: 'alpenrose',     name: 'Alpenrose',            anker: PhaenoAnker.tracht,    referenzDoy: 160), // Hochlagen-Haupttracht (Default)
  Indikatorpflanze(key: 'bergwiesen',    name: 'Bergwiesen-Vollblüte', anker: PhaenoAnker.tracht,    referenzDoy: 160),
  Indikatorpflanze(key: 'weidenroeschen',name: 'Weidenröschen',        anker: PhaenoAnker.tracht,    referenzDoy: 175),
  Indikatorpflanze(key: 'linde',         name: 'Linde',                anker: PhaenoAnker.tracht,    referenzDoy: 176), // Tal (~25.6.)
  Indikatorpflanze(key: 'edelkastanie',  name: 'Edelkastanie',         anker: PhaenoAnker.tracht,    referenzDoy: 182), // Tal (~1.7.)
];

const kDefaultIndikatorFruehjahr = 'loewenzahn';
const kDefaultIndikatorTracht = 'alpenrose';

/// Max. Betrag des phänologischen Offsets (Defense-in-Depth gegen Fehleingaben).
const kMaxOffsetTage = 60;

/// Katalog-Lookup (null bei unbekanntem/fehlendem Key — Drift-tolerant).
Indikatorpflanze? indikatorVon(String? key) {
  if (key == null) return null;
  for (final i in kIndikatorpflanzen) {
    if (i.key == key) return i;
  }
  return null;
}

/// Zeiger eines Ankers (für das gefilterte Dropdown).
List<Indikatorpflanze> indikatorenFuer(PhaenoAnker anker) =>
    kIndikatorpflanzen.where((i) => i.anker == anker).toList();

/// Tag im Jahr (1..366). Rein integer → DST-immun (keine Duration über Zeitumstellung).
int doyVon(DateTime d) {
  const kum = [0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334];
  final istSchalt = (d.year % 4 == 0 && (d.year % 100 != 0 || d.year % 400 == 0));
  final schalt = (istSchalt && d.month > 2) ? 1 : 0;
  return kum[d.month - 1] + d.day + schalt;
}

/// Ergebnis der Honigreinheit-Prüfung (weicher Inline-Hinweis im Fütterungs-Formular).
enum HonigreinheitHinweis { keiner, verfaelschung, notfuetterung }

// zuckerwasser_1_1 (Jungvolk-Anfüttern, i. d. R. kein Honigraum) bewusst NICHT gewarnt → kein Fehlalarm.
const _kGewarnteFutterarten = {'zuckerwasser_3_2', 'invertsirup', 'futterteig'};

/// Zuckerfütterung während der (beobachteten) Tracht kann den erntbaren Honig verfälschen (BGD 4.2).
/// Feuert NUR, wenn eine Tracht-Beobachtung existiert ([trachtFenster] != null).
HonigreinheitHinweis honigreinheitHinweis({
  required String futterart,
  required String zweck,
  required DateTime datum,
  required (DateTime, DateTime)? trachtFenster,
}) {
  if (trachtFenster == null) return HonigreinheitHinweis.keiner;
  if (!_kGewarnteFutterarten.contains(futterart)) return HonigreinheitHinweis.keiner;
  final t = DateTime(datum.year, datum.month, datum.day);
  if (t.isBefore(trachtFenster.$1) || t.isAfter(trachtFenster.$2)) return HonigreinheitHinweis.keiner;
  return zweck == 'notfuetterung' ? HonigreinheitHinweis.notfuetterung : HonigreinheitHinweis.verfaelschung;
}
```

- [ ] **Step 4: Test grün laufen lassen**

Run: `cd bienen_app && flutter test test/features/phaenologie/phaenologie_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/phaenologie/domain/phaenologie.dart test/features/phaenologie/phaenologie_test.dart
git commit -m "feat(phaenologie): Indikator-Katalog, doyVon, Honigreinheit-Regel (pure)"
```

---

## Task 3: Domain `beobachtung.dart` — Modell + Serialisierung (anker-Guard)

**Files:**
- Create: `lib/features/phaenologie/domain/beobachtung.dart`
- Test: `test/features/phaenologie/beobachtung_test.dart`

- [ ] **Step 1: Failing test schreiben**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:bienen_app/features/phaenologie/domain/phaenologie.dart';
import 'package:bienen_app/features/phaenologie/domain/beobachtung.dart';

void main() {
  test('fromJson/toUpsertJson: nur 4 Felder, kein betrieb_id/id', () {
    final b = PhaenoBeobachtung.fromJson({
      'id': 'x', 'betrieb_id': 'b1', 'jahr': 2026, 'anker': 'tracht',
      'indikator_key': 'alpenrose', 'blueh_am': '2026-06-14',
    });
    expect(b.anker, PhaenoAnker.tracht);
    expect(b.bluehAm, DateTime(2026, 6, 14));
    final j = b.toUpsertJson();
    expect(j.keys.toSet(), {'jahr', 'anker', 'indikator_key', 'blueh_am'});
    expect(j['anker'], 'tracht');
    expect(j['blueh_am'], '2026-06-14');
  });

  test('toUpsertJson: anker-Guard (tracht-Key auf fruehjahr-Anker -> AssertionError)', () {
    final falsch = PhaenoBeobachtung(
        jahr: 2026, anker: PhaenoAnker.fruehjahr, indikatorKey: 'alpenrose', bluehAm: DateTime(2026, 6, 14));
    expect(() => falsch.toUpsertJson(), throwsA(isA<AssertionError>()));
  });
}
```

- [ ] **Step 2: Test rot laufen lassen**

Run: `cd bienen_app && flutter test test/features/phaenologie/beobachtung_test.dart`
Expected: FAIL.

- [ ] **Step 3: `beobachtung.dart` implementieren**

```dart
import 'package:bienen_app/features/phaenologie/domain/phaenologie.dart';

/// Eine beobachtete Zeigerpflanzen-Blüte (je Betrieb/Jahr/Anker eindeutig).
/// Trägt bewusst KEIN betrieb_id/id — die setzt die DB (Default aktive_betrieb_id()).
class PhaenoBeobachtung {
  final int jahr;
  final PhaenoAnker anker;
  final String indikatorKey;
  final DateTime bluehAm;
  const PhaenoBeobachtung({
    required this.jahr,
    required this.anker,
    required this.indikatorKey,
    required this.bluehAm,
  });

  factory PhaenoBeobachtung.fromJson(Map<String, dynamic> j) => PhaenoBeobachtung(
        jahr: j['jahr'] as int,
        anker: (j['anker'] as String) == 'tracht' ? PhaenoAnker.tracht : PhaenoAnker.fruehjahr,
        indikatorKey: j['indikator_key'] as String,
        bluehAm: DateTime.parse(j['blueh_am'] as String),
      );

  /// NUR die vier fachlichen Felder — betrieb_id/id werden WEGGELASSEN (nicht null gesetzt),
  /// damit der DB-Default private.aktive_betrieb_id() greift. anker-Guard verhindert stillen
  /// Fehl-Offset (tracht-Key auf fruehjahr-Anker o. ä.).
  Map<String, dynamic> toUpsertJson() {
    assert(indikatorVon(indikatorKey)?.anker == anker,
        'indikatorKey "$indikatorKey" passt nicht zum anker $anker');
    final d = bluehAm;
    final iso = '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    return {
      'jahr': jahr,
      'anker': anker == PhaenoAnker.tracht ? 'tracht' : 'fruehjahr',
      'indikator_key': indikatorKey,
      'blueh_am': iso,
    };
  }
}
```

- [ ] **Step 4: Test grün laufen lassen**

Run: `cd bienen_app && flutter test test/features/phaenologie/beobachtung_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/phaenologie/domain/beobachtung.dart test/features/phaenologie/beobachtung_test.dart
git commit -m "feat(phaenologie): PhaenoBeobachtung-Modell (toUpsertJson mit anker-Guard)"
```

---

## Task 4: Gateway-Trio (abstrakt + Fake + Supabase)

**Files:**
- Create: `lib/features/phaenologie/domain/phaenologie_gateway.dart`
- Create: `lib/features/phaenologie/data/fake_phaenologie_gateway.dart`
- Create: `lib/features/phaenologie/data/supabase_phaenologie_gateway.dart`
- Test: `test/features/phaenologie/phaenologie_gateway_test.dart`

- [ ] **Step 1: Failing test schreiben** (Fake-Roundtrip: upsert dedupt je jahr/anker)

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:bienen_app/features/phaenologie/domain/phaenologie.dart';
import 'package:bienen_app/features/phaenologie/domain/beobachtung.dart';
import 'package:bienen_app/features/phaenologie/data/fake_phaenologie_gateway.dart';

void main() {
  test('Fake: upsert dedupt je (jahr, anker)', () async {
    final gw = FakePhaenologieGateway();
    await gw.upsert(PhaenoBeobachtung(jahr: 2026, anker: PhaenoAnker.tracht, indikatorKey: 'alpenrose', bluehAm: DateTime(2026, 6, 14)));
    await gw.upsert(PhaenoBeobachtung(jahr: 2026, anker: PhaenoAnker.tracht, indikatorKey: 'linde', bluehAm: DateTime(2026, 6, 20)));
    await gw.upsert(PhaenoBeobachtung(jahr: 2026, anker: PhaenoAnker.fruehjahr, indikatorKey: 'loewenzahn', bluehAm: DateTime(2026, 4, 30)));
    final alle = await gw.alle();
    expect(alle.length, 2); // tracht überschrieben, fruehjahr separat
    final tracht = alle.firstWhere((b) => b.anker == PhaenoAnker.tracht);
    expect(tracht.indikatorKey, 'linde');
  });
}
```

- [ ] **Step 2: Test rot laufen lassen**

Run: `cd bienen_app && flutter test test/features/phaenologie/phaenologie_gateway_test.dart`
Expected: FAIL.

- [ ] **Step 3: Gateway (abstrakt) implementieren** — `phaenologie_gateway.dart`

```dart
import 'package:bienen_app/features/phaenologie/domain/beobachtung.dart';

class PhaenologieFehler implements Exception {
  final String code;
  final String message;
  const PhaenologieFehler(this.code, this.message);
  @override
  String toString() => message;
}

abstract class PhaenologieGateway {
  /// Alle Beobachtungen des aktiven Betriebs (RLS filtert nach betrieb_id).
  Future<List<PhaenoBeobachtung>> alle();

  /// Upsert je (betrieb_id, jahr, anker) — überschreibt eine bestehende Zeile.
  Future<void> upsert(PhaenoBeobachtung b);
}
```

- [ ] **Step 4: Fake implementieren** — `fake_phaenologie_gateway.dart`

```dart
import 'package:bienen_app/features/phaenologie/domain/beobachtung.dart';
import 'package:bienen_app/features/phaenologie/domain/phaenologie_gateway.dart';

class FakePhaenologieGateway implements PhaenologieGateway {
  final _map = <String, PhaenoBeobachtung>{}; // key = '$jahr-$anker'
  String _k(PhaenoBeobachtung b) => '${b.jahr}-${b.anker.name}';

  @override
  Future<List<PhaenoBeobachtung>> alle() async => _map.values.toList();

  @override
  Future<void> upsert(PhaenoBeobachtung b) async => _map[_k(b)] = b;
}
```

- [ ] **Step 5: Supabase-Gateway implementieren** — `supabase_phaenologie_gateway.dart`

```dart
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:bienen_app/features/phaenologie/domain/beobachtung.dart';
import 'package:bienen_app/features/phaenologie/domain/phaenologie_gateway.dart';

class SupabasePhaenologieGateway implements PhaenologieGateway {
  final SupabaseClient _c;
  SupabasePhaenologieGateway(this._c);

  Never _rethrow(Object e) {
    if (e is PostgrestException && e.code != null) {
      throw PhaenologieFehler(e.code!, e.message);
    }
    throw e;
  }

  @override
  Future<List<PhaenoBeobachtung>> alle() async {
    try {
      final res = await _c.from('phaenologie_beobachtungen').select();
      return (res as List)
          .map((j) => PhaenoBeobachtung.fromJson(j as Map<String, dynamic>))
          .toList();
    } catch (e) {
      _rethrow(e);
    }
  }

  @override
  Future<void> upsert(PhaenoBeobachtung b) async {
    try {
      await _c
          .from('phaenologie_beobachtungen')
          .upsert(b.toUpsertJson(), onConflict: 'betrieb_id,jahr,anker');
    } catch (e) {
      _rethrow(e);
    }
  }
}
```

- [ ] **Step 6: Test grün laufen lassen**

Run: `cd bienen_app && flutter test test/features/phaenologie/phaenologie_gateway_test.dart`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add lib/features/phaenologie/domain/phaenologie_gateway.dart lib/features/phaenologie/data/ test/features/phaenologie/phaenologie_gateway_test.dart
git commit -m "feat(phaenologie): Gateway-Trio (abstrakt/Fake/Supabase, upsert onConflict)"
```

---

## Task 5: Provider `phaenologie_provider.dart`

**Files:**
- Create: `lib/features/phaenologie/presentation/providers/phaenologie_provider.dart`

- [ ] **Step 1: Provider implementieren** (Muster gesundheit_provider.dart; kein eigener Test — über UI/Generator abgedeckt)

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bienen_app/core/supabase/supabase_config.dart';
import 'package:bienen_app/features/phaenologie/data/supabase_phaenologie_gateway.dart';
import 'package:bienen_app/features/phaenologie/domain/beobachtung.dart';
import 'package:bienen_app/features/phaenologie/domain/phaenologie_gateway.dart';

final phaenologieGatewayProvider =
    Provider<PhaenologieGateway>((ref) => SupabasePhaenologieGateway(SupabaseConfig.client));

final phaenologieProvider =
    AsyncNotifierProvider<PhaenologieNotifier, List<PhaenoBeobachtung>>(PhaenologieNotifier.new);

class PhaenologieNotifier extends AsyncNotifier<List<PhaenoBeobachtung>> {
  PhaenologieGateway get _gw => ref.read(phaenologieGatewayProvider);
  @override
  Future<List<PhaenoBeobachtung>> build() => _gw.alle();

  Future<void> speichern(PhaenoBeobachtung b) async {
    await _gw.upsert(b);
    ref.invalidateSelf();
  }
}
```

- [ ] **Step 2: analyze**

Run: `cd bienen_app && flutter analyze lib/features/phaenologie`
Expected: No issues.

- [ ] **Step 3: Commit**

```bash
git add lib/features/phaenologie/presentation/providers/phaenologie_provider.dart
git commit -m "feat(phaenologie): phaenologieProvider (AsyncNotifier + speichern)"
```

---

## Task 6: Generator — SaisonRegel-Felder + `effektiverOffset` (±60-Klemme)

**Files:**
- Modify: `lib/features/aufgaben/domain/saison_regeln.dart` (SaisonRegel-Klasse Z.14-43; Import Z.9-10)
- Test: `test/features/aufgaben/generator_test.dart` (neue Gruppe anhängen)

- [ ] **Step 1: Failing test schreiben** (ans Ende von `generator_test.dart`, in `main()`)

```dart
  group('Phänologie: effektiverOffset', () {
    final loewenzahn = kSaisonRegeln.firstWhere((r) => r.key == 'fruehjahrsdurchsicht'); // phase=fruehjahr (nach Task 7)
    test('Beobachtung -> DOY-Differenz, geklemmt auf ±60', () {
      // Löwenzahn referenzDoy 115; Blüte 6.6. (DOY 157) -> +42
      final b = PhaenoBeobachtung(jahr: 2026, anker: PhaenoAnker.fruehjahr, indikatorKey: 'loewenzahn', bluehAm: DateTime(2026, 6, 6));
      expect(effektiverOffset(regel: loewenzahn, saisonJahr: 2026, beobachtungen: [b], flatOffset: 0), 42);
      // Fehleingabe 5.2. (DOY 36) -> -79 -> geklemmt auf -60
      final falsch = PhaenoBeobachtung(jahr: 2026, anker: PhaenoAnker.fruehjahr, indikatorKey: 'loewenzahn', bluehAm: DateTime(2026, 2, 5));
      expect(effektiverOffset(regel: loewenzahn, saisonJahr: 2026, beobachtungen: [falsch], flatOffset: 0), -60);
    });
    test('keine passende Beobachtung -> flatOffset (offsetAnwenden) bzw. 0', () {
      expect(effektiverOffset(regel: loewenzahn, saisonJahr: 2026, beobachtungen: const [], flatOffset: 42), 42);
      final kalenderfix = kSaisonRegeln.firstWhere((r) => r.key == 'sommerbehandlung_2');
      expect(effektiverOffset(regel: kalenderfix, saisonJahr: 2026, beobachtungen: const [], flatOffset: 42), 0);
    });
    test('anker-Mismatch (tracht-Key auf fruehjahr-Regel) -> Fallback', () {
      final b = PhaenoBeobachtung(jahr: 2026, anker: PhaenoAnker.fruehjahr, indikatorKey: 'alpenrose', bluehAm: DateTime(2026, 6, 14));
      // indikatorVon('alpenrose').anker == tracht != fruehjahr -> Fallback flatOffset
      expect(effektiverOffset(regel: loewenzahn, saisonJahr: 2026, beobachtungen: [b], flatOffset: 42), 42);
    });
  });
```

Ergänze oben in `generator_test.dart` die Imports:
```dart
import 'package:bienen_app/features/phaenologie/domain/phaenologie.dart';
import 'package:bienen_app/features/phaenologie/domain/beobachtung.dart';
```

- [ ] **Step 2: Test rot laufen lassen**

Run: `cd bienen_app && flutter test test/features/aufgaben/generator_test.dart --plain-name "effektiverOffset"`
Expected: FAIL (`effektiverOffset` unbekannt; `phase` unbekannt).

- [ ] **Step 3: SaisonRegel-Felder + Import ergänzen** — in `saison_regeln.dart`

Import ergänzen (nach Z.10):
```dart
import 'package:bienen_app/features/phaenologie/domain/phaenologie.dart';
import 'package:bienen_app/features/phaenologie/domain/beobachtung.dart';
```

In `class SaisonRegel` die Felder ergänzen (nach `nurBeiAnzahlErnten`):
```dart
  /// Offset-Override-Phase (fruehjahr|tracht); null = kein phänologischer Offset-Override.
  final PhaenoAnker? phase;
  /// Ketten-Anker: Key der Regel, an deren effektives Ende diese Regel hängt (nur bei Tracht-Beobachtung).
  /// Sentinel '__letzte_ernte' -> honigernte_sommer (bei 2 Ernten) bzw. honigernte.
  final String? ankerRegelKey;
  final int ankerVersatzStartTage;
  final int ankerVersatzEndeTage;
```

Konstruktor-Parameter ergänzen (nach `this.nurBeiAnzahlErnten,`):
```dart
    this.phase,
    this.ankerRegelKey,
    this.ankerVersatzStartTage = 0,
    this.ankerVersatzEndeTage = 0,
```

- [ ] **Step 4: `effektiverOffset` + `_beobachtungFuer` implementieren** — in `saison_regeln.dart` (nach `regelVon`)

```dart
/// Beobachtung für ein Kandidatenjahr + Anker (Inline-Helper statt package:collection).
PhaenoBeobachtung? _beobachtungFuer(List<PhaenoBeobachtung> bs, int jahr, PhaenoAnker anker) {
  for (final b in bs) {
    if (b.jahr == jahr && b.anker == anker) return b;
  }
  return null;
}

/// Effektiver Offset (Tage) einer Regel für ein Kandidatenjahr:
/// - phänologisch (beobachtete Blüte − referenzDoy, geklemmt ±kMaxOffsetTage), wenn eine
///   zum Anker passende Beobachtung vorliegt;
/// - sonst A+B-Baseline (flacher Offset wenn offsetAnwenden, sonst 0).
int effektiverOffset({
  required SaisonRegel regel,
  required int saisonJahr,
  required List<PhaenoBeobachtung> beobachtungen,
  required int flatOffset,
}) {
  final phase = regel.phase;
  if (phase != null) {
    final b = _beobachtungFuer(beobachtungen, saisonJahr, phase);
    final ind = b == null ? null : indikatorVon(b.indikatorKey);
    if (b != null && ind != null && ind.anker == phase) {
      final off = doyVon(b.bluehAm) - ind.referenzDoy;
      return off.clamp(-kMaxOffsetTage, kMaxOffsetTage);
    }
  }
  return regel.offsetAnwenden ? flatOffset : 0;
}
```

- [ ] **Step 5: Test grün laufen lassen** (die neue Gruppe; Regel-`phase` wird in Task 7 gesetzt — dieser Test nutzt `fruehjahrsdurchsicht`, das erst in Task 7 phase=fruehjahr bekommt)

> **Hinweis Reihenfolge:** Der `effektiverOffset`-Test verlangt `phase` auf `fruehjahrsdurchsicht`. Setze daher in DIESEM Step schon `phase: PhaenoAnker.fruehjahr` bei `fruehjahrsdurchsicht` (die restliche Zuordnung folgt in Task 7). Danach:

Run: `cd bienen_app && flutter test test/features/aufgaben/generator_test.dart --plain-name "effektiverOffset"`
Expected: PASS.

- [ ] **Step 6: Bestandstests grün halten**

Run: `cd bienen_app && flutter test test/features/aufgaben/generator_test.dart`
Expected: PASS (alle bestehenden + neue).

- [ ] **Step 7: Commit**

```bash
git add lib/features/aufgaben/domain/saison_regeln.dart test/features/aufgaben/generator_test.dart
git commit -m "feat(generator): SaisonRegel +phase/ankerRegelKey/versatz + effektiverOffset (±60-Klemme)"
```

---

## Task 7: Generator — Ketten-Anker + Regel-Zuordnung + Signatur

**Files:**
- Modify: `lib/features/aufgaben/domain/saison_regeln.dart` (Regeln Z.45-194; Generator Z.251-304)
- Test: `test/features/aufgaben/generator_test.dart`

- [ ] **Step 1: Failing tests schreiben** (Kette + Ordnung + Cross-Phasen + Rückwärtskompatibilität)

```dart
  group('Phänologie: Ketten-Anker', () {
    // Alpenrose 14.6. (DOY 165), referenzDoy 160 -> honigernte-Offset +5
    final trachtBeob = [PhaenoBeobachtung(jahr: 2026, anker: PhaenoAnker.tracht, indikatorKey: 'alpenrose', bluehAm: DateTime(2026, 6, 14))];

    List<AufgabenVorschlag> lauf({List<PhaenoBeobachtung> beob = const [], BetriebsEinstellungen? e, DateTime? stichtag}) =>
        anstehendeVorschlaege(
          stichtag: stichtag ?? DateTime(2026, 7, 1),
          saisonOffsetTage: 42,
          regelAufgaben: const [],
          anzahlAktiveVoelker: 1,
          einstellungen: e ?? const BetriebsEinstellungen.leer(),
          beobachtungen: beob,
        );

    DateTime faellig(List<AufgabenVorschlag> v, String key) =>
        v.firstWhere((x) => x.regel.key == key).faelligAm;

    test('Rückwärtskompatibilität: ohne Beobachtung sommerbehandlung_1 kalenderfix 15.8.', () {
      final v = lauf();
      expect(faellig(v, 'sommerbehandlung_1'), DateTime(2026, 8, 15));
    });

    test('Mit Tracht-Beobachtung: sommerbehandlung_1 folgt der Ernte (Ende Juli, nicht 15.8.)', () {
      final v = lauf(beob: trachtBeob, stichtag: DateTime(2026, 6, 20));
      final beh = faellig(v, 'sommerbehandlung_1');
      expect(beh.month, 7); // Ende Juli statt 15.8.
      expect(beh.isBefore(DateTime(2026, 8, 1)), isTrue);
    });

    test('Ordnung mit Beobachtung: honigernte <= gemuelldiagnose_sommer <= sommerbehandlung_1', () {
      final v = lauf(beob: trachtBeob, stichtag: DateTime(2026, 6, 1));
      final e = faellig(v, 'honigernte');
      final d = faellig(v, 'gemuelldiagnose_sommer');
      final b = faellig(v, 'sommerbehandlung_1');
      expect(e.isAfter(d), isFalse);
      expect(d.isAfter(b), isFalse);
    });

    test('2-Ernten: __letzte_ernte -> honigernte_sommer; Behandlung nach der 2. Ernte', () {
      final e2 = const BetriebsEinstellungen(anzahlErnten: 2);
      final v = lauf(beob: trachtBeob, e: e2, stichtag: DateTime(2026, 6, 1));
      final sommer = faellig(v, 'honigernte_sommer');
      final beh = faellig(v, 'sommerbehandlung_1');
      expect(beh.isBefore(sommer), isFalse);
    });

    test('Cross-Phasen bei Teil-Beobachtung: nur Frühjahr -> honigraum_aufsetzen <= honigernte', () {
      final nurFr = [PhaenoBeobachtung(jahr: 2026, anker: PhaenoAnker.fruehjahr, indikatorKey: 'loewenzahn', bluehAm: DateTime(2026, 6, 10))];
      final v = lauf(beob: nurFr, stichtag: DateTime(2026, 4, 1));
      final auf = faellig(v, 'honigraum_aufsetzen');
      final ernte = faellig(v, 'honigernte');
      expect(auf.isAfter(ernte), isFalse);
    });
  });
```

- [ ] **Step 2: Test rot laufen lassen**

Run: `cd bienen_app && flutter test test/features/aufgaben/generator_test.dart --plain-name "Ketten-Anker"`
Expected: FAIL (Regeln haben noch keine phase/anker; Generator kennt beobachtungen nicht).

- [ ] **Step 3: `_effektivesFenster` + Auflösung implementieren** — in `saison_regeln.dart` (vor `anstehendeVorschlaege`)

```dart
bool _hatTrachtBeobachtung(List<PhaenoBeobachtung> bs, int jahr) =>
    _beobachtungFuer(bs, jahr, PhaenoAnker.tracht) != null;

String _ankerKeyAufloesen(String ankerRegelKey, BetriebsEinstellungen e) =>
    ankerRegelKey == '__letzte_ernte'
        ? (e.anzahlErnten == 2 ? 'honigernte_sommer' : 'honigernte')
        : ankerRegelKey;

/// Effektives [start, ende]-Fenster einer Regel für ein Kandidatenjahr.
/// Ketten-Anker greift NUR bei vorhandener Tracht-Beobachtung (sonst A+B-Basisfenster + Offset).
/// Rekursion terminiert: __letzte_ernte -> honigernte(_sommer) -> honigernte (kein ankerRegelKey).
(DateTime, DateTime) _effektivesFenster(
  SaisonRegel r,
  int jahr, {
  required int flatOffset,
  required List<PhaenoBeobachtung> beobachtungen,
  required BetriebsEinstellungen einstellungen,
}) {
  if (r.ankerRegelKey != null && _hatTrachtBeobachtung(beobachtungen, jahr)) {
    final anker = regelVon(_ankerKeyAufloesen(r.ankerRegelKey!, einstellungen))!;
    final (_, ankerEnde) = _effektivesFenster(anker, jahr,
        flatOffset: flatOffset, beobachtungen: beobachtungen, einstellungen: einstellungen);
    return (
      DateTime(ankerEnde.year, ankerEnde.month, ankerEnde.day + r.ankerVersatzStartTage),
      DateTime(ankerEnde.year, ankerEnde.month, ankerEnde.day + r.ankerVersatzEndeTage),
    );
  }
  final off = effektiverOffset(
      regel: r, saisonJahr: jahr, beobachtungen: beobachtungen, flatOffset: flatOffset);
  return (DateTime(jahr, r.startMonat, r.startTag + off), DateTime(jahr, r.endMonat, r.endTag + off));
}

/// Effektives Tracht-Fenster [honigraum_aufsetzen-Start … letzte-Ernte-Ende] für ein Jahr,
/// oder null wenn keine Tracht-Beobachtung existiert (dann keine Honigreinheit-Warnung).
(DateTime, DateTime)? trachtFensterFuer({
  required int jahr,
  required int flatOffset,
  required List<PhaenoBeobachtung> beobachtungen,
  required BetriebsEinstellungen einstellungen,
}) {
  if (!_hatTrachtBeobachtung(beobachtungen, jahr)) return null;
  final aufsetzen = regelVon('honigraum_aufsetzen')!;
  final letzteErnte = regelVon(einstellungen.anzahlErnten == 2 ? 'honigernte_sommer' : 'honigernte')!;
  final (start, _) = _effektivesFenster(aufsetzen, jahr,
      flatOffset: flatOffset, beobachtungen: beobachtungen, einstellungen: einstellungen);
  final (_, ende) = _effektivesFenster(letzteErnte, jahr,
      flatOffset: flatOffset, beobachtungen: beobachtungen, einstellungen: einstellungen);
  return (start, ende);
}
```

- [ ] **Step 4: Generator-Signatur + Fensterberechnung umstellen** — in `anstehendeVorschlaege`

Signatur ergänzen (nach `einstellungen`-Parameter):
```dart
  List<PhaenoBeobachtung> beobachtungen = const [],
```

Die alte Offset-/Fensterberechnung ersetzen. Entferne Z.267 (`final off = r.offsetAnwenden ? saisonOffsetTage : 0;`) und ersetze im `for (final jahr …)`-Block die beiden Zeilen
```dart
      final start = DateTime(jahr, r.startMonat, r.startTag + off);
      final ende = DateTime(jahr, r.endMonat, r.endTag + off);
```
durch
```dart
      final (start, ende) = _effektivesFenster(r, jahr,
          flatOffset: saisonOffsetTage, beobachtungen: beobachtungen, einstellungen: einstellungen);
```
(Der DST-Kommentar Z.264-266 bleibt sinngemäß gültig — die Kalenderkomponenten-Arithmetik steckt jetzt in `_effektivesFenster`.)

- [ ] **Step 5: Regel-Zuordnung setzen** — in `kSaisonRegeln`

**Frühjahr (`phase: PhaenoAnker.fruehjahr`)** — bei diesen Regeln ergänzen (alle haben bereits `offsetAnwenden: true`):
`erste_durchsicht`, `fruehjahrsdurchsicht`, `wabenhygiene`, `drohnenrahmen_einsetzen`, `drohnenschnitt`, `brutraum_erweitern`, `schwarmkontrolle`, `serbelvoelker_fruehjahr`, `varroakontrolle_fruehsommer`, `trachtluecke_notfuetterung`, `jungvoelker_bilden`, `koeniginnen_vermehren`.

**Tracht (`phase: PhaenoAnker.tracht`)** — ergänzen (behalten `offsetAnwenden: true`):
`honigraum_aufsetzen`, `honigernte`.

**Ketten-Anker** — ergänzen:
- `honigernte_sommer` (heute kalenderfix, `nurBeiAnzahlErnten: 2`): `ankerRegelKey: 'honigernte', ankerVersatzStartTage: 35, ankerVersatzEndeTage: 45`.
- `gemuelldiagnose_sommer` (heute `offsetAnwenden: true`, Basis 6.6.–20.6. — beides BEHALTEN): `ankerRegelKey: '__letzte_ernte', ankerVersatzStartTage: 0, ankerVersatzEndeTage: 3`.
- `sommerbehandlung_1` (heute kalenderfix, Basis 20.7.–15.8. — behalten): `ankerRegelKey: '__letzte_ernte', ankerVersatzStartTage: 5, ankerVersatzEndeTage: 12`.

Beispiel `honigernte` konkret:
```dart
  SaisonRegel(key: 'honigernte', titel: 'Honigernte (Reife prüfen)',
      beschreibung: 'Verdeckelungsgrad/Wassergehalt prüfen, reife Honigwaben abschleudern.',
      kategorie: 'sonstiges', ebene: RegelEbene.volk,
      startMonat: 5, startTag: 20, endMonat: 6, endTag: 5,
      offsetAnwenden: true, phase: PhaenoAnker.tracht),
```
Beispiel `sommerbehandlung_1` konkret:
```dart
  SaisonRegel(key: 'sommerbehandlung_1', titel: '1. Varroa-Sommerbehandlung starten',
      beschreibung: 'Ameisensäure-Langzeitbehandlung nach der Ernte starten (Temperaturfenster beachten).',
      kategorie: 'behandlung', ebene: RegelEbene.volk,
      startMonat: 7, startTag: 20, endMonat: 8, endTag: 15, aktionRoute: 'behandlung',
      ankerRegelKey: '__letzte_ernte', ankerVersatzStartTage: 5, ankerVersatzEndeTage: 12),
```

- [ ] **Step 6: Tests grün laufen lassen** (neue Gruppe + alle Bestandstests)

Run: `cd bienen_app && flutter test test/features/aufgaben/generator_test.dart`
Expected: PASS (inkl. der 149 Bestandstests — ohne Beobachtung unverändert).

- [ ] **Step 7: Commit**

```bash
git add lib/features/aufgaben/domain/saison_regeln.dart test/features/aufgaben/generator_test.dart
git commit -m "feat(generator): Ketten-Anker (Sommerkette folgt Ernte) + Phasen-Zuordnung + trachtFensterFuer"
```

---

## Task 8: Provider-Verdrahtung (Generator + Auth-Reload)

**Files:**
- Modify: `lib/features/aufgaben/presentation/providers/aufgaben_provider.dart` (`vorschlaegeProvider` Z.75-87)
- Modify: `lib/features/auth/presentation/auth_providers.dart` (`_datenNeuLaden` Z.76-94)

- [ ] **Step 1: `beobachtungen` in `vorschlaegeProvider` durchreichen**

Import ergänzen:
```dart
import 'package:bienen_app/features/phaenologie/presentation/providers/phaenologie_provider.dart';
```
Im Provider vor dem `return`:
```dart
  final beob = ref.watch(phaenologieProvider).valueOrNull ?? const [];
```
und den Aufruf um `beobachtungen: beob,` ergänzen.

- [ ] **Step 2: `phaenologieProvider` bei Auth-Wechsel invalidieren**

Import ergänzen:
```dart
import 'package:bienen_app/features/phaenologie/presentation/providers/phaenologie_provider.dart';
```
In `_datenNeuLaden()` ergänzen:
```dart
    ref.invalidate(phaenologieProvider);
```

- [ ] **Step 3: analyze**

Run: `cd bienen_app && flutter analyze lib/features/aufgaben lib/features/auth`
Expected: No issues.

- [ ] **Step 4: Commit**

```bash
git add lib/features/aufgaben/presentation/providers/aufgaben_provider.dart lib/features/auth/presentation/auth_providers.dart
git commit -m "feat(phaenologie): Beobachtungen in Generator-Provider + Auth-Reload verdrahten"
```

---

## Task 9: UI — Phänologie-Sektion auf `/einstellungen`

**Files:**
- Create: `lib/features/phaenologie/presentation/widgets/phaenologie_sektion.dart`
- Modify: `lib/features/einstellungen/pages/einstellungen_page.dart` (ListView Z.100-175)

- [ ] **Step 1: Sub-Widget implementieren** (eigenständig, eigener Inline-Save, KEIN context.go, watcht phaenologieProvider)

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bienen_app/core/theme/app_theme.dart';
import 'package:bienen_app/features/phaenologie/domain/beobachtung.dart';
import 'package:bienen_app/features/phaenologie/domain/phaenologie.dart';
import 'package:bienen_app/features/phaenologie/presentation/providers/phaenologie_provider.dart';

/// Erfassung der beobachteten Zeigerpflanzen-Blüte (Frühjahr + Tracht) fürs laufende Saisonjahr.
/// Eigenständige Sektion mit eigenem Inline-Save — unabhängig vom Betriebs-Formular.
class PhaenologieSektion extends ConsumerWidget {
  const PhaenologieSektion({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(phaenologieProvider);
    final jahr = DateTime.now().year;
    final beob = async.valueOrNull ?? const <PhaenoBeobachtung>[];
    PhaenoBeobachtung? fuer(PhaenoAnker a) {
      for (final b in beob) {
        if (b.jahr == jahr && b.anker == a) return b;
      }
      return null;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Zeigerpflanzen-Blüte (Phänologie)', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text('Wann die Zeigerpflanze an deinem Standort blüht, verschiebt die Saisonaufgaben '
            'präziser als das feste Offset (Jahr $jahr).', style: const TextStyle(fontSize: 12, color: AppColors.grey600)),
        const SizedBox(height: 8),
        _AnkerZeile(anker: PhaenoAnker.fruehjahr, jahr: jahr, vorhanden: fuer(PhaenoAnker.fruehjahr)),
        const SizedBox(height: 8),
        _AnkerZeile(anker: PhaenoAnker.tracht, jahr: jahr, vorhanden: fuer(PhaenoAnker.tracht)),
      ],
    );
  }
}

class _AnkerZeile extends ConsumerStatefulWidget {
  final PhaenoAnker anker;
  final int jahr;
  final PhaenoBeobachtung? vorhanden;
  const _AnkerZeile({required this.anker, required this.jahr, required this.vorhanden});
  @override
  ConsumerState<_AnkerZeile> createState() => _AnkerZeileState();
}

class _AnkerZeileState extends ConsumerState<_AnkerZeile> {
  late String _key;
  DateTime? _datum;
  bool _speichert = false;

  @override
  void initState() {
    super.initState();
    _key = widget.vorhanden?.indikatorKey ??
        (widget.anker == PhaenoAnker.tracht ? kDefaultIndikatorTracht : kDefaultIndikatorFruehjahr);
    _datum = widget.vorhanden?.bluehAm;
  }

  bool get _unplausibel {
    if (_datum == null) return false;
    final ref = indikatorVon(_key);
    if (ref == null) return false;
    return (doyVon(_datum!) - ref.referenzDoy).abs() > 45;
  }

  Future<void> _speichern() async {
    if (_datum == null) return;
    setState(() => _speichert = true);
    try {
      await ref.read(phaenologieProvider.notifier).speichern(PhaenoBeobachtung(
            jahr: widget.jahr, anker: widget.anker, indikatorKey: _key, bluehAm: _datum!));
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Blühbeobachtung gespeichert.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fehler: $e')));
      }
    } finally {
      if (mounted) setState(() => _speichert = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final label = widget.anker == PhaenoAnker.tracht ? 'Tracht-Anker' : 'Frühjahrs-Anker';
    final pflanzen = indikatorenFuer(widget.anker);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
        Row(children: [
          Expanded(
            child: DropdownButton<String>(
              isExpanded: true,
              value: _key,
              items: [for (final p in pflanzen) DropdownMenuItem(value: p.key, child: Text(p.name))],
              onChanged: (v) => setState(() => _key = v!),
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: () async {
              final d = await showDatePicker(
                context: context,
                initialDate: _datum ?? DateTime(widget.jahr, 6, 1),
                firstDate: DateTime(widget.jahr, 1, 1),
                lastDate: DateTime(widget.jahr, 12, 31),
              );
              if (d != null) setState(() => _datum = d);
            },
            child: Text(_datum == null ? 'Datum' : '${_datum!.day}.${_datum!.month}.'),
          ),
          IconButton(
            icon: _speichert
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.save_outlined),
            onPressed: (_datum == null || _speichert) ? null : _speichern,
          ),
        ]),
        if (_unplausibel)
          const Text('Ungewöhnliches Blühdatum — bitte prüfen.',
              style: TextStyle(fontSize: 12, color: AppColors.amber800, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
```

> **Hinweis:** Falls `AppColors.grey600` nicht existiert, die verfügbare graue Konstante aus `core/theme/app_theme.dart` verwenden (vorab prüfen). `AppColors.amber800` wird bereits in `einstellungen_page.dart` genutzt.

- [ ] **Step 2: Sektion in `einstellungen_page.dart` einhängen**

Import ergänzen:
```dart
import 'package:bienen_app/features/phaenologie/presentation/widgets/phaenologie_sektion.dart';
```
In der ListView **vor** dem finalen `FilledButton(onPressed: _speichern …)` einfügen:
```dart
            const Divider(height: 32),
            const PhaenologieSektion(),
            const SizedBox(height: 24),
```

- [ ] **Step 3: analyze**

Run: `cd bienen_app && flutter analyze lib/features/phaenologie lib/features/einstellungen`
Expected: No issues.

- [ ] **Step 4: Commit**

```bash
git add lib/features/phaenologie/presentation/widgets/phaenologie_sektion.dart lib/features/einstellungen/pages/einstellungen_page.dart
git commit -m "feat(phaenologie): Einstellungen-Sektion zur Blühbeobachtung (eigener Inline-Save)"
```

---

## Task 10: UI — Honigreinheit-Hinweis im Fütterungs-Formular

**Files:**
- Modify: `lib/features/fuetterung/presentation/pages/fuetterung_form_page.dart` (Prewarm Z.37-45; build Z.60-146)

- [ ] **Step 1: Prewarm um phaenologie + einstellungen erweitern**

Imports ergänzen:
```dart
import 'package:bienen_app/features/aufgaben/domain/saison_regeln.dart';
import 'package:bienen_app/features/phaenologie/domain/phaenologie.dart';
import 'package:bienen_app/features/phaenologie/presentation/providers/phaenologie_provider.dart';
```
In `_prewarm()` die `Future.wait`-Liste ergänzen:
```dart
        ref.read(phaenologieProvider.future),
        ref.read(betriebsEinstellungenProvider.future),
```
(`betriebsEinstellungenProvider` kommt aus `voelker_provider.dart` — bereits via `voelker_provider.dart`-Import verfügbar? Sonst importieren: `import 'package:bienen_app/features/voelker/presentation/providers/voelker_provider.dart';` — ist bereits vorhanden.)

- [ ] **Step 2: Hinweis im build() berechnen + anzeigen**

Im `build()` nach `final materialien = …`:
```dart
    final einst = ref.watch(betriebsEinstellungenProvider).valueOrNull;
    final beob = ref.watch(phaenologieProvider).valueOrNull ?? const [];
    final fenster = einst == null
        ? null
        : trachtFensterFuer(
            jahr: _datum.year,
            flatOffset: einst.saisonOffsetDefaultTage,
            beobachtungen: beob,
            einstellungen: einst);
    final honigHinweis = honigreinheitHinweis(
        futterart: _futterart, zweck: _zweck, datum: _datum, trachtFenster: fenster);
```
In der ListView (z. B. direkt nach dem Bio-Banner-Block) einfügen:
```dart
              if (honigHinweis != HonigreinheitHinweis.keiner)
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: Colors.amber.withAlpha(38), borderRadius: BorderRadius.circular(8)),
                  child: Row(children: [
                    const Icon(Icons.info_outline, color: Colors.amber),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(honigHinweis == HonigreinheitHinweis.notfuetterung
                          ? 'Notfütterung: Honig aus dieser Periode nicht als reinen Honig ernten (BGD 4.2).'
                          : 'Zuckerfütterung während der Tracht kann den Honig verfälschen (BGD 4.2).'),
                    ),
                  ]),
                ),
```

- [ ] **Step 3: analyze**

Run: `cd bienen_app && flutter analyze lib/features/fuetterung`
Expected: No issues.

- [ ] **Step 4: Commit**

```bash
git add lib/features/fuetterung/presentation/pages/fuetterung_form_page.dart
git commit -m "feat(phaenologie): Honigreinheit-Hinweis im Fütterungs-Formular (nur bei Tracht-Beobachtung)"
```

---

## Task 11: Living-Docs + Version-Bump + Deploy

**Files:**
- Modify: `pubspec.yaml` (`version:`)
- Modify: `docs/decision-log.md`, `docs/roadmap-app.md`, `ToDo.md`
- Modify: App-Memory `C:\Users\furmi\.claude\projects\D--Projekte-Bienen-bienen-app\memory\MEMORY.md`

- [ ] **Step 1: Version bumpen** — `pubspec.yaml` `version:` → `1.17.0+38`.

- [ ] **Step 2: decision-log D-49 + 4.20-Vermerk ergänzen** (Ketten-Verankerung + Alpenrose; Per-Standort-Promotion nicht rein additiv).

- [ ] **Step 3: roadmap-app.md** — 4.4-Zeile: „Phänologie-Anker (C) LIVE (v1.17.0)" nachziehen; 4.20 als Keimzelle-Fortschritt vermerken.

- [ ] **Step 4: ToDo.md** — Stand-Datum, Erledigtes (C mit Commit-Range), Offenes (D Ableger/Zucht als nächstes).

- [ ] **Step 5: Volltest + analyze**

Run: `cd bienen_app && flutter analyze && flutter test`
Expected: No issues; alle Tests grün (inkl. der 149 Bestand + neue Phänologie-Gruppe).

- [ ] **Step 6: Deploy** (stehende Freigabe nach grünen Tests)

Run: `bash bienen_app/deploy.sh`
Expected: Self-Verify des Live-Flips grün (Version 1.17.0+38 live).

- [ ] **Step 7: Commit + Memory**

```bash
git add pubspec.yaml docs/decision-log.md docs/roadmap-app.md ToDo.md
git commit -m "chore(phaenologie): v1.17.0 — Living-Docs + Version-Bump + Deploy"
```
App-Memory: neuen Gotcha ergänzen (Ketten-Anker `__letzte_ernte`, ±60-Klemme, Alpenrose-Default, immutable jahr-CHECK).

---

## Self-Review (gegen Spec v2)

**1. Spec-Coverage:**
- §2.1 Katalog + referenzDoy + Alpenrose → Task 2 ✓
- §2.2 Migration J01 (immutable CHECK, kein Index, upsert, anker-Guard) → Task 1 + Task 3 (toUpsertJson) + Task 4 (onConflict) ✓
- §3.3 effektiverOffset + ±60-Klemme → Task 6 ✓
- §3.4 Ketten-Anker + __letzte_ernte → Task 7 ✓
- §3.5 Regel-Zuordnung (honigraum_aufsetzen→tracht; Kettenregeln) → Task 7 ✓
- §3.6 Signatur +beobachtungen + Provider + Schaltjahr-Doku → Task 6/7/8 + doyVon-Kommentar ✓
- §4.1 Phänologie-Sektion (Inline-Save, Plausibilisierung, kein viewer-Guard) → Task 9 ✓
- §4.2 Honigreinheit nur bei Beobachtung + Ableger-Schutz + Notfütterung + Prewarm → Task 2 (Regel) + Task 10 (UI) ✓
- §5 Import-Richtung einseitig → phaenologie.dart importiert kein aufgaben; trachtFensterFuer/effektiverOffset in saison_regeln.dart ✓
- §6 Tests (Klemme, Rückwärtskompat, Ordnung, Cross-Phasen, Honigreinheit, Katalog, Gateway, DOY) → Tasks 2/3/4/6/7 ✓
- §7 Deploy 1.17.0+38 → Task 11 ✓
- §8 decision-log/4.20 → Task 11 ✓

**2. Placeholder-Scan:** kein TBD/TODO; alle Code-Steps mit vollem Code. Versatz-Tageswerte konkret gesetzt (35/45, 0/3, 5/12) statt Bandbreiten. ✓

**3. Typ-Konsistenz:** `effektiverOffset`/`_effektivesFenster`/`trachtFensterFuer`/`doyVon`/`honigreinheitHinweis`/`PhaenoBeobachtung`/`PhaenoAnker`/`kMaxOffsetTage` konsistent über Tasks 2/3/6/7/10. `phaenologieProvider`/`speichern` konsistent Task 5/8/9. `HonigreinheitHinweis`-Enum Task 2/10. ✓

**Offene Plan-Punkte (bewusst, Fachstellen-Check bei Feinjustierung):** Versatz-Tageswerte + referenzDoy(alpenrose=160)/robinie sind Richtwerte; bei realer Saison 2027 nachjustierbar (reine Konstanten, kein Struktureingriff).
