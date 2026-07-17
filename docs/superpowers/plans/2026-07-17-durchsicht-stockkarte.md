# Durchsicht/Stockkarte (Modul 4.3) — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Digitale Stockkarte je Volk: strukturierte, datierte Durchsichts-Einträge (fünf Kernfragen W-B-F-P-G) mit Foto, als Timeline in der Volk-Detailseite (4.2).

**Architecture:** Eine additive Migration `D01` (Tabelle `inspections` + View `v_letzte_durchsichten`), eine `D02` (privater Storage-Bucket `inspection-photos` + Policies). Flutter-Feature `lib/features/durchsicht/` nach dem 4.2-Muster (Gateway-Interface + Supabase-/Fake-Impl, Riverpod `AsyncNotifier`), plus ein gemeinsamer `FotoSpeicher`-Helfer (`lib/core/storage/`) und zwei kleine Andock-Eingriffe in 4.2 (Detailseite „Verlauf" → Timeline, `VolkCard` → „zuletzt gesehen"). Record-only; Fotos privat mit Signed-URL + aktivem Lösch-Lifecycle.

**Tech Stack:** Supabase/Postgres 17.6 (MCP `apply_migration`/`execute_sql`/`get_advisors`), Flutter Web, flutter_riverpod ^2.6.1, go_router ^14.8.1, supabase_flutter ^2.8.3, image_picker (vorhanden), flutter_test.

**Spec:** [2026-07-17-durchsicht-stockkarte-design.md](../specs/2026-07-17-durchsicht-stockkarte-design.md)
**Supabase project_id:** `dcdcohktxbhdxnxjvcyp` · **Branch:** `feat/durchsicht`

---

## Referenz-Muster (Bestand — einhalten)
- **RLS-Helper:** `private.meine_betrieb_ids()`, `private.kann_schreiben(uuid)`, `private.aktive_betrieb_id()`, **`private.ist_mitglied(uuid)`** (für Storage-SELECT), `private.current_app_user()`.
- **Trigger:** `private.set_row_actor()`, `private.set_updated_at()`.
- **Storage-Muster:** Upload `SupabaseConfig.client.storage.from(bucket).uploadBinary(path, bytes, fileOptions: FileOptions(upsert:true, contentType:'image/jpeg'))`; privat lesen `createSignedUrl(path, sekunden)`; löschen `remove([path])`. Policy-Muster A10 (Write, `kann_schreiben`) + B02 (SELECT, `ist_mitglied`), beide mit `<betrieb_id>/`-Pfad + UUID-Regex-Guard.
- **Provider:** `AsyncNotifierProvider`(.family), `ref.invalidateSelf()`, keine stillen `catch`→`[]`. Muster: `lib/features/voelker/presentation/providers/voelker_provider.dart`.

## File Structure
**Migrationen** (`supabase/migrations/`): `D01_inspections.sql`, `D02_storage_inspection_photos.sql`
**Core** (`lib/core/storage/`): `foto_speicher.dart`
**Domain** (`lib/features/durchsicht/domain/`): `durchsicht.dart`, `bienen_schaetzung.dart`, `durchsicht_gateway.dart`
**Data** (`lib/features/durchsicht/data/`): `supabase_durchsicht_gateway.dart`, `fake_durchsicht_gateway.dart`
**Presentation** (`lib/features/durchsicht/presentation/`): `providers/durchsicht_provider.dart`, `pages/durchsicht_form_page.dart`, `pages/durchsicht_detail_page.dart`, `widgets/durchsicht_timeline.dart`, `widgets/durchsicht_karte.dart`
**Fremdeingriffe:** `lib/features/auth/presentation/auth_providers.dart` (`_datenNeuLaden`), `lib/features/voelker/presentation/pages/volk_detail_page.dart` („Verlauf"→Timeline), `lib/features/voelker/presentation/widgets/volk_card.dart` („zuletzt gesehen"), `lib/core/router/app_router.dart` (Routen).
**Tests** (`test/features/durchsicht/`): `bienen_schaetzung_test.dart`, `durchsicht_model_test.dart`, `fake_durchsicht_gateway_test.dart`, `durchsicht_provider_reset_test.dart`.

---

# Phase 1 — Datenbank (D01, D02)

> Je Migration: Datei schreiben → MCP `apply_migration(project_id,name,query)` → Rollback-DO-Verifikation via `execute_sql` → commit.

### Task 1: D01 — `inspections` + View

**Files:** Create `supabase/migrations/D01_inspections.sql`

- [ ] **Step 1: Datei schreiben**

```sql
-- D01_inspections.sql | Durchsicht/Stockkarte je Volk. Same-Tenant-Komposit-FK auf voelker
-- (ON DELETE CASCADE; voelker wird normal per Status aufgeloest, nicht hart geloescht).
-- View v_letzte_durchsichten (security_invoker) fuer die Voelkerliste (PostgREST kann kein distinct on).

create table if not exists public.inspections (
  id uuid primary key default gen_random_uuid(),
  volk_id uuid not null,
  durchgefuehrt_am date not null default current_date,
  wetter text,
  temperatur_c numeric,
  dauer_min int check (dauer_min is null or dauer_min >= 0),
  weiselzustand text check (weiselzustand in ('weiselrichtig','weisellos','drohnenbruetig','unsicher')),
  koenigin_gesehen boolean not null default false,
  stifte_gesehen boolean not null default false,
  weiselzellen text check (weiselzellen in ('keine','spielnaepfchen','schwarmzellen','nachschaffungszellen')),
  weiselzellen_anzahl int check (weiselzellen_anzahl is null or weiselzellen_anzahl >= 0),
  brutbild text check (brutbild in ('geschlossen','lueckig','bunt','kaum','kein')),
  brut_waben numeric check (brut_waben is null or brut_waben >= 0),
  staerke_wabengassen numeric check (staerke_wabengassen is null or staerke_wabengassen >= 0),
  futter_kg numeric check (futter_kg is null or futter_kg >= 0),
  pollen text check (pollen in ('viel','mittel','wenig','kein')),
  platz text check (platz in ('ok','eng','honigraum_noetig','zu_gross')),
  sanftmut int check (sanftmut is null or sanftmut between 1 and 4),
  wabensitz int check (wabensitz is null or wabensitz between 1 and 4),
  auffaelligkeiten text[] not null default '{}'
    check (auffaelligkeiten <@ array['kalkbrut','sackbrut','faulbrut_verdacht','sauerbrut_verdacht',
                                     'ruhr','raeuberei','wachsmotte','varroa_sichtbar','kahlflug']::text[]),
  massnahmen text,
  naechste_durchsicht_am date,
  foto_urls text[] not null default '{}',
  notiz text,
  betrieb_id uuid not null default private.aktive_betrieb_id()
    references public.betriebe(id) on delete cascade,
  created_by uuid, updated_by uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (betrieb_id, id),
  constraint inspections_volk_fk
    foreign key (betrieb_id, volk_id) references public.voelker (betrieb_id, id) on delete cascade
);

alter table public.inspections enable row level security;
revoke all on public.inspections from anon, public;
grant select, insert, update, delete on public.inspections to authenticated;
create index if not exists idx_inspections_volk_datum
  on public.inspections (betrieb_id, volk_id, durchgefuehrt_am desc);

drop trigger if exists trg_inspections_actor on public.inspections;
create trigger trg_inspections_actor before insert or update
  on public.inspections for each row execute function private.set_row_actor();
drop trigger if exists trg_inspections_updated on public.inspections;
create trigger trg_inspections_updated before update
  on public.inspections for each row execute function private.set_updated_at();

drop policy if exists inspections_sel_member on public.inspections;
create policy inspections_sel_member on public.inspections
  for select to authenticated using (betrieb_id in (select private.meine_betrieb_ids()));
drop policy if exists inspections_ins_writer on public.inspections;
create policy inspections_ins_writer on public.inspections
  for insert to authenticated with check (private.kann_schreiben(betrieb_id));
drop policy if exists inspections_upd_writer on public.inspections;
create policy inspections_upd_writer on public.inspections
  for update to authenticated using (private.kann_schreiben(betrieb_id))
  with check (private.kann_schreiben(betrieb_id));
drop policy if exists inspections_del_writer on public.inspections;
create policy inspections_del_writer on public.inspections
  for delete to authenticated using (private.kann_schreiben(betrieb_id));

-- letzte Durchsicht je Volk (RLS der Basistabelle gilt via security_invoker)
drop view if exists public.v_letzte_durchsichten;
create view public.v_letzte_durchsichten with (security_invoker = true) as
  select distinct on (volk_id) *
  from public.inspections
  order by volk_id, durchgefuehrt_am desc, created_at desc;
```

