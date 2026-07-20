# Volk-/Königin-Bewertung (Baustein D2a) — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ein Volk je Saison auf 6 BGD-Achsen (Skala 1–4) bewerten; die Bewertungen + ein Saison-Aggregat (Ø je Achse, Minimum für Schwarmträgheit, Gesamtnote) erscheinen auf der Volk-Detailseite. Kein volk-übergreifendes Ranking.

**Architecture:** Neues Feature `lib/features/zucht/` (Modell + Achsen-Katalog + Aggregation + Gateway-Trio + Provider + UI), Muster gesundheit/vermehrung. Migration **L01** = Tabelle `volk_bewertungen`. `aggregiereSaison` ist pure. Import strikt einseitig `zucht → voelker`.

**Tech Stack:** Flutter Web, Riverpod AsyncNotifier (ohne Codegen), Supabase (RLS, Komposit-FKs), Dart-Tests.

**Spec:** `docs/superpowers/specs/2026-07-20-koenigin-bewertung-design.md` (v2, freigegeben). **Branch:** `feat/koenigin-bewertung` (existiert).
**Verifiziert:** `koeniginnen` hat `unique(betrieb_id, id)` (`koeniginnen_betrieb_id_id_key`) → Komposit-FK trägt. Volk-Modell (`volk.dart`) hat `koeniginId`.

---

## File Structure

| Datei | Verantwortung |
|---|---|
| `supabase/migrations/L01_volk_bewertungen.sql` | Tabelle (neu, Prod-freigabepflichtig) |
| `lib/features/zucht/domain/bewertung.dart` | `VolkBewertung`-Modell, `kBewertungsAchsen`, `SaisonAggregat`, `aggregiereSaison`, `wertFuer` (pure) |
| `lib/features/zucht/domain/bewertung_gateway.dart` | abstrakt + `BewertungFehler` |
| `lib/features/zucht/data/{fake,supabase}_bewertung_gateway.dart` | Fake + PostgREST |
| `lib/features/zucht/presentation/providers/bewertung_provider.dart` | Gateway + `bewertungenProvider` + `bewertungenFuerVolkProvider` + speichern/loeschen |
| `lib/features/zucht/presentation/pages/bewertung_form_page.dart` | Erfassung/Edit (6 Achsen) |
| `lib/features/zucht/presentation/widgets/bewertung_sektion.dart` | Volk-Detailseite (Aggregat + Liste + Edit/Delete) |

**Modify:** `voelker/presentation/pages/volk_detail_page.dart` (Sektion einbetten) · `auth/presentation/auth_providers.dart` (invalidate) · `core/router/app_router.dart` (Route).

---

## Task 1: Migration L01 — `volk_bewertungen`

**Files:** Create `supabase/migrations/L01_volk_bewertungen.sql`

- [ ] **Step 1: SQL-File schreiben** (Muster H01/G01; kein `saison_jahr` [aus bewertet_am abgeleitet]; kein `current_date`-CHECK [Formular-Plausi, J01-Konvention]; FK-Indizes; RLS/Trigger voll)

```sql
-- L01_volk_bewertungen.sql | Volk-Bewertung (Baustein D2a, Modul 4.17). 6 BGD-Achsen (1-4) je Volk/Saison.
-- Normale CRUD via RLS. Saison = year(bewertet_am), NICHT gespeichert. Kein Ranking in v1.
create table if not exists public.volk_bewertungen (
  id uuid primary key default gen_random_uuid(),
  volk_id uuid not null,
  koenigin_id uuid,                        -- Zuordnungs-Referenz z. Bewertungszeitpunkt (SET NULL)
  bewertet_am date not null,
  sanftmut smallint not null check (sanftmut between 1 and 4),
  wabensitz smallint not null check (wabensitz between 1 and 4),
  schwarmtraegheit smallint not null check (schwarmtraegheit between 1 and 4),
  brutbild smallint not null check (brutbild between 1 and 4),
  volksstaerke smallint not null check (volksstaerke between 1 and 4),
  gesundheit smallint not null check (gesundheit between 1 and 4),
  notiz text,
  betrieb_id uuid not null default private.aktive_betrieb_id()
    references public.betriebe(id) on delete cascade,
  created_by uuid, updated_by uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (betrieb_id, id),
  constraint bewertung_volk_fk foreign key (betrieb_id, volk_id)
    references public.voelker (betrieb_id, id) on delete cascade,     -- operativ (wie aufgaben), keine Pflichtdaten
  constraint bewertung_koenigin_fk foreign key (betrieb_id, koenigin_id)
    references public.koeniginnen (betrieb_id, id) on delete set null (koenigin_id)
);
alter table public.volk_bewertungen enable row level security;
revoke all on public.volk_bewertungen from anon, public;
grant select, insert, update, delete on public.volk_bewertungen to authenticated;
create index if not exists idx_bewertung_volk on public.volk_bewertungen (betrieb_id, volk_id);
create index if not exists idx_bewertung_koenigin on public.volk_bewertungen (betrieb_id, koenigin_id);

drop trigger if exists trg_bewertung_actor on public.volk_bewertungen;
create trigger trg_bewertung_actor before insert or update
  on public.volk_bewertungen for each row execute function private.set_row_actor();
drop trigger if exists trg_bewertung_updated on public.volk_bewertungen;
create trigger trg_bewertung_updated before update
  on public.volk_bewertungen for each row execute function private.set_updated_at();

drop policy if exists bewertung_sel_member on public.volk_bewertungen;
create policy bewertung_sel_member on public.volk_bewertungen
  for select to authenticated using (betrieb_id in (select private.meine_betrieb_ids()));
drop policy if exists bewertung_ins_writer on public.volk_bewertungen;
create policy bewertung_ins_writer on public.volk_bewertungen
  for insert to authenticated with check (private.kann_schreiben(betrieb_id));
drop policy if exists bewertung_upd_writer on public.volk_bewertungen;
create policy bewertung_upd_writer on public.volk_bewertungen
  for update to authenticated using (private.kann_schreiben(betrieb_id)) with check (private.kann_schreiben(betrieb_id));
drop policy if exists bewertung_del_writer on public.volk_bewertungen;
create policy bewertung_del_writer on public.volk_bewertungen
  for delete to authenticated using (private.kann_schreiben(betrieb_id));
-- ROLLBACK: drop table public.volk_bewertungen;
```

