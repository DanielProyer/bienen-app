import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bienen_app/features/durchsicht/sprache/data/sprach_controller.dart';
import 'package:bienen_app/features/durchsicht/sprache/domain/sprache_erkenner.dart';

/// Toggle-Mikro. [onEndText] bekommt jedes End-Transkript (Diktat: anhängen; Kommando: parsen).
class SprachMikro extends ConsumerWidget {
  final String mikroId;
  final void Function(String endText) onEndText;
  final String label;
  final bool kompakt; // Diktat = kompakt (nur Icon), Kommando = mit Label/Status
  const SprachMikro({super.key, required this.mikroId, required this.onEndText, this.label = 'Sprechen', this.kompakt = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ctrl = ref.read(sprachControllerProvider.notifier);
    if (!ctrl.verfuegbar) return const SizedBox.shrink(); // Firefox/Safari: kein Mikro
    final z = ref.watch(sprachControllerProvider);
    final aktiv = z.aktivesMikro == mikroId;
    final fehler = aktiv && z.status == ErkennerStatus.fehler;

    void toggle() => aktiv ? ctrl.stoppen() : ctrl.starten(mikroId, onEndText);

    if (kompakt) {
      return IconButton(
        icon: Icon(aktiv ? Icons.mic : Icons.mic_none, color: aktiv ? Colors.red : null),
        tooltip: aktiv ? 'Diktat stoppen' : 'Diktieren',
        onPressed: toggle,
      );
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      FilledButton.tonalIcon(
        onPressed: toggle,
        icon: Icon(aktiv ? Icons.stop_circle : Icons.mic),
        label: Text(aktiv ? 'hört zu … (tippen zum Stoppen)' : label),
        style: aktiv ? FilledButton.styleFrom(backgroundColor: Colors.red.shade100) : null,
      ),
      if (aktiv && z.interim.isNotEmpty)
        Padding(padding: const EdgeInsets.only(top: 4, left: 4), child: Text('„${z.interim}…"', style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.grey))),
      if (fehler)
        const Padding(padding: EdgeInsets.only(top: 4, left: 4), child: Text('Kein Netz / Mikro — Spracheingabe pausiert (Tippen geht).', style: TextStyle(fontSize: 12, color: Colors.red))),
    ]);
  }
}
