import 'package:bienen_app/features/fuetterung/domain/fuetterung.dart';

/// Auffütter-Saison beginnt am 1. Juli (Nordhalbkugel-Fachdefault; F4 überschreibt später).
const kAuffuetterSaisonStartMonat = 7;

/// Σ Produktmasse (kg) der nicht-stornierten Auffütterungen der laufenden Saison.
/// Saison-Anker IN der Funktion gekapselt (M2): bei Monat < 7 startet die Saison im Vorjahr
/// (1.7.X–30.6.X+1), sonst würde der Balken von Januar bis Juni fälschlich auf 0 fallen.
/// Vergleich rein auf Datumsebene (kein UTC-Shift — durchgefuehrt_am ist ein PG `date`).
double winterfutterKg(List<Fuetterung> fuetterungen, {required DateTime stichtag}) {
  final saisonStartJahr =
      stichtag.month < kAuffuetterSaisonStartMonat ? stichtag.year - 1 : stichtag.year;
  final saisonStart = DateTime(saisonStartJahr, kAuffuetterSaisonStartMonat, 1);
  var summe = 0.0;
  for (final f in fuetterungen) {
    if (f.isStorniert || f.zweck != 'auffuetterung') continue;
    if (f.durchgefuehrtAm.isBefore(saisonStart)) continue;
    summe += f.mengeProVolkKg.toDouble();
  }
  return summe;
}

/// Fortschritt 0..1 (null-/0-Ziel-sicher, Clamp auf 1).
double winterfutterProzent(double kg, double zielKg) {
  if (zielKg <= 0) return 0;
  final p = kg / zielKg;
  return p > 1 ? 1 : p;
}
