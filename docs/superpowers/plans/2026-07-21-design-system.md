# App-Design-Überarbeitung (Design-System + Kern-Screens) — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:subagent-driven-development. Steps use `- [ ]` checkboxes. Ultracode an → je Task adversariale/Spec-Verifikation.

**Goal:** Ein konsistentes, ruhiges, einhändig bedienbares Design: zentrale Tokens + ausgebautes Theme + ein Baukasten wiederverwendbarer Widgets, angewandt auf die Kern-Screens (Cockpit, Völker, Volk-Detail, Durchsicht-Wizard, Nav).

**Architecture:** Reine Präsentationsschicht — keine Änderung an Providern, Gateways, Routen, DB. Neue `BeeTokens` (Farb-Rollen/Abstände/Schrift/Größen) + `BeeSignal`; Theme liest Tokens; Bausteine in `lib/shared/widgets/` lesen NUR Tokens; Screens tauschen handgesetzte Konstrukte gegen Bausteine. Richtung **A** (warm, beruhigt).

**Tech Stack:** Flutter Web, Material 3, Riverpod, go_router. Spec: `docs/superpowers/specs/2026-07-21-design-system-ueberarbeitung-design.md`.

---

## Dateistruktur
**Neu:** `lib/core/theme/app_tokens.dart` · `lib/shared/widgets/{app_button,app_card,section_header,status_pill,app_list_tile,stat_tile,form_scaffold,empty_state,confirm_sheet}.dart` · Tests `test/design/{tokens_test,bausteine_test}.dart` · `assets/fonts/Inter-*.ttf`
**Geändert:** `lib/core/theme/app_theme.dart` · `lib/shared/widgets/app_shell.dart` · `lib/features/dashboard/pages/dashboard_page.dart` + `widgets/{warnband,heute_karte,voelker_karte,waage_kachel}.dart` · `lib/features/voelker/presentation/pages/{voelker_page,volk_detail_page}.dart` · `lib/features/durchsicht/presentation/pages/durchsicht_wizard_page.dart` + `widgets/waben_schritt.dart` · `pubspec.yaml`

**Migrations-Prinzip:** Bestehende `AppColors` bleiben (un-migrierte Screens nutzen sie weiter). Bausteine/Kern-Screens nutzen ausschließlich `BeeTokens`. Keine Verhaltens-/Provider-/Routen-Änderung — nur Darstellung.

---

## Task 1: Design-Tokens `BeeTokens` + `BeeSignal`

**Files:** Create `lib/core/theme/app_tokens.dart` · Test `test/design/tokens_test.dart`

- [ ] **Step 1: Failing test**
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bienen_app/core/theme/app_tokens.dart';
void main() {
  test('Signal-Rollen liefern Flächen/Text-Paar', () {
    expect(BeeSignal.warnung.flaeche, const Color(0xFFFAEEDA));
    expect(BeeSignal.warnung.text, const Color(0xFF854F0B));
    expect(BeeSignal.erfolg.text, const Color(0xFF3B6D11));
    expect(BeeSignal.gefahr.text, const Color(0xFFA32D2D));
    expect(BeeSignal.neutral.flaeche, BeeTokens.karte);
  });
  test('Abstände auf 4/8-Raster', () {
    expect([BeeTokens.xs, BeeTokens.sm, BeeTokens.md, BeeTokens.lg, BeeTokens.xl],
        [4.0, 8.0, 12.0, 16.0, 24.0]);
  });
}
```
- [ ] **Step 2:** `cd /d/Projekte/Bienen/bienen_app && flutter test test/design/tokens_test.dart` → FAIL.
- [ ] **Step 3: Implement** `lib/core/theme/app_tokens.dart`:
```dart
import 'package:flutter/material.dart';

/// Zentrale Design-Tokens (Richtung A: warm, beruhigt). Bausteine/Screens lesen
/// NUR Tokens, nie rohe Hex-/Pixelwerte. Die alte AppColors-Palette bleibt für
/// noch nicht migrierte Screens bestehen.
class BeeTokens {
  BeeTokens._();

  // ── Farb-Rollen: Flächen ──
  static const oberflaeche = Color(0xFFFAF7F2); // Seiten-Hintergrund
  static const karte = Colors.white;

  // ── Text ──
  static const textPrimaer = Color(0xFF4E342E);
  static const textSekundaer = Color(0xFF8B5E0B);
  static const textGedaempft = Color(0xFFA1887F);

  // ── Rand ──
  static const rand = Color(0xFFEAE3D6);
  static const randStark = Color(0xFFD7CCC8);
  static const chevron = Color(0xFFC9BCA8);

  // ── Akzent ──
  static const honig = Color(0xFFD4920B);
  static const honigTint = Color(0xFFFAEEDA);