- [ ] **Step 2: Auf Produktion anwenden** (⚠️ FREIGABEPFLICHTIG — nur nach expliziter L01-Zustimmung) via `apply_migration` (name `L01_volk_bewertungen`).
- [ ] **Step 3: Verifizieren** — `list_tables` (volk_bewertungen, 4 Policies/2 Trigger/2 Indizes/RLS); `get_advisors(security)` **und** `get_advisors(performance)` → 0 neue (FK-Indizes vorhanden).
- [ ] **Step 4: Commit**
```bash
git add supabase/migrations/L01_volk_bewertungen.sql
git commit -m "feat(zucht): Migration L01 volk_bewertungen (6 BGD-Achsen)"
```

---

## Task 2: Domain — Achsen-Katalog + Modell + Aggregation (pure, TDD)

**Files:** Create `lib/features/zucht/domain/bewertung.dart`; Test `test/features/zucht/bewertung_test.dart`

- [ ] **Step 1: Failing tests**
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:bienen_app/features/zucht/domain/bewertung.dart';

VolkBewertung _b({int s = 3, int w = 3, int schwarm = 3, int brut = 3, int staerke = 3, int g = 3, DateTime? am}) =>
    VolkBewertung(id: 'x', volkId: 'v1', bewertetAm: am ?? DateTime(2026, 6, 1),
        sanftmut: s, wabensitz: w, schwarmtraegheit: schwarm, brutbild: brut, volksstaerke: staerke, gesundheit: g);

