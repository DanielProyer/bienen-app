import 'package:flutter/material.dart';
import 'package:bienen_app/core/theme/app_tokens.dart';

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String titel;
  final String? text;
  final Widget? aktion;
  const EmptyState({super.key, required this.icon, required this.titel, this.text, this.aktion});

  @override
  Widget build(BuildContext context) {
    return Center(child: Padding(padding: const EdgeInsets.all(BeeTokens.xl), child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 40, color: BeeTokens.textGedaempft),
      const SizedBox(height: BeeTokens.md),
      Text(titel, textAlign: TextAlign.center, style: BeeTokens.abschnitt),
      if (text != null) ...[const SizedBox(height: BeeTokens.sm), Text(text!, textAlign: TextAlign.center, style: BeeTokens.gedaempft)],
      if (aktion != null) ...[const SizedBox(height: BeeTokens.lg), aktion!],
    ])));
  }
}
