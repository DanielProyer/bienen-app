import 'package:flutter/material.dart';
import 'package:bienen_app/core/theme/app_tokens.dart';
import 'package:bienen_app/shared/widgets/app_button.dart';

/// Bestätigung als Bodenblatt (Daumen-erreichbar) statt zentralem Dialog.
Future<bool> confirmSheet(BuildContext context, {required String titel, String? text,
    String bestaetigenLabel = 'Bestätigen', bool gefahr = false}) async {
  final ok = await showModalBottomSheet<bool>(
    context: context,
    builder: (ctx) => SafeArea(child: Padding(padding: const EdgeInsets.all(BeeTokens.lg),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(titel, style: BeeTokens.abschnitt),
        if (text != null) ...[const SizedBox(height: BeeTokens.sm), Text(text, style: BeeTokens.text)],
        const SizedBox(height: BeeTokens.lg),
        AppButton(label: bestaetigenLabel, kind: gefahr ? AppButtonKind.gefahr : AppButtonKind.primaer, full: true, onPressed: () => Navigator.pop(ctx, true)),
        const SizedBox(height: BeeTokens.sm),
        AppButton(label: 'Abbrechen', kind: AppButtonKind.text, full: true, onPressed: () => Navigator.pop(ctx, false)),
      ]))),
  );
  return ok ?? false;
}
