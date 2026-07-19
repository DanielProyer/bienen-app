# Cockpit & IA-Umbau Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Nav auf 4 Betriebs-Tabs umbauen (Cockpit · Völker · Aufgaben · Projekt), Dashboard zum Betriebs-Cockpit machen, Projekt-Sammelseite mit aktualisiertem Fortschritt anlegen.

**Architecture:** Reine UI-Schicht — keine Migration, keine neuen Fetches. Cockpit konsumiert bestehende Provider (`aufgabenListProvider`, `vorschlaegeProvider`, `offeneAufgabenStatsProvider`, `aktiveVoelkerProvider`, `letzteDurchsichtMapProvider`, `aktiveMeldepflichtProvider`, `darfSchreibenProvider`). Zwei neue pure Helper mit Tests; Meilensteine als Dart-Konstante.

**Tech Stack:** Flutter Web 3.41.x, Riverpod, Go Router (Hash).

**Spec:** `docs/superpowers/specs/2026-07-19-cockpit-ia-design.md` (v1). Branch: `feat/cockpit-ia` (existiert). Version am Ende: **1.15.0+33**.

**Bestehende Bausteine (NICHT neu bauen):** `naechsteOffene` kommt NEU, aber `gruppiereOffene` existiert ([aufgaben_gruppierung.dart](../../lib/features/aufgaben/domain/aufgaben_gruppierung.dart)); `letzteDurchsichtMapProvider` (Map volkId→Durchsicht, Feld `durchgefuehrtAm`) existiert ([durchsicht_provider.dart](../../lib/features/durchsicht/presentation/providers/durchsicht_provider.dart:19)); `aktiveMeldepflichtProvider(volkId)` existiert ([gesundheit_provider.dart](../../lib/features/gesundheit/presentation/providers/gesundheit_provider.dart:32)); Abhaken-Notifier `aufgabenListProvider.notifier.abhaken(id, erledigt:)` existiert. `gesundheitsstatus`-Werte: `unauffaellig|beobachtung|krank|sperre`.

---

## File-Struktur (Ziel)

```
lib/core/util/relativ_datum.dart                     (neu — pure)
lib/features/aufgaben/domain/aufgaben_gruppierung.dart (Modify — naechsteOffene ergänzen)
lib/features/projekt/domain/meilensteine.dart        (neu — Konstante)
lib/features/projekt/pages/projekt_page.dart         (neu)
lib/features/dashboard/pages/dashboard_page.dart     (Rewrite — Cockpit-Kompositum)
lib/features/dashboard/widgets/warnband.dart         (neu)
lib/features/dashboard/widgets/heute_karte.dart      (neu)
lib/features/dashboard/widgets/voelker_karte.dart    (neu)
lib/features/dashboard/widgets/waage_kachel.dart     (neu)
lib/features/mehr/                                   (LÖSCHEN, ganzer Ordner)
lib/core/router/app_router.dart                      (Modify — /projekt neu, /mehr → redirect)
lib/shared/widgets/app_shell.dart                    (Rewrite der Nav-Listen — 4 Tabs)
test/core/relativ_datum_test.dart                    (neu)
test/features/aufgaben/gruppierung_test.dart         (Modify — naechsteOffene-Tests)
test/features/projekt/meilensteine_test.dart         (neu)
pubspec.yaml                                         (Version)
```

---

### Task 1: Pure Helpers — `naechsteOffene()` + `relativGesehen()`

**Files:**
- Modify: `lib/features/aufgaben/domain/aufgaben_gruppierung.dart` (ans Ende)
- Create: `lib/core/util/relativ_datum.dart`
- Test: `test/features/aufgaben/gruppierung_test.dart` (ergänzen), `test/core/relativ_datum_test.dart` (neu)

- [ ] **Step 1: Failing Tests schreiben**

In `test/features/aufgaben/gruppierung_test.dart` ergänzen (Helper `_a` existiert dort):

```dart
  test('naechsteOffene: sortiert aufsteigend (überfällige automatisch zuerst), max n, nur offene', () {
    final heute = DateTime(2026, 7, 19);
    final res = naechsteOffene([
      _a('c', DateTime(2026, 8, 1)),
      _a('u', DateTime(2026, 7, 10)),
      _a('e', DateTime(2026, 7, 1), status: 'erledigt'),
      _a('x', DateTime(2026, 7, 2), status: 'uebersprungen'),
      _a('b', DateTime(2026, 7, 25)),
      _a('d', DateTime(2026, 9, 1)),
    ], heute, 3);
    expect(res.map((x) => x.id).toList(), ['u', 'b', 'c']);
  });
```