void main() {
  test('Katalog-Invarianten: genau 6 Achsen, Keys eindeutig, je 4 Anker', () {
    expect(kBewertungsAchsen.length, 6);
    final keys = kBewertungsAchsen.map((a) => a.key).toList();
    expect(keys.toSet().length, 6);
    expect(keys.toSet(), {'sanftmut', 'wabensitz', 'schwarmtraegheit', 'brutbild', 'volksstaerke', 'gesundheit'});
    for (final a in kBewertungsAchsen) {
      expect(a.anker.length, 4, reason: a.key);
    }
  });

  test('wertFuer mappt alle 6 Keys', () {
    final b = _b(s: 1, w: 2, schwarm: 3, brut: 4, staerke: 1, g: 2);
    expect(b.wertFuer('sanftmut'), 1);
    expect(b.wertFuer('brutbild'), 4);
    expect(b.wertFuer('gesundheit'), 2);
    expect(() => b.wertFuer('gibtsnicht'), throwsArgumentError);
  });

  test('aggregiereSaison: Ø je Achse, MINIMUM für schwarmtraegheit, Gesamtnote = Ø der 6 rohen Aggregate', () {
    // schwarm: [4,4,1] -> Min 1; sanftmut [2,4,3] -> Ø 3.0
    final bs = [
      _b(s: 2, w: 3, schwarm: 4, brut: 3, staerke: 3, g: 3),
      _b(s: 4, w: 3, schwarm: 4, brut: 3, staerke: 3, g: 3),
      _b(s: 3, w: 3, schwarm: 1, brut: 3, staerke: 3, g: 3),
    ];
    final agg = aggregiereSaison(bs)!;
    expect(agg.achsen['schwarmtraegheit'], 1.0);      // Minimum
    expect(agg.achsen['sanftmut'], closeTo(3.0, 1e-9)); // (2+4+3)/3
    expect(agg.achsen['wabensitz'], 3.0);
    // Gesamtnote = Ø(3.0, 3.0, 1.0, 3.0, 3.0, 3.0) = 16/6
    expect(agg.gesamtnote, closeTo(16 / 6, 1e-9));
    expect(agg.anzahl, 3);
  });

  test('aggregiereSaison: 1 Bewertung = Werte; leer = null', () {
    expect(aggregiereSaison(const []), isNull);
    final agg = aggregiereSaison([_b(s: 4, schwarm: 2)])!;
    expect(agg.achsen['sanftmut'], 4.0);
    expect(agg.achsen['schwarmtraegheit'], 2.0);
  });

  test('fromJson/toInsertJson: ohne betrieb_id/id, koeniginId nullable', () {
    final b = VolkBewertung.fromJson({
      'id': 'a1', 'volk_id': 'v1', 'koenigin_id': null, 'bewertet_am': '2026-06-01',
      'sanftmut': 3, 'wabensitz': 3, 'schwarmtraegheit': 2, 'brutbild': 4, 'volksstaerke': 3, 'gesundheit': 4,
    });
    expect(b.koeniginId, isNull);
    expect(b.brutbild, 4);
    final j = b.toInsertJson();
    expect(j.containsKey('betrieb_id'), isFalse);
    expect(j.containsKey('id'), isFalse);
    expect(j['schwarmtraegheit'], 2);
    expect(j['bewertet_am'], '2026-06-01');
  });
}
```

- [ ] **Step 2: Test rot** — `flutter test test/features/zucht/bewertung_test.dart` → FAIL.

- [ ] **Step 3: `bewertung.dart` implementieren**
```dart
/// Volk-Bewertung (Baustein D2a). 6 BGD-Achsen, Skala 1-4, alle 'höher = besser'. Pure.
class BewertungsAchse {
  final String key;          // = DB-Spaltenname
  final String label;
  final List<String> anker;  // 4 Verhaltensanker, Index 0 = Note 1 … Index 3 = Note 4
  const BewertungsAchse({required this.key, required this.label, required this.anker});
}

const kBewertungsAchsen = <BewertungsAchse>[
  BewertungsAchse(key: 'sanftmut', label: 'Sanftmut',
      anker: ['stechlustig', 'nervös', 'sanft', 'sehr sanft']),
  BewertungsAchse(key: 'wabensitz', label: 'Wabensitz',
      anker: ['flüchtig/abtropfend', 'laufend', 'ruhig', 'fest sitzend']),
  BewertungsAchse(key: 'schwarmtraegheit', label: 'Schwarmträgheit',
      anker: ['geschwärmt/starker Trieb', 'deutlicher Trieb', 'geringer Trieb', 'kein Schwarmtrieb']),
  BewertungsAchse(key: 'brutbild', label: 'Brutbild',
      anker: ['stark löchrig/Buckelbrut', 'lückig', 'gut, wenige Lücken', 'geschlossen/lückenlos']),
  BewertungsAchse(key: 'volksstaerke', label: 'Volksstärke',
      anker: ['sehr schwach/Serbel', 'schwach', 'durchschnittlich', 'stark (jahreszeit-entsprechend)']),
  BewertungsAchse(key: 'gesundheit', label: 'Gesundheit',
      anker: ['stark belastet/Symptome', 'Varroa-/Krankheitszeichen', 'leichte Auffälligkeit', 'keine Auffälligkeiten']),
];

class VolkBewertung {
  final String id;
  final String volkId;
  final String? koeniginId;
  final DateTime bewertetAm;
  final int sanftmut, wabensitz, schwarmtraegheit, brutbild, volksstaerke, gesundheit;
  final String? notiz;
  const VolkBewertung({
    required this.id, required this.volkId, this.koeniginId, required this.bewertetAm,
    required this.sanftmut, required this.wabensitz, required this.schwarmtraegheit,
    required this.brutbild, required this.volksstaerke, required this.gesundheit, this.notiz,
  });

  int wertFuer(String key) => switch (key) {
        'sanftmut' => sanftmut,
        'wabensitz' => wabensitz,
        'schwarmtraegheit' => schwarmtraegheit,
        'brutbild' => brutbild,
        'volksstaerke' => volksstaerke,
        'gesundheit' => gesundheit,
        _ => throw ArgumentError('unbekannte Achse $key'),
      };

  static String _iso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  factory VolkBewertung.fromJson(Map<String, dynamic> j) => VolkBewertung(
        id: j['id'] as String,
        volkId: j['volk_id'] as String,
        koeniginId: j['koenigin_id'] as String?,
        bewertetAm: DateTime.parse(j['bewertet_am'] as String),
        sanftmut: j['sanftmut'] as int,
        wabensitz: j['wabensitz'] as int,
        schwarmtraegheit: j['schwarmtraegheit'] as int,
        brutbild: j['brutbild'] as int,
        volksstaerke: j['volksstaerke'] as int,
        gesundheit: j['gesundheit'] as int,
        notiz: j['notiz'] as String?,
      );

