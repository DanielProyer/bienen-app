# Modul 4.4 „Aufgaben & Kalender" Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Aufgabenverwaltung mit regelbasiertem Saison-Vorschlags-Generator (alpiner Jahresablauf, konfigurierbarer Offset) als neuer Haupt-Tab, plus Dashboard-Kachel und Volk-Detail-Section.

**Architecture:** Tabelle `aufgaben` (normale CRUD via RLS, KEIN RPC, KEIN Soft-Delete; Dedup partieller Unique-Index für Regel-Zeilen). Regel-Katalog (25 Regeln) + Generator als reine Dart-Funktionen (`saison_regeln.dart`, Muster `krankheit.dart`). Feature `lib/features/aufgaben/` nach dem 4.14-Muster (Gateway abstrakt/Fake/Supabase, AsyncNotifier, abgeleitete Provider ohne eigenen Fetch).

**Tech Stack:** Flutter Web 3.41.x, Riverpod AsyncNotifier (ohne Codegen), Go Router (Hash), supabase_flutter, PostgreSQL 15+ (`nulls not distinct`).

**Spec:** `docs/superpowers/specs/2026-07-19-aufgaben-kalender-design.md` (v1, freigegeben). Branch: `feat/aufgaben` (existiert). Version am Ende: **1.14.0+32**.

**WICHTIG — bestehende Bausteine (NICHT neu anlegen):**
- `betriebs_einstellungen.saison_offset_default_tage` existiert seit C01 (Default 0, Arosa-Seed = 42); Dart: `BetriebsEinstellungen.saisonOffsetDefaultTage` ([betriebs_einstellungen.dart](../../lib/features/voelker/domain/betriebs_einstellungen.dart)).
- Provider: `voelkerListProvider`, `aktiveVoelkerProvider`, `standorteProvider`, `betriebsEinstellungenProvider` in [voelker_provider.dart](../../lib/features/voelker/presentation/providers/voelker_provider.dart).
- Auth: `darfSchreibenProvider`, `AuthController._datenNeuLaden()` in [auth_providers.dart](../../lib/features/auth/presentation/auth_providers.dart).
- RLS-Helper: `private.aktive_betrieb_id()`, `private.meine_betrieb_ids()`, `private.kann_schreiben(uuid)`, `private.set_row_actor()`, `private.set_updated_at()` (alle live).

---

## File-Struktur (Ziel)

```
supabase/migrations/H01_aufgaben.sql                     (neu)
lib/features/aufgaben/
  domain/aufgabe.dart                                    (neu — Modell)
  domain/saison_regeln.dart                              (neu — Katalog + Generator, pure)
  domain/aufgaben_gruppierung.dart                       (neu — Fälligkeits-Gruppen, pure)
  domain/aufgaben_gateway.dart                           (neu — abstrakt + Fehler)
  data/fake_aufgaben_gateway.dart                        (neu)
  data/supabase_aufgaben_gateway.dart                    (neu)
  presentation/providers/aufgaben_provider.dart          (neu)
  presentation/pages/aufgaben_page.dart                  (neu)
  presentation/pages/aufgabe_form_page.dart              (neu)
  presentation/widgets/vorschlag_karte.dart              (neu)
  presentation/widgets/aufgaben_section.dart             (neu — Volk-Detail)
test/features/aufgaben/
  aufgabe_test.dart · saison_regeln_test.dart · generator_test.dart
  gruppierung_test.dart · aufgaben_provider_test.dart
Modifiziert: app_router.dart · app_shell.dart · auth_providers.dart ·
  dashboard_page.dart · volk_detail_page.dart · pubspec.yaml
Gelöscht: lib/features/dashboard/pages/todo_page.dart
```

---

### Task 1: Migration H01 schreiben (Datei)

**Files:**
- Create: `supabase/migrations/H01_aufgaben.sql`

- [ ] **Step 1: SQL-Datei schreiben**

```sql
-- H01_aufgaben.sql | Aufgaben & Kalender (Modul 4.4). Operative Arbeitsplanung:
-- normale CRUD via RLS (KEIN RPC, KEIN Soft-Delete, keine Errcodes — kein Journal/Nachweis).
-- Regel-Vorschlaege (quelle='regel') dedupen ueber partiellen Unique-Index (nulls not distinct):
-- eine angenommene ODER uebersprungene Zeile unterdrueckt den Vorschlag dauerhaft.
-- volk-FK ON DELETE CASCADE (Planung darf mit dem Volk verschwinden), standort SET NULL (spaltenqualifiziert).

create table if not exists public.aufgaben (
  id uuid primary key default gen_random_uuid(),
  titel text not null check (length(titel) between 1 and 200),
  beschreibung text,
  kategorie text not null check (kategorie in
    ('durchsicht','behandlung','fuetterung','schutz','werkstatt','verwaltung','sonstiges')),
  faellig_am date not null,
  prioritaet text not null default 'normal' check (prioritaet in ('hoch','normal','niedrig')),
  status text not null default 'offen' check (status in ('offen','erledigt','uebersprungen')),
  erledigt_am timestamptz,
  volk_id uuid,
  standort_id uuid,
  quelle text not null default 'manuell' check (quelle in ('manuell','regel')),
  regel_key text,
  saison_jahr int,
  betrieb_id uuid not null default private.aktive_betrieb_id()
    references public.betriebe(id) on delete cascade,
  created_by uuid, updated_by uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (betrieb_id, id),
  constraint aufgaben_volk_fk foreign key (betrieb_id, volk_id)
    references public.voelker (betrieb_id, id) on delete cascade,
  constraint aufgaben_standort_fk foreign key (betrieb_id, standort_id)
    references public.standorte (betrieb_id, id) on delete set null (standort_id),
  constraint aufgaben_erledigt_chk check ((status = 'erledigt') = (erledigt_am is not null)),
  constraint aufgaben_regel_chk check ((quelle = 'regel') = (regel_key is not null)),
  constraint aufgaben_saison_chk check ((quelle = 'regel') = (saison_jahr is not null))
);
alter table public.aufgaben enable row level security;
revoke all on public.aufgaben from anon, public;
grant select, insert, update, delete on public.aufgaben to authenticated;

create unique index if not exists aufgaben_regel_dedup on public.aufgaben
  (betrieb_id, regel_key, saison_jahr, volk_id, faellig_am) nulls not distinct
  where quelle = 'regel';
create index if not exists idx_aufgaben_status_faellig
  on public.aufgaben (betrieb_id, status, faellig_am);
create index if not exists idx_aufgaben_volk on public.aufgaben (betrieb_id, volk_id);

drop trigger if exists trg_aufgaben_actor on public.aufgaben;
create trigger trg_aufgaben_actor before insert or update
  on public.aufgaben for each row execute function private.set_row_actor();
drop trigger if exists trg_aufgaben_updated on public.aufgaben;
create trigger trg_aufgaben_updated before update
  on public.aufgaben for each row execute function private.set_updated_at();

drop policy if exists aufgaben_sel_member on public.aufgaben;
create policy aufgaben_sel_member on public.aufgaben
  for select to authenticated using (betrieb_id in (select private.meine_betrieb_ids()));
drop policy if exists aufgaben_ins_writer on public.aufgaben;
create policy aufgaben_ins_writer on public.aufgaben
  for insert to authenticated with check (private.kann_schreiben(betrieb_id));
drop policy if exists aufgaben_upd_writer on public.aufgaben;
create policy aufgaben_upd_writer on public.aufgaben
  for update to authenticated using (private.kann_schreiben(betrieb_id))
  with check (private.kann_schreiben(betrieb_id));
drop policy if exists aufgaben_del_writer on public.aufgaben;
create policy aufgaben_del_writer on public.aufgaben
  for delete to authenticated using (private.kann_schreiben(betrieb_id));
```

- [ ] **Step 2: Commit**

```bash
git add supabase/migrations/H01_aufgaben.sql
git commit -m "feat(db): H01 aufgaben-Tabelle (Modul 4.4, normale CRUD + Regel-Dedup-Index)"
```

---

### Task 2: H01 auf Produktion anwenden + verifizieren

**Voraussetzung: explizite Freigabe des Users für die Produktions-Migration liegt vor (wird beim Ausführungs-Start eingeholt).** Supabase-Projekt `dcdcohktxbhdxnxjvcyp`, via MCP-Tool `apply_migration` (Name `h01_aufgaben`, Inhalt = Datei aus Task 1).

- [ ] **Step 1: `apply_migration` mit dem SQL aus Task 1 ausführen**

- [ ] **Step 2: DO-Test — CHECKs + Dedup (via `execute_sql`)**

```sql
do $$
declare v_volk uuid; v_id uuid;
begin
  -- Admin-Kontext als Owner (Gotcha 10)
  perform set_config('app.current_user_id', '57255790-cd8b-4177-a24d-fd0e6bf975a2', true);
  select id into v_volk from public.voelker
    where betrieb_id = '1c84d5dd-d22e-4bce-bba9-5e861b2f4aa4' limit 1;

  -- 1) manuelle Aufgabe ok
  insert into public.aufgaben (titel, kategorie, faellig_am, volk_id, betrieb_id)
    values ('Test', 'sonstiges', current_date, v_volk, '1c84d5dd-d22e-4bce-bba9-5e861b2f4aa4')
    returning id into v_id;

  -- 2) erledigt ohne erledigt_am muss scheitern
  begin
    update public.aufgaben set status = 'erledigt' where id = v_id;
    raise exception 'CHECK erledigt_chk griff nicht';
  exception when check_violation then null;
  end;

  -- 3) regel ohne regel_key muss scheitern
  begin
    insert into public.aufgaben (titel, kategorie, faellig_am, quelle, betrieb_id)
      values ('X', 'sonstiges', current_date, 'regel', '1c84d5dd-d22e-4bce-bba9-5e861b2f4aa4');
    raise exception 'CHECK regel_chk griff nicht';
  exception when check_violation then null;
  end;

  -- 4) Dedup: gleiche Regel-Zeile 2x muss scheitern (nulls not distinct, volk_id null)
  insert into public.aufgaben (titel, kategorie, faellig_am, quelle, regel_key, saison_jahr, betrieb_id)
    values ('R', 'schutz', current_date, 'regel', 'test_regel', 2026, '1c84d5dd-d22e-4bce-bba9-5e861b2f4aa4');
  begin
    insert into public.aufgaben (titel, kategorie, faellig_am, quelle, regel_key, saison_jahr, betrieb_id)
      values ('R', 'schutz', current_date, 'regel', 'test_regel', 2026, '1c84d5dd-d22e-4bce-bba9-5e861b2f4aa4');
    raise exception 'Dedup-Index griff nicht';
  exception when unique_violation then null;
  end;

  -- Aufräumen
  delete from public.aufgaben where titel in ('Test', 'R');
  raise notice 'H01 DO-Tests OK';
end $$;
```

Expected: `H01 DO-Tests OK` (notice), keine Exception.

- [ ] **Step 3: Security-Advisors prüfen**

`get_advisors(type='security')` → **0 neue Findings** (Bestand unverändert).

---

### Task 3: Domain-Modell `Aufgabe`

**Files:**
- Create: `lib/features/aufgaben/domain/aufgabe.dart`
- Test: `test/features/aufgaben/aufgabe_test.dart`

- [ ] **Step 1: Failing Test schreiben**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:bienen_app/features/aufgaben/domain/aufgabe.dart';

