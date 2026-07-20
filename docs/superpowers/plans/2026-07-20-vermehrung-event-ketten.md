# Vermehrungs-Event-Ketten (Baustein D1) — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Der Imker erfasst ein Vermehrungs-Startereignis (4 BGD-Methoden) vom Volk aus; ein Ketten-Generator leitet daraus datierte Aufgaben-Vorschläge mit relativen Fristen ab, die im Aufgaben-Tab als „Vermehrung"-Sektion erscheinen und als normale Aufgaben materialisiert werden.

**Architecture:** Neues Feature `lib/features/vermehrung/` (Modell + Ketten-Katalog + Gateway-Trio + Provider, Muster gesundheit/phaenologie). Migration **K01** = neue Tabelle `vermehrungs_ereignisse` + Erweiterung `aufgaben` (quelle='ereignis', ereignis_id, schritt_key, Dedup-Index). Der Ketten-Generator ist eine pure Funktion; Annehmen materialisiert über die bestehende `aufgaben`-Infrastruktur. Import strikt einseitig `vermehrung → aufgaben/voelker`.

**Tech Stack:** Flutter Web, Riverpod AsyncNotifier (ohne Codegen), Supabase (RLS, Komposit-FKs), Dart-Tests.

**Spec:** `docs/superpowers/specs/2026-07-20-vermehrung-event-ketten-design.md` (v2, freigegeben). **Branch:** `feat/vermehrung` (existiert).

---

## File Structure

| Datei | Verantwortung |
|---|---|
| `supabase/migrations/K01_vermehrungs_ereignisse.sql` | Tabelle + aufgaben-ALTER (neu, Prod-freigabepflichtig) |
| `lib/features/vermehrung/domain/vermehrung.dart` | `VermehrungsMethode`-Metadaten (Label, `brutfreiBeiErstellung`) |
| `lib/features/vermehrung/domain/vermehrungs_ereignis.dart` | `VermehrungsEreignis` + fromJson/toInsertJson |
| `lib/features/vermehrung/domain/vermehrungs_ketten.dart` | `KettenSchritt`, `kVermehrungsKetten` (4 Ketten), `KettenVorschlag`, `kettenVorschlaege`, `kettenVorschauFuer`, `aufgabeAusKettenVorschlag` (pure) |
| `lib/features/vermehrung/domain/vermehrung_gateway.dart` | abstrakt + `VermehrungFehler` |
| `lib/features/vermehrung/data/{fake,supabase}_vermehrung_gateway.dart` | Fake + PostgREST |
| `lib/features/vermehrung/presentation/providers/vermehrung_provider.dart` | Gateway + Liste + `kettenVorschlaegeProvider` |
| `lib/features/vermehrung/presentation/pages/vermehrung_form_page.dart` | Erfassung + Ketten-Vorschau |
| `lib/features/vermehrung/presentation/widgets/vermehrung_sektion.dart` | Volk-Detailseite-Sektion |
| `lib/features/vermehrung/presentation/widgets/ketten_vorschlag_karte.dart` | Vorschlags-Karte (Annehmen/Überspringen) |

**Modify:** `aufgaben/domain/aufgabe.dart` (+`ereignisId`/`schrittKey`) · `aufgaben/presentation/pages/aufgabe_form_page.dart` (Roundtrip) · `aufgaben/presentation/providers/aufgaben_provider.dart` (`kettenMaterialisieren`) · `aufgaben/presentation/pages/aufgaben_page.dart` (Vermehrungs-Sektion) · `auth/presentation/auth_providers.dart` (invalidate) · `core/router/app_router.dart` (Route) · `voelker/.../volk_detail_page.dart` (Sektion einbetten).

---

## Task 1: Migration K01 — `vermehrungs_ereignisse` + `aufgaben`-Erweiterung

**Files:** Create `supabase/migrations/K01_vermehrungs_ereignisse.sql`

- [ ] **Step 1: Bestands-Constraint-Namen verifizieren** (vor dem Schreiben)

Via Supabase-MCP `execute_sql` (Projekt `dcdcohktxbhdxnxjvcyp`):
```sql
select conname from pg_constraint where conrelid='public.aufgaben'::regclass
  and contype='c' and pg_get_constraintdef(oid) ilike '%quelle%';
```
Erwartet: `aufgaben_quelle_check`. Falls abweichend → im SQL unten den `drop constraint`-Namen anpassen.

- [ ] **Step 2: SQL-File schreiben** (Muster H01; SET-NULL-FKs, kein current_date-CHECK, RLS/Trigger voll, Dedup ohne volk_id)

```sql
-- K01_vermehrungs_ereignisse.sql | Vermehrungs-Event-Ketten (Baustein D1, Modul 4.16).
-- Startereignis + relative Fristen; Ketten-Schritte materialisieren als aufgaben (quelle='ereignis').
create table if not exists public.vermehrungs_ereignisse (
  id uuid primary key default gen_random_uuid(),
  methode text not null check (methode in
    ('kunstschwarm','koeniginnen_kunstschwarm','brutableger','flugling')),
  erstellt_am date not null,
  stammvolk_id uuid,
  jungvolk_id uuid,
  os_bei_erstellung boolean not null default false,
  notiz text,
  betrieb_id uuid not null default private.aktive_betrieb_id()
    references public.betriebe(id) on delete cascade,
  created_by uuid, updated_by uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (betrieb_id, id),
  constraint vermehrung_stammvolk_fk foreign key (betrieb_id, stammvolk_id)
    references public.voelker (betrieb_id, id) on delete set null (stammvolk_id),
  constraint vermehrung_jungvolk_fk foreign key (betrieb_id, jungvolk_id)
    references public.voelker (betrieb_id, id) on delete set null (jungvolk_id)
);
alter table public.vermehrungs_ereignisse enable row level security;
revoke all on public.vermehrungs_ereignisse from anon, public;
grant select, insert, update, delete on public.vermehrungs_ereignisse to authenticated;
create index if not exists idx_vermehrung_stammvolk on public.vermehrungs_ereignisse (betrieb_id, stammvolk_id);
create index if not exists idx_vermehrung_jungvolk  on public.vermehrungs_ereignisse (betrieb_id, jungvolk_id);

drop trigger if exists trg_vermehrung_actor on public.vermehrungs_ereignisse;
create trigger trg_vermehrung_actor before insert or update
  on public.vermehrungs_ereignisse for each row execute function private.set_row_actor();
drop trigger if exists trg_vermehrung_updated on public.vermehrungs_ereignisse;
create trigger trg_vermehrung_updated before update
  on public.vermehrungs_ereignisse for each row execute function private.set_updated_at();

drop policy if exists vermehrung_sel_member on public.vermehrungs_ereignisse;
create policy vermehrung_sel_member on public.vermehrungs_ereignisse
  for select to authenticated using (betrieb_id in (select private.meine_betrieb_ids()));
drop policy if exists vermehrung_ins_writer on public.vermehrungs_ereignisse;
create policy vermehrung_ins_writer on public.vermehrungs_ereignisse
  for insert to authenticated with check (private.kann_schreiben(betrieb_id));
drop policy if exists vermehrung_upd_writer on public.vermehrungs_ereignisse;
create policy vermehrung_upd_writer on public.vermehrungs_ereignisse
  for update to authenticated using (private.kann_schreiben(betrieb_id)) with check (private.kann_schreiben(betrieb_id));
drop policy if exists vermehrung_del_writer on public.vermehrungs_ereignisse;
create policy vermehrung_del_writer on public.vermehrungs_ereignisse
  for delete to authenticated using (private.kann_schreiben(betrieb_id));

-- aufgaben-Erweiterung
alter table public.aufgaben add column if not exists ereignis_id uuid;
alter table public.aufgaben add column if not exists schritt_key text;
alter table public.aufgaben drop constraint if exists aufgaben_quelle_check;
alter table public.aufgaben add constraint aufgaben_quelle_check
  check (quelle in ('manuell','regel','ereignis'));
alter table public.aufgaben add constraint aufgaben_ereignis_fk
  foreign key (betrieb_id, ereignis_id) references public.vermehrungs_ereignisse (betrieb_id, id) on delete cascade;
alter table public.aufgaben add constraint aufgaben_ereignis_chk
  check ((quelle = 'ereignis') = (ereignis_id is not null and schritt_key is not null));
create unique index if not exists aufgaben_ereignis_dedup on public.aufgaben
  (betrieb_id, ereignis_id, schritt_key) where quelle = 'ereignis';
-- ROLLBACK: drop index aufgaben_ereignis_dedup; alter table aufgaben drop constraint aufgaben_ereignis_chk,
--   drop constraint aufgaben_ereignis_fk; alter table aufgaben drop column schritt_key, drop column ereignis_id;
--   (quelle-CHECK auf ('manuell','regel') zurück); drop table vermehrungs_ereignisse;
```