  /// Ohne betrieb_id/id (DB-Default). koenigin_id = Referenz.
  Map<String, dynamic> toInsertJson() => {
        'volk_id': volkId,
        'koenigin_id': koeniginId,
        'bewertet_am': _iso(bewertetAm),
        'sanftmut': sanftmut,
        'wabensitz': wabensitz,
        'schwarmtraegheit': schwarmtraegheit,
        'brutbild': brutbild,
        'volksstaerke': volksstaerke,
        'gesundheit': gesundheit,
        'notiz': notiz,
      };
}

class SaisonAggregat {
  final Map<String, double> achsen; // key → aggregierter Wert
  final double gesamtnote;          // Ø der 6 rohen Achsenwerte (vollpräzise; Rundung nur Anzeige)
  final int anzahl;
  const SaisonAggregat({required this.achsen, required this.gesamtnote, required this.anzahl});
}

/// Saison-Aggregat aus den (1..n) Bewertungen EINES Volks EINER Saison. null wenn leer.
/// Je Achse Mittelwert; schwarmtraegheit = Minimum (BGD: ein Schwarm zählt).
SaisonAggregat? aggregiereSaison(List<VolkBewertung> bewertungen) {
  if (bewertungen.isEmpty) return null;
  final achsen = <String, double>{};
  for (final a in kBewertungsAchsen) {
    final werte = bewertungen.map((b) => b.wertFuer(a.key)).toList();
    achsen[a.key] = a.key == 'schwarmtraegheit'
        ? werte.reduce((x, y) => x < y ? x : y).toDouble()      // Minimum
        : werte.reduce((x, y) => x + y) / werte.length;         // Mittelwert
  }
  final gesamt = achsen.values.reduce((x, y) => x + y) / achsen.length;
  return SaisonAggregat(achsen: achsen, gesamtnote: gesamt, anzahl: bewertungen.length);
}
```

- [ ] **Step 4: Test grün** → PASS.
- [ ] **Step 5: Commit**
```bash
git add lib/features/zucht/domain/bewertung.dart test/features/zucht/bewertung_test.dart
git commit -m "feat(zucht): Achsen-Katalog + VolkBewertung-Modell + aggregiereSaison (pure)"
```

---

## Task 3: Gateway-Trio

**Files:** Create `zucht/domain/bewertung_gateway.dart`, `zucht/data/{fake,supabase}_bewertung_gateway.dart`; Test `test/features/zucht/bewertung_gateway_test.dart`

- [ ] **Step 1: Failing test** (Fake-CRUD)
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:bienen_app/features/zucht/domain/bewertung.dart';
import 'package:bienen_app/features/zucht/data/fake_bewertung_gateway.dart';

void main() {
  test('Fake: speichern (insert+update) + alle + loeschen', () async {
    final gw = FakeBewertungGateway();
    await gw.speichern(VolkBewertung(id: '', volkId: 'v1', bewertetAm: DateTime(2026, 6, 1),
        sanftmut: 3, wabensitz: 3, schwarmtraegheit: 3, brutbild: 3, volksstaerke: 3, gesundheit: 3));
    var alle = await gw.alle();
    expect(alle.length, 1);
    final id = alle.first.id;
    await gw.speichern(VolkBewertung(id: id, volkId: 'v1', bewertetAm: DateTime(2026, 6, 1),
        sanftmut: 4, wabensitz: 3, schwarmtraegheit: 3, brutbild: 3, volksstaerke: 3, gesundheit: 3));
    alle = await gw.alle();
    expect(alle.length, 1);
    expect(alle.first.sanftmut, 4);
    await gw.loeschen(id);
    expect((await gw.alle()), isEmpty);
  });
}
```

- [ ] **Step 2: Test rot.**

- [ ] **Step 3: `bewertung_gateway.dart`**
```dart
import 'package:bienen_app/features/zucht/domain/bewertung.dart';

class BewertungFehler implements Exception {
  final String code; final String message;
  const BewertungFehler(this.code, this.message);
  @override String toString() => message;
}

abstract class BewertungGateway {
  Future<List<VolkBewertung>> alle();
  Future<void> speichern(VolkBewertung b); // insert wenn id leer, sonst update
  Future<void> loeschen(String id);
}
```

