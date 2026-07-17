import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:bienen_app/features/auth/presentation/auth_providers.dart';
import 'package:bienen_app/features/durchsicht/domain/bienen_schaetzung.dart';
import 'package:bienen_app/features/durchsicht/domain/durchsicht.dart';
import 'package:bienen_app/features/durchsicht/domain/durchsicht_gateway.dart';
import 'package:bienen_app/features/durchsicht/presentation/providers/durchsicht_provider.dart';

/// [bestehend] != null -> Bearbeiten.
class DurchsichtFormPage extends ConsumerStatefulWidget {
  final String volkId;
  final Durchsicht? bestehend;
  const DurchsichtFormPage({super.key, required this.volkId, this.bestehend});
  @override
  ConsumerState<DurchsichtFormPage> createState() => _DurchsichtFormPageState();
}

class _DurchsichtFormPageState extends ConsumerState<DurchsichtFormPage> {
  late DateTime _datum;
  String? _weiselzustand, _brutbild, _pollen, _platz, _weiselzellen;
  bool _koeniginGesehen = false, _stifteGesehen = false, _busy = false;
  int? _sanftmut, _wabensitz;
  final _wetter = TextEditingController();
  final _temp = TextEditingController();
  final _dauer = TextEditingController();
  final _wzAnzahl = TextEditingController();
  final _brutWaben = TextEditingController();
  final _staerke = TextEditingController();
  final _futter = TextEditingController();
  final _massnahmen = TextEditingController();
  final _notiz = TextEditingController();
  final _auffaelligkeiten = <String>{};
  final _fotoPfade = <String>[];

  @override
  void initState() {
    super.initState();
    final b = widget.bestehend;
    _datum = b?.durchgefuehrtAm ?? DateTime.now();
    if (b != null) {
      _weiselzustand = b.weiselzustand; _brutbild = b.brutbild; _pollen = b.pollen;
      _platz = b.platz; _weiselzellen = b.weiselzellen;
      _koeniginGesehen = b.koeniginGesehen; _stifteGesehen = b.stifteGesehen;
      _sanftmut = b.sanftmut; _wabensitz = b.wabensitz;
      _wetter.text = b.wetter ?? '';
      _temp.text = b.temperaturC?.toString() ?? '';
      _dauer.text = b.dauerMin?.toString() ?? '';
      _wzAnzahl.text = b.weiselzellenAnzahl?.toString() ?? '';
      _brutWaben.text = b.brutWaben?.toString() ?? '';
      _staerke.text = b.staerkeWabengassen?.toString() ?? '';
      _futter.text = b.futterKg?.toString() ?? '';
      _massnahmen.text = b.massnahmen ?? ''; _notiz.text = b.notiz ?? '';
      _auffaelligkeiten.addAll(b.auffaelligkeiten);
      _fotoPfade.addAll(b.fotoUrls);
    }
  }

