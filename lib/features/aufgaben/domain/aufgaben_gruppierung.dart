import 'package:bienen_app/features/aufgaben/domain/aufgabe.dart';

enum AufgabenGruppe { ueberfaellig, heute, demnaechst, spaeter }

/// DST-sichere Kalendertag-Differenz: UTC-Konstruktion kennt keine Zeitumstellung.
int _tagDiff(DateTime a, DateTime b) =>
    DateTime.utc(a.year, a.month, a.day).difference(DateTime.utc(b.year, b.month, b.day)).inDays;

/// Gruppiert OFFENE Aufgaben nach Fälligkeit relativ zu [stichtag] (nur Datumsteil).
/// demnaechst = 1..14 Tage voraus. Innerhalb jeder Gruppe aufsteigend nach faellig_am.
Map<AufgabenGruppe, List<Aufgabe>> gruppiereOffene(List<Aufgabe> alle, DateTime stichtag) {
  final offen = alle.where((a) => a.status == 'offen').toList()
    ..sort((a, b) => a.faelligAm.compareTo(b.faelligAm));
  final m = {for (final g in AufgabenGruppe.values) g: <Aufgabe>[]};
  for (final a in offen) {
    final diff = _tagDiff(a.faelligAm, stichtag);
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

/// Die nächsten [n] OFFENEN Aufgaben, aufsteigend nach faellig_am —
/// überfällige stehen damit automatisch zuerst. Fürs Cockpit („Heute & demnächst").
List<Aufgabe> naechsteOffene(List<Aufgabe> alle, DateTime stichtag, int n) {
  final offen = alle.where((a) => a.status == 'offen').toList()
    ..sort((a, b) => a.faelligAm.compareTo(b.faelligAm));
  return offen.take(n).toList();
}
