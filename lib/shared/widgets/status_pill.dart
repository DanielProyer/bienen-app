import 'package:flutter/material.dart';
import 'package:bienen_app/core/theme/app_tokens.dart';

class StatusPill extends StatelessWidget {
  final String label;
  final BeeSignal signal;
  const StatusPill({super.key, required this.label, this.signal = BeeSignal.neutral});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: BeeTokens.md, vertical: 5),
      decoration: BoxDecoration(color: signal.flaeche, borderRadius: BorderRadius.circular(BeeTokens.rPille)),
      child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: signal.text)),
    );
  }
}
