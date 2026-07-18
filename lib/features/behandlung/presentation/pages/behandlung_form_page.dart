import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:bienen_app/features/auth/presentation/auth_providers.dart';
import 'package:bienen_app/features/behandlung/domain/wirkstoff.dart';
import 'package:bienen_app/features/behandlung/presentation/providers/behandlung_provider.dart';
import 'package:bienen_app/features/material/presentation/providers/material_provider.dart';
import 'package:bienen_app/features/voelker/presentation/providers/voelker_provider.dart';

class BehandlungFormPage extends ConsumerStatefulWidget {
  final String volkId;
  const BehandlungFormPage({super.key, required this.volkId});
  @override
  ConsumerState<BehandlungFormPage> createState() => _BehandlungFormPageState();
}

class _BehandlungFormPageState extends ConsumerState<BehandlungFormPage> {
  late final Set<String> _volkIds = {widget.volkId};
  DateTime _datum = DateTime.now();
  final _praeparat = TextEditingController();
  String _wirkstoff = 'ameisensaeure';
  String _anwendungsart = 'dispenser_verdunster';
  final _menge = TextEditingController();
  String _einheit = 'ml';
  final _person = TextEditingController();
  String? _materialId;
  bool _speichert = false;
  bool _geladen = false;

  @override
  void initState() {
    super.initState();
    _person.text = Supabase.instance.client.auth.currentUser?.email ?? '';
    WidgetsBinding.instance.addPostFrameCallback((_) => _prewarm());
  }

  Future<void> _prewarm() async {
    try {
      await Future.wait([
        ref.read(materialListProvider.future),
        ref.read(voelkerListProvider.future),
      ]);
    } catch (_) {/* Dropdowns bleiben ggf. leer; Speichern zeigt Fehler */}
    if (mounted) setState(() => _geladen = true);
  }

  @override
  void dispose() {
    _praeparat.dispose();
    _menge.dispose();
    _person.dispose();
    super.dispose();
  }

  bool get _biotech => Anwendungsart.ohneChemie.contains(_anwendungsart);

  @override
  Widget build(BuildContext context) {
    if (!ref.watch(darfSchreibenProvider)) {
      return Scaffold(appBar: AppBar(title: const Text('Behandlung')),
          body: const Center(child: Text('Nur Lesezugriff.')));
    }
    final voelker = ref.watch(voelkerListProvider).valueOrNull ?? [];
    final materialien = (ref.watch(materialListProvider).valueOrNull ?? [])
        .where((m) => m.isConsumable && m.bereich == 'imkerei')
        .toList();

    // Bio-Banner: Warnung UND mindestens ein selektiertes Volk ist nicht konventionell.
    final selektierte = voelker.where((v) => _volkIds.contains(v.id)).toList();
    final zeigeBioBanner = bioKonformitaet(_wirkstoff, _anwendungsart) == BioBewertung.warnung &&
        selektierte.any((v) => v.bioStatus != 'konventionell');

    return Scaffold(
      appBar: AppBar(title: const Text('Behandlung erfassen')),
      body: !_geladen
          ? const Center(child: CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.all(16), children: [
              const Text('Völker (Sammelbehandlung)', style: TextStyle(fontWeight: FontWeight.bold)),
              Wrap(spacing: 8, children: [
                for (final v in voelker)
                  FilterChip(
                    label: Text(v.name),
                    selected: _volkIds.contains(v.id),
                    onSelected: (s) => setState(() => s ? _volkIds.add(v.id) : _volkIds.remove(v.id)),
                  ),
              ]),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Datum: ${_datum.day}.${_datum.month}.${_datum.year}'),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final d = await showDatePicker(context: context, initialDate: _datum,
                      firstDate: DateTime(2020), lastDate: DateTime(2100));
                  if (d != null) setState(() => _datum = d);
                },
              ),
              DropdownButtonFormField<String>(
                initialValue: _wirkstoff,
                decoration: const InputDecoration(labelText: 'Wirkstoff'),
                items: [for (final w in Wirkstoff.werte) DropdownMenuItem(value: w, child: Text(Wirkstoff.labels[w]!))],
                onChanged: (v) => setState(() => _wirkstoff = v!),
              ),
              DropdownButtonFormField<String>(
                initialValue: _anwendungsart,
                decoration: const InputDecoration(labelText: 'Anwendungsart'),
                items: [for (final a in Anwendungsart.werte) DropdownMenuItem(value: a, child: Text(Anwendungsart.labels[a]!))],
                onChanged: (v) => setState(() => _anwendungsart = v!),
              ),
              if (!_biotech)
                TextField(controller: _praeparat, decoration: const InputDecoration(labelText: 'Präparat (Handelsname)')),
              if (!_biotech)
                Row(children: [
                  Expanded(child: TextField(controller: _menge, keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Menge je Volk'))),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 100,
                    child: DropdownButtonFormField<String>(
                      initialValue: _einheit,
                      decoration: const InputDecoration(labelText: 'Einheit'),
                      items: const [
                        DropdownMenuItem(value: 'ml', child: Text('ml')),
                        DropdownMenuItem(value: 'g', child: Text('g')),
                        DropdownMenuItem(value: 'stueck', child: Text('Stück')),
                      ],
                      onChanged: (v) => setState(() => _einheit = v!),
                    ),
                  ),
                ]),
              DropdownButtonFormField<String?>(
                initialValue: _materialId,
                decoration: const InputDecoration(labelText: 'Material (Lager-Abbuchung, optional)'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('— keins —')),
                  for (final m in materialien) DropdownMenuItem(value: m.id, child: Text('${m.name} (${m.unit ?? '—'})')),
                ],
                onChanged: (v) => setState(() => _materialId = v),
              ),
              TextField(controller: _person, decoration: const InputDecoration(labelText: 'Verantwortliche Person')),
              if (zeigeBioBanner)
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.orange.withAlpha(38), borderRadius: BorderRadius.circular(8)),
                  child: Row(children: [
                    const Icon(Icons.warning_amber, color: Colors.orange),
                    const SizedBox(width: 8),
                    Expanded(child: Text(
                      'Nicht bio-konformer Wirkstoff auf: ${selektierte.where((v) => v.bioStatus != 'konventionell').map((v) => v.name).join(', ')}',
                    )),
                  ]),
                ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _speichert ? null : _speichern,
                icon: const Icon(Icons.save),
                label: Text(_speichert ? 'Speichert…' : 'Behandlung speichern'),
              ),
            ]),
    );
  }

  Future<void> _speichern() async {
    if (_volkIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mindestens ein Volk wählen.')));
      return;
    }
    setState(() => _speichert = true);
    try {
      await ref.read(behandlungAktionenProvider).erfassen(
            volkIds: _volkIds.toList(),
            datumBeginn: _datum,
            wirkstoff: _wirkstoff,
            anwendungsart: _anwendungsart,
            verantwortlichePerson: _person.text.trim(),
            praeparat: _biotech ? null : _praeparat.text.trim(),
            mengeProVolk: _biotech ? null : num.tryParse(_menge.text.replaceAll(',', '.')),
            einheit: _biotech ? null : _einheit,
            materialId: _materialId,
          );
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        setState(() => _speichert = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fehler: $e')));
      }
    }
  }
}