  // ── Signal-Rollen (Fläche + Text) ──
  static const erfolgFlaeche = Color(0xFFEAF3DE);
  static const erfolgText = Color(0xFF3B6D11);
  static const warnungFlaeche = Color(0xFFFAEEDA);
  static const warnungText = Color(0xFF854F0B);
  static const gefahrFlaeche = Color(0xFFFCEBEB);
  static const gefahrText = Color(0xFFA32D2D);
  static const infoFlaeche = Color(0xFFE6F1FB);
  static const infoText = Color(0xFF185FA5);

  // ── Abstände (4/8-Raster) ──
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;

  // ── Radien ──
  static const rKarte = 12.0;
  static const rControl = 14.0;
  static const rPille = 20.0;

  // ── Tap-Ziele ──
  static const tapMin = 48.0;
  static const stepper = 52.0;

  // ── Schrift-Skala (2 Gewichte) ──
  static const titel = TextStyle(fontSize: 20, fontWeight: FontWeight.w500, color: textPrimaer, height: 1.3);
  static const abschnitt = TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: textPrimaer, height: 1.35);
  static const text = TextStyle(fontSize: 15, fontWeight: FontWeight.w400, color: textPrimaer, height: 1.45);
  static const label = TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: textSekundaer, height: 1.3);
  static const gedaempft = TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: textGedaempft, height: 1.3);
}

enum BeeSignal { erfolg, warnung, gefahr, info, neutral }