void main() {
  test('fromJson/toInsertJson Roundtrip inkl. Regel-Feldern', () {
    final j = {
      'id': 'a1', 'titel': 'Startfütterung', 'beschreibung': null,
      'kategorie': 'fuetterung', 'faellig_am': '2026-07-31',
      'prioritaet': 'hoch', 'status': 'offen', 'erledigt_am': null,
      'volk_id': 'v1', 'standort_id': null,
      'quelle': 'regel', 'regel_key': 'startfuetterung', 'saison_jahr': 2026,
    };
    final a = Aufgabe.fromJson(j);
    expect(a.faelligAm, DateTime(2026, 7, 31));
    expect(a.istOffen, isTrue);
    final ins = a.toInsertJson();
    expect(ins['faellig_am'], '2026-07-31');
    expect(ins['regel_key'], 'startfuetterung');
    expect(ins['saison_jahr'], 2026);
    expect(ins.containsKey('id'), isFalse);
    expect(ins.containsKey('erledigt_am'), isFalse); // wird nur via setzeStatus gesetzt
  });

  test('erledigt: istOffen false, erledigtAm geparst', () {
    final a = Aufgabe.fromJson({
      'id': 'a2', 'titel': 'X', 'kategorie': 'sonstiges', 'faellig_am': '2026-01-01',
      'status': 'erledigt', 'erledigt_am': '2026-01-02T10:00:00Z', 'quelle': 'manuell',
    });
    expect(a.istOffen, isFalse);
    expect(a.erledigtAm, isNotNull);
  });
}
```

- [ ] **Step 2: Test laufen lassen — muss scheitern**

Run: `flutter test test/features/aufgaben/aufgabe_test.dart`
Expected: FAIL (aufgabe.dart existiert nicht)

- [ ] **Step 3: Modell implementieren**

```dart
class Aufgabe {
  final String id;
  final String titel;
  final String? beschreibung;
  final String kategorie; // durchsicht|behandlung|fuetterung|schutz|werkstatt|verwaltung|sonstiges
  final DateTime faelligAm;
  final String prioritaet; // hoch|normal|niedrig
  final String status; // offen|erledigt|uebersprungen
  final DateTime? erledigtAm;
  final String? volkId;
  final String? standortId;
  final String quelle; // manuell|regel
  final String? regelKey;
  final int? saisonJahr;

  const Aufgabe({
    required this.id,
    required this.titel,
    this.beschreibung,
    required this.kategorie,
    required this.faelligAm,
    this.prioritaet = 'normal',
    this.status = 'offen',
    this.erledigtAm,
    this.volkId,
    this.standortId,
    this.quelle = 'manuell',
    this.regelKey,
    this.saisonJahr,
  });

  bool get istOffen => status == 'offen';

  static DateTime _d(Object? v) => DateTime.parse(v as String);
  static String _iso(DateTime d) => d.toIso8601String().substring(0, 10);

  factory Aufgabe.fromJson(Map<String, dynamic> j) => Aufgabe(
        id: j['id'] as String,
        titel: j['titel'] as String,
        beschreibung: j['beschreibung'] as String?,
        kategorie: j['kategorie'] as String,
        faelligAm: _d(j['faellig_am']),
        prioritaet: (j['prioritaet'] as String?) ?? 'normal',
        status: (j['status'] as String?) ?? 'offen',
        erledigtAm: j['erledigt_am'] != null ? _d(j['erledigt_am']) : null,
        volkId: j['volk_id'] as String?,
        standortId: j['standort_id'] as String?,
        quelle: (j['quelle'] as String?) ?? 'manuell',
        regelKey: j['regel_key'] as String?,
        saisonJahr: j['saison_jahr'] as int?,
      );

  /// Ohne id/erledigt_am: id vergibt die DB, erledigt_am nur via setzeStatus.
  Map<String, dynamic> toInsertJson() => {
        'titel': titel,
        'beschreibung': beschreibung,
        'kategorie': kategorie,
        'faellig_am': _iso(faelligAm),
        'prioritaet': prioritaet,
        'status': status,
        'volk_id': volkId,
        'standort_id': standortId,
        'quelle': quelle,
        'regel_key': regelKey,
        'saison_jahr': saisonJahr,
      };
}
```

- [ ] **Step 4: Test laufen lassen — muss grün sein**

Run: `flutter test test/features/aufgaben/aufgabe_test.dart`
Expected: PASS (2 Tests)

- [ ] **Step 5: Commit**

```bash
git add lib/features/aufgaben/domain/aufgabe.dart test/features/aufgaben/aufgabe_test.dart
git commit -m "feat(aufgaben): Domain-Modell Aufgabe"
```

---

### Task 4: Regel-Katalog `saison_regeln.dart` (Katalog + Invarianten)

**Files:**
- Create: `lib/features/aufgaben/domain/saison_regeln.dart` (nur Katalog; Generator kommt in Task 5 in DIESELBE Datei)
- Test: `test/features/aufgaben/saison_regeln_test.dart`

- [ ] **Step 1: Failing Test (Katalog-Invarianten)**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:bienen_app/features/aufgaben/domain/saison_regeln.dart';

void main() {
  test('Katalog: 25 Regeln, Keys unique', () {
    expect(kSaisonRegeln.length, 25);
    expect(kSaisonRegeln.map((r) => r.key).toSet().length, 25);
  });

  test('Kategorien = DB-CHECK-Werte', () {
    const erlaubt = {'durchsicht', 'behandlung', 'fuetterung', 'schutz', 'werkstatt', 'verwaltung', 'sonstiges'};
    for (final r in kSaisonRegeln) {
      expect(erlaubt.contains(r.kategorie), isTrue, reason: r.key);
    }
  });

  test('Fenster valide: Datum konstruierbar, Start <= Ende, KEIN Jahreswechsel', () {
    for (final r in kSaisonRegeln) {
      final start = DateTime(2026, r.startMonat, r.startTag);
      final ende = DateTime(2026, r.endMonat, r.endTag);
      expect(start.month, r.startMonat, reason: '${r.key}: Tag ungültig (Monatsüberlauf)');
      expect(ende.month, r.endMonat, reason: '${r.key}: Tag ungültig (Monatsüberlauf)');
      expect(start.isBefore(ende) || start.isAtSameMomentAs(ende), isTrue,
          reason: '${r.key}: Fenster über Jahreswechsel verboten (Gotcha 11)');
    }
  });

  test('aktionRoute nur bekannte Werte', () {
    const routen = {null, 'durchsicht', 'behandlung', 'fuetterung', 'varroa'};
    for (final r in kSaisonRegeln) {
      expect(routen.contains(r.aktionRoute), isTrue, reason: r.key);
    }
  });

  test('Intervall-Regeln: schwarmkontrolle 7, drohnenschnitt 14', () {
    expect(kSaisonRegeln.firstWhere((r) => r.key == 'schwarmkontrolle').intervallTage, 7);
    expect(kSaisonRegeln.firstWhere((r) => r.key == 'drohnenschnitt').intervallTage, 14);
  });

  test('regelVon: Lookup + null bei unbekanntem Key', () {
    expect(regelVon('schwarmkontrolle')?.intervallTage, 7);
    expect(regelVon('gibts_nicht'), isNull);
    expect(regelVon(null), isNull);
  });

  test('Offset nur auf Frühjahrs-/Trachtregeln (9 Stück)', () {
    expect(kSaisonRegeln.where((r) => r.offsetAnwenden).length, 9);
  });
}
```

- [ ] **Step 2: Test laufen lassen — muss scheitern**

Run: `flutter test test/features/aufgaben/saison_regeln_test.dart`
Expected: FAIL (Datei existiert nicht)

- [ ] **Step 3: Katalog implementieren**