- [ ] **Step 2: Anwenden** — `apply_migration` name `D01_inspections`. Erwartung: success.
- [ ] **Step 3: Rollback-DO-Verifikation** — `execute_sql`:

```sql
do $$
declare v_b uuid; v_v uuid; v_cnt int;
begin
  select id into v_b from public.betriebe limit 1;
  insert into public.voelker (betrieb_id, name) values (v_b, 'T-DV') returning id into v_v;
  -- (a) CHECK: unbekanntes auffaelligkeiten-Flag -> Fehler
  begin
    insert into public.inspections (betrieb_id, volk_id, auffaelligkeiten)
      values (v_b, v_v, array['quatsch']);
    raise exception 'FAIL: auffaelligkeiten-CHECK haette greifen muessen';
  exception when check_violation then null;
  end;
  -- (b) CHECK: sanftmut ausserhalb 1-4
  begin
    insert into public.inspections (betrieb_id, volk_id, sanftmut) values (v_b, v_v, 9);
    raise exception 'FAIL: sanftmut-CHECK haette greifen muessen';
  exception when check_violation then null;
  end;
  -- (c) gueltige Durchsicht + View
  insert into public.inspections (betrieb_id, volk_id, durchgefuehrt_am, weiselzustand, auffaelligkeiten)
    values (v_b, v_v, '2026-05-01', 'weiselrichtig', array['kalkbrut','varroa_sichtbar']);
  insert into public.inspections (betrieb_id, volk_id, durchgefuehrt_am, weiselzustand)
    values (v_b, v_v, '2026-06-01', 'weisellos');
  select count(*) into v_cnt from public.v_letzte_durchsichten where volk_id = v_v;
  if v_cnt <> 1 then raise exception 'FAIL: View liefert % Zeilen statt 1', v_cnt; end if;
  if (select durchgefuehrt_am from public.v_letzte_durchsichten where volk_id=v_v) <> '2026-06-01' then
    raise exception 'FAIL: View liefert nicht die neueste';
  end if;
  -- (d) ON DELETE CASCADE: Volk hart loeschen -> Durchsichten weg
  delete from public.voelker where id = v_v;
  if (select count(*) from public.inspections where volk_id = v_v) <> 0 then
    raise exception 'FAIL: CASCADE hat Durchsichten nicht geloescht';
  end if;
  raise notice 'OK D01: CHECKs + View + CASCADE';
  raise exception 'ROLLBACK_TESTDATEN';
exception when others then
  if sqlerrm <> 'ROLLBACK_TESTDATEN' then raise; end if;
end $$;
```
Erwartung: `NOTICE OK D01 …`, keine persistierten Testdaten.

- [ ] **Step 4: Commit** — `git add supabase/migrations/D01_inspections.sql && git commit -m "feat(db): D01 inspections + v_letzte_durchsichten"`

### Task 2: D02 — privater Storage-Bucket `inspection-photos`

**Files:** Create `supabase/migrations/D02_storage_inspection_photos.sql`

- [ ] **Step 1: Datei schreiben**

```sql
-- D02_storage_inspection_photos.sql | PRIVATER Bucket (Brutbild/Krankheitsfotos = Gesundheitsdaten).
-- SELECT nur Mitglied (B02-Muster private.ist_mitglied); Write nur kann_schreiben (A10-Muster).
-- Anzeige via createSignedUrl; foto_urls speichert PFADE.

insert into storage.buckets (id, name, public)
  values ('inspection-photos', 'inspection-photos', false)
  on conflict (id) do nothing;

drop policy if exists auth_sel_inspection_photos on storage.objects;
create policy auth_sel_inspection_photos on storage.objects for select to authenticated
  using (bucket_id = 'inspection-photos'
    and (storage.foldername(name))[1] ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
    and private.ist_mitglied(((storage.foldername(name))[1])::uuid));

drop policy if exists auth_ins_inspection_photos on storage.objects;
create policy auth_ins_inspection_photos on storage.objects for insert to authenticated
  with check (bucket_id = 'inspection-photos'
    and (storage.foldername(name))[1] ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
    and private.kann_schreiben(((storage.foldername(name))[1])::uuid));

drop policy if exists auth_upd_inspection_photos on storage.objects;
create policy auth_upd_inspection_photos on storage.objects for update to authenticated
  using (bucket_id = 'inspection-photos'
    and (storage.foldername(name))[1] ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
    and private.kann_schreiben(((storage.foldername(name))[1])::uuid))
  with check (bucket_id = 'inspection-photos'
    and (storage.foldername(name))[1] ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
    and private.kann_schreiben(((storage.foldername(name))[1])::uuid));

drop policy if exists auth_del_inspection_photos on storage.objects;
create policy auth_del_inspection_photos on storage.objects for delete to authenticated
  using (bucket_id = 'inspection-photos'
    and (storage.foldername(name))[1] ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
    and private.kann_schreiben(((storage.foldername(name))[1])::uuid));
```

- [ ] **Step 2: Anwenden** — `apply_migration` name `D02_storage_inspection_photos`.
- [ ] **Step 3: Verifikation** — `execute_sql`:

```sql
select
  (select public from storage.buckets where id='inspection-photos') as ist_privat_false,
  (select count(*) from pg_policies where schemaname='storage' and tablename='objects'
     and policyname like '%inspection_photos') as anzahl_policies;
```
Erwartung: `ist_privat_false = false`, `anzahl_policies = 4`.

- [ ] **Step 4: Commit** — `git commit -m "feat(db): D02 privater Bucket inspection-photos + Policies"`

### Task 3: Advisor-Gate

- [ ] **Step 1:** `get_advisors(project_id='dcdcohktxbhdxnxjvcyp', type='security')`.
- [ ] **Step 2:** Erwartung: **keine neuen** Findings gegenüber dem 4.2-Stand (kein neuer SECURITY-DEFINER-RPC; die View ist `security_invoker` → keine 0029-Zeile; `inspections` hat RLS+Policies; FK ist durch `idx_inspections_volk_datum` gedeckt → kein `unindexed_foreign_keys`). Bekannt bleiben nur die 6 Auth/4.2-RPC-0029 + Leaked-Password. Jedes neue Finding vor dem Weiterbau beheben.
- [ ] **Step 3:** kein Commit (Prüfung).

---

# Phase 2 — Core & Domain

