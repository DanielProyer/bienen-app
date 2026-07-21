import 'package:bienen_app/features/material/data/models/material_item.dart';
import 'package:bienen_app/features/material/data/models/material_purchase.dart';

/// Reine Kosten-Aggregation fuer das Material-/Kosten-Dashboard.
/// Keine Provider-/Supabase-Abhaengigkeiten — pur und testbar.
class KostenDashboard {
  final double bisher,
      investitionIst,
      laufendIst,
      geplant,
      sollBudget,
      archivIst,
      kostenJeVolk;
  final Map<String, double> proKategorie, proZahlungsart;
  final Map<int, double> proJahr;

  const KostenDashboard({
    required this.bisher,
    required this.investitionIst,
    required this.laufendIst,
    required this.geplant,
    required this.sollBudget,
    required this.archivIst,
    required this.kostenJeVolk,
    required this.proKategorie,
    required this.proJahr,
    required this.proZahlungsart,
  });

  /// Budget-Ausschoepfung (Ist / Soll); 0 wenn kein Soll-Budget vorhanden.
  double get ausschoepfung => sollBudget > 0 ? bisher / sollBudget : 0;

  /// Noch offener Budget-Rest (nie negativ).
  double get offen {
    final o = sollBudget - bisher;
    return o > 0 ? o : 0;
  }

  bool get leer => bisher == 0 && geplant == 0 && archivIst == 0;
}

/// Effektiver Betrag eines Kaufs: Gesamtpreis bevorzugt, sonst Menge x Stueckpreis.
double _betrag(MaterialPurchase p) =>
    p.gesamtpreis ??
    ((p.menge != null && p.stueckpreis != null) ? p.menge! * p.stueckpreis! : 0.0);

KostenDashboard berechneKostenDashboard(
    List<MaterialItem> items, List<MaterialPurchase> purchases, int anzahlVoelker) {
  final byId = {for (final i in items) i.id: i};
  var bisher = 0.0, investition = 0.0, laufend = 0.0, archiv = 0.0;
  final proKategorie = <String, double>{}, proZahlungsart = <String, double>{};
  final proJahr = <int, double>{};
  for (final p in purchases) {
    final betrag = _betrag(p);
    final m = byId[p.materialId];
    // Kaeufe archivierter Materialien laufen separat (Archiv-Topf).
    if (m != null && m.archiviert) {
      archiv += betrag;
      continue;
    }
    bisher += betrag;
    if (m != null) {
      m.isConsumable ? laufend += betrag : investition += betrag;
      proKategorie[m.category] = (proKategorie[m.category] ?? 0) + betrag;
    }
    final za = (p.zahlungsart == null || p.zahlungsart!.trim().isEmpty)
        ? 'Unbekannt'
        : p.zahlungsart!;
    proZahlungsart[za] = (proZahlungsart[za] ?? 0) + betrag;
    if (p.gekauftAm != null) {
      proJahr[p.gekauftAm!.year] = (proJahr[p.gekauftAm!.year] ?? 0) + betrag;
    }
  }
  var geplant = 0.0, soll = 0.0;
  for (final i in items) {
    if (i.archiviert) continue;
    final schaetz = (i.priceCHF ?? 0) * i.quantity;
    soll += schaetz;
    if (i.status == 'geplant' || i.status == 'bestellt') geplant += schaetz;
  }
  final n = anzahlVoelker < 1 ? 1 : anzahlVoelker;
  return KostenDashboard(
    bisher: bisher,
    investitionIst: investition,
    laufendIst: laufend,
    geplant: geplant,
    sollBudget: soll,
    archivIst: archiv,
    kostenJeVolk: laufend / n,
    proKategorie: proKategorie,
    proJahr: proJahr,
    proZahlungsart: proZahlungsart,
  );
}

/// Bestands-Ampel fuer Verbrauchsmaterial mit gesetztem Mindestbestand.
enum BestandStatus { genug, nachbestellen, nichtRelevant }

BestandStatus bestandStatus(MaterialItem m) {
  if (!m.isConsumable || m.minQty <= 0) return BestandStatus.nichtRelevant;
  return m.stockQty >= m.minQty ? BestandStatus.genug : BestandStatus.nachbestellen;
}
