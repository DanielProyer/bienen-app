import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:bienen_app/core/theme/app_theme.dart';
import 'package:bienen_app/features/monitoring/presentation/providers/monitoring_provider.dart';

class SensorStatusCard extends ConsumerWidget {
  const SensorStatusCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final latest = ref.watch(latestReadingProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.sensors, color: AppColors.brown600, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Sensor-Status',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppColors.brown600,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (latest != null) ...[
              _StatusRow(
                icon: Icons.thermostat,
                label: 'Temperatur',
                value: latest.temperatureC != null
                    ? '${NumberFormat('#0.0', 'de_CH').format(latest.temperatureC)} °C'
                    : '--',
                color: _tempColor(latest.temperatureC),
              ),
              const SizedBox(height: 10),
              _StatusRow(
                icon: Icons.water_drop_outlined,
                label: 'Luftfeuchtigkeit',
                value: latest.humidityPct != null
                    ? '${latest.humidityPct!.round()} %'
                    : '--',
                color: AppColors.brown600,
              ),
              const SizedBox(height: 10),
              _StatusRow(
                icon: Icons.battery_std,
                label: 'Batterie',
                value: latest.batteryPct != null
                    ? '${latest.batteryPct} %'
                    : '--',
                color: _batteryColor(latest.batteryPct),
              ),
              const SizedBox(height: 10),
              _StatusRow(
                icon: Icons.sync,
                label: 'Letzte Sync',
                value: _timeAgo(latest.recordedAt),
                color: _syncColor(latest.recordedAt),
              ),
            ] else
              Center(
                child: Text(
                  'Keine Sensordaten',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.brown300,
                      ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Color _tempColor(double? temp) {
    if (temp == null) return AppColors.brown300;
    if (temp < 10) return Colors.blue;
    if (temp > 40) return Colors.red;
    return AppColors.green600;
  }

  Color _batteryColor(int? pct) {
    if (pct == null) return AppColors.brown300;
    if (pct < 20) return Colors.red;
    if (pct < 50) return AppColors.amber600;
    return AppColors.green600;
  }

  Color _syncColor(DateTime lastSync) {
    final ago = DateTime.now().difference(lastSync);
    if (ago.inHours > 2) return Colors.red;
    if (ago.inMinutes > 30) return AppColors.amber600;
    return AppColors.green600;
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'gerade eben';
    if (diff.inMinutes < 60) return 'vor ${diff.inMinutes} Min.';
    if (diff.inHours < 24) return 'vor ${diff.inHours} Std.';
    return 'vor ${diff.inDays} Tagen';
  }
}

class _StatusRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatusRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.brown600,
                ),
          ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: color,
              ),
        ),
      ],
    );
  }
}