```dart
/// Saison-Regelwerk Modul 4.4 — Fachkonstante (Muster krankheit.dart, KEIN DB-Seed).
/// Quelle: imkerei/02_Recherche/02_Jahresablauf_Imker_Arosa_1570m.md (Kompaktkalender).
/// Basisfenster = Mittelland; `offsetAnwenden` (Frühjahr/Tracht) verschiebt um
/// betriebs_einstellungen.saison_offset_default_tage (Arosa +42 = DATENWERT, kein Code).
/// Herbst-/Winterregeln sind kalenderfix mit alpin-sicheren Fenstern (alpiner Herbst kommt
/// FRÜHER — ein positiver Offset wäre dort falsch; früh einfüttern schadet nie).
library;

enum RegelEbene { volk, betrieb }

class SaisonRegel {
  final String key;
  final String titel;
  final String beschreibung;
  final String kategorie; // = DB-CHECK-Wert
  final RegelEbene ebene;
  final int startMonat, startTag, endMonat, endTag; // Basisfenster (inkl.)
  final bool offsetAnwenden;
  final int? intervallTage;
  final String? aktionRoute; // 'durchsicht'|'behandlung'|'fuetterung'|'varroa'|null

  const SaisonRegel({
    required this.key,
    required this.titel,
    required this.beschreibung,
    required this.kategorie,
    required this.ebene,
    required this.startMonat,
    required this.startTag,
    required this.endMonat,
    required this.endTag,
    this.offsetAnwenden = false,
    this.intervallTage,
    this.aktionRoute,
  });
}

const kSaisonRegeln = <SaisonRegel>[
  // ---- kalenderfix ----
  SaisonRegel(key: 'werkstatt_winter', titel: 'Werkstatt: Rähmchen, Mittelwände, Material',
      beschreibung: 'Winterruhe nutzen: Rähmchen drahten, Mittelwände einlöten, Material für die Saison bestellen.',
      kategorie: 'werkstatt', ebene: RegelEbene.betrieb,
      startMonat: 1, startTag: 1, endMonat: 2, endTag: 28),
  SaisonRegel(key: 'futtervorrat_winter', titel: 'Futtervorrat prüfen (Gewicht/Futterteig)',
      beschreibung: 'Beute von aussen anheben/wägen; bei Bedarf Futterteig direkt aufs Volk legen.',
      kategorie: 'durchsicht', ebene: RegelEbene.volk,
      startMonat: 2, startTag: 1, endMonat: 3, endTag: 20),
  SaisonRegel(key: 'gemuelldiagnose_fruehjahr', titel: 'Gemülldiagnose Frühjahr (Milbenfall)',
      beschreibung: 'Windel einlegen, natürlichen Milbenfall pro Tag zählen — Startwert für die Saison.',
      kategorie: 'behandlung', ebene: RegelEbene.volk,
      startMonat: 3, startTag: 1, endMonat: 3, endTag: 31, aktionRoute: 'varroa'),
  SaisonRegel(key: 'maeuseschutz_entfernen', titel: 'Mäusegitter/Fluglochkeil entfernen',
      beschreibung: 'Nach dem Reinigungsflug Flugloch wieder freigeben (Pollenhöschen dürfen nicht abgestreift werden).',
      kategorie: 'schutz', ebene: RegelEbene.betrieb,
      startMonat: 3, startTag: 15, endMonat: 4, endTag: 15),
  SaisonRegel(key: 'gemuelldiagnose_sommer', titel: 'Gemülldiagnose nach Ernte',
      beschreibung: 'Milbenfall/Tag nach der Ernte messen — Entscheidungsgrundlage für die Sommerbehandlung.',
      kategorie: 'behandlung', ebene: RegelEbene.volk,
      startMonat: 7, startTag: 1, endMonat: 7, endTag: 15, aktionRoute: 'varroa'),
  SaisonRegel(key: 'startfuetterung', titel: 'Startfütterung (~5 kg)',
      beschreibung: 'Nach dem Abschleudern sofort ~5 kg füttern, damit das Volk nicht in eine Futterlücke fällt.',
      kategorie: 'fuetterung', ebene: RegelEbene.volk,
      startMonat: 7, startTag: 15, endMonat: 7, endTag: 31, aktionRoute: 'fuetterung'),
  SaisonRegel(key: 'sommerbehandlung_1', titel: '1. Varroa-Sommerbehandlung starten',
      beschreibung: 'Ameisensäure-Langzeitbehandlung nach der Ernte starten (Temperaturfenster beachten).',
      kategorie: 'behandlung', ebene: RegelEbene.volk,
      startMonat: 7, startTag: 20, endMonat: 8, endTag: 15, aktionRoute: 'behandlung'),
  SaisonRegel(key: 'hauptfuetterung', titel: 'Hauptfütterung (Etappen)',
      beschreibung: 'Winterfutter in 2–3 Etappen auffüttern (Ziel siehe Winterfutter-Balken je Volk).',
      kategorie: 'fuetterung', ebene: RegelEbene.volk,
      startMonat: 8, startTag: 1, endMonat: 8, endTag: 31, aktionRoute: 'fuetterung'),
  SaisonRegel(key: 'sommerbehandlung_2', titel: '2. Varroa-Sommerbehandlung',
      beschreibung: 'Zweite Behandlung nach Abschluss der Fütterung — Wintervölker milbenarm aufziehen.',
      kategorie: 'behandlung', ebene: RegelEbene.volk,
      startMonat: 8, startTag: 25, endMonat: 9, endTag: 20, aktionRoute: 'behandlung'),
  SaisonRegel(key: 'auffuetterung_abschliessen', titel: 'Auffütterung ABSCHLIESSEN (Deadline!)',
      beschreibung: 'Fütterung spätestens jetzt abschliessen, damit das Volk das Futter noch invertieren und verdeckeln kann.',
      kategorie: 'fuetterung', ebene: RegelEbene.volk,
      startMonat: 9, startTag: 1, endMonat: 9, endTag: 10, aktionRoute: 'fuetterung'),
  SaisonRegel(key: 'futterkontrolle_herbst', titel: 'Futterkontrolle + Weiselkontrolle',
      beschreibung: 'Futtervorrat und Weiselrichtigkeit prüfen; schwache Völker jetzt vereinigen.',
      kategorie: 'durchsicht', ebene: RegelEbene.volk,
      startMonat: 9, startTag: 20, endMonat: 10, endTag: 10, aktionRoute: 'durchsicht'),
  SaisonRegel(key: 'maeuseschutz_ansetzen', titel: 'Mäusegitter/Fluglochkeil ansetzen',
      beschreibung: 'Vor dem ersten Frost Mäusegitter montieren — Mäuse zerstören im Winter ganze Völker.',
      kategorie: 'schutz', ebene: RegelEbene.betrieb,
      startMonat: 10, startTag: 1, endMonat: 10, endTag: 31),
  SaisonRegel(key: 'winterfest_machen', titel: 'Winterfest: Windsicherung, Beschwerung, Schnee-Zugang',
      beschreibung: 'Deckel beschweren, Beuten gegen Sturm sichern, Zugang bei Schnee planen.',
      kategorie: 'schutz', ebene: RegelEbene.betrieb,
      startMonat: 10, startTag: 10, endMonat: 10, endTag: 31),
  SaisonRegel(key: 'spechtschutz', titel: 'Spechtschutz anbringen (Netz/Verkleidung)',
      beschreibung: 'Grünspechte hacken im Winter Beuten an — Netz oder Verkleidung anbringen.',
      kategorie: 'schutz', ebene: RegelEbene.betrieb,
      startMonat: 11, startTag: 1, endMonat: 11, endTag: 30),
  SaisonRegel(key: 'brutfreiheit_pruefen', titel: 'Brutfreiheit prüfen (vor Winterbehandlung)',
      beschreibung: 'Nach ~3 Wochen Dauerfrost bzw. ab Mitte November Brutfreiheit kontrollieren.',
      kategorie: 'behandlung', ebene: RegelEbene.volk,
      startMonat: 11, startTag: 1, endMonat: 11, endTag: 20),
  SaisonRegel(key: 'oxalsaeure_winter', titel: 'Oxalsäure-Winterbehandlung (brutfrei)',
      beschreibung: 'Restentmilbung im brutfreien Zustand — träufeln bei geschlossener Wintertraube.',
      kategorie: 'behandlung', ebene: RegelEbene.volk,
      startMonat: 11, startTag: 15, endMonat: 12, endTag: 15, aktionRoute: 'behandlung'),
  // ---- Frühjahr/Tracht (offsetAnwenden) ----
  SaisonRegel(key: 'erste_durchsicht', titel: 'Erste kurze Durchsicht (ab ~15 °C)',
      beschreibung: 'Kurzkontrolle: Volksstärke, Futter, Weiselrichtigkeit — nicht auseinanderreissen.',
      kategorie: 'durchsicht', ebene: RegelEbene.volk,
      startMonat: 3, startTag: 1, endMonat: 3, endTag: 25, offsetAnwenden: true, aktionRoute: 'durchsicht'),
  SaisonRegel(key: 'fruehjahrsdurchsicht', titel: 'Frühjahrsdurchsicht (vollständig)',
      beschreibung: 'Vollständige Durchsicht bei 16–20 °C: Brutbild, Futterkranzprobe, Bodentausch.',
      kategorie: 'durchsicht', ebene: RegelEbene.volk,
      startMonat: 3, startTag: 15, endMonat: 4, endTag: 10, offsetAnwenden: true, aktionRoute: 'durchsicht'),
  SaisonRegel(key: 'wabenhygiene', titel: 'Wabenhygiene/Bodentausch',
      beschreibung: 'Alte, dunkle Waben ausscheiden; Boden tauschen oder reinigen.',
      kategorie: 'durchsicht', ebene: RegelEbene.volk,
      startMonat: 3, startTag: 1, endMonat: 4, endTag: 15, offsetAnwenden: true),
  SaisonRegel(key: 'drohnenrahmen_einsetzen', titel: 'Drohnenrahmen einsetzen',
      beschreibung: 'Drohnenrahmen als biotechnische Varroa-Falle einhängen.',
      kategorie: 'durchsicht', ebene: RegelEbene.volk,
      startMonat: 3, startTag: 20, endMonat: 4, endTag: 10, offsetAnwenden: true),
  SaisonRegel(key: 'drohnenschnitt', titel: 'Drohnenrahmen schneiden',
      beschreibung: 'Verdeckelte Drohnenbrut alle ~14 Tage ausschneiden (Varroa-Entnahme).',
      kategorie: 'durchsicht', ebene: RegelEbene.volk,
      startMonat: 4, startTag: 1, endMonat: 6, endTag: 30, offsetAnwenden: true, intervallTage: 14),
  SaisonRegel(key: 'brutraum_erweitern', titel: 'Brutraum erweitern',
      beschreibung: 'Bei starkem Wachstum Brutraum mit Mittelwänden erweitern.',
      kategorie: 'durchsicht', ebene: RegelEbene.volk,
      startMonat: 4, startTag: 1, endMonat: 4, endTag: 20, offsetAnwenden: true),
  SaisonRegel(key: 'honigraum_aufsetzen', titel: 'Honigraum aufsetzen',
      beschreibung: 'Bei Trachtbeginn Honigraum aufsetzen (Absperrgitter kontrollieren).',
      kategorie: 'durchsicht', ebene: RegelEbene.volk,
      startMonat: 4, startTag: 10, endMonat: 4, endTag: 30, offsetAnwenden: true),
  SaisonRegel(key: 'schwarmkontrolle', titel: 'Schwarmkontrolle (alle 7 Tage!)',
      beschreibung: 'Wöchentlich auf Schwarmzellen kontrollieren — ein versäumter Termin kann das halbe Volk kosten.',
      kategorie: 'durchsicht', ebene: RegelEbene.volk,
      startMonat: 4, startTag: 15, endMonat: 6, endTag: 1, offsetAnwenden: true, intervallTage: 7,
      aktionRoute: 'durchsicht'),
  SaisonRegel(key: 'honigernte', titel: 'Honigernte (Reife prüfen)',
      beschreibung: 'Verdeckelungsgrad/Wassergehalt prüfen, reife Honigwaben abschleudern.',
      kategorie: 'sonstiges', ebene: RegelEbene.volk,
      startMonat: 5, startTag: 20, endMonat: 6, endTag: 5, offsetAnwenden: true),
];

/// Katalog-Lookup (null bei unbekanntem/fehlendem Key — Drift-tolerant).
SaisonRegel? regelVon(String? key) {
  if (key == null) return null;
  for (final r in kSaisonRegeln) {
    if (r.key == key) return r;
  }
  return null;
}
```

- [ ] **Step 4: Test laufen lassen — muss grün sein**

Run: `flutter test test/features/aufgaben/saison_regeln_test.dart`
Expected: PASS (7 Tests)

- [ ] **Step 5: Commit**

```bash
git add lib/features/aufgaben/domain/saison_regeln.dart test/features/aufgaben/saison_regeln_test.dart
git commit -m "feat(aufgaben): Saison-Regelkatalog (25 Regeln, Basis Mittelland + Offset-Flag)"
```

---

### Task 5: Generator `anstehendeVorschlaege()` (in `saison_regeln.dart` ergänzen)

**Files:**
- Modify: `lib/features/aufgaben/domain/saison_regeln.dart` (ans Ende anhängen)
- Test: `test/features/aufgaben/generator_test.dart`

- [ ] **Step 1: Failing Tests schreiben**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:bienen_app/features/aufgaben/domain/aufgabe.dart';
import 'package:bienen_app/features/aufgaben/domain/saison_regeln.dart';

Aufgabe _regelAufgabe(String key, int jahr, DateTime faellig,
        {String status = 'offen', String? volkId = 'v1'}) =>
    Aufgabe(
      id: 'x', titel: 'x', kategorie: 'sonstiges', faelligAm: faellig,
      status: status, volkId: volkId, quelle: 'regel', regelKey: key, saisonJahr: jahr,
    );

