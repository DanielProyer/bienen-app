import 'package:flutter/material.dart';
import 'package:bienen_app/core/theme/app_tokens.dart';

class SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;

  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: BeeTokens.titel),
        if (subtitle != null) ...[
          const SizedBox(height: BeeTokens.xs),
          Text(subtitle!, style: BeeTokens.gedaempft),
        ],
      ],
    );
  }
}