extension BeeSignalFarben on BeeSignal {
  Color get flaeche => switch (this) {
        BeeSignal.erfolg => BeeTokens.erfolgFlaeche,
        BeeSignal.warnung => BeeTokens.warnungFlaeche,
        BeeSignal.gefahr => BeeTokens.gefahrFlaeche,
        BeeSignal.info => BeeTokens.infoFlaeche,
        BeeSignal.neutral => BeeTokens.karte,
      };
  Color get text => switch (this) {
        BeeSignal.erfolg => BeeTokens.erfolgText,
        BeeSignal.warnung => BeeTokens.warnungText,
        BeeSignal.gefahr => BeeTokens.gefahrText,
        BeeSignal.info => BeeTokens.infoText,
        BeeSignal.neutral => BeeTokens.textSekundaer,
      };
}
```
- [ ] **Step 4:** Test → PASS.
- [ ] **Step 5: Commit** `feat(design): Design-Tokens BeeTokens + BeeSignal`

---

## Task 2: Theme auf Tokens umbauen

**Files:** Modify `lib/core/theme/app_theme.dart`

> Kein Test (Theme). `AppColors` bleibt im File. `GoogleFonts.interTextTheme()` bleibt vorerst (Task 11 bündelt Inter lokal).

- [ ] **Step 1: Implement** — ersetze den Body von `AppTheme.light` (Import `app_tokens.dart` ergänzen), Rest der Datei/`AppColors` unverändert:
```dart
static ThemeData get light {
  final textTheme = GoogleFonts.interTextTheme();
  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: BeeTokens.honig, brightness: Brightness.light, surface: BeeTokens.karte),
    scaffoldBackgroundColor: BeeTokens.oberflaeche,
    textTheme: textTheme,
    appBarTheme: AppBarTheme(
      backgroundColor: BeeTokens.karte,
      foregroundColor: BeeTokens.textPrimaer,
      elevation: 0,
      scrolledUnderElevation: 0,
      shape: const Border(bottom: BorderSide(color: BeeTokens.honig, width: 2)),
      titleTextStyle: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w500, color: BeeTokens.textPrimaer),
    ),
    cardTheme: CardThemeData(
      color: BeeTokens.karte, elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(BeeTokens.rKarte),
        side: const BorderSide(color: BeeTokens.rand, width: 0.5)),
    ),
    filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(
      minimumSize: const Size(0, BeeTokens.tapMin), backgroundColor: BeeTokens.honig, foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(BeeTokens.rControl)))),
    outlinedButtonTheme: OutlinedButtonThemeData(style: OutlinedButton.styleFrom(
      minimumSize: const Size(0, BeeTokens.tapMin), foregroundColor: BeeTokens.textPrimaer,
      side: const BorderSide(color: BeeTokens.randStark),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(BeeTokens.rControl)))),
    textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(
      minimumSize: const Size(0, BeeTokens.tapMin), foregroundColor: BeeTokens.honig)),
    chipTheme: ChipThemeData(
      backgroundColor: BeeTokens.karte, selectedColor: BeeTokens.honigTint,
      side: const BorderSide(color: BeeTokens.rand, width: 0.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(BeeTokens.rControl))),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: BeeTokens.karte,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(BeeTokens.rKarte)))),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: BeeTokens.karte, indicatorColor: BeeTokens.honigTint,
      elevation: 0, height: 64,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(
        color: s.contains(WidgetState.selected) ? BeeTokens.honig : BeeTokens.textGedaempft))),
    inputDecorationTheme: InputDecorationTheme(
      filled: true, fillColor: BeeTokens.karte,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(BeeTokens.rControl),
        borderSide: const BorderSide(color: BeeTokens.rand)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(BeeTokens.rControl),
        borderSide: const BorderSide(color: BeeTokens.rand)),
    ),
    navigationRailTheme: const NavigationRailThemeData(
      backgroundColor: AppColors.brown800,
      selectedIconTheme: IconThemeData(color: AppColors.amber400),
      unselectedIconTheme: IconThemeData(color: Colors.white70)),
  );
}
```
- [ ] **Step 2:** `flutter analyze lib/core/theme` → 0.
- [ ] **Step 3: Commit** `feat(design): Theme auf BeeTokens (helle Kopfleiste, Honig-Akzent, 48px-Ziele)`

---

## Task 3: `AppButton` + `AppCard`

**Files:** Create `lib/shared/widgets/app_button.dart`, `lib/shared/widgets/app_card.dart` · Test `test/design/bausteine_test.dart`

- [ ] **Step 1: Failing test** (Datei anlegen; weitere Bausteine hängen später an)
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bienen_app/shared/widgets/app_button.dart';
import 'package:bienen_app/shared/widgets/app_card.dart';

Widget _host(Widget c) => MaterialApp(home: Scaffold(body: c));
void main() {
  testWidgets('AppButton zeigt Label und ruft onPressed', (t) async {
    var tapped = false;
    await t.pumpWidget(_host(AppButton(label: 'Speichern', onPressed: () => tapped = true)));
    expect(find.text('Speichern'), findsOneWidget);
    await t.tap(find.text('Speichern'));
    expect(tapped, isTrue);
  });
  testWidgets('AppButton busy sperrt onPressed', (t) async {
    var tapped = false;
    await t.pumpWidget(_host(AppButton(label: 'X', busy: true, onPressed: () => tapped = true)));
    await t.tap(find.byType(AppButton));
    expect(tapped, isFalse);
  });
  testWidgets('AppCard rendert Kind', (t) async {
    await t.pumpWidget(_host(const AppCard(child: Text('Inhalt'))));
    expect(find.text('Inhalt'), findsOneWidget);
  });
}
```
- [ ] **Step 2:** `flutter test test/design/bausteine_test.dart` → FAIL.
- [ ] **Step 3: Implement** `app_button.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:bienen_app/core/theme/app_tokens.dart';

enum AppButtonKind { primaer, sekundaer, text, gefahr }

class AppButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final AppButtonKind kind;
  final bool busy;
  final bool full;
  const AppButton({super.key, required this.label, this.icon, this.onPressed,
      this.kind = AppButtonKind.primaer, this.busy = false, this.full = false});

  @override
  Widget build(BuildContext context) {
    final Widget child = busy
        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
        : (icon == null
            ? Text(label)
            : Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 20), const SizedBox(width: BeeTokens.sm), Text(label)]));
    final onTap = busy ? null : onPressed;
    final Widget btn = switch (kind) {
      AppButtonKind.primaer => FilledButton(onPressed: onTap, child: child),
      AppButtonKind.sekundaer => OutlinedButton(onPressed: onTap, child: child),
      AppButtonKind.text => TextButton(onPressed: onTap, child: child),
      AppButtonKind.gefahr => FilledButton(
          onPressed: onTap,
          style: FilledButton.styleFrom(backgroundColor: BeeTokens.gefahrText, foregroundColor: Colors.white),
          child: child),
    };
    return full ? SizedBox(width: double.infinity, child: btn) : btn;
  }
}
```
`app_card.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:bienen_app/core/theme/app_tokens.dart';

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  const AppCard({super.key, required this.child, this.padding = const EdgeInsets.all(BeeTokens.lg), this.onTap});

  @override
  Widget build(BuildContext context) {
    final content = Padding(padding: padding, child: child);
    return Container(
      decoration: BoxDecoration(
        color: BeeTokens.karte,
        borderRadius: BorderRadius.circular(BeeTokens.rKarte),
        border: Border.all(color: BeeTokens.rand, width: 0.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: onTap == null ? content : InkWell(onTap: onTap, child: content),
    );
  }
}
```
- [ ] **Step 4:** Test → PASS. `flutter analyze lib/shared/widgets` → 0.
- [ ] **Step 5: Commit** `feat(design): Baustein AppButton + AppCard`

---

## Task 4: `SectionHeader` + `StatusPill`

**Files:** Create `lib/shared/widgets/section_header.dart`, `lib/shared/widgets/status_pill.dart` · Test: an `bausteine_test.dart` anhängen

