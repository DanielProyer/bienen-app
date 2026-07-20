# Wissensdatenbank Zyklus 1 — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. Ultracode ist an → je Task adversariale Verifikation + finaler Review.

**Goal:** Kontext-Wissen (schnelle Info + SVG-Skizze + eigene Fotos je Betrieb) in die App, generisch per `key` verlinkt; erster Andock: die Durchsicht-Zeichen.

**Architecture:** Neues Feature `lib/features/wissen/`. Ebene A = const-Fachkatalog (offline, type-sicher, generischer Deep-Link). Ebene B = mandantenfähige Foto-Tabelle + privater Bucket (Migration M01), Storage über den bestehenden `FotoSpeicher`. Das ⓘ (`WissenInfoButton`) + das BottomSheet-`WissenPanel` docken über den `key` an jedes Modul an; Skizze-Vollbild und Recherche-Detail per `Navigator.push` (keine fragile `extra`-Route).

**Tech Stack:** Flutter Web, Riverpod (AsyncNotifier.family), go_router (Hash), supabase_flutter, flutter_svg (neu), image_picker + file_picker (vorhanden). Spec: `docs/superpowers/specs/2026-07-20-wissensdatenbank-design.md`.

---

## Dateistruktur

**Neu:**
- `supabase/migrations/M01_wissen_fotos.sql` — Tabelle + Bucket + RLS + Trigger
- `lib/features/wissen/domain/wissen_eintrag.dart` — `WissensEintrag`, `WissensLink`, `WissensKategorie`
- `lib/features/wissen/domain/wissen_katalog.dart` — Katalog + reine Funktionen
- `lib/features/wissen/domain/durchsicht_wissen.dart` — `kDurchsichtWissen` (Andock-Map)
- `lib/features/wissen/domain/wissen_foto.dart` — `WissenFoto` (read-only)
- `lib/features/wissen/data/wissen_foto_repository.dart` — Supabase + `FotoSpeicher('wissen-photos')`
- `lib/features/wissen/data/wissen_foto_providers.dart` — Riverpod `.family`
- `lib/features/wissen/presentation/pages/wissen_overview_page.dart`
- `lib/features/wissen/presentation/pages/wissen_skizze_page.dart`
- `lib/features/wissen/presentation/widgets/wissen_info_button.dart`
- `lib/features/wissen/presentation/widgets/wissen_panel.dart`
- `lib/features/wissen/presentation/widgets/wissen_foto_strip.dart`
- `assets/wissen/{stifte,brutbild,pollen,futter,weiselzelle,koenigin,baurahmen}.svg`
- Tests: `test/wissen/{wissen_link_test,wissen_katalog_test,wissen_suche_test,durchsicht_wissen_test,wissen_foto_test}.dart`

**Geändert:**
- `pubspec.yaml` — `flutter_svg` + `assets/wissen/`, Version `1.21.0+42`
- `lib/core/router/app_router.dart` — Route `/wissen`
- `lib/features/projekt/pages/projekt_page.dart` — Nav-Kachel „Wissen"
- `lib/shared/widgets/app_shell.dart` — `/wissen` ins Shell-Highlight (Index 3)
- `lib/features/durchsicht/presentation/widgets/waben_schritt.dart` — ⓘ neben belegten Merkmalen

---

## Task 1: Produktions-Migration M01 (Bucket + Tabelle + RLS)

