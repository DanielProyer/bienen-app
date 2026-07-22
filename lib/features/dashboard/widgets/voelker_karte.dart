import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:bienen_app/core/theme/app_tokens.dart';
import 'package:bienen_app/core/util/relativ_datum.dart';
import 'package:bienen_app/features/durchsicht/presentation/providers/durchsicht_provider.dart';
import 'package:bienen_app/features/gesundheit/presentation/providers/gesundheit_provider.dart';
import 'package:bienen_app/features/voelker/presentation/providers/voelker_provider.dart';
import 'package:bienen_app/shared/widgets/app_button.dart';
import 'package:bienen_app/shared/widgets/app_card.dart';
import 'package:bienen_app/shared/widgets/app_list_tile.dart';
import 'package:bienen_app/shared/widgets/section_header.dart';

/// Cockpit-Karte „Völker": je aktives Volk Ampel + Name + „gesehen: `<relativ>`".
class VoelkerKarte extends ConsumerWidget {
  const VoelkerKarte({super.key});

  /// Gesundheits-Ampel über Signal-Rollen (statt roher Hex-Werte).
  static Color _ampelFarbe(String status) => switch (status) {
        'unauffaellig' => BeeSignal.erfolg.text,
        'beobachtung' => BeeSignal.warnung.text,
        'krank' || 'sperre' => BeeSignal.gefahr.text,
        _ => BeeTokens.textGedaempft,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final voelker = ref.watch(aktiveVoelkerProvider);
    final letzte = ref.watch(letzteDurchsichtMapProvider);
    final heute = DateTime.now();

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            titel: 'Völker',
            action: AppButton(label: 'alle →', kind: AppButtonKind.text, onPressed: () => context.go('/voelker')),
          ),
          if (voelker.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: BeeTokens.sm),
              child: InkWell(
                onTap: () => context.go('/voelker'),
                child: const Text('Noch kein Volk erfasst — jetzt anlegen →',
                    style: TextStyle(color: BeeTokens.textGedaempft)),
              ),
            ),
          for (final v in voelker)
            AppListTile(
              statusFarbe: _ampelFarbe(v.gesundheitsstatus),
              titel: v.name,
              untertitel: 'gesehen: ${relativGesehen(letzte[v.id]?.durchgefuehrtAm, heute)}',
              trailing: ref.watch(aktiveMeldepflichtProvider(v.id)).isNotEmpty
                  ? Icon(Icons.report, size: 18, color: BeeSignal.gefahr.text)
                  : null,
              onTap: () => context.go('/voelker/${v.id}'),
            ),
        ],
      ),
    );
  }
}
