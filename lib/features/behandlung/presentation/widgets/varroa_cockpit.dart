import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:bienen_app/features/behandlung/domain/ampel_schwellen.dart';
import 'package:bienen_app/features/behandlung/domain/behandlung.dart';
import 'package:bienen_app/features/behandlung/domain/varroa_kontrolle.dart';

/// Varroa-Cockpit: Milben/Tag-Verlauf (Gemüll) + saisonales Ampelband + Behandlungs-Marker
/// (nur nicht-stornierte), dazu Befall-%-Chips (Puderzucker/Auswaschung), ein methodengerechter
/// Ampel-Chip aus der letzten Kontrolle und ein Höhen-Caveat (F4 macht den Offset später konfigurierbar).
class VarroaCockpit extends StatelessWidget {
  final List<VarroaKontrolle> kontrollen; // absteigend sortiert
  final List<Behandlung> behandlungen; // inkl. stornierte
  const VarroaCockpit({super.key, required this.kontrollen, required this.behandlungen});

  static Color _ampelColor(Ampel a) => switch (a) {
        Ampel.gruen => Colors.green,
        Ampel.gelb => Colors.orange,
        Ampel.rot => Colors.red,
        Ampel.keinRichtwert => Colors.grey,
      };

  static String _ampelText(Ampel a) => switch (a) {
        Ampel.gruen => 'grün',
        Ampel.gelb => 'gelb — beobachten',
        Ampel.rot => 'rot — Behandlung empfohlen',
        Ampel.keinRichtwert => 'kein Richtwert',
      };

  @override
  Widget build(BuildContext context) {
    final gemuell = kontrollen.where((k) => k.methode == 'gemuell').toList();
    final proben = kontrollen.where((k) => k.methode != 'gemuell').toList();

    // Ampel-Chip aus der letzten Kontrolle (kontrollen ist absteigend -> erstes Element).
    Widget? ampelChip;
    if (kontrollen.isNotEmpty) {
      final k = kontrollen.first;
      final a = ampelFuerKontrolle(
        methode: k.methode, milbenGesamt: k.milbenGesamt,
        messdauerTage: k.messdauerTage, bienenProbe: k.bienenProbe, monat: k.durchgefuehrtAm.month,
      );
      if (a != Ampel.keinRichtwert) {
        ampelChip = Chip(
          backgroundColor: _ampelColor(a).withAlpha(38),
          avatar: CircleAvatar(backgroundColor: _ampelColor(a), radius: 6),
          label: Text('Befall: ${_ampelText(a)}'),
        );
      }
    }

    // Milben/Tag-Punkte (Gemüll), chronologisch aufsteigend für die Linie.
    final punkte = <FlSpot>[];
    final sortedGemuell = [...gemuell]..sort((a, b) => a.durchgefuehrtAm.compareTo(b.durchgefuehrtAm));
    for (var i = 0; i < sortedGemuell.length; i++) {
      final k = sortedGemuell[i];
      final mpt = milbenProTag(k.milbenGesamt, k.messdauerTage);
      if (mpt != null) punkte.add(FlSpot(i.toDouble(), mpt));
    }

    // Behandlungs-Marker (nur nicht-stornierte) als vertikale Linien am nächstgelegenen Punktindex.
    final marker = <VerticalLine>[];
    for (final b in behandlungen.where((b) => !b.isStorniert)) {
      final idx = sortedGemuell.indexWhere((k) => !k.durchgefuehrtAm.isBefore(b.datumBeginn));
      final x = idx < 0 ? (sortedGemuell.length - 1).toDouble() : idx.toDouble();
      if (x >= 0) marker.add(VerticalLine(x: x, color: Colors.blue.withAlpha(128), strokeWidth: 1.5));
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (ampelChip != null) Padding(padding: const EdgeInsets.only(bottom: 8), child: ampelChip),
      if (punkte.length >= 2)
        SizedBox(
          height: 160,
          child: LineChart(LineChartData(
            gridData: const FlGridData(show: true),
            titlesData: const FlTitlesData(
              leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 28)),
              rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            borderData: FlBorderData(show: false),
            extraLinesData: ExtraLinesData(verticalLines: marker),
            lineBarsData: [
              LineChartBarData(spots: punkte, isCurved: false, barWidth: 2, color: Colors.brown, dotData: const FlDotData(show: true)),
            ],
          )),
        )
      else
        const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('Noch keine Gemüll-Verlaufskurve (mind. 2 Messungen).')),
      if (proben.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Wrap(spacing: 6, runSpacing: 4, children: [
            for (final k in proben.take(6))
              Builder(builder: (_) {
                final a = ampelPuderzucker(befallProzent(k.milbenGesamt, k.bienenProbe));
                final p = befallProzent(k.milbenGesamt, k.bienenProbe);
                return Chip(
                  backgroundColor: _ampelColor(a).withAlpha(30),
                  label: Text('${k.durchgefuehrtAm.day}.${k.durchgefuehrtAm.month}. · ${p?.toStringAsFixed(1) ?? '—'} %'),
                );
              }),
          ]),
        ),
      const Padding(
        padding: EdgeInsets.only(top: 8),
        child: Text(
          'Höhenabhängig — im Gebirge die Saison-Schwelle ~4–6 Wochen später lesen. '
          'Milbenfall nach einer Winterbehandlung ist Erfolgskontrolle, kein Behandlungsanlass.',
          style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.grey),
        ),
      ),
    ]);
  }
}
