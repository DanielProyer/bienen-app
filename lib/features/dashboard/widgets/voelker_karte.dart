import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:bienen_app/core/theme/app_theme.dart';
import 'package:bienen_app/core/util/relativ_datum.dart';
import 'package:bienen_app/features/durchsicht/presentation/providers/durchsicht_provider.dart';
import 'package:bienen_app/features/gesundheit/presentation/providers/gesundheit_provider.dart';
import 'package:bienen_app/features/voelker/presentation/providers/voelker_provider.dart';

/// Cockpit-Karte „Völker": je aktives Volk Ampel + Name + „gesehen: `<relativ>`".
class VoelkerKarte extends ConsumerWidget {
  const VoelkerKarte({super.key});

  static const _ampel = {
    'unauffaellig': Color(0xFF5CB85C),
    'beobachtung': Color(0xFFF0AD4E),
    'krank': Color(0xFFD9534F),
    'sperre': Color(0xFFD9534F),
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final voelker = ref.watch(aktiveVoelkerProvider);
    final letzte = ref.watch(letzteDurchsichtMapProvider);
    final heute = DateTime.now();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.hive, size: 20, color: AppColors.honeyDark),
              const SizedBox(width: 8),
              const Expanded(child: Text('Völker', style: TextStyle(fontWeight: FontWeight.bold))),
              TextButton(onPressed: () => context.go('/voelker'), child: const Text('alle →')),
            ]),
            if (voelker.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: InkWell(
                  onTap: () => context.go('/voelker'),
                  child: const Text('Noch kein Volk erfasst — jetzt anlegen →',
                      style: TextStyle(color: AppColors.brown300)),
                ),
              ),
            for (final v in voelker)
              InkWell(
                onTap: () => context.go('/voelker/${v.id}'),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(children: [
                    Container(
                      width: 10, height: 10,
                      decoration: BoxDecoration(
                          color: _ampel[v.gesundheitsstatus] ?? AppColors.brown300,
                          shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                        child: Text(v.name,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500))),
                    if (ref.watch(aktiveMeldepflichtProvider(v.id)).isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Icon(Icons.report, size: 16, color: Colors.red.shade700),
                      ),
                    Text('gesehen: ${relativGesehen(letzte[v.id]?.durchgefuehrtAm, heute)}',
                        style: const TextStyle(fontSize: 12, color: AppColors.brown300)),
                  ]),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