### Task 4: Foto-Speicher-Helfer (gemeinsam)

**Files:** Create `lib/core/storage/foto_speicher.dart`

- [ ] **Step 1: Implementieren**

```dart
import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Duenner Storage-Helfer fuer PRIVATE Buckets: laedt hoch (gibt den PFAD zurueck,
/// nicht die URL), erzeugt Signed-URLs, entfernt Objekte. Pfadkonvention:
/// '<betrieb_id>/<gruppe>/foto_<ts>.jpg' (mandanten-scoped fuer die Storage-Policies).
class FotoSpeicher {
  final SupabaseClient _c;
  final String bucket;
  const FotoSpeicher(this._c, this.bucket);

  Future<String> hochladen({
    required String betriebId,
    required String gruppeId,
    required Uint8List bytes,
  }) async {
    final pfad = '$betriebId/$gruppeId/foto_${DateTime.now().microsecondsSinceEpoch}.jpg';
    await _c.storage.from(bucket).uploadBinary(
          pfad,
          bytes,
          fileOptions: const FileOptions(upsert: true, contentType: 'image/jpeg'),
        );
    return pfad;
  }

  Future<String> signedUrl(String pfad, {int ablaufSekunden = 3600}) =>
      _c.storage.from(bucket).createSignedUrl(pfad, ablaufSekunden);

  Future<void> entfernen(List<String> pfade) async {
    if (pfade.isEmpty) return;
    await _c.storage.from(bucket).remove(pfade);
  }
}
```

- [ ] **Step 2: analyze** — `flutter analyze lib/core/storage/foto_speicher.dart` → sauber.
- [ ] **Step 3: Commit** — `git commit -m "feat(core): FotoSpeicher-Helfer (privater Bucket, Signed-URL, Pfade)"`

### Task 5: `bienenSchaetzung` (reine Funktion, TDD)

**Files:** Create `lib/features/durchsicht/domain/bienen_schaetzung.dart`, Test `test/features/durchsicht/bienen_schaetzung_test.dart`

- [ ] **Step 1: Failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:bienen_app/features/durchsicht/domain/bienen_schaetzung.dart';

void main() {
  test('~1000 Bienen je besetzter Wabengasse (Dadant-Richtwert)', () {
    expect(bienenSchaetzung(0), 0);
    expect(bienenSchaetzung(1), 1000);
    expect(bienenSchaetzung(8.5), 8500);
    expect(bienenSchaetzung(null), isNull);
  });
}
```

- [ ] **Step 2: Test → FAIL.** `flutter test test/features/durchsicht/bienen_schaetzung_test.dart`
- [ ] **Step 3: Implementieren**

```dart
/// Grobe Bienenzahl-Schaetzung aus besetzten Wabengassen (~1000/Gasse, Dadant;
/// Recherche 11). Nur Anzeige, nicht gespeichert.
int? bienenSchaetzung(num? wabengassen) =>
    wabengassen == null ? null : (wabengassen * 1000).round();
```

- [ ] **Step 4: Test → PASS.**
- [ ] **Step 5: Commit** — `git commit -m "feat(durchsicht): bienenSchaetzung"`

### Task 6: Domain-Modell `Durchsicht` + Whitelist (TDD)

**Files:** Create `lib/features/durchsicht/domain/durchsicht.dart`, Test `test/features/durchsicht/durchsicht_model_test.dart`

- [ ] **Step 1: Failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:bienen_app/features/durchsicht/domain/durchsicht.dart';

void main() {
  test('fromJson/toInsertJson Roundtrip inkl. text[]', () {
    final j = {
      'id': 'd1', 'volk_id': 'v1', 'durchgefuehrt_am': '2026-05-01',
      'weiselzustand': 'weiselrichtig', 'koenigin_gesehen': true, 'stifte_gesehen': true,
      'auffaelligkeiten': ['kalkbrut', 'varroa_sichtbar'], 'foto_urls': ['b/v1/foto_1.jpg'],
      'sanftmut': 3,
    };
    final d = Durchsicht.fromJson(j);
    expect(d.weiselzustand, 'weiselrichtig');
    expect(d.auffaelligkeiten, ['kalkbrut', 'varroa_sichtbar']);
    expect(d.fotoUrls, ['b/v1/foto_1.jpg']);
    final ins = d.toInsertJson();
    expect(ins['auffaelligkeiten'], ['kalkbrut', 'varroa_sichtbar']);
    expect(ins.containsKey('id'), isFalse); // id nie im Insert
  });

  test('unbekanntes Auffaelligkeits-Flag wird verworfen', () {
    expect(Durchsicht.gueltigeFlags(['kalkbrut', 'quatsch', 'ruhr']), ['kalkbrut', 'ruhr']);
  });
}
```

- [ ] **Step 2: Test → FAIL.**
- [ ] **Step 3: Implementieren**

```dart
class Durchsicht {
  static const auffaelligkeitenWhitelist = <String>{
    'kalkbrut', 'sackbrut', 'faulbrut_verdacht', 'sauerbrut_verdacht',
    'ruhr', 'raeuberei', 'wachsmotte', 'varroa_sichtbar', 'kahlflug',
  };

  final String id;
  final String volkId;
  final DateTime durchgefuehrtAm;
  final String? wetter;
  final num? temperaturC;
  final int? dauerMin;
  final String? weiselzustand;
  final bool koeniginGesehen;
  final bool stifteGesehen;
  final String? weiselzellen;
  final int? weiselzellenAnzahl;
  final String? brutbild;
  final num? brutWaben;
  final num? staerkeWabengassen;
  final num? futterKg;
  final String? pollen;
  final String? platz;
  final int? sanftmut;
  final int? wabensitz;
  final List<String> auffaelligkeiten;
  final String? massnahmen;
  final DateTime? naechsteDurchsichtAm;
  final List<String> fotoUrls; // Storage-PFADE
  final String? notiz;

  const Durchsicht({
    required this.id,
    required this.volkId,
    required this.durchgefuehrtAm,
    this.wetter,
    this.temperaturC,
    this.dauerMin,
    this.weiselzustand,
    this.koeniginGesehen = false,
    this.stifteGesehen = false,
    this.weiselzellen,
    this.weiselzellenAnzahl,
    this.brutbild,
    this.brutWaben,
    this.staerkeWabengassen,
    this.futterKg,
    this.pollen,
    this.platz,
    this.sanftmut,
    this.wabensitz,
    this.auffaelligkeiten = const [],
    this.massnahmen,
    this.naechsteDurchsichtAm,
    this.fotoUrls = const [],
    this.notiz,
  });

  static List<String> gueltigeFlags(List<String> flags) =>
      flags.where(auffaelligkeitenWhitelist.contains).toList();

  static DateTime _d(Object? v) => DateTime.parse(v as String);

  factory Durchsicht.fromJson(Map<String, dynamic> j) => Durchsicht(
        id: j['id'] as String,
        volkId: j['volk_id'] as String,
        durchgefuehrtAm: _d(j['durchgefuehrt_am']),
        wetter: j['wetter'] as String?,
        temperaturC: j['temperatur_c'] as num?,
        dauerMin: j['dauer_min'] as int?,
        weiselzustand: j['weiselzustand'] as String?,
        koeniginGesehen: (j['koenigin_gesehen'] as bool?) ?? false,
        stifteGesehen: (j['stifte_gesehen'] as bool?) ?? false,
        weiselzellen: j['weiselzellen'] as String?,
        weiselzellenAnzahl: j['weiselzellen_anzahl'] as int?,
        brutbild: j['brutbild'] as String?,
        brutWaben: j['brut_waben'] as num?,
        staerkeWabengassen: j['staerke_wabengassen'] as num?,
        futterKg: j['futter_kg'] as num?,
        pollen: j['pollen'] as String?,
        platz: j['platz'] as String?,
        sanftmut: j['sanftmut'] as int?,
        wabensitz: j['wabensitz'] as int?,
        auffaelligkeiten:
            ((j['auffaelligkeiten'] as List?)?.cast<String>() ?? const []),
        massnahmen: j['massnahmen'] as String?,
        naechsteDurchsichtAm: j['naechste_durchsicht_am'] != null
            ? _d(j['naechste_durchsicht_am'])
            : null,
        fotoUrls: ((j['foto_urls'] as List?)?.cast<String>() ?? const []),
        notiz: j['notiz'] as String?,
      );

  String _iso(DateTime d) => d.toIso8601String().substring(0, 10);

  Map<String, dynamic> toInsertJson() => {
        'volk_id': volkId,
        'durchgefuehrt_am': _iso(durchgefuehrtAm),
        'wetter': wetter,
        'temperatur_c': temperaturC,
        'dauer_min': dauerMin,
        'weiselzustand': weiselzustand,
        'koenigin_gesehen': koeniginGesehen,
        'stifte_gesehen': stifteGesehen,
        'weiselzellen': weiselzellen,
        'weiselzellen_anzahl': weiselzellenAnzahl,
        'brutbild': brutbild,
        'brut_waben': brutWaben,
        'staerke_wabengassen': staerkeWabengassen,
        'futter_kg': futterKg,
        'pollen': pollen,
        'platz': platz,
        'sanftmut': sanftmut,
        'wabensitz': wabensitz,
        'auffaelligkeiten': gueltigeFlags(auffaelligkeiten),
        'massnahmen': massnahmen,
        'naechste_durchsicht_am':
            naechsteDurchsichtAm != null ? _iso(naechsteDurchsichtAm!) : null,
        'foto_urls': fotoUrls,
        'notiz': notiz,
      };
}
```