- [ ] **Step 3: Auf Produktion anwenden** (⚠️ FREIGABEPFLICHTIG — nur nach expliziter K01-Zustimmung) via `apply_migration` (name `K01_vermehrungs_ereignisse`).

- [ ] **Step 4: Verifizieren** — `list_tables` (vermehrungs_ereignisse mit 4 Policies/2 Triggern/2 Indizes); `execute_sql` prüft `aufgaben`-Spalten ereignis_id/schritt_key + Constraint `aufgaben_ereignis_chk` + Index `aufgaben_ereignis_dedup`; `get_advisors(security)` **und** `get_advisors(performance)` → 0 neue (FK-Indizes vorhanden).

- [ ] **Step 5: Commit**
```bash
git add supabase/migrations/K01_vermehrungs_ereignisse.sql
git commit -m "feat(vermehrung): Migration K01 vermehrungs_ereignisse + aufgaben-Erweiterung"
```

---

## Task 2: Domain — Methoden-Metadaten + Ereignis-Modell

**Files:** Create `lib/features/vermehrung/domain/vermehrung.dart`, `.../vermehrungs_ereignis.dart`; Test `test/features/vermehrung/vermehrungs_ereignis_test.dart`

- [ ] **Step 1: Failing test**
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:bienen_app/features/vermehrung/domain/vermehrung.dart';
import 'package:bienen_app/features/vermehrung/domain/vermehrungs_ereignis.dart';

void main() {
  test('Methoden-Metadaten: 4 Methoden, Labels, brutfreiBeiErstellung nur schwarmartig', () {
    expect(kVermehrungsMethoden.keys.toSet(),
        {'kunstschwarm', 'koeniginnen_kunstschwarm', 'brutableger', 'flugling'});
    expect(kVermehrungsMethoden['kunstschwarm']!.brutfreiBeiErstellung, isTrue);
    expect(kVermehrungsMethoden['brutableger']!.brutfreiBeiErstellung, isFalse);
    expect(kVermehrungsMethoden['flugling']!.brutfreiBeiErstellung, isFalse);
  });

  test('Ereignis fromJson/toInsertJson: ohne betrieb_id/id, jungvolk null möglich', () {
    final e = VermehrungsEreignis.fromJson({
      'id': 'e1', 'betrieb_id': 'b1', 'methode': 'brutableger', 'erstellt_am': '2026-06-05',
      'stammvolk_id': 'v1', 'jungvolk_id': null, 'os_bei_erstellung': false, 'notiz': null,
    });
    expect(e.id, 'e1');
    expect(e.methode, 'brutableger');
    expect(e.erstelltAm, DateTime(2026, 6, 5));
    expect(e.jungvolkId, isNull);
    final j = e.toInsertJson();
    expect(j.containsKey('betrieb_id'), isFalse);
    expect(j.containsKey('id'), isFalse);
    expect(j['methode'], 'brutableger');
    expect(j['erstellt_am'], '2026-06-05');
  });
}
```

- [ ] **Step 2: Test rot** — `flutter test test/features/vermehrung/vermehrungs_ereignis_test.dart` → FAIL.

- [ ] **Step 3: `vermehrung.dart`**
```dart
/// Vermehrungs-Methoden-Metadaten (Fachkonstante, pure). Quelle: Recherche 25 §10.
class VermehrungsMethode {
  final String key;
  final String label;
  /// Volk ist bei Erstellung brutfrei (nur schwarmartige Methoden) → OS-bei-Erstellung fachlich sinnvoll.
  final bool brutfreiBeiErstellung;
  const VermehrungsMethode({required this.key, required this.label, required this.brutfreiBeiErstellung});
}

const kVermehrungsMethoden = <String, VermehrungsMethode>{
  'kunstschwarm': VermehrungsMethode(key: 'kunstschwarm', label: 'Kunstschwarm', brutfreiBeiErstellung: true),
  'koeniginnen_kunstschwarm': VermehrungsMethode(
      key: 'koeniginnen_kunstschwarm', label: 'Königinnen-Kunstschwarm', brutfreiBeiErstellung: true),
  'brutableger': VermehrungsMethode(key: 'brutableger', label: 'Brutableger', brutfreiBeiErstellung: false),
  'flugling': VermehrungsMethode(key: 'flugling', label: 'Flugling', brutfreiBeiErstellung: false),
};
```

- [ ] **Step 4: `vermehrungs_ereignis.dart`**
```dart
class VermehrungsEreignis {
  final String id;
  final String methode;
  final DateTime erstelltAm;
  final String? stammvolkId;
  final String? jungvolkId;
  final bool osBeiErstellung;
  final String? notiz;
  const VermehrungsEreignis({
    required this.id, required this.methode, required this.erstelltAm,
    this.stammvolkId, this.jungvolkId, this.osBeiErstellung = false, this.notiz,
  });

  static String _iso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  factory VermehrungsEreignis.fromJson(Map<String, dynamic> j) => VermehrungsEreignis(
        id: j['id'] as String,
        methode: j['methode'] as String,
        erstelltAm: DateTime.parse(j['erstellt_am'] as String),
        stammvolkId: j['stammvolk_id'] as String?,
        jungvolkId: j['jungvolk_id'] as String?,
        osBeiErstellung: (j['os_bei_erstellung'] as bool?) ?? false,
        notiz: j['notiz'] as String?,
      );