void main() {
  // 19.07. ohne Offset: gemuelldiagnose_sommer (bis 15.7.) vorbei; startfuetterung (15.–31.7.)
  // und sommerbehandlung_1 (20.7.–15.8.) aktiv; hauptfuetterung (ab 1.8.) im 14-Tage-Vorlauf.
  test('Fenster ohne Offset: aktive + Vorlauf-Regeln am 19.07.', () {
    final v = anstehendeVorschlaege(
      stichtag: DateTime(2026, 7, 19), saisonOffsetTage: 0,
      regelAufgaben: const [], anzahlAktiveVoelker: 1,
    );
    final keys = v.map((x) => x.regel.key).toSet();
    expect(keys.contains('startfuetterung'), isTrue);
    expect(keys.contains('sommerbehandlung_1'), isTrue);
    expect(keys.contains('hauptfuetterung'), isTrue); // 1.8. liegt <= 14 Tage voraus
    expect(keys.contains('gemuelldiagnose_sommer'), isFalse); // Fenster vorbei
    expect(keys.contains('oxalsaeure_winter'), isFalse);
  });

  test('Offset +42 verschiebt Frühjahrsregeln: honigraum_aufsetzen am 5.6. aktiv', () {
    // Basis 10.4.–30.4. + 42 = 22.5.–11.6.
    final v = anstehendeVorschlaege(
      stichtag: DateTime(2026, 6, 5), saisonOffsetTage: 42,
      regelAufgaben: const [], anzahlAktiveVoelker: 1,
    );
    expect(v.map((x) => x.regel.key), contains('honigraum_aufsetzen'));
    // fix-Regel bleibt unverschoben: startfuetterung am 5.6. NICHT aktiv
    expect(v.map((x) => x.regel.key), isNot(contains('startfuetterung')));
  });

  test('keine volk-Regeln ohne aktive Völker (betrieb-Regeln bleiben)', () {
    final v = anstehendeVorschlaege(
      stichtag: DateTime(2026, 10, 15), saisonOffsetTage: 0,
      regelAufgaben: const [], anzahlAktiveVoelker: 0,
    );
    expect(v.every((x) => x.regel.ebene == RegelEbene.betrieb), isTrue);
    expect(v.map((x) => x.regel.key), contains('maeuseschutz_ansetzen'));
  });

  test('Dedup: angenommene Regel (Zeile vorhanden) wird nicht mehr vorgeschlagen', () {
    final v = anstehendeVorschlaege(
      stichtag: DateTime(2026, 7, 19), saisonOffsetTage: 0,
      regelAufgaben: [_regelAufgabe('startfuetterung', 2026, DateTime(2026, 7, 31))],
      anzahlAktiveVoelker: 1,
    );
    expect(v.map((x) => x.regel.key), isNot(contains('startfuetterung')));
  });

  test('Dedup: übersprungene Regel (volkId null) unterdrückt fürs Saisonjahr', () {
    final v = anstehendeVorschlaege(
      stichtag: DateTime(2026, 7, 19), saisonOffsetTage: 0,
      regelAufgaben: [_regelAufgabe('sommerbehandlung_1', 2026, DateTime(2026, 8, 15),
          status: 'uebersprungen', volkId: null)],
      anzahlAktiveVoelker: 1,
    );
    expect(v.map((x) => x.regel.key), isNot(contains('sommerbehandlung_1')));
  });

  test('Intervall: Schwarmkontrolle nächster Termin = jüngste + 7, erst ab 2 Tagen Vorlauf', () {
    // Offset 0: Fenster 15.4.–1.6. Jüngste Zeile faellig 10.5. → nächster 17.5.
    final basis = [_regelAufgabe('schwarmkontrolle', 2026, DateTime(2026, 5, 10))];
    final am16 = anstehendeVorschlaege(
      stichtag: DateTime(2026, 5, 16), saisonOffsetTage: 0,
      regelAufgaben: basis, anzahlAktiveVoelker: 1,
    );
    final sk16 = am16.where((x) => x.regel.key == 'schwarmkontrolle').toList();
    expect(sk16.single.faelligAm, DateTime(2026, 5, 17));

    final am12 = anstehendeVorschlaege(
      stichtag: DateTime(2026, 5, 12), saisonOffsetTage: 0,
      regelAufgaben: basis, anzahlAktiveVoelker: 1,
    );
    expect(am12.where((x) => x.regel.key == 'schwarmkontrolle'), isEmpty); // 17.5. > 12.5.+2
  });

  test('Intervall: nach Fensterende kein Vorschlag mehr', () {
    final v = anstehendeVorschlaege(
      stichtag: DateTime(2026, 6, 10), saisonOffsetTage: 0,
      regelAufgaben: [_regelAufgabe('schwarmkontrolle', 2026, DateTime(2026, 5, 30))],
      anzahlAktiveVoelker: 1,
    );
    expect(v.where((x) => x.regel.key == 'schwarmkontrolle'), isEmpty); // 6.6. > 1.6. Ende
  });

  test('faelligAm-Default = Fensterende (Deadline-Charakter)', () {
    final v = anstehendeVorschlaege(
      stichtag: DateTime(2026, 9, 5), saisonOffsetTage: 0,
      regelAufgaben: const [], anzahlAktiveVoelker: 1,
    );
    final auf = v.firstWhere((x) => x.regel.key == 'auffuetterung_abschliessen');
    expect(auf.faelligAm, DateTime(2026, 9, 10));
    expect(auf.saisonJahr, 2026);
  });

  test('Jahreswechsel-Vorlauf: werkstatt_winter (ab 1.1.) erscheint schon am 20.12. mit saisonJahr Folgejahr', () {
    final v = anstehendeVorschlaege(
      stichtag: DateTime(2026, 12, 20), saisonOffsetTage: 0,
      regelAufgaben: const [], anzahlAktiveVoelker: 1,
    );
    final w = v.firstWhere((x) => x.regel.key == 'werkstatt_winter');
    expect(w.saisonJahr, 2027);
  });

  test('sortiert nach faelligAm aufsteigend', () {
    final v = anstehendeVorschlaege(
      stichtag: DateTime(2026, 7, 19), saisonOffsetTage: 0,
      regelAufgaben: const [], anzahlAktiveVoelker: 1,
    );
    for (var i = 1; i < v.length; i++) {
      expect(v[i - 1].faelligAm.isAfter(v[i].faelligAm), isFalse);
    }
  });
}
```

- [ ] **Step 2: Test laufen lassen — muss scheitern**

Run: `flutter test test/features/aufgaben/generator_test.dart`
Expected: FAIL (`anstehendeVorschlaege` nicht definiert)

- [ ] **Step 3: Generator implementieren (in `saison_regeln.dart` ergänzen)**

```dart
// --- Generator (unten in saison_regeln.dart anhängen; Import oben ergänzen) ---
// import 'package:bienen_app/features/aufgaben/domain/aufgabe.dart';

/// Vorlauf, mit dem Fenster-Regeln vor Fensterbeginn erscheinen.
const kVorlaufTage = 14;

/// Kürzerer Vorlauf für Intervall-Regeln (sonst erschiene der 7-Tage-Rhythmus sofort wieder).
const kIntervallVorlaufTage = 2;

class AufgabenVorschlag {
  final SaisonRegel regel;
  final DateTime fensterStart;
  final DateTime fensterEnde;
  final DateTime faelligAm;
  final int saisonJahr;
  const AufgabenVorschlag({
    required this.regel,
    required this.fensterStart,
    required this.fensterEnde,
    required this.faelligAm,
    required this.saisonJahr,
  });
}

DateTime _tag(DateTime d) => DateTime(d.year, d.month, d.day);

/// Reine Funktion: welche Saisonaufgaben stehen am [stichtag] an?
/// [regelAufgaben] = alle Aufgaben mit quelle='regel' (jeder Status — angenommene UND
/// übersprungene Zeilen dedupen). Saison-Anker gekapselt: Kandidatenjahre Vorjahr/aktuell/Folgejahr
/// (Vorlauf über Jahreswechsel; Gotcha 11 aus 4.6).
List<AufgabenVorschlag> anstehendeVorschlaege({
  required DateTime stichtag,
  required int saisonOffsetTage,
  required List<Aufgabe> regelAufgaben,
  required int anzahlAktiveVoelker,
}) {
  final heute = _tag(stichtag);
  final out = <AufgabenVorschlag>[];
  for (final r in kSaisonRegeln) {
    if (r.ebene == RegelEbene.volk && anzahlAktiveVoelker == 0) continue;
    final offset = Duration(days: r.offsetAnwenden ? saisonOffsetTage : 0);
    for (final jahr in [heute.year - 1, heute.year, heute.year + 1]) {
      final start = DateTime(jahr, r.startMonat, r.startTag).add(offset);
      final ende = DateTime(jahr, r.endMonat, r.endTag).add(offset);
      if (heute.isAfter(ende)) continue;
      final vorhanden = regelAufgaben
          .where((a) => a.regelKey == r.key && a.saisonJahr == jahr)
          .toList();
      if (vorhanden.any((a) => a.status == 'uebersprungen' && a.volkId == null)) continue;
      if (r.intervallTage == null) {
        if (vorhanden.isNotEmpty) continue;
        if (heute.isBefore(start.subtract(const Duration(days: kVorlaufTage)))) continue;
        out.add(AufgabenVorschlag(
            regel: r, fensterStart: start, fensterEnde: ende, faelligAm: ende, saisonJahr: jahr));
      } else {
        DateTime faellig;
        if (vorhanden.isEmpty) {
          if (heute.isBefore(start.subtract(const Duration(days: kVorlaufTage)))) continue;
          faellig = heute.isBefore(start) ? start : heute;
        } else {
          final juengste = vorhanden.map((a) => _tag(a.faelligAm)).reduce((a, b) => a.isAfter(b) ? a : b);
          faellig = juengste.add(Duration(days: r.intervallTage!));
          if (faellig.difference(heute).inDays > kIntervallVorlaufTage) continue;
        }
        if (faellig.isAfter(ende)) continue;
        out.add(AufgabenVorschlag(
            regel: r, fensterStart: start, fensterEnde: ende, faelligAm: faellig, saisonJahr: jahr));
      }
    }
  }
  out.sort((a, b) => a.faelligAm.compareTo(b.faelligAm));
  return out;
}
```

- [ ] **Step 4: Beide Domain-Tests laufen lassen — müssen grün sein**

Run: `flutter test test/features/aufgaben/generator_test.dart test/features/aufgaben/saison_regeln_test.dart`
Expected: PASS (17 Tests)

- [ ] **Step 5: Commit**

```bash
git add lib/features/aufgaben/domain/saison_regeln.dart test/features/aufgaben/generator_test.dart
git commit -m "feat(aufgaben): Vorschlags-Generator anstehendeVorschlaege() (pure, Offset/Dedup/Intervall)"
```

---

### Task 6: Fälligkeits-Gruppierung (pure)

**Files:**
- Create: `lib/features/aufgaben/domain/aufgaben_gruppierung.dart`
- Test: `test/features/aufgaben/gruppierung_test.dart`

- [ ] **Step 1: Failing Test schreiben**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:bienen_app/features/aufgaben/domain/aufgabe.dart';
import 'package:bienen_app/features/aufgaben/domain/aufgaben_gruppierung.dart';

Aufgabe _a(String id, DateTime f, {String status = 'offen'}) =>
    Aufgabe(id: id, titel: id, kategorie: 'sonstiges', faelligAm: f, status: status);

void main() {
  final heute = DateTime(2026, 7, 19);

  test('gruppiert offene Aufgaben nach Fälligkeit', () {
    final g = gruppiereOffene([
      _a('u', DateTime(2026, 7, 10)),
      _a('h', DateTime(2026, 7, 19)),
      _a('d', DateTime(2026, 7, 30)),
      _a('s', DateTime(2026, 9, 1)),
      _a('e', DateTime(2026, 7, 1), status: 'erledigt'),
      _a('x', DateTime(2026, 7, 1), status: 'uebersprungen'),
    ], heute);
    expect(g[AufgabenGruppe.ueberfaellig]!.single.id, 'u');
    expect(g[AufgabenGruppe.heute]!.single.id, 'h');
    expect(g[AufgabenGruppe.demnaechst]!.single.id, 'd');
    expect(g[AufgabenGruppe.spaeter]!.single.id, 's');
  });

  test('Grenze: heute+14 ist demnächst, heute+15 später; innerhalb sortiert', () {
    final g = gruppiereOffene([
      _a('b', DateTime(2026, 8, 2)),  // +14
      _a('c', DateTime(2026, 8, 3)),  // +15
      _a('a', DateTime(2026, 7, 25)),
    ], heute);
    expect(g[AufgabenGruppe.demnaechst]!.map((x) => x.id).toList(), ['a', 'b']);
    expect(g[AufgabenGruppe.spaeter]!.single.id, 'c');
  });
}
```

- [ ] **Step 2: Test laufen lassen — muss scheitern**

Run: `flutter test test/features/aufgaben/gruppierung_test.dart`
Expected: FAIL (Datei existiert nicht)

- [ ] **Step 3: Implementieren**

```dart
import 'package:bienen_app/features/aufgaben/domain/aufgabe.dart';

enum AufgabenGruppe { ueberfaellig, heute, demnaechst, spaeter }

/// Gruppiert OFFENE Aufgaben nach Fälligkeit relativ zu [stichtag] (nur Datumsteil).
/// demnaechst = 1..14 Tage voraus. Innerhalb jeder Gruppe aufsteigend nach faellig_am.
Map<AufgabenGruppe, List<Aufgabe>> gruppiereOffene(List<Aufgabe> alle, DateTime stichtag) {
  final h = DateTime(stichtag.year, stichtag.month, stichtag.day);
  final offen = alle.where((a) => a.status == 'offen').toList()
    ..sort((a, b) => a.faelligAm.compareTo(b.faelligAm));
  final m = {for (final g in AufgabenGruppe.values) g: <Aufgabe>[]};
  for (final a in offen) {
    final f = DateTime(a.faelligAm.year, a.faelligAm.month, a.faelligAm.day);
    final diff = f.difference(h).inDays;
    if (diff < 0) {
      m[AufgabenGruppe.ueberfaellig]!.add(a);
    } else if (diff == 0) {
      m[AufgabenGruppe.heute]!.add(a);
    } else if (diff <= 14) {
      m[AufgabenGruppe.demnaechst]!.add(a);
    } else {
      m[AufgabenGruppe.spaeter]!.add(a);
    }
  }
  return m;
}
```