> **Controller-Aufgabe, braucht explizite Freigabe** („M01 auf Produktion freigeben"). Anlegen als nummeriertes File **und** via Supabase-MCP `apply_migration` (Projekt `dcdcohktxbhdxnxjvcyp`).

**Files:**
- Create: `supabase/migrations/M01_wissen_fotos.sql`

- [ ] **Step 1: Migrationsfile schreiben**

```sql
-- M01_wissen_fotos.sql | Wissensdatenbank: eigene Beispiel-Fotos je Betrieb (Modul 4.21).
-- Privater Bucket + mandantenfähige Tabelle. Muster: L01 (Tabelle) + G02 (Bucket/Storage).
create table if not exists public.wissen_fotos (
  id uuid primary key default gen_random_uuid(),
  wissen_key text not null check (length(btrim(wissen_key)) > 0),
  storage_path text not null check (storage_path like (betrieb_id::text || '/%')),
  beschriftung text,
  betrieb_id uuid not null default private.aktive_betrieb_id()
    references public.betriebe(id) on delete cascade,
  created_by uuid, updated_by uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (betrieb_id, id)
);
alter table public.wissen_fotos enable row level security;
revoke all on public.wissen_fotos from anon, public;
grant select, insert, update, delete on public.wissen_fotos to authenticated;
create index if not exists idx_wissen_fotos_key on public.wissen_fotos (betrieb_id, wissen_key);

drop trigger if exists trg_wissen_fotos_actor on public.wissen_fotos;
create trigger trg_wissen_fotos_actor before insert or update
  on public.wissen_fotos for each row execute function private.set_row_actor();
drop trigger if exists trg_wissen_fotos_updated on public.wissen_fotos;
create trigger trg_wissen_fotos_updated before update
  on public.wissen_fotos for each row execute function private.set_updated_at();

drop policy if exists wissen_fotos_sel_member on public.wissen_fotos;
create policy wissen_fotos_sel_member on public.wissen_fotos
  for select to authenticated using (betrieb_id in (select private.meine_betrieb_ids()));
drop policy if exists wissen_fotos_ins_writer on public.wissen_fotos;
create policy wissen_fotos_ins_writer on public.wissen_fotos
  for insert to authenticated with check (private.kann_schreiben(betrieb_id));
drop policy if exists wissen_fotos_upd_writer on public.wissen_fotos;
create policy wissen_fotos_upd_writer on public.wissen_fotos
  for update to authenticated using (private.kann_schreiben(betrieb_id)) with check (private.kann_schreiben(betrieb_id));
drop policy if exists wissen_fotos_del_writer on public.wissen_fotos;
create policy wissen_fotos_del_writer on public.wissen_fotos
  for delete to authenticated using (private.kann_schreiben(betrieb_id));

insert into storage.buckets (id, name, public)
  values ('wissen-photos', 'wissen-photos', false)
  on conflict (id) do nothing;

drop policy if exists auth_sel_wissen_photos on storage.objects;
create policy auth_sel_wissen_photos on storage.objects for select to authenticated
  using (bucket_id = 'wissen-photos'
    and (storage.foldername(name))[1] ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
    and private.ist_mitglied(((storage.foldername(name))[1])::uuid));
drop policy if exists auth_ins_wissen_photos on storage.objects;
create policy auth_ins_wissen_photos on storage.objects for insert to authenticated
  with check (bucket_id = 'wissen-photos'
    and (storage.foldername(name))[1] ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
    and private.kann_schreiben(((storage.foldername(name))[1])::uuid));
drop policy if exists auth_upd_wissen_photos on storage.objects;
create policy auth_upd_wissen_photos on storage.objects for update to authenticated
  using (bucket_id = 'wissen-photos'
    and (storage.foldername(name))[1] ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
    and private.kann_schreiben(((storage.foldername(name))[1])::uuid))
  with check (bucket_id = 'wissen-photos'
    and (storage.foldername(name))[1] ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
    and private.kann_schreiben(((storage.foldername(name))[1])::uuid));
drop policy if exists auth_del_wissen_photos on storage.objects;
create policy auth_del_wissen_photos on storage.objects for delete to authenticated
  using (bucket_id = 'wissen-photos'
    and (storage.foldername(name))[1] ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
    and private.kann_schreiben(((storage.foldername(name))[1])::uuid));
-- ROLLBACK (vollständig): drop policy auth_{sel,ins,upd,del}_wissen_photos on storage.objects;
--   delete from storage.objects where bucket_id='wissen-photos'; delete from storage.buckets where id='wissen-photos';
--   drop table if exists public.wissen_fotos;
```

- [ ] **Step 2: Auf Produktion anwenden (nach Freigabe)**

Via Supabase-MCP `apply_migration` (name `M01_wissen_fotos`, query = obiges SQL).

- [ ] **Step 3: Verifizieren**

Rollback-Probe in einer Transaktion: insert als Mitglied → cross-tenant-select liefert 0; insert mit `storage_path` unter fremder betrieb_id → Check-Violation. `get_advisors(security)` + `get_advisors(performance)` → **0 neue** Findings. `list_tables` zeigt `wissen_fotos`; `storage.buckets` enthält `wissen-photos`.

- [ ] **Step 4: Commit**

```bash
git add supabase/migrations/M01_wissen_fotos.sql
git commit -m "feat(wissen): M01 Migration wissen_fotos (Tabelle + Bucket + RLS)"
```

---

## Task 2: pubspec — flutter_svg + Asset-Verzeichnis + Version

**Files:**
- Modify: `pubspec.yaml`

- [ ] **Step 1: Dependency + Asset + Version eintragen**

Unter `dependencies:` (nach `file_picker: ^8.1.0`):
```yaml
  flutter_svg: ^2.0.10
```
Unter `flutter: assets:` ergänzen:
```yaml
    - assets/wissen/
```
`version:` ändern:
```yaml
version: 1.21.0+42
```

- [ ] **Step 2: Platzhalter-Asset anlegen (damit `assets/wissen/` existiert)**

```bash
mkdir -p assets/wissen
```
(Die echten SVGs kommen in Task 4.)

- [ ] **Step 3: Holen & prüfen**

Run: `flutter pub get`
Expected: erfolgreich, `flutter_svg` aufgelöst.

- [ ] **Step 4: Commit**

```bash
git add pubspec.yaml pubspec.lock
git commit -m "chore(wissen): flutter_svg + assets/wissen/, version 1.21.0"
```

---

## Task 3: Domain-Modelle + WissensLink-Assert

**Files:**
- Create: `lib/features/wissen/domain/wissen_eintrag.dart`
- Test: `test/wissen/wissen_link_test.dart`

- [ ] **Step 1: Failing test schreiben**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:bienen_app/features/wissen/domain/wissen_eintrag.dart';

void main() {
  test('WissensLink verlangt genau eine Quelle', () {
    expect(() => WissensLink(label: 'x'), throwsA(isA<AssertionError>()));
    expect(() => WissensLink(label: 'x', rechercheAsset: 'a', url: 'b'), throwsA(isA<AssertionError>()));
    expect(const WissensLink(label: 'x', rechercheAsset: 'a').rechercheAsset, 'a');
    expect(const WissensLink(label: 'y', url: 'https://z').url, 'https://z');
  });
}
```

- [ ] **Step 2: Test laufen lassen → FAIL**

Run: `flutter test test/wissen/wissen_link_test.dart`
Expected: FAIL (Datei/Typ nicht gefunden).

- [ ] **Step 3: Modelle implementieren**

```dart
/// Ein weiterführender Link eines Wissens-Eintrags — GENAU eine Quelle.
class WissensLink {
  final String label;
  final String? rechercheAsset; // z.B. 'assets/recherche/10_Bienenbiologie_Das_Bienenvolk.md'
  final String? url;            // externe Quelle (z.B. BGD-Merkblatt)
  const WissensLink({required this.label, this.rechercheAsset, this.url})
      : assert((rechercheAsset == null) != (url == null),
            'Genau eine Quelle: rechercheAsset ODER url');
}

/// Ein Wissens-Eintrag = eine „schnelle Info" mit Skizze + Weiterführung.
class WissensEintrag {
  final String key;            // STABIL — der Deep-Link-Anker, eindeutig
  final String titel;
  final String kurzinfo;
  final String kategorie;      // WissensKategorie.key
  final String? skizze;        // Asset-Pfad SVG
  final List<WissensLink> mehr;
  final List<String> verwandte;
  final List<String> stichworte;
  const WissensEintrag({
    required this.key, required this.titel, required this.kurzinfo, required this.kategorie,
    this.skizze, this.mehr = const [], this.verwandte = const [], this.stichworte = const [],
  });
}

/// Kategorie = ein Schritt im Imkerei-Prozess (Übersicht-Kacheln).
class WissensKategorie {
  final String key;
  final String titel;
  final String icon; // Icon-Name-Mapping in der UI
  const WissensKategorie({required this.key, required this.titel, required this.icon});
}
```

- [ ] **Step 4: Test → PASS**

Run: `flutter test test/wissen/wissen_link_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/wissen/domain/wissen_eintrag.dart test/wissen/wissen_link_test.dart
git commit -m "feat(wissen): Domain-Modelle WissensEintrag/Link/Kategorie"
```

---

## Task 4: SVG-Skizzen (7 Dateien)

**Files:**
- Create: `assets/wissen/stifte.svg`, `brutbild.svg`, `pollen.svg`, `futter.svg`, `weiselzelle.svg`, `koenigin.svg`, `baurahmen.svg`

Alle einheitlich `viewBox="0 0 240 160"`, Honig/Braun-Palette, deutsche Beschriftung, flach/schematisch (Prinzip-Skizzen, nicht fotorealistisch). Fotorealismus liefern später die eigenen Fotos.

- [ ] **Step 1: `assets/wissen/stifte.svg`**

```svg
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 240 160">
  <g fill="#FAC775" stroke="#633806" stroke-width="2">
    <rect x="24" y="34" width="52" height="52" rx="6"/>
    <rect x="94" y="34" width="52" height="52" rx="6"/>
    <rect x="164" y="34" width="52" height="52" rx="6"/>
  </g>
  <g stroke="#633806" stroke-width="4" stroke-linecap="round" fill="none">
    <line x1="50" y1="82" x2="50" y2="46"/>
    <line x1="120" y1="82" x2="128" y2="50"/>
    <line x1="190" y1="82" x2="205" y2="66"/>
  </g>
  <g fill="#633806" font-family="sans-serif" font-size="13" text-anchor="middle">
    <text x="50" y="108">Tag 1</text><text x="120" y="108">Tag 2</text><text x="190" y="108">Tag 3</text>
    <text x="120" y="134" font-size="14">senkrecht = frisch (≤3 Tage)</text>
  </g>
</svg>
```

- [ ] **Step 2: `assets/wissen/brutbild.svg`**

```svg
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 240 160">
  <g stroke="#633806" stroke-width="1.5">
    <rect x="16" y="30" width="60" height="60" rx="4" fill="#C9A66B"/>
    <rect x="90" y="30" width="60" height="60" rx="4" fill="#C9A66B"/>
    <g fill="#7a5a2e"><circle cx="112" cy="46" r="3"/><circle cx="132" cy="60" r="3"/><circle cx="106" cy="74" r="3"/></g>
    <rect x="164" y="30" width="60" height="60" rx="4" fill="#C9A66B"/>
    <g fill="#FAC775"><circle cx="180" cy="46" r="6"/><circle cx="200" cy="58" r="6"/><circle cx="188" cy="74" r="6"/></g>
  </g>
  <g fill="#633806" font-family="sans-serif" font-size="13" text-anchor="middle">
    <text x="46" y="108">gesund</text><text x="120" y="108">löchrig</text><text x="194" y="108">buckelbrut</text>
    <text x="120" y="134" font-size="13">flach-lückenlos vs. Störung vs. weisellos</text>
  </g>
</svg>
```

- [ ] **Step 3: `assets/wissen/pollen.svg`**

```svg
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 240 160">
  <g stroke="#633806" stroke-width="1.5">
    <circle cx="120" cy="66" r="18" fill="#C9A66B"/>
    <circle cx="120" cy="30" r="9" fill="#E8A33D"/><circle cx="150" cy="42" r="9" fill="#9BB43A"/>
    <circle cx="162" cy="72" r="9" fill="#E86A3D"/><circle cx="150" cy="100" r="9" fill="#E8C43D"/>
    <circle cx="120" cy="106" r="9" fill="#9BB43A"/><circle cx="90" cy="100" r="9" fill="#E86A3D"/>
    <circle cx="78" cy="72" r="9" fill="#E8A33D"/><circle cx="90" cy="42" r="9" fill="#E8C43D"/>
  </g>
  <g fill="#633806" font-family="sans-serif" font-size="14" text-anchor="middle">
    <text x="120" y="70">Brut</text><text x="120" y="140">Pollenkranz um das Brutnest</text>
  </g>
</svg>
```

- [ ] **Step 4: `assets/wissen/futter.svg`**

```svg
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 240 160">
  <g stroke="#633806" stroke-width="2">
    <rect x="34" y="36" width="56" height="56" rx="6" fill="#E8B84D"/>
    <rect x="150" y="36" width="56" height="56" rx="6" fill="#FBF0D6"/>
  </g>
  <path d="M110 64 h24" stroke="#633806" stroke-width="3" marker-end="url(#a)"/>
  <defs><marker id="a" markerWidth="8" markerHeight="8" refX="6" refY="3" orient="auto">
    <path d="M0 0 L6 3 L0 6 z" fill="#633806"/></marker></defs>
  <g fill="#633806" font-family="sans-serif" font-size="13" text-anchor="middle">
    <text x="62" y="110">offen · glänzend</text><text x="178" y="110">verdeckelt</text>
    <text x="120" y="136" font-size="14">Nektar reift zu Honig</text>
  </g>
</svg>
```

- [ ] **Step 5: `assets/wissen/weiselzelle.svg`**

```svg
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 240 160">
  <rect x="20" y="24" width="90" height="70" rx="4" fill="#C9A66B" stroke="#633806" stroke-width="1.5"/>
  <path d="M60 94 q6 26 -6 34 q-12 -8 -6 -34 z" fill="#8a6a34" stroke="#633806" stroke-width="1.5"/>
  <rect x="130" y="24" width="90" height="70" rx="4" fill="#C9A66B" stroke="#633806" stroke-width="1.5"/>
  <path d="M172 52 q22 4 30 -6 q-8 -14 -30 -6 z" fill="#8a6a34" stroke="#633806" stroke-width="1.5"/>
  <g fill="#633806" font-family="sans-serif" font-size="12" text-anchor="middle">
    <text x="65" y="150">Schwarmzelle (Rand)</text><text x="175" y="150">Nachschaffung (Fläche)</text>
  </g>
</svg>
```

- [ ] **Step 6: `assets/wissen/koenigin.svg`**

```svg
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 240 160">
  <g fill="#C9A66B" stroke="#633806" stroke-width="1"><circle cx="80" cy="60" r="10"/><circle cx="150" cy="50" r="10"/><circle cx="120" cy="90" r="10"/><circle cx="170" cy="88" r="10"/><circle cx="96" cy="96" r="10"/></g>
  <ellipse cx="124" cy="64" rx="22" ry="11" fill="#E8A33D" stroke="#633806" stroke-width="2"/>
  <circle cx="106" cy="64" r="7" fill="#633806"/>
  <g fill="#633806" font-family="sans-serif" font-size="14" text-anchor="middle">
    <text x="124" y="138">Königin: länger, im Pulk auf Brut</text>
  </g>
</svg>
```

- [ ] **Step 7: `assets/wissen/baurahmen.svg`**

```svg
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 240 160">
  <rect x="30" y="20" width="180" height="100" rx="4" fill="none" stroke="#633806" stroke-width="4"/>
  <g fill="#B98A46" stroke="#633806" stroke-width="1.5">
    <ellipse cx="70" cy="70" rx="12" ry="16"/><ellipse cx="102" cy="70" rx="12" ry="16"/>
    <ellipse cx="134" cy="70" rx="12" ry="16"/><ellipse cx="166" cy="70" rx="12" ry="16"/>
  </g>
  <line x1="40" y1="96" x2="200" y2="96" stroke="#B32D2D" stroke-width="2" stroke-dasharray="6 4"/>
  <g fill="#633806" font-family="sans-serif" font-size="13" text-anchor="middle">
    <text x="120" y="140">Drohnenbrut ausschneiden → Varroa ↓</text>
  </g>
</svg>
```

- [ ] **Step 8: Commit**

```bash
git add assets/wissen/
git commit -m "feat(wissen): 7 SVG-Skizzen der Durchsicht-Zeichen"
```

---

## Task 5: Katalog + Invarianten-/Suche-Tests

**Files:**
- Create: `lib/features/wissen/domain/wissen_katalog.dart`
- Test: `test/wissen/wissen_katalog_test.dart`, `test/wissen/wissen_suche_test.dart`

- [ ] **Step 1: Failing tests schreiben**

`test/wissen/wissen_katalog_test.dart`:
```dart
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:bienen_app/features/wissen/domain/wissen_eintrag.dart';
import 'package:bienen_app/features/wissen/domain/wissen_katalog.dart';

void main() {
  test('keys eindeutig und nicht leer', () {
    final keys = kWissensKatalog.map((e) => e.key).toList();
    expect(keys.toSet().length, keys.length);
    expect(keys.any((k) => k.trim().isEmpty), isFalse);
  });
  test('verwandte lösen auf', () {
    for (final e in kWissensKatalog) {
      for (final v in e.verwandte) {
        expect(wissenVon(v), isNotNull, reason: '${e.key} → verwandte $v fehlt');
      }
    }
  });
  test('kategorie existiert', () {
    final kats = kWissensKategorien.map((k) => k.key).toSet();
    for (final e in kWissensKatalog) {
      expect(kats.contains(e.kategorie), isTrue, reason: e.key);
    }
  });
  test('jede skizze existiert und ist in pubspec deklariert', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final declared = RegExp(r'-\s+(assets/\S+)').allMatches(pubspec).map((m) => m.group(1)!).toList();
    for (final e in kWissensKatalog) {
      if (e.skizze == null) continue;
      expect(File(e.skizze!).existsSync(), isTrue, reason: 'Datei fehlt: ${e.skizze}');
      final covered = declared.any((d) => d == e.skizze || (d.endsWith('/') && e.skizze!.startsWith(d)));
      expect(covered, isTrue, reason: 'nicht in pubspec: ${e.skizze}');
    }
  });
  test('rechercheAsset existiert', () {
    for (final e in kWissensKatalog) {
      for (final l in e.mehr) {
        if (l.rechercheAsset != null) {
          expect(File(l.rechercheAsset!).existsSync(), isTrue, reason: l.rechercheAsset);
        }
      }
    }
  });
  test('wissenVon Null-Kontrakt (kein Throw)', () {
    expect(wissenVon(null), isNull);
    expect(wissenVon('gibt_es_nicht'), isNull);
  });
  test('belegteKategorien filtert leere aus', () {
    expect(belegteKategorien().map((k) => k.key), contains('durchsicht'));
    const leere = WissensKategorie(key: 'varroa', titel: 'Varroa', icon: 'bug');
    const voll = WissensKategorie(key: 'durchsicht', titel: 'Durchsicht', icon: 'eye');
    const eintrag = WissensEintrag(key: 'x', titel: 'X', kurzinfo: 'x', kategorie: 'durchsicht');
    final res = belegteKategorien(kategorien: const [voll, leere], katalog: const [eintrag]);
    expect(res.map((k) => k.key), ['durchsicht']);
  });
}
```

`test/wissen/wissen_suche_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:bienen_app/features/wissen/domain/wissen_katalog.dart';