  /// Ohne betrieb_id/id — DB-Default/gen_random_uuid.
  Map<String, dynamic> toInsertJson() => {
        'methode': methode,
        'erstellt_am': _iso(erstelltAm),
        'stammvolk_id': stammvolkId,
        'jungvolk_id': jungvolkId,
        'os_bei_erstellung': osBeiErstellung,
        'notiz': notiz,
      };
}
```

- [ ] **Step 5: Test grün** — `flutter test test/features/vermehrung/vermehrungs_ereignis_test.dart` → PASS.

- [ ] **Step 6: Commit**
```bash
git add lib/features/vermehrung/domain/vermehrung.dart lib/features/vermehrung/domain/vermehrungs_ereignis.dart test/features/vermehrung/vermehrungs_ereignis_test.dart
git commit -m "feat(vermehrung): Methoden-Metadaten + VermehrungsEreignis-Modell"
```

---

## Task 3: Domain — Ketten-Katalog + Generator (KRITISCH, pure, TDD)

**Files:** Create `lib/features/vermehrung/domain/vermehrungs_ketten.dart`; Test `test/features/vermehrung/vermehrungs_ketten_test.dart`

> **Import:** `vermehrungs_ketten.dart` importiert `aufgabe.dart` (für `aufgabeAusKettenVorschlag`), `vermehrung.dart`, `vermehrungs_ereignis.dart`. Einseitig — `aufgabe.dart` importiert NICHT vermehrung.

- [ ] **Step 1: Failing tests** (Dedup ohne volk_id, überfällig, stichtag-Normalisierung, jungvolk-null, Katalog-Drift, Invarianten)
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:bienen_app/features/aufgaben/domain/aufgabe.dart';
import 'package:bienen_app/features/vermehrung/domain/vermehrung.dart';
import 'package:bienen_app/features/vermehrung/domain/vermehrungs_ereignis.dart';
import 'package:bienen_app/features/vermehrung/domain/vermehrungs_ketten.dart';

VermehrungsEreignis _ev({String methode = 'brutableger', DateTime? am, String? stamm = 'v1', String? jung}) =>
    VermehrungsEreignis(id: 'e1', methode: methode, erstelltAm: am ?? DateTime(2026, 6, 5),
        stammvolkId: stamm, jungvolkId: jung);

Aufgabe _kettenAufgabe(String schrittKey, {String status = 'offen'}) => Aufgabe(
    id: 'a1', titel: 't', kategorie: 'durchsicht', faelligAm: DateTime(2026, 6, 14),
    status: status, quelle: 'ereignis', ereignisId: 'e1', schrittKey: schrittKey);

void main() {
  List<KettenVorschlag> lauf({required DateTime stichtag, List<VermehrungsEreignis>? ev,
          List<Aufgabe> auf = const [], Set<String> aktiv = const {'v1', 'j1'}}) =>
      kettenVorschlaege(stichtag: stichtag, ereignisse: ev ?? [_ev(jung: 'j1')],
          kettenAufgaben: auf, aktiveVolkIds: aktiv);

  test('Katalog-Invarianten: 4 Methoden, je >=1 Schritt, schrittKey eindeutig, chronologisch, tagVon<=tagBis', () {
    expect(kVermehrungsKetten.keys.toSet(), kVermehrungsMethoden.keys.toSet()); // kein Drift
    const erlaubteKat = {'durchsicht', 'behandlung', 'fuetterung', 'schutz', 'werkstatt', 'verwaltung', 'sonstiges'};
    for (final schritte in kVermehrungsKetten.values) {
      expect(schritte, isNotEmpty);
      final keys = schritte.map((s) => s.schrittKey).toList();
      expect(keys.toSet().length, keys.length); // eindeutig
      for (var i = 0; i < schritte.length; i++) {
        expect(schritte[i].tagVon <= schritte[i].tagBis, isTrue);
        if (i > 0) expect(schritte[i - 1].tagVon <= schritte[i].tagVon, isTrue); // chronologisch
        expect(erlaubteKat.contains(schritte[i].kategorie), isTrue);
      }
    }
  });

  test('Vorlauf: Schritt erscheint ab start-14, im Fenster', () {
    // brutableger Tag 9 (start=ende=14.6.), Vorlauf ab 31.5.
    final vor = lauf(stichtag: DateTime(2026, 5, 20)); // vor Vorlauf
    expect(vor.any((v) => v.schritt.schrittKey == 'zellen_brechen'), isFalse);
    final im = lauf(stichtag: DateTime(2026, 6, 1)); // im Vorlauf
    expect(im.any((v) => v.schritt.schrittKey == 'zellen_brechen'), isTrue);
  });

  test('Überfällig: nach fensterEnde bleibt offener Schritt sichtbar mit ueberfaellig=true', () {
    final v = lauf(stichtag: DateTime(2026, 6, 20)); // nach Tag 9 (14.6.)
    final z = v.firstWhere((x) => x.schritt.schrittKey == 'zellen_brechen');
    expect(z.ueberfaellig, isTrue);
  });

  test('Dedup ohne volk_id: angenommener/übersprungener Schritt -> kein Vorschlag mehr', () {
    final an = lauf(stichtag: DateTime(2026, 6, 12), auf: [_kettenAufgabe('zellen_brechen')]);
    expect(an.any((v) => v.schritt.schrittKey == 'zellen_brechen'), isFalse);
    final sk = lauf(stichtag: DateTime(2026, 6, 12), auf: [_kettenAufgabe('zellen_brechen', status: 'uebersprungen')]);
    expect(sk.any((v) => v.schritt.schrittKey == 'zellen_brechen'), isFalse);
  });

  test('stichtag mit Uhrzeit am Rand-Tag (ende) → noch sichtbar (Normalisierung)', () {
    final v = lauf(stichtag: DateTime(2026, 6, 14, 14, 30)); // Tag 9 = 14.6., mit Uhrzeit
    final z = v.where((x) => x.schritt.schrittKey == 'zellen_brechen');
    expect(z.isNotEmpty, isTrue);
    expect(z.first.ueberfaellig, isFalse); // heute==ende, nicht überfällig
  });

  test('Jungvolk null: jungvolk-Ziel-Schritte werden NICHT vorgeschlagen', () {
    // brutableger: beide Schritte ziel=jungvolk; ohne jungvolk_id keine Vorschläge
    final v = lauf(stichtag: DateTime(2026, 6, 12), ev: [_ev(jung: null)]);
    expect(v.where((x) => x.schritt.ziel == KettenZiel.jungvolk), isEmpty);
  });

  test('Ziel-Volk gelöscht (nicht in aktiveVolkIds) → kein Vorschlag', () {
    final v = lauf(stichtag: DateTime(2026, 6, 12), ev: [_ev(jung: 'j1')], aktiv: {}); // v1/j1 weg
    expect(v, isEmpty);
  });

  test('Methode ohne Katalog-Eintrag → Ereignis übersprungen (kein Crash)', () {
    final v = lauf(stichtag: DateTime(2026, 6, 12), ev: [_ev(methode: 'unbekannt', jung: 'j1')]);
    expect(v, isEmpty);
  });

  test('aufgabeAusKettenVorschlag: quelle=ereignis mit ereignisId/schrittKey', () {
    final v = lauf(stichtag: DateTime(2026, 6, 12)).first;
    final a = aufgabeAusKettenVorschlag(v);
    expect(a.quelle, 'ereignis');
    expect(a.ereignisId, 'e1');
    expect(a.schrittKey, v.schritt.schrittKey);
    expect(a.volkId, v.volkId);
    final sk = aufgabeAusKettenVorschlag(v, status: 'uebersprungen');
    expect(sk.status, 'uebersprungen');
  });
}
```

- [ ] **Step 2: Test rot** — `flutter test test/features/vermehrung/vermehrungs_ketten_test.dart` → FAIL.