- [ ] **Step 1: Failing test** (anhängen)
```dart
// + Imports section_header.dart, status_pill.dart, app_tokens.dart
testWidgets('SectionHeader zeigt Titel + trailing', (t) async {
  await t.pumpWidget(_host(const SectionHeader(titel: 'Heute', trailingText: '3 Aufgaben')));
  expect(find.text('Heute'), findsOneWidget);
  expect(find.text('3 Aufgaben'), findsOneWidget);
});
testWidgets('StatusPill nutzt Signal-Farbe', (t) async {
  await t.pumpWidget(_host(const StatusPill(label: 'überfällig', signal: BeeSignal.gefahr)));
  expect(find.text('überfällig'), findsOneWidget);
});
```
- [ ] **Step 2:** Test → FAIL.
- [ ] **Step 3: Implement** `section_header.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:bienen_app/core/theme/app_tokens.dart';

class SectionHeader extends StatelessWidget {
  final String titel;
  final String? trailingText;
  final Widget? action;
  const SectionHeader({super.key, required this.titel, this.trailingText, this.action});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: BeeTokens.sm),
      child: Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
        Text(titel, style: BeeTokens.label),
        if (trailingText != null) ...[const SizedBox(width: BeeTokens.sm), Text(trailingText!, style: BeeTokens.gedaempft)],
        const Spacer(),
        if (action != null) action!,
      ]),
    );
  }
}
```
`status_pill.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:bienen_app/core/theme/app_tokens.dart';

class StatusPill extends StatelessWidget {
  final String label;
  final BeeSignal signal;
  const StatusPill({super.key, required this.label, this.signal = BeeSignal.neutral});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: BeeTokens.md, vertical: 5),
      decoration: BoxDecoration(color: signal.flaeche, borderRadius: BorderRadius.circular(BeeTokens.rPille)),
      child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: signal.text)),
    );
  }
}
```
- [ ] **Step 4:** Test → PASS. analyze → 0.
- [ ] **Step 5: Commit** `feat(design): Baustein SectionHeader + StatusPill`

---

## Task 5: `AppListTile` + `StatTile`

**Files:** Create `lib/shared/widgets/app_list_tile.dart`, `lib/shared/widgets/stat_tile.dart` · Test anhängen

- [ ] **Step 1: Failing test** (anhängen)
```dart
// + Imports
testWidgets('AppListTile: Titel/Untertitel + Tap', (t) async {
  var tapped = false;
  await t.pumpWidget(_host(AppListTile(titel: 'Volk 1', untertitel: 'heute gesehen', onTap: () => tapped = true)));
  expect(find.text('Volk 1'), findsOneWidget);
  expect(find.text('heute gesehen'), findsOneWidget);
  await t.tap(find.text('Volk 1'));
  expect(tapped, isTrue);
});
testWidgets('StatTile: Label + Wert', (t) async {
  await t.pumpWidget(_host(const StatTile(label: 'Bisher', wert: 'CHF 640')));
  expect(find.text('Bisher'), findsOneWidget);
  expect(find.text('CHF 640'), findsOneWidget);
});
```
- [ ] **Step 2:** Test → FAIL.
- [ ] **Step 3: Implement** `app_list_tile.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:bienen_app/core/theme/app_tokens.dart';

class AppListTile extends StatelessWidget {
  final Widget? leading;
  final Color? statusFarbe;
  final String titel;
  final String? untertitel;
  final Widget? trailing;
  final VoidCallback? onTap;
  const AppListTile({super.key, this.leading, this.statusFarbe, required this.titel,
      this.untertitel, this.trailing, this.onTap});

  @override
  Widget build(BuildContext context) {
    final Widget? lead = leading ??
        (statusFarbe != null
            ? Container(width: 11, height: 11, decoration: BoxDecoration(color: statusFarbe, shape: BoxShape.circle))
            : null);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(BeeTokens.rKarte),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: BeeTokens.tapMin),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: BeeTokens.md, vertical: BeeTokens.md),
          child: Row(children: [
            if (lead != null) ...[lead, const SizedBox(width: BeeTokens.md)],
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(titel, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: BeeTokens.textPrimaer)),
              if (untertitel != null)
                Padding(padding: const EdgeInsets.only(top: 2), child: Text(untertitel!, style: BeeTokens.gedaempft)),
            ])),
            if (trailing != null) trailing! else if (onTap != null) const Icon(Icons.chevron_right, color: BeeTokens.chevron),
          ]),
        ),
      ),
    );
  }
}
```
`stat_tile.dart`:
```dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:bienen_app/core/theme/app_tokens.dart';

class StatTile extends StatelessWidget {
  final String label;
  final String wert;
  const StatTile({super.key, required this.label, required this.wert});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: BeeTokens.md, vertical: BeeTokens.md),
      decoration: BoxDecoration(
        color: BeeTokens.karte,
        borderRadius: BorderRadius.circular(BeeTokens.rKarte),
        border: Border.all(color: BeeTokens.rand, width: 0.5)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Text(label, style: BeeTokens.gedaempft),
        const SizedBox(height: BeeTokens.xs),
        FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(wert,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w500, color: BeeTokens.textPrimaer,
            fontFeatures: [FontFeature.tabularFigures()]))),
      ]),
    );
  }
}
```
- [ ] **Step 4:** Test → PASS. analyze → 0.
- [ ] **Step 5: Commit** `feat(design): Baustein AppListTile + StatTile`

