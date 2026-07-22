import 'package:flutter/material.dart';
import 'package:bienen_app/core/theme/app_tokens.dart';

class AppListTile extends StatelessWidget {
  final Widget? leading;
  final Color? statusFarbe;
  final String titel;
  final String? untertitel;
  final Widget? trailing;
  final VoidCallback? onTap;
  const AppListTile({super.key, this.leading, this.statusFarbe, required this.titel,
      this.untertitel, this.trailing, this.onTap});

  @override
  Widget build(BuildContext context) {
    final Widget? lead = leading ??
        (statusFarbe != null
            ? Container(width: 11, height: 11, decoration: BoxDecoration(color: statusFarbe, shape: BoxShape.circle))
            : null);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(BeeTokens.rKarte),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: BeeTokens.tapMin),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: BeeTokens.md, vertical: BeeTokens.md),
          child: Row(children: [
            if (lead != null) ...[lead, const SizedBox(width: BeeTokens.md)],
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(titel, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: BeeTokens.textPrimaer)),
              if (untertitel != null)
                Padding(padding: const EdgeInsets.only(top: 2), child: Text(untertitel!, style: BeeTokens.gedaempft)),
            ])),
            if (trailing != null) trailing! else if (onTap != null) const Icon(Icons.chevron_right, color: BeeTokens.chevron),
          ]),
        ),
      ),
    );
  }
}