- [ ] **Step 4: Test → PASS.** `flutter test test/features/durchsicht/durchsicht_model_test.dart`
- [ ] **Step 5: Commit** — `git commit -m "feat(durchsicht): Durchsicht-Modell + Auffaelligkeiten-Whitelist"`

### Task 7: Gateway-Interface

**Files:** Create `lib/features/durchsicht/domain/durchsicht_gateway.dart`

- [ ] **Step 1: Implementieren**

```dart
import 'dart:typed_data';
import 'package:bienen_app/features/durchsicht/domain/durchsicht.dart';

class DurchsichtFehler implements Exception {
  final String code;
  final String message;
  const DurchsichtFehler(this.code, this.message);
  @override
  String toString() => message;
}

abstract class DurchsichtGateway {
  Future<List<Durchsicht>> fuerVolk(String volkId);          // absteigend nach Datum
  Future<List<Durchsicht>> letzteJeVolk();                   // aus v_letzte_durchsichten
  Future<void> speichern(Durchsicht d);                      // insert wenn id leer, sonst update
  Future<void> loeschen(Durchsicht d);                       // entfernt auch die Fotos
  Future<String> fotoHochladen({required String betriebId, required String gruppeId, required Uint8List bytes}); // -> Pfad
  Future<String> fotoSignedUrl(String pfad);
  Future<void> fotoEntfernen(List<String> pfade);
}
```

- [ ] **Step 2: Commit** — `git commit -m "feat(durchsicht): DurchsichtGateway-Interface"`

### Task 8: FakeDurchsichtGateway + Tests (TDD)

**Files:** Create `lib/features/durchsicht/data/fake_durchsicht_gateway.dart`, Test `test/features/durchsicht/fake_durchsicht_gateway_test.dart`

- [ ] **Step 1: Failing test**

```dart
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:bienen_app/features/durchsicht/data/fake_durchsicht_gateway.dart';
import 'package:bienen_app/features/durchsicht/domain/durchsicht.dart';

Durchsicht _d(String id, String volk, String datum) =>
    Durchsicht(id: id, volkId: volk, durchgefuehrtAm: DateTime.parse(datum));

void main() {
  test('fuerVolk absteigend nach Datum', () async {
    final gw = FakeDurchsichtGateway();
    await gw.speichern(_d('', 'v1', '2026-05-01'));
    await gw.speichern(_d('', 'v1', '2026-06-01'));
    await gw.speichern(_d('', 'v2', '2026-05-15'));
    final list = await gw.fuerVolk('v1');
    expect(list.length, 2);
    expect(list.first.durchgefuehrtAm, DateTime.parse('2026-06-01'));
  });

  test('letzteJeVolk = neueste je Volk', () async {
    final gw = FakeDurchsichtGateway();
    await gw.speichern(_d('', 'v1', '2026-05-01'));
    await gw.speichern(_d('', 'v1', '2026-06-01'));
    await gw.speichern(_d('', 'v2', '2026-05-15'));
    final letzte = await gw.letzteJeVolk();
    expect(letzte.length, 2);
    expect(letzte.firstWhere((d) => d.volkId == 'v1').durchgefuehrtAm,
        DateTime.parse('2026-06-01'));
  });

  test('loeschen entfernt Zeile + Fotos', () async {
    final gw = FakeDurchsichtGateway();
    await gw.speichern(Durchsicht(
        id: 'd1', volkId: 'v1', durchgefuehrtAm: DateTime.parse('2026-05-01'),
        fotoUrls: const ['b/v1/foto_1.jpg']));
    final d = (await gw.fuerVolk('v1')).first;
    await gw.loeschen(d);
    expect(await gw.fuerVolk('v1'), isEmpty);
    expect(gw.entfernteFotos, ['b/v1/foto_1.jpg']);
  });
}
```

- [ ] **Step 2: Test → FAIL.**
- [ ] **Step 3: Implementieren**

```dart
import 'dart:typed_data';
import 'package:bienen_app/features/durchsicht/domain/durchsicht.dart';
import 'package:bienen_app/features/durchsicht/domain/durchsicht_gateway.dart';

class FakeDurchsichtGateway implements DurchsichtGateway {
  final _map = <String, Durchsicht>{};
  final entfernteFotos = <String>[];
  int _seq = 0;

  List<Durchsicht> get _alle =>
      _map.values.toList()..sort((a, b) => b.durchgefuehrtAm.compareTo(a.durchgefuehrtAm));

  @override
  Future<List<Durchsicht>> fuerVolk(String volkId) async =>
      _alle.where((d) => d.volkId == volkId).toList();

  @override
  Future<List<Durchsicht>> letzteJeVolk() async {
    final byVolk = <String, Durchsicht>{};
    for (final d in _alle) {
      byVolk.putIfAbsent(d.volkId, () => d); // _alle ist absteigend -> erstes = neuestes
    }
    return byVolk.values.toList();
  }

  @override
  Future<void> speichern(Durchsicht d) async {
    final id = d.id.isEmpty ? 'd${++_seq}' : d.id;
    _map[id] = Durchsicht(
      id: id, volkId: d.volkId, durchgefuehrtAm: d.durchgefuehrtAm, wetter: d.wetter,
      temperaturC: d.temperaturC, dauerMin: d.dauerMin, weiselzustand: d.weiselzustand,
      koeniginGesehen: d.koeniginGesehen, stifteGesehen: d.stifteGesehen,
      weiselzellen: d.weiselzellen, weiselzellenAnzahl: d.weiselzellenAnzahl,
      brutbild: d.brutbild, brutWaben: d.brutWaben, staerkeWabengassen: d.staerkeWabengassen,
      futterKg: d.futterKg, pollen: d.pollen, platz: d.platz, sanftmut: d.sanftmut,
      wabensitz: d.wabensitz, auffaelligkeiten: Durchsicht.gueltigeFlags(d.auffaelligkeiten),
      massnahmen: d.massnahmen, naechsteDurchsichtAm: d.naechsteDurchsichtAm,
      fotoUrls: d.fotoUrls, notiz: d.notiz,
    );
  }

  @override
  Future<void> loeschen(Durchsicht d) async {
    entfernteFotos.addAll(d.fotoUrls);
    _map.remove(d.id);
  }

  @override
  Future<String> fotoHochladen({required String betriebId, required String gruppeId, required Uint8List bytes}) async =>
      '$betriebId/$gruppeId/foto_${++_seq}.jpg';

  @override
  Future<String> fotoSignedUrl(String pfad) async => 'https://signed.test/$pfad';

  @override
  Future<void> fotoEntfernen(List<String> pfade) async => entfernteFotos.addAll(pfade);
}
```