- [ ] **Step 4: `fake_bewertung_gateway.dart`**
```dart
import 'package:bienen_app/features/zucht/domain/bewertung.dart';
import 'package:bienen_app/features/zucht/domain/bewertung_gateway.dart';

class FakeBewertungGateway implements BewertungGateway {
  final _map = <String, VolkBewertung>{};
  int _seq = 0;
  @override
  Future<List<VolkBewertung>> alle() async => _map.values.toList();
  @override
  Future<void> speichern(VolkBewertung b) async {
    final id = b.id.isEmpty ? 'bw${++_seq}' : b.id;
    _map[id] = VolkBewertung(id: id, volkId: b.volkId, koeniginId: b.koeniginId, bewertetAm: b.bewertetAm,
        sanftmut: b.sanftmut, wabensitz: b.wabensitz, schwarmtraegheit: b.schwarmtraegheit,
        brutbild: b.brutbild, volksstaerke: b.volksstaerke, gesundheit: b.gesundheit, notiz: b.notiz);
  }
  @override
  Future<void> loeschen(String id) async => _map.remove(id);
}
```

- [ ] **Step 5: `supabase_bewertung_gateway.dart`** (Muster supabase_gesundheit_gateway)
```dart
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:bienen_app/features/zucht/domain/bewertung.dart';
import 'package:bienen_app/features/zucht/domain/bewertung_gateway.dart';

class SupabaseBewertungGateway implements BewertungGateway {
  final SupabaseClient _c;
  SupabaseBewertungGateway(this._c);
  Never _rethrow(Object e) {
    if (e is PostgrestException && e.code != null) throw BewertungFehler(e.code!, e.message);
    throw e;
  }
  @override
  Future<List<VolkBewertung>> alle() async {
    try {
      final res = await _c.from('volk_bewertungen').select().order('bewertet_am', ascending: false);
      return (res as List).map((j) => VolkBewertung.fromJson(j as Map<String, dynamic>)).toList();
    } catch (e) { _rethrow(e); }
  }
  @override
  Future<void> speichern(VolkBewertung b) async {
    try {
      final json = b.toInsertJson();
      if (b.id.isEmpty) {
        await _c.from('volk_bewertungen').insert(json);
      } else {
        await _c.from('volk_bewertungen').update(json).eq('id', b.id);
      }
    } catch (e) { _rethrow(e); }
  }
  @override
  Future<void> loeschen(String id) async {
    try { await _c.from('volk_bewertungen').delete().eq('id', id); } catch (e) { _rethrow(e); }
  }
}
```

- [ ] **Step 6: Test grün.**
- [ ] **Step 7: Commit**
```bash
git add lib/features/zucht/domain/bewertung_gateway.dart lib/features/zucht/data/ test/features/zucht/bewertung_gateway_test.dart
git commit -m "feat(zucht): Gateway-Trio (abstrakt/Fake/Supabase)"
```

---

## Task 4: Provider + Auth-Reload

**Files:** Create `zucht/presentation/providers/bewertung_provider.dart`; Modify `auth/presentation/auth_providers.dart`

- [ ] **Step 1: `bewertung_provider.dart`**
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bienen_app/core/supabase/supabase_config.dart';
import 'package:bienen_app/features/zucht/data/supabase_bewertung_gateway.dart';
import 'package:bienen_app/features/zucht/domain/bewertung.dart';
import 'package:bienen_app/features/zucht/domain/bewertung_gateway.dart';

final bewertungGatewayProvider =
    Provider<BewertungGateway>((ref) => SupabaseBewertungGateway(SupabaseConfig.client));

final bewertungenProvider =
    AsyncNotifierProvider<BewertungNotifier, List<VolkBewertung>>(BewertungNotifier.new);

class BewertungNotifier extends AsyncNotifier<List<VolkBewertung>> {
  BewertungGateway get _gw => ref.read(bewertungGatewayProvider);
  @override
  Future<List<VolkBewertung>> build() => _gw.alle();
  Future<void> speichern(VolkBewertung b) async { await _gw.speichern(b); ref.invalidateSelf(); }
  Future<void> loeschen(String id) async { await _gw.loeschen(id); ref.invalidateSelf(); }
}