void main() {
  test('leere/whitespace query → leer', () {
    expect(sucheWissen(''), isEmpty);
    expect(sucheWissen('   '), isEmpty);
  });
  test('diakritik-normalisiert', () {
    expect(sucheWissen('koenigin').map((e) => e.key), contains('koenigin_finden'));
    expect(sucheWissen('königin').map((e) => e.key), contains('koenigin_finden'));
  });
  test('trifft Stichwort', () {
    expect(sucheWissen('varroa').map((e) => e.key), contains('baurahmen_drohnen'));
  });
}
```

- [ ] **Step 2: Tests laufen lassen → FAIL**

Run: `flutter test test/wissen/wissen_katalog_test.dart test/wissen/wissen_suche_test.dart`
Expected: FAIL (Katalog fehlt).

- [ ] **Step 3: Katalog implementieren**

```dart
import 'package:bienen_app/features/wissen/domain/wissen_eintrag.dart';

const kWissensKategorien = <WissensKategorie>[
  WissensKategorie(key: 'durchsicht', titel: 'Durchsicht', icon: 'eye'),
];

const kWissensKatalog = <WissensEintrag>[
  WissensEintrag(
    key: 'stifte', titel: 'Stifte erkennen', kategorie: 'durchsicht',
    kurzinfo: 'Frische Eier sind schlanke, ~1,5 mm lange „Reiskörner", die senkrecht am Zellboden stehen. '
        'Sichtbare Stifte = die Königin hat vor höchstens 3 Tagen gelegt.',
    skizze: 'assets/wissen/stifte.svg',
    mehr: [WissensLink(label: 'Bienenvolk & Eilage', rechercheAsset: 'assets/recherche/10_Bienenbiologie_Das_Bienenvolk.md')],
    verwandte: ['koenigin_finden', 'brut_offen_verdeckelt', 'weiselzelle'],
    stichworte: ['ei', 'eier', 'reiskorn', 'gelege', 'stift'],
  ),
  WissensEintrag(
    key: 'brut_offen_verdeckelt', titel: 'Brutbild deuten', kategorie: 'durchsicht',
    kurzinfo: 'Gesund: flach, geschlossen, lückenlos verdeckelt. Löcher/„Schrotschuss" = mögliche Störung. '
        'Buckelbrut (einzeln hochgewölbte Deckel auf Arbeiterzellen, verstreut, mehrere Eier pro Zelle) = '
        'drohnenbrütig/weisellos → rasch handeln. Gewollte Drohnen-Buckelzellen stehen dagegen im Baurahmen.',
    skizze: 'assets/wissen/brutbild.svg',
    mehr: [
      WissensLink(label: 'Bienenvolk & Brut', rechercheAsset: 'assets/recherche/10_Bienenbiologie_Das_Bienenvolk.md'),
      WissensLink(label: 'Völkervermehrung (Weisellosigkeit)', rechercheAsset: 'assets/recherche/13_Voelkervermehrung.md'),
      WissensLink(label: 'Bienengesundheit', rechercheAsset: 'assets/recherche/14_Bienengesundheit_Krankheiten_CH.md'),
    ],
    verwandte: ['stifte', 'weiselzelle', 'baurahmen_drohnen'],
    stichworte: ['brutnest', 'verdeckelt', 'buckelbrut', 'drohnenmuetterchen', 'schrotschuss'],
  ),
  WissensEintrag(
    key: 'pollen', titel: 'Pollen & Bienenbrot', kategorie: 'durchsicht',
    kurzinfo: 'Bunte, matt-glänzende, fest eingestampfte Zellen — meist im Kranz rund um das Brutnest. '
        'Zeichen für Sammeltätigkeit und gute Ernährung.',
    skizze: 'assets/wissen/pollen.svg',
    mehr: [WissensLink(label: 'Bienenvolk & Ernährung', rechercheAsset: 'assets/recherche/10_Bienenbiologie_Das_Bienenvolk.md')],
    verwandte: ['futter_nektar'],
    stichworte: ['bienenbrot', 'perga', 'pollenkranz'],
  ),
  WissensEintrag(
    key: 'futter_nektar', titel: 'Futter & Nektar', kategorie: 'durchsicht',
    kurzinfo: 'Offener Nektar ist glänzend und flüssig, oben in der Wabe. Reifer Honig ist weiß verdeckelt. '
        'Die Menge grob = Anzahl gefüllter Waben.',
    skizze: 'assets/wissen/futter.svg',
    mehr: [
      WissensLink(label: 'Bienenvolk & Vorräte', rechercheAsset: 'assets/recherche/10_Bienenbiologie_Das_Bienenvolk.md'),
      WissensLink(label: 'Honig-Ernte & Qualität', rechercheAsset: 'assets/recherche/16_Honig_Ernte_Qualitaet_Vermarktung.md'),
    ],
    verwandte: ['pollen'],
    stichworte: ['honig', 'nektar', 'futter', 'vorrat'],
  ),
  WissensEintrag(
    key: 'weiselzelle', titel: 'Weiselzelle deuten', kategorie: 'durchsicht',
    kurzinfo: 'Schwarmzellen hängen am Wabenrand/-unterkante, oft mehrere → Schwarmstimmung. '
        'Nachschaffungszellen sitzen in der Wabenfläche → das Volk zieht eine Ersatz-Königin (Weisellosigkeit).',
    skizze: 'assets/wissen/weiselzelle.svg',
    mehr: [
      WissensLink(label: 'Völkervermehrung & Schwarm', rechercheAsset: 'assets/recherche/13_Voelkervermehrung.md'),
      WissensLink(label: 'Vermehrung/Jungvolk (BGD)', rechercheAsset: 'assets/recherche/25_Vermehrung_Jungvolkbildung_BGD.md'),
    ],
    verwandte: ['koenigin_finden', 'stifte', 'brut_offen_verdeckelt'],
    stichworte: ['schwarmzelle', 'nachschaffung', 'weiselnapf', 'schwarm'],
  ),
  WissensEintrag(
    key: 'koenigin_finden', titel: 'Königin finden', kategorie: 'durchsicht',
    kurzinfo: 'Länger, glänzender Hinterleib, ruhige Bewegung — meist im Bienenpulk auf offener Brut. '
        'Systematisch Wabe für Wabe suchen, dort, wo Stifte und junge Brut sind.',
    skizze: 'assets/wissen/koenigin.svg',
    mehr: [
      WissensLink(label: 'Bienenvolk & Königin', rechercheAsset: 'assets/recherche/10_Bienenbiologie_Das_Bienenvolk.md'),
      WissensLink(label: 'Königinnenzucht', rechercheAsset: 'assets/recherche/12_Koeniginnenzucht.md'),
    ],
    verwandte: ['stifte', 'weiselzelle'],
    stichworte: ['weisel', 'koenigin', 'majestaet'],
  ),
  WissensEintrag(
    key: 'baurahmen_drohnen', titel: 'Baurahmen lesen', kategorie: 'durchsicht',
    kurzinfo: 'Im Baurahmen bauen die Bienen Drohnenzellen (hochgewölbte Buckelzellen). '
        'Verdeckelte Drohnenbrut ausschneiden = biotechnische Varroa-Reduktion (die Milbe bevorzugt Drohnenbrut).',
    skizze: 'assets/wissen/baurahmen.svg',
    mehr: [
      WissensLink(label: 'Varroa-Konzept (alpin)', rechercheAsset: 'assets/recherche/15_Varroa_Bekaempfungskonzept_alpin.md'),
      WissensLink(label: 'Varroa-Behandlung (BGD)', rechercheAsset: 'assets/recherche/22_Varroa_Behandlungskonzept_BGD.md'),
    ],
    verwandte: ['weiselzelle', 'brut_offen_verdeckelt'],
    stichworte: ['drohnenbrut', 'drohnenrahmen', 'varroa', 'biotechnik'],
  ),
];