- [ ] **Step 3: `vermehrungs_ketten.dart` implementieren**
```dart
import 'package:bienen_app/features/aufgaben/domain/aufgabe.dart';
import 'package:bienen_app/features/vermehrung/domain/vermehrungs_ereignis.dart';

enum KettenZiel { stammvolk, jungvolk }

class KettenSchritt {
  final String schrittKey;
  final String titel;
  final String beschreibung;
  final int tagVon;
  final int tagBis;
  final KettenZiel ziel;
  final String kategorie;
  const KettenSchritt({
    required this.schrittKey, required this.titel, required this.beschreibung,
    required this.tagVon, required this.tagBis, required this.ziel, required this.kategorie,
  });
}

/// Fachliche Ketten (Recherche 25 §10). Kellerhaft-Offset: die "≤7 T nach Einlogieren"-Frist
/// zählt ab Einlogieren (nach 3–5 T Kellerhaft), NICHT ab Tag 0 → konservativ Tag 10–12.
/// Werte sind BGD-Richtwerte (Fachstellen-Check).
const kVermehrungsKetten = <String, List<KettenSchritt>>{
  'brutableger': [
    KettenSchritt(schrittKey: 'zellen_brechen', titel: 'Weiselzellen bis auf 1 ausbrechen',
        beschreibung: 'Überzählige Weiselzellen bis auf 1 (max. 2) ausbrechen. Danach bis zur Weiselkontrolle NICHT öffnen.',
        tagVon: 9, tagBis: 9, ziel: KettenZiel.jungvolk, kategorie: 'durchsicht'),
    KettenSchritt(schrittKey: 'weiselkontrolle_os', titel: 'Weiselkontrolle + Oxalsäure bei Eilage',
        beschreibung: 'Weiselrichtigkeit prüfen; bei Königin in Eilage Oxalsäure sprühen (Oxuvar 5.7 %, 3–4 ml/Wabenseite), idealerweise auf Neubau.',
        tagVon: 25, tagBis: 30, ziel: KettenZiel.jungvolk, kategorie: 'behandlung'),
  ],
  'kunstschwarm': [
    KettenSchritt(schrittKey: 'kellerhaft_ende', titel: 'Kellerhaft beenden, einlogieren',
        beschreibung: 'Nach 3–5 T Kellerhaft: Futterteigverschluss, Mittelwände, einlogieren, füttern.',
        tagVon: 3, tagBis: 5, ziel: KettenZiel.jungvolk, kategorie: 'durchsicht'),
    KettenSchritt(schrittKey: 'weiselkontrolle_os', titel: 'Weiselkontrolle (Königin-Annahme) + Oxalsäure',
        beschreibung: 'Spätestens 7 T nach Einlogieren: Weiselrichtigkeit prüfen (zugesetzte Königin angenommen?). Bei Eilage Oxalsäure sprühen.',
        tagVon: 10, tagBis: 12, ziel: KettenZiel.jungvolk, kategorie: 'behandlung'),
  ],
  'koeniginnen_kunstschwarm': [
    KettenSchritt(schrittKey: 'stammvolk_zellen_brechen', titel: 'Stammvolk: Weiselzellen bis auf 1 ausbrechen',
        beschreibung: '9 T nach Bildung im Stammvolk die Nachschaffungszellen bis auf 1 (max. 2) ausbrechen.',
        tagVon: 9, tagBis: 9, ziel: KettenZiel.stammvolk, kategorie: 'durchsicht'),
    KettenSchritt(schrittKey: 'jungvolk_weiselkontrolle_os', titel: 'Jungvolk: Weiselkontrolle + Oxalsäure',
        beschreibung: 'Spätestens 7 T nach Einlogieren: Weiselrichtigkeit; bei Eilage Oxalsäure sprühen.',
        tagVon: 10, tagBis: 12, ziel: KettenZiel.jungvolk, kategorie: 'behandlung'),
    KettenSchritt(schrittKey: 'stammvolk_weiselkontrolle_os', titel: 'Stammvolk: Weiselkontrolle + Oxalsäure (Doppelbremse)',
        beschreibung: 'Bei Brutfreiheit die zweite Varroa-Bremse nutzen: Oxalsäure vor Verdeckelung der ersten Brut der neuen Königin.',
        tagVon: 25, tagBis: 30, ziel: KettenZiel.stammvolk, kategorie: 'behandlung'),
  ],
  'flugling': [
    KettenSchritt(schrittKey: 'zellen_brechen', titel: 'Flugling: Weiselzellen bis auf 1 ausbrechen',
        beschreibung: '9 T nach Bildung überzählige Weiselzellen bis auf 1 (max. 2) ausbrechen.',
        tagVon: 9, tagBis: 9, ziel: KettenZiel.jungvolk, kategorie: 'durchsicht'),
    KettenSchritt(schrittKey: 'weiselkontrolle_os', titel: 'Flugling: Weiselkontrolle + Oxalsäure',
        beschreibung: '25–30 T nach Bildung Weiselkontrolle; bei Eilage Oxalsäure, auf Neubau setzen.',
        tagVon: 25, tagBis: 30, ziel: KettenZiel.jungvolk, kategorie: 'behandlung'),
    KettenSchritt(schrittKey: 'brutling_os', titel: 'Brutling (Stammvolk): Oxalsäure nach Auslaufen der Brut',
        beschreibung: 'Der Brutling wird mit der gedeckelten Brut milbenärmer; nach Auslaufen der Brut Oxalsäure.',
        tagVon: 25, tagBis: 30, ziel: KettenZiel.stammvolk, kategorie: 'behandlung'),
  ],
};

const kKettenVorlaufTage = 14;

class KettenVorschlag {
  final VermehrungsEreignis ereignis;
  final KettenSchritt schritt;
  final DateTime fensterStart;
  final DateTime fensterEnde;
  final DateTime faelligAm;
  final String? volkId;
  final bool ueberfaellig;
  final String beschreibung;
  const KettenVorschlag({
    required this.ereignis, required this.schritt, required this.fensterStart, required this.fensterEnde,
    required this.faelligAm, required this.volkId, required this.ueberfaellig, required this.beschreibung,
  });
}

DateTime _tag(DateTime d) => DateTime(d.year, d.month, d.day);

/// Reine Funktion: welche Ketten-Schritte stehen am [stichtag] an?
/// Relative Fristen (kalenderunabhängig). DST-sicher (Kalenderkomponenten). Überfällige offene
/// Einmal-Schritte bleiben sichtbar (ueberfaellig=true). Dedup NUR über (ereignis_id, schritt_key).
List<KettenVorschlag> kettenVorschlaege({
  required DateTime stichtag,
  required List<VermehrungsEreignis> ereignisse,
  required List<Aufgabe> kettenAufgaben,
  required Set<String> aktiveVolkIds,
}) {
  final heute = _tag(stichtag);
  final out = <KettenVorschlag>[];
  for (final e in ereignisse) {
    final kette = kVermehrungsKetten[e.methode];
    if (kette == null) continue; // Katalog-Drift-tolerant
    for (final s in kette) {
      // Dedup: existiert eine Ketten-Aufgabe für (ereignis, schritt)?
      final schonMaterialisiert = kettenAufgaben.any((a) =>
          a.ereignisId == e.id && a.schrittKey == s.schrittKey);
      if (schonMaterialisiert) continue;
      // Ziel-Volk
      final volkId = s.ziel == KettenZiel.stammvolk ? e.stammvolkId : e.jungvolkId;
      if (volkId == null) continue;                 // jungvolk noch nicht verknüpft / stammvolk weg
      if (!aktiveVolkIds.contains(volkId)) continue; // Volk gelöscht/inaktiv
      final start = DateTime(e.erstelltAm.year, e.erstelltAm.month, e.erstelltAm.day + s.tagVon);
      final ende = DateTime(e.erstelltAm.year, e.erstelltAm.month, e.erstelltAm.day + s.tagBis);
      final vorlaufGrenze = DateTime(start.year, start.month, start.day - kKettenVorlaufTage);
      if (heute.isBefore(vorlaufGrenze)) continue;   // noch nicht im Vorlauf
      out.add(KettenVorschlag(
        ereignis: e, schritt: s, fensterStart: start, fensterEnde: ende, faelligAm: ende,
        volkId: volkId, ueberfaellig: heute.isAfter(ende), beschreibung: s.beschreibung,
      ));
    }
  }
  out.sort((a, b) => a.faelligAm.compareTo(b.faelligAm));
  return out;
}

/// Für die Ketten-Vorschau im Formular: alle Schritte einer Methode, datiert ab [erstelltAm] (read-only).
List<({KettenSchritt schritt, DateTime von, DateTime bis})> kettenVorschauFuer(String methode, DateTime erstelltAm) {
  final kette = kVermehrungsKetten[methode] ?? const [];
  return [
    for (final s in kette)
      (schritt: s,
       von: DateTime(erstelltAm.year, erstelltAm.month, erstelltAm.day + s.tagVon),
       bis: DateTime(erstelltAm.year, erstelltAm.month, erstelltAm.day + s.tagBis)),
  ];
}

/// Materialisiert einen Vorschlag als normale Aufgabe (quelle='ereignis').
Aufgabe aufgabeAusKettenVorschlag(KettenVorschlag v, {String status = 'offen'}) => Aufgabe(
      id: '', titel: v.schritt.titel, beschreibung: v.beschreibung, kategorie: v.schritt.kategorie,
      faelligAm: v.faelligAm, status: status, volkId: v.volkId,
      quelle: 'ereignis', ereignisId: v.ereignis.id, schrittKey: v.schritt.schrittKey,
    );
```

- [ ] **Step 4: Test grün** — `flutter test test/features/vermehrung/vermehrungs_ketten_test.dart` → PASS.

- [ ] **Step 5: Commit**
```bash
git add lib/features/vermehrung/domain/vermehrungs_ketten.dart test/features/vermehrung/vermehrungs_ketten_test.dart
git commit -m "feat(vermehrung): Ketten-Katalog (4 Methoden) + Generator kettenVorschlaege (pure)"
```

---

## Task 4: Aufgabe-Modell erweitern (+ereignisId/schrittKey) + Formular-Roundtrip

**Files:** Modify `aufgaben/domain/aufgabe.dart`, `aufgaben/presentation/pages/aufgabe_form_page.dart`; Test `test/features/aufgaben/aufgabe_ereignis_test.dart`

- [ ] **Step 1: Failing test**
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:bienen_app/features/aufgaben/domain/aufgabe.dart';

