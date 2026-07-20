import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:bienen_app/core/theme/app_theme.dart';
import 'package:bienen_app/features/aufgaben/presentation/providers/aufgaben_provider.dart';
import 'package:bienen_app/features/vermehrung/domain/vermehrung.dart';
import 'package:bienen_app/features/vermehrung/domain/vermehrungs_ketten.dart';

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
    return Card(
      color: (v.ueberfaellig ? Colors.red : AppColors.honey).withAlpha(18),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.hub, size: 18, color: AppColors.honeyDark),
            const SizedBox(width: 8),
            Expanded(child: Text(v.schritt.titel, style: const TextStyle(fontWeight: FontWeight.w600))),
            if (v.ueberfaellig)
              Padding(padding: const EdgeInsets.only(right: 6),
                  child: Text('überfällig', style: TextStyle(fontSize: 11, color: Colors.red.shade700, fontWeight: FontWeight.w600))),
            Text('$von – $bis', style: const TextStyle(fontSize: 12, color: AppColors.brown300)),
          ]),
          const SizedBox(height: 4),
          Text('$methodeLabel · ${v.schritt.ziel == KettenZiel.stammvolk ? 'Stammvolk' : 'Jungvolk'}',
              style: const TextStyle(fontSize: 12, color: AppColors.brown300)),
          const SizedBox(height: 6),
          Text(v.beschreibung, style: const TextStyle(fontSize: 13, color: AppColors.brown600)),
          const SizedBox(height: 8),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            TextButton(onPressed: () => _materialisieren(context, ref, 'uebersprungen'), child: const Text('Überspringen')),
            const SizedBox(width: 8),
            FilledButton(onPressed: () => _materialisieren(context, ref, 'offen'), child: const Text('Annehmen')),
          ]),
        ]),
      ),
    );
  }
}