---

## Task 6: `FormScaffold` + `EmptyState` + `ConfirmSheet`

**Files:** Create `lib/shared/widgets/form_scaffold.dart`, `lib/shared/widgets/empty_state.dart`, `lib/shared/widgets/confirm_sheet.dart` · Test anhängen

- [ ] **Step 1: Failing test** (anhängen)
```dart
// + Imports form_scaffold.dart, empty_state.dart
testWidgets('FormScaffold zeigt Titel, Inhalt, Bodenleiste', (t) async {
  await t.pumpWidget(MaterialApp(home: FormScaffold(
    titel: 'Durchsicht',
    child: const Text('Inhalt'),
    bodenleiste: AppButton(label: 'Weiter', onPressed: () {}))));
  expect(find.text('Durchsicht'), findsOneWidget);
  expect(find.text('Inhalt'), findsOneWidget);
  expect(find.text('Weiter'), findsOneWidget);
});
testWidgets('EmptyState zeigt Titel + Text', (t) async {
  await t.pumpWidget(_host(const EmptyState(icon: Icons.inbox, titel: 'Leer', text: 'Nichts da')));
  expect(find.text('Leer'), findsOneWidget);
  expect(find.text('Nichts da'), findsOneWidget);
});
```
- [ ] **Step 2:** Test → FAIL.
- [ ] **Step 3: Implement** `form_scaffold.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:bienen_app/core/theme/app_tokens.dart';

/// Einhand-Gerüst: Titel oben, Inhalt scrollt, Hauptaktion(en) unten angeheftet
/// (Daumen-erreichbar). Sekundäre/zerstörerische Aktionen gehören in [kopfAktionen]
/// (Overflow oben), nie in die Bodenleiste.
class FormScaffold extends StatelessWidget {
  final String titel;
  final String? untertitel;
  final List<Widget> kopfAktionen;
  final Widget child;
  final Widget bodenleiste;
  final bool busy;
  const FormScaffold({super.key, required this.titel, this.untertitel,
      this.kopfAktionen = const [], required this.child, required this.bodenleiste, this.busy = false});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BeeTokens.oberflaeche,
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(titel),
          if (untertitel != null) Text(untertitel!,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: BeeTokens.textGedaempft)),
        ]),
        actions: kopfAktionen,
      ),
      body: Column(children: [
        Expanded(child: AbsorbPointer(absorbing: busy, child: child)),
        SafeArea(top: false, child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(BeeTokens.lg, BeeTokens.sm, BeeTokens.lg, BeeTokens.lg),
          decoration: const BoxDecoration(color: BeeTokens.karte, border: Border(top: BorderSide(color: BeeTokens.rand, width: 0.5))),
          child: bodenleiste,
        )),
      ]),
    );
  }
}
```
`empty_state.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:bienen_app/core/theme/app_tokens.dart';

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String titel;
  final String? text;
  final Widget? aktion;
  const EmptyState({super.key, required this.icon, required this.titel, this.text, this.aktion});

  @override
  Widget build(BuildContext context) {
    return Center(child: Padding(padding: const EdgeInsets.all(BeeTokens.xl), child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 40, color: BeeTokens.textGedaempft),
      const SizedBox(height: BeeTokens.md),
      Text(titel, textAlign: TextAlign.center, style: BeeTokens.abschnitt),
      if (text != null) ...[const SizedBox(height: BeeTokens.sm), Text(text!, textAlign: TextAlign.center, style: BeeTokens.gedaempft)],
      if (aktion != null) ...[const SizedBox(height: BeeTokens.lg), aktion!],
    ])));
  }
}
```
`confirm_sheet.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:bienen_app/core/theme/app_tokens.dart';
import 'package:bienen_app/shared/widgets/app_button.dart';

/// Bestätigung als Bodenblatt (Daumen-erreichbar) statt zentralem Dialog.
Future<bool> confirmSheet(BuildContext context, {required String titel, String? text,
    String bestaetigenLabel = 'Bestätigen', bool gefahr = false}) async {
  final ok = await showModalBottomSheet<bool>(
    context: context,
    builder: (ctx) => SafeArea(child: Padding(padding: const EdgeInsets.all(BeeTokens.lg),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(titel, style: BeeTokens.abschnitt),
        if (text != null) ...[const SizedBox(height: BeeTokens.sm), Text(text!, style: BeeTokens.text)],
        const SizedBox(height: BeeTokens.lg),
        AppButton(label: bestaetigenLabel, kind: gefahr ? AppButtonKind.gefahr : AppButtonKind.primaer, full: true, onPressed: () => Navigator.pop(ctx, true)),
        const SizedBox(height: BeeTokens.sm),
        AppButton(label: 'Abbrechen', kind: AppButtonKind.text, full: true, onPressed: () => Navigator.pop(ctx, false)),
      ]))),
  );
  return ok ?? false;
}
```
- [ ] **Step 4:** Test → PASS. `flutter analyze lib/shared/widgets test/design` → 0.
- [ ] **Step 5: Commit** `feat(design): Baustein FormScaffold + EmptyState + ConfirmSheet`