WissensEintrag? wissenVon(String? key) {
  if (key == null) return null;
  for (final e in kWissensKatalog) {
    if (e.key == key) return e;
  }
  return null; // KEIN firstWhere ohne orElse — Null-Kontrakt trägt den WissenInfoButton
}

Iterable<WissensKategorie> belegteKategorien({
  List<WissensKategorie> kategorien = kWissensKategorien,
  List<WissensEintrag> katalog = kWissensKatalog,
}) => kategorien.where((k) => katalog.any((e) => e.kategorie == k.key));

List<WissensEintrag> eintraegeDerKategorie(String kategorieKey,
        {List<WissensEintrag> katalog = kWissensKatalog}) =>
    katalog.where((e) => e.kategorie == kategorieKey).toList();

String _normalisiere(String s) => s.toLowerCase()
    .replaceAll('ä', 'ae').replaceAll('ö', 'oe').replaceAll('ü', 'ue').replaceAll('ß', 'ss');

List<WissensEintrag> sucheWissen(String query, {List<WissensEintrag> katalog = kWissensKatalog}) {
  final q = _normalisiere(query.trim());
  if (q.isEmpty) return const [];
  return katalog.where((e) =>
      _normalisiere(e.titel).contains(q) ||
      _normalisiere(e.kurzinfo).contains(q) ||
      e.stichworte.any((s) => _normalisiere(s).contains(q))).toList();
}
```

- [ ] **Step 4: Tests → PASS**

Run: `flutter test test/wissen/wissen_katalog_test.dart test/wissen/wissen_suche_test.dart`
Expected: PASS (setzt Task 4-SVGs voraus).

- [ ] **Step 5: Commit**

```bash
git add lib/features/wissen/domain/wissen_katalog.dart test/wissen/wissen_katalog_test.dart test/wissen/wissen_suche_test.dart
git commit -m "feat(wissen): Katalog mit 7 Durchsicht-Einträgen + Invarianten-Tests"
```

---

## Task 6: Andock-Map + Test

**Files:**
- Create: `lib/features/wissen/domain/durchsicht_wissen.dart`
- Test: `test/wissen/durchsicht_wissen_test.dart`

- [ ] **Step 1: Failing test schreiben**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:bienen_app/features/durchsicht/domain/wabe.dart';
import 'package:bienen_app/features/wissen/domain/wissen_katalog.dart';
import 'package:bienen_app/features/wissen/domain/durchsicht_wissen.dart';

void main() {
  test('jeder Andock-Wert löst auf', () {
    for (final key in kDurchsichtWissen.values) {
      expect(wissenVon(key), isNotNull, reason: key);
    }
  });
  test('jeder Andock-Schlüssel ist ein bekanntes Merkmal', () {
    final bekannt = {...WabeBeobachtung.kWabenInhalte, 'flag_koenigin', 'flag_weiselzelle', 'flag_stifte'};
    for (final k in kDurchsichtWissen.keys) {
      expect(bekannt.contains(k), isTrue, reason: k);
    }
  });
}
```

