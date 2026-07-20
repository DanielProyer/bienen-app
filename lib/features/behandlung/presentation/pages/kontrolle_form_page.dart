import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:bienen_app/features/auth/presentation/auth_providers.dart';
import 'package:bienen_app/features/behandlung/domain/ampel_schwellen.dart';
import 'package:bienen_app/features/behandlung/domain/varroa_kontrolle.dart';
import 'package:bienen_app/features/behandlung/presentation/providers/behandlung_provider.dart';
import 'package:bienen_app/features/wissen/domain/behandlung_wissen.dart';
import 'package:bienen_app/features/wissen/presentation/widgets/wissen_info_button.dart';

class KontrolleFormPage extends ConsumerStatefulWidget {
  final String volkId;
  const KontrolleFormPage({super.key, required this.volkId});
  @override
  ConsumerState<KontrolleFormPage> createState() => _KontrolleFormPageState();
}

class _KontrolleFormPageState extends ConsumerState<KontrolleFormPage> {
  String _methode = 'gemuell';
  DateTime _datum = DateTime.now();
  final _milben = TextEditingController();
  final _messdauer = TextEditingController(text: '3');
  final _bienen = TextEditingController(text: '300');
  final _notiz = TextEditingController();
  bool _speichert = false;

  @override
  void dispose() {
    _milben.dispose();
    _messdauer.dispose();
    _bienen.dispose();
    _notiz.dispose();
    super.dispose();
  }

  int? get _milbenVal => int.tryParse(_milben.text);

  // Ohne eingegebene Milbenzahl kein Richtwert (nicht faelschlich "gruen" bei leerem Feld).
  Ampel get _ampel => _milbenVal == null
      ? Ampel.keinRichtwert
      : ampelFuerKontrolle(
          methode: _methode, milbenGesamt: _milbenVal!,
          messdauerTage: int.tryParse(_messdauer.text), bienenProbe: int.tryParse(_bienen.text), monat: _datum.month,
        );

  @override
  Widget build(BuildContext context) {
    if (!ref.watch(darfSchreibenProvider)) {
      return Scaffold(appBar: AppBar(title: const Text('Milbendiagnose')),
          body: const Center(child: Text('Nur Lesezugriff.')));
    }
    final gemuell = _methode == 'gemuell';
    return Scaffold(
      appBar: AppBar(title: const Text('Milbendiagnose')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Row(children: [
          Expanded(
            child: Wrap(spacing: 8, children: [
              for (final m in const ['gemuell', 'puderzucker', 'auswaschung'])
                ChoiceChip(
                  label: Text(switch (m) { 'gemuell' => 'Gemüll', 'puderzucker' => 'Puderzucker', _ => 'Auswaschung' }),
                  selected: _methode == m,
                  onSelected: (_) => setState(() => _methode = m),
                ),
            ]),
          ),
          WissenInfoButton(wissenKey: kVarroaMethodeWissen[_methode] ?? ''),
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
        TextField(controller: _milben, keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Milben gezählt'), onChanged: (_) => setState(() {})),
        if (gemuell)
          TextField(controller: _messdauer, keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Messdauer (Tage)'), onChanged: (_) => setState(() {})),
        if (!gemuell)
          TextField(controller: _bienen, keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Bienen in der Probe (~300)'), onChanged: (_) => setState(() {})),
        const SizedBox(height: 8),
        _AmpelZeile(methode: _methode, ampel: _ampel, milben: _milbenVal,
            messdauer: int.tryParse(_messdauer.text), bienen: int.tryParse(_bienen.text)),
        TextField(controller: _notiz, decoration: const InputDecoration(labelText: 'Notiz')),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _speichert ? null : _speichern,
          icon: const Icon(Icons.save),
          label: Text(_speichert ? 'Speichert…' : 'Speichern'),
        ),
      ]),
    );
  }

  Future<void> _speichern() async {
    if (_milbenVal == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bitte Milbenzahl eingeben.')));
      return;
    }
    setState(() => _speichert = true);
    try {
      await ref.read(kontrollenFuerVolkProvider(widget.volkId).notifier).speichern(VarroaKontrolle(
            id: '', volkId: widget.volkId, durchgefuehrtAm: _datum, methode: _methode,
            messdauerTage: _methode == 'gemuell' ? int.tryParse(_messdauer.text) : null,
            milbenGesamt: _milbenVal!,
            bienenProbe: _methode != 'gemuell' ? int.tryParse(_bienen.text) : null,
            notiz: _notiz.text.trim().isEmpty ? null : _notiz.text.trim(),
          ));
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        setState(() => _speichert = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fehler: $e')));
      }
    }
  }
}

class _AmpelZeile extends StatelessWidget {
  final String methode;
  final Ampel ampel;
  final int? milben, messdauer, bienen;
  const _AmpelZeile({required this.methode, required this.ampel, this.milben, this.messdauer, this.bienen});

  @override
  Widget build(BuildContext context) {
    final wert = methode == 'gemuell'
        ? milbenProTag(milben, messdauer)?.toStringAsFixed(1)
        : befallProzent(milben, bienen)?.toStringAsFixed(1);
    final einheit = methode == 'gemuell' ? 'Milben/Tag' : '% Befall';
    final color = switch (ampel) {
      Ampel.gruen => Colors.green, Ampel.gelb => Colors.orange, Ampel.rot => Colors.red, Ampel.keinRichtwert => Colors.grey,
    };
    return Row(children: [
      Icon(Icons.circle, color: color, size: 14),
      const SizedBox(width: 8),
      Text('${wert ?? '—'} $einheit'),
    ]);
  }
}
