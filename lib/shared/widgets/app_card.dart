import 'package:flutter/material.dart';
import 'package:bienen_app/core/theme/app_tokens.dart';

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  const AppCard({super.key, required this.child, this.padding = const EdgeInsets.all(BeeTokens.lg), this.onTap});

  @override
  Widget build(BuildContext context) {
    final content = Padding(padding: padding, child: child);
    return Container(
      decoration: BoxDecoration(
        color: BeeTokens.karte,
        borderRadius: BorderRadius.circular(BeeTokens.rKarte),
        border: Border.all(color: BeeTokens.rand, width: 0.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: onTap == null ? content : InkWell(onTap: onTap, child: content),
    );
  }
}
