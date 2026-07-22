import 'package:flutter/material.dart';
import 'package:bienen_app/core/theme/app_tokens.dart';
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
    final signal = neobiota ? BeeSignal.info : BeeSignal.gefahr;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: BeeTokens.sm),
      padding: const EdgeInsets.all(BeeTokens.md),
      decoration: BoxDecoration(
        color: signal.flaeche,
        border: Border.all(color: signal.text.withAlpha(120)),
        borderRadius: BorderRadius.circular(BeeTokens.rKarte),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(neobiota ? Icons.report_gmailerrorred : Icons.warning_amber, color: signal.text),
          const SizedBox(width: BeeTokens.sm),
          Expanded(child: Text(neobiota ? 'Neobiota-Meldung: ${k.label}' : 'Meldepflicht aktiv: ${k.label}',
              style: TextStyle(fontWeight: FontWeight.bold, color: signal.text))),
        ]),
        if (k.meldehinweis != null) Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(k.meldehinweis!),
        ),
        Padding(padding: const EdgeInsets.only(top: 6),
          child: Text('Sofort: ${k.sofortmassnahme}', style: const TextStyle(fontWeight: FontWeight.w500))),
        const Padding(padding: EdgeInsets.only(top: 6),
          child: Text('Rechtshinweis ohne Gewähr — verbindlich ist die zuständige Fachstelle / BLV.',
              style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: BeeTokens.textGedaempft))),
      ]),
    );
  }
}