void main() {
  test('quelle=ereignis: ereignisId/schrittKey Roundtrip in toInsertJson', () {
    final a = Aufgabe(id: '', titel: 'x', kategorie: 'behandlung', faelligAm: DateTime(2026, 7, 1),
        quelle: 'ereignis', ereignisId: 'e1', schrittKey: 'zellen_brechen', volkId: 'v1');
    final j = a.toInsertJson();
    expect(j['ereignis_id'], 'e1');
    expect(j['schritt_key'], 'zellen_brechen');
    final b = Aufgabe.fromJson({...j, 'id': 'a1', 'prioritaet': 'normal', 'status': 'offen'});
    expect(b.ereignisId, 'e1');
    expect(b.schrittKey, 'zellen_brechen');
  });

  test('quelle=manuell: ereignis-Felder bleiben null', () {
    final a = Aufgabe(id: '', titel: 'x', kategorie: 'sonstiges', faelligAm: DateTime(2026, 7, 1));
    final j = a.toInsertJson();
    expect(j['ereignis_id'], isNull);
    expect(j['schritt_key'], isNull);
  });
}
```

- [ ] **Step 2: Test rot** — FAIL (Felder existieren nicht).

- [ ] **Step 3: `aufgabe.dart` erweitern** — Felder + Konstruktor + fromJson + toInsertJson:
```dart
  final String? ereignisId;
  final String? schrittKey;
```
Konstruktor: `this.ereignisId, this.schrittKey,` ergänzen. fromJson: `ereignisId: j['ereignis_id'] as String?, schrittKey: j['schritt_key'] as String?,`. toInsertJson: `'ereignis_id': ereignisId, 'schritt_key': schrittKey,` ergänzen (null bei manuell/regel — der DB-CHECK verlangt sie nur bei quelle='ereignis').

- [ ] **Step 4: `aufgabe_form_page.dart` Roundtrip** — im `_speichern` den `Aufgabe(...)`-Aufbau (Z.55-68) um `ereignisId: b?.ereignisId, schrittKey: b?.schrittKey,` ergänzen (sonst bricht der Biconditional-CHECK beim Bearbeiten einer Ketten-Aufgabe).

- [ ] **Step 5: Test grün + Bestandstests** — `flutter test test/features/aufgaben` → alle PASS (149+ Bestand unberührt, da Default-null).

- [ ] **Step 6: Commit**
```bash
git add lib/features/aufgaben/domain/aufgabe.dart lib/features/aufgaben/presentation/pages/aufgabe_form_page.dart test/features/aufgaben/aufgabe_ereignis_test.dart
git commit -m "feat(aufgaben): Aufgabe +ereignisId/schrittKey (quelle=ereignis) + Formular-Roundtrip"
```

---

## Task 5: Gateway-Trio

**Files:** Create `vermehrung/domain/vermehrung_gateway.dart`, `vermehrung/data/{fake,supabase}_vermehrung_gateway.dart`; Test `test/features/vermehrung/vermehrung_gateway_test.dart`

- [ ] **Step 1: Failing test** (Fake-CRUD)
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:bienen_app/features/vermehrung/domain/vermehrungs_ereignis.dart';
import 'package:bienen_app/features/vermehrung/data/fake_vermehrung_gateway.dart';

void main() {
  test('Fake: speichern + alle + jungvolkVerknuepfen + loeschen', () async {
    final gw = FakeVermehrungGateway();
    await gw.speichern(const VermehrungsEreignis(id: '', methode: 'brutableger', erstelltAm: null_, stammvolkId: 'v1'));
    var alle = await gw.alle();
    expect(alle.length, 1);
    final id = alle.first.id;
    await gw.jungvolkVerknuepfen(id, 'j1');
    alle = await gw.alle();
    expect(alle.first.jungvolkId, 'j1');
    await gw.loeschen(id);
    expect((await gw.alle()), isEmpty);
  });
}
```
> Hinweis: `null_` ist Platzhalter — im echten Test `DateTime(2026, 6, 5)` einsetzen (const-Konflikt vermeiden: nicht-const konstruieren).

- [ ] **Step 2: Test rot.**

- [ ] **Step 3: `vermehrung_gateway.dart`**
```dart
import 'package:bienen_app/features/vermehrung/domain/vermehrungs_ereignis.dart';

class VermehrungFehler implements Exception {
  final String code; final String message;
  const VermehrungFehler(this.code, this.message);
  @override String toString() => message;
}

abstract class VermehrungGateway {
  Future<List<VermehrungsEreignis>> alle();
  Future<void> speichern(VermehrungsEreignis e);        // insert wenn id leer, sonst update
  Future<void> jungvolkVerknuepfen(String id, String jungvolkId);
  Future<void> loeschen(String id);
}
```

- [ ] **Step 4: `fake_vermehrung_gateway.dart`**
```dart
import 'package:bienen_app/features/vermehrung/domain/vermehrungs_ereignis.dart';
import 'package:bienen_app/features/vermehrung/domain/vermehrung_gateway.dart';

class FakeVermehrungGateway implements VermehrungGateway {
  final _map = <String, VermehrungsEreignis>{};
  int _seq = 0;
  @override
  Future<List<VermehrungsEreignis>> alle() async => _map.values.toList();
  @override
  Future<void> speichern(VermehrungsEreignis e) async {
    final id = e.id.isEmpty ? 'ev${++_seq}' : e.id;
    _map[id] = VermehrungsEreignis(id: id, methode: e.methode, erstelltAm: e.erstelltAm,
        stammvolkId: e.stammvolkId, jungvolkId: e.jungvolkId, osBeiErstellung: e.osBeiErstellung, notiz: e.notiz);
  }
  @override
  Future<void> jungvolkVerknuepfen(String id, String jungvolkId) async {
    final e = _map[id];
    if (e == null) return;
    _map[id] = VermehrungsEreignis(id: e.id, methode: e.methode, erstelltAm: e.erstelltAm,
        stammvolkId: e.stammvolkId, jungvolkId: jungvolkId, osBeiErstellung: e.osBeiErstellung, notiz: e.notiz);
  }
  @override
  Future<void> loeschen(String id) async => _map.remove(id);
}
```

- [ ] **Step 5: `supabase_vermehrung_gateway.dart`** (Muster supabase_gesundheit_gateway)
```dart
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:bienen_app/features/vermehrung/domain/vermehrungs_ereignis.dart';
import 'package:bienen_app/features/vermehrung/domain/vermehrung_gateway.dart';

class SupabaseVermehrungGateway implements VermehrungGateway {
  final SupabaseClient _c;
  SupabaseVermehrungGateway(this._c);
  Never _rethrow(Object e) {
    if (e is PostgrestException && e.code != null) throw VermehrungFehler(e.code!, e.message);
    throw e;
  }
  @override
  Future<List<VermehrungsEreignis>> alle() async {
    try {
      final res = await _c.from('vermehrungs_ereignisse').select().order('erstellt_am', ascending: false);
      return (res as List).map((j) => VermehrungsEreignis.fromJson(j as Map<String, dynamic>)).toList();
    } catch (e) { _rethrow(e); }
  }
  @override
  Future<void> speichern(VermehrungsEreignis e) async {
    try {
      final json = e.toInsertJson();
      if (e.id.isEmpty) {
        await _c.from('vermehrungs_ereignisse').insert(json);
      } else {
        await _c.from('vermehrungs_ereignisse').update(json).eq('id', e.id);
      }
    } catch (err) { _rethrow(err); }
  }
  @override
  Future<void> jungvolkVerknuepfen(String id, String jungvolkId) async {
    try {
      await _c.from('vermehrungs_ereignisse').update({'jungvolk_id': jungvolkId}).eq('id', id);
    } catch (e) { _rethrow(e); }
  }
  @override
  Future<void> loeschen(String id) async {
    try { await _c.from('vermehrungs_ereignisse').delete().eq('id', id); } catch (e) { _rethrow(e); }
  }
}
```

- [ ] **Step 6: Test grün.**