/// Bewertungen eines Volks (neueste zuerst) — reine Ableitung.
final bewertungenFuerVolkProvider = Provider.family<List<VolkBewertung>, String>((ref, volkId) {
  final list = ref.watch(bewertungenProvider).valueOrNull ?? const [];
  return list.where((b) => b.volkId == volkId).toList()
    ..sort((a, b) => b.bewertetAm.compareTo(a.bewertetAm));
});
```

- [ ] **Step 2: Auth-Reload** — `auth_providers.dart` Import + in `_datenNeuLaden()`: `ref.invalidate(bewertungenProvider);`.

- [ ] **Step 3: analyze** — `flutter analyze lib/features/zucht lib/features/auth` → 0 issues.
- [ ] **Step 4: Commit**
```bash
git add lib/features/zucht/presentation/providers/bewertung_provider.dart lib/features/auth/presentation/auth_providers.dart
git commit -m "feat(zucht): Provider (bewertungen + fuerVolk) + Auth-Reload"
```

---

## Task 5: UI — Erfassungs-/Edit-Formular + Route

**Files:** Create `zucht/presentation/pages/bewertung_form_page.dart`; Modify `core/router/app_router.dart`

- [ ] **Step 1: `bewertung_form_page.dart`** (6 Achsen-`SegmentedButton` mit Anker-Text; watcht voelkerListProvider für koeniginId; Edit-Modus via `bewertungId`; Status-Guard)
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:bienen_app/core/theme/app_theme.dart';
import 'package:bienen_app/features/auth/presentation/auth_providers.dart';
import 'package:bienen_app/features/voelker/presentation/providers/voelker_provider.dart';
import 'package:bienen_app/features/zucht/domain/bewertung.dart';
import 'package:bienen_app/features/zucht/presentation/providers/bewertung_provider.dart';

class BewertungFormPage extends ConsumerStatefulWidget {
  final String volkId;
  final String? bewertungId; // null = neu
  const BewertungFormPage({super.key, required this.volkId, this.bewertungId});
  @override
  ConsumerState<BewertungFormPage> createState() => _BewertungFormPageState();
}

class _BewertungFormPageState extends ConsumerState<BewertungFormPage> {
  final _werte = <String, int>{for (final a in kBewertungsAchsen) a.key: 3};
  DateTime _datum = DateTime.now();
  final _notiz = TextEditingController();
  bool _speichert = false;
  bool _initialisiert = false;

  @override
  void dispose() { _notiz.dispose(); super.dispose(); }

  void _uebernehmen(VolkBewertung b) {
    for (final a in kBewertungsAchsen) { _werte[a.key] = b.wertFuer(a.key); }
    _datum = b.bewertetAm;
    _notiz.text = b.notiz ?? '';
  }

  Future<void> _speichern(String? koeniginId) async {
    setState(() => _speichert = true);
    try {
      await ref.read(bewertungenProvider.notifier).speichern(VolkBewertung(
            id: widget.bewertungId ?? '', volkId: widget.volkId, koeniginId: koeniginId, bewertetAm: _datum,
            sanftmut: _werte['sanftmut']!, wabensitz: _werte['wabensitz']!, schwarmtraegheit: _werte['schwarmtraegheit']!,
            brutbild: _werte['brutbild']!, volksstaerke: _werte['volksstaerke']!, gesundheit: _werte['gesundheit']!,
            notiz: _notiz.text.trim().isEmpty ? null : _notiz.text.trim()));
      if (mounted) context.go('/voelker/${widget.volkId}');
    } catch (e) {
      if (mounted) { setState(() => _speichert = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fehler: $e'))); }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!ref.watch(darfSchreibenProvider)) {
      return Scaffold(appBar: AppBar(title: const Text('Bewertung')),
          body: const Center(child: Text('Nur mit Schreibrechten verfügbar.')));
    }
    final voelker = ref.watch(voelkerListProvider).valueOrNull;
    if (voelker == null) {
      return Scaffold(appBar: AppBar(title: const Text('Bewertung')),
          body: const Center(child: CircularProgressIndicator()));
    }
    final volk = voelker.where((v) => v.id == widget.volkId).firstOrNull;
    // Edit-Modus vorbefüllen
    if (!_initialisiert && widget.bewertungId != null) {
      final b = ref.read(bewertungenFuerVolkProvider(widget.volkId)).where((x) => x.id == widget.bewertungId).firstOrNull;
      if (b != null) _uebernehmen(b);
    }
    _initialisiert = true;
    final inaktiv = volk != null && volk.status != 'aktiv';

    return Scaffold(
      appBar: AppBar(title: Text(widget.bewertungId == null ? 'Volk bewerten' : 'Bewertung bearbeiten')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        if (inaktiv)
          const Padding(padding: EdgeInsets.only(bottom: 8),
            child: Text('Volk inaktiv — Bewertung wird trotzdem gespeichert.',
                style: TextStyle(color: AppColors.amber800, fontWeight: FontWeight.w600))),
        ListTile(contentPadding: EdgeInsets.zero,
          title: Text('Datum: ${DateFormat('dd.MM.yyyy').format(_datum)}'),
          trailing: const Icon(Icons.calendar_today),
          onTap: () async {
            final d = await showDatePicker(context: context, initialDate: _datum,
                firstDate: DateTime(2020), lastDate: DateTime.now());
            if (d != null) setState(() => _datum = d);
          },
        ),
        const SizedBox(height: 8),
        for (final a in kBewertungsAchsen) ...[
          Text(a.label, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          SegmentedButton<int>(
            segments: [for (var i = 1; i <= 4; i++) ButtonSegment(value: i, label: Text('$i'))],
            selected: {_werte[a.key]!},
            onSelectionChanged: (s) => setState(() => _werte[a.key] = s.first),
          ),
          Text(a.anker[_werte[a.key]! - 1], style: const TextStyle(fontSize: 12, color: AppColors.brown300)),
          const SizedBox(height: 12),
        ],
        TextField(controller: _notiz, decoration: const InputDecoration(labelText: 'Notiz'), maxLines: 2),
        const SizedBox(height: 20),
        FilledButton(onPressed: _speichert ? null : () => _speichern(volk?.koeniginId),
            child: Text(_speichert ? 'Speichert…' : 'Bewertung speichern')),
      ]),
    );
  }
}
```
> Hinweis: `firstOrNull` auf `Iterable` braucht `dart:collection`-Extension NICHT — es ist seit Dart 3 in `dart:core` verfügbar? NEIN: `firstOrNull` kommt aus `package:collection`. Um den Lint zu vermeiden, stattdessen einen Inline-Helper oder `where(...).cast<Volk?>().firstWhere((_) => true, orElse: () => null)` — **im Plan-Umsetzung:** ersetze `voelker.where(...).firstOrNull` durch eine kleine lokale Funktion `Volk? _finde(List voelker)` mit for-Schleife (analog saison_regeln `regelVon`). Gleiches für die Edit-Vorbefüllung.

