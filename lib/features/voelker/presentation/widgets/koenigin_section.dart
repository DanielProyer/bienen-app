import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bienen_app/features/auth/presentation/auth_providers.dart';
import 'package:bienen_app/features/voelker/domain/jahresfarbe.dart';
import 'package:bienen_app/features/voelker/domain/volk.dart';
import 'package:bienen_app/features/voelker/presentation/widgets/volk_form.dart';

class KoeniginSection extends ConsumerWidget {
  final Volk volk;
  const KoeniginSection({super.key, required this.volk});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final k = volk.koenigin;
    final darf = ref.watch(darfSchreibenProvider);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Text('Koenigin', style: TextStyle(fontWeight: FontWeight.bold)),
            const Spacer(),
            if (darf && k == null)
              TextButton(
                onPressed: () => showKoeniginForm(context, ref),
                child: const Text('Koenigin anlegen'),
              ),
            if (darf)
              TextButton(
                onPressed: () => showUmweiselnDialog(context, ref, volk),
                child: const Text('Umweiseln'),
              ),
          ]),
          if (k == null)
            const Text('weisellos / nicht erfasst')
          else ...[
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