- [ ] **Step 4: Test laufen lassen — muss grün sein**

Run: `flutter test test/features/aufgaben/gruppierung_test.dart`
Expected: PASS (2 Tests)

- [ ] **Step 5: Commit**

```bash
git add lib/features/aufgaben/domain/aufgaben_gruppierung.dart test/features/aufgaben/gruppierung_test.dart
git commit -m "feat(aufgaben): Fälligkeits-Gruppierung (pure)"
```

---

### Task 7: Gateway (abstrakt + Fake)

**Files:**
- Create: `lib/features/aufgaben/domain/aufgaben_gateway.dart`
- Create: `lib/features/aufgaben/data/fake_aufgaben_gateway.dart`
- Test: `test/features/aufgaben/aufgaben_provider_test.dart` (erster Teil)

- [ ] **Step 1: Abstraktes Gateway schreiben**

```dart
import 'package:bienen_app/features/aufgaben/domain/aufgabe.dart';

class AufgabenFehler implements Exception {
  final String code;
  final String message;
  const AufgabenFehler(this.code, this.message);
  @override
  String toString() => message;
}

abstract class AufgabenGateway {
  Future<List<Aufgabe>> alle(); // ganzer Betrieb, faellig_am aufsteigend
  Future<void> speichern(Aufgabe a); // insert wenn id leer, sonst update
  /// Vorschlag annehmen/überspringen: mehrere Zeilen; Dedup-Konflikte (23505) still ignorieren.
  Future<void> speichernBatch(List<Aufgabe> aufgaben);
  Future<void> setzeStatus(String id, String status, {DateTime? erledigtAm});
  Future<void> loeschen(String id);
}
```

- [ ] **Step 2: Fake-Gateway schreiben**

```dart
import 'package:bienen_app/features/aufgaben/domain/aufgabe.dart';
import 'package:bienen_app/features/aufgaben/domain/aufgaben_gateway.dart';

class FakeAufgabenGateway implements AufgabenGateway {
  final List<Aufgabe> _rows = [];
  int _seq = 0;

  String _key(Aufgabe a) => '${a.regelKey}|${a.saisonJahr}|${a.volkId}|${a.faelligAm}';

  @override
  Future<List<Aufgabe>> alle() async =>
      List.of(_rows)..sort((a, b) => a.faelligAm.compareTo(b.faelligAm));

  @override
  Future<void> speichern(Aufgabe a) async {
    if (a.id.isEmpty) {
      _rows.add(Aufgabe(
        id: 'f${++_seq}', titel: a.titel, beschreibung: a.beschreibung,
        kategorie: a.kategorie, faelligAm: a.faelligAm, prioritaet: a.prioritaet,
        status: a.status, volkId: a.volkId, standortId: a.standortId,
        quelle: a.quelle, regelKey: a.regelKey, saisonJahr: a.saisonJahr,
      ));
    } else {
      final i = _rows.indexWhere((x) => x.id == a.id);
      if (i >= 0) _rows[i] = a;
    }
  }

  @override
  Future<void> speichernBatch(List<Aufgabe> aufgaben) async {
    for (final a in aufgaben) {
      // Dedup wie der DB-Index: gleiche Regel-Zeile still überspringen.
      if (a.quelle == 'regel' &&
          _rows.any((x) => x.quelle == 'regel' && _key(x) == _key(a))) {
        continue;
      }
      await speichern(a);
    }
  }

  @override
  Future<void> setzeStatus(String id, String status, {DateTime? erledigtAm}) async {
    final i = _rows.indexWhere((x) => x.id == id);
    if (i < 0) return;
    final a = _rows[i];
    _rows[i] = Aufgabe(
      id: a.id, titel: a.titel, beschreibung: a.beschreibung, kategorie: a.kategorie,
      faelligAm: a.faelligAm, prioritaet: a.prioritaet, status: status,
      erledigtAm: erledigtAm, volkId: a.volkId, standortId: a.standortId,
      quelle: a.quelle, regelKey: a.regelKey, saisonJahr: a.saisonJahr,
    );
  }

  @override
  Future<void> loeschen(String id) async => _rows.removeWhere((x) => x.id == id);
}
```

- [ ] **Step 3: Smoke-Test (läuft erst nach Task 8 vollständig — hier nur Fake-CRUD)**

In `test/features/aufgaben/aufgaben_provider_test.dart` anlegen:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:bienen_app/features/aufgaben/data/fake_aufgaben_gateway.dart';
import 'package:bienen_app/features/aufgaben/domain/aufgabe.dart';

void main() {
  test('Fake: Batch dedupt Regel-Zeilen wie der DB-Index', () async {
    final gw = FakeAufgabenGateway();
    final r = Aufgabe(
      id: '', titel: 'R', kategorie: 'schutz', faelligAm: DateTime(2026, 10, 31),
      quelle: 'regel', regelKey: 'maeuseschutz_ansetzen', saisonJahr: 2026,
    );
    await gw.speichernBatch([r, r]);
    expect((await gw.alle()).length, 1);
  });

  test('Fake: setzeStatus + loeschen', () async {
    final gw = FakeAufgabenGateway();
    await gw.speichern(Aufgabe(id: '', titel: 'M', kategorie: 'sonstiges', faelligAm: DateTime(2026, 8, 1)));
    final id = (await gw.alle()).single.id;
    await gw.setzeStatus(id, 'erledigt', erledigtAm: DateTime(2026, 8, 1, 12));
    expect((await gw.alle()).single.status, 'erledigt');
    await gw.loeschen(id);
    expect(await gw.alle(), isEmpty);
  });
}
```

- [ ] **Step 4: Tests laufen lassen — müssen grün sein**

Run: `flutter test test/features/aufgaben/aufgaben_provider_test.dart`
Expected: PASS (2 Tests)

- [ ] **Step 5: Commit**

```bash
git add lib/features/aufgaben/domain/aufgaben_gateway.dart lib/features/aufgaben/data/fake_aufgaben_gateway.dart test/features/aufgaben/aufgaben_provider_test.dart
git commit -m "feat(aufgaben): Gateway-Abstraktion + Fake (Batch-Dedup wie DB-Index)"
```

---

### Task 8: Supabase-Gateway

**Files:**
- Create: `lib/features/aufgaben/data/supabase_aufgaben_gateway.dart`

- [ ] **Step 1: Implementieren (Muster [supabase_gesundheit_gateway.dart](../../lib/features/gesundheit/data/supabase_gesundheit_gateway.dart))**

```dart
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:bienen_app/features/aufgaben/domain/aufgabe.dart';
import 'package:bienen_app/features/aufgaben/domain/aufgaben_gateway.dart';

class SupabaseAufgabenGateway implements AufgabenGateway {
  final SupabaseClient _c;
  SupabaseAufgabenGateway(this._c);

  Never _rethrow(Object e) {
    if (e is PostgrestException && e.code != null) {
      throw AufgabenFehler(e.code!, e.message);
    }
    throw e;
  }

  @override
  Future<List<Aufgabe>> alle() async {
    try {
      final res = await _c.from('aufgaben').select().order('faellig_am', ascending: true);
      return (res as List).map((j) => Aufgabe.fromJson(j as Map<String, dynamic>)).toList();
    } catch (e) {
      _rethrow(e);
    }
  }

  @override
  Future<void> speichern(Aufgabe a) async {
    try {
      final json = a.toInsertJson();
      if (a.id.isEmpty) {
        await _c.from('aufgaben').insert(json);
      } else {
        await _c.from('aufgaben').update(json).eq('id', a.id);
      }
    } catch (e) {
      _rethrow(e);
    }
  }

  @override
  Future<void> speichernBatch(List<Aufgabe> aufgaben) async {
    if (aufgaben.isEmpty) return;
    try {
      await _c.from('aufgaben').insert(aufgaben.map((a) => a.toInsertJson()).toList());
    } on PostgrestException catch (e) {
      if (e.code == '23505') return; // Dedup-Index: Doppelklick, still ignorieren
      _rethrow(e);
    } catch (e) {
      _rethrow(e);
    }
  }

  @override
  Future<void> setzeStatus(String id, String status, {DateTime? erledigtAm}) async {
    try {
      await _c.from('aufgaben').update({
        'status': status,
        'erledigt_am': erledigtAm?.toIso8601String(),
      }).eq('id', id);
    } catch (e) {
      _rethrow(e);
    }
  }

  @override
  Future<void> loeschen(String id) async {
    try {
      await _c.from('aufgaben').delete().eq('id', id);
    } catch (e) {
      _rethrow(e);
    }
  }
}
```

- [ ] **Step 2: Analyse laufen lassen**

Run: `flutter analyze lib/features/aufgaben`
Expected: No issues found

- [ ] **Step 3: Commit**

```bash
git add lib/features/aufgaben/data/supabase_aufgaben_gateway.dart
git commit -m "feat(aufgaben): Supabase-Gateway (Batch-Insert, 23505 still)"
```

---

### Task 9: Provider + Auth-Reload

**Files:**
- Create: `lib/features/aufgaben/presentation/providers/aufgaben_provider.dart`
- Modify: `lib/features/auth/presentation/auth_providers.dart` (Import + eine Zeile in `_datenNeuLaden`)
- Test: `test/features/aufgaben/aufgaben_provider_test.dart` (erweitern)

- [ ] **Step 1: Failing Tests ergänzen (an bestehende Datei anhängen)**

```dart
// Zusätzliche Imports oben in der Testdatei:
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:bienen_app/features/aufgaben/domain/saison_regeln.dart';
// import 'package:bienen_app/features/aufgaben/presentation/providers/aufgaben_provider.dart';

  test('Notifier: vorschlagAnnehmen legt je Volk eine Regel-Zeile an', () async {
    final gw = FakeAufgabenGateway();
    final c = ProviderContainer(overrides: [aufgabenGatewayProvider.overrideWithValue(gw)]);
    addTearDown(c.dispose);
    await c.read(aufgabenListProvider.future);
    final regel = kSaisonRegeln.firstWhere((r) => r.key == 'startfuetterung');
    final v = AufgabenVorschlag(
      regel: regel, fensterStart: DateTime(2026, 7, 15), fensterEnde: DateTime(2026, 7, 31),
      faelligAm: DateTime(2026, 7, 31), saisonJahr: 2026,
    );
    await c.read(aufgabenListProvider.notifier).vorschlagAnnehmen(v, volkIds: ['v1', 'v2']);
    final rows = await gw.alle();
    expect(rows.length, 2);
    expect(rows.every((a) => a.regelKey == 'startfuetterung' && a.status == 'offen'), isTrue);
    expect(rows.map((a) => a.volkId).toSet(), {'v1', 'v2'});
  });

  test('Notifier: vorschlagUeberspringen legt EINE Zeile ohne volk_id an', () async {
    final gw = FakeAufgabenGateway();
    final c = ProviderContainer(overrides: [aufgabenGatewayProvider.overrideWithValue(gw)]);
    addTearDown(c.dispose);
    await c.read(aufgabenListProvider.future);
    final regel = kSaisonRegeln.firstWhere((r) => r.key == 'sommerbehandlung_1');
    final v = AufgabenVorschlag(
      regel: regel, fensterStart: DateTime(2026, 7, 20), fensterEnde: DateTime(2026, 8, 15),
      faelligAm: DateTime(2026, 8, 15), saisonJahr: 2026,
    );
    await c.read(aufgabenListProvider.notifier).vorschlagUeberspringen(v);
    final rows = await gw.alle();
    expect(rows.single.status, 'uebersprungen');
    expect(rows.single.volkId, isNull);
  });

  test('offeneAufgabenStatsProvider zählt offen + überfällig', () async {
    final gw = FakeAufgabenGateway();
    await gw.speichern(Aufgabe(id: '', titel: 'alt', kategorie: 'sonstiges', faelligAm: DateTime(2020, 1, 1)));
    await gw.speichern(Aufgabe(id: '', titel: 'zukunft', kategorie: 'sonstiges', faelligAm: DateTime(2099, 1, 1)));
    final c = ProviderContainer(overrides: [aufgabenGatewayProvider.overrideWithValue(gw)]);
    addTearDown(c.dispose);
    await c.read(aufgabenListProvider.future);
    final stats = c.read(offeneAufgabenStatsProvider);
    expect(stats.offen, 2);
    expect(stats.ueberfaellig, 1);
  });

  test('aufgabenFuerVolkProvider: nur offene des Volks', () async {
    final gw = FakeAufgabenGateway();
    await gw.speichern(Aufgabe(id: '', titel: 'a', kategorie: 'sonstiges', faelligAm: DateTime(2026, 8, 1), volkId: 'v1'));
    await gw.speichern(Aufgabe(id: '', titel: 'b', kategorie: 'sonstiges', faelligAm: DateTime(2026, 8, 1), volkId: 'v2'));
    final c = ProviderContainer(overrides: [aufgabenGatewayProvider.overrideWithValue(gw)]);
    addTearDown(c.dispose);
    await c.read(aufgabenListProvider.future);
    expect(c.read(aufgabenFuerVolkProvider('v1')).single.titel, 'a');
  });
