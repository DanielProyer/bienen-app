import 'package:flutter/material.dart';
import 'package:bienen_app/core/theme/app_tokens.dart';

class SectionHeader extends StatelessWidget {
  final String titel;
  final String? trailingText;
  final Widget? action;
  const SectionHeader({super.key, required this.titel, this.trailingText, this.action});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: BeeTokens.sm),
      child: Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
        Text(titel, style: BeeTokens.label),
        if (trailingText != null) ...[const SizedBox(width: BeeTokens.sm), Text(trailingText!, style: BeeTokens.gedaempft)],
        const Spacer(),
        ?action,
      ]),
    );
  }
}
