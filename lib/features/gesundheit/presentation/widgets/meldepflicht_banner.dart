import 'package:flutter/material.dart';
import 'package:bienen_app/features/gesundheit/domain/krankheit.dart';

/// Roter Meldepflicht-Banner für eine zu_bekaempfen- oder neobiota-Krankheit (mit Rechtsauskunft-Disclaimer).
/// Zeigt nichts an, wenn die Krankheit nicht meldepflichtig ist.
class MeldepflichtBanner extends StatelessWidget {
  final String krankheitKey;
  const MeldepflichtBanner({super.key, required this.krankheitKey});

  @override
  Widget build(BuildContext context) {
    if (!istMeldepflichtig(krankheitKey)) return const SizedBox.shrink();
    final k = katalogEintrag(krankheitKey);
    if (k == null) return const SizedBox.shrink();
    final neobiota = k.rechtskategorie == Rechtskategorie.neobiotaMeldung;
    final color = neobiota ? Colors.purple : Colors.red;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withAlpha(28),
        border: Border.all(color: color.withAlpha(120)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(neobiota ? Icons.report_gmailerrorred : Icons.warning_amber, color: color),
          const SizedBox(width: 8),
          Expanded(child: Text(neobiota ? 'Neobiota-Meldung: ${k.label}' : 'Meldepflicht aktiv: ${k.label}',
              style: TextStyle(fontWeight: FontWeight.bold, color: color))),
        ]),
        if (k.meldehinweis != null) Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(k.meldehinweis!),
        ),
        Padding(padding: const EdgeInsets.only(top: 6),
          child: Text('Sofort: ${k.sofortmassnahme}', style: const TextStyle(fontWeight: FontWeight.w500))),
        const Padding(padding: EdgeInsets.only(top: 6),
          child: Text('Rechtshinweis ohne Gewähr — verbindlich ist die zuständige Fachstelle / BLV.',
              style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.grey))),
      ]),
    );
  }
}