Neu `test/core/relativ_datum_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:bienen_app/core/util/relativ_datum.dart';

void main() {
  final heute = DateTime(2026, 7, 19);
  test('relativGesehen: heute/gestern/vor N Tagen/noch nie', () {
    expect(relativGesehen(DateTime(2026, 7, 19, 23), heute), 'heute');
    expect(relativGesehen(DateTime(2026, 7, 18), heute), 'gestern');
    expect(relativGesehen(DateTime(2026, 7, 12), heute), 'vor 7 Tagen');
    expect(relativGesehen(null, heute), 'noch nie');
  });
  test('relativGesehen: Zukunftsdatum (Uhr verstellt) fällt auf heute zurück', () {
    expect(relativGesehen(DateTime(2026, 7, 25), heute), 'heute');
  });
}
```

- [ ] **Step 2: Tests laufen lassen — müssen scheitern**

Run: `flutter test test/features/aufgaben/gruppierung_test.dart test/core/relativ_datum_test.dart`
Expected: FAIL (`naechsteOffene`/Datei fehlen)

- [ ] **Step 3: Implementieren**

Ans Ende von `aufgaben_gruppierung.dart`:

```dart
/// Die nächsten [n] OFFENEN Aufgaben, aufsteigend nach faellig_am —
/// überfällige stehen damit automatisch zuerst. Fürs Cockpit („Heute & demnächst").
List<Aufgabe> naechsteOffene(List<Aufgabe> alle, DateTime stichtag, int n) {
  final offen = alle.where((a) => a.status == 'offen').toList()
    ..sort((a, b) => a.faelligAm.compareTo(b.faelligAm));
  return offen.take(n).toList();
}
```

Neu `lib/core/util/relativ_datum.dart`:

```dart
/// Relative Tages-Angabe fürs Cockpit („gesehen: heute/gestern/vor N Tagen").
/// DST-sicher via UTC-Tagesdifferenz (Gotcha 14). Zukunftsdaten → 'heute'.
String relativGesehen(DateTime? datum, DateTime stichtag) {
  if (datum == null) return 'noch nie';
  final diff = DateTime.utc(stichtag.year, stichtag.month, stichtag.day)
      .difference(DateTime.utc(datum.year, datum.month, datum.day))
      .inDays;
  if (diff <= 0) return 'heute';
  if (diff == 1) return 'gestern';
  return 'vor $diff Tagen';
}
```

- [ ] **Step 4: Tests laufen lassen — müssen grün sein**

Run: `flutter test test/features/aufgaben/gruppierung_test.dart test/core/relativ_datum_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/features/aufgaben/domain/aufgaben_gruppierung.dart lib/core/util/relativ_datum.dart test/features/aufgaben/gruppierung_test.dart test/core/relativ_datum_test.dart
git commit -m "feat(cockpit): pure Helpers naechsteOffene + relativGesehen"
```

---

### Task 2: Meilensteine-Konstante

**Files:**
- Create: `lib/features/projekt/domain/meilensteine.dart`
- Test: `test/features/projekt/meilensteine_test.dart`

- [ ] **Step 1: Failing Test schreiben**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:bienen_app/features/projekt/domain/meilensteine.dart';

void main() {
  test('genau ein Meilenstein ist der nächste Schritt', () {
    expect(kProjektMeilensteine.where((m) => m.status == MeilensteinStatus.naechster).length, 1);
  });
  test('Reihenfolge: erst erledigt, dann nächster, dann offen (keine Rücksprünge)', () {
    var phase = 0; // 0=erledigt, 1=naechster, 2=offen
    for (final m in kProjektMeilensteine) {
      final p = switch (m.status) {
        MeilensteinStatus.erledigt => 0,
        MeilensteinStatus.naechster => 1,
        MeilensteinStatus.offen => 2,
      };
      expect(p >= phase, isTrue, reason: m.titel);
      phase = p;
    }
  });
}
```

- [ ] **Step 2: Test laufen lassen — muss scheitern**

Run: `flutter test test/features/projekt/meilensteine_test.dart`
Expected: FAIL (Datei fehlt)

- [ ] **Step 3: Implementieren**

```dart
/// Projekt-Meilensteine (Mandant-1-Aufbau-Doku, statisch — gepflegt beim
/// Arbeitsschluss; bewusste Ausnahme von der No-Hardcode-Regel, siehe Spec §3).
enum MeilensteinStatus { erledigt, naechster, offen }

