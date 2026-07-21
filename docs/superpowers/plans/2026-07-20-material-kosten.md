# Material-Rework + Kosten-Dashboard — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:subagent-driven-development. Steps use checkbox (`- [ ]`) syntax. Ultracode an → je Task adversariale Verifikation + finaler Review.

**Goal:** Material klar nach Typ trennen (Verbrauch/Anlage/Archiv), den Nachkauf-Fehlalarm fixen (Kauf→Bestand-Trigger), Standbau archivieren, professionelles Kosten-Dashboard (Investition vs. laufend, Budget Soll/Ist).

**Architecture:** Migration N01 (archiviert-Spalte + Standbau-Archiv + Bestands-Korrektur + purchase→stock-Trigger). Reine Aggregation `berechneKostenDashboard`/`bestandStatus` (offline getestet). Provider-Umbau (archiviert-Filter, nachkaufen-Fix, kostenDashboardProvider). UI: Segmente Verbrauch/Anlagen/Ausgaben + Archiv.

**Tech Stack:** Flutter Web, Riverpod, Supabase (Trigger), fl_chart/CSS-Balken. Spec: `docs/superpowers/specs/2026-07-20-material-kosten-design.md`.

---

## Dateistruktur
**Neu:** `supabase/migrations/N01_material_rework.sql` · `lib/features/material/domain/kosten_dashboard.dart` · `presentation/widgets/{verbrauch_ansicht,anlagen_ansicht,kosten_dashboard,archiv_ansicht}.dart` · Tests `test/material/{kosten_dashboard_test,material_filter_test}.dart`
**Geändert:** `data/models/material_item.dart` (+archiviert) · `presentation/providers/material_provider.dart` · `presentation/pages/material_page.dart` (Umbau) · `presentation/pages/material_detail_page.dart` (Typ+Archiv)

---

## Task 1: Migration N01 (Produktion) — Controller, braucht Freigabe

**Files:** Create `supabase/migrations/N01_material_rework.sql`

- [ ] **Step 1: File schreiben** (SQL exakt aus Spec §3)
- [ ] **Step 2: Anwenden** via Supabase-MCP `apply_migration` (name `N01_material_rework`, Projekt `dcdcohktxbhdxnxjvcyp`) — **nach Freigabe**.
- [ ] **Step 3: Verifizieren:** `execute_sql` — Spalte `archiviert` existiert; `select count(*) from materials where bereich='standbau' and not archiviert` = 0; Trigger `trg_material_bestand` existiert; Test-Insert eines material_purchases (menge) auf ein Verbrauchsmaterial → `stock_qty` steigt, Delete → sinkt; `get_advisors(security)` + `(performance)` → 0 neue.
- [ ] **Step 4: Commit** `git -C D:/Projekte/Bienen/bienen_app add supabase/migrations/N01_material_rework.sql && git ... commit -m "feat(material): N01 Migration (archiviert + Standbau-Archiv + Bestands-Korrektur + purchase→stock-Trigger)"`

---

## Task 2: Modell — `archiviert`

**Files:** Modify `lib/features/material/data/models/material_item.dart` · Test `test/material/material_item_archiviert_test.dart`

