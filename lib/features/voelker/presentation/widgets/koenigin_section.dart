import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bienen_app/features/auth/presentation/auth_providers.dart';
import 'package:bienen_app/features/voelker/domain/jahresfarbe.dart';
import 'package:bienen_app/features/voelker/domain/volk.dart';
import 'package:bienen_app/features/voelker/presentation/providers/voelker_provider.dart';
import 'package:bienen_app/features/voelker/presentation/widgets/volk_form.dart';

class KoeniginSection extends ConsumerWidget {
  final Volk volk;
  const KoeniginSection({super.key, required this.volk});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final k = volk.koenigin;
    final darf = ref.watch(darfSchreibenProvider);
    final rasseDefault = ref.watch(betriebsEinstellungenProvider).valueOrNull?.rasseDefault;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Expanded(
              child: Text('Königin',
                  style: TextStyle(fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis),
            ),
            if (darf && k == null)
              TextButton(
                // zuVolkId: die neue Königin gehoert diesem Volk — sonst
                // entstuende nur ein unsichtbarer Register-Eintrag.
                onPressed: () => showKoeniginForm(context, ref, zuVolkId: volk.id),
                child: const Text('Anlegen'),
              ),
            if (darf)
              TextButton(
                onPressed: () => showUmweiselnDialog(context, ref, volk),
                // Ohne Königin ist es keine Umweiselung, sondern eine Erst-Zuordnung.
                child: Text(k == null ? 'Zuordnen' : 'Umweiseln'),
              ),
          ]),
          if (k == null) ...[
            const Text('weisellos / nicht erfasst'),
            if (rasseDefault != null)
              Text('Rasse (Betriebs-Default): $rasseDefault',
                  style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.grey)),
          ] else ...[
            Text('Kennung: ${k.kennung ?? '—'}'),
            Text('Schlupfjahr: ${k.schlupfjahr ?? '—'}'
                '${k.schlupfjahr != null ? ' (${jahresfarbe(k.schlupfjahr!).label})' : ''}'),
            Text('Rasse: ${k.rasse ?? '—'} · Linie: ${k.linie ?? '—'}'),
            Text('Begattung: ${k.begattungsart}'),
          ],
        ]),
      ),
    );
  }
}