---

## Task 7: Nav-Shell umbauen

**Files:** Modify `lib/shared/widgets/app_shell.dart`

- [ ] **Step 1: Implement** — im `NavigationBar` (mobil) und `NavigationRail` (breit) das Label `'Voelker'` → `'Völker'` korrigieren (beide Vorkommen). Das mobile `NavigationBar` erbt jetzt Farben/Indicator/Höhe aus `navigationBarTheme` (Task 2) — entferne evtl. dort noch hartkodierte Farben, verlasse dich aufs Theme. Rail (Desktop) bleibt wie ist (brown800). Keine Struktur-/Routing-Änderung.
- [ ] **Step 2:** `flutter analyze lib/shared/widgets/app_shell.dart` → 0.
- [ ] **Step 3: Commit** `feat(design): Nav-Leiste — Völker-Umlaut + Theme-Farben`

---

## Task 8: Cockpit auf Bausteine

**Files:** Modify `lib/features/dashboard/pages/dashboard_page.dart` + `widgets/{warnband,heute_karte,voelker_karte,waage_kachel}.dart`

> Kein Verhaltens-/Provider-Wechsel — nur Darstellung. Importiere die Bausteine + `app_tokens.dart`. Bestehende Provider-Watches und Navigations-Ziele bleiben exakt.

