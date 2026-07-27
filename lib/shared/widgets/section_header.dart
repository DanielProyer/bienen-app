import 'package:flutter/material.dart';
import 'package:bienen_app/core/theme/app_tokens.dart';

class SectionHeader extends StatelessWidget {
  final String titel;
  final String? trailingText;
  final Widget? action;
  final IconData? symbol;
  const SectionHeader({super.key, required this.titel, this.trailingText, this.action, this.symbol});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: BeeTokens.sm),
      child: Row(
        // Ein Icon hat keine Textbaseline. Mit Symbol deshalb zentriert
        // ausrichten; ohne Symbol bleibt die bisherige Baseline-Ausrichtung
        // unverändert, damit die bestehenden Aufrufer gleich aussehen.
        crossAxisAlignment: symbol == null ? CrossAxisAlignment.baseline : CrossAxisAlignment.center,
        textBaseline: TextBaseline.alphabetic,
        children: [
          if (symbol != null) ...[
            Icon(symbol, size: 18, color: BeeTokens.honig),
            const SizedBox(width: BeeTokens.sm),
          ],
          Text(titel, style: BeeTokens.label),
          if (trailingText != null) ...[const SizedBox(width: BeeTokens.sm), Text(trailingText!, style: BeeTokens.gedaempft)],
          const Spacer(),
          ?action,
        ],
      ),
    );
  }
}
