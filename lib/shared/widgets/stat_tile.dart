import 'package:flutter/material.dart';
import 'package:bienen_app/core/theme/app_tokens.dart';

class StatTile extends StatelessWidget {
  final String label;
  final String wert;
  const StatTile({super.key, required this.label, required this.wert});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: BeeTokens.md, vertical: BeeTokens.md),
      decoration: BoxDecoration(
        color: BeeTokens.karte,
        borderRadius: BorderRadius.circular(BeeTokens.rKarte),
        border: Border.all(color: BeeTokens.rand, width: 0.5)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Text(label, style: BeeTokens.gedaempft),
        const SizedBox(height: BeeTokens.xs),
        FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(wert,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w500, color: BeeTokens.textPrimaer,
            fontFeatures: [FontFeature.tabularFigures()]))),
      ]),
    );
  }
}