class Meilenstein {
  final String titel;
  final String wann;
  final MeilensteinStatus status;
  const Meilenstein(this.titel, this.wann, this.status);
}

const kProjektMeilensteine = <Meilenstein>[
  Meilenstein('Planung & Recherche', '2025/26', MeilensteinStatus.erledigt),
  Meilenstein('Bienenstand gebaut', 'Jul 26', MeilensteinStatus.erledigt),
  Meilenstein('Erstausstattung gekauft', 'Jul 26', MeilensteinStatus.erledigt),
  Meilenstein('Volk 1 übernommen', '19.07.26', MeilensteinStatus.erledigt),
  Meilenstein('HiveWatch-Waage live', '~Aug 26', MeilensteinStatus.naechster),
  Meilenstein('Einwinterung Volk 1', 'Herbst 26', MeilensteinStatus.offen),
  Meilenstein('Volk 2 · 1. Honigernte', '2027', MeilensteinStatus.offen),
  Meilenstein('4 Völker → max 8', '2028–30', MeilensteinStatus.offen),
];

/// Status-Zeile für die Projekt-Kopfkarte.
const kBetriebLaeuftSeit = 'Betrieb läuft seit 19.07.2026';
```

- [ ] **Step 4: Test laufen lassen — muss grün sein**

Run: `flutter test test/features/projekt/meilensteine_test.dart`
Expected: PASS (2 Tests)

- [ ] **Step 5: Commit**

```bash
git add lib/features/projekt/domain/meilensteine.dart test/features/projekt/meilensteine_test.dart
git commit -m "feat(projekt): Meilenstein-Konstante (aktualisierter Projektfortschritt)"
```

---

### Task 3: Cockpit-Widgets + dashboard_page-Umbau

**Files:**
- Create: `lib/features/dashboard/widgets/warnband.dart`, `heute_karte.dart`, `voelker_karte.dart`, `waage_kachel.dart`
- Rewrite: `lib/features/dashboard/pages/dashboard_page.dart`

- [ ] **Step 1: `warnband.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:bienen_app/features/aufgaben/presentation/providers/aufgaben_provider.dart';
import 'package:bienen_app/features/gesundheit/presentation/providers/gesundheit_provider.dart';
import 'package:bienen_app/features/voelker/presentation/providers/voelker_provider.dart';

/// Rotes Warnband je Befund: überfällige Aufgaben + aktive Meldepflicht-Ereignisse.
/// Kein Befund → rendert nichts.
class Warnband extends ConsumerWidget {
  const Warnband({super.key});

  Widget _band(BuildContext context, {required IconData icon, required String text, required VoidCallback onTap}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(10),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            // WICHTIG: kein borderRadius hier — nicht-uniformer Border (nur left)
            // + borderRadius wirft einen Flutter-Assert; das Clipping macht das Material.
            decoration: BoxDecoration(
              border: Border(left: BorderSide(color: Colors.red.shade700, width: 4)),
            ),
            child: Row(children: [
              Icon(icon, size: 18, color: Colors.red.shade700),
              const SizedBox(width: 8),
              Expanded(
                child: Text(text,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.red.shade900)),
              ),
              Icon(Icons.chevron_right, size: 18, color: Colors.red.shade700),
            ]),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final baender = <Widget>[];
    final stats = ref.watch(offeneAufgabenStatsProvider);
    if (stats.ueberfaellig > 0) {
      baender.add(_band(context,
          icon: Icons.warning_amber,
          text: stats.ueberfaellig == 1 ? '1 Aufgabe überfällig' : '${stats.ueberfaellig} Aufgaben überfällig',
          onTap: () => context.go('/aufgaben')));
    }
    for (final volk in ref.watch(aktiveVoelkerProvider)) {
      final melde = ref.watch(aktiveMeldepflichtProvider(volk.id));
      if (melde.isNotEmpty) {
        baender.add(_band(context,
            icon: Icons.report,
            text: 'Meldepflicht aktiv: ${volk.name}',
            onTap: () => context.go('/voelker/${volk.id}')));
      }
    }
    if (baender.isEmpty) return const SizedBox.shrink();
    return Column(children: baender);
  }
}
```

- [ ] **Step 2: `heute_karte.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:bienen_app/core/theme/app_theme.dart';
import 'package:bienen_app/features/aufgaben/domain/aufgabe.dart';
import 'package:bienen_app/features/aufgaben/domain/aufgaben_gruppierung.dart';
import 'package:bienen_app/features/aufgaben/presentation/providers/aufgaben_provider.dart';
import 'package:bienen_app/features/auth/presentation/auth_providers.dart';
import 'package:bienen_app/features/voelker/presentation/providers/voelker_provider.dart';