```

- [ ] **Step 2: Test laufen lassen — muss scheitern**

Run: `flutter test test/features/aufgaben/aufgaben_provider_test.dart`
Expected: FAIL (Provider existieren nicht)

- [ ] **Step 3: Provider implementieren**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bienen_app/core/supabase/supabase_config.dart';
import 'package:bienen_app/features/aufgaben/data/supabase_aufgaben_gateway.dart';
import 'package:bienen_app/features/aufgaben/domain/aufgabe.dart';
import 'package:bienen_app/features/aufgaben/domain/aufgaben_gateway.dart';
import 'package:bienen_app/features/aufgaben/domain/saison_regeln.dart';
import 'package:bienen_app/features/voelker/presentation/providers/voelker_provider.dart';

final aufgabenGatewayProvider =
    Provider<AufgabenGateway>((ref) => SupabaseAufgabenGateway(SupabaseConfig.client));

final aufgabenListProvider =
    AsyncNotifierProvider<AufgabenNotifier, List<Aufgabe>>(AufgabenNotifier.new);

class AufgabenNotifier extends AsyncNotifier<List<Aufgabe>> {
  AufgabenGateway get _gw => ref.read(aufgabenGatewayProvider);
  @override
  Future<List<Aufgabe>> build() => _gw.alle();

  Future<void> speichern(Aufgabe a) async {
    await _gw.speichern(a);
    ref.invalidateSelf();
  }

  Future<void> loeschen(String id) async {
    await _gw.loeschen(id);
    ref.invalidateSelf();
  }

  Future<void> abhaken(String id, {bool erledigt = true}) async {
    await _gw.setzeStatus(id, erledigt ? 'erledigt' : 'offen',
        erledigtAm: erledigt ? DateTime.now() : null);
    ref.invalidateSelf();
  }

  Aufgabe _ausVorschlag(AufgabenVorschlag v, {String? volkId, String status = 'offen'}) => Aufgabe(
        id: '', titel: v.regel.titel, beschreibung: v.regel.beschreibung,
        kategorie: v.regel.kategorie, faelligAm: v.faelligAm, status: status,
        volkId: volkId, quelle: 'regel', regelKey: v.regel.key, saisonJahr: v.saisonJahr,
      );

  /// ebene=volk: eine Zeile je [volkIds]; ebene=betrieb: volkIds ignorieren (eine Zeile).
  Future<void> vorschlagAnnehmen(AufgabenVorschlag v, {List<String> volkIds = const []}) async {
    final rows = v.regel.ebene == RegelEbene.volk
        ? volkIds.map((id) => _ausVorschlag(v, volkId: id)).toList()
        : [_ausVorschlag(v)];
    await _gw.speichernBatch(rows);
    ref.invalidateSelf();
  }

  /// Überspringen dedupt die Regel fürs ganze Saisonjahr (eine Zeile OHNE volk_id).
  Future<void> vorschlagUeberspringen(AufgabenVorschlag v) async {
    await _gw.speichernBatch([_ausVorschlag(v, status: 'uebersprungen')]);
    ref.invalidateSelf();
  }
}

/// Offene Aufgaben eines Volks (reine Ableitung — kein eigener Fetch, D-18/D-23-sicher).
final aufgabenFuerVolkProvider = Provider.family<List<Aufgabe>, String>((ref, volkId) {
  final list = ref.watch(aufgabenListProvider).valueOrNull ?? const <Aufgabe>[];
  return list.where((a) => a.istOffen && a.volkId == volkId).toList();
});

/// Dashboard-Kachel: offene + überfällige Anzahl.
final offeneAufgabenStatsProvider = Provider<({int offen, int ueberfaellig})>((ref) {
  final list = ref.watch(aufgabenListProvider).valueOrNull ?? const <Aufgabe>[];
  final heute = DateTime.now();
  final h = DateTime(heute.year, heute.month, heute.day);
  final offen = list.where((a) => a.istOffen).toList();
  final ueberfaellig = offen.where((a) => a.faelligAm.isBefore(h)).length;
  return (offen: offen.length, ueberfaellig: ueberfaellig);
});

/// Generator-Vorschläge (Liste + Einstellungen + aktive Völker kombiniert).
final vorschlaegeProvider = Provider<List<AufgabenVorschlag>>((ref) {
  final aufgaben = ref.watch(aufgabenListProvider).valueOrNull;
  final einst = ref.watch(betriebsEinstellungenProvider).valueOrNull;
  if (aufgaben == null || einst == null) return const [];
  final aktive = ref.watch(aktiveVoelkerProvider);
  return anstehendeVorschlaege(
    stichtag: DateTime.now(),
    saisonOffsetTage: einst.saisonOffsetDefaultTage,
    regelAufgaben: aufgaben.where((a) => a.quelle == 'regel').toList(),
    anzahlAktiveVoelker: aktive.length,
  );
});
```

- [ ] **Step 4: Auth-Reload registrieren (Gotcha 1)**

In `lib/features/auth/presentation/auth_providers.dart`:
Import ergänzen:
```dart
import 'package:bienen_app/features/aufgaben/presentation/providers/aufgaben_provider.dart';
```
In `_datenNeuLaden()` nach `ref.invalidate(gesundheitFuerVolkProvider);` ergänzen:
```dart
    ref.invalidate(aufgabenListProvider);
```

- [ ] **Step 5: Tests laufen lassen — müssen grün sein**

Run: `flutter test test/features/aufgaben/`
Expected: PASS (alle Aufgaben-Tests)

- [ ] **Step 6: Commit**

```bash
git add lib/features/aufgaben/presentation/providers/aufgaben_provider.dart lib/features/auth/presentation/auth_providers.dart test/features/aufgaben/aufgaben_provider_test.dart
git commit -m "feat(aufgaben): Provider (Notifier + Ableitungen) + Auth-Reload"
```

---

### Task 10: UI — AufgabenPage + VorschlagKarte + Nav + Routen

