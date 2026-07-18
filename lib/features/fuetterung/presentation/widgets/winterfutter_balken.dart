import 'package:flutter/material.dart';
import 'package:bienen_app/features/fuetterung/domain/fuetterung.dart';
import 'package:bienen_app/features/fuetterung/domain/winterfutter.dart';

/// Winterfutter-Fortschritt: Σ Auffütterung (Produktmasse) der laufenden Saison gegen das Ziel.
class WinterfutterBalken extends StatelessWidget {
  final List<Fuetterung> fuetterungen;
  final num zielKg;
  final DateTime stichtag;
  const WinterfutterBalken({
    super.key,
    required this.fuetterungen,
    required this.zielKg,
    required this.stichtag,
  });

  @override
  Widget build(BuildContext context) {
    final kg = winterfutterKg(fuetterungen, stichtag: stichtag);
    final prozent = winterfutterProzent(kg, zielKg.toDouble());
    final erreicht = kg >= zielKg;
    final color = erreicht ? Colors.green : Colors.amber.shade700;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Text('Winterfutter', style: TextStyle(fontWeight: FontWeight.bold)),
        const Spacer(),
        Text('${kg.toStringAsFixed(1)} / ${zielKg.toStringAsFixed(0)} kg (${(prozent * 100).floor()} %)',
            style: TextStyle(color: color, fontWeight: FontWeight.bold)),
      ]),
      const SizedBox(height: 6),
      ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: LinearProgressIndicator(
          value: prozent, minHeight: 10,
          backgroundColor: Colors.grey.withAlpha(40), color: color),
      ),
      const SizedBox(height: 4),
      Text(
        erreicht
            ? 'Ziel erreicht.'
            : 'Ziel noch nicht erreicht — erfasste Produktmasse Auffütterung (Richtwert 22 kg; alpine Hochlage eher 24–25). Produktgewicht ≠ eingelagerter Vorrat.',
        style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.grey),
      ),
    ]);
  }
}
