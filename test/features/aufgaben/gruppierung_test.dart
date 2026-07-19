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