**Files:**
- Create: `lib/features/aufgaben/presentation/widgets/vorschlag_karte.dart`
- Create: `lib/features/aufgaben/presentation/pages/aufgaben_page.dart`
- Modify: `lib/core/router/app_router.dart` (Route `/aufgaben`; Import)
- Modify: `lib/shared/widgets/app_shell.dart` (neuer Tab „Aufgaben" an Index 2)

- [ ] **Step 1: VorschlagKarte implementieren**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:bienen_app/core/theme/app_theme.dart';
import 'package:bienen_app/features/aufgaben/domain/saison_regeln.dart';
import 'package:bienen_app/features/aufgaben/presentation/providers/aufgaben_provider.dart';
import 'package:bienen_app/features/voelker/presentation/providers/voelker_provider.dart';

/// Karte für einen Generator-Vorschlag: Annehmen (ggf. Völker-Auswahl) / Überspringen.
class VorschlagKarte extends ConsumerWidget {
  final AufgabenVorschlag vorschlag;
  const VorschlagKarte({super.key, required this.vorschlag});

  Future<void> _annehmen(BuildContext context, WidgetRef ref) async {
    final notifier = ref.read(aufgabenListProvider.notifier);
    if (vorschlag.regel.ebene == RegelEbene.betrieb) {
      await notifier.vorschlagAnnehmen(vorschlag);
      return;
    }
    final voelker = ref.read(aktiveVoelkerProvider);
    if (voelker.length == 1) {
      await notifier.vorschlagAnnehmen(vorschlag, volkIds: [voelker.single.id]);
      return;
    }
    if (!context.mounted) return;
    final gewaehlt = await showDialog<List<String>>(
      context: context,
      builder: (_) => _VoelkerAuswahlDialog(
          titel: vorschlag.regel.titel,
          voelker: [for (final v in voelker) (id: v.id, name: v.name)]),
    );
    if (gewaehlt == null || gewaehlt.isEmpty) return;
    await notifier.vorschlagAnnehmen(vorschlag, volkIds: gewaehlt);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = vorschlag.regel;
    final bis = DateFormat('dd.MM.').format(vorschlag.faelligAm);
    return Card(
      color: AppColors.honey.withAlpha(18),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.auto_awesome, size: 18, color: AppColors.honeyDark),
              const SizedBox(width: 8),
              Expanded(child: Text(r.titel, style: const TextStyle(fontWeight: FontWeight.w600))),
              Text('bis $bis', style: const TextStyle(fontSize: 12, color: AppColors.brown300)),
            ]),
            const SizedBox(height: 6),
            Text(r.beschreibung, style: const TextStyle(fontSize: 13, color: AppColors.brown600)),
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              TextButton(
                onPressed: () => ref.read(aufgabenListProvider.notifier).vorschlagUeberspringen(vorschlag),
                child: const Text('Überspringen'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: () => _annehmen(context, ref),
                child: const Text('Annehmen'),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

class _VoelkerAuswahlDialog extends StatefulWidget {
  final String titel;
  final List<({String id, String name})> voelker;
  const _VoelkerAuswahlDialog({required this.titel, required this.voelker});
  @override
  State<_VoelkerAuswahlDialog> createState() => _VoelkerAuswahlDialogState();
}

class _VoelkerAuswahlDialogState extends State<_VoelkerAuswahlDialog> {
  late final Set<String> _gewaehlt = widget.voelker.map((v) => v.id).toSet();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.titel),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          for (final v in widget.voelker)
            CheckboxListTile(
              value: _gewaehlt.contains(v.id),
              title: Text(v.name),
              onChanged: (on) => setState(() => on == true ? _gewaehlt.add(v.id) : _gewaehlt.remove(v.id)),
            ),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen')),
        FilledButton(
          onPressed: () => Navigator.pop(context, _gewaehlt.toList()),
          child: const Text('Anlegen'),
        ),
      ],
    );
  }
}
```

- [ ] **Step 2: AufgabenPage implementieren**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:bienen_app/core/theme/app_theme.dart';
import 'package:bienen_app/features/aufgaben/domain/aufgabe.dart';
import 'package:bienen_app/features/aufgaben/domain/aufgaben_gruppierung.dart';
import 'package:bienen_app/features/aufgaben/domain/saison_regeln.dart';
import 'package:bienen_app/features/aufgaben/presentation/providers/aufgaben_provider.dart';
import 'package:bienen_app/features/aufgaben/presentation/widgets/vorschlag_karte.dart';
import 'package:bienen_app/features/auth/presentation/auth_providers.dart';
import 'package:bienen_app/features/voelker/presentation/providers/voelker_provider.dart';

class AufgabenPage extends ConsumerWidget {
  const AufgabenPage({super.key});

  static const _gruppenTitel = {
    AufgabenGruppe.ueberfaellig: 'Überfällig',
    AufgabenGruppe.heute: 'Heute',
    AufgabenGruppe.demnaechst: 'Demnächst',
    AufgabenGruppe.spaeter: 'Später',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(aufgabenListProvider);
    final vorschlaege = ref.watch(vorschlaegeProvider);
    final darfSchreiben = ref.watch(darfSchreibenProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Aufgaben')),
      floatingActionButton: darfSchreiben
          ? FloatingActionButton.extended(
              onPressed: () => context.go('/aufgaben/neu'),
              icon: const Icon(Icons.add),
              label: const Text('Neue Aufgabe'),
            )
          : null,
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Fehler: $e')),
        data: (alle) {
          final gruppen = gruppiereOffene(alle, DateTime.now());
          final erledigt = _kuerzlichErledigt(alle);
          final leer = alle.isEmpty && vorschlaege.isEmpty;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (darfSchreiben && vorschlaege.isNotEmpty) ...[
                const _SektionTitel('Saisonaufgaben'),
                ...vorschlaege.map((v) => VorschlagKarte(vorschlag: v)),
                const SizedBox(height: 16),
              ],
              if (leer)
                const Padding(
                  padding: EdgeInsets.only(top: 48),
                  child: Center(child: Text('Keine Aufgaben — alles im grünen Bereich. 🐝')),
                ),
              for (final g in AufgabenGruppe.values)
                if (gruppen[g]!.isNotEmpty) ...[
                  _SektionTitel(_gruppenTitel[g]!,
                      farbe: g == AufgabenGruppe.ueberfaellig ? Colors.red.shade700 : null),
                  ...gruppen[g]!.map((a) => _AufgabeZeile(
                      aufgabe: a,
                      ueberfaellig: g == AufgabenGruppe.ueberfaellig,
                      darfSchreiben: darfSchreiben)),
                  const SizedBox(height: 12),
                ],
              if (erledigt.isNotEmpty)
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: Text('Erledigt & Übersprungen (${erledigt.length})',
                      style: const TextStyle(fontSize: 14, color: AppColors.brown300)),
                  children: [
                    for (final a in erledigt)
                      _AufgabeZeile(aufgabe: a, ueberfaellig: false, darfSchreiben: darfSchreiben),
                  ],
                ),
              const SizedBox(height: 80),
            ],
          );
        },
      ),
    );
  }

  /// Erledigte/übersprungene der letzten 30 Tage (übersprungene Regel-Marker ohne Volk zeigen wir mit).
  List<Aufgabe> _kuerzlichErledigt(List<Aufgabe> alle) {
    final grenze = DateTime.now().subtract(const Duration(days: 30));
    return alle.where((a) {
      if (a.status == 'erledigt') return a.erledigtAm != null && a.erledigtAm!.isAfter(grenze);
      if (a.status == 'uebersprungen') return a.faelligAm.isAfter(grenze);
      return false;
    }).toList()
      ..sort((a, b) => b.faelligAm.compareTo(a.faelligAm));
  }
}

class _SektionTitel extends StatelessWidget {
  final String text;
  final Color? farbe;
  const _SektionTitel(this.text, {this.farbe});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text,
            style: TextStyle(
                fontSize: 15, fontWeight: FontWeight.bold, color: farbe ?? AppColors.brown800)),
      );
}

class _AufgabeZeile extends ConsumerWidget {
  final Aufgabe aufgabe;
  final bool ueberfaellig;
  final bool darfSchreiben;
  const _AufgabeZeile({required this.aufgabe, required this.ueberfaellig, required this.darfSchreiben});

  static const _kategorieLabel = {
    'durchsicht': 'Durchsicht', 'behandlung': 'Behandlung', 'fuetterung': 'Fütterung',
    'schutz': 'Schutz', 'werkstatt': 'Werkstatt', 'verwaltung': 'Verwaltung', 'sonstiges': 'Sonstiges',
  };

  void _abhaken(BuildContext context, WidgetRef ref, bool erledigt) {
    final notifier = ref.read(aufgabenListProvider.notifier);
    notifier.abhaken(aufgabe.id, erledigt: erledigt);
    if (erledigt) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('„${aufgabe.titel}" erledigt'),
        action: SnackBarAction(
            label: 'Rückgängig', onPressed: () => notifier.abhaken(aufgabe.id, erledigt: false)),
      ));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final voelker = ref.watch(voelkerListProvider).valueOrNull ?? const [];
    String? volkName;
    for (final v in voelker) {
      if (v.id == aufgabe.volkId) {
        volkName = v.name;
        break;
      }
    }
    final erledigt = aufgabe.status == 'erledigt';
    final uebersprungen = aufgabe.status == 'uebersprungen';
    final datum = DateFormat('dd.MM.').format(aufgabe.faelligAm);
    final aktion = regelVon(aufgabe.regelKey)?.aktionRoute;

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        dense: true,
        leading: darfSchreiben && !uebersprungen
            ? Checkbox(value: erledigt, onChanged: (v) => _abhaken(context, ref, v ?? false))
            : Icon(uebersprungen ? Icons.skip_next : (erledigt ? Icons.check_circle : Icons.radio_button_unchecked),
                color: AppColors.brown300),
        title: Text(aufgabe.titel,
            style: TextStyle(
              decoration: erledigt || uebersprungen ? TextDecoration.lineThrough : null,
              color: erledigt || uebersprungen ? AppColors.brown300 : null,
              fontWeight: aufgabe.prioritaet == 'hoch' ? FontWeight.w600 : FontWeight.w400,
            )),
        subtitle: Wrap(spacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
          Text(datum,
              style: TextStyle(
                  fontSize: 12, color: ueberfaellig ? Colors.red.shade700 : AppColors.brown300)),
          Text(_kategorieLabel[aufgabe.kategorie] ?? aufgabe.kategorie,
              style: const TextStyle(fontSize: 12, color: AppColors.brown300)),
          if (volkName != null)
            InkWell(
              onTap: () => context.go('/voelker/${aufgabe.volkId}'),
              child: Text('🐝 $volkName',
                  style: const TextStyle(fontSize: 12, color: AppColors.honeyDark)),
            ),
          if (aufgabe.prioritaet == 'hoch' && !erledigt && !uebersprungen)
            const Text('PRIO', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.amber600)),
        ]),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          if (darfSchreiben && aktion != null && aufgabe.volkId != null && !erledigt && !uebersprungen)
            IconButton(
              tooltip: 'Erfassen',
              icon: const Icon(Icons.arrow_forward, size: 20),
              onPressed: () => context.go('/voelker/${aufgabe.volkId}/$aktion'),
            ),
          if (darfSchreiben && !uebersprungen)
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'edit') context.go('/aufgaben/${aufgabe.id}/bearbeiten');
                if (v == 'del') _loeschen(context, ref);
                if (v == 'reopen') _abhaken(context, ref, false);
              },
              itemBuilder: (_) => [
                if (!erledigt) const PopupMenuItem(value: 'edit', child: Text('Bearbeiten')),
                if (erledigt) const PopupMenuItem(value: 'reopen', child: Text('Wieder öffnen')),
                const PopupMenuItem(value: 'del', child: Text('Löschen')),
              ],
            ),
        ]),
      ),
    );
  }

  Future<void> _loeschen(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Aufgabe löschen?'),
        content: Text('„${aufgabe.titel}" wird endgültig gelöscht.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Abbrechen')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Löschen')),
        ],
      ),
    );
    if (ok == true) await ref.read(aufgabenListProvider.notifier).loeschen(aufgabe.id);
  }
}
```

- [ ] **Step 3: Route + Nav ergänzen**

`lib/core/router/app_router.dart` — Import `todo_page.dart` bleibt vorerst (fliegt in Task 12); NEU importieren:
```dart
import 'package:bienen_app/features/aufgaben/presentation/pages/aufgaben_page.dart';
import 'package:bienen_app/features/aufgaben/presentation/pages/aufgabe_form_page.dart';
```
Nach dem `/dashboard`-GoRoute-Block einfügen:
```dart
        GoRoute(
          path: '/aufgaben',
          builder: (context, state) => const AufgabenPage(),
          routes: [
            GoRoute(
              path: 'neu',
              builder: (c, s) => const AufgabeFormPage(),
            ),
            GoRoute(
              path: ':id/bearbeiten',
              builder: (c, s) => AufgabeFormPage(aufgabeId: s.pathParameters['id']),
            ),
          ],
        ),
```
(`AufgabeFormPage` entsteht in Task 11 — Task 10 und 11 zusammen committen ODER in Task 10 einen leeren Platzhalter vermeiden: **Task 10 wird erst NACH Task 11 kompiliert/committet, Reihenfolge unten beachten.** Der Implementer arbeitet Task 10+11 in einem Rutsch, Commit am Ende von Task 11.)

`lib/shared/widgets/app_shell.dart` — Tab „Aufgaben" an **Index 2** (nach Völker):
- `_selectedIndex`: neu
```dart
    if (location.startsWith('/voelker')) return 1;
    if (location.startsWith('/aufgaben')) return 2;
    if (location.startsWith('/monitoring')) return 3;
    if (location.startsWith('/material')) return 4;
    if (location.startsWith('/construction')) return 5;
    if (location.startsWith('/mehr') ||
        location.startsWith('/recherche') ||
        location.startsWith('/entscheidungen')) {
      return 6;
    }
    return 0;
```
- `_onDestinationSelected`: neu
```dart
      case 0: context.go('/dashboard');
      case 1: context.go('/voelker');
      case 2: context.go('/aufgaben');
      case 3: context.go('/monitoring');
      case 4: context.go('/material');
      case 5: context.go('/construction');
      case 6: context.go('/mehr');
```
- In BEIDEN Destination-Listen (NavigationRail + NavigationBar) nach „Voelker" einfügen:
```dart
                NavigationRailDestination(
                  icon: Icon(Icons.task_alt_outlined),
                  selectedIcon: Icon(Icons.task_alt),
                  label: Text('Aufgaben'),
                ),
```
bzw.
```dart
          NavigationDestination(
            icon: Icon(Icons.task_alt_outlined),
            selectedIcon: Icon(Icons.task_alt),
            label: 'Aufgaben',
          ),
```

- [ ] **Step 4: KEIN Commit — weiter zu Task 11 (FormPage), dann gemeinsam bauen + committen**

---

### Task 11: UI — AufgabeFormPage (+ Commit von Task 10+11)

**Files:**
- Create: `lib/features/aufgaben/presentation/pages/aufgabe_form_page.dart`

- [ ] **Step 1: Implementieren**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:bienen_app/features/aufgaben/domain/aufgabe.dart';
import 'package:bienen_app/features/aufgaben/presentation/providers/aufgaben_provider.dart';
import 'package:bienen_app/features/auth/presentation/auth_providers.dart';
import 'package:bienen_app/features/voelker/presentation/providers/voelker_provider.dart';

class AufgabeFormPage extends ConsumerStatefulWidget {
  final String? aufgabeId; // null = neu
  const AufgabeFormPage({super.key, this.aufgabeId});
  @override
  ConsumerState<AufgabeFormPage> createState() => _AufgabeFormPageState();
}

