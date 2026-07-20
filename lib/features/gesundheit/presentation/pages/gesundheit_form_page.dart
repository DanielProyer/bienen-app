import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:bienen_app/features/auth/presentation/auth_providers.dart';
import 'package:bienen_app/features/gesundheit/domain/gesundheitsereignis.dart';
import 'package:bienen_app/features/gesundheit/domain/krankheit.dart';
import 'package:bienen_app/features/gesundheit/presentation/providers/gesundheit_provider.dart';
import 'package:bienen_app/features/gesundheit/presentation/widgets/meldepflicht_banner.dart';
import 'package:bienen_app/features/wissen/domain/gesundheit_wissen.dart';
import 'package:bienen_app/features/wissen/presentation/widgets/wissen_info_button.dart';

class GesundheitFormPage extends ConsumerStatefulWidget {
  final String volkId;
  final String? vorbefuelltKrankheit;
  const GesundheitFormPage({super.key, required this.volkId, this.vorbefuelltKrankheit});
  @override
  ConsumerState<GesundheitFormPage> createState() => _GesundheitFormPageState();
}

const _statusWerte = ['verdacht', 'bestaetigt', 'gemeldet', 'in_behandlung', 'saniert', 'ausgeheilt', 'erloschen'];
const _statusLabels = {
  'verdacht': 'Verdacht', 'bestaetigt': 'Bestätigt', 'gemeldet': 'Gemeldet', 'in_behandlung': 'In Behandlung',
  'saniert': 'Saniert', 'ausgeheilt': 'Ausgeheilt', 'erloschen': 'Erloschen',
};