/// Cockpit-Karte „Heute & demnächst": die nächsten 3 offenen Aufgaben, direkt abhakbar.
class HeuteKarte extends ConsumerWidget {
  const HeuteKarte({super.key});

  Future<void> _abhaken(BuildContext context, WidgetRef ref, Aufgabe a) async {
    final notifier = ref.read(aufgabenListProvider.notifier);
    try {
      await notifier.abhaken(a.id);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('„${a.titel}" erledigt'),
        action: SnackBarAction(
          label: 'Rückgängig',
          onPressed: () async {
            try {
              await notifier.abhaken(a.id, erledigt: false);
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fehler: $e')));
              }
            }
          },
        ),
      ));
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fehler: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alle = ref.watch(aufgabenListProvider).valueOrNull ?? const <Aufgabe>[];
    final heute = DateTime.now();
    final h = DateTime(heute.year, heute.month, heute.day);
    final naechste = naechsteOffene(alle, heute, 3);
    final vorschlaege = ref.watch(vorschlaegeProvider).length;
    final darfSchreiben = ref.watch(darfSchreibenProvider);
    final voelker = ref.watch(voelkerListProvider).valueOrNull ?? const [];

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
                  child: Text('Heute & demnächst', style: TextStyle(fontWeight: FontWeight.bold))),
              TextButton(onPressed: () => context.go('/aufgaben'), child: const Text('alle →')),
            ]),
            if (naechste.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('Keine offenen Aufgaben. 🐝', style: TextStyle(color: AppColors.brown300)),
              ),
            for (final a in naechste)
              Row(children: [
                if (darfSchreiben)
                  Checkbox(value: false, onChanged: (_) => _abhaken(context, ref, a))
                else
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: Icon(Icons.radio_button_unchecked, size: 18, color: AppColors.brown300),
                  ),
                Expanded(child: Text(a.titel, style: const TextStyle(fontSize: 14), overflow: TextOverflow.ellipsis)),
                if (a.volkId != null) ...[
                  for (final v in voelker)
                    if (v.id == a.volkId)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Text('🐝 ${v.name}',
                            style: const TextStyle(fontSize: 11, color: AppColors.honeyDark)),
                      ),
                ],
                Text(DateFormat('dd.MM.').format(a.faelligAm),
                    style: TextStyle(
                        fontSize: 12,
                        color: a.faelligAm.isBefore(h) ? Colors.red.shade700 : AppColors.brown300,
                        fontWeight: a.faelligAm.isBefore(h) ? FontWeight.w600 : FontWeight.w400)),
              ]),
            if (vorschlaege > 0)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: InkWell(
                  onTap: () => context.go('/aufgaben'),
                  child: Text('✨ $vorschlaege Saisonvorschläge warten',
                      style: const TextStyle(fontSize: 12, color: AppColors.brown300)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 3: `voelker_karte.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:bienen_app/core/theme/app_theme.dart';
import 'package:bienen_app/core/util/relativ_datum.dart';
import 'package:bienen_app/features/durchsicht/presentation/providers/durchsicht_provider.dart';
import 'package:bienen_app/features/gesundheit/presentation/providers/gesundheit_provider.dart';
import 'package:bienen_app/features/voelker/presentation/providers/voelker_provider.dart';

/// Cockpit-Karte „Völker": je aktives Volk Ampel + Name + „gesehen: <relativ>".
class VoelkerKarte extends ConsumerWidget {
  const VoelkerKarte({super.key});

  static const _ampel = {
    'unauffaellig': Color(0xFF5CB85C),
    'beobachtung': Color(0xFFF0AD4E),
    'krank': Color(0xFFD9534F),
    'sperre': Color(0xFFD9534F),
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final voelker = ref.watch(aktiveVoelkerProvider);
    final letzte = ref.watch(letzteDurchsichtMapProvider);
    final heute = DateTime.now();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.hive, size: 20, color: AppColors.honeyDark),
              const SizedBox(width: 8),
              const Expanded(child: Text('Völker', style: TextStyle(fontWeight: FontWeight.bold))),
              TextButton(onPressed: () => context.go('/voelker'), child: const Text('alle →')),
            ]),
            if (voelker.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: InkWell(
                  onTap: () => context.go('/voelker'),
                  child: const Text('Noch kein Volk erfasst — jetzt anlegen →',
                      style: TextStyle(color: AppColors.brown300)),
                ),
              ),
            for (final v in voelker)
              InkWell(
                onTap: () => context.go('/voelker/${v.id}'),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(children: [
                    Container(
                      width: 10, height: 10,
                      decoration: BoxDecoration(
                          color: _ampel[v.gesundheitsstatus] ?? AppColors.brown300,
                          shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                        child: Text(v.name,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500))),
                    if (ref.watch(aktiveMeldepflichtProvider(v.id)).isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Icon(Icons.report, size: 16, color: Colors.red.shade700),
                      ),
                    Text('gesehen: ${relativGesehen(letzte[v.id]?.durchgefuehrtAm, heute)}',
                        style: const TextStyle(fontSize: 12, color: AppColors.brown300)),
                  ]),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: `waage_kachel.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:bienen_app/core/theme/app_theme.dart';

/// Platzhalter bis Modul 4.9 — bewusst OHNE Demo-Daten. Andockpunkt für die HiveWatch-Waage.
class WaageKachel extends StatelessWidget {
  const WaageKachel({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: () => context.go('/monitoring'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            const Icon(Icons.monitor_weight_outlined, size: 28, color: AppColors.brown300),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
                Text('Waage & Sensorik', style: TextStyle(fontWeight: FontWeight.bold)),
                Text('HiveWatch-Stockwaage folgt — danach hier: Gewicht 24 h, Brutraumtemperatur, Alarme.',
                    style: TextStyle(fontSize: 12, color: AppColors.brown300)),
              ]),
            ),
            const Icon(Icons.chevron_right, color: AppColors.brown300),
          ]),
        ),
      ),
    );
  }
}
```

- [ ] **Step 5: `dashboard_page.dart` KOMPLETT ersetzen**

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:bienen_app/core/theme/app_theme.dart';
import 'package:bienen_app/features/dashboard/widgets/heute_karte.dart';
import 'package:bienen_app/features/dashboard/widgets/voelker_karte.dart';
import 'package:bienen_app/features/dashboard/widgets/waage_kachel.dart';
import 'package:bienen_app/features/dashboard/widgets/warnband.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  static const _wochentage = ['Montag', 'Dienstag', 'Mittwoch', 'Donnerstag', 'Freitag', 'Samstag', 'Sonntag'];

  @override
  Widget build(BuildContext context) {
    final jetzt = DateTime.now();
    final datum = '${_wochentage[jetzt.weekday - 1]}, ${jetzt.day}.${jetzt.month}.${jetzt.year}';
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cockpit'),
        actions: [
          IconButton(
            tooltip: 'Konto & Team',
            icon: const Icon(Icons.account_circle_outlined),
            onPressed: () => context.go('/konto'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 12),
              child: Text(datum, style: const TextStyle(fontSize: 13, color: AppColors.brown300)),
            ),
            const Warnband(),
            const HeuteKarte(),
            const SizedBox(height: 12),
            const VoelkerKarte(),
            const SizedBox(height: 12),
            const WaageKachel(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
```