class _AufgabeFormPageState extends ConsumerState<AufgabeFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _titel = TextEditingController();
  final _beschreibung = TextEditingController();
  String _kategorie = 'sonstiges';
  String _prioritaet = 'normal';
  DateTime _faelligAm = DateTime.now();
  String? _volkId;
  String? _standortId;
  Aufgabe? _basis; // beim Bearbeiten
  bool _initialisiert = false;

  static const _kategorien = {
    'durchsicht': 'Durchsicht', 'behandlung': 'Behandlung', 'fuetterung': 'Fütterung',
    'schutz': 'Schutz', 'werkstatt': 'Werkstatt', 'verwaltung': 'Verwaltung', 'sonstiges': 'Sonstiges',
  };

  @override
  void dispose() {
    _titel.dispose();
    _beschreibung.dispose();
    super.dispose();
  }

  void _uebernehmen(Aufgabe a) {
    _basis = a;
    _titel.text = a.titel;
    _beschreibung.text = a.beschreibung ?? '';
    _kategorie = a.kategorie;
    _prioritaet = a.prioritaet;
    _faelligAm = a.faelligAm;
    _volkId = a.volkId;
    _standortId = a.standortId;
  }

  Future<void> _speichern() async {
    if (!_formKey.currentState!.validate()) return;
    final b = _basis;
    final a = Aufgabe(
      id: b?.id ?? '',
      titel: _titel.text.trim(),
      beschreibung: _beschreibung.text.trim().isEmpty ? null : _beschreibung.text.trim(),
      kategorie: _kategorie,
      faelligAm: _faelligAm,
      prioritaet: _prioritaet,
      status: b?.status ?? 'offen',
      volkId: _volkId,
      standortId: _standortId,
      quelle: b?.quelle ?? 'manuell',
      regelKey: b?.regelKey,
      saisonJahr: b?.saisonJahr,
    );
    try {
      await ref.read(aufgabenListProvider.notifier).speichern(a);
      if (mounted) context.go('/aufgaben');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fehler: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Rollen-Guard (Gotcha 5): viewer hat hier nichts verloren.
    if (!ref.watch(darfSchreibenProvider)) {
      return Scaffold(
        appBar: AppBar(title: const Text('Aufgabe')),
        body: const Center(child: Text('Nur mit Schreibrechten verfügbar.')),
      );
    }
    // Stammdaten laden (Gotcha 2): erst rendern, wenn Dropdown-Daten da sind.
    final voelkerAsync = ref.watch(voelkerListProvider);
    final standorteAsync = ref.watch(standorteProvider);
    final aufgabenAsync = ref.watch(aufgabenListProvider);
    if (!voelkerAsync.hasValue || !standorteAsync.hasValue || !aufgabenAsync.hasValue) {
      return Scaffold(
        appBar: AppBar(title: const Text('Aufgabe')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (widget.aufgabeId != null && !_initialisiert) {
      for (final x in aufgabenAsync.value!) {
        if (x.id == widget.aufgabeId) {
          _uebernehmen(x);
          break;
        }
      }
    }
    _initialisiert = true;

    final voelker = voelkerAsync.value!.where((v) => v.status == 'aktiv' || v.id == _volkId).toList();
    final standorte = standorteAsync.value!;

    return Scaffold(
      appBar: AppBar(title: Text(widget.aufgabeId == null ? 'Neue Aufgabe' : 'Aufgabe bearbeiten')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _titel,
              decoration: const InputDecoration(labelText: 'Titel *'),
              maxLength: 200,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Titel angeben' : null,
            ),
            TextFormField(
              controller: _beschreibung,
              decoration: const InputDecoration(labelText: 'Beschreibung'),
              maxLines: 3,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _kategorie,
              decoration: const InputDecoration(labelText: 'Kategorie'),
              items: [
                for (final e in _kategorien.entries)
                  DropdownMenuItem(value: e.key, child: Text(e.value)),
              ],
              onChanged: (v) => setState(() => _kategorie = v ?? 'sonstiges'),
            ),
            const SizedBox(height: 12),
            InputDecorator(
              decoration: const InputDecoration(labelText: 'Fällig am'),
              child: InkWell(
                onTap: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: _faelligAm,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2040),
                  );
                  if (d != null) setState(() => _faelligAm = d);
                },
                child: Text(DateFormat('dd.MM.yyyy').format(_faelligAm)),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _prioritaet,
              decoration: const InputDecoration(labelText: 'Priorität'),
              items: const [
                DropdownMenuItem(value: 'hoch', child: Text('Hoch')),
                DropdownMenuItem(value: 'normal', child: Text('Normal')),
                DropdownMenuItem(value: 'niedrig', child: Text('Niedrig')),
              ],
              onChanged: (v) => setState(() => _prioritaet = v ?? 'normal'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              initialValue: _volkId,
              decoration: const InputDecoration(labelText: 'Volk (optional)'),
              items: [
                const DropdownMenuItem<String?>(value: null, child: Text('— kein Volk —')),
                for (final v in voelker) DropdownMenuItem(value: v.id, child: Text(v.name)),
              ],
              onChanged: (v) => setState(() => _volkId = v),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              initialValue: _standortId,
              decoration: const InputDecoration(labelText: 'Standort (optional)'),
              items: [
                const DropdownMenuItem<String?>(value: null, child: Text('— kein Standort —')),
                for (final s in standorte) DropdownMenuItem(value: s.id, child: Text(s.name)),
              ],
              onChanged: (v) => setState(() => _standortId = v),
            ),
            const SizedBox(height: 24),
            FilledButton(onPressed: _speichern, child: const Text('Speichern')),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Bauen + analysieren (Task 10+11 zusammen)**

Run: `flutter analyze`
Expected: No issues found

- [ ] **Step 3: Alle Tests laufen lassen**

Run: `flutter test`
Expected: PASS (alle, inkl. Bestand)

- [ ] **Step 4: Commit (Task 10+11)**

```bash
git add lib/features/aufgaben/presentation lib/core/router/app_router.dart lib/shared/widgets/app_shell.dart
git commit -m "feat(aufgaben): Aufgaben-Tab (Vorschläge + Fälligkeits-Gruppen), Formular, Nav"
```

---

### Task 12: Andocken — Dashboard-Kachel, Volk-Section, todo_page löschen

**Files:**
- Create: `lib/features/aufgaben/presentation/widgets/aufgaben_section.dart`
- Modify: `lib/features/dashboard/pages/dashboard_page.dart` (Kachel + QuickLink)
- Modify: `lib/features/voelker/presentation/pages/volk_detail_page.dart` (Section einfügen)
- Modify: `lib/core/router/app_router.dart` (Route `/dashboard/todo` + Import entfernen)
- Delete: `lib/features/dashboard/pages/todo_page.dart`

- [ ] **Step 1: AufgabenSection (Volk-Detail) implementieren**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:bienen_app/core/theme/app_theme.dart';
import 'package:bienen_app/features/aufgaben/presentation/providers/aufgaben_provider.dart';

/// Volk-Detailseite: bis zu 5 offene Aufgaben dieses Volks.
class AufgabenSection extends ConsumerWidget {
  final String volkId;
  const AufgabenSection({super.key, required this.volkId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offene = ref.watch(aufgabenFuerVolkProvider(volkId));
    if (offene.isEmpty) return const SizedBox.shrink();
    final heute = DateTime.now();
    final h = DateTime(heute.year, heute.month, heute.day);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.task_alt, size: 20, color: AppColors.honeyDark),
              const SizedBox(width: 8),
              const Expanded(
                  child: Text('Offene Aufgaben', style: TextStyle(fontWeight: FontWeight.bold))),
              TextButton(onPressed: () => context.go('/aufgaben'), child: const Text('alle →')),
            ]),
            for (final a in offene.take(5))
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(children: [
                  Icon(Icons.radio_button_unchecked,
                      size: 16,
                      color: a.faelligAm.isBefore(h) ? Colors.red.shade700 : AppColors.brown300),
                  const SizedBox(width: 8),
                  Expanded(child: Text(a.titel, style: const TextStyle(fontSize: 13))),
                  Text(DateFormat('dd.MM.').format(a.faelligAm),
                      style: TextStyle(
                          fontSize: 12,
                          color: a.faelligAm.isBefore(h) ? Colors.red.shade700 : AppColors.brown300)),
                ]),
              ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Volk-Detailseite ergänzen**

In `volk_detail_page.dart`: Import
```dart
import 'package:bienen_app/features/aufgaben/presentation/widgets/aufgaben_section.dart';
```
und nach `StandortSection(volk: volk),` (Zeile ~66) einfügen:
```dart
              AufgabenSection(volkId: volk.id),
```

- [ ] **Step 3: Dashboard-Kachel + QuickLink**

`dashboard_page.dart`:
- Klasse auf `ConsumerWidget` umstellen (Import `flutter_riverpod` + `aufgaben_provider.dart`), `build(BuildContext context, WidgetRef ref)`.
- Oben im Haupt-Column (vor „Projektfortschritt") eine Kachel einfügen:
```dart
            _buildAufgabenKachel(context, ref),
            const SizedBox(height: 24),
```
```dart
  Widget _buildAufgabenKachel(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(offeneAufgabenStatsProvider);
    return Card(
      child: InkWell(
        onTap: () => context.go('/aufgaben'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(children: [
            Icon(Icons.task_alt,
                size: 32,
                color: stats.ueberfaellig > 0 ? Colors.red.shade700 : AppColors.honey),
            const SizedBox(width: 16),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Aufgaben', style: TextStyle(fontWeight: FontWeight.bold)),
                Text(
                  stats.ueberfaellig > 0
                      ? '${stats.offen} offen · ${stats.ueberfaellig} überfällig'
                      : '${stats.offen} offen',
                  style: TextStyle(
                      fontSize: 13,
                      color: stats.ueberfaellig > 0 ? Colors.red.shade700 : AppColors.brown300),
                ),
              ]),
            ),
            const Icon(Icons.chevron_right, color: AppColors.brown300),
          ]),
        ),
      ),
    );
  }
```
- QuickLink ersetzen: `_QuickLink('Aufgaben', Icons.task_alt, '/dashboard/todo', 'Projekt-Aufgaben & Phasenplan')` → `_QuickLink('Aufgaben', Icons.task_alt, '/aufgaben', 'Saisonaufgaben & Planung')`.

- [ ] **Step 4: todo_page entfernen**

- In `app_router.dart`: Import `todo_page.dart` löschen + den `GoRoute(path: 'todo', …)`-Block unter `/dashboard` entfernen.
- Datei `lib/features/dashboard/pages/todo_page.dart` löschen.

- [ ] **Step 5: Analyse + Tests**

Run: `flutter analyze && flutter test`
Expected: No issues · alle Tests PASS

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "feat(aufgaben): Dashboard-Kachel + Volk-Section; statische Projekt-Todo-Seite entfernt"
```

---

### Task 13: Abschluss — Version, Merge, Deploy

- [ ] **Step 1: Version bumpen**

In `pubspec.yaml`: `version: 1.14.0+32`

- [ ] **Step 2: Voll-Check**

Run: `flutter analyze && flutter test`
Expected: No issues · alle Tests PASS

- [ ] **Step 3: Committen + auf master mergen + pushen**

```bash
git add pubspec.yaml
git commit -m "chore: Version 1.14.0+32 (Modul 4.4 Aufgaben & Kalender)"
git checkout master
git merge --no-ff feat/aufgaben -m "feat: Modul 4.4 Aufgaben & Kalender (v1.14.0)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
git push origin master
```

- [ ] **Step 4: Deployen (stehende Freigabe nach grünen Tests)**

Run: `bash deploy.sh`
Expected: Build ok, gh-pages-Push ok, „✓ Live bestaetigt" (Version 1.14.0).

- [ ] **Step 5: Live-Smoke**

`curl -s https://danielproyer.github.io/bienen-app/version.json` → `"version":"1.14.0"`.