- [ ] **Step 7: Commit**
```bash
git add lib/features/vermehrung/domain/vermehrung_gateway.dart lib/features/vermehrung/data/ test/features/vermehrung/vermehrung_gateway_test.dart
git commit -m "feat(vermehrung): Gateway-Trio (abstrakt/Fake/Supabase)"
```

---

## Task 6: Provider + Materialisierung + Auth-Reload

**Files:** Create `vermehrung/presentation/providers/vermehrung_provider.dart`; Modify `aufgaben/presentation/providers/aufgaben_provider.dart`, `auth/presentation/auth_providers.dart`

- [ ] **Step 1: `AufgabenNotifier.kettenMaterialisieren`** — in `aufgaben_provider.dart` ergänzen (nutzt speichernBatch → 23505-tolerant, Dedup-Race-sicher):
```dart
  /// Materialisiert einen angenommenen/übersprungenen Ketten-Schritt als Aufgabe (quelle='ereignis').
  Future<void> kettenMaterialisieren(Aufgabe a) async {
    await _gw.speichernBatch([a]);
    ref.invalidateSelf();
  }
```

- [ ] **Step 2: `vermehrung_provider.dart`**
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bienen_app/core/supabase/supabase_config.dart';
import 'package:bienen_app/features/aufgaben/domain/aufgabe.dart';
import 'package:bienen_app/features/aufgaben/presentation/providers/aufgaben_provider.dart';
import 'package:bienen_app/features/vermehrung/data/supabase_vermehrung_gateway.dart';
import 'package:bienen_app/features/vermehrung/domain/vermehrungs_ereignis.dart';
import 'package:bienen_app/features/vermehrung/domain/vermehrung_gateway.dart';
import 'package:bienen_app/features/vermehrung/domain/vermehrungs_ketten.dart';
import 'package:bienen_app/features/voelker/presentation/providers/voelker_provider.dart';

final vermehrungGatewayProvider =
    Provider<VermehrungGateway>((ref) => SupabaseVermehrungGateway(SupabaseConfig.client));

final vermehrungListProvider =
    AsyncNotifierProvider<VermehrungNotifier, List<VermehrungsEreignis>>(VermehrungNotifier.new);

class VermehrungNotifier extends AsyncNotifier<List<VermehrungsEreignis>> {
  VermehrungGateway get _gw => ref.read(vermehrungGatewayProvider);
  @override
  Future<List<VermehrungsEreignis>> build() => _gw.alle();
  Future<void> speichern(VermehrungsEreignis e) async { await _gw.speichern(e); ref.invalidateSelf(); }
  Future<void> jungvolkVerknuepfen(String id, String jungvolkId) async {
    await _gw.jungvolkVerknuepfen(id, jungvolkId); ref.invalidateSelf();
  }
  Future<void> loeschen(String id) async {
    await _gw.loeschen(id);
    ref.invalidateSelf();
    ref.invalidate(aufgabenListProvider); // FK ON DELETE CASCADE hat Ketten-Aufgaben entfernt
  }
}

/// Ketten-Vorschläge (Vermehrung) für den Aufgaben-Tab.
final kettenVorschlaegeProvider = Provider<List<KettenVorschlag>>((ref) {
  final ereignisse = ref.watch(vermehrungListProvider).valueOrNull;
  final aufgaben = ref.watch(aufgabenListProvider).valueOrNull;
  if (ereignisse == null || aufgaben == null) return const [];
  final aktiv = ref.watch(aktiveVoelkerProvider).map((v) => v.id).toSet();
  return kettenVorschlaege(
    stichtag: DateTime.now(),
    ereignisse: ereignisse,
    kettenAufgaben: aufgaben.where((a) => a.quelle == 'ereignis').toList(),
    aktiveVolkIds: aktiv,
  );
});
```

- [ ] **Step 3: Auth-Reload** — `auth_providers.dart` Import + in `_datenNeuLaden()`: `ref.invalidate(vermehrungListProvider);`.

- [ ] **Step 4: analyze** — `flutter analyze lib/features/vermehrung lib/features/aufgaben lib/features/auth` → 0 issues.

- [ ] **Step 5: Commit**
```bash
git add lib/features/vermehrung/presentation/providers/vermehrung_provider.dart lib/features/aufgaben/presentation/providers/aufgaben_provider.dart lib/features/auth/presentation/auth_providers.dart
git commit -m "feat(vermehrung): Provider + kettenVorschlaegeProvider + Materialisierung + Auth-Reload"
```

---

## Task 7: UI — Vorschlags-Karte + Vermehrungs-Sektion im Aufgaben-Tab

**Files:** Create `vermehrung/presentation/widgets/ketten_vorschlag_karte.dart`; Modify `aufgaben/presentation/pages/aufgaben_page.dart`

- [ ] **Step 1: `ketten_vorschlag_karte.dart`** (Muster vorschlag_karte.dart, aber Ziel-Volk steht fest → kein Völker-Dialog)
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:bienen_app/core/theme/app_theme.dart';
import 'package:bienen_app/features/aufgaben/presentation/providers/aufgaben_provider.dart';
import 'package:bienen_app/features/vermehrung/domain/vermehrung.dart';
import 'package:bienen_app/features/vermehrung/domain/vermehrungs_ketten.dart';

class KettenVorschlagKarte extends ConsumerWidget {
  final KettenVorschlag vorschlag;
  const KettenVorschlagKarte({super.key, required this.vorschlag});

  Future<void> _materialisieren(BuildContext context, WidgetRef ref, String status) async {
    try {
      await ref.read(aufgabenListProvider.notifier)
          .kettenMaterialisieren(aufgabeAusKettenVorschlag(vorschlag, status: status));
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fehler: $e')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = vorschlag;
    final methodeLabel = kVermehrungsMethoden[v.ereignis.methode]?.label ?? v.ereignis.methode;
    final von = DateFormat('dd.MM.').format(v.fensterStart);
    final bis = DateFormat('dd.MM.').format(v.faelligAm);
    return Card(
      color: (v.ueberfaellig ? Colors.red : AppColors.honey).withAlpha(18),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.hub, size: 18, color: AppColors.honeyDark),
            const SizedBox(width: 8),
            Expanded(child: Text(v.schritt.titel, style: const TextStyle(fontWeight: FontWeight.w600))),
            if (v.ueberfaellig)
              Padding(padding: const EdgeInsets.only(right: 6),
                  child: Text('überfällig', style: TextStyle(fontSize: 11, color: Colors.red.shade700, fontWeight: FontWeight.w600))),
            Text('$von – $bis', style: const TextStyle(fontSize: 12, color: AppColors.brown300)),
          ]),
          const SizedBox(height: 4),
          Text('$methodeLabel · ${v.schritt.ziel == KettenZiel.stammvolk ? 'Stammvolk' : 'Jungvolk'}',
              style: const TextStyle(fontSize: 12, color: AppColors.brown300)),
          const SizedBox(height: 6),
          Text(v.beschreibung, style: const TextStyle(fontSize: 13, color: AppColors.brown600)),
          const SizedBox(height: 8),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            TextButton(onPressed: () => _materialisieren(context, ref, 'uebersprungen'), child: const Text('Überspringen')),
            const SizedBox(width: 8),
            FilledButton(onPressed: () => _materialisieren(context, ref, 'offen'), child: const Text('Annehmen')),
          ]),
        ]),
      ),
    );
  }
}
```

- [ ] **Step 2: Vermehrungs-Sektion in `aufgaben_page.dart`** — Import `kettenVorschlaegeProvider` + `KettenVorschlagKarte`; im build `final ketten = ref.watch(kettenVorschlaegeProvider);`; in der ListView nach dem Saison-Block:
```dart
              if (darfSchreiben && ketten.isNotEmpty) ...[
                const _SektionTitel('Vermehrung'),
                ...ketten.map((v) => KettenVorschlagKarte(vorschlag: v)),
                const SizedBox(height: 16),
              ],
```
Und `leer` um `&& ketten.isEmpty` erweitern.

- [ ] **Step 3: analyze** — `flutter analyze lib/features/vermehrung lib/features/aufgaben` → 0 issues.