- [ ] **Step 4: Test → PASS.**
- [ ] **Step 5: Commit** — `git commit -m "feat(durchsicht): FakeDurchsichtGateway + Tests"`

### Task 9: SupabaseDurchsichtGateway

**Files:** Create `lib/features/durchsicht/data/supabase_durchsicht_gateway.dart`

- [ ] **Step 1: Implementieren**

```dart
import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:bienen_app/core/storage/foto_speicher.dart';
import 'package:bienen_app/features/durchsicht/domain/durchsicht.dart';
import 'package:bienen_app/features/durchsicht/domain/durchsicht_gateway.dart';

class SupabaseDurchsichtGateway implements DurchsichtGateway {
  final SupabaseClient _c;
  late final FotoSpeicher _fotos = FotoSpeicher(_c, 'inspection-photos');
  SupabaseDurchsichtGateway(this._c);

  Never _rethrow(Object e) {
    if (e is PostgrestException && e.code != null) {
      throw DurchsichtFehler(e.code!, e.message);
    }
    throw e;
  }

  @override
  Future<List<Durchsicht>> fuerVolk(String volkId) async {
    try {
      final res = await _c
          .from('inspections')
          .select()
          .eq('volk_id', volkId)
          .order('durchgefuehrt_am', ascending: false);
      return (res as List).map((j) => Durchsicht.fromJson(j as Map<String, dynamic>)).toList();
    } catch (e) {
      _rethrow(e);
    }
  }

  @override
  Future<List<Durchsicht>> letzteJeVolk() async {
    final res = await _c.from('v_letzte_durchsichten').select();
    return (res as List).map((j) => Durchsicht.fromJson(j as Map<String, dynamic>)).toList();
  }

  @override
  Future<void> speichern(Durchsicht d) async {
    try {
      final json = d.toInsertJson();
      if (d.id.isEmpty) {
        await _c.from('inspections').insert(json);
      } else {
        await _c.from('inspections').update(json).eq('id', d.id);
      }
    } catch (e) {
      _rethrow(e);
    }
  }

  @override
  Future<void> loeschen(Durchsicht d) async {
    // Loeschpflicht: erst Storage-Objekte, dann die Zeile.
    await fotoEntfernen(d.fotoUrls);
    await _c.from('inspections').delete().eq('id', d.id);
  }

  @override
  Future<String> fotoHochladen({required String betriebId, required String gruppeId, required Uint8List bytes}) =>
      _fotos.hochladen(betriebId: betriebId, gruppeId: gruppeId, bytes: bytes);

  @override
  Future<String> fotoSignedUrl(String pfad) => _fotos.signedUrl(pfad);

  @override
  Future<void> fotoEntfernen(List<String> pfade) async {
    try {
      await _fotos.entfernen(pfade);
    } catch (_) {
      // best-effort: Foto-Reste blockieren das Loeschen der Durchsicht nicht.
    }
  }
}
```

- [ ] **Step 2: analyze** → sauber.
- [ ] **Step 3: Commit** — `git commit -m "feat(durchsicht): SupabaseDurchsichtGateway (View, Signed-URL, Foto-Lifecycle)"`

---

# Phase 3 — State & Andocken

### Task 10: Provider + Auth-Invalidierung (TDD)

**Files:** Create `lib/features/durchsicht/presentation/providers/durchsicht_provider.dart`; Modify `lib/features/auth/presentation/auth_providers.dart`; Test `test/features/durchsicht/durchsicht_provider_reset_test.dart`

- [ ] **Step 1: Provider implementieren**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bienen_app/core/supabase/supabase_config.dart';
import 'package:bienen_app/features/durchsicht/data/supabase_durchsicht_gateway.dart';
import 'package:bienen_app/features/durchsicht/domain/durchsicht.dart';
import 'package:bienen_app/features/durchsicht/domain/durchsicht_gateway.dart';

final durchsichtGatewayProvider =
    Provider<DurchsichtGateway>((ref) => SupabaseDurchsichtGateway(SupabaseConfig.client));

final durchsichtenFuerVolkProvider =
    AsyncNotifierProvider.family<DurchsichtenNotifier, List<Durchsicht>, String>(
        DurchsichtenNotifier.new);

final letzteDurchsichtenProvider =
    AsyncNotifierProvider<LetzteDurchsichtenNotifier, List<Durchsicht>>(
        LetzteDurchsichtenNotifier.new);

/// Letzte Durchsicht je volkId (gemappt) fuer die VolkCard.
final letzteDurchsichtMapProvider = Provider<Map<String, Durchsicht>>((ref) {
  final list = ref.watch(letzteDurchsichtenProvider).valueOrNull ?? const [];
  return {for (final d in list) d.volkId: d};
});

class DurchsichtenNotifier extends FamilyAsyncNotifier<List<Durchsicht>, String> {
  DurchsichtGateway get _gw => ref.read(durchsichtGatewayProvider);
  @override
  Future<List<Durchsicht>> build(String volkId) => _gw.fuerVolk(volkId);

  Future<void> speichern(Durchsicht d) async {
    await _gw.speichern(d);
    ref.invalidateSelf();
    ref.invalidate(letzteDurchsichtenProvider);
  }

  Future<void> loeschen(Durchsicht d) async {
    await _gw.loeschen(d);
    ref.invalidateSelf();
    ref.invalidate(letzteDurchsichtenProvider);
  }
}

