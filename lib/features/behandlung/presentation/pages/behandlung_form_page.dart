import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:bienen_app/features/auth/presentation/auth_providers.dart';
import 'package:bienen_app/features/behandlung/domain/wirkstoff.dart';
import 'package:bienen_app/features/behandlung/presentation/providers/behandlung_provider.dart';
import 'package:bienen_app/features/material/presentation/providers/material_provider.dart';
import 'package:bienen_app/features/voelker/presentation/providers/voelker_provider.dart';
import 'package:bienen_app/features/wissen/domain/behandlung_wissen.dart';
import 'package:bienen_app/features/wissen/presentation/widgets/wissen_info_button.dart';
import 'package:bienen_app/core/theme/app_tokens.dart';
import 'package:bienen_app/shared/widgets/app_button.dart';
import 'package:bienen_app/shared/widgets/empty_state.dart';
import 'package:bienen_app/shared/widgets/form_scaffold.dart';
import 'package:bienen_app/shared/widgets/section_header.dart';

class BehandlungFormPage extends ConsumerStatefulWidget {
  final String volkId;
  const BehandlungFormPage({super.key, required this.volkId});
  @override
  ConsumerState<BehandlungFormPage> createState() => _BehandlungFormPageState();
}

class _BehandlungFormPageState extends ConsumerState<BehandlungFormPage> {
  late final Set<String> _volkIds = {widget.volkId};
  DateTime _datum = DateTime.now();
  DateTime? _datumEnde;
  final _praeparat = TextEditingController();
  String _wirkstoff = 'ameisensaeure';
  String _anwendungsart = 'dispenser_verdunster';
  final _menge = TextEditingController();
  String _einheit = 'ml';
  final _konzentration = TextEditingController();
  final _charge = TextEditingController();
  final _aussentemp = TextEditingController();
  final _wartefrist = TextEditingController();
  final _indikation = TextEditingController(text: 'Varroabekämpfung');
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
    _konzentration.dispose();
    _charge.dispose();
    _aussentemp.dispose();
    _wartefrist.dispose();
    _indikation.dispose();
    _person.dispose();
    super.dispose();
  }

  bool get _biotech => Anwendungsart.ohneChemie.contains(_anwendungsart);

  @override
  Widget build(BuildContext context) {
    if (!ref.watch(darfSchreibenProvider)) {
      return Scaffold(
        appBar: AppBar(title: const Text('Behandlung')),
        body: const EmptyState(icon: Icons.lock_outline, titel: 'Nur Lesezugriff.'),
      );
    }
    final voelker = ref.watch(voelkerListProvider).valueOrNull ?? [];
    final materialien = (ref.watch(materialListProvider).valueOrNull ?? [])
        .where((m) => m.isConsumable && m.bereich == 'imkerei')
        .toList();

    // Bio-Banner: Warnung UND mindestens ein selektiertes Volk ist nicht konventionell.
    final selektierte = voelker.where((v) => _volkIds.contains(v.id)).toList();
    final zeigeBioBanner = bioKonformitaet(_wirkstoff, _anwendungsart) == BioBewertung.warnung &&
        selektierte.any((v) => v.bioStatus != 'konventionell');

    if (!_geladen) {
      return Scaffold(
        appBar: AppBar(title: const Text('Behandlung erfassen')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    return FormScaffold(
      titel: 'Behandlung erfassen',
      bodenleiste: AppButton(
        label: 'Behandlung speichern',
        icon: Icons.save,
        busy: _speichert,
        full: true,
        onPressed: _speichern,
      ),
      child: ListView(padding: const EdgeInsets.all(BeeTokens.lg), children: [
              const SectionHeader(titel: 'Völker (Sammelbehandlung)'),
              Wrap(spacing: BeeTokens.sm, children: [
                for (final v in voelker)
                  FilterChip(
                    label: Text(v.name),
                    selected: _volkIds.contains(v.id),
                    onSelected: (s) => setState(() => s ? _volkIds.add(v.id) : _volkIds.remove(v.id)),
                  ),
              ]),
              const SizedBox(height: BeeTokens.md),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Beginn: ${_datum.day}.${_datum.month}.${_datum.year}'),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final d = await showDatePicker(context: context, initialDate: _datum,
                      firstDate: DateTime(2020), lastDate: DateTime(2100));
                  if (d != null) setState(() => _datum = d);
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(_datumEnde == null
                    ? 'Ende: — (optional, mehrtägig)'
                    : 'Ende: ${_datumEnde!.day}.${_datumEnde!.month}.${_datumEnde!.year}'),
                trailing: _datumEnde == null
                    ? const Icon(Icons.calendar_today)
                    : IconButton(icon: const Icon(Icons.clear), onPressed: () => setState(() => _datumEnde = null)),
                onTap: () async {
                  final d = await showDatePicker(context: context, initialDate: _datumEnde ?? _datum,
                      firstDate: _datum, lastDate: DateTime(2100));
                  if (d != null) setState(() => _datumEnde = d);
                },
              ),
              Row(children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _wirkstoff,
                    decoration: const InputDecoration(labelText: 'Wirkstoff'),
                    items: [for (final w in Wirkstoff.werte) DropdownMenuItem(value: w, child: Text(Wirkstoff.labels[w]!))],
                    onChanged: (v) => setState(() => _wirkstoff = v!),
                  ),
                ),
                WissenInfoButton(wissenKey: kBehandlungWirkstoffWissen[_wirkstoff] ?? ''),
              ]),
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
                  const SizedBox(width: BeeTokens.md),
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
              if (!_biotech)
                Row(children: [
                  Expanded(child: TextField(controller: _konzentration,
                      decoration: const InputDecoration(labelText: 'Konzentration (z.B. 60%)'))),
                  const SizedBox(width: BeeTokens.md),
                  Expanded(child: TextField(controller: _charge,
                      decoration: const InputDecoration(labelText: 'Charge'))),
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
              Row(children: [
                Expanded(child: TextField(controller: _aussentemp, keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Aussentemp. °C'))),
                const SizedBox(width: BeeTokens.md),
                Expanded(child: TextField(controller: _wartefrist, keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Wartefrist (Tage)'))),
              ]),
              TextField(controller: _indikation, decoration: const InputDecoration(labelText: 'Indikation')),
              TextField(controller: _person, decoration: const InputDecoration(labelText: 'Verantwortliche Person')),
              if (zeigeBioBanner)
                Container(
                  margin: const EdgeInsets.only(top: BeeTokens.md),
                  padding: const EdgeInsets.all(BeeTokens.md),
                  decoration: BoxDecoration(color: BeeSignal.warnung.flaeche, borderRadius: BorderRadius.circular(BeeTokens.rKarte)),
                  child: Row(children: [
                    Icon(Icons.warning_amber, color: BeeSignal.warnung.text),
                    const SizedBox(width: BeeTokens.sm),
                    Expanded(child: Text(
                      'Nicht bio-konformer Wirkstoff auf: ${selektierte.where((v) => v.bioStatus != 'konventionell').map((v) => v.name).join(', ')}',
                      style: TextStyle(color: BeeSignal.warnung.text),
                    )),
                  ]),
                ),
            ]),
    );
  }

  String? _leerZuNull(String s) => s.trim().isEmpty ? null : s.trim();

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
            datumEnde: _datumEnde,
            wirkstoff: _wirkstoff,
            anwendungsart: _anwendungsart,
            verantwortlichePerson: _person.text.trim(),
            praeparat: _biotech ? null : _leerZuNull(_praeparat.text),
            mengeProVolk: _biotech ? null : num.tryParse(_menge.text.replaceAll(',', '.')),
            einheit: _biotech ? null : _einheit,
            konzentration: _biotech ? null : _leerZuNull(_konzentration.text),
            charge: _biotech ? null : _leerZuNull(_charge.text),
            aussentemperaturC: num.tryParse(_aussentemp.text.replaceAll(',', '.')),
            wartefristTage: int.tryParse(_wartefrist.text),
            indikation: _leerZuNull(_indikation.text),
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
