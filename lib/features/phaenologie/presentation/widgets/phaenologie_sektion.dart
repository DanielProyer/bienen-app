import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bienen_app/core/theme/app_theme.dart';
import 'package:bienen_app/features/phaenologie/domain/beobachtung.dart';
import 'package:bienen_app/features/phaenologie/domain/phaenologie.dart';
import 'package:bienen_app/features/phaenologie/presentation/providers/phaenologie_provider.dart';

/// Erfassung der beobachteten Zeigerpflanzen-Blüte (Frühjahr + Tracht) fürs laufende Saisonjahr.
/// Eigenständige Sektion mit eigenem Inline-Save — unabhängig vom Betriebs-Formular.
class PhaenologieSektion extends ConsumerWidget {
  const PhaenologieSektion({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(phaenologieProvider);
    final jahr = DateTime.now().year;
    final beob = async.valueOrNull ?? const <PhaenoBeobachtung>[];
    PhaenoBeobachtung? fuer(PhaenoAnker a) {
      for (final b in beob) {
        if (b.jahr == jahr && b.anker == a) return b;
      }
      return null;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Zeigerpflanzen-Blüte (Phänologie)', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text('Wann die Zeigerpflanze an deinem Standort blüht, verschiebt die Saisonaufgaben '
            'präziser als das feste Offset (Jahr $jahr).', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        const SizedBox(height: 8),
        _AnkerZeile(anker: PhaenoAnker.fruehjahr, jahr: jahr, vorhanden: fuer(PhaenoAnker.fruehjahr)),
        const SizedBox(height: 8),
        _AnkerZeile(anker: PhaenoAnker.tracht, jahr: jahr, vorhanden: fuer(PhaenoAnker.tracht)),
      ],
    );
  }
}

class _AnkerZeile extends ConsumerStatefulWidget {
  final PhaenoAnker anker;
  final int jahr;
  final PhaenoBeobachtung? vorhanden;
  const _AnkerZeile({required this.anker, required this.jahr, required this.vorhanden});
  @override
  ConsumerState<_AnkerZeile> createState() => _AnkerZeileState();
}

class _AnkerZeileState extends ConsumerState<_AnkerZeile> {
  late String _key;
  DateTime? _datum;
  bool _speichert = false;

  @override
  void initState() {
    super.initState();
    _key = widget.vorhanden?.indikatorKey ??
        (widget.anker == PhaenoAnker.tracht ? kDefaultIndikatorTracht : kDefaultIndikatorFruehjahr);
    _datum = widget.vorhanden?.bluehAm;
  }

  bool get _unplausibel {
    if (_datum == null) return false;
    final ref = indikatorVon(_key);
    if (ref == null) return false;
    return (doyVon(_datum!) - ref.referenzDoy).abs() > 45;
  }

  Future<void> _speichern() async {
    if (_datum == null) return;
    setState(() => _speichert = true);
    try {
      await ref.read(phaenologieProvider.notifier).speichern(PhaenoBeobachtung(
            jahr: widget.jahr, anker: widget.anker, indikatorKey: _key, bluehAm: _datum!));
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Blühbeobachtung gespeichert.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fehler: $e')));
      }
    } finally {
      if (mounted) setState(() => _speichert = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final label = widget.anker == PhaenoAnker.tracht ? 'Tracht-Anker' : 'Frühjahrs-Anker';
    final pflanzen = indikatorenFuer(widget.anker);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
        Row(children: [
          Expanded(
            child: DropdownButton<String>(
              isExpanded: true,
              value: _key,
              items: [for (final p in pflanzen) DropdownMenuItem(value: p.key, child: Text(p.name))],
              onChanged: (v) => setState(() => _key = v!),
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: () async {
              final d = await showDatePicker(
                context: context,
                initialDate: _datum ?? DateTime(widget.jahr, 6, 1),
                firstDate: DateTime(widget.jahr, 1, 1),
                lastDate: DateTime(widget.jahr, 12, 31),
              );
              if (d != null) setState(() => _datum = d);
            },
            child: Text(_datum == null ? 'Datum' : '${_datum!.day}.${_datum!.month}.'),
          ),
          IconButton(
            icon: _speichert
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.save_outlined),
            onPressed: (_datum == null || _speichert) ? null : _speichern,
          ),
        ]),
        if (_unplausibel)
          const Text('Ungewöhnliches Blühdatum — bitte prüfen.',
              style: TextStyle(fontSize: 12, color: AppColors.amber800, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
