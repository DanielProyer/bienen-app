import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:bienen_app/core/theme/app_tokens.dart';
import 'package:bienen_app/features/monitoring/presentation/providers/monitoring_provider.dart';
import 'package:bienen_app/shared/widgets/app_card.dart';
import 'package:bienen_app/shared/widgets/section_header.dart';

class SensorStatusCard extends ConsumerWidget {
  const SensorStatusCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final latest = ref.watch(latestReadingProvider);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(titel: 'Sensor-Status'),
          if (latest != null) ...[
            _StatusRow(
              icon: Icons.thermostat,
              label: 'Temperatur',
              value: latest.temperatureC != null
                  ? '${NumberFormat('#0.0', 'de_CH').format(latest.temperatureC)} °C'
                  : '--',
              farbe: _tempFarbe(latest.temperatureC),
            ),
            const SizedBox(height: BeeTokens.sm),
            _StatusRow(
              icon: Icons.water_drop_outlined,
              label: 'Luftfeuchtigkeit',
              value: latest.humidityPct != null
                  ? '${latest.humidityPct!.round()} %'
                  : '--',
              farbe: BeeTokens.textSekundaer,
            ),
            const SizedBox(height: BeeTokens.sm),
            _StatusRow(
              icon: Icons.battery_std,
              label: 'Batterie',
              value: latest.batteryPct != null ? '${latest.batteryPct} %' : '--',
              farbe: _batterieFarbe(latest.batteryPct),
            ),
            const SizedBox(height: BeeTokens.sm),
            _StatusRow(
              icon: Icons.sync,
              label: 'Letzte Sync',
              value: _timeAgo(latest.recordedAt),
              farbe: _syncFarbe(latest.recordedAt),
            ),
          ] else
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: BeeTokens.sm),
                child: Text('Keine Sensordaten', style: BeeTokens.gedaempft),
              ),
            ),
        ],
      ),
    );
  }

  /// Sensorwerte über Signal-Rollen (kalt = Info, zu warm = Gefahr).
  /// Schwellen unverändert gegenüber der Vorversion.
  Color _tempFarbe(double? temp) {
    if (temp == null) return BeeTokens.textGedaempft;
    if (temp < 10) return BeeSignal.info.text;
    if (temp > 40) return BeeSignal.gefahr.text;
    return BeeSignal.erfolg.text;
  }

  Color _batterieFarbe(int? pct) {
    if (pct == null) return BeeTokens.textGedaempft;
    if (pct < 20) return BeeSignal.gefahr.text;
    if (pct < 50) return BeeSignal.warnung.text;
    return BeeSignal.erfolg.text;
  }

  Color _syncFarbe(DateTime lastSync) {
    final ago = DateTime.now().difference(lastSync);
    if (ago.inHours > 2) return BeeSignal.gefahr.text;
    if (ago.inMinutes > 30) return BeeSignal.warnung.text;
    return BeeSignal.erfolg.text;
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
  final Color farbe;

  const _StatusRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.farbe,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: farbe),
        const SizedBox(width: BeeTokens.sm),
        Expanded(child: Text(label, style: BeeTokens.label)),
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: farbe,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}
