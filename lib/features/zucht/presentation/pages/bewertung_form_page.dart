import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:bienen_app/core/theme/app_theme.dart';
import 'package:bienen_app/features/auth/presentation/auth_providers.dart';
import 'package:bienen_app/features/voelker/domain/volk.dart';
import 'package:bienen_app/features/voelker/presentation/providers/voelker_provider.dart';
import 'package:bienen_app/features/wissen/domain/bewertung_wissen.dart';
import 'package:bienen_app/features/wissen/presentation/widgets/wissen_info_button.dart';
import 'package:bienen_app/features/zucht/domain/bewertung.dart';
import 'package:bienen_app/features/zucht/presentation/providers/bewertung_provider.dart';

/// Katalog-Lookup ohne package:collection (Muster regelVon in saison_regeln.dart).
Volk? _findeVolk(List<Volk> vs, String id) {
  for (final v in vs) {
    if (v.id == id) return v;
  }
  return null;
}

VolkBewertung? _findeBewertung(List<VolkBewertung> bs, String id) {
  for (final b in bs) {
    if (b.id == id) return b;
  }
  return null;
}

class BewertungFormPage extends ConsumerStatefulWidget {
  final String volkId;
  final String? bewertungId; // null = neu
  const BewertungFormPage({super.key, required this.volkId, this.bewertungId});
  @override
  ConsumerState<BewertungFormPage> createState() => _BewertungFormPageState();
}

class _BewertungFormPageState extends ConsumerState<BewertungFormPage> {
  final _werte = <String, int>{for (final a in kBewertungsAchsen) a.key: 3};
  DateTime _datum = DateTime.now();
  final _notiz = TextEditingController();
  bool _speichert = false;
  bool _initialisiert = false;

  @override
  void dispose() { _notiz.dispose(); super.dispose(); }

  void _uebernehmen(VolkBewertung b) {
    for (final a in kBewertungsAchsen) { _werte[a.key] = b.wertFuer(a.key); }
    _datum = b.bewertetAm;
    _notiz.text = b.notiz ?? '';
  }

  Future<void> _speichern(String? koeniginId) async {
    setState(() => _speichert = true);
    try {
      await ref.read(bewertungenProvider.notifier).speichern(VolkBewertung(
            id: widget.bewertungId ?? '', volkId: widget.volkId, koeniginId: koeniginId, bewertetAm: _datum,
            sanftmut: _werte['sanftmut']!, wabensitz: _werte['wabensitz']!, schwarmtraegheit: _werte['schwarmtraegheit']!,
            brutbild: _werte['brutbild']!, volksstaerke: _werte['volksstaerke']!, gesundheit: _werte['gesundheit']!,
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
      return Scaffold(appBar: AppBar(title: const Text('Bewertung')),
          body: const Center(child: Text('Nur mit Schreibrechten verfügbar.')));
    }
    final voelker = ref.watch(voelkerListProvider).valueOrNull;
    if (voelker == null) {
      return Scaffold(appBar: AppBar(title: const Text('Bewertung')),
          body: const Center(child: CircularProgressIndicator()));
    }
    final volk = _findeVolk(voelker, widget.volkId);
    // Edit-Modus vorbefüllen
    if (!_initialisiert && widget.bewertungId != null) {
      final b = _findeBewertung(
          ref.read(bewertungenFuerVolkProvider(widget.volkId)), widget.bewertungId!);
      if (b != null) _uebernehmen(b);
    }
    _initialisiert = true;
    final inaktiv = volk != null && volk.status != 'aktiv';

    return Scaffold(
      appBar: AppBar(title: Text(widget.bewertungId == null ? 'Volk bewerten' : 'Bewertung bearbeiten')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        if (inaktiv)
          const Padding(padding: EdgeInsets.only(bottom: 8),
            child: Text('Volk inaktiv — Bewertung wird trotzdem gespeichert.',
                style: TextStyle(color: AppColors.amber800, fontWeight: FontWeight.w600))),
        ListTile(contentPadding: EdgeInsets.zero,
          title: Text('Datum: ${DateFormat('dd.MM.yyyy').format(_datum)}'),
          trailing: const Icon(Icons.calendar_today),
          onTap: () async {
            final d = await showDatePicker(context: context, initialDate: _datum,
                firstDate: DateTime(2020), lastDate: DateTime.now());
            if (d != null) setState(() => _datum = d);
          },
        ),
        const SizedBox(height: 8),
        for (final a in kBewertungsAchsen) ...[
          Row(mainAxisSize: MainAxisSize.min, children: [
            Text(a.label, style: const TextStyle(fontWeight: FontWeight.w600)),
            WissenInfoButton(wissenKey: kBewertungAchseWissen[a.key] ?? ''),
          ]),
          const SizedBox(height: 4),
          SegmentedButton<int>(
            segments: [for (var i = 1; i <= 4; i++) ButtonSegment(value: i, label: Text('$i'))],
            selected: {_werte[a.key]!},
            onSelectionChanged: (s) => setState(() => _werte[a.key] = s.first),
          ),
          Text(a.anker[_werte[a.key]! - 1], style: const TextStyle(fontSize: 12, color: AppColors.brown300)),
          const SizedBox(height: 12),
        ],
        TextField(controller: _notiz, decoration: const InputDecoration(labelText: 'Notiz'), maxLines: 2),
        const SizedBox(height: 20),
        FilledButton(onPressed: _speichert ? null : () => _speichern(volk?.koeniginId),
            child: Text(_speichert ? 'Speichert…' : 'Bewertung speichern')),
      ]),
    );
  }
}