- [ ] **Step 1: Failing test**
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:bienen_app/features/material/data/models/material_item.dart';
void main() {
  test('archiviert round-trip', () {
    final m = MaterialItem.fromJson({'id':'1','category':'c','name':'n','archiviert':true});
    expect(m.archiviert, isTrue);
    expect(m.toJson()['archiviert'], isTrue);
    expect(MaterialItem.fromJson({'id':'2','category':'c','name':'n'}).archiviert, isFalse); // Default
  });
}
```
- [ ] **Step 2:** `flutter test test/material/material_item_archiviert_test.dart` → FAIL.
- [ ] **Step 3: Implement** — `final bool archiviert;` ergänzen: Konstruktor `this.archiviert = false,`, copyWith (`bool? archiviert` + `archiviert: archiviert ?? this.archiviert`), fromJson `archiviert: json['archiviert'] as bool? ?? false,`, toJson `'archiviert': archiviert,`.
- [ ] **Step 4:** Test → PASS.
- [ ] **Step 5: Commit** `feat(material): MaterialItem.archiviert`

---

## Task 3: Reine Aggregation — `kosten_dashboard.dart` (TDD, der Kern)

**Files:** Create `lib/features/material/domain/kosten_dashboard.dart` · Test `test/material/kosten_dashboard_test.dart`

- [ ] **Step 1: Failing test**
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:bienen_app/features/material/data/models/material_item.dart';
import 'package:bienen_app/features/material/data/models/material_purchase.dart';
import 'package:bienen_app/features/material/domain/kosten_dashboard.dart';

MaterialItem _m(String id, {bool consumable = false, bool arch = false, String cat = 'Div', String status = 'gekauft', double preis = 0, int qty = 1, double stock = 0, double min = 0}) =>
    MaterialItem(id: id, category: cat, name: id, isConsumable: consumable, archiviert: arch, status: status, priceCHF: preis, quantity: qty, stockQty: stock, minQty: min);
MaterialPurchase _p(String mid, {double? gesamt, DateTime? am, String? za}) =>
    MaterialPurchase(id: 'p$mid', materialId: mid, gesamtpreis: gesamt, gekauftAm: am, zahlungsart: za);

void main() {
  test('Investition vs laufend + Soll/Ist + Archiv separat', () {
    final items = [
      _m('beute', preis: 300, qty: 2, status: 'gekauft'),            // Anlage, Soll 600
      _m('futter', consumable: true, preis: 20, status: 'geplant'),  // laufend, geplant 20
      _m('bau', arch: true, preis: 999),                             // archiviert
    ];
    final purchases = [
      _p('beute', gesamt: 620, am: DateTime(2026,3,1), za: 'TWINT'), // Investition
      _p('futter', gesamt: 18, am: DateTime(2026,5,1), za: 'Bar'),   // laufend
      _p('bau', gesamt: 800, am: DateTime(2025,9,1)),                // Archiv
    ];
    final d = berechneKostenDashboard(items, purchases, 1);
    expect(d.bisher, 638);            // 620 + 18 (Archiv NICHT drin)
    expect(d.investitionIst, 620);
    expect(d.laufendIst, 18);
    expect(d.archivIst, 800);
    expect(d.geplant, 20);
    expect(d.sollBudget, 620);        // 600 (beute) + 20 (futter); Archiv nicht
    expect(d.proZahlungsart['TWINT'], 620);
    expect(d.proJahr[2026], 638);
    expect(d.kostenJeVolk, 18);       // laufend / 1
    expect(d.ausschoepfung, closeTo(638/620, 0.001));
  });
  test('Kauf ohne Material zählt zu bisher, nicht in Split', () {
    final d = berechneKostenDashboard(const [], [_p('weg', gesamt: 50)], 1);
    expect(d.bisher, 50); expect(d.investitionIst, 0); expect(d.laufendIst, 0);
  });
  test('kostenJeVolk teilt durch max(1,n)', () {
    final items = [_m('f', consumable: true)];
    final d = berechneKostenDashboard(items, [_p('f', gesamt: 40)], 0);
    expect(d.kostenJeVolk, 40); // n=0 → /1
  });
  test('bestandStatus', () {
    expect(bestandStatus(_m('a', consumable: true, min: 2, stock: 1)), BestandStatus.nachbestellen);
    expect(bestandStatus(_m('b', consumable: true, min: 2, stock: 5)), BestandStatus.genug);
    expect(bestandStatus(_m('c', consumable: false, min: 2, stock: 0)), BestandStatus.nichtRelevant);
    expect(bestandStatus(_m('d', consumable: true, min: 0, stock: 0)), BestandStatus.nichtRelevant);
  });
}
```
- [ ] **Step 2:** Test → FAIL.
- [ ] **Step 3: Implement**
```dart
import 'package:bienen_app/features/material/data/models/material_item.dart';
import 'package:bienen_app/features/material/data/models/material_purchase.dart';

class KostenDashboard {
  final double bisher, investitionIst, laufendIst, geplant, sollBudget, archivIst, kostenJeVolk;
  final Map<String, double> proKategorie, proZahlungsart;
  final Map<int, double> proJahr;
  const KostenDashboard({required this.bisher, required this.investitionIst, required this.laufendIst,
    required this.geplant, required this.sollBudget, required this.archivIst, required this.kostenJeVolk,
    required this.proKategorie, required this.proJahr, required this.proZahlungsart});
  double get ausschoepfung => sollBudget > 0 ? bisher / sollBudget : 0;
  double get offen { final o = sollBudget - bisher; return o > 0 ? o : 0; }
  bool get leer => bisher == 0 && geplant == 0 && archivIst == 0;
}

double _betrag(MaterialPurchase p) =>
    p.gesamtpreis ?? ((p.menge != null && p.stueckpreis != null) ? p.menge! * p.stueckpreis! : 0.0);

KostenDashboard berechneKostenDashboard(List<MaterialItem> items, List<MaterialPurchase> purchases, int anzahlVoelker) {
  final byId = {for (final i in items) i.id: i};
  var bisher = 0.0, investition = 0.0, laufend = 0.0, archiv = 0.0;
  final proKategorie = <String, double>{}, proZahlungsart = <String, double>{};
  final proJahr = <int, double>{};
  for (final p in purchases) {
    final betrag = _betrag(p);
    final m = byId[p.materialId];
    if (m != null && m.archiviert) { archiv += betrag; continue; }
    bisher += betrag;
    if (m != null) {
      m.isConsumable ? laufend += betrag : investition += betrag;
      proKategorie[m.category] = (proKategorie[m.category] ?? 0) + betrag;
    }
    final za = (p.zahlungsart == null || p.zahlungsart!.trim().isEmpty) ? 'Unbekannt' : p.zahlungsart!;
    proZahlungsart[za] = (proZahlungsart[za] ?? 0) + betrag;
    if (p.gekauftAm != null) proJahr[p.gekauftAm!.year] = (proJahr[p.gekauftAm!.year] ?? 0) + betrag;
  }
  var geplant = 0.0, soll = 0.0;
  for (final i in items) {
    if (i.archiviert) continue;
    final schaetz = (i.priceCHF ?? 0) * i.quantity;
    soll += schaetz;
    if (i.status == 'geplant' || i.status == 'bestellt') geplant += schaetz;
  }
  final n = anzahlVoelker < 1 ? 1 : anzahlVoelker;
  return KostenDashboard(bisher: bisher, investitionIst: investition, laufendIst: laufend,
    geplant: geplant, sollBudget: soll, archivIst: archiv, kostenJeVolk: laufend / n,
    proKategorie: proKategorie, proJahr: proJahr, proZahlungsart: proZahlungsart);
}

enum BestandStatus { genug, nachbestellen, nichtRelevant }
BestandStatus bestandStatus(MaterialItem m) {
  if (!m.isConsumable || m.minQty <= 0) return BestandStatus.nichtRelevant;
  return m.stockQty >= m.minQty ? BestandStatus.genug : BestandStatus.nachbestellen;
}
```
- [ ] **Step 4:** Test → PASS.
- [ ] **Step 5: Commit** `feat(material): reine Kosten-Aggregation + bestandStatus`

