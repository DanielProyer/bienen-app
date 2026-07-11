# Bienenstand-Bau Feature Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Neuer App-Tab „Bau" mit vollem v4-Bauplan (Referenz) und einer Supabase-synchronen, foto-dokumentierten Bau-Checkliste (F00–F18).

**Architecture:** Neues Feature `lib/features/construction/` nach dem `material/`-Muster (immutable Model, manueller Riverpod `AsyncNotifier`, Supabase inline, Optimistic-Update + Revert). Referenzansicht rendert Markdown-Asset (`flutter_markdown`) + ISO-Bild + PDF-Link. Foto-Upload über `image_picker` → Supabase Storage (Bucket `construction-photos`). 6. Nav-Tab in `app_shell.dart` + Route in `app_router.dart`.

**Tech Stack:** Flutter 3.41.1 (Web), Riverpod 2.6, go_router 14.8, supabase_flutter 2.8, flutter_markdown 0.7, image_picker (neu).

**Branch:** `feature/construction` (bereits angelegt, ausgecheckt).

---

## Dateistruktur

Neu:
- `assets/bauplan/bienenstand_bauplan.md` — voller v4-Text (Referenz)
- `assets/bauplan/bienenstand_variante2_bauplan.pdf` — 6-seitiger Bauplan
- `assets/bauplan/bienenstand_iso.png` — ISO-Übersichtsbild
- `lib/features/construction/data/models/construction_step.dart` — Model
- `lib/features/construction/presentation/providers/construction_provider.dart` — Notifier + Provider
- `lib/features/construction/presentation/widgets/construction_step_tile.dart` — Abhak-/Foto-Tile
- `lib/features/construction/presentation/pages/bauplan_view.dart` — Referenzansicht
- `lib/features/construction/presentation/pages/construction_page.dart` — Tab-Seite
- `supabase/construction_schema.sql` — Tabelle + RLS + Trigger + Seed + Bucket (Doku im Repo)
- `test/features/construction/construction_step_test.dart` — Model-Tests
- `test/features/construction/construction_progress_test.dart` — Progress-Tests

Geändert:
- `pubspec.yaml` — `image_picker`-Dependency + Asset-Verzeichnis `assets/bauplan/`
- `lib/core/router/app_router.dart` — Import + `/construction`-Route
- `lib/shared/widgets/app_shell.dart` — 6. Tab „Bau" an drei Stellen

Extern (ausserhalb Repo, im Projektordner):
- `D:\Projekte\Bienen\03_Bienenstand\fotos\` — leerer Ordner für manuelle Foto-Ablage

---

## Task 1: Vorarbeiten — Assets & Ordner

**Files:**
- Create: `assets/bauplan/bienenstand_bauplan.md`, `assets/bauplan/bienenstand_variante2_bauplan.pdf`, `assets/bauplan/bienenstand_iso.png`
- Create (extern): `D:\Projekte\Bienen\03_Bienenstand\fotos\.gitkeep`-Äquivalent (nur Ordner)
- Modify: `pubspec.yaml:33-34`

- [ ] **Step 1: Assets-Ordner anlegen und Dateien kopieren**

Aus Repo-Root `D:/Projekte/Bienen/bienen_app` (Bash):
```bash
mkdir -p assets/bauplan
cp "D:/Projekte/Bienen/03_Bienenstand/bienenstand_bauanleitung_detail_1.md" assets/bauplan/bienenstand_bauplan.md
cp "D:/Projekte/Bienen/03_Bienenstand/bienenstand_variante2_bauplan.pdf" assets/bauplan/bienenstand_variante2_bauplan.pdf
cp "D:/Projekte/Bienen/03_Bienenstand/bienenstand_iso.png" assets/bauplan/bienenstand_iso.png
mkdir -p "D:/Projekte/Bienen/03_Bienenstand/fotos"
```

- [ ] **Step 2: Assets in pubspec.yaml registrieren**

`pubspec.yaml`, ersetze den `assets:`-Block (Z. 33-34):
```yaml
  assets:
    - assets/recherche/
    - assets/bauplan/
```

- [ ] **Step 3: Commit**

```bash
git add assets/bauplan pubspec.yaml
git commit -m "Add Bienenstand build-plan assets (md, pdf, iso image)"
```

---

## Task 2: image_picker-Dependency

**Files:**
- Modify: `pubspec.yaml:9-21`

- [ ] **Step 1: Dependency hinzufügen**

`pubspec.yaml`, nach Zeile `fl_chart: ^0.70.0` (Z. 21) einfügen:
```yaml
  image_picker: ^1.1.2
