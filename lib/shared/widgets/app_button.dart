import 'package:flutter/material.dart';
import 'package:bienen_app/core/theme/app_tokens.dart';

enum AppButtonKind { primaer, sekundaer, text, gefahr }

class AppButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final AppButtonKind kind;
  final bool busy;
  final bool full;
  const AppButton({super.key, required this.label, this.icon, this.onPressed,
      this.kind = AppButtonKind.primaer, this.busy = false, this.full = false});

  @override
  Widget build(BuildContext context) {
    final Widget child = busy
        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
        : (icon == null
            ? Text(label)
            : Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 20), const SizedBox(width: BeeTokens.sm), Text(label)]));
    final onTap = busy ? null : onPressed;
    final Widget btn = switch (kind) {
      AppButtonKind.primaer => FilledButton(onPressed: onTap, child: child),
      AppButtonKind.sekundaer => OutlinedButton(onPressed: onTap, child: child),
      AppButtonKind.text => TextButton(onPressed: onTap, child: child),
      AppButtonKind.gefahr => FilledButton(
          onPressed: onTap,
          style: FilledButton.styleFrom(backgroundColor: BeeTokens.gefahrText, foregroundColor: Colors.white),
          child: child),
    };
    return full ? SizedBox(width: double.infinity, child: btn) : btn;
  }
}