class LetzteDurchsichtenNotifier extends AsyncNotifier<List<Durchsicht>> {
  @override
  Future<List<Durchsicht>> build() => ref.read(durchsichtGatewayProvider).letzteJeVolk();
}
```

- [ ] **Step 2: Failing test** (nach signOut ist der Durchsichts-Cache invalidiert)

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bienen_app/features/auth/data/fake_auth_gateway.dart';
import 'package:bienen_app/features/auth/presentation/auth_providers.dart';
import 'package:bienen_app/features/durchsicht/data/fake_durchsicht_gateway.dart';
import 'package:bienen_app/features/durchsicht/domain/durchsicht.dart';
import 'package:bienen_app/features/durchsicht/presentation/providers/durchsicht_provider.dart';

void main() {
  test('signOut invalidiert den Durchsichts-Cache', () async {
    final fake = FakeDurchsichtGateway();
    await fake.speichern(Durchsicht(id: 'd1', volkId: 'v1', durchgefuehrtAm: DateTime(2026, 5, 1)));
    final container = ProviderContainer(overrides: [
      authGatewayProvider.overrideWithValue(FakeAuthGateway()),
      durchsichtGatewayProvider.overrideWithValue(fake),
    ]);
    addTearDown(container.dispose);

    await container.read(durchsichtenFuerVolkProvider('v1').future);
    expect(container.read(durchsichtenFuerVolkProvider('v1')).valueOrNull, isNotEmpty);

    await container.read(authControllerProvider.notifier).signOut();
    final neu = await container.read(durchsichtenFuerVolkProvider('v1').future);
    expect(neu, isNotNull); // Rebuild lief fehlerfrei (kein Stale-Cache-Crash)
  });
}
```
> `FakeAuthGateway`-Konstruktion an die reale Signatur anpassen (siehe `test/features/voelker/voelker_provider_reset_test.dart`).

- [ ] **Step 3: Test → FAIL** (Provider nicht in `_datenNeuLaden`).
- [ ] **Step 4: `_datenNeuLaden` erweitern** — in `auth_providers.dart` Import ergänzen und in `_datenNeuLaden()` nach den bestehenden `invalidate`-Aufrufen:

```dart
// Import oben:
import 'package:bienen_app/features/durchsicht/presentation/providers/durchsicht_provider.dart';

// in _datenNeuLaden():
    ref.invalidate(durchsichtenFuerVolkProvider);
    ref.invalidate(letzteDurchsichtenProvider);
```

- [ ] **Step 5: Test + analyze** → PASS, sauber.
- [ ] **Step 6: Commit** — `git commit -m "feat(durchsicht): Provider + Auth-Cache-Invalidierung"`

### Task 11: Durchsichts-Formular (Seite)

**Files:** Create `lib/features/durchsicht/presentation/pages/durchsicht_form_page.dart`

- [ ] **Step 1: Implementieren** — vollflächige, abschnittsweise Erfassung; Foto-Upload via Gateway (Pfade sammeln); Speichern via Provider; `VoelkerFehler`/generischer Fehler als SnackBar.

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:bienen_app/features/auth/presentation/auth_providers.dart';
import 'package:bienen_app/features/durchsicht/domain/bienen_schaetzung.dart';
import 'package:bienen_app/features/durchsicht/domain/durchsicht.dart';
import 'package:bienen_app/features/durchsicht/domain/durchsicht_gateway.dart';
import 'package:bienen_app/features/durchsicht/presentation/providers/durchsicht_provider.dart';

/// [bestehend] != null -> Bearbeiten.
class DurchsichtFormPage extends ConsumerStatefulWidget {
  final String volkId;
  final Durchsicht? bestehend;
  const DurchsichtFormPage({super.key, required this.volkId, this.bestehend});
  @override
  ConsumerState<DurchsichtFormPage> createState() => _DurchsichtFormPageState();
}

class _DurchsichtFormPageState extends ConsumerState<DurchsichtFormPage> {
  late DateTime _datum;
  String? _weiselzustand, _brutbild, _pollen, _platz, _weiselzellen;
  bool _koeniginGesehen = false, _stifteGesehen = false, _busy = false;
  int? _sanftmut, _wabensitz;
  final _staerke = TextEditingController();
  final _futter = TextEditingController();
  final _massnahmen = TextEditingController();
  final _notiz = TextEditingController();
  final _auffaelligkeiten = <String>{};
  final _fotoPfade = <String>[];

  @override
  void initState() {
    super.initState();
    final b = widget.bestehend;
    _datum = b?.durchgefuehrtAm ?? DateTime.now();
    if (b != null) {
      _weiselzustand = b.weiselzustand; _brutbild = b.brutbild; _pollen = b.pollen;
      _platz = b.platz; _weiselzellen = b.weiselzellen;
      _koeniginGesehen = b.koeniginGesehen; _stifteGesehen = b.stifteGesehen;
      _sanftmut = b.sanftmut; _wabensitz = b.wabensitz;
      _staerke.text = b.staerkeWabengassen?.toString() ?? '';
      _futter.text = b.futterKg?.toString() ?? '';
      _massnahmen.text = b.massnahmen ?? ''; _notiz.text = b.notiz ?? '';
      _auffaelligkeiten.addAll(b.auffaelligkeiten);
      _fotoPfade.addAll(b.fotoUrls);
    }
  }

