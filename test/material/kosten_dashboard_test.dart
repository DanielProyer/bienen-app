import 'package:flutter_test/flutter_test.dart';
import 'package:bienen_app/features/material/data/models/material_item.dart';
import 'package:bienen_app/features/material/data/models/material_purchase.dart';
import 'package:bienen_app/features/material/domain/kosten_dashboard.dart';

MaterialItem _m(String id,
        {bool consumable = false,
        bool arch = false,
        String cat = 'Div',
        String status = 'gekauft',
        double preis = 0,
        int qty = 1,
        double stock = 0,
        double min = 0}) =>
    MaterialItem(
        id: id,
        category: cat,
        name: id,
        isConsumable: consumable,
        archiviert: arch,
        status: status,
        priceCHF: preis,
        quantity: qty,
        stockQty: stock,
        minQty: min);

MaterialPurchase _p(String mid, {double? gesamt, DateTime? am, String? za}) =>
    MaterialPurchase(
        id: 'p$mid',
        materialId: mid,
        gesamtpreis: gesamt,
        gekauftAm: am,
        zahlungsart: za);

void main() {
  test('Investition vs laufend + Soll/Ist + Archiv separat', () {
    final items = [
      _m('beute', preis: 300, qty: 2, status: 'gekauft'), // Anlage, Soll 600
      _m('futter', consumable: true, preis: 20, status: 'geplant'), // laufend, geplant 20
      _m('bau', arch: true, preis: 999), // archiviert
    ];
    final purchases = [
      _p('beute', gesamt: 620, am: DateTime(2026, 3, 1), za: 'TWINT'), // Investition
      _p('futter', gesamt: 18, am: DateTime(2026, 5, 1), za: 'Bar'), // laufend
      _p('bau', gesamt: 800, am: DateTime(2025, 9, 1)), // Archiv
    ];
    final d = berechneKostenDashboard(items, purchases, 1);
    expect(d.bisher, 638);
    expect(d.investitionIst, 620);
    expect(d.laufendIst, 18);
    expect(d.archivIst, 800);
    expect(d.geplant, 20);
    expect(d.sollBudget, 620);
    expect(d.proZahlungsart['TWINT'], 620);
    expect(d.proJahr[2026], 638);
    expect(d.kostenJeVolk, 18);
    expect(d.ausschoepfung, closeTo(638 / 620, 0.001));
  });
  test('Kauf ohne Material zählt zu bisher, nicht in Split', () {
    final d = berechneKostenDashboard(const [], [_p('weg', gesamt: 50)], 1);
    expect(d.bisher, 50);
    expect(d.investitionIst, 0);
    expect(d.laufendIst, 0);
  });
  test('kostenJeVolk teilt durch max(1,n)', () {
    final items = [_m('f', consumable: true)];
    final d = berechneKostenDashboard(items, [_p('f', gesamt: 40)], 0);
    expect(d.kostenJeVolk, 40);
  });
  test('bestandStatus', () {
    expect(bestandStatus(_m('a', consumable: true, min: 2, stock: 1)),
        BestandStatus.nachbestellen);
    expect(bestandStatus(_m('b', consumable: true, min: 2, stock: 5)),
        BestandStatus.genug);
    expect(bestandStatus(_m('c', consumable: false, min: 2, stock: 0)),
        BestandStatus.nichtRelevant);
    expect(bestandStatus(_m('d', consumable: true, min: 0, stock: 0)),
        BestandStatus.nichtRelevant);
  });
}