class _GesundheitFormPageState extends ConsumerState<GesundheitFormPage> {
  late String _krankheit =
      (widget.vorbefuelltKrankheit != null && katalogEintrag(widget.vorbefuelltKrankheit!) != null)
          ? widget.vorbefuelltKrankheit!
          : 'afb';
  DateTime _datum = DateTime.now();
  String? _schweregrad;
  String _status = 'verdacht';
  DateTime? _gemeldetAm;
  bool _labor = false;
  final _massnahme = TextEditingController();
  final _person = TextEditingController();
  final _notiz = TextEditingController();
  final _fotoPfade = <String>[];
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _person.text = Supabase.instance.client.auth.currentUser?.email ?? '';
  }

  @override
  void dispose() {
    _massnahme.dispose();
    _person.dispose();
    _notiz.dispose();
    super.dispose();
  }

  Future<void> _fotoAufnehmen() async {
    final betriebId = ref.read(currentBetriebIdProvider);
    if (betriebId == null) return;
    final file = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 75, maxWidth: 2000);
    if (file == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final bytes = await file.readAsBytes();
      final pfad = await ref.read(gesundheitGatewayProvider)
          .fotoHochladen(betriebId: betriebId, gruppeId: widget.volkId, bytes: bytes);
      if (mounted) setState(() => _fotoPfade.add(pfad));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Foto fehlgeschlagen: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!ref.watch(darfSchreibenProvider)) {
      return Scaffold(appBar: AppBar(title: const Text('Diagnose')), body: const Center(child: Text('Nur Lesezugriff.')));
    }
    // Katalog gruppiert nach Rechtskategorie
    final gruppen = <Rechtskategorie, List<Krankheit>>{};
    for (final k in kKrankheiten) {
      gruppen.putIfAbsent(k.rechtskategorie, () => []).add(k);
    }
    const gruppenLabel = {
      Rechtskategorie.zuBekaempfen: '⚠ Meldepflichtig (zu bekämpfen)',
      Rechtskategorie.zuUeberwachen: 'Zu überwachen',
      Rechtskategorie.neobiotaMeldung: 'Neobiota (Meldung)',
      Rechtskategorie.nichtMeldepflichtig: 'Nicht meldepflichtig',
    };
    final k = katalogEintrag(_krankheit);

    return Scaffold(
      appBar: AppBar(title: const Text('Diagnose erfassen')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Row(children: [
          Expanded(
            child: DropdownButtonFormField<String>(
              initialValue: _krankheit,
              decoration: const InputDecoration(labelText: 'Krankheit / Schädling'),
              items: [
                for (final r in [Rechtskategorie.zuBekaempfen, Rechtskategorie.zuUeberwachen,
                                 Rechtskategorie.neobiotaMeldung, Rechtskategorie.nichtMeldepflichtig])
                  if (gruppen[r] != null) ...[
                    DropdownMenuItem<String>(enabled: false, child: Text(gruppenLabel[r]!,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey))),
                    for (final e in gruppen[r]!) DropdownMenuItem(value: e.key, child: Text('   ${e.label}')),
                  ],
              ],
              onChanged: (v) => setState(() => _krankheit = v!),
            ),
          ),
          WissenInfoButton(wissenKey: kKrankheitWissen[_krankheit] ?? ''),
        ]),
        MeldepflichtBanner(krankheitKey: _krankheit),
        if (k != null && !istMeldepflichtig(_krankheit)) Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Text('${k.leitsymptome}\nMaßnahme: ${k.sofortmassnahme}',
              style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text('Festgestellt: ${_datum.day}.${_datum.month}.${_datum.year}'),
          trailing: const Icon(Icons.calendar_today),
          onTap: () async {
            final d = await showDatePicker(context: context, initialDate: _datum,
                firstDate: DateTime(2020), lastDate: DateTime.now());
            if (d != null) setState(() => _datum = d);
          },
        ),
        DropdownButtonFormField<String?>(
          initialValue: _schweregrad,
          decoration: const InputDecoration(labelText: 'Schweregrad (optional)'),
          items: const [
            DropdownMenuItem(value: null, child: Text('—')),
            DropdownMenuItem(value: 'leicht', child: Text('leicht')),
            DropdownMenuItem(value: 'mittel', child: Text('mittel')),
            DropdownMenuItem(value: 'schwer', child: Text('schwer')),
          ],
          onChanged: (v) => setState(() => _schweregrad = v),
        ),
        DropdownButtonFormField<String>(
          initialValue: _status,
          decoration: const InputDecoration(labelText: 'Status'),
          items: [for (final s in _statusWerte) DropdownMenuItem(value: s, child: Text(_statusLabels[s]!))],
          onChanged: (v) => setState(() {
            _status = v!;
            if (_status == 'gemeldet' && _gemeldetAm == null) _gemeldetAm = DateTime.now();
          }),
        ),
        if (_status == 'gemeldet')
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('Gemeldet am: ${_gemeldetAm == null ? '—' : '${_gemeldetAm!.day}.${_gemeldetAm!.month}.${_gemeldetAm!.year}'}'),
            trailing: const Icon(Icons.calendar_today),
            onTap: () async {
              final d = await showDatePicker(context: context, initialDate: _gemeldetAm ?? _datum,
                  firstDate: _datum, lastDate: DateTime.now());
              if (d != null) setState(() => _gemeldetAm = d);
            },
          ),
        SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Probe ans Labor eingesandt'),
            value: _labor, onChanged: (v) => setState(() => _labor = v)),
        TextField(controller: _massnahme, decoration: const InputDecoration(labelText: 'Maßnahme')),
        TextField(controller: _person, decoration: const InputDecoration(labelText: 'Verantwortliche Person')),
        TextField(controller: _notiz, decoration: const InputDecoration(labelText: 'Notiz')),
        const SizedBox(height: 12),
        Row(children: [
          OutlinedButton.icon(onPressed: _busy ? null : _fotoAufnehmen,
              icon: const Icon(Icons.add_a_photo), label: const Text('Foto')),
          const SizedBox(width: 12),
          Text('${_fotoPfade.length} Foto(s)'),
        ]),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _busy ? null : _speichern,
          icon: const Icon(Icons.save),
          label: Text(_busy ? 'Speichert…' : 'Diagnose speichern'),
        ),
      ]),
    );
  }

  Future<void> _speichern() async {
    if (_status == 'gemeldet' && _gemeldetAm == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bei Status „gemeldet" bitte das Melde-Datum setzen.')));
      return;
    }
    if (_gemeldetAm != null && _gemeldetAm!.isBefore(_datum)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Das Melde-Datum darf nicht vor dem Feststellungsdatum liegen.')));
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(gesundheitFuerVolkProvider(widget.volkId).notifier).speichern(Gesundheitsereignis(
            id: '', volkId: widget.volkId, festgestelltAm: _datum, krankheit: _krankheit,
            schweregrad: _schweregrad, status: _status, gemeldetAm: _status == 'gemeldet' ? _gemeldetAm : null,
            laborEingesandt: _labor, fotoUrls: _fotoPfade,
            massnahme: _massnahme.text.trim().isEmpty ? null : _massnahme.text.trim(),
            verantwortlichePerson: _person.text.trim().isEmpty ? null : _person.text.trim(),
            notiz: _notiz.text.trim().isEmpty ? null : _notiz.text.trim(),
          ));
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fehler: $e')));
      }
    }
  }
}