---

## Task 4: Provider-Umbau + Filter-Tests

**Files:** Modify `presentation/providers/material_provider.dart` · Test `test/material/material_filter_test.dart`

- [ ] **Step 1: Failing test** (reine Filter-Logik über eine Fixture-Liste)
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:bienen_app/features/material/data/models/material_item.dart';
import 'package:bienen_app/features/material/domain/kosten_dashboard.dart';
// Prüft die Filter-Prädikate als reine Funktionen (siehe Step 3: als top-level Helfer extrahiert).
```
*(Der Test prüft die extrahierten reinen Prädikate `istVerbrauch`/`istAnlage`/`istArchiviert`/`istNachzukaufen` — im Provider-File als top-level Funktionen definiert, damit sie ohne ProviderContainer testbar sind.)*
```dart
void main() {
  MaterialItem m(String id, {bool c=false, bool a=false, String s='gekauft', double stock=0, double min=0}) =>
    MaterialItem(id:id, category:'x', name:id, isConsumable:c, archiviert:a, status:s, stockQty:stock, minQty:min);
  test('Nachkauf: frisch gekauft mit vollem Bestand ist NICHT fällig', () {
    expect(istNachzukaufen(m('a', c:true, stock:10, min:2)), isFalse);        // voll → kein Alarm (Bug behoben)
    expect(istNachzukaufen(m('b', c:true, stock:1, min:2)), isTrue);          // verbraucht → fällig
    expect(istNachzukaufen(m('c', c:true, a:true, stock:0, min:2)), isFalse); // archiviert → nie
    expect(istNachzukaufen(m('d', c:true, stock:0, min:0)), isFalse);         // kein Mindest → nie
    expect(istNachzukaufen(m('e', c:false, stock:0, min:2)), isFalse);        // Anlage → nie
    expect(istNachzukaufen(m('f', c:true, s:'geplant', stock:0, min:2)), isFalse); // nicht gekauft → gehört auf Einkaufsliste
  });
}
```
- [ ] **Step 2:** Test → FAIL (Funktionen fehlen).
- [ ] **Step 3: Implement** — im Provider-File top-level Prädikate + neue Provider:
```dart
bool istArchiviert(MaterialItem i) => i.archiviert;
bool istVerbrauch(MaterialItem i) => !i.archiviert && i.isConsumable;
bool istAnlage(MaterialItem i) => !i.archiviert && !i.isConsumable;
bool istNachzukaufen(MaterialItem i) =>
    !i.archiviert && i.isConsumable && i.status == 'gekauft' && i.minQty > 0 && i.stockQty < i.minQty;