- [ ] **Step 2: Test → FAIL**

Run: `flutter test test/wissen/durchsicht_wissen_test.dart`
Expected: FAIL (Datei fehlt).

- [ ] **Step 3: Andock-Map implementieren**

```dart
/// Durchsicht-Merkmal (Toggle-key bzw. 'flag_*') → Wissens-key. Nur belegte Merkmale bekommen ein ⓘ.
/// 'mittelwand' und 'leer' haben (v1) keinen Eintrag → kein ⓘ.
const kDurchsichtWissen = <String, String>{
  'brut': 'brut_offen_verdeckelt',
  'pollen': 'pollen',
  'futter': 'futter_nektar',
  'honig': 'futter_nektar',
  'baurahmen': 'baurahmen_drohnen',
  'flag_koenigin': 'koenigin_finden',
  'flag_weiselzelle': 'weiselzelle',
  'flag_stifte': 'stifte',
};
```

- [ ] **Step 4: Test → PASS**

Run: `flutter test test/wissen/durchsicht_wissen_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/wissen/domain/durchsicht_wissen.dart test/wissen/durchsicht_wissen_test.dart
git commit -m "feat(wissen): Andock-Map Durchsicht → Wissens-key + Test"
```

---

## Task 7: WissenFoto-Modell + fromJson-Test

**Files:**
- Create: `lib/features/wissen/domain/wissen_foto.dart`
- Test: `test/wissen/wissen_foto_test.dart`

- [ ] **Step 1: Failing test schreiben**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:bienen_app/features/wissen/domain/wissen_foto.dart';

void main() {
  test('fromJson parst alle Felder (beschriftung gesetzt)', () {
    final f = WissenFoto.fromJson({
      'id': 'id1', 'wissen_key': 'stifte', 'storage_path': 'b/stifte/foto_1.jpg',
      'beschriftung': 'meine Wabe', 'created_at': '2026-07-20T10:00:00Z',
    });
    expect(f.id, 'id1');
    expect(f.wissenKey, 'stifte');
    expect(f.storagePath, 'b/stifte/foto_1.jpg');
    expect(f.beschriftung, 'meine Wabe');
    expect(f.createdAt.toUtc(), DateTime.utc(2026, 7, 20, 10));
  });
  test('fromJson mit beschriftung null', () {
    final f = WissenFoto.fromJson({
      'id': 'id2', 'wissen_key': 'brut_offen_verdeckelt', 'storage_path': 'b/x/foto_2.jpg',
      'beschriftung': null, 'created_at': '2026-07-20T11:00:00Z',
    });
    expect(f.beschriftung, isNull);
  });
}
```

- [ ] **Step 2: Test → FAIL**

Run: `flutter test test/wissen/wissen_foto_test.dart`
Expected: FAIL.

- [ ] **Step 3: Modell implementieren**

```dart
/// Read-only: Rows werden nur gelesen; Schreiben läuft über das Repository (Upload). Kein toJson.
class WissenFoto {
  final String id;
  final String wissenKey;
  final String storagePath;
  final String? beschriftung;
  final DateTime createdAt;
  const WissenFoto({
    required this.id, required this.wissenKey, required this.storagePath,
    this.beschriftung, required this.createdAt,
  });
  factory WissenFoto.fromJson(Map<String, dynamic> j) => WissenFoto(
        id: j['id'] as String,
        wissenKey: j['wissen_key'] as String,
        storagePath: j['storage_path'] as String,
        beschriftung: j['beschriftung'] as String?,
        createdAt: DateTime.parse(j['created_at'] as String),
      );
}
```

- [ ] **Step 4: Test → PASS**

Run: `flutter test test/wissen/wissen_foto_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/wissen/domain/wissen_foto.dart test/wissen/wissen_foto_test.dart
git commit -m "feat(wissen): WissenFoto-Modell (read-only) + fromJson-Test"
```

---

## Task 8: Repository (FotoSpeicher-Reuse + betrieb_id-Filter)

**Files:**
- Create: `lib/features/wissen/data/wissen_foto_repository.dart`

> Kein Unit-Test (DB-abhängig; Mandanten-Isolation via Migrations-Verifikation Task 1). Muster: `SupabaseGesundheitGateway`.

- [ ] **Step 1: Repository implementieren**

```dart
import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:bienen_app/core/storage/foto_speicher.dart';
import 'package:bienen_app/features/wissen/domain/wissen_foto.dart';

class WissenFotoRepository {
  final SupabaseClient _c;
  late final FotoSpeicher _fotos = FotoSpeicher(_c, 'wissen-photos');
  WissenFotoRepository(this._c);

  /// PFLICHT-Filter auf den aktiven Betrieb: wissen_key ist betriebsübergreifend gleich,
  /// RLS (meine_betrieb_ids = Plural) allein würde Mehrbetriebs-Fotos mischen.
  Future<List<WissenFoto>> ladeFotos({required String wissenKey, required String betriebId}) async {
    final res = await _c
        .from('wissen_fotos')
        .select()
        .eq('wissen_key', wissenKey)
        .eq('betrieb_id', betriebId)
        .order('created_at', ascending: false);
    return (res as List).map((j) => WissenFoto.fromJson(j as Map<String, dynamic>)).toList();
  }

  Future<String> signierteUrl(String storagePath) => _fotos.signedUrl(storagePath);

  Future<WissenFoto> ergaenzeFoto({
    required String wissenKey,
    required String betriebId,
    required Uint8List jpegBytes,
    String? beschriftung,
  }) async {
    final pfad = await _fotos.hochladen(betriebId: betriebId, gruppeId: wissenKey, bytes: jpegBytes);
    final row = await _c.from('wissen_fotos').insert({
      'wissen_key': wissenKey,
      'storage_path': pfad,
      if (beschriftung != null && beschriftung.trim().isNotEmpty) 'beschriftung': beschriftung.trim(),
    }).select().single();
    return WissenFoto.fromJson(row);
  }