  Future<void> _fotoAufnehmen() async {
    final betriebId = ref.read(currentBetriebIdProvider);
    if (betriebId == null) return;
    final file = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 75, maxWidth: 2000);
    if (file == null) return;
    setState(() => _busy = true);
    try {
      final bytes = await file.readAsBytes();
      final pfad = await ref.read(durchsichtGatewayProvider).fotoHochladen(
            betriebId: betriebId, gruppeId: widget.volkId, bytes: bytes);
      setState(() => _fotoPfade.add(pfad));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Foto fehlgeschlagen: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _speichern() async {
    setState(() => _busy = true);
    final d = Durchsicht(
      id: widget.bestehend?.id ?? '',
      volkId: widget.volkId,
      durchgefuehrtAm: _datum,
      weiselzustand: _weiselzustand,
      koeniginGesehen: _koeniginGesehen,
      stifteGesehen: _stifteGesehen,
      weiselzellen: _weiselzellen,
      brutbild: _brutbild,
      staerkeWabengassen: num.tryParse(_staerke.text.replaceAll(',', '.')),
      futterKg: num.tryParse(_futter.text.replaceAll(',', '.')),
      pollen: _pollen,
      platz: _platz,
      sanftmut: _sanftmut,
      wabensitz: _wabensitz,
      auffaelligkeiten: _auffaelligkeiten.toList(),
      massnahmen: _massnahmen.text.trim().isEmpty ? null : _massnahmen.text.trim(),
      fotoUrls: _fotoPfade,
      notiz: _notiz.text.trim().isEmpty ? null : _notiz.text.trim(),
    );
    try {
      await ref.read(durchsichtenFuerVolkProvider(widget.volkId).notifier).speichern(d);
      if (mounted) Navigator.pop(context);
    } on DurchsichtFehler catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Speichern fehlgeschlagen: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _chips(String label, List<String> optionen, String? wert, ValueChanged<String?> onSel) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(padding: const EdgeInsets.only(top: 12, bottom: 4), child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600))),
          Wrap(spacing: 8, children: [
            for (final o in optionen)
              ChoiceChip(label: Text(o), selected: wert == o, onSelected: (s) => onSel(s ? o : null)),
          ]),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final gassen = num.tryParse(_staerke.text.replaceAll(',', '.'));
    final schaetzung = bienenSchaetzung(gassen);
    return Scaffold(
      appBar: AppBar(title: Text(widget.bestehend == null ? 'Durchsicht' : 'Durchsicht bearbeiten')),
      body: AbsorbPointer(
        absorbing: _busy,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Datum'),
            subtitle: Text('${_datum.day}.${_datum.month}.${_datum.year}'),
            trailing: const Icon(Icons.calendar_today),
            onTap: () async {
              final d = await showDatePicker(context: context, initialDate: _datum,
                  firstDate: DateTime(2020), lastDate: DateTime(2100));
              if (d != null) setState(() => _datum = d);
            },
          ),
          _chips('Weiselzustand', const ['weiselrichtig', 'weisellos', 'drohnenbruetig', 'unsicher'], _weiselzustand, (v) => setState(() => _weiselzustand = v)),
          SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Königin gesehen'), value: _koeniginGesehen, onChanged: (v) => setState(() => _koeniginGesehen = v)),
          SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Stifte gesehen'), value: _stifteGesehen, onChanged: (v) => setState(() => _stifteGesehen = v)),
          if (_stifteGesehen) const Padding(padding: EdgeInsets.only(bottom: 4), child: Text('Frische Stifte sprechen für weiselrichtig.', style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey))),
          _chips('Weiselzellen', const ['keine', 'spielnaepfchen', 'schwarmzellen', 'nachschaffungszellen'], _weiselzellen, (v) => setState(() => _weiselzellen = v)),
          _chips('Brutbild', const ['geschlossen', 'lueckig', 'bunt', 'kaum', 'kein'], _brutbild, (v) => setState(() => _brutbild = v)),
          TextField(controller: _staerke, keyboardType: TextInputType.number, onChanged: (_) => setState(() {}), decoration: InputDecoration(labelText: 'Besetzte Wabengassen', helperText: schaetzung != null ? '≈ $schaetzung Bienen' : null)),
          TextField(controller: _futter, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Futter (kg, Schätzung)')),
          _chips('Pollen', const ['viel', 'mittel', 'wenig', 'kein'], _pollen, (v) => setState(() => _pollen = v)),
          _chips('Platz', const ['ok', 'eng', 'honigraum_noetig', 'zu_gross'], _platz, (v) => setState(() => _platz = v)),
          _slider('Sanftmut', _sanftmut, (v) => setState(() => _sanftmut = v)),
          _slider('Wabensitz', _wabensitz, (v) => setState(() => _wabensitz = v)),
          const Padding(padding: EdgeInsets.only(top: 12, bottom: 4), child: Text('Auffälligkeiten', style: TextStyle(fontWeight: FontWeight.w600))),
          Wrap(spacing: 8, children: [
            for (final f in Durchsicht.auffaelligkeitenWhitelist)
              FilterChip(label: Text(f), selected: _auffaelligkeiten.contains(f),
                  onSelected: (s) => setState(() => s ? _auffaelligkeiten.add(f) : _auffaelligkeiten.remove(f))),
          ]),
          TextField(controller: _massnahmen, maxLines: 2, decoration: const InputDecoration(labelText: 'Massnahmen')),
          TextField(controller: _notiz, maxLines: 2, decoration: const InputDecoration(labelText: 'Notiz')),
          const SizedBox(height: 12),
          Row(children: [
            OutlinedButton.icon(onPressed: _fotoAufnehmen, icon: const Icon(Icons.add_a_photo), label: const Text('Foto')),
            const SizedBox(width: 12),
            Text('${_fotoPfade.length} Foto(s)'),
          ]),
          const SizedBox(height: 20),
          FilledButton(onPressed: _busy ? null : _speichern, child: const Text('Speichern')),
        ]),
      ),
    );
  }

  Widget _slider(String label, int? wert, ValueChanged<int?> onCh) => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Row(children: [
          SizedBox(width: 90, child: Text(label)),
          Expanded(child: Slider(value: (wert ?? 0).toDouble(), min: 0, max: 4, divisions: 4,
              label: wert == null ? '—' : '$wert', onChanged: (v) => onCh(v == 0 ? null : v.round()))),
          SizedBox(width: 24, child: Text(wert?.toString() ?? '—')),
        ]),
      );
}
```

- [ ] **Step 2: Commit** — `git commit -m "feat(durchsicht): Durchsichts-Formular (geführt, Foto)"`

### Task 12: Timeline-Karte, Detailseite, Router & 4.2-Andocken

**Files:** Create `widgets/durchsicht_karte.dart`, `widgets/durchsicht_timeline.dart`, `pages/durchsicht_detail_page.dart`; Modify `lib/core/router/app_router.dart`, `lib/features/voelker/presentation/pages/volk_detail_page.dart`, `lib/features/voelker/presentation/widgets/volk_card.dart`

- [ ] **Step 1: `durchsicht_karte.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:bienen_app/features/durchsicht/domain/durchsicht.dart';

