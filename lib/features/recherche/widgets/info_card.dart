import 'package:flutter/material.dart';
import 'package:bienen_app/core/theme/app_theme.dart';

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
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: highlight ? AppColors.green50 : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: highlight
            ? const BorderSide(color: AppColors.green400)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon,
                color: highlight ? AppColors.green600 : AppColors.honey,
                size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: highlight ? AppColors.green800 : null,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    content,
                    style: TextStyle(
                      color: highlight
                          ? AppColors.green800
                          : AppColors.brown600,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