(Damit entfallen `_buildHeader`, `_buildAufgabenKachel`, `_buildProjectPhases`, `_buildQuickLinks`, `_buildKeyFacts`, `_Phase`, `_QuickLink` ersatzlos — die Aufgaben-Zahl lebt jetzt im Warnband/HeuteKarte, Projekt-Teile ziehen in Task 4 um.)

- [ ] **Step 6: Analyse**

Run: `flutter analyze lib/features/dashboard lib/core/util`
Expected: No issues found

- [ ] **Step 7: Commit**

```bash
git add lib/features/dashboard lib/core/util
git commit -m "feat(cockpit): Dashboard wird Betriebs-Cockpit (Warnband, Heute, Voelker, Waage)"
```

---

### Task 4: Projekt-Seite + Router + Nav (4 Tabs) + Mehr löschen

**Files:**
- Create: `lib/features/projekt/pages/projekt_page.dart`
- Modify: `lib/core/router/app_router.dart`
- Modify: `lib/shared/widgets/app_shell.dart`
- Delete: `lib/features/mehr/` (ganzer Ordner)

- [ ] **Step 1: `projekt_page.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:bienen_app/core/theme/app_theme.dart';
import 'package:bienen_app/features/projekt/domain/meilensteine.dart';

class ProjektPage extends StatelessWidget {
  const ProjektPage({super.key});

  static const _bereiche = [
    (icon: Icons.shopping_cart, titel: 'Material & Lager', sub: 'Bestand · Einkäufe', route: '/material'),
    (icon: Icons.construction, titel: 'Bau', sub: 'Bienenstand · Honigraum', route: '/construction'),
    (icon: Icons.menu_book, titel: 'Recherche', sub: 'Fachthemen', route: '/recherche'),
    (icon: Icons.checklist, titel: 'Entscheidungen', sub: 'Chronik', route: '/entscheidungen'),
    (icon: Icons.monitor_weight, titel: 'Monitoring', sub: 'Waagen-Verwaltung', route: '/monitoring'),
    (icon: Icons.account_circle, titel: 'Konto & Team', sub: 'Mitglieder · Einladungen', route: '/konto'),
  ];

  static const _facts = [
    (icon: Icons.grid_view, text: 'Dadant Blatt 10 · Holz'),
    (icon: Icons.hive, text: 'Buckfast (T. Hassler)'),
    (icon: Icons.eco, text: 'Ziel: Bio-Honig'),
    (icon: Icons.flag, text: 'max 8 Völker bis 2030'),
    (icon: Icons.group, text: 'Daniel & Lorena'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Projekt')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(children: [
                  const Text('🐝', style: TextStyle(fontSize: 32)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Projekt Imkerei Arosa',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.brown800)),
                      Text(kBetriebLaeuftSeit,
                          style: TextStyle(fontSize: 12.5, color: Colors.green.shade700, fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ]),
              ),
            ),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 2.1,
              children: [
                for (final b in _bereiche)
                  Card(
                    margin: EdgeInsets.zero,
                    child: InkWell(
                      onTap: () => context.go(b.route),
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Row(children: [
                          Icon(b.icon, size: 24, color: AppColors.honey),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(b.titel,
                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                      overflow: TextOverflow.ellipsis),
                                  Text(b.sub,
                                      style: const TextStyle(fontSize: 10.5, color: AppColors.brown300),
                                      overflow: TextOverflow.ellipsis),
                                ]),
                          ),
                        ]),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Projektfortschritt', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  for (final m in kProjektMeilensteine)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(children: [
                        Container(
                          width: 22, height: 22, alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: m.status == MeilensteinStatus.erledigt ? AppColors.green600 : null,
                            border: m.status == MeilensteinStatus.erledigt
                                ? null
                                : Border.all(
                                    color: m.status == MeilensteinStatus.naechster
                                        ? AppColors.honeyDark
                                        : AppColors.brown100,
                                    width: 2),
                          ),
                          child: m.status == MeilensteinStatus.erledigt
                              ? const Icon(Icons.check, size: 14, color: Colors.white)
                              : null,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(m.titel,
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: m.status == MeilensteinStatus.naechster
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                                color: m.status == MeilensteinStatus.offen
                                    ? AppColors.brown300
                                    : AppColors.brown800,
                              )),
                        ),
                        Text(m.wann, style: const TextStyle(fontSize: 11, color: AppColors.brown300)),
                      ]),
                    ),
                ]),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final f in _facts)
                  Chip(
                    avatar: Icon(f.icon, size: 16, color: AppColors.brown600),
                    label: Text(f.text, style: const TextStyle(fontSize: 12)),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Router anpassen (`app_router.dart`)**

- Import `mehr_page.dart` LÖSCHEN; Import ergänzen:
```dart
import 'package:bienen_app/features/projekt/pages/projekt_page.dart';
```
- Den Block `GoRoute(path: '/mehr', builder: (context, state) => const MehrPage()),` ersetzen durch:
```dart
        GoRoute(path: '/projekt', builder: (context, state) => const ProjektPage()),
        GoRoute(path: '/mehr', redirect: (context, state) => '/projekt'),