  Future<void> _fotoAufnehmen() async {
    final betriebId = ref.read(currentBetriebIdProvider);
    if (betriebId == null) return;
    final file = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 75, maxWidth: 2000);
    if (file == null) return;
    if (!mounted) return;
    setState(() => _busy = true);
    try {
      final bytes = await file.readAsBytes();
      final pfad = await ref.read(durchsichtGatewayProvider).fotoHochladen(
            betriebId: betriebId, gruppeId: widget.volkId, bytes: bytes);
      if (!mounted) return;
      setState(() => _fotoPfade.add(pfad));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Foto fehlgeschlagen: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _speichern() async {
    setState(() => _busy = true);
    final d = Durchsicht(
      id: widget.bestehend?.id ?? '',
      volkId: widget.volkId,
      durchgefuehrtAm: _datum,
      wetter: _wetter.text.trim().isEmpty ? null : _wetter.text.trim(),
      temperaturC: num.tryParse(_temp.text.replaceAll(',', '.')),
      dauerMin: int.tryParse(_dauer.text),
      weiselzustand: _weiselzustand,
      koeniginGesehen: _koeniginGesehen,
      stifteGesehen: _stifteGesehen,
      weiselzellen: _weiselzellen,
      weiselzellenAnzahl: int.tryParse(_wzAnzahl.text),
      brutbild: _brutbild,
      brutWaben: num.tryParse(_brutWaben.text.replaceAll(',', '.')),
      staerkeWabengassen: num.tryParse(_staerke.text.replaceAll(',', '.')),
      futterKg: num.tryParse(_futter.text.replaceAll(',', '.')),
      pollen: _pollen,
      platz: _platz,
      sanftmut: _sanftmut,
      wabensitz: _wabensitz,
      auffaelligkeiten: _auffaelligkeiten.toList(),
      massnahmen: _massnahmen.text.trim().isEmpty ? null : _massnahmen.text.trim(),
      fotoUrls: _fotoPfade,
      notiz: _notiz.text.trim().isEmpty ? null : _notiz.text.trim(),
    );
    try {
      await ref.read(durchsichtenFuerVolkProvider(widget.volkId).notifier).speichern(d);
      if (mounted) Navigator.pop(context);
    } on DurchsichtFehler catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Speichern fehlgeschlagen: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _chips(String label, List<String> optionen, String? wert, ValueChanged<String?> onSel) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(padding: const EdgeInsets.only(top: 12, bottom: 4), child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600))),
          Wrap(spacing: 8, children: [
            for (final o in optionen)
              ChoiceChip(label: Text(o), selected: wert == o, onSelected: (s) => onSel(s ? o : null)),
          ]),
        ],
      );

  @override
  Widget build(BuildContext context) {
    if (!ref.watch(darfSchreibenProvider)) {
      return Scaffold(
        appBar: AppBar(title: const Text('Durchsicht')),
        body: const Center(child: Text('Nur Lesezugriff.')),
      );
    }
    final gassen = num.tryParse(_staerke.text.replaceAll(',', '.'));
    final schaetzung = bienenSchaetzung(gassen);
    return Scaffold(
      appBar: AppBar(title: Text(widget.bestehend == null ? 'Durchsicht' : 'Durchsicht bearbeiten')),
      body: AbsorbPointer(
        absorbing: _busy,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Datum'),
            subtitle: Text('${_datum.day}.${_datum.month}.${_datum.year}'),
            trailing: const Icon(Icons.calendar_today),
            onTap: () async {
              final d = await showDatePicker(context: context, initialDate: _datum,
                  firstDate: DateTime(2020), lastDate: DateTime(2100));
              if (d != null) setState(() => _datum = d);
            },
          ),
          const Padding(padding: EdgeInsets.only(top: 12, bottom: 4), child: Text('Kontext', style: TextStyle(fontWeight: FontWeight.w600))),
          TextField(controller: _wetter, decoration: const InputDecoration(labelText: 'Wetter')),
          Row(children: [
            Expanded(child: TextField(controller: _temp, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Temperatur (°C)'))),
            const SizedBox(width: 12),
            Expanded(child: TextField(controller: _dauer, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Dauer (min)'))),
          ]),
          _chips('Weiselzustand', const ['weiselrichtig', 'weisellos', 'drohnenbruetig', 'unsicher'], _weiselzustand, (v) => setState(() => _weiselzustand = v)),
          SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Königin gesehen'), value: _koeniginGesehen, onChanged: (v) => setState(() => _koeniginGesehen = v)),
          SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Stifte gesehen'), value: _stifteGesehen, onChanged: (v) => setState(() => _stifteGesehen = v)),
          if (_stifteGesehen) const Padding(padding: EdgeInsets.only(bottom: 4), child: Text('Frische Stifte sprechen für weiselrichtig.', style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey))),
          _chips('Weiselzellen', const ['keine', 'spielnaepfchen', 'schwarmzellen', 'nachschaffungszellen'], _weiselzellen, (v) => setState(() => _weiselzellen = v)),
          TextField(controller: _wzAnzahl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Anzahl Weiselzellen')),
          _chips('Brutbild', const ['geschlossen', 'lueckig', 'bunt', 'kaum', 'kein'], _brutbild, (v) => setState(() => _brutbild = v)),
          TextField(controller: _brutWaben, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Brutwaben (Anzahl)')),
          TextField(controller: _staerke, keyboardType: TextInputType.number, onChanged: (_) => setState(() {}), decoration: InputDecoration(labelText: 'Besetzte Wabengassen', helperText: schaetzung != null ? '≈ $schaetzung Bienen' : null)),
          TextField(controller: _futter, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Futter (kg, Schätzung)')),
          _chips('Pollen', const ['viel', 'mittel', 'wenig', 'kein'], _pollen, (v) => setState(() => _pollen = v)),
          _chips('Platz', const ['ok', 'eng', 'honigraum_noetig', 'zu_gross'], _platz, (v) => setState(() => _platz = v)),
          _slider('Sanftmut', _sanftmut, (v) => setState(() => _sanftmut = v)),
          _slider('Wabensitz', _wabensitz, (v) => setState(() => _wabensitz = v)),
          const Padding(padding: EdgeInsets.only(top: 12, bottom: 4), child: Text('Auffälligkeiten', style: TextStyle(fontWeight: FontWeight.w600))),
          Wrap(spacing: 8, children: [
            for (final f in Durchsicht.auffaelligkeitenWhitelist)
              FilterChip(label: Text(f), selected: _auffaelligkeiten.contains(f),
                  onSelected: (s) => setState(() => s ? _auffaelligkeiten.add(f) : _auffaelligkeiten.remove(f))),
          ]),
          TextField(controller: _massnahmen, maxLines: 2, decoration: const InputDecoration(labelText: 'Massnahmen')),
          TextField(controller: _notiz, maxLines: 2, decoration: const InputDecoration(labelText: 'Notiz')),
          const SizedBox(height: 12),
          Row(children: [
            OutlinedButton.icon(onPressed: _fotoAufnehmen, icon: const Icon(Icons.add_a_photo), label: const Text('Foto')),
            const SizedBox(width: 12),
            Text('${_fotoPfade.length} Foto(s)'),
          ]),
          const SizedBox(height: 20),
          FilledButton(onPressed: _busy ? null : _speichern, child: const Text('Speichern')),
        ]),
      ),
    );
  }

  Widget _slider(String label, int? wert, ValueChanged<int?> onCh) => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Row(children: [
          SizedBox(width: 90, child: Text(label)),
          Expanded(child: Slider(value: (wert ?? 0).toDouble(), min: 0, max: 4, divisions: 4,
              label: wert == null ? '—' : '$wert', onChanged: (v) => onCh(v == 0 ? null : v.round()))),
          SizedBox(width: 24, child: Text(wert?.toString() ?? '—')),
        ]),
      );
}
