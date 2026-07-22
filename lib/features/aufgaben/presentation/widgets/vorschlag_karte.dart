import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:bienen_app/core/theme/app_tokens.dart';
import 'package:bienen_app/features/aufgaben/domain/saison_regeln.dart';
import 'package:bienen_app/features/aufgaben/presentation/providers/aufgaben_provider.dart';
import 'package:bienen_app/features/voelker/presentation/providers/voelker_provider.dart';
import 'package:bienen_app/shared/widgets/app_button.dart';
import 'package:bienen_app/shared/widgets/app_card.dart';

/// Karte für einen Generator-Vorschlag: Annehmen (ggf. Völker-Auswahl) / Überspringen.
class VorschlagKarte extends ConsumerWidget {
  final AufgabenVorschlag vorschlag;
  const VorschlagKarte({super.key, required this.vorschlag});

  Future<void> _annehmen(BuildContext context, WidgetRef ref) async {
    final notifier = ref.read(aufgabenListProvider.notifier);
    try {
      if (vorschlag.regel.ebene == RegelEbene.betrieb) {
        await notifier.vorschlagAnnehmen(vorschlag);
        return;
      }
      final voelker = ref.read(aktiveVoelkerProvider);
      if (voelker.length == 1) {
        await notifier.vorschlagAnnehmen(vorschlag, volkIds: [voelker.single.id]);
        return;
      }
      if (!context.mounted) return;
      final gewaehlt = await showDialog<List<String>>(
        context: context,
        builder: (_) => _VoelkerAuswahlDialog(
            titel: vorschlag.regel.titel,
            voelker: [for (final v in voelker) (id: v.id, name: v.name)]),
      );
      if (gewaehlt == null || gewaehlt.isEmpty) return;
      await notifier.vorschlagAnnehmen(vorschlag, volkIds: gewaehlt);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fehler: $e')));
      }
    }
  }

  Future<void> _ueberspringen(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(aufgabenListProvider.notifier).vorschlagUeberspringen(vorschlag);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fehler: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = vorschlag.regel;
    final von = DateFormat('dd.MM.').format(vorschlag.fensterStart);
    final bis = DateFormat('dd.MM.').format(vorschlag.faelligAm);
    return Padding(
      padding: const EdgeInsets.only(bottom: BeeTokens.sm),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.auto_awesome, size: 18, color: BeeTokens.honig),
              const SizedBox(width: BeeTokens.sm),
              Expanded(child: Text(r.titel, style: BeeTokens.abschnitt)),
              Text('$von – $bis', style: BeeTokens.gedaempft),
            ]),
            const SizedBox(height: BeeTokens.xs),
            Text(vorschlag.beschreibung, style: BeeTokens.text),
            const SizedBox(height: BeeTokens.md),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              AppButton(
                label: 'Überspringen',
                kind: AppButtonKind.text,
                onPressed: () => _ueberspringen(context, ref),
              ),
              const SizedBox(width: BeeTokens.sm),
              AppButton(
                label: 'Annehmen',
                onPressed: () => _annehmen(context, ref),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

class _VoelkerAuswahlDialog extends StatefulWidget {
  final String titel;
  final List<({String id, String name})> voelker;
  const _VoelkerAuswahlDialog({required this.titel, required this.voelker});
  @override
  State<_VoelkerAuswahlDialog> createState() => _VoelkerAuswahlDialogState();
}

class _VoelkerAuswahlDialogState extends State<_VoelkerAuswahlDialog> {
  late final Set<String> _gewaehlt = widget.voelker.map((v) => v.id).toSet();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.titel),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          for (final v in widget.voelker)
            CheckboxListTile(
              value: _gewaehlt.contains(v.id),
              title: Text(v.name),
              onChanged: (on) => setState(() => on == true ? _gewaehlt.add(v.id) : _gewaehlt.remove(v.id)),
            ),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen')),
        FilledButton(
          onPressed: () => Navigator.pop(context, _gewaehlt.toList()),
          child: const Text('Anlegen'),
        ),
      ],
    );
  }
}