- [ ] **Step 1: `dashboard_page.dart`** — Datumszeile/Abstände auf `BeeTokens` (`EdgeInsets.all(BeeTokens.lg)`, `SizedBox(height: BeeTokens.md)`); Datums-`Text`-Farbe `BeeTokens.textGedaempft`. AppBar-Action (Konto-IconButton) bleibt.
- [ ] **Step 2: `warnband.dart`** — jedes Warn-Band auf `AppListTile` mit `onTap` + führendem Warn-Icon + `trailing: Icon(Icons.chevron_right)`, in einer `AppCard` bzw. mit `BeeSignal.gefahr`-Fläche (überfällig/Meldepflicht = `gefahr`). Alle `Colors.red.shadeXXX` entfernen → `BeeTokens`/`BeeSignal.gefahr`. `SizedBox.shrink()` bei kein-Befund bleibt.
- [ ] **Step 3: `heute_karte.dart`** — `Card`+`Padding` → `AppCard`; Kopf-`Row` (Icon+Titel+„alle →") → `SectionHeader(titel: 'Heute', trailingText: …, action: AppButton(label: 'alle', kind: text, …))`; jede Aufgaben-`Row` → `AppListTile` (führende `Checkbox` als `leading`, Volk/Datum als `untertitel` oder `trailing: StatusPill`); überfällig-Datum → `StatusPill(signal: gefahr)`. Alle `AppColors.honeyDark/brown300`/`Colors.red.shade700`/festen fontSize → `BeeTokens`. `_abhaken`-Logik + SnackBar/Undo + `darfSchreiben`-Gating unverändert.
- [ ] **Step 4: `voelker_karte.dart`** — `Card`+`Padding` → `AppCard`; Kopf-Row → `SectionHeader`; Volk-Zeile → `AppListTile(statusFarbe: <Ampelfarbe>, titel: name, untertitel: 'gesehen …', trailing: Meldepflicht-Icon?)`. **Die lokale roh-Hex-Ampel-Map** (`Color(0xFF5CB85C/F0AD4E/D9534F)`) ersetzen: Ampel → `BeeSignal`/Signal-Textfarben (`gesund→erfolgText`, `beobachtung→warnungText`, `krank/sperre→gefahrText`) als `statusFarbe`. `AppColors.honeyDark/brown300`/festen fontSize → `BeeTokens`.
- [ ] **Step 5: `waage_kachel.dart`** — `Card`+`InkWell`+`Row` → `AppCard(onTap: …)` mit innerer `AppListTile`-Optik (Leading-Icon + Titel/Untertitel + Chevron) bzw. `AppListTile`. `AppColors.brown300`/feste Werte → `BeeTokens`. Navigations-Ziel `/monitoring` bleibt.
- [ ] **Step 6:** `flutter analyze lib/features/dashboard` → 0; `flutter test` → grün (keine Regressions).
- [ ] **Step 7: Commit** `feat(design): Cockpit auf Bausteine (AppCard/SectionHeader/AppListTile/StatusPill, Ampel-Hex raus)`

---

## Task 9: Völker-Liste + Volk-Detail auf Bausteine

**Files:** Modify `lib/features/voelker/presentation/pages/voelker_page.dart`, `volk_detail_page.dart`

> Provider/Routing/`showVolkForm` unverändert.

- [ ] **Step 1: `voelker_page.dart`** — Leer-`Column` → `EmptyState(icon: Icons.hive_outlined, titel: 'Noch keine Völker', text: …, aktion: AppButton(label: 'Erstes Volk anlegen', icon: Icons.add, onPressed: → showVolkForm))`. Fehler-`Column` → `EmptyState(icon: Icons.error_outline, titel: 'Fehler beim Laden', aktion: AppButton(label: 'Erneut versuchen', kind: sekundaer, onPressed: → ref.invalidate))`. `AppBar('Voelker')` → `'Völker'`. FAB bleibt (Öffnen-Aktion). `VolkCard` unverändert lassen ODER (falls klein) auf `AppListTile` in `AppCard` — nur wenn ohne Verhaltensrisiko; sonst so lassen.
- [ ] **Step 2: `volk_detail_page.dart`** — `ListView(padding: EdgeInsets.all(BeeTokens.md))`; Stammdaten-`Card` → `AppCard`; Waage-`Card`/`ListTile` → `AppCard(onTap: →/monitoring)` mit `AppListTile`-Inhalt; `volk.status` → `StatusPill`; Loading/Error/„nicht gefunden"-Center → `EmptyState`. Edit-`IconButton` bleibt oben rechts (öffnet nur `showVolkForm`). Feste `fontWeight.bold`/`EdgeInsets`/`SizedBox` → `BeeTokens`. Die ausgelagerten Section-Widgets (Koenigin/Standort/Aufgaben/Durchsicht/Behandlung/…) bleiben unverändert (ziehen in ihren Modul-Durchgängen nach).
- [ ] **Step 3:** `flutter analyze lib/features/voelker` → 0; `flutter test` → grün.
- [ ] **Step 4: Commit** `feat(design): Völker-Liste + Volk-Detail auf Bausteine`

---

## Task 10: Durchsicht-Wizard auf FormScaffold + Waben-Tokens

**Files:** Modify `lib/features/durchsicht/presentation/pages/durchsicht_wizard_page.dart`, `widgets/waben_schritt.dart`

> Der Wizard hat bereits eine selbstgebaute Boden-`Row` (SafeArea/Padding/Row) — die wird durch `FormScaffold.bodenleiste` ersetzt. Wizard-Flow (`PageView`/`PageController`/`_weiter`/`_zurueck`/`_speichern`), Vorbefüllung, Foto, Sprache: **unverändert**.

- [ ] **Step 1: `durchsicht_wizard_page.dart`** — `Scaffold`+`AppBar`+`Column(Expanded(PageView)+SafeArea(Row))` ersetzen durch `FormScaffold(titel: 'Durchsicht', untertitel: '${seite+1}/3 · $titel', busy: _busy, child: PageView(...), bodenleiste: <Row aus AppButtons>)`. Bodenleiste: `Row([ if (seite>0) AppButton(label:'Zurück', kind: sekundaer, onPressed:_zurueck), const SizedBox(width: BeeTokens.sm), Expanded(child: AppButton(label: letzteSeite ? 'Speichern' : 'Weiter', icon: letzteSeite ? null : Icons.arrow_forward, busy:_busy, onPressed: letzteSeite ? _speichern : _weiter)) ])`. Das bisherige `AbsorbPointer(_busy)` übernimmt `FormScaffold.busy`. „Nur Lesezugriff"-Center → `EmptyState`. Seiten-`ListView`s bleiben Body-Inhalt. Feste `EdgeInsets`/`Colors.grey`/`fontSize` → `BeeTokens`.
- [ ] **Step 2:** Der „Erfasste Waben verwerfen"-`AlertDialog` (in `_wabenModusSetzen`) → `await confirmSheet(context, titel: 'Erfasste Waben verwerfen?', text: …, bestaetigenLabel: 'Verwerfen', gefahr: true)`.
- [ ] **Step 3: `waben_schritt.dart`** — Nur Tokenisierung: `AppColors.honeyDark/brown300/honey.withAlpha(60)/brown600` → `BeeTokens` (Waben-Segment-`BoxDecoration`: Rand/Fill/`borderRadius` aus Tokens); feste `SizedBox`/`fontSize` → `BeeTokens`; interne „Zurück/Nächste Wabe"-Row-Buttons → `AppButton` (sekundaer/primaer). Controlled-Logik (`onChanged`/`widget.waben`) unverändert. Ergebniszeile (Brutwaben/Königin/Stifte) darf `StatusPill` nutzen (optional).
- [ ] **Step 4:** `flutter analyze lib/features/durchsicht` → 0; `flutter test` → grün (Sprach-/Waben-Tests dürfen nicht brechen).
- [ ] **Step 5: Commit** `feat(design): Durchsicht-Wizard auf FormScaffold (Bodenleiste) + Waben-Tokens + ConfirmSheet`

---

## Task 11: Inter als lokales Asset (isoliert, mit Fallback)

**Files:** Create `assets/fonts/Inter-Regular.ttf`, `assets/fonts/Inter-Medium.ttf` · Modify `pubspec.yaml`, `lib/core/theme/app_theme.dart`

> **Best-effort:** Gelingt der Download nicht, bleibt `GoogleFonts.interTextTheme()` (Task 2) — dann diesen Task als BLOCKED melden, ohne den Rest zu gefährden.

- [ ] **Step 1: Fonts laden** (OFL, frei bündelbar) via Bash:
```bash
cd /d/Projekte/Bienen/bienen_app && mkdir -p assets/fonts && \
curl -fsSL -o assets/fonts/Inter-Regular.ttf "https://github.com/rsms/inter/raw/v4.1/docs/font-files/InterVariable.ttf" && ls -la assets/fonts
```
Falls die Variable-Font-URL nicht passt, alternativ die statischen Instanzen aus dem Google-Fonts-Repo laden (`https://github.com/google/fonts/raw/main/ofl/inter/Inter[opsz,wght].ttf`) und als eine Variable-Datei einbinden. Ziel: mindestens **eine** Inter-`.ttf` unter `assets/fonts/`.
- [ ] **Step 2: `pubspec.yaml`** — unter `flutter:` ergänzen:
```yaml
  fonts:
    - family: Inter
      fonts:
        - asset: assets/fonts/Inter-Regular.ttf
        - asset: assets/fonts/Inter-Medium.ttf
          weight: 500
```
(Bei Variable-Font: nur einen `asset`-Eintrag ohne `weight`; Flutter nutzt die `wght`-Achse über `fontWeight`.)
- [ ] **Step 3: `app_theme.dart`** — `GoogleFonts.interTextTheme()` → `ThemeData(fontFamily: 'Inter', …)` bzw. `Typography.material2021().black.apply(fontFamily: 'Inter')` als `textTheme`; `GoogleFonts.inter(...)` in `appBarTheme.titleTextStyle` → `TextStyle(fontFamily: 'Inter', …)`. `import 'package:google_fonts/...'` entfernen. Prüfe per `grep -rn "google_fonts" lib`, ob sonst nirgends genutzt → wenn frei, `google_fonts`-Dependency aus `pubspec.yaml` entfernen (sonst belassen).
- [ ] **Step 4:** `flutter analyze lib/core/theme` → 0; `flutter test` → grün. (Optische Prüfung im Browser in Task 12.)
- [ ] **Step 5: Commit** `feat(design): Inter als lokales Asset bündeln (kein Runtime-Font-Fetch)`

---

## Task 12: Abschluss — Voll-Check, Version, Browser, Deploy

- [ ] **Step 1:** `pubspec.yaml` Version → `1.30.0+52`.
- [ ] **Step 2:** `cd /d/Projekte/Bienen/bienen_app && flutter analyze` (0) und `flutter test` (alle grün, inkl. neue design-Tests).
- [ ] **Step 3: Browser-Boot-Check** (Preview `{url: live}` nach Deploy oder lokal): App bootet, Login-Seite rendert, keine Konsolen-Fehler; wenn eingeloggt-testbar: Cockpit/Völker/Durchsicht zeigen die neue helle Kopfleiste + Bodenleiste. (Eingeloggte Feinabnahme = Daniels Feldtest.)
- [ ] **Step 4: Deploy** `bash deploy.sh` (bei DNS-Fehler erneut).
- [ ] **Step 5: Commit** `chore(design): v1.30.0 Design-System + Kern-Screens`

---

## Self-Review-Notizen
- **Reihenfolge:** Tokens (1) → Theme (2) → Bausteine (3–6) → Nav (7) → Screens (8–10) → Font (11) → Abschluss (12). Jede Schicht baut auf der vorigen; Bausteine existieren, bevor Screens sie nutzen.
- **Rein Präsentation:** kein Task ändert Provider/Gateways/Routen/DB — die Screen-Tasks betonen „Logik unverändert".
- **Type-Konsistenz:** `BeeTokens`/`BeeSignal`/`AppButtonKind`/Baustein-Signaturen sind in Task 1/3–6 definiert und werden in 8–10 exakt so genutzt.
- **Font-Task isoliert** (11, Fallback google_fonts) — gefährdet das Design-System nicht.
- **Hardcode-Nester** (Ampel-Hex in `voelker_karte`, Rot-Schema in `warnband`, `AppColors.*` in `waben_schritt`) sind explizit als Ersetzungsziele benannt.
- **Un-migrierte Screens** funktionieren weiter (AppColors bleibt; globale Theme-Änderungen wie helle AppBar wirken überall konsistent).
