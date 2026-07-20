import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:bienen_app/features/aufgaben/domain/aufgabe.dart';
import 'package:bienen_app/features/aufgaben/presentation/providers/aufgaben_provider.dart';
import 'package:bienen_app/features/auth/presentation/auth_providers.dart';
import 'package:bienen_app/features/voelker/presentation/providers/voelker_provider.dart';

class AufgabeFormPage extends ConsumerStatefulWidget {
  final String? aufgabeId; // null = neu
  const AufgabeFormPage({super.key, this.aufgabeId});
  @override
  ConsumerState<AufgabeFormPage> createState() => _AufgabeFormPageState();
}

class _AufgabeFormPageState extends ConsumerState<AufgabeFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _titel = TextEditingController();
  final _beschreibung = TextEditingController();
  String _kategorie = 'sonstiges';
  String _prioritaet = 'normal';
  DateTime _faelligAm = DateTime.now();
  String? _volkId;
  String? _standortId;
  Aufgabe? _basis; // beim Bearbeiten
  bool _initialisiert = false;

  static const _kategorien = {
    'durchsicht': 'Durchsicht', 'behandlung': 'Behandlung', 'fuetterung': 'Fütterung',
    'schutz': 'Schutz', 'werkstatt': 'Werkstatt', 'verwaltung': 'Verwaltung', 'sonstiges': 'Sonstiges',
  };

  @override
  void dispose() {
    _titel.dispose();
    _beschreibung.dispose();
    super.dispose();
  }

  void _uebernehmen(Aufgabe a) {
    _basis = a;
    _titel.text = a.titel;
    _beschreibung.text = a.beschreibung ?? '';
    _kategorie = a.kategorie;
    _prioritaet = a.prioritaet;
    _faelligAm = a.faelligAm;
    _volkId = a.volkId;
    _standortId = a.standortId;
  }

  Future<void> _speichern() async {
    if (!_formKey.currentState!.validate()) return;
    final b = _basis;
    final a = Aufgabe(
      id: b?.id ?? '',
      titel: _titel.text.trim(),
      beschreibung: _beschreibung.text.trim().isEmpty ? null : _beschreibung.text.trim(),
      kategorie: _kategorie,
      faelligAm: _faelligAm,
      prioritaet: _prioritaet,
      status: b?.status ?? 'offen',
      volkId: _volkId,
      standortId: _standortId,
      quelle: b?.quelle ?? 'manuell',
      regelKey: b?.regelKey,
      saisonJahr: b?.saisonJahr,
      ereignisId: b?.ereignisId,
      schrittKey: b?.schrittKey,
    );
    try {
      await ref.read(aufgabenListProvider.notifier).speichern(a);
      if (mounted) context.go('/aufgaben');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fehler: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Rollen-Guard (Gotcha 5): viewer hat hier nichts verloren.
    if (!ref.watch(darfSchreibenProvider)) {
      return Scaffold(
        appBar: AppBar(title: const Text('Aufgabe')),
        body: const Center(child: Text('Nur mit Schreibrechten verfügbar.')),
      );
    }
    // Stammdaten laden (Gotcha 2): erst rendern, wenn Dropdown-Daten da sind.
    final voelkerAsync = ref.watch(voelkerListProvider);
    final standorteAsync = ref.watch(standorteProvider);
    final aufgabenAsync = ref.watch(aufgabenListProvider);
    if (!voelkerAsync.hasValue || !standorteAsync.hasValue || !aufgabenAsync.hasValue) {
      return Scaffold(
        appBar: AppBar(title: const Text('Aufgabe')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (widget.aufgabeId != null && !_initialisiert) {
      for (final x in aufgabenAsync.value!) {
        if (x.id == widget.aufgabeId) {
          _uebernehmen(x);
          break;
        }
      }
    }
    _initialisiert = true;

    final voelker = voelkerAsync.value!.where((v) => v.status == 'aktiv' || v.id == _volkId).toList();
    final standorte = standorteAsync.value!;

    return Scaffold(
      appBar: AppBar(title: Text(widget.aufgabeId == null ? 'Neue Aufgabe' : 'Aufgabe bearbeiten')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _titel,
              decoration: const InputDecoration(labelText: 'Titel *'),
              maxLength: 200,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Titel angeben' : null,
            ),
            TextFormField(
              controller: _beschreibung,
              decoration: const InputDecoration(labelText: 'Beschreibung'),
              maxLines: 3,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _kategorie,
              decoration: const InputDecoration(labelText: 'Kategorie'),
              items: [
                for (final e in _kategorien.entries)
                  DropdownMenuItem(value: e.key, child: Text(e.value)),
              ],
              onChanged: (v) => setState(() => _kategorie = v ?? 'sonstiges'),
            ),
            const SizedBox(height: 12),
            InputDecorator(
              decoration: const InputDecoration(labelText: 'Fällig am'),
              child: InkWell(
                onTap: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: _faelligAm,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2040),
                  );
                  if (d != null) setState(() => _faelligAm = d);
                },
                child: Text(DateFormat('dd.MM.yyyy').format(_faelligAm)),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _prioritaet,
              decoration: const InputDecoration(labelText: 'Priorität'),
              items: const [
                DropdownMenuItem(value: 'hoch', child: Text('Hoch')),
                DropdownMenuItem(value: 'normal', child: Text('Normal')),
                DropdownMenuItem(value: 'niedrig', child: Text('Niedrig')),
              ],
              onChanged: (v) => setState(() => _prioritaet = v ?? 'normal'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              initialValue: _volkId,
              decoration: const InputDecoration(labelText: 'Volk (optional)'),
              items: [
                const DropdownMenuItem<String?>(value: null, child: Text('— kein Volk —')),
                for (final v in voelker) DropdownMenuItem(value: v.id, child: Text(v.name)),
              ],
              onChanged: (v) => setState(() => _volkId = v),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              initialValue: _standortId,
              decoration: const InputDecoration(labelText: 'Standort (optional)'),
              items: [
                const DropdownMenuItem<String?>(value: null, child: Text('— kein Standort —')),
                for (final s in standorte) DropdownMenuItem(value: s.id, child: Text(s.name)),
              ],
              onChanged: (v) => setState(() => _standortId = v),
            ),
            const SizedBox(height: 24),
            FilledButton(onPressed: _speichern, child: const Text('Speichern')),
          ],
        ),
      ),
    );
  }
}
