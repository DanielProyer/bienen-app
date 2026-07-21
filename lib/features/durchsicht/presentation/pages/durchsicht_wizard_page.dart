import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:bienen_app/features/auth/presentation/auth_providers.dart';
import 'package:bienen_app/features/durchsicht/domain/bienen_schaetzung.dart';
import 'package:bienen_app/features/durchsicht/domain/durchsicht.dart';
import 'package:bienen_app/features/durchsicht/domain/durchsicht_gateway.dart';
import 'package:bienen_app/features/durchsicht/domain/wabe.dart';
import 'package:bienen_app/features/durchsicht/presentation/providers/durchsicht_provider.dart';
import 'package:bienen_app/features/durchsicht/presentation/widgets/waben_schritt.dart';
import 'package:bienen_app/features/durchsicht/sprache/domain/sprach_kommando.dart';
import 'package:bienen_app/features/durchsicht/sprache/presentation/sprach_mikro.dart';

/// Geführte Durchsicht als 3-Schritt-Wizard: Kontext → optional Waben → Kennzahlen.
/// [bestehend] != null -> Bearbeiten. Deckt ALLE Felder des alten Formulars ab.
class DurchsichtWizardPage extends ConsumerStatefulWidget {
  final String volkId;
  final Durchsicht? bestehend;
  const DurchsichtWizardPage({super.key, required this.volkId, this.bestehend});
  @override
  ConsumerState<DurchsichtWizardPage> createState() => _DurchsichtWizardPageState();
}

class _DurchsichtWizardPageState extends ConsumerState<DurchsichtWizardPage> {
  final _pageController = PageController();
  int _seite = 0;

  late DateTime _datum;
  DateTime? _naechste;
  String? _weiselzustand, _brutbild, _pollen, _platz, _weiselzellen;
  bool _koeniginGesehen = false, _stifteGesehen = false, _busy = false;
  int? _sanftmut, _wabensitz;
  // Zahlen-Felder als _TapStepper (grosse +/− Ziele) — gehalten als num?.
  num? _temp, _dauer, _wzAnzahl, _brutWaben, _staerke, _futter;
  final _wetter = TextEditingController();
  final _massnahmen = TextEditingController();
  final _notiz = TextEditingController();
  final _auffaelligkeiten = <String>{};
  final _fotoPfade = <String>[];

  // Optionale Waben-für-Waben-Erfassung.
  List<WabeBeobachtung> _waben = [];
  bool _wabenModus = false;
  bool _vorbefuellt = false;