- [ ] **Step 2: Route** — in `app_router.dart` unter `/voelker/:id` (nach `vermehrung`) ergänzen + Import `BewertungFormPage`:
```dart
                GoRoute(
                  path: 'bewertung',
                  builder: (c, s) => BewertungFormPage(
                    volkId: s.pathParameters['id']!,
                    bewertungId: s.uri.queryParameters['b'],
                  ),
                ),
```

- [ ] **Step 3: analyze** — `flutter analyze lib/features/zucht lib/core/router` → 0 issues (Inline-Helper statt firstOrNull!).
- [ ] **Step 4: Commit**
```bash
git add lib/features/zucht/presentation/pages/bewertung_form_page.dart lib/core/router/app_router.dart
git commit -m "feat(zucht): Bewertungs-Formular (6 Achsen, Edit-Modus) + Route"
```

---

## Task 6: UI — Bewertungs-Sektion auf der Volk-Detailseite

**Files:** Create `zucht/presentation/widgets/bewertung_sektion.dart`; Modify `voelker/presentation/pages/volk_detail_page.dart`

- [ ] **Step 1: `bewertung_sektion.dart`** — Saison-Aggregat (Gesamtnote + Achsen-Balken) + Liste (Edit/Delete)
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:bienen_app/core/theme/app_theme.dart';
import 'package:bienen_app/features/auth/presentation/auth_providers.dart';
import 'package:bienen_app/features/zucht/domain/bewertung.dart';
import 'package:bienen_app/features/zucht/presentation/providers/bewertung_provider.dart';

class BewertungSektion extends ConsumerWidget {
  final String volkId;
  const BewertungSektion({super.key, required this.volkId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final darf = ref.watch(darfSchreibenProvider);
    final alle = ref.watch(bewertungenFuerVolkProvider(volkId));
    final saison = DateTime.now().year;
    final saisonBew = alle.where((b) => b.bewertetAm.year == saison).toList();
    final agg = aggregiereSaison(saisonBew);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Expanded(child: Text('Bewertung', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
        if (darf)
          TextButton.icon(onPressed: () => context.go('/voelker/$volkId/bewertung'),
              icon: const Icon(Icons.star_border, size: 18), label: const Text('Bewerten')),
      ]),
      if (agg == null)
        const Padding(padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('Noch nicht bewertet.', style: TextStyle(color: AppColors.brown300)))
      else ...[
        Text('Gesamtnote Saison $saison: ${agg.gesamtnote.toStringAsFixed(1)} / 4  (${agg.anzahl}×)',
            style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.honeyDark)),
        const SizedBox(height: 6),
        for (final a in kBewertungsAchsen)
          Padding(padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(children: [
              SizedBox(width: 120, child: Text(a.label, style: const TextStyle(fontSize: 12))),
              Expanded(child: LinearProgressIndicator(value: agg.achsen[a.key]! / 4, minHeight: 6)),
              const SizedBox(width: 8),
              Text(agg.achsen[a.key]!.toStringAsFixed(1), style: const TextStyle(fontSize: 12)),
            ])),
      ],
      const SizedBox(height: 8),
      for (final b in alle)
        Card(child: ListTile(
          dense: true,
          title: Text('${DateFormat('dd.MM.yyyy').format(b.bewertetAm)}'),
          subtitle: Text([for (final a in kBewertungsAchsen) '${a.label[0]}${b.wertFuer(a.key)}'].join(' · ')
              + (b.notiz != null ? ' — ${b.notiz}' : '')),
          trailing: darf ? PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'edit') { context.go('/voelker/$volkId/bewertung?b=${b.id}'); }
              else if (v == 'del') { await _loeschen(context, ref, b.id); }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'edit', child: Text('Bearbeiten')),
              PopupMenuItem(value: 'del', child: Text('Löschen')),
            ],
          ) : null,
        )),
    ]);
  }

  Future<void> _loeschen(BuildContext context, WidgetRef ref, String id) async {
    final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      title: const Text('Bewertung löschen?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Abbrechen')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Löschen')),
      ],
    ));
    if (ok == true) {
      try { await ref.read(bewertungenProvider.notifier).loeschen(id); }
      catch (e) { if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fehler: $e'))); }
    }
  }
}
```

- [ ] **Step 2: Einbetten** — in `volk_detail_page.dart` nach `VermehrungSektion(volkId: volk.id)` (Z.82) ergänzen:
```dart
              const SizedBox(height: 8),
              BewertungSektion(volkId: volk.id),