class DurchsichtKarte extends StatelessWidget {
  final Durchsicht d;
  final VoidCallback onTap;
  const DurchsichtKarte({super.key, required this.d, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final teile = <String>[
      if (d.staerkeWabengassen != null) '${d.staerkeWabengassen} Gassen',
      if (d.auffaelligkeiten.isNotEmpty) d.auffaelligkeiten.join(', '),
      if ((d.massnahmen ?? '').isNotEmpty) d.massnahmen!,
    ];
    return Card(
      child: ListTile(
        onTap: onTap,
        title: Text('${d.durchgefuehrtAm.day}.${d.durchgefuehrtAm.month}.${d.durchgefuehrtAm.year}'),
        subtitle: teile.isEmpty ? null : Text(teile.join(' · '), maxLines: 2, overflow: TextOverflow.ellipsis),
        trailing: d.weiselzustand == null
            ? null
            : Chip(label: Text(d.weiselzustand!), visualDensity: VisualDensity.compact),
      ),
    );
  }
}
```

- [ ] **Step 2: `durchsicht_timeline.dart`** (ersetzt den 4.2-Platzhalter; lädt die Timeline, „+ Durchsicht", Empty/Error-States)

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:bienen_app/features/auth/presentation/auth_providers.dart';
import 'package:bienen_app/features/durchsicht/presentation/providers/durchsicht_provider.dart';
import 'package:bienen_app/features/durchsicht/presentation/widgets/durchsicht_karte.dart';

class DurchsichtTimeline extends ConsumerWidget {
  final String volkId;
  const DurchsichtTimeline({super.key, required this.volkId});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(durchsichtenFuerVolkProvider(volkId));
    final darf = ref.watch(darfSchreibenProvider);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Text('Verlauf (Durchsichten)', style: TextStyle(fontWeight: FontWeight.bold)),
            const Spacer(),
            if (darf)
              TextButton.icon(
                onPressed: () => context.go('/voelker/$volkId/durchsicht'),
                icon: const Icon(Icons.add), label: const Text('Durchsicht')),
          ]),
          async.when(
            loading: () => const Padding(padding: EdgeInsets.all(8), child: LinearProgressIndicator()),
            error: (e, _) => Padding(padding: const EdgeInsets.all(8), child: Text('Fehler: $e')),
            data: (list) => list.isEmpty
                ? const Padding(padding: EdgeInsets.all(8), child: Text('Noch keine Durchsicht.'))
                : Column(children: [
                    for (final d in list)
                      DurchsichtKarte(d: d, onTap: () => context.go('/voelker/$volkId/durchsicht/${d.id}')),
                  ]),
          ),
        ]),
      ),
    );
  }
}
```

- [ ] **Step 3: `durchsicht_detail_page.dart`** (Vollansicht + Bearbeiten + Löschen)

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:bienen_app/features/auth/presentation/auth_providers.dart';
import 'package:bienen_app/features/durchsicht/domain/durchsicht.dart';
import 'package:bienen_app/features/durchsicht/presentation/pages/durchsicht_form_page.dart';
import 'package:bienen_app/features/durchsicht/presentation/providers/durchsicht_provider.dart';

class DurchsichtDetailPage extends ConsumerWidget {
  final String volkId;
  final String durchsichtId;
  const DurchsichtDetailPage({super.key, required this.volkId, required this.durchsichtId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(durchsichtenFuerVolkProvider(volkId));
    final darf = ref.watch(darfSchreibenProvider);
    return async.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Fehler: $e'))),
      data: (list) {
        final i = list.indexWhere((d) => d.id == durchsichtId);
        if (i < 0) {
          return Scaffold(appBar: AppBar(), body: const Center(child: Text('Durchsicht nicht gefunden.')));
        }
        final d = list[i];
        return Scaffold(
          appBar: AppBar(
            title: Text('${d.durchgefuehrtAm.day}.${d.durchgefuehrtAm.month}.${d.durchgefuehrtAm.year}'),
            actions: [
              if (darf) IconButton(icon: const Icon(Icons.edit), onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => DurchsichtFormPage(volkId: volkId, bestehend: d)))),
              if (darf) IconButton(icon: const Icon(Icons.delete_outline), onPressed: () async {
                final ok = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
                  title: const Text('Durchsicht löschen?'),
                  content: const Text('Der Eintrag und seine Fotos werden entfernt.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Abbrechen')),
                    FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Löschen')),
                  ],
                ));
                if (ok == true) {
                  await ref.read(durchsichtenFuerVolkProvider(volkId).notifier).loeschen(d);
                  if (context.mounted) context.go('/voelker/$volkId');
                }
              }),
            ],
          ),
          body: ListView(padding: const EdgeInsets.all(16), children: [
            _z('Weiselzustand', d.weiselzustand),
            _z('Königin gesehen', d.koeniginGesehen ? 'ja' : 'nein'),
            _z('Stifte gesehen', d.stifteGesehen ? 'ja' : 'nein'),
            _z('Weiselzellen', d.weiselzellen),
            _z('Brutbild', d.brutbild),
            _z('Wabengassen', d.staerkeWabengassen?.toString()),
            _z('Futter (kg)', d.futterKg?.toString()),
            _z('Pollen', d.pollen),
            _z('Platz', d.platz),
            _z('Sanftmut', d.sanftmut?.toString()),
            _z('Wabensitz', d.wabensitz?.toString()),
            _z('Auffälligkeiten', d.auffaelligkeiten.isEmpty ? null : d.auffaelligkeiten.join(', ')),
            _z('Massnahmen', d.massnahmen),
            _z('Notiz', d.notiz),
            _z('Fotos', d.fotoUrls.isEmpty ? null : '${d.fotoUrls.length}'),
          ]),
        );
      },
    );
  }

  Widget _z(String label, String? wert) => (wert == null || wert.isEmpty)
      ? const SizedBox.shrink()
      : Padding(padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(width: 140, child: Text(label, style: const TextStyle(color: Colors.grey))),
            Expanded(child: Text(wert)),
          ]));
}
```
> Foto-Anzeige (Signed-URL) ist bewusst schlank („N Fotos") — die volle Galerie liefert 4.25. Optional: pro Pfad `fotoSignedUrl` laden und als `Image.network` zeigen; hält den ersten Cut klein.

- [ ] **Step 4: Router-Routen** — in `app_router.dart` innerhalb der `/voelker/:id`-Route die zwei Unterrouten ergänzen (Imports der zwei Pages + `DurchsichtFormPage`):

```dart
// unter GoRoute(path: '/voelker', routes: [ GoRoute(path: ':id', ... , routes: [ ... hier ... ]) ])
GoRoute(
  path: 'durchsicht',
  builder: (c, s) => DurchsichtFormPage(volkId: s.pathParameters['id']!),
),
GoRoute(
  path: 'durchsicht/:did',
  builder: (c, s) => DurchsichtDetailPage(
    volkId: s.pathParameters['id']!, durchsichtId: s.pathParameters['did']!),
),
```
> Falls `/voelker/:id` bisher keine `routes:`-Liste hat, eine anlegen. Bestehende `/voelker`- und `/voelker/:id`-Builder unverändert lassen.

- [ ] **Step 5: 4.2-Andocken — `volk_detail_page.dart`:** die Platzhalter-Card „Verlauf — kommt mit Durchsicht/Behandlung" durch `DurchsichtTimeline(volkId: volk.id)` ersetzen (Import ergänzen).

- [ ] **Step 6: 4.2-Andocken — `volk_card.dart`:** in `ConsumerWidget` umwandeln (falls nötig) bzw. `letzteDurchsichtMapProvider` lesen und eine dezente Zeile ergänzen:

```dart
// im build: final letzte = ref.watch(letzteDurchsichtMapProvider)[volk.id];
// im subtitle/trailing-Bereich:
//   letzte == null ? 'noch nie gesehen'
//     : 'zuletzt: ${DateTime.now().difference(letzte.durchgefuehrtAm).inDays} Tage'
```
> `VolkCard` ist aktuell `StatelessWidget` — auf `ConsumerWidget` umstellen (Import `flutter_riverpod`), `build(context, ref)`; die bestehende Nutzung in `voelker_page.dart` bleibt gleich.

- [ ] **Step 7: analyze + tests** — `flutter analyze` sauber; `flutter test --concurrency=1` grün.
- [ ] **Step 8: Commit** — `git commit -m "feat(durchsicht): Timeline/Detail/Router + Andocken an Volk-Detailseite & VolkCard"`

---

# Phase 4 — Abschluss

### Task 13: Volllauf + Version + Deploy

- [ ] **Step 1:** `flutter analyze` → **No issues found.**
- [ ] **Step 2:** `flutter test --concurrency=1` → alle grün (inkl. `test/features/durchsicht/*`).
- [ ] **Step 3:** `pubspec.yaml` `version:` von `1.9.0+27` → `1.10.0+28`. Commit.
- [ ] **Step 4:** Merge `feat/durchsicht` → `master` (`--no-ff`), Push, `bash deploy.sh`.
- [ ] **Step 5: Live-Verifikation** (headless-Limit beachten): Durchsicht anlegen → erscheint in der Timeline; Foto aufnehmen → Signed-URL lädt; Werte in der Detailansicht; „zuletzt gesehen" in der Völkerliste; Löschen entfernt Eintrag (+ best-effort Foto). Bei fremdem Betrieb: keine Durchsichten sichtbar.
- [ ] **Step 6: Arbeitsschluss (App-Schiene):** `ToDo.md`/`roadmap-app.md`/`decision-log.md`/Memory nachführen, `git status` sauber.

---

## Self-Review (vom Plan-Autor)
- **Spec-Abdeckung:** §4.1 inspections → Task 1; §4.2 View → Task 1; §4.3 privater Bucket → Task 2; §5 bienenSchaetzung → Task 5; §6 Gateway/Provider/Foto-Lifecycle/Andocken/`_datenNeuLaden` → Task 7–12; §7 Migrationen/Deploy → Task 1–3/13; §8 Tests → Task 1–2 (SQL) + 5/6/8/10 (Dart); §9 Erweiterungspunkte als Felder enthalten.
- **Placeholder:** keine „TBD"; jeder Code-Step zeigt Code.
- **Typkonsistenz:** `DurchsichtGateway`-Signaturen identisch in Interface/Fake/Supabase/Providern; `durchsichtenFuerVolkProvider`/`letzteDurchsichtenProvider`/`letzteDurchsichtMapProvider` konsistent; `fotoHochladen({betriebId, gruppeId, bytes})` überall gleich; `Durchsicht.auffaelligkeitenWhitelist`/`gueltigeFlags` konsistent DB↔App.
- **Offen:** Foto-Vollanzeige (Signed-URL als `Image.network`) bewusst minimal (Task 12 Step 3 Notiz) — 4.25 liefert die Galerie.
