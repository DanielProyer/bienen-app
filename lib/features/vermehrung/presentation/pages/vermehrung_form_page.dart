import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:bienen_app/core/theme/app_tokens.dart';
import 'package:bienen_app/features/auth/presentation/auth_providers.dart';
import 'package:bienen_app/features/vermehrung/domain/vermehrung.dart';
import 'package:bienen_app/features/vermehrung/domain/vermehrungs_ereignis.dart';
import 'package:bienen_app/features/vermehrung/domain/vermehrungs_ketten.dart';
import 'package:bienen_app/features/vermehrung/presentation/providers/vermehrung_provider.dart';
import 'package:bienen_app/features/voelker/presentation/providers/voelker_provider.dart';
import 'package:bienen_app/shared/widgets/app_button.dart';
import 'package:bienen_app/shared/widgets/empty_state.dart';
import 'package:bienen_app/shared/widgets/form_scaffold.dart';
import 'package:bienen_app/shared/widgets/section_header.dart';

class VermehrungFormPage extends ConsumerStatefulWidget {
  final String volkId; // Stammvolk-Kontext
  const VermehrungFormPage({super.key, required this.volkId});
  @override
  ConsumerState<VermehrungFormPage> createState() => _VermehrungFormPageState();
}

class _VermehrungFormPageState extends ConsumerState<VermehrungFormPage> {
  String _methode = 'brutableger';
  DateTime _erstelltAm = DateTime.now();
  bool _os = false;
  String? _jungvolkId;
  final _notiz = TextEditingController();
  bool _speichert = false;

  @override
  void dispose() { _notiz.dispose(); super.dispose(); }

  Future<void> _speichern() async {
    setState(() => _speichert = true);
    try {
      await ref.read(vermehrungListProvider.notifier).speichern(VermehrungsEreignis(
            id: '', methode: _methode, erstelltAm: _erstelltAm, stammvolkId: widget.volkId,
            jungvolkId: _jungvolkId,
            osBeiErstellung: (kVermehrungsMethoden[_methode]?.brutfreiBeiErstellung ?? false) && _os,
            notiz: _notiz.text.trim().isEmpty ? null : _notiz.text.trim()));
      if (mounted) context.go('/voelker/${widget.volkId}');
    } catch (e) {
      if (mounted) { setState(() => _speichert = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fehler: $e'))); }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!ref.watch(darfSchreibenProvider)) {
      return Scaffold(appBar: AppBar(title: const Text('Vermehrung')),
          body: const EmptyState(icon: Icons.lock_outline, titel: 'Nur mit Schreibrechten verfügbar.'));
    }
    final voelker = ref.watch(voelkerListProvider).valueOrNull ?? const [];
    final andere = voelker.where((v) => v.id != widget.volkId).toList();
    final meta = kVermehrungsMethoden[_methode]!;
    final heute = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final inZukunft = _erstelltAm.isAfter(heute);
    final langeHer = _erstelltAm.isBefore(heute.subtract(const Duration(days: 60)));
    final vorschau = kettenVorschauFuer(_methode, _erstelltAm);

    return FormScaffold(
      titel: 'Ableger/Vermehrung erfassen',
      busy: _speichert,
      bodenleiste: AppButton(
          label: 'Vermehrung speichern', full: true, busy: _speichert, onPressed: _speichern),
      child: ListView(padding: const EdgeInsets.all(BeeTokens.lg), children: [
        DropdownButtonFormField<String>(
          initialValue: _methode,
          decoration: const InputDecoration(labelText: 'Methode'),
          items: [for (final m in kVermehrungsMethoden.values) DropdownMenuItem(value: m.key, child: Text(m.label))],
          onChanged: (v) => setState(() => _methode = v!),
        ),
        const SizedBox(height: BeeTokens.md),
        InputDecorator(
          decoration: InputDecoration(labelText: 'Erstellt am',
              helperText: inZukunft ? 'Datum liegt in der Zukunft' : (langeHer ? 'Über 60 Tage her — Kette evtl. schon abgelaufen' : null),
              helperStyle: (inZukunft || langeHer) ? const TextStyle(color: BeeTokens.warnungText, fontWeight: FontWeight.w600) : null),
          child: InkWell(
            onTap: () async {
              final d = await showDatePicker(context: context, initialDate: _erstelltAm,
                  firstDate: DateTime(2020), lastDate: DateTime(2100));
              if (d != null) setState(() => _erstelltAm = d);
            },
            child: Text(DateFormat('dd.MM.yyyy').format(_erstelltAm)),
          ),
        ),
        if (meta.brutfreiBeiErstellung)
          SwitchListTile(contentPadding: EdgeInsets.zero,
              title: const Text('Oxalsäure bei Erstellung'),
              subtitle: const Text('Brutfreies Jungvolk direkt behandelt (Notiz).'),
              value: _os, onChanged: (on) => setState(() => _os = on)),
        const SizedBox(height: BeeTokens.sm),
        DropdownButtonFormField<String?>(
          initialValue: _jungvolkId,
          decoration: const InputDecoration(labelText: 'Jungvolk (optional, später verknüpfbar)'),
          items: [
            const DropdownMenuItem<String?>(value: null, child: Text('— später —')),
            for (final v in andere) DropdownMenuItem(value: v.id, child: Text(v.name)),
          ],
          onChanged: (v) => setState(() => _jungvolkId = v),
        ),
        TextField(controller: _notiz, decoration: const InputDecoration(labelText: 'Notiz'), maxLines: 2),
        const SizedBox(height: BeeTokens.lg),
        const SectionHeader(titel: 'Ketten-Vorschau'),
        for (final s in vorschau)
          Padding(padding: const EdgeInsets.symmetric(vertical: 2),
            child: Text('Tag ${s.schritt.tagVon}${s.schritt.tagBis != s.schritt.tagVon ? '–${s.schritt.tagBis}' : ''} · '
                '${DateFormat('dd.MM.').format(s.von)}: ${s.schritt.titel} · '
                '${s.schritt.ziel == KettenZiel.stammvolk ? 'Stammvolk' : 'Jungvolk'}',
                style: BeeTokens.gedaempft)),
        if (_methode == 'flugling')
          Padding(padding: const EdgeInsets.only(top: BeeTokens.xs),
            child: Text('Hinweis: Flugling bei regem Flug 11–15 Uhr bilden.',
                style: BeeTokens.gedaempft.copyWith(color: BeeTokens.warnungText))),
      ]),
    );
  }
}