  Future<void> loescheFoto(WissenFoto foto) async {
    await _c.from('wissen_fotos').delete().eq('id', foto.id);
    await _fotos.entfernen([foto.storagePath]);
  }
}
```

- [ ] **Step 2: Analyze**

Run: `flutter analyze lib/features/wissen/data/wissen_foto_repository.dart`
Expected: keine Fehler.

- [ ] **Step 3: Commit**

```bash
git add lib/features/wissen/data/wissen_foto_repository.dart
git commit -m "feat(wissen): Foto-Repository (FotoSpeicher-Reuse, betrieb_id-Pflichtfilter)"
```

---

## Task 9: Provider (Riverpod .family)

**Files:**
- Create: `lib/features/wissen/data/wissen_foto_providers.dart`

> Muster: `gesundheit_provider.dart`. `build` **watcht** `currentBetriebIdProvider` → Reload bei Betriebswechsel.

- [ ] **Step 1: Provider implementieren**

```dart
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bienen_app/core/supabase/supabase_config.dart';
import 'package:bienen_app/features/auth/presentation/auth_providers.dart';
import 'package:bienen_app/features/wissen/data/wissen_foto_repository.dart';
import 'package:bienen_app/features/wissen/domain/wissen_foto.dart';

final wissenFotoRepositoryProvider =
    Provider<WissenFotoRepository>((ref) => WissenFotoRepository(SupabaseConfig.client));

final wissenFotosProvider =
    AsyncNotifierProvider.family<WissenFotosNotifier, List<WissenFoto>, String>(WissenFotosNotifier.new);

class WissenFotosNotifier extends FamilyAsyncNotifier<List<WissenFoto>, String> {
  @override
  Future<List<WissenFoto>> build(String wissenKey) async {
    final betriebId = ref.watch(currentBetriebIdProvider); // watch → Reload bei Betriebswechsel
    if (betriebId == null) return const [];
    return ref.read(wissenFotoRepositoryProvider).ladeFotos(wissenKey: wissenKey, betriebId: betriebId);
  }

  Future<void> ergaenze({required Uint8List jpegBytes, String? beschriftung}) async {
    final betriebId = ref.read(currentBetriebIdProvider);
    if (betriebId == null) return;
    await ref.read(wissenFotoRepositoryProvider)
        .ergaenzeFoto(wissenKey: arg, betriebId: betriebId, jpegBytes: jpegBytes, beschriftung: beschriftung);
    ref.invalidateSelf();
  }

  Future<void> loeschen(WissenFoto foto) async {
    await ref.read(wissenFotoRepositoryProvider).loescheFoto(foto);
    ref.invalidateSelf();
  }
}
```

- [ ] **Step 2: Analyze**

Run: `flutter analyze lib/features/wissen/data/wissen_foto_providers.dart`
Expected: keine Fehler (ggf. Import-Pfad `auth_providers.dart` bestätigen — `currentBetriebIdProvider` ist dort definiert).

- [ ] **Step 3: Commit**

```bash
git add lib/features/wissen/data/wissen_foto_providers.dart
git commit -m "feat(wissen): Riverpod-Provider für Fotos (.family, Reload bei Betriebswechsel)"
```

---

## Task 10: Skizze-Vollbild-Seite

**Files:**
- Create: `lib/features/wissen/presentation/pages/wissen_skizze_page.dart`

- [ ] **Step 1: Implementieren**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Vollbild-Zoom einer SVG-Skizze. Wird per Navigator.push geöffnet (KEINE Route → kein extra-Problem).
class WissenSkizzePage extends StatelessWidget {
  final String assetPfad;
  final String? titel;
  const WissenSkizzePage({super.key, required this.assetPfad, this.titel});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(titel ?? 'Skizze')),
      body: Center(
        child: InteractiveViewer(
          minScale: 1,
          maxScale: 5,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SvgPicture.asset(assetPfad, fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Analyze & Commit**

Run: `flutter analyze lib/features/wissen/presentation/pages/wissen_skizze_page.dart`
Expected: keine Fehler.
```bash
git add lib/features/wissen/presentation/pages/wissen_skizze_page.dart
git commit -m "feat(wissen): Skizze-Vollbild (InteractiveViewer + flutter_svg)"
```

---

## Task 11: WissenInfoButton (generisches ⓘ)

**Files:**
- Create: `lib/features/wissen/presentation/widgets/wissen_info_button.dart`

> Hängt von `openWissenPanel` (Task 13) ab. Das Panel (Task 13) importiert den Info-Button NICHT — es gibt also keinen Zyklus. **Reihenfolge: Task 13 (Panel) unmittelbar VOR oder zusammen mit Task 11 umsetzen und beide zusammen analysieren** (der Analyze in Task 11 braucht `openWissenPanel`).

- [ ] **Step 1: Implementieren**

```dart
import 'package:flutter/material.dart';
import 'package:bienen_app/features/wissen/domain/wissen_katalog.dart';
import 'package:bienen_app/features/wissen/presentation/widgets/wissen_panel.dart';

/// Kleines ⓘ, das JEDES Modul über den Wissens-`key` andocken kann.
/// Rendert nichts, wenn der key unbekannt ist (kein dangling ⓘ).
class WissenInfoButton extends StatelessWidget {
  final String wissenKey;
  final double size;
  const WissenInfoButton({super.key, required this.wissenKey, this.size = 20});

  @override
  Widget build(BuildContext context) {
    if (wissenVon(wissenKey) == null) return const SizedBox.shrink();
    return IconButton(
      icon: Icon(Icons.info_outline, size: size),
      tooltip: 'Worauf achten?',
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints(),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      onPressed: () => openWissenPanel(context, wissenKey),
    );
  }
}
```

- [ ] **Step 2: (zusammen mit Task 13) analyze & commit** — siehe Task 13.

---

## Task 12: WissenFotoStrip („Meine Beispiele")

**Files:**
- Create: `lib/features/wissen/presentation/widgets/wissen_foto_strip.dart`

- [ ] **Step 1: Implementieren**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:bienen_app/features/wissen/data/wissen_foto_providers.dart';
import 'package:bienen_app/features/wissen/domain/wissen_foto.dart';

class WissenFotoStrip extends ConsumerWidget {
  final String wissenKey;
  const WissenFotoStrip({super.key, required this.wissenKey});

  Future<void> _upload(WidgetRef ref, Uint8List? bytes) async {
    if (bytes == null) return;
    await ref.read(wissenFotosProvider(wissenKey).notifier).ergaenze(jpegBytes: bytes);
  }

  Future<void> _quelleWaehlen(BuildContext context, WidgetRef ref) async {
    final quelle = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(leading: const Icon(Icons.camera_alt), title: const Text('Kamera'),
              onTap: () => Navigator.pop(context, 'kamera')),
          ListTile(leading: const Icon(Icons.photo_library), title: const Text('Galerie'),
              onTap: () => Navigator.pop(context, 'galerie')),
          ListTile(leading: const Icon(Icons.insert_drive_file), title: const Text('Dokumente'),
              onTap: () => Navigator.pop(context, 'datei')),
        ]),
      ),
    );
    if (quelle == null) return;
    if (quelle == 'datei') {
      final res = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
      final f = (res != null && res.files.isNotEmpty) ? res.files.first : null;
      if (f?.bytes != null) await _upload(ref, f!.bytes);
    } else {
      final x = await ImagePicker().pickImage(
        source: quelle == 'kamera' ? ImageSource.camera : ImageSource.gallery,
        imageQuality: 75, maxWidth: 2000,
      );
      if (x != null) await _upload(ref, await x.readAsBytes());
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fotos = ref.watch(wissenFotosProvider(wissenKey));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Icon(Icons.photo, size: 16),
        const SizedBox(width: 6),
        Text('Meine Beispiele', style: Theme.of(context).textTheme.labelMedium),
      ]),
      const SizedBox(height: 8),
      SizedBox(
        height: 72,
        child: ListView(scrollDirection: Axis.horizontal, children: [
          ...(fotos.valueOrNull ?? const <WissenFoto>[]).map((f) => _Thumb(foto: f, wissenKey: wissenKey)),
          OutlinedButton(
            onPressed: () => _quelleWaehlen(context, ref),
            child: const Column(mainAxisSize: MainAxisSize.min,
                children: [Icon(Icons.add), Text('Foto', style: TextStyle(fontSize: 11))]),
          ),
        ]),
      ),
    ]);
  }
}

class _Thumb extends ConsumerWidget {
  final WissenFoto foto;
  final String wissenKey;
  const _Thumb({required this.foto, required this.wissenKey});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(wissenFotoRepositoryProvider);
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onLongPress: () async {
          final ok = await showDialog<bool>(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text('Foto löschen?'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Abbrechen')),
                TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Löschen')),
              ],
            ),
          );
          if (ok == true) await ref.read(wissenFotosProvider(wissenKey).notifier).loeschen(foto);
        },
        child: FutureBuilder<String>(
          future: repo.signierteUrl(foto.storagePath),
          builder: (context, snap) => ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: snap.hasData
                ? Image.network(snap.data!, width: 72, height: 72, fit: BoxFit.cover)
                : Container(width: 72, height: 72, color: Colors.black12,
                    child: const Icon(Icons.image, color: Colors.black26)),
          ),
        ),
      ),
    );
  }
}
```

