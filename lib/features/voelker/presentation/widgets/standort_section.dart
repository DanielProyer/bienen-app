import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bienen_app/features/auth/presentation/auth_providers.dart';
import 'package:bienen_app/features/voelker/domain/volk.dart';
import 'package:bienen_app/features/voelker/presentation/widgets/volk_form.dart';

class StandortSection extends ConsumerWidget {
  final Volk volk;
  const StandortSection({super.key, required this.volk});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = volk.standort;
    final darf = ref.watch(darfSchreibenProvider);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Text('Standort', style: TextStyle(fontWeight: FontWeight.bold)),
            const Spacer(),
            // Nur wenn das Volk noch keinen Stand hat: sonst wuerde ein
            // Neuanlegen es still umziehen. Umziehen laeuft ueber das
            // Volk-Formular (Standort-Dropdown).
            if (darf && s == null)
              TextButton(
                // zuVolk: der neue Stand gehoert diesem Volk — sonst entstuende
                // nur ein unsichtbarer Stammdaten-Eintrag.
                onPressed: () => showStandortForm(context, ref, zuVolk: volk),
                child: const Text('Standort anlegen'),
              ),
          ]),
          if (s == null)
            const Text('kein Standort zugeordnet')
          else ...[
            Text(s.name),
            if (s.amtlicheStandnummer != null) Text('Standnr.: ${s.amtlicheStandnummer}'),
            if (s.hoeheM != null) Text('${s.hoeheM} m'),
            if (s.sperrbezirk) const Text('⚠ Sperrbezirk', style: TextStyle(color: Colors.red)),
          ],
        ]),
      ),
    );
  }
}
