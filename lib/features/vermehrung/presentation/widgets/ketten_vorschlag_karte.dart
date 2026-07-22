import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:bienen_app/core/theme/app_tokens.dart';
import 'package:bienen_app/features/aufgaben/presentation/providers/aufgaben_provider.dart';
import 'package:bienen_app/features/vermehrung/domain/vermehrung.dart';
import 'package:bienen_app/features/vermehrung/domain/vermehrungs_ketten.dart';
import 'package:bienen_app/shared/widgets/app_button.dart';
import 'package:bienen_app/shared/widgets/app_card.dart';
import 'package:bienen_app/shared/widgets/status_pill.dart';

class KettenVorschlagKarte extends ConsumerWidget {
  final KettenVorschlag vorschlag;
  const KettenVorschlagKarte({super.key, required this.vorschlag});

  Future<void> _materialisieren(BuildContext context, WidgetRef ref, String status) async {
    try {
      await ref.read(aufgabenListProvider.notifier)
          .kettenMaterialisieren(aufgabeAusKettenVorschlag(vorschlag, status: status));
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fehler: $e')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = vorschlag;
    final methodeLabel = kVermehrungsMethoden[v.ereignis.methode]?.label ?? v.ereignis.methode;
    final von = DateFormat('dd.MM.').format(v.fensterStart);
    final bis = DateFormat('dd.MM.').format(v.faelligAm);
    return Padding(
      padding: const EdgeInsets.only(bottom: BeeTokens.sm),
      child: AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.hub, size: 18, color: BeeTokens.honig),
            const SizedBox(width: BeeTokens.sm),
            Expanded(child: Text(v.schritt.titel, style: BeeTokens.abschnitt)),
            if (v.ueberfaellig) ...[
              const StatusPill(label: 'überfällig', signal: BeeSignal.gefahr),
              const SizedBox(width: BeeTokens.sm),
            ],
            Text('$von – $bis', style: BeeTokens.gedaempft),
          ]),
          const SizedBox(height: BeeTokens.xs),
          Text('$methodeLabel · ${v.schritt.ziel == KettenZiel.stammvolk ? 'Stammvolk' : 'Jungvolk'}',
              style: BeeTokens.gedaempft),
          const SizedBox(height: BeeTokens.sm),
          Text(v.beschreibung, style: BeeTokens.text),
          const SizedBox(height: BeeTokens.md),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            AppButton(label: 'Überspringen', kind: AppButtonKind.text,
                onPressed: () => _materialisieren(context, ref, 'uebersprungen')),
            const SizedBox(width: BeeTokens.sm),
            AppButton(label: 'Annehmen',
                onPressed: () => _materialisieren(context, ref, 'offen')),
          ]),
        ]),
      ),
    );
  }
}