- [ ] **Step 4: Commit**
```bash
git add lib/features/vermehrung/presentation/widgets/ketten_vorschlag_karte.dart lib/features/aufgaben/presentation/pages/aufgaben_page.dart
git commit -m "feat(vermehrung): Ketten-Vorschlags-Karte + Vermehrungs-Sektion im Aufgaben-Tab"
```

---

## Task 8: UI — Erfassungs-Formular + Route

**Files:** Create `vermehrung/presentation/pages/vermehrung_form_page.dart`; Modify `core/router/app_router.dart`

- [ ] **Step 1: `vermehrung_form_page.dart`** (Stammvolk vorbelegt via volkId; Methode/Datum/OS-Switch[nur brutfrei]/Jungvolk/Notiz; Live-Ketten-Vorschau via `kettenVorschauFuer`; erstellt_am-Plausi)
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:bienen_app/core/theme/app_theme.dart';
import 'package:bienen_app/features/auth/presentation/auth_providers.dart';
import 'package:bienen_app/features/vermehrung/domain/vermehrung.dart';
import 'package:bienen_app/features/vermehrung/domain/vermehrungs_ereignis.dart';
import 'package:bienen_app/features/vermehrung/domain/vermehrungs_ketten.dart';
import 'package:bienen_app/features/vermehrung/presentation/providers/vermehrung_provider.dart';
import 'package:bienen_app/features/voelker/presentation/providers/voelker_provider.dart';

class VermehrungFormPage extends ConsumerStatefulWidget {
  final String volkId; // Stammvolk-Kontext
  const VermehrungFormPage({super.key, required this.volkId});
  @override
  ConsumerState<VermehrungFormPage> createState() => _VermehrungFormPageState();
}

class _VermehrungFormPageState extends ConsumerState<VermehrungFormPage> {
  String _methode = 'brutableger';
  DateTime _erstelltAm = DateTime.now();
  bool _os = false;
  String? _jungvolkId;
  final _notiz = TextEditingController();
  bool _speichert = false;

  @override
  void dispose() { _notiz.dispose(); super.dispose(); }