```
Import `BewertungSektion` oben ergänzen.

- [ ] **Step 3: analyze** — `flutter analyze lib/features/zucht lib/features/voelker` → 0 issues.
- [ ] **Step 4: Commit**
```bash
git add lib/features/zucht/presentation/widgets/bewertung_sektion.dart lib/features/voelker/presentation/pages/volk_detail_page.dart
git commit -m "feat(zucht): Bewertungs-Sektion auf der Volk-Detailseite (Aggregat + Liste + Edit/Delete)"
```

---

## Task 7: Living-Docs + Version-Bump + Deploy

**Files:** Modify `pubspec.yaml`, `docs/decision-log.md`, `docs/roadmap-app.md`, `ToDo.md`; App-Memory

- [ ] **Step 1: Version** — `pubspec.yaml` → `1.19.0+40`.
- [ ] **Step 2: decision-log** — D-55 (6-Achsen-Bewertung, kein Ranking in v1, Begründung + deferred) + Gotchas (saison aus bewertet_am; firstOrNull→Inline-Helper; koenigin_id-Referenz; schwarmtraegheit=Min hart verdrahtet).
- [ ] **Step 3: roadmap-app.md** — 4.17 Basis (Volk-Bewertung) LIVE (D2a, v1.19.0); Auslese-Ranking + D2b später.
- [ ] **Step 4: ToDo.md** — Stand, Erledigtes (D2a + Commit-Range), Offenes (Auslese-Ranking ab ≥3 Völkern; D2b Umlarv).
- [ ] **Step 5: Volltest + analyze** — `flutter analyze && flutter test` → 0 issues, alle grün.
- [ ] **Step 6: Deploy** — `bash deploy.sh` (stehende Freigabe); Live-Flip 1.19.0 verifizieren.
- [ ] **Step 7: Commit + Memory**
```bash
git add pubspec.yaml docs/decision-log.md docs/roadmap-app.md ToDo.md
git commit -m "chore(zucht): v1.19.0 — Living-Docs + Version-Bump + Deploy"
```
App-Memory: neuer Tabellen-Eintrag `volk_bewertungen` (L01) + Gotchas.

---

## Self-Review (gegen Spec v2)

**1. Spec-Coverage:** §2.1 Migration (kein saison_jahr, kein current_date-CHECK) → Task 1 ✓ · §2.2 Katalog (6 Achsen + Anker) + Modell → Task 2 ✓ · §3 aggregiereSaison (Ø + Min schwarm, Gesamtnote roh) → Task 2 ✓ · Gateway/Provider → Task 3/4 ✓ · §4.1 Formular (6 Achsen, koeniginId aus Volk, Edit-Modus ?b=, Status-Guard) → Task 5 ✓ · §4.2 Sektion (Aggregat + Liste + Edit/Delete) → Task 6 ✓ · Route Plural + ?b → Task 5 ✓ · §6 Tests → Task 2/3 ✓ · §7 Deploy → Task 7 ✓ · KEIN Ranking/Projekt/Badge (Nicht-Ziel) — nirgends implementiert ✓.

**2. Placeholder-Scan:** kein TBD; die einzige Warnung ist der explizite `firstOrNull`-Hinweis in Task 5 (Inline-Helper statt package:collection) — bewusst als Umsetzungsanweisung, kein Platzhalter. Einbettungszeile Task 6 konkret (nach Z.82 VermehrungSektion).

**3. Typ-Konsistenz:** `VolkBewertung`/`wertFuer`/`kBewertungsAchsen`/`SaisonAggregat`/`aggregiereSaison` konsistent Task 2/3/4/5/6. `bewertungenProvider`/`bewertungenFuerVolkProvider`/`speichern`/`loeschen` Task 4/5/6. Route `?b=` Task 5 ↔ Sektion-Edit-Link Task 6.

**Offene Plan-Punkte (bewusst):** `firstOrNull`→Inline-Helper in Task 5 (verbindlich); `bewertet_am`-Zukunft rein im Formular (`lastDate: now`) statt DB-CHECK (J01-Konvention).