```

- [ ] **Step 3: `app_shell.dart` — Nav auf 4 Tabs**

`_selectedIndex` ersetzen:
```dart
  int _selectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    if (location.startsWith('/voelker')) return 1;
    if (location.startsWith('/aufgaben')) return 2;
    if (location.startsWith('/projekt') ||
        location.startsWith('/material') ||
        location.startsWith('/construction') ||
        location.startsWith('/monitoring') ||
        location.startsWith('/recherche') ||
        location.startsWith('/entscheidungen') ||
        location.startsWith('/konto') ||
        location.startsWith('/mehr')) {
      return 3;
    }
    return 0;
  }
```
`_onDestinationSelected` ersetzen:
```dart
  void _onDestinationSelected(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go('/dashboard');
      case 1:
        context.go('/voelker');
      case 2:
        context.go('/aufgaben');
      case 3:
        context.go('/projekt');
    }
  }
```
Beide Destination-Listen (Rail + BottomBar) auf genau diese 4 kürzen — Rail:
```dart
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home),
                  label: Text('Cockpit'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.hive_outlined),
                  selectedIcon: Icon(Icons.hive),
                  label: Text('Voelker'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.task_alt_outlined),
                  selectedIcon: Icon(Icons.task_alt),
                  label: Text('Aufgaben'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.folder_open_outlined),
                  selectedIcon: Icon(Icons.folder_open),
                  label: Text('Projekt'),
                ),
              ],