Import `dart:typed_data` oben ergänzen (für `Uint8List`):
```dart
import 'dart:typed_data';
```

- [ ] **Step 2: Analyze & Commit**

Run: `flutter analyze lib/features/wissen/presentation/widgets/wissen_foto_strip.dart`
Expected: keine Fehler.
```bash
git add lib/features/wissen/presentation/widgets/wissen_foto_strip.dart
git commit -m "feat(wissen): Foto-Strip mit Kamera/Galerie/Dokumente-Upload"
```

---

## Task 13: WissenPanel (BottomSheet + openWissenPanel)

**Files:**
- Create: `lib/features/wissen/presentation/widgets/wissen_panel.dart`

- [ ] **Step 1: Implementieren**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:bienen_app/features/recherche/pages/markdown_viewer_page.dart';
import 'package:bienen_app/features/wissen/domain/wissen_eintrag.dart';
import 'package:bienen_app/features/wissen/domain/wissen_katalog.dart';
import 'package:bienen_app/features/wissen/presentation/pages/wissen_skizze_page.dart';
import 'package:bienen_app/features/wissen/presentation/widgets/wissen_foto_strip.dart';

/// Öffnet das Wissens-Panel (schnelle Info + Skizze + eigene Fotos + Mehr) für [startKey].
Future<void> openWissenPanel(BuildContext context, String startKey) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => FractionallySizedBox(
      heightFactor: 0.75,
      child: _WissenPanel(startKey: startKey),
    ),
  );
}

class _WissenPanel extends StatefulWidget {
  final String startKey;
  const _WissenPanel({required this.startKey});
  @override
  State<_WissenPanel> createState() => _WissenPanelState();
}

class _WissenPanelState extends State<_WissenPanel> {
  late String _key = widget.startKey;
  final _scroll = ScrollController();

  void _wechsle(String neu) {
    setState(() => _key = neu);
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  @override
  Widget build(BuildContext context) {
    final e = wissenVon(_key);
    if (e == null) return const SizedBox.shrink();
    final root = Navigator.of(context, rootNavigator: true);
    return ListView(controller: _scroll, padding: const EdgeInsets.fromLTRB(16, 0, 16, 24), children: [
      Text(e.titel, style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 8),
      Text(e.kurzinfo, style: Theme.of(context).textTheme.bodyMedium),
      if (e.skizze != null) ...[
        const SizedBox(height: 16),
        GestureDetector(
          onTap: () => root.push(MaterialPageRoute(
              fullscreenDialog: true,
              builder: (_) => WissenSkizzePage(assetPfad: e.skizze!, titel: e.titel))),
          child: Container(
            height: 160,
            decoration: BoxDecoration(border: Border.all(color: Colors.black12), borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.all(8),
            child: SvgPicture.asset(e.skizze!, fit: BoxFit.contain),
          ),
        ),
        const Padding(padding: EdgeInsets.only(top: 4),
            child: Text('Skizze · antippen für Vollbild', style: TextStyle(fontSize: 11, color: Colors.black54))),
      ],
      const SizedBox(height: 16),
      WissenFotoStrip(wissenKey: e.key),
      if (e.mehr.isNotEmpty) ...[
        const Divider(height: 24),
        for (final l in e.mehr)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(l.url != null ? Icons.open_in_new : Icons.menu_book),
            title: Text(l.label),
            onTap: () {
              if (l.rechercheAsset != null) {
                root.push(MaterialPageRoute(
                    builder: (_) => MarkdownViewerPage(title: l.label, assetPath: l.rechercheAsset!)));
              } else if (l.url != null) {
                launchUrl(Uri.parse(l.url!), mode: LaunchMode.externalApplication);
              }
            },
          ),
      ],
      if (e.verwandte.isNotEmpty) ...[
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 4, children: [
          for (final v in e.verwandte)
            if (wissenVon(v) != null)
              ActionChip(label: Text('→ ${wissenVon(v)!.titel}'), onPressed: () => _wechsle(v)),
        ]),
      ],
    ]);
  }
}
```

- [ ] **Step 2: Analyze (Task 11 + 12 + 13 zusammen)**

Run: `flutter analyze lib/features/wissen/presentation/`
Expected: keine Fehler.

- [ ] **Step 3: Commit (Task 11 + 13)**

```bash
git add lib/features/wissen/presentation/widgets/wissen_panel.dart lib/features/wissen/presentation/widgets/wissen_info_button.dart
git commit -m "feat(wissen): WissenPanel (BottomSheet) + generischer WissenInfoButton"
```

---

## Task 14: Übersicht-Seite + Route + Nav-Kachel

**Files:**
- Create: `lib/features/wissen/presentation/pages/wissen_overview_page.dart`
- Modify: `lib/core/router/app_router.dart`, `lib/features/projekt/pages/projekt_page.dart`, `lib/shared/widgets/app_shell.dart`

- [ ] **Step 1: Übersicht-Seite implementieren**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:bienen_app/features/wissen/domain/wissen_eintrag.dart';
import 'package:bienen_app/features/wissen/domain/wissen_katalog.dart';
import 'package:bienen_app/features/wissen/presentation/widgets/wissen_panel.dart';

const _katIcons = <String, IconData>{'eye': Icons.visibility, 'bug': Icons.pest_control, 'droplet': Icons.water_drop};

class WissenOverviewPage extends StatefulWidget {
  const WissenOverviewPage({super.key});
  @override
  State<WissenOverviewPage> createState() => _WissenOverviewPageState();
}

class _WissenOverviewPageState extends State<WissenOverviewPage> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final treffer = _query.trim().isEmpty ? null : sucheWissen(_query);
    return Scaffold(
      appBar: AppBar(title: const Text('Wissen')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        TextField(
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search), hintText: 'Suchen: Stifte, Varroa, Futter …',
            border: OutlineInputBorder()),
          onChanged: (v) => setState(() => _query = v),
        ),
        const SizedBox(height: 16),
        if (treffer != null)
          ...treffer.map((e) => _EintragTile(e))
        else ...[
          for (final kat in belegteKategorien()) ...[
            Padding(padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(children: [
                  Icon(_katIcons[kat.icon] ?? Icons.menu_book, size: 18),
                  const SizedBox(width: 8),
                  Text(kat.titel, style: Theme.of(context).textTheme.titleMedium),
                ])),
            ...eintraegeDerKategorie(kat.key).map((e) => _EintragTile(e)),
          ],
        ],
        const Divider(height: 32),
        ListTile(
          leading: const Icon(Icons.library_books),
          title: const Text('Alle Recherchen & Merkblätter'),
          trailing: const Icon(Icons.arrow_forward),
          onTap: () => context.go('/recherche'),
        ),
      ]),
    );
  }
}

class _EintragTile extends StatelessWidget {
  final WissensEintrag e;
  const _EintragTile(this.e);
  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: e.skizze != null
            ? SizedBox(width: 40, height: 40, child: SvgPicture.asset(e.skizze!, fit: BoxFit.contain))
            : const Icon(Icons.lightbulb_outline),
        title: Text(e.titel),
        subtitle: Text(e.kurzinfo, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => openWissenPanel(context, e.key),
      ),
    );
  }
}
```

