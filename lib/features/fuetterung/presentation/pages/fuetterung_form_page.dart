import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:bienen_app/features/aufgaben/domain/saison_regeln.dart';
import 'package:bienen_app/features/auth/presentation/auth_providers.dart';
import 'package:bienen_app/features/fuetterung/domain/futterart.dart';
import 'package:bienen_app/features/fuetterung/presentation/providers/fuetterung_provider.dart';
import 'package:bienen_app/features/material/presentation/providers/material_provider.dart';
import 'package:bienen_app/features/phaenologie/domain/phaenologie.dart';
import 'package:bienen_app/features/phaenologie/presentation/providers/phaenologie_provider.dart';
import 'package:bienen_app/features/voelker/presentation/providers/voelker_provider.dart';

class FuetterungFormPage extends ConsumerStatefulWidget {
  final String volkId;
  const FuetterungFormPage({super.key, required this.volkId});
  @override
  ConsumerState<FuetterungFormPage> createState() => _FuetterungFormPageState();
}

class _FuetterungFormPageState extends ConsumerState<FuetterungFormPage> {
  late final Set<String> _volkIds = {widget.volkId};
  DateTime _datum = DateTime.now();
  String _zweck = 'auffuetterung';
  String _futterart = 'zuckerwasser_3_2';
  bool _bio = false; // Fail-safe: kein stiller Bio-Falsch-Positiv; Warnung führt zur bewussten Bio-Markierung
  final _menge = TextEditingController();
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
        ref.read(phaenologieProvider.future),
        ref.read(betriebsEinstellungenProvider.future),
      ]);
    } catch (_) {/* Dropdowns bleiben ggf. leer; Speichern zeigt Fehler */}
    if (mounted) setState(() => _geladen = true);
  }

  @override
  void dispose() {
    _menge.dispose();
    _person.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!ref.watch(darfSchreibenProvider)) {
      return Scaffold(appBar: AppBar(title: const Text('Fütterung')),
          body: const Center(child: Text('Nur Lesezugriff.')));
    }
    final voelker = ref.watch(voelkerListProvider).valueOrNull ?? [];
    final materialien = (ref.watch(materialListProvider).valueOrNull ?? [])
        .where((m) => m.isConsumable && m.bereich == 'imkerei')
        .toList();

    final selektierte = voelker.where((v) => _volkIds.contains(v.id)).toList();
    final zeigeBioBanner = !_bio && selektierte.any((v) => v.bioStatus != 'konventionell');

    final einst = ref.watch(betriebsEinstellungenProvider).valueOrNull;
    final beob = ref.watch(phaenologieProvider).valueOrNull ?? const [];
    final fenster = einst == null
        ? null
        : trachtFensterFuer(
            jahr: _datum.year,
            flatOffset: einst.saisonOffsetDefaultTage,
            beobachtungen: beob,
            einstellungen: einst);
    final honigHinweis = honigreinheitHinweis(
        futterart: _futterart, zweck: _zweck, datum: _datum, trachtFenster: fenster);

    return Scaffold(
      appBar: AppBar(title: const Text('Fütterung erfassen')),
      body: !_geladen
          ? const Center(child: CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.all(16), children: [
              const Text('Völker (Sammelfütterung)', style: TextStyle(fontWeight: FontWeight.bold)),
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
              const SizedBox(height: 8),
              const Text('Zweck'),
              Wrap(spacing: 8, children: [
                for (final z in Zweck.werte)
                  ChoiceChip(
                    label: Text(Zweck.labels[z]!),
                    selected: _zweck == z,
                    onSelected: (_) => setState(() => _zweck = z),
                  ),
              ]),
              DropdownButtonFormField<String>(
                initialValue: _futterart,
                decoration: const InputDecoration(labelText: 'Futterart'),
                items: [for (final f in Futterart.werte) DropdownMenuItem(value: f, child: Text(Futterart.labels[f]!))],
                onChanged: (v) => setState(() => _futterart = v!),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Bio-zertifiziert'),
                value: _bio,
                onChanged: (v) => setState(() => _bio = v),
              ),
              TextField(controller: _menge, keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Menge PRO Volk (kg)')),
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
                      'Nicht bio-zertifiziertes Futter auf: ${selektierte.where((v) => v.bioStatus != 'konventionell').map((v) => v.name).join(', ')}',
                    )),
                  ]),
                ),
              if (honigHinweis != HonigreinheitHinweis.keiner)
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: Colors.amber.withAlpha(38), borderRadius: BorderRadius.circular(8)),
                  child: Row(children: [
                    const Icon(Icons.info_outline, color: Colors.amber),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(honigHinweis == HonigreinheitHinweis.notfuetterung
                          ? 'Notfütterung: Honig aus dieser Periode nicht als reinen Honig ernten (BGD 4.2).'
                          : 'Zuckerfütterung während der Tracht kann den Honig verfälschen (BGD 4.2).'),
                    ),
                  ]),
                ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _speichert ? null : _speichern,
                icon: const Icon(Icons.save),
                label: Text(_speichert ? 'Speichert…' : 'Fütterung speichern'),
              ),
            ]),
    );
  }

  Future<void> _speichern() async {
    final menge = num.tryParse(_menge.text.replaceAll(',', '.'));
    if (_volkIds.isEmpty || menge == null || menge <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Mindestens ein Volk und eine Menge > 0 nötig.')));
      return;
    }
    setState(() => _speichert = true);
    try {
      await ref.read(fuetterungAktionenProvider).erfassen(
            volkIds: _volkIds.toList(),
            durchgefuehrtAm: _datum,
            zweck: _zweck,
            futterart: _futterart,
            bioZertifiziert: _bio,
            mengeProVolkKg: menge,
            materialId: _materialId,
            verantwortlichePerson: _person.text.trim().isEmpty ? null : _person.text.trim(),
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
