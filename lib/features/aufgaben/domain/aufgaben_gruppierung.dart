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
