import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bienen_app/features/durchsicht/presentation/providers/durchsicht_provider.dart';
import 'package:bienen_app/features/voelker/domain/jahresfarbe.dart';
import 'package:bienen_app/features/voelker/domain/volk.dart';

Color _farbe(Jahresfarbe f) => switch (f) {
      Jahresfarbe.weiss => Colors.white,
      Jahresfarbe.gelb => Colors.amber,
      Jahresfarbe.rot => Colors.red,
      Jahresfarbe.gruen => Colors.green,
      Jahresfarbe.blau => Colors.blue,
    };

class VolkCard extends ConsumerWidget {
  final Volk volk;
  final VoidCallback onTap;
  const VolkCard({super.key, required this.volk, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jahr = volk.koenigin?.schlupfjahr;
    final letzte = ref.watch(letzteDurchsichtMapProvider)[volk.id];
    final zuletztText = letzte == null
        ? 'noch nie gesehen'
        : 'zuletzt: ${DateTime.now().difference(letzte.durchgefuehrtAm).inDays} Tage';
    return Card(
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: jahr != null ? _farbe(jahresfarbe(jahr)) : Colors.grey.shade300,
          child: jahr == null ? const Icon(Icons.help_outline, size: 18) : null,
        ),
        title: Text(volk.name),
        subtitle: Text([
          volk.standort?.name ?? 'kein Standort',
          if (volk.koenigin?.rasse != null) volk.koenigin!.rasse!,
          zuletztText,
        ].join(' · ')),
        trailing: Chip(label: Text(volk.status), visualDensity: VisualDensity.compact),
      ),
    );
  }
}