  @override
  void initState() {
    super.initState();
    final b = widget.bestehend;
    _datum = b?.durchgefuehrtAm ?? DateTime.now();
    _naechste = b?.naechsteDurchsichtAm;
    if (b != null) {
      _weiselzustand = b.weiselzustand; _brutbild = b.brutbild; _pollen = b.pollen;
      _platz = b.platz; _weiselzellen = b.weiselzellen;
      _koeniginGesehen = b.koeniginGesehen; _stifteGesehen = b.stifteGesehen;
      _sanftmut = b.sanftmut; _wabensitz = b.wabensitz;
      _wetter.text = b.wetter ?? '';
      _temp = b.temperaturC;
      _dauer = b.dauerMin;
      _wzAnzahl = b.weiselzellenAnzahl;
      _brutWaben = b.brutWaben;
      _staerke = b.staerkeWabengassen;
      _futter = b.futterKg;
      _massnahmen.text = b.massnahmen ?? ''; _notiz.text = b.notiz ?? '';
      _auffaelligkeiten.addAll(b.auffaelligkeiten);
      _fotoPfade.addAll(b.fotoUrls);
      _waben = [...b.waben];
      if (b.waben.isNotEmpty) _wabenModus = true;
      // Bearbeiten: bestehende Kennzahlen NICHT durch Ableitung überschreiben.
      _vorbefuellt = true;
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _wetter.dispose();
    _massnahmen.dispose();
    _notiz.dispose();
    super.dispose();
  }

  /// N leere Startwaben: letzte Durchsicht dieses Volks mit Waben, sonst 10.
  int _startWabenAnzahl() {
    final list = ref.read(durchsichtenFuerVolkProvider(widget.volkId)).valueOrNull;
    if (list != null) {
      for (final d in list) {
        if (d.waben.isNotEmpty) return d.waben.length;
      }
    }
    return 10;
  }

  Future<void> _wabenModusSetzen(bool on) async {
    // Edit mit erfassten Waben: Ausschalten erst nach Bestätigung (sonst stumm verworfen).
    if (!on && (widget.bestehend?.waben.isNotEmpty ?? false)) {
      final verwerfen = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Erfasste Waben verwerfen?'),
          content: const Text('Die Wabe-für-Wabe-Erfassung dieser Durchsicht wird beim Speichern entfernt.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Abbrechen')),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Verwerfen')),
          ],
        ),
      );
      if (verwerfen != true) return; // Schalter bleibt an
    }
    if (!mounted) return;
    setState(() {
      _wabenModus = on;
      if (on && _waben.isEmpty) {
        _waben = List.generate(_startWabenAnzahl(), (_) => const WabeBeobachtung());
      }
    });
  }

  /// Beim Wechsel Waben -> Kennzahlen (Seite 2->3), EINMALIG. Leere Waben -> null -> kein Overwrite.
  /// Nur brut_waben / koenigin_gesehen / stifte_gesehen; Futter nur als Hinweis, Gassen/Zellen bleiben manuell.
  void _uebernehmeVorbefuellung() {
    if (!_wabenModus) return; // nur aus GENUTZTEN Waben ableiten (Schalter aus -> nichts überschreiben)
    if (_vorbefuellt) return;
    final v = vorbefuellungAus(_waben);
    if (v == null) return;
    setState(() {
      _brutWaben = v.brutWaben;
      _koeniginGesehen = v.koeniginGesehen;
      _stifteGesehen = v.stifteGesehen;
      _vorbefuellt = true;
    });
  }

  void _weiter() {
    if (_seite == 1) _uebernehmeVorbefuellung(); // Waben -> Kennzahlen
    _geheZu((_seite + 1).clamp(0, 2));
  }

  void _zurueck() => _geheZu((_seite - 1).clamp(0, 2));

  void _geheZu(int ziel) {
    _pageController.animateToPage(ziel, duration: const Duration(milliseconds: 250), curve: Curves.easeInOut);
    setState(() => _seite = ziel);
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
      temperaturC: _temp,
      dauerMin: _dauer?.toInt(),
      weiselzustand: _weiselzustand,
      koeniginGesehen: _koeniginGesehen,
      stifteGesehen: _stifteGesehen,
      weiselzellen: _weiselzellen,
      weiselzellenAnzahl: _wzAnzahl?.toInt(),
      brutbild: _brutbild,
      brutWaben: _brutWaben,
      staerkeWabengassen: _staerke,
      futterKg: _futter,
      pollen: _pollen,
      platz: _platz,
      sanftmut: _sanftmut,
      wabensitz: _wabensitz,
      auffaelligkeiten: _auffaelligkeiten.toList(),
      massnahmen: _massnahmen.text.trim().isEmpty ? null : _massnahmen.text.trim(),
      naechsteDurchsichtAm: _naechste,
      fotoUrls: _fotoPfade,
      notiz: _notiz.text.trim().isEmpty ? null : _notiz.text.trim(),
      waben: _wabenModus ? _waben : const [],
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

  void _wendeKommandoAn(SprachKommando? k) {
    if (k == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('nicht erkannt'), duration: Duration(milliseconds: 900)));
      return;
    }
    String quittung = '';
    setState(() {
      switch (k) {
        case ZahlKommando(:final feld, :final wert):
          switch (feld) {
            case 'temperatur': _temp = wert; case 'dauer': _dauer = wert;
            case 'wz_anzahl': _wzAnzahl = wert; case 'brutwaben': _brutWaben = wert;
            case 'staerke': _staerke = wert; case 'futter': _futter = wert;
            case 'sanftmut': _sanftmut = wert.toInt().clamp(0, 4);
            case 'wabensitz': _wabensitz = wert.toInt().clamp(0, 4);
          }
          quittung = '$feld → $wert';
        case EnumKommando(:final feld, :final wert):
          switch (feld) {
            case 'weiselzustand': _weiselzustand = wert; case 'weiselzellen': _weiselzellen = wert;
            case 'brutbild': _brutbild = wert; case 'pollen': _pollen = wert; case 'platz': _platz = wert;
          }
          quittung = '$feld → $wert';
        case BoolKommando(:final feld, :final wert):
          if (feld == 'koenigin') _koeniginGesehen = wert;
          if (feld == 'stifte') _stifteGesehen = wert;
          quittung = '$feld → ${wert ? 'ja' : 'nein'}';
        case AuffaelligkeitKommando(:final key, :final an):
          an ? _auffaelligkeiten.add(key) : _auffaelligkeiten.remove(key);
          quittung = 'Auffälligkeit $key';
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(quittung), duration: const Duration(milliseconds: 900)));
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

  Widget _slider(String label, int? wert, ValueChanged<int?> onCh) => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Row(children: [
          SizedBox(width: 90, child: Text(label)),
          Expanded(child: Slider(value: (wert ?? 0).toDouble(), min: 0, max: 4, divisions: 4,
              label: wert == null ? '—' : '$wert', onChanged: (v) => onCh(v == 0 ? null : v.round()))),
          SizedBox(width: 24, child: Text(wert?.toString() ?? '—')),
        ]),
      );

  Widget _datumTile(String label, DateTime? wert, {required VoidCallback onTap, VoidCallback? onClear, IconData icon = Icons.calendar_today}) => ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(label),
        subtitle: Text(wert == null ? '—' : '${wert.day}.${wert.month}.${wert.year}'),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          if (onClear != null && wert != null)
            IconButton(icon: const Icon(Icons.clear), tooltip: 'Zurücksetzen', onPressed: onClear),
          Icon(icon),
        ]),
        onTap: onTap,
      );

  Widget _seiteKontext() => ListView(padding: const EdgeInsets.all(16), children: [
        SprachMikro(mikroId: 'kmd-kontext', label: 'Kommando sprechen',
            onEndText: (t) => _wendeKommandoAn(parseKommando(t, SprachKontext.kontext))),
        const Divider(),
        _datumTile('Datum', _datum, onTap: () async {
          final d = await showDatePicker(context: context, initialDate: _datum, firstDate: DateTime(2020), lastDate: DateTime(2100));
          if (d != null) setState(() => _datum = d);
        }),
        const Padding(padding: EdgeInsets.only(top: 12, bottom: 4), child: Text('Kontext', style: TextStyle(fontWeight: FontWeight.w600))),
        Row(children: [
          Expanded(child: TextField(controller: _wetter, decoration: const InputDecoration(labelText: 'Wetter'))),
          SprachMikro(mikroId: 'dik-wetter', kompakt: true, onEndText: (t) => setState(() => _wetter.text = '${_wetter.text} $t'.trim())),
        ]),
        _TapStepper(label: 'Temperatur (°C)', wert: _temp, min: -30, onCh: (v) => setState(() => _temp = v)),
        _TapStepper(label: 'Dauer (min)', wert: _dauer, schritt: 5, onCh: (v) => setState(() => _dauer = v)),
        _chips('Weiselzustand', const ['weiselrichtig', 'weisellos', 'drohnenbruetig', 'unsicher'], _weiselzustand, (v) => setState(() => _weiselzustand = v)),
      ]);

  Widget _seiteWaben() => ListView(padding: const EdgeInsets.all(16), children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Waben einzeln erfassen'),
          subtitle: const Text('Optional: Wabe für Wabe — leitet Brutwaben, Königin & Stifte ab.'),
          value: _wabenModus,
          onChanged: _wabenModusSetzen,
        ),
        const SizedBox(height: 8),
        if (_wabenModus)
          WabenSchritt(waben: _waben, onChanged: (w) => setState(() => _waben = w))
        else
          const Padding(
            padding: EdgeInsets.only(top: 24),
            child: Text('Ohne Waben-Erfassung überspringst du diesen Schritt und trägst die Kennzahlen direkt ein.',
                style: TextStyle(color: Colors.grey)),
          ),
      ]);

  Widget _seiteKennzahlen() {
    final schaetzung = bienenSchaetzung(_staerke);
    final futterHinweis = _wabenModus && _waben.isNotEmpty ? '≈ ${futterKgHinweisAus(_waben)} kg aus Waben' : null;
    return ListView(padding: const EdgeInsets.all(16), children: [
      SprachMikro(mikroId: 'kmd-kennzahlen', label: 'Kommando sprechen',
          onEndText: (t) => _wendeKommandoAn(parseKommando(t, SprachKontext.kennzahlen))),
      const Divider(),
      SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Königin gesehen'), value: _koeniginGesehen, onChanged: (v) => setState(() => _koeniginGesehen = v)),
      SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Stifte gesehen'), value: _stifteGesehen, onChanged: (v) => setState(() => _stifteGesehen = v)),
      if (_stifteGesehen) const Padding(padding: EdgeInsets.only(bottom: 4), child: Text('Frische Stifte sprechen für weiselrichtig.', style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey))),
      _chips('Weiselzellen', const ['keine', 'spielnaepfchen', 'schwarmzellen', 'nachschaffungszellen'], _weiselzellen, (v) => setState(() => _weiselzellen = v)),
      _TapStepper(label: 'Anzahl Weiselzellen', wert: _wzAnzahl, onCh: (v) => setState(() => _wzAnzahl = v)),
      _chips('Brutbild', const ['geschlossen', 'lueckig', 'bunt', 'kaum', 'kein'], _brutbild, (v) => setState(() => _brutbild = v)),
      _TapStepper(label: 'Brutwaben (Anzahl)', wert: _brutWaben, onCh: (v) => setState(() => _brutWaben = v)),
      _TapStepper(label: 'Besetzte Wabengassen', wert: _staerke, hinweis: schaetzung != null ? '≈ $schaetzung Bienen' : null, onCh: (v) => setState(() => _staerke = v)),
      _TapStepper(label: 'Futter (kg, Schätzung)', wert: _futter, hinweis: futterHinweis, onCh: (v) => setState(() => _futter = v)),
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
      Row(children: [
        Expanded(child: TextField(controller: _massnahmen, maxLines: 2, decoration: const InputDecoration(labelText: 'Massnahmen'))),
        SprachMikro(mikroId: 'dik-massnahmen', kompakt: true, onEndText: (t) => setState(() => _massnahmen.text = '${_massnahmen.text} $t'.trim())),
      ]),
      Row(children: [
        Expanded(child: TextField(controller: _notiz, maxLines: 2, decoration: const InputDecoration(labelText: 'Notiz'))),
        SprachMikro(mikroId: 'dik-notiz', kompakt: true, onEndText: (t) => setState(() => _notiz.text = '${_notiz.text} $t'.trim())),
      ]),
      _datumTile('Nächste Durchsicht (Empfehlung)', _naechste,
          icon: Icons.event,
          onClear: () => setState(() => _naechste = null),
          onTap: () async {
            final d = await showDatePicker(context: context, initialDate: _naechste ?? _datum, firstDate: DateTime(2020), lastDate: DateTime(2100));
            if (d != null) setState(() => _naechste = d);
          }),
      const SizedBox(height: 12),
      Row(children: [
        OutlinedButton.icon(onPressed: _fotoAufnehmen, icon: const Icon(Icons.add_a_photo), label: const Text('Foto')),
        const SizedBox(width: 12),
        Text('${_fotoPfade.length} Foto(s)'),
      ]),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    if (!ref.watch(darfSchreibenProvider)) {
      return Scaffold(
        appBar: AppBar(title: const Text('Durchsicht')),
        body: const Center(child: Text('Nur Lesezugriff.')),
      );
    }
    const titel = ['Kontext', 'Waben', 'Kennzahlen'];
    final letzte = _seite == 2;
    return Scaffold(
      appBar: AppBar(title: Text('${widget.bestehend == null ? 'Durchsicht' : 'Durchsicht bearbeiten'} · ${_seite + 1}/3 · ${titel[_seite]}')),
      body: AbsorbPointer(
        absorbing: _busy,
        child: Column(children: [
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              onPageChanged: (i) => setState(() => _seite = i),
              children: [_seiteKontext(), _seiteWaben(), _seiteKennzahlen()],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                if (_seite > 0) ...[
                  OutlinedButton(onPressed: _busy ? null : _zurueck, child: const Text('Zurück')),
                  const SizedBox(width: 12),
                ],
                Expanded(child: FilledButton(
                  onPressed: _busy ? null : (letzte ? _speichern : _weiter),
                  child: Text(letzte ? 'Speichern' : 'Weiter →'),
                )),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

/// Grosse +/− Tap-Ziele für Zahlen-Eingaben (ersetzt Number-TextFields im Wizard).
class _TapStepper extends StatelessWidget {
  final String label;
  final num? wert;
  final num schritt;
  final num min;
  final ValueChanged<num?> onCh;
  final String? hinweis;
  const _TapStepper({required this.label, required this.wert, this.schritt = 1, this.min = 0, required this.onCh, this.hinweis});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label),
            if (hinweis != null) Text(hinweis!, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ])),
          IconButton(iconSize: 28, icon: const Icon(Icons.remove_circle_outline),
              onPressed: () => onCh(((wert ?? 0) - schritt).clamp(min, 999))),
          SizedBox(width: 40, child: InkWell(
            onTap: wert == null ? null : () => onCh(null), // Tap auf Wert -> zurück auf "—" (null ≠ 0)
            child: Padding(padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text('${wert ?? '—'}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 18))))),
          IconButton(iconSize: 28, icon: const Icon(Icons.add_circle_outline),
              onPressed: () => onCh((wert ?? 0) + schritt)),
        ]),
      );
}
