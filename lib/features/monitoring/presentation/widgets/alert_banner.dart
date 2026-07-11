import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:bienen_app/features/monitoring/presentation/providers/monitoring_provider.dart';

class AlertBanner extends ConsumerWidget {
  const AlertBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alerts = ref.watch(activeAlertsProvider);
    if (alerts.isEmpty) return const SizedBox.shrink();

    return Column(
      children: alerts.map((alert) {
        final color = _alertColor(alert.alertType);
        final icon = _alertIcon(alert.alertType);

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: color.withAlpha(30),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withAlpha(100)),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      alert.alertLabel,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: color,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    if (alert.message != null)
                      Text(
                        alert.message!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: color.withAlpha(200),
                            ),
                      ),
                    Text(
                      DateFormat('dd.MM. HH:mm').format(alert.createdAt.toLocal()),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: color.withAlpha(150),
                            fontSize: 11,
                          ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.close, color: color, size: 18),
                onPressed: () {
                  ref.read(allAlertsProvider.notifier).acknowledge(alert.id);
                },
                tooltip: 'Bestätigen',
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Color _alertColor(String type) {
    switch (type) {
      case 'swarm':
        return Colors.red.shade700;
      case 'low_battery':
        return Colors.orange.shade700;
      case 'offline':
        return Colors.grey.shade700;
      case 'tracht_start':
        return Colors.green.shade700;
      case 'tracht_end':
        return Colors.blue.shade700;
      default:
        return Colors.orange.shade700;
    }
  }

  IconData _alertIcon(String type) {
    switch (type) {
      case 'swarm':
        return Icons.warning_amber_rounded;
      case 'low_battery':
        return Icons.battery_alert;
      case 'offline':
        return Icons.wifi_off;
      case 'tracht_start':
        return Icons.trending_up;
      case 'tracht_end':
        return Icons.trending_down;
      default:
        return Icons.notifications_active;
    }
  }
}