```

- [ ] **Step 2: Pub get ausführen**

Run: `flutter pub get`
Expected: „Got dependencies!" ohne Fehler; `image_picker` in `pubspec.lock`.

- [ ] **Step 3: Commit**

```bash
git add pubspec.yaml pubspec.lock
git commit -m "Add image_picker dependency for construction photos"
```

---

## Task 3: Supabase — Tabelle, RLS, Trigger, Seed, Storage-Bucket

**Files:**
- Create: `supabase/construction_schema.sql`

Ausführung über das Supabase-MCP (`apply_migration`) gegen Projekt `dcdcohktxbhdxnxjvcyp`. Das SQL zusätzlich als Repo-Doku ablegen.

- [ ] **Step 1: SQL-Datei anlegen**

`supabase/construction_schema.sql`:
```sql
-- Bienen App: Construction (Bienenstand-Bau) Schema
-- Tabelle für die Bau-Checkliste + Foto-Dokumentation

create table if not exists construction_steps (
  id uuid primary key default gen_random_uuid(),
  phase text not null,           -- vorbereitung | einkauf | bau | abnahme | nachkontrolle
  foto_code text not null,       -- F00..F18
  title text not null,
  soll text,
  sort_order int default 0,
  is_done boolean default false,
  note text,
  photo_url text,
  photo_taken_at timestamptz,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

alter table construction_steps enable row level security;

create policy "Allow public read" on construction_steps for select using (true);
create policy "Allow public insert" on construction_steps for insert with check (true);
create policy "Allow public update" on construction_steps for update using (true);
create policy "Allow public delete" on construction_steps for delete using (true);

-- update_updated_at() existiert bereits (materials); Trigger wiederverwenden
create trigger construction_steps_updated_at
  before update on construction_steps
  for each row execute function update_updated_at();

-- Seed: 19 Foto-/Kontrollpunkte (F00-F18)
insert into construction_steps (phase, foto_code, title, soll, sort_order) values
('vorbereitung','F00','Standort vor Baubeginn (Übersicht Fläche + Ausrichtung Südost)', null, 0),
('einkauf','F01','Eingekauftes Material komplett ausgelegt (Vollständigkeits-Beleg)', null, 1),
('bau','F02','Beide fertigen Doppelbalken, Stossversatz sichtbar','Stösse liegen nie übereinander; Balken gerade, kein Verzug', 2),
('bau','F03','Angezeichnetes Rechteck 2000×400 mit Massband','Beinabstand 2000 mm, Balkenachse 400 mm, Diagonalen gleich', 3),
('bau','F04','Alle 4 Erdschrauben gesetzt (Übersicht)','Positionen = Rechteck aus Schritt 2', 4),
('bau','F05','Wasserwaage an einer Hülse (Lot-Beleg)','Jede Erdschraube lotrecht', 5),
('bau','F06','Durchbolzter Pfosten im U-FIX (Detail)','Pfosten fest, grob gleiche Oberkante', 6),
('bau','F07','Nivellier-Bolzen im Pfostenkopf (Detail)','Schraube leichtgängig, Scheibe plan, ±25 mm frei', 7),
('bau','F08','Laser-/Wasserwaagen-Kontrolle auf dem Balken','Balken waagerecht längs UND quer; Kontermuttern fest', 8),
('bau','F09','Schwerlast-Winkel montiert (Detail)','Je Balken 2 Winkel, 8 gesamt', 9),
('bau','F10','Platte mit versiegelten Kanten + Entwässerungslöchern','Kanten rundum versiegelt; Löcher Ø 8 mm', 10),
('bau','F11','Alle 4 Platten montiert (Gesamtansicht)','Völkerabstand ≈ 265 mm, Plattenlücke ~160 mm', 11),
('bau','F12','Wasserwaage auf einer Platte','Jede Platte waagerecht (Waagengenauigkeit)', 12),
('bau','F13','Fertig behandelter, getrockneter Stand','Kein blankes Hirnholz', 13),
('bau','F14','Waage auf Platte (vor Beute)','Reihenfolge Platte → Waage → Beute', 14),
('bau','F15','Fertiger Stand mit 4 Beuten, Fluglöcher Südost','Beutenboden ≈ 44 cm', 15),
('abnahme','F16','Übersicht Endzustand','Keine Durchbiegung sichtbar (< 0,5 mm bei Vollvolk)', 16),
('abnahme','F17','Detail Nivellierung/Kontermutter (Abnahme-Beleg)','Kontermuttern fest', 17),
('nachkontrolle','F18','Nach dem Nachnivellieren (Datum im Dateinamen)','Wieder exakt waagerecht; keine losen Verbindungen', 18);

-- Storage-Bucket für Baufotos (public)
insert into storage.buckets (id, name, public)
values ('construction-photos', 'construction-photos', true)
on conflict (id) do nothing;

create policy "Public read construction photos" on storage.objects
  for select using (bucket_id = 'construction-photos');
create policy "Public upload construction photos" on storage.objects
  for insert with check (bucket_id = 'construction-photos');
create policy "Public update construction photos" on storage.objects
  for update using (bucket_id = 'construction-photos');
```

- [ ] **Step 2: Migration anwenden (Supabase-MCP)**

Über MCP `apply_migration` (name: `construction_steps`, query = Inhalt oben, ggf. ohne den `storage.*`-Teil in einer zweiten Migration `construction_storage` falls Policy-Konflikte). Bei „policy already exists" die betroffene `create policy` mit `drop policy if exists ...` vorab ergänzen.

- [ ] **Step 3: Verifizieren**

Über MCP `execute_sql`: `select foto_code, phase, sort_order from construction_steps order by sort_order;`
Expected: 19 Zeilen F00–F18. Und `select id, public from storage.buckets where id = 'construction-photos';` → 1 Zeile, `public = true`.

- [ ] **Step 4: Commit**

```bash
git add supabase/construction_schema.sql
git commit -m "Add construction_steps table, seed and storage bucket SQL"
```

---

## Task 4: Model `ConstructionStep` (TDD)

**Files:**
- Create: `lib/features/construction/data/models/construction_step.dart`
- Test: `test/features/construction/construction_step_test.dart`

- [ ] **Step 1: Failing test schreiben**

`test/features/construction/construction_step_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:bienen_app/features/construction/data/models/construction_step.dart';

void main() {
  test('fromJson maps snake_case DB keys', () {
    final step = ConstructionStep.fromJson({
      'id': 'abc',
      'phase': 'bau',
      'foto_code': 'F06',
      'title': 'Pfosten im U-FIX',
      'soll': 'Pfosten fest',
      'sort_order': 6,
      'is_done': true,
      'note': 'ok',
      'photo_url': 'https://x/y.jpg',
      'photo_taken_at': '2026-07-11T10:00:00.000Z',
    });
    expect(step.id, 'abc');
    expect(step.fotoCode, 'F06');
    expect(step.isDone, true);
    expect(step.photoTakenAt!.toUtc().hour, 10);
  });

  test('toJson round-trips through fromJson', () {
    const original = ConstructionStep(
      id: '1', phase: 'bau', fotoCode: 'F02', title: 'Balken', sortOrder: 2);
    final restored = ConstructionStep.fromJson(original.toJson());
    expect(restored.id, '1');
    expect(restored.fotoCode, 'F02');
    expect(restored.isDone, false);
    expect(restored.photoUrl, isNull);
  });

  test('copyWith overrides only given fields', () {
    const s = ConstructionStep(
      id: '1', phase: 'bau', fotoCode: 'F02', title: 'Balken');
    final done = s.copyWith(isDone: true, note: 'fertig');
    expect(done.isDone, true);
    expect(done.note, 'fertig');
    expect(done.title, 'Balken');
  });
}
```

- [ ] **Step 2: Test laufen lassen (muss fehlschlagen)**

Run: `flutter test test/features/construction/construction_step_test.dart`
Expected: FAIL — „Target of URI doesn't exist" (Model fehlt).

- [ ] **Step 3: Model implementieren**

`lib/features/construction/data/models/construction_step.dart`:
```dart
class ConstructionStep {
  final String id;
  final String phase;
  final String fotoCode;
  final String title;
  final String? soll;
  final int sortOrder;
  final bool isDone;
  final String? note;
  final String? photoUrl;
  final DateTime? photoTakenAt;

  const ConstructionStep({
    required this.id,
    required this.phase,
    required this.fotoCode,
    required this.title,
    this.soll,
    this.sortOrder = 0,
    this.isDone = false,
    this.note,
    this.photoUrl,
    this.photoTakenAt,
  });

  ConstructionStep copyWith({
    String? id,
    String? phase,
    String? fotoCode,
    String? title,
    String? soll,
    int? sortOrder,
    bool? isDone,
    String? note,
    String? photoUrl,
    DateTime? photoTakenAt,
  }) {
    return ConstructionStep(
      id: id ?? this.id,
      phase: phase ?? this.phase,
      fotoCode: fotoCode ?? this.fotoCode,
      title: title ?? this.title,
      soll: soll ?? this.soll,
      sortOrder: sortOrder ?? this.sortOrder,
      isDone: isDone ?? this.isDone,
      note: note ?? this.note,
      photoUrl: photoUrl ?? this.photoUrl,
      photoTakenAt: photoTakenAt ?? this.photoTakenAt,
    );
  }

  factory ConstructionStep.fromJson(Map<String, dynamic> json) {
    return ConstructionStep(
      id: json['id'] as String,
      phase: json['phase'] as String,
      fotoCode: json['foto_code'] as String,
      title: json['title'] as String,
      soll: json['soll'] as String?,
      sortOrder: json['sort_order'] as int? ?? 0,
      isDone: json['is_done'] as bool? ?? false,
      note: json['note'] as String?,
      photoUrl: json['photo_url'] as String?,
      photoTakenAt: json['photo_taken_at'] != null
          ? DateTime.parse(json['photo_taken_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'phase': phase,
      'foto_code': fotoCode,
      'title': title,
      'soll': soll,
      'sort_order': sortOrder,
      'is_done': isDone,
      'note': note,
      'photo_url': photoUrl,
      'photo_taken_at': photoTakenAt?.toIso8601String(),
    };
  }
}
```

- [ ] **Step 4: Test laufen lassen (muss bestehen)**

Run: `flutter test test/features/construction/construction_step_test.dart`
Expected: PASS (3 Tests).

- [ ] **Step 5: Commit**

```bash
git add lib/features/construction/data/models/construction_step.dart test/features/construction/construction_step_test.dart
git commit -m "Add ConstructionStep model with tests"
```

---

## Task 5: Provider + Progress-Funktion (TDD für Progress)

**Files:**
- Create: `lib/features/construction/presentation/providers/construction_provider.dart`
- Test: `test/features/construction/construction_progress_test.dart`

- [ ] **Step 1: Failing test für reine Progress-Funktion**

`test/features/construction/construction_progress_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:bienen_app/features/construction/data/models/construction_step.dart';
import 'package:bienen_app/features/construction/presentation/providers/construction_provider.dart';

ConstructionStep _s(String id, bool done) =>
    ConstructionStep(id: id, phase: 'bau', fotoCode: 'F$id', title: 't', isDone: done);

void main() {
  test('constructionProgress counts done and total', () {
    final steps = [_s('1', true), _s('2', false), _s('3', true)];
    final p = constructionProgress(steps);
    expect(p.done, 2);
    expect(p.total, 3);
  });

  test('constructionProgress on empty list is 0/0', () {
    final p = constructionProgress(const []);
    expect(p.done, 0);
    expect(p.total, 0);
  });
}
```

- [ ] **Step 2: Test laufen lassen (muss fehlschlagen)**

Run: `flutter test test/features/construction/construction_progress_test.dart`
Expected: FAIL — `constructionProgress` nicht definiert.

- [ ] **Step 3: Provider implementieren**

`lib/features/construction/presentation/providers/construction_provider.dart`:
```dart
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:bienen_app/core/supabase/supabase_config.dart';
import 'package:bienen_app/features/construction/data/models/construction_step.dart';

final constructionStepsProvider =
    AsyncNotifierProvider<ConstructionStepsNotifier, List<ConstructionStep>>(
        ConstructionStepsNotifier.new);

typedef ConstructionProgress = ({int done, int total});

ConstructionProgress constructionProgress(List<ConstructionStep> steps) {
  final done = steps.where((s) => s.isDone).length;
  return (done: done, total: steps.length);
}

final constructionProgressProvider = Provider<ConstructionProgress>((ref) {
  final steps = ref.watch(constructionStepsProvider).valueOrNull ?? const [];
  return constructionProgress(steps);
});

class ConstructionStepsNotifier extends AsyncNotifier<List<ConstructionStep>> {
  static const _bucket = 'construction-photos';

  @override
  Future<List<ConstructionStep>> build() => _fetch();

  Future<List<ConstructionStep>> _fetch() async {
    try {
      final response = await SupabaseConfig.client
          .from('construction_steps')
          .select()
          .order('sort_order');
      return (response as List)
          .map((j) => ConstructionStep.fromJson(j as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return _seedData;
    }
  }

  Future<void> toggleDone(String id, bool done) async {
    final current = state.valueOrNull ?? [];
    state = AsyncData([
      for (final s in current)
        if (s.id == id) s.copyWith(isDone: done) else s,
    ]);
    try {
      await SupabaseConfig.client
          .from('construction_steps')
          .update({'is_done': done}).eq('id', id);
    } catch (_) {
      state = AsyncData(current);
      rethrow;
    }
  }

  Future<void> updateNote(String id, String note) async {
    final current = state.valueOrNull ?? [];
    state = AsyncData([
      for (final s in current)
        if (s.id == id) s.copyWith(note: note) else s,
    ]);
    try {
      await SupabaseConfig.client
          .from('construction_steps')
          .update({'note': note}).eq('id', id);
    } catch (_) {
      state = AsyncData(current);
      rethrow;
    }
  }

  Future<void> attachPhoto(String id, Uint8List bytes) async {
    final path = '$id.jpg';
    await SupabaseConfig.client.storage.from(_bucket).uploadBinary(
          path,
          bytes,
          fileOptions:
              const FileOptions(upsert: true, contentType: 'image/jpeg'),
        );
    final base = SupabaseConfig.client.storage.from(_bucket).getPublicUrl(path);
    final takenAt = DateTime.now();
    // Cache-Bust, damit das neue Foto sofort angezeigt wird
    final url = '$base?v=${takenAt.millisecondsSinceEpoch}';

    final current = state.valueOrNull ?? [];
    state = AsyncData([
      for (final s in current)
        if (s.id == id)
          s.copyWith(photoUrl: url, photoTakenAt: takenAt)
        else
          s,
    ]);
    await SupabaseConfig.client.from('construction_steps').update({
      'photo_url': url,
      'photo_taken_at': takenAt.toIso8601String(),
    }).eq('id', id);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = AsyncData(await _fetch());
  }
}

// Fallback-Seed (falls Supabase nicht erreichbar). Reihenfolge = sort_order.
final _seedData = <ConstructionStep>[
  const ConstructionStep(id: '0', phase: 'vorbereitung', fotoCode: 'F00', title: 'Standort vor Baubeginn (Übersicht Fläche + Ausrichtung Südost)', sortOrder: 0),
  const ConstructionStep(id: '1', phase: 'einkauf', fotoCode: 'F01', title: 'Eingekauftes Material komplett ausgelegt (Vollständigkeits-Beleg)', sortOrder: 1),
  const ConstructionStep(id: '2', phase: 'bau', fotoCode: 'F02', title: 'Beide fertigen Doppelbalken, Stossversatz sichtbar', soll: 'Stösse liegen nie übereinander; Balken gerade, kein Verzug', sortOrder: 2),
  const ConstructionStep(id: '3', phase: 'bau', fotoCode: 'F03', title: 'Angezeichnetes Rechteck 2000×400 mit Massband', soll: 'Beinabstand 2000 mm, Balkenachse 400 mm, Diagonalen gleich', sortOrder: 3),
  const ConstructionStep(id: '4', phase: 'bau', fotoCode: 'F04', title: 'Alle 4 Erdschrauben gesetzt (Übersicht)', soll: 'Positionen = Rechteck aus Schritt 2', sortOrder: 4),
  const ConstructionStep(id: '5', phase: 'bau', fotoCode: 'F05', title: 'Wasserwaage an einer Hülse (Lot-Beleg)', soll: 'Jede Erdschraube lotrecht', sortOrder: 5),
  const ConstructionStep(id: '6', phase: 'bau', fotoCode: 'F06', title: 'Durchbolzter Pfosten im U-FIX (Detail)', soll: 'Pfosten fest, grob gleiche Oberkante', sortOrder: 6),
  const ConstructionStep(id: '7', phase: 'bau', fotoCode: 'F07', title: 'Nivellier-Bolzen im Pfostenkopf (Detail)', soll: 'Schraube leichtgängig, Scheibe plan, ±25 mm frei', sortOrder: 7),
  const ConstructionStep(id: '8', phase: 'bau', fotoCode: 'F08', title: 'Laser-/Wasserwaagen-Kontrolle auf dem Balken', soll: 'Balken waagerecht längs UND quer; Kontermuttern fest', sortOrder: 8),
  const ConstructionStep(id: '9', phase: 'bau', fotoCode: 'F09', title: 'Schwerlast-Winkel montiert (Detail)', soll: 'Je Balken 2 Winkel, 8 gesamt', sortOrder: 9),
  const ConstructionStep(id: '10', phase: 'bau', fotoCode: 'F10', title: 'Platte mit versiegelten Kanten + Entwässerungslöchern', soll: 'Kanten rundum versiegelt; Löcher Ø 8 mm', sortOrder: 10),
  const ConstructionStep(id: '11', phase: 'bau', fotoCode: 'F11', title: 'Alle 4 Platten montiert (Gesamtansicht)', soll: 'Völkerabstand ≈ 265 mm, Plattenlücke ~160 mm', sortOrder: 11),
  const ConstructionStep(id: '12', phase: 'bau', fotoCode: 'F12', title: 'Wasserwaage auf einer Platte', soll: 'Jede Platte waagerecht (Waagengenauigkeit)', sortOrder: 12),
  const ConstructionStep(id: '13', phase: 'bau', fotoCode: 'F13', title: 'Fertig behandelter, getrockneter Stand', soll: 'Kein blankes Hirnholz', sortOrder: 13),
  const ConstructionStep(id: '14', phase: 'bau', fotoCode: 'F14', title: 'Waage auf Platte (vor Beute)', soll: 'Reihenfolge Platte → Waage → Beute', sortOrder: 14),
  const ConstructionStep(id: '15', phase: 'bau', fotoCode: 'F15', title: 'Fertiger Stand mit 4 Beuten, Fluglöcher Südost', soll: 'Beutenboden ≈ 44 cm', sortOrder: 15),
  const ConstructionStep(id: '16', phase: 'abnahme', fotoCode: 'F16', title: 'Übersicht Endzustand', soll: 'Keine Durchbiegung sichtbar (< 0,5 mm bei Vollvolk)', sortOrder: 16),
  const ConstructionStep(id: '17', phase: 'abnahme', fotoCode: 'F17', title: 'Detail Nivellierung/Kontermutter (Abnahme-Beleg)', soll: 'Kontermuttern fest', sortOrder: 17),
  const ConstructionStep(id: '18', phase: 'nachkontrolle', fotoCode: 'F18', title: 'Nach dem Nachnivellieren (Datum im Dateinamen)', soll: 'Wieder exakt waagerecht; keine losen Verbindungen', sortOrder: 18),
];
```

- [ ] **Step 4: Test laufen lassen (muss bestehen)**

Run: `flutter test test/features/construction/construction_progress_test.dart`
Expected: PASS (2 Tests).

- [ ] **Step 5: Commit**

```bash
git add lib/features/construction/presentation/providers/construction_provider.dart test/features/construction/construction_progress_test.dart
git commit -m "Add construction provider with progress helper and tests"
```

---

## Task 6: Step-Tile Widget

**Files:**
- Create: `lib/features/construction/presentation/widgets/construction_step_tile.dart`

- [ ] **Step 1: Tile implementieren**

`lib/features/construction/presentation/widgets/construction_step_tile.dart`:
```dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:bienen_app/core/theme/app_theme.dart';
import 'package:bienen_app/features/construction/data/models/construction_step.dart';
import 'package:bienen_app/features/construction/presentation/providers/construction_provider.dart';

class ConstructionStepTile extends ConsumerWidget {
  final ConstructionStep step;
  const ConstructionStepTile({super.key, required this.step});

  Future<void> _pickPhoto(BuildContext context, WidgetRef ref) async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
      maxWidth: 2000,
    );
    if (file == null) return;
    final Uint8List bytes = await file.readAsBytes();
    try {
      await ref
          .read(constructionStepsProvider.notifier)
          .attachPhoto(step.id, bytes);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Foto-Upload fehlgeschlagen: $e')),
        );
      }
    }
  }

  Future<void> _editNote(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController(text: step.note ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Notiz · ${step.fotoCode}'),
        content: TextField(
          controller: controller,
          maxLines: 4,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Notiz eingeben…'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Speichern'),
          ),
        ],
      ),
    );
    if (result != null) {
      await ref
          .read(constructionStepsProvider.notifier)
          .updateNote(step.id, result);
    }
  }

  void _showPhoto(BuildContext context) {
    if (step.photoUrl == null) return;
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        child: InteractiveViewer(
          child: Image.network(step.photoUrl!),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(constructionStepsProvider.notifier);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              value: step.isDone,
              onChanged: (v) => notifier.toggleDone(step.id, v ?? false),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.honey,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          step.fotoCode,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          step.title,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            decoration: step.isDone
                                ? TextDecoration.lineThrough
                                : null,
                            color: step.isDone ? AppColors.brown300 : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (step.soll != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Soll: ${step.soll}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.green800,
                      ),
                    ),
                  ],
                  if (step.note != null && step.note!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      '📝 ${step.note}',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.brown600,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      TextButton.icon(
                        onPressed: () => _pickPhoto(context, ref),
                        icon: Icon(
                          step.photoUrl == null
                              ? Icons.add_a_photo_outlined
                              : Icons.cameraswitch_outlined,
                          size: 18,
                        ),
                        label: Text(step.photoUrl == null ? 'Foto' : 'Ersetzen'),
                      ),
                      TextButton.icon(
                        onPressed: () => _editNote(context, ref),
                        icon: const Icon(Icons.edit_note, size: 18),
                        label: const Text('Notiz'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (step.photoUrl != null)
              GestureDetector(
                onTap: () => _showPhoto(context),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.network(
                    step.photoUrl!,
                    width: 56,
                    height: 56,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(Icons.broken_image),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Analyze**

Run: `flutter analyze lib/features/construction/presentation/widgets/construction_step_tile.dart`
Expected: „No issues found!"

- [ ] **Step 3: Commit**

```bash
git add lib/features/construction/presentation/widgets/construction_step_tile.dart
git commit -m "Add construction step tile with photo upload and note"
```

---

## Task 7: Bauplan-Referenzansicht

**Files:**
- Create: `lib/features/construction/presentation/pages/bauplan_view.dart`

- [ ] **Step 1: BauplanView implementieren**

`lib/features/construction/presentation/pages/bauplan_view.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:bienen_app/core/theme/app_theme.dart';

class BauplanView extends StatefulWidget {
  const BauplanView({super.key});

  @override
  State<BauplanView> createState() => _BauplanViewState();
}

class _BauplanViewState extends State<BauplanView> {
  String? _content;
  String? _error;

  static const _assetMd = 'assets/bauplan/bienenstand_bauplan.md';
  static const _assetPdf =
      'assets/assets/bauplan/bienenstand_variante2_bauplan.pdf';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final c = await rootBundle.loadString(_assetMd);
      setState(() => _content = c);
    } catch (e) {
      setState(() => _error = 'Bauplan konnte nicht geladen werden: $e');
    }
  }

  Future<void> _openPdf() async {
    // Flutter-Web legt deklarierte Assets unter assets/<pfad> ab; Uri.base
    // berücksichtigt das GitHub-Pages base-href (/bienen-app/).
    final uri = Uri.base.resolve(_assetPdf);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Center(
        child: Text(_error!, style: const TextStyle(color: Colors.red)),
      );
    }
    if (_content == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.asset('assets/bauplan/bienenstand_iso.png'),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: _openPdf,
              icon: const Icon(Icons.picture_as_pdf),
              label: const Text('Bauplan als PDF öffnen'),
            ),
            OutlinedButton.icon(
              onPressed: () => context.go('/material'),
              icon: const Icon(Icons.shopping_cart),
              label: const Text('Zur Einkaufsliste'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        MarkdownBody(
          data: _content!,
          selectable: true,
          styleSheet: MarkdownStyleSheet(
            h1: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.brown800),
            h2: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.brown800),
            h3: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.honeyDark),
            p: const TextStyle(fontSize: 14, height: 1.6),
            tableHead: const TextStyle(fontWeight: FontWeight.bold),
            tableBorder:
                TableBorder.all(color: AppColors.brown100, width: 1),
            tableCellsPadding: const EdgeInsets.all(6),
            listBullet: const TextStyle(fontSize: 14),
          ),
        ),
      ],
    );
  }
}
```

- [ ] **Step 2: Analyze**

Run: `flutter analyze lib/features/construction/presentation/pages/bauplan_view.dart`
Expected: „No issues found!"

- [ ] **Step 3: Commit**

```bash
git add lib/features/construction/presentation/pages/bauplan_view.dart
git commit -m "Add build-plan reference view (markdown + iso image + pdf link)"
```

---

## Task 8: Construction-Page (Tabs + Doku-Liste)

**Files:**
- Create: `lib/features/construction/presentation/pages/construction_page.dart`

- [ ] **Step 1: ConstructionPage implementieren**

`lib/features/construction/presentation/pages/construction_page.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bienen_app/core/theme/app_theme.dart';
import 'package:bienen_app/features/construction/data/models/construction_step.dart';
import 'package:bienen_app/features/construction/presentation/pages/bauplan_view.dart';
import 'package:bienen_app/features/construction/presentation/providers/construction_provider.dart';
import 'package:bienen_app/features/construction/presentation/widgets/construction_step_tile.dart';

const _phaseLabels = <String, String>{
  'vorbereitung': 'Vorbereitung',
  'einkauf': 'Einkauf',
  'bau': 'Bau',
  'abnahme': 'Endabnahme',
  'nachkontrolle': 'Nachkontrolle',
};

class ConstructionPage extends StatelessWidget {
  const ConstructionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Bienenstand-Bau'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Bauplan', icon: Icon(Icons.architecture)),
              Tab(text: 'Dokumentation', icon: Icon(Icons.checklist)),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            BauplanView(),
            _DocumentationTab(),
          ],
        ),
      ),
    );
  }
}

class _DocumentationTab extends ConsumerWidget {
  const _DocumentationTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stepsAsync = ref.watch(constructionStepsProvider);
    final progress = ref.watch(constructionProgressProvider);

    return stepsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Fehler: $e')),
      data: (steps) {
        // Nach Phase gruppieren, Reihenfolge über sort_order erhalten
        final phases = <String, List<ConstructionStep>>{};
        for (final s in steps) {
          phases.putIfAbsent(s.phase, () => []).add(s);
        }
        return Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: AppColors.amber50,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Fortschritt: ${progress.done}/${progress.total} dokumentiert',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress.total == 0
                          ? 0
                          : progress.done / progress.total,
                      minHeight: 8,
                      backgroundColor: AppColors.brown100,
                      color: AppColors.green600,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                children: [
                  for (final entry in phases.entries) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                      child: Text(
                        _phaseLabels[entry.key] ?? entry.key,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.brown800,
                        ),
                      ),
                    ),
                    for (final step in entry.value)
                      ConstructionStepTile(step: step),
                  ],
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
```

- [ ] **Step 2: Analyze**

Run: `flutter analyze lib/features/construction/presentation/pages/construction_page.dart`
Expected: „No issues found!"

- [ ] **Step 3: Commit**

```bash
git add lib/features/construction/presentation/pages/construction_page.dart
git commit -m "Add construction page with plan/documentation tabs"
```

---

## Task 9: Navigation & Route verdrahten

**Files:**
- Modify: `lib/core/router/app_router.dart:18-20, 182-191`
- Modify: `lib/shared/widgets/app_shell.dart:10-32, 91-96, 130-135`

- [ ] **Step 1: Router-Import + Route**

`app_router.dart`, nach Z. 19 (Import `scale_settings_page.dart`) einfügen:
```dart
import 'package:bienen_app/features/construction/presentation/pages/construction_page.dart';
```
Und nach dem `/monitoring`-GoRoute-Block (nach Z. 191, vor `],` der ShellRoute-routes) einfügen:
```dart
        GoRoute(
          path: '/construction',
          builder: (context, state) => const ConstructionPage(),
        ),
```

- [ ] **Step 2: `_selectedIndex` erweitern**

`app_shell.dart`, in `_selectedIndex()` vor `return 0;` (Z. 16) einfügen:
```dart
    if (location.startsWith('/construction')) return 5;
```

- [ ] **Step 3: `_onDestinationSelected` erweitern**

`app_shell.dart`, in der `switch`-Anweisung nach `case 4:` (Z. 29-30) ergänzen:
```dart
      case 5:
        context.go('/construction');
```

- [ ] **Step 4: NavigationRail-Destination ergänzen**

`app_shell.dart`, in der `destinations`-Liste des `NavigationRail` nach dem „Waage"-Eintrag (nach Z. 95) einfügen:
```dart
                NavigationRailDestination(
                  icon: Icon(Icons.construction_outlined),
                  selectedIcon: Icon(Icons.construction),
                  label: Text('Bau'),
                ),
```

- [ ] **Step 5: NavigationBar-Destination ergänzen**

`app_shell.dart`, in der `destinations`-Liste der `NavigationBar` nach dem „Waage"-Eintrag (nach Z. 134) einfügen:
```dart
          NavigationDestination(
            icon: Icon(Icons.construction_outlined),
            selectedIcon: Icon(Icons.construction),
            label: 'Bau',
          ),
```

- [ ] **Step 6: Analyze gesamtes Projekt**

Run: `flutter analyze`
Expected: „No issues found!" (keine ungenutzten Imports, keine fehlenden Symbole).

- [ ] **Step 7: Commit**

```bash
git add lib/core/router/app_router.dart lib/shared/widgets/app_shell.dart
git commit -m "Wire construction feature into router and nav (6th Bau tab)"
```

---

## Task 10: Verifikation im Browser

**Files:** keine (manuelle Prüfung)

- [ ] **Step 1: Alle Tests laufen lassen**

Run: `flutter test`
Expected: alle Tests PASS (Model 3 + Progress 2 + evtl. bestehender widget_test).
Falls `test/widget_test.dart` (Flutter-Default) bricht, weil es `MyApp` erwartet: als separates Problem notieren, nicht in diesem Feature fixen.

- [ ] **Step 2: Web-Build prüfen**

Run: `flutter build web`
Expected: „✓ Built build/web" ohne Fehler; `assets/bauplan/*` im Build enthalten.

- [ ] **Step 3: App lokal starten und manuell prüfen (verify-Skill)**

Nutze die `verify`-/`run`-Fähigkeit (Preview-Server). Prüfen:
1. 6. Tab „Bau" erscheint in BottomNav (schmal) und NavigationRail (breit).
2. Tab „Bauplan": ISO-Bild lädt, Markdown-Volltext (Masstabelle, Zuschnitt, Einkaufsliste) sichtbar, „PDF öffnen" öffnet die PDF, „Zur Einkaufsliste" wechselt zu `/material`.
3. Tab „Dokumentation": 19 Punkte F00–F18, nach Phasen gruppiert, Fortschrittsbalken 0/19.
4. Abhaken eines Punkts → Häkchen bleibt (Supabase-Persist); Reload → Status bleibt.
5. „Foto" → Bild wählen → Thumbnail erscheint, Vollbild per Tap; Reload → Foto bleibt.
6. „Notiz" → Text speichern → erscheint unter dem Punkt.

- [ ] **Step 4: Abschluss-Commit (falls kleine Fixes nötig waren)**

```bash
git add -A
git commit -m "Fix issues found during construction feature verification"
```

---

## Self-Review (durchgeführt)

- **Spec-Abdeckung:** voller Bauplan in App → Task 7 (BauplanView). Supabase-Sync + Foto → Task 3 (Tabelle+Bucket), Task 5 (Provider), Task 6 (Upload). Neuer Tab → Task 9. Repo-Vorarbeiten/fotos-Ordner → Task 1. Datenmodell → Task 4. Alle Spec-Abschnitte abgedeckt.
- **Platzhalter:** keine „TBD/TODO"; jeder Code-Step enthält vollständigen Code und exakte Befehle.
- **Typ-Konsistenz:** `constructionStepsProvider`, `ConstructionStepsNotifier`, Methoden `toggleDone/updateNote/attachPhoto/refresh`, `constructionProgress`/`ConstructionProgress ({done,total})`, DB-Keys snake_case durchgängig identisch über Tasks 4/5/6/8 verwendet.
- **Offener Punkt zur Laufzeit-Verifikation:** PDF-Asset-URL auf Flutter-Web (`assets/assets/...` + `Uri.base.resolve`) in Step 10.3 im Browser bestätigen; bei Bedarf auf einen In-App-PDF-Viewer ausweichen (nicht Teil dieses Plans).