  Future<void> _speichern() async {
    setState(() => _speichert = true);
    try {
      await ref.read(vermehrungListProvider.notifier).speichern(VermehrungsEreignis(
            id: '', methode: _methode, erstelltAm: _erstelltAm, stammvolkId: widget.volkId,
            jungvolkId: _jungvolkId,
            osBeiErstellung: (kVermehrungsMethoden[_methode]?.brutfreiBeiErstellung ?? false) && _os,
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
      return Scaffold(appBar: AppBar(title: const Text('Vermehrung')),
          body: const Center(child: Text('Nur mit Schreibrechten verfügbar.')));
    }
    final voelker = ref.watch(voelkerListProvider).valueOrNull ?? const [];
    final andere = voelker.where((v) => v.id != widget.volkId).toList();
    final meta = kVermehrungsMethoden[_methode]!;
    final heute = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final inZukunft = _erstelltAm.isAfter(heute);
    final langeHer = _erstelltAm.isBefore(heute.subtract(const Duration(days: 60)));
    final vorschau = kettenVorschauFuer(_methode, _erstelltAm);

    return Scaffold(
      appBar: AppBar(title: const Text('Ableger/Vermehrung erfassen')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        DropdownButtonFormField<String>(
          initialValue: _methode,
          decoration: const InputDecoration(labelText: 'Methode'),
          items: [for (final m in kVermehrungsMethoden.values) DropdownMenuItem(value: m.key, child: Text(m.label))],
          onChanged: (v) => setState(() => _methode = v!),
        ),
        const SizedBox(height: 12),
        InputDecorator(
          decoration: InputDecoration(labelText: 'Erstellt am',
              helperText: inZukunft ? 'Datum liegt in der Zukunft' : (langeHer ? 'Über 60 Tage her — Kette evtl. schon abgelaufen' : null),
              helperStyle: (inZukunft || langeHer) ? const TextStyle(color: AppColors.amber800, fontWeight: FontWeight.w600) : null),
          child: InkWell(
            onTap: () async {
              final d = await showDatePicker(context: context, initialDate: _erstelltAm,
                  firstDate: DateTime(2020), lastDate: DateTime(2100));
              if (d != null) setState(() => _erstelltAm = d);
            },
            child: Text(DateFormat('dd.MM.yyyy').format(_erstelltAm)),
          ),
        ),
        if (meta.brutfreiBeiErstellung)
          SwitchListTile(contentPadding: EdgeInsets.zero,
              title: const Text('Oxalsäure bei Erstellung'),
              subtitle: const Text('Brutfreies Jungvolk direkt behandelt (Notiz).'),
              value: _os, onChanged: (on) => setState(() => _os = on)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String?>(
          initialValue: _jungvolkId,
          decoration: const InputDecoration(labelText: 'Jungvolk (optional, später verknüpfbar)'),
          items: [
            const DropdownMenuItem<String?>(value: null, child: Text('— später —')),
            for (final v in andere) DropdownMenuItem(value: v.id, child: Text(v.name)),
          ],
          onChanged: (v) => setState(() => _jungvolkId = v),
        ),
        TextField(controller: _notiz, decoration: const InputDecoration(labelText: 'Notiz'), maxLines: 2),
        const SizedBox(height: 16),
        const Text('Ketten-Vorschau', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        for (final s in vorschau)
          Padding(padding: const EdgeInsets.symmetric(vertical: 2),
            child: Text('Tag ${s.schritt.tagVon}${s.schritt.tagBis != s.schritt.tagVon ? '–${s.schritt.tagBis}' : ''} · '
                '${DateFormat('dd.MM.').format(s.von)}: ${s.schritt.titel} · '
                '${s.schritt.ziel == KettenZiel.stammvolk ? 'Stammvolk' : 'Jungvolk'}',
                style: const TextStyle(fontSize: 12, color: AppColors.brown600))),
        if (_methode == 'flugling')
          const Padding(padding: EdgeInsets.only(top: 6),
            child: Text('Hinweis: Flugling bei regem Flug 11–15 Uhr bilden.',
                style: TextStyle(fontSize: 12, color: AppColors.amber800))),
        const SizedBox(height: 20),
        FilledButton(onPressed: _speichert ? null : _speichern,
            child: Text(_speichert ? 'Speichert…' : 'Vermehrung speichern')),
      ]),
    );
  }
}
```

- [ ] **Step 2: Route** — in `app_router.dart` unter der `/voelker/:id`-`routes:`-Liste (nach `gesundheit`, ~Z.434) ergänzen:
```dart
                GoRoute(
                  path: 'vermehrung',
                  builder: (c, s) => VermehrungFormPage(volkId: s.pathParameters['id']!),
                ),
```
Import `VermehrungFormPage` oben ergänzen.

- [ ] **Step 3: analyze** — `flutter analyze lib/features/vermehrung lib/core/router` → 0 issues.

- [ ] **Step 4: Commit**
```bash
git add lib/features/vermehrung/presentation/pages/vermehrung_form_page.dart lib/core/router/app_router.dart
git commit -m "feat(vermehrung): Erfassungs-Formular + Ketten-Vorschau + Route /voelker/:id/vermehrung"
```

---

## Task 9: UI — Vermehrungs-Sektion auf der Volk-Detailseite

**Files:** Create `vermehrung/presentation/widgets/vermehrung_sektion.dart`; Modify `voelker/.../volk_detail_page.dart`

- [ ] **Step 1: `vermehrung_sektion.dart`** — listet Ereignisse mit diesem Volk als Stamm-/Jungvolk; „Ableger erfassen"-Button; je Ereignis Methode/Datum/Fortschritt + „Jungvolk verknüpfen" (wenn null) + Löschen.
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:bienen_app/core/theme/app_theme.dart';
import 'package:bienen_app/features/auth/presentation/auth_providers.dart';
import 'package:bienen_app/features/aufgaben/presentation/providers/aufgaben_provider.dart';
import 'package:bienen_app/features/vermehrung/domain/vermehrung.dart';
import 'package:bienen_app/features/vermehrung/domain/vermehrungs_ketten.dart';
import 'package:bienen_app/features/vermehrung/presentation/providers/vermehrung_provider.dart';
import 'package:bienen_app/features/voelker/presentation/providers/voelker_provider.dart';

class VermehrungSektion extends ConsumerWidget {
  final String volkId;
  const VermehrungSektion({super.key, required this.volkId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final darf = ref.watch(darfSchreibenProvider);
    final ereignisse = (ref.watch(vermehrungListProvider).valueOrNull ?? const [])
        .where((e) => e.stammvolkId == volkId || e.jungvolkId == volkId).toList();
    final aufgaben = ref.watch(aufgabenListProvider).valueOrNull ?? const [];
    final andere = (ref.watch(voelkerListProvider).valueOrNull ?? const []).where((v) => v.id != volkId).toList();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Expanded(child: Text('Vermehrung', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
        if (darf)
          TextButton.icon(onPressed: () => context.go('/voelker/$volkId/vermehrung'),
              icon: const Icon(Icons.add, size: 18), label: const Text('Ableger erfassen')),
      ]),
      if (ereignisse.isEmpty)
        const Padding(padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('Noch keine Vermehrung erfasst.', style: TextStyle(color: AppColors.brown300))),
      for (final e in ereignisse)
        Builder(builder: (_) {
          final n = (kVermehrungsKetten[e.methode] ?? const []).length;
          final x = aufgaben.where((a) => a.quelle == 'ereignis' && a.ereignisId == e.id).length;
          final rolle = e.stammvolkId == volkId ? 'Stammvolk' : 'Jungvolk';
          return Card(child: ListTile(
            title: Text('${kVermehrungsMethoden[e.methode]?.label ?? e.methode} · $rolle'),
            subtitle: Text('${DateFormat('dd.MM.yyyy').format(e.erstelltAm)} · $x/$n Schritte'
                '${e.jungvolkId == null ? ' · Jungvolk nicht verknüpft' : ''}'),
            trailing: darf ? PopupMenuButton<String>(
              onSelected: (v) async {
                if (v == 'link') { await _jungvolkWaehlen(context, ref, e.id, andere); }
                if (v == 'del') { await _loeschen(context, ref, e.id); }
              },
              itemBuilder: (_) => [
                if (e.jungvolkId == null) const PopupMenuItem(value: 'link', child: Text('Jungvolk verknüpfen')),
                const PopupMenuItem(value: 'del', child: Text('Löschen')),
              ],
            ) : null,
          ));
        }),
    ]);
  }

  Future<void> _jungvolkWaehlen(BuildContext context, WidgetRef ref, String id, List<dynamic> andere) async {
    final gewaehlt = await showDialog<String>(context: context, builder: (_) => SimpleDialog(
      title: const Text('Jungvolk verknüpfen'),
      children: [for (final v in andere) SimpleDialogOption(onPressed: () => Navigator.pop(context, v.id as String), child: Text(v.name as String))],
    ));
    if (gewaehlt != null) {
      try { await ref.read(vermehrungListProvider.notifier).jungvolkVerknuepfen(id, gewaehlt); }
      catch (e) { if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fehler: $e'))); }
    }
  }

  Future<void> _loeschen(BuildContext context, WidgetRef ref, String id) async {
    final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      title: const Text('Ereignis löschen?'),
      content: const Text('Entfernt das Ereignis und seine Ketten-Aufgaben (auch erledigte). Erfasste Behandlungen im Journal bleiben erhalten.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Abbrechen')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Löschen')),
      ],
    ));
    if (ok == true) {
      try { await ref.read(vermehrungListProvider.notifier).loeschen(id); }
      catch (e) { if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fehler: $e'))); }
    }
  }
}
```

- [ ] **Step 2: In `volk_detail_page.dart` einbetten** — die bestehende Struktur lesen (wo Gesundheit-/Fütterung-Sektionen eingebettet sind) und `VermehrungSektion(volkId: volkId)` an derselben Stelle (nach der Gesundheit-Sektion) einfügen, mit vorangehendem Divider/Abstand analog den Nachbar-Sektionen.

- [ ] **Step 3: analyze** — `flutter analyze lib/features/vermehrung lib/features/voelker` → 0 issues.

- [ ] **Step 4: Commit**
```bash
git add lib/features/vermehrung/presentation/widgets/vermehrung_sektion.dart lib/features/voelker/
git commit -m "feat(vermehrung): Vermehrungs-Sektion auf der Volk-Detailseite (erfassen/verknüpfen/löschen)"
```

---

## Task 10: Living-Docs + Version-Bump + Deploy

**Files:** Modify `pubspec.yaml`, `docs/decision-log.md`, `docs/roadmap-app.md`, `ToDo.md`; App-Memory

- [ ] **Step 1: Version** — `pubspec.yaml` → `1.18.0+39`.
- [ ] **Step 2: decision-log** — D-52 (Event-Ketten, 4 Methoden, Blocker-Vermeidung, kein Genericity-Anspruch) + Gotchas (Dedup ohne volk_id, überfällige-Schritte, quelle='ereignis'-Roundtrip im Formular, current_date-CHECK vermieden).
- [ ] **Step 3: roadmap-app.md** — 4.16 Basis LIVE (D1, v1.18.0).
- [ ] **Step 4: ToDo.md** — Stand-Datum, Erledigtes (D1 mit Commit-Range), Offenes (D2 Umlarv/Zucht; 3 deferred Methoden).
- [ ] **Step 5: Volltest + analyze** — `flutter analyze && flutter test` → 0 issues; alle grün (Bestand + neue vermehrung-Tests).
- [ ] **Step 6: Deploy** — `bash deploy.sh` (stehende Freigabe nach grünen Tests); Live-Flip auf 1.18.0 verifizieren.
- [ ] **Step 7: Commit + Memory**
```bash
git add pubspec.yaml docs/decision-log.md docs/roadmap-app.md ToDo.md
git commit -m "chore(vermehrung): v1.18.0 — Living-Docs + Version-Bump + Deploy"
```
App-Memory: neuer Tabellen-Eintrag `vermehrungs_ereignisse` (K01) + aufgaben-Erweiterung + Gotchas.

---

## Self-Review (gegen Spec v2)

**1. Spec-Coverage:** §2.1 Migration → Task 1 ✓ · §2.2 Katalog (4 Ketten) → Task 3 ✓ · §3 Generator (Dedup ohne volk_id, überfällig, stichtag-Normalisierung, jungvolk-null, Katalog-Drift) → Task 3 ✓ · aufgabe +Felder + Formular-Roundtrip → Task 4 ✓ · Gateway/Provider → Task 5/6 ✓ · §4.1 Formular + OS-Switch-Gating + Vorschau → Task 8 ✓ · §4.2 Volk-Sektion (verknüpfen/löschen) → Task 9 ✓ · §4.3 Aufgaben-Tab-Sektion + kategorie='behandlung' → Task 7 ✓ · Route Plural → Task 8 ✓ · §6 Tests → Task 2/3/4/5 ✓ · §7 Deploy → Task 10 ✓.

**2. Placeholder-Scan:** kein TBD; Ketten-Katalog konkret ausformuliert (4 Methoden, alle Schritte). Einziger bewusster Platzhalter: Task 5 Step 1 `null_` (im Text als „DateTime einsetzen" markiert). Task 9 Step 2 (Einbettungsstelle) verweist auf das Lesen der Bestandsstruktur — legitim, da die genaue Zeile variabel ist.

**3. Typ-Konsistenz:** `KettenSchritt`/`KettenZiel`/`KettenVorschlag`/`kettenVorschlaege`/`kettenVorschauFuer`/`aufgabeAusKettenVorschlag` konsistent Task 3/7/8/9. `VermehrungsEreignis`/`toInsertJson` Task 2/5/8. `kettenMaterialisieren` Task 6/7. `Aufgabe.ereignisId/schrittKey` Task 4/3. `kVermehrungsMethoden`/`kVermehrungsKetten` durchgängig.

**Offene Plan-Punkte (bewusst):** Tageswerte sind BGD-Richtwerte (Fachstellen-Check bei realer Saison 2027); die genaue Einbettungszeile der Sektion in `volk_detail_page.dart` liest der Implementierer aus der Bestandsstruktur.
