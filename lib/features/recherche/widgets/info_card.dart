import 'package:flutter/material.dart';
import 'package:bienen_app/core/theme/app_tokens.dart';

class InfoCard extends StatelessWidget {
  final String title;
  final String content;
  final IconData icon;
  final bool highlight;

  const InfoCard({
    super.key,
    required this.title,
    required this.content,
    required this.icon,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final bg = highlight ? BeeSignal.erfolg.flaeche : BeeTokens.karte;
    final borderColor = highlight ? BeeSignal.erfolg.text : BeeTokens.rand;
    final borderWidth = highlight ? 1.0 : 0.5;
    final iconColor = highlight ? BeeSignal.erfolg.text : BeeTokens.honig;
    final titleColor = highlight ? BeeSignal.erfolg.text : BeeTokens.textPrimaer;
    final contentColor =
        highlight ? BeeSignal.erfolg.text : BeeTokens.textGedaempft;

    return Container(
      margin: const EdgeInsets.only(bottom: BeeTokens.md),
      padding: const EdgeInsets.all(BeeTokens.lg),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(BeeTokens.rKarte),
        border: Border.all(color: borderColor, width: borderWidth),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 24),
          const SizedBox(width: BeeTokens.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: titleColor,
                  ),
                ),
                const SizedBox(height: BeeTokens.xs + 2),
                Text(
                  content,
                  style: TextStyle(
                    color: contentColor,
                    height: 1.4,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