- [ ] **Step 2: Route registrieren (`app_router.dart`)**

Import oben ergänzen (bei den anderen Feature-Imports):
```dart
import 'package:bienen_app/features/wissen/presentation/pages/wissen_overview_page.dart';
```
Als Geschwister-Route zur `/recherche`-`GoRoute` (im selben `routes:`-Block der Shell), z.B. direkt vor `GoRoute(path: '/recherche', …)`:
```dart
        GoRoute(
          path: '/wissen',
          builder: (context, state) => const WissenOverviewPage(),
        ),
```

- [ ] **Step 3: Shell-Highlight (`app_shell.dart`)**

In `_selectedIndex` die `/projekt`-Bedingung um `/wissen` erweitern (Zeile mit `location.startsWith('/recherche') ||`):
```dart
        location.startsWith('/recherche') ||
        location.startsWith('/wissen') ||
```

- [ ] **Step 4: Nav-Kachel (`projekt_page.dart`)**

In `_bereiche` nach der Recherche-Zeile einfügen:
```dart
    (icon: Icons.lightbulb_outline, titel: 'Wissen', sub: 'Schnelle Infos & Skizzen', route: '/wissen'),
```

- [ ] **Step 5: Analyze**

Run: `flutter analyze lib/features/wissen/ lib/core/router/app_router.dart lib/features/projekt/pages/projekt_page.dart lib/shared/widgets/app_shell.dart`
Expected: keine Fehler.

- [ ] **Step 6: Commit**

```bash
git add lib/features/wissen/presentation/pages/wissen_overview_page.dart lib/core/router/app_router.dart lib/features/projekt/pages/projekt_page.dart lib/shared/widgets/app_shell.dart
git commit -m "feat(wissen): Übersicht-Seite + Route /wissen + Nav-Kachel"
```

---

## Task 15: Andock in der Durchsicht (waben_schritt.dart)

**Files:**
- Modify: `lib/features/durchsicht/presentation/widgets/waben_schritt.dart`

> Ziel: neben Inhalt-Chips (`brut/pollen/futter/honig/baurahmen`) und Flag-Chips (`Königin/Weiselzelle/Stifte`) ein ⓘ, wenn das Merkmal in `kDurchsichtWissen` steht. Waben-Logik unverändert.

- [ ] **Step 1: Imports ergänzen**

```dart
import 'package:bienen_app/features/wissen/domain/durchsicht_wissen.dart';
import 'package:bienen_app/features/wissen/presentation/widgets/wissen_info_button.dart';
```

- [ ] **Step 2: Inhalt-Chips um ⓘ ergänzen**

Den Inhalt-`Wrap` (`for (final e in _inhaltLabel.entries) FilterChip(...)`) ersetzen durch:
```dart
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final e in _inhaltLabel.entries)
            Row(mainAxisSize: MainAxisSize.min, children: [
              FilterChip(label: Text(e.value), selected: w.inhalte.contains(e.key),
                  onSelected: (_) => _toggleInhalt(e.key)),
              if (kDurchsichtWissen.containsKey(e.key)) WissenInfoButton(wissenKey: kDurchsichtWissen[e.key]!),
            ]),
        ]),
```

- [ ] **Step 3: Flag-Chips um ⓘ ergänzen**

Den Flag-`Wrap` (Königin/Weiselzelle/Stifte) ersetzen durch (jede FilterChip in eine `Row` mit nachgestelltem ⓘ):
```dart
        Wrap(spacing: 8, children: [
          Row(mainAxisSize: MainAxisSize.min, children: [
            FilterChip(avatar: const Icon(Icons.star, size: 18), label: const Text('Königin'), selected: w.koenigin,
                onSelected: (s) => _ersetze(WabeBeobachtung(inhalte: w.inhalte, koenigin: s, weiselzelle: w.weiselzelle, stifte: w.stifte))),
            WissenInfoButton(wissenKey: kDurchsichtWissen['flag_koenigin']!),
          ]),
          Row(mainAxisSize: MainAxisSize.min, children: [
            FilterChip(label: const Text('Weiselzelle'), selected: w.weiselzelle,
                onSelected: (s) => _ersetze(WabeBeobachtung(inhalte: w.inhalte, koenigin: w.koenigin, weiselzelle: s, stifte: w.stifte))),
            WissenInfoButton(wissenKey: kDurchsichtWissen['flag_weiselzelle']!),
          ]),
          Row(mainAxisSize: MainAxisSize.min, children: [
            FilterChip(label: const Text('Stifte'), selected: w.stifte,
                onSelected: (s) => _ersetze(WabeBeobachtung(inhalte: w.inhalte, koenigin: w.koenigin, weiselzelle: w.weiselzelle, stifte: s))),
            WissenInfoButton(wissenKey: kDurchsichtWissen['flag_stifte']!),
          ]),
        ]),
```

- [ ] **Step 4: Analyze & bestehende Tests**

Run: `flutter analyze lib/features/durchsicht/`
Expected: keine Fehler.
Run: `flutter test`
Expected: alle grün (inkl. neue Wissen-Tests).

- [ ] **Step 5: Commit**

```bash
git add lib/features/durchsicht/presentation/widgets/waben_schritt.dart
git commit -m "feat(wissen): ⓘ-Andock in der Durchsicht (Waben-Merkmale + Flags)"
```

---

## Task 16: Abschluss — analyze/test + Browser-Verifikation + Deploy

**Files:**
- (keine neuen)

- [ ] **Step 1: Voll-Analyse & Tests**

Run: `flutter analyze`
Expected: keine Fehler/Warnings.
Run: `flutter test`
Expected: alle grün.

- [ ] **Step 2: Browser-Verifikation (Preview)**

Dev-Server starten, prüfen: `/wissen` zeigt Kategorie „Durchsicht" + 7 Einträge; Panel öffnet mit Kurzinfo + Skizze; Skizze-Vollbild zoombar; „+ Foto" bietet 3 Quellen; „Mehr" öffnet MarkdownViewerPage (Sheet bleibt darunter); in der Durchsicht erscheint das ⓘ neben Brut/Pollen/Futter/Königin/Weiselzelle/Stifte; Suche „koenigin" findet „Königin finden".

- [ ] **Step 3: Deploy**

Run: `bash deploy.sh`
Expected: Build + cache-bust + gh-pages push + Live-Flip-Self-Verify grün (bei transientem DNS-Fehler „Could not resolve host: github.com" → erneut ausführen).

- [ ] **Step 4: Commit (falls offene Änderungen) & Status**

```bash
git status
```
Expected: sauberer Baum auf Branch `feat/wissensdatenbank`.

---

## Self-Review-Notizen (bereits berücksichtigt)

- **Task-Reihenfolge 11↔13:** `WissenInfoButton` importiert `openWissenPanel` — Task 13 unmittelbar mit Task 11 umsetzen und gemeinsam analysieren (im Plan vermerkt).
- **Skizze-Abhängigkeit:** Task 4 (SVGs) liegt vor Task 5 (Katalog-Test prüft `File.existsSync`).
- **Migration zuerst:** Task 1 (M01) vor den Foto-Tasks 8/9; Foto-Upload/-Laden schlägt sonst zur Laufzeit fehl (Tabelle/Bucket).
- **Mandanten-Isolation:** `ladeFotos` filtert explizit auf `betrieb_id` (Task 8) — der Kern-Review-Befund.
- **Kein `extra`-Routing:** Skizze-Vollbild + Recherche-Detail per `Navigator.push` (Task 10/13), nur `/wissen` als Route (Task 14).