```
```dart
final aktiveMaterialienProvider = Provider<List<MaterialItem>>((ref) =>
    (ref.watch(materialListProvider).valueOrNull ?? const []).where((i) => !i.archiviert).toList());
final verbrauchItemsProvider = Provider<List<MaterialItem>>((ref) =>
    (ref.watch(materialListProvider).valueOrNull ?? const []).where(istVerbrauch).toList());
final anlageItemsProvider = Provider<List<MaterialItem>>((ref) =>
    (ref.watch(materialListProvider).valueOrNull ?? const []).where(istAnlage).toList());
final archivItemsProvider = Provider<List<MaterialItem>>((ref) =>
    (ref.watch(materialListProvider).valueOrNull ?? const []).where(istArchiviert).toList());
```
- `nachkaufenItemsProvider` → `(ref.watch(materialListProvider).valueOrNull ?? const []).where(istNachzukaufen).toList()`.
- `einkaufenItemsProvider`/`bestandItemsProvider` → zusätzlich `&& !i.archiviert`.
- `kostenDashboardProvider` (nutzt Task 3 + Völker):
```dart
final kostenDashboardProvider = Provider<KostenDashboard>((ref) {
  final items = ref.watch(materialListProvider).valueOrNull ?? const [];
  final purchases = ref.watch(materialPurchasesProvider).valueOrNull ?? const [];
  final anzahl = (ref.watch(voelkerListProvider).valueOrNull ?? const []).length; // aktive Völker
  return berechneKostenDashboard(items, purchases, anzahl);
});
```
  *(Import den bestehenden Völker-Provider; falls der Name abweicht, per Grep den echten `voelker`-Listen-Provider finden und einsetzen.)*
- `MaterialListNotifier.setArchiviert(String id, bool wert)` (optimistic wie `updateStock`, `update({'archiviert': wert})`).
- `MaterialPurchasesNotifier.addPurchase`/`deletePurchase`: nach `insert`/`delete` **zusätzlich** `ref.invalidate(materialListProvider)` (Trigger-Bestand nachziehen).
- [ ] **Step 4:** `flutter test test/material/` → PASS; `flutter analyze lib/features/material/providers` → 0.
- [ ] **Step 5: Commit** `feat(material): Provider (archiviert-Filter, nachkaufen-Fix, kostenDashboard, setArchiviert, Kauf→List-Invalidation)`

---

## Task 5: UI-Umbau `material_page.dart` — Segmente Verbrauch/Anlagen/Ausgaben + Archiv

**Files:** Modify `presentation/pages/material_page.dart` · Create `presentation/widgets/{verbrauch_ansicht,anlagen_ansicht,archiv_ansicht}.dart`

> Restrukturierung: statt Tabs Einkaufen/Bestand/Nachkaufen/Ausgaben → **3 Segmente Verbrauch · Anlagen · Ausgaben** (`TabBar` length 3) + **Archiv-IconButton** in der AppBar (öffnet `ArchivAnsicht` als eigene Seite via `Navigator.push`). Der Bereich-Filter entfällt (Standbau ist archiviert; imkerei/honigverarbeitung mischen im Verbrauch/Anlage-Schnitt nicht mehr störend). Bestehende `_SummaryCard`/Hilfsklassen wandern ins `kosten_dashboard.dart`-Widget (Task 6).

- [ ] **Step 1:** `material_page.dart` neu: `DefaultTabController(length: 3)` mit AppBar-`actions:[IconButton(Icons.archive_outlined → Navigator.push(ArchivAnsicht))]`, `TabBar(tabs:[Verbrauch, Anlagen, Ausgaben])`, `TabBarView(children:[VerbrauchAnsicht(), AnlagenAnsicht(), KostenDashboard()])`. Kein `_BereichFilterRow` mehr.
- [ ] **Step 2: `verbrauch_ansicht.dart`** (ConsumerWidget): oben ein Nachkauf-Banner falls `nachkaufenItemsProvider` nicht leer (amber, „N Artikel nachbestellen"); dann Abschnitt „Im Bestand" (`verbrauchItems` mit `status=='gekauft'`) — je Item `MaterialListTile` + Bestandsbalken (`stockQty/minQty`, Badge aus `bestandStatus`: grün *genug* / amber *nachbestellen*) + inline `stock_qty`/`min_qty`-Editier-Affordance (bestehende `updateStock`/`updateMinQty`); dann Abschnitt „Auf der Einkaufsliste" (`verbrauchItems` mit status geplant/bestellt → `MaterialListTile`). Muster/Widgets aus dem bisherigen `_BestandTile`/`_NachkaufenView` wiederverwenden.
- [ ] **Step 3: `anlagen_ansicht.dart`** (ConsumerWidget): Abschnitt „Vorhanden" (`anlageItems` status gekauft → `MaterialListTile`, Untertitel Anzahl · Preis · letztes Kaufdatum aus `purchasesByMaterialProvider`) + „Geplant" (status geplant/bestellt). KEIN Bestandsbalken/Nachkauf.
- [ ] **Step 4: `archiv_ansicht.dart`** (eigene Seite, Scaffold+AppBar „Archiv"): Liste `archivItemsProvider`, je Item `MaterialListTile` + Button „reaktivieren" → `materialListProvider.notifier.setArchiviert(id, false)`. Empty-State „Archiv ist leer".
- [ ] **Step 5:** `flutter analyze lib/features/material/` → 0; `flutter test` → grün.
- [ ] **Step 6: Commit** `feat(material): Ansicht Verbrauch/Anlagen/Archiv (Segmente + Archiv-Seite)`

---

## Task 6: `kosten_dashboard.dart`-Widget (das reiche Dashboard)

**Files:** Create `presentation/widgets/kosten_dashboard.dart`

- [ ] **Step 1:** ConsumerWidget, `final d = ref.watch(kostenDashboardProvider);`, Empty-State bei `d.leer`. Aufbau (ListView), Muster/Zahlenformat aus dem bisherigen `_AusgabenView` (`_chf`, Cards):
  1. **Kennzahl-Karten** (Wrap/Grid): Bisher (`d.bisher`), Investitionen (`d.investitionIst`), Laufend (`d.laufendIst`), Noch geplant (`d.geplant`).
  2. **Budget Soll/Ist:** Balken `d.ausschoepfung` (LinearProgressIndicator o. Ä.) + „CHF {bisher} von {sollBudget} · {%} · offen {offen}".
  3. **Nach Kategorie:** `d.proKategorie` (sortiert desc) als Balkenliste.
  4. **Pro Jahr:** `d.proJahr` als kleine Balken.
  5. **Zahlungsart:** `d.proZahlungsart` (sortiert desc).
  6. **Kosten je Volk:** `d.kostenJeVolk` (klein).
  7. **Archiv/Bau:** `d.archivIst` als gedämpfte Zeile „nicht in laufenden Betriebskosten".
  Zahlen mit `NumberFormat('#,##0.00','de_CH')`, `tabular-nums`-Wirkung via monospaced/rechtsbündig.
- [ ] **Step 2:** `flutter analyze` → 0; `flutter test` → grün.
- [ ] **Step 3: Commit** `feat(material): Kosten-Dashboard-Widget (Investition/laufend, Budget Soll/Ist, Kategorie/Jahr/Zahlungsart, je Volk, Archiv)`

---

## Task 7: `material_detail_page.dart` — Typ-Umschalter + Archivieren

**Files:** Modify `presentation/pages/material_detail_page.dart`

- [ ] **Step 1:** Lies die Datei; ergänze (ohne die bestehende Foto-/PDF-/Kauf-Erfassung zu verändern):
  - **Typ-Umschalter** (Verbrauch/Anlage = `is_consumable`): ein SegmentedButton/Switch, der `is_consumable` togglet (`materialListProvider.notifier` — neue Methode `updateIsConsumable(id,bool)` analog `updateStatus`).
  - **Archivieren/Reaktivieren:** ein Menü-/Button-Eintrag → `setArchiviert(id, !item.archiviert)` + SnackBar.
  - Bei Anlagegut (`!is_consumable`): Bestand/Mindest-Felder ausblenden.
- [ ] **Step 2:** `flutter analyze lib/features/material/` → 0; `flutter test` → grün.
- [ ] **Step 3: Commit** `feat(material): Detailseite Typ-Umschalter + Archivieren`

---

## Task 8: Abschluss — Voll-Check, Version, Browser, Deploy

- [ ] **Step 1:** `pubspec.yaml` Version → `1.29.0+51`.
- [ ] **Step 2:** `cd /d/Projekte/Bienen/bienen_app && flutter analyze` (0) und `flutter test` (alle grün, neu: kosten_dashboard, material_filter, material_item_archiviert).
- [ ] **Step 3: Browser-Verifikation** (Preview): Material-Tab → 3 Segmente; Verbrauch zeigt Bestand + KEIN Fehlalarm für frisch gekauftes; Anlagen ohne Bestandsbalken; Ausgaben-Dashboard rendert (Investition/laufend/Budget); Archiv-Seite zeigt Standbau-Material + reaktivieren; keine Konsolen-Fehler.
- [ ] **Step 4: Deploy** `bash deploy.sh` (bei DNS-Fehler erneut).
- [ ] **Step 5: Commit** `chore(material): v1.29.0 Material-Rework + Kosten-Dashboard`

---

## Self-Review-Notizen
- **Migration zuerst** (Task 1) — die Provider/UI erwarten `archiviert` + korrigierten Bestand; ohne N01 zeigt die UI weiter Fehlalarme.
- **Reiner Kern getestet** (Task 3/4): Aggregation + Filter-Prädikate offline; die Bug-Regression (frisch gekauft ≠ Nachkauf) ist ein expliziter Test.
- **UI folgt Bestand:** die neuen Ansichten recyclen `MaterialListTile`/`_chf`/Card-Muster aus dem alten `material_page.dart` (kein Neu-Erfinden).
- **Völker-Provider-Name** in Task 4 vor Nutzung per Grep verifizieren (aktive-Völker-Zählung für Kosten je Volk).
- **Kauf→List-Invalidation** (Task 4): ohne sie zeigt der Trigger-Bestand erst nach Reload.