```
BottomBar (die `destinations:`-Liste der `NavigationBar`) exakt so ersetzen:
```dart
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Cockpit',
          ),
          NavigationDestination(
            icon: Icon(Icons.hive_outlined),
            selectedIcon: Icon(Icons.hive),
            label: 'Voelker',
          ),
          NavigationDestination(
            icon: Icon(Icons.task_alt_outlined),
            selectedIcon: Icon(Icons.task_alt),
            label: 'Aufgaben',
          ),
          NavigationDestination(
            icon: Icon(Icons.folder_open_outlined),
            selectedIcon: Icon(Icons.folder_open),
            label: 'Projekt',
          ),
        ],
```

- [ ] **Step 4: `lib/features/mehr/` löschen + Restreferenzen prüfen**

Run: Ordner `lib/features/mehr` löschen, dann `grep -rn "MehrPage\|/mehr" lib/` → einzige Treffer: Redirect in `app_router.dart` + `_selectedIndex` in `app_shell.dart`.

- [ ] **Step 5: Voll-Check**

Run: `flutter analyze && flutter test`
Expected: No issues · alle Tests PASS

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "feat(projekt): Projekt-Sammelseite, Nav auf 4 Tabs, /mehr-Redirect, MehrPage entfernt"
```

---

### Task 5: Abschluss — Version, Merge, Deploy

- [ ] **Step 1:** `pubspec.yaml`: `version: 1.15.0+33`
- [ ] **Step 2:** Run `flutter analyze && flutter test` → No issues · alle PASS
- [ ] **Step 3:**
```bash
git add pubspec.yaml
git commit -m "chore: Version 1.15.0+33 (Cockpit & IA-Umbau)"
git checkout master
git merge --no-ff feat/cockpit-ia -m "feat: Cockpit & IA-Umbau (v1.15.0)

4 Betriebs-Tabs (Cockpit/Voelker/Aufgaben/Projekt), Dashboard wird
Betriebszentrale, Projekt-Sammelseite mit aktualisiertem Fortschritt.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
git push origin master
```
- [ ] **Step 4:** Run `bash deploy.sh` → „✓ Live bestaetigt" (v1.15.0)
- [ ] **Step 5:** `curl -s https://danielproyer.github.io/bienen-app/version.json` → `"version":"1.15.0"`
