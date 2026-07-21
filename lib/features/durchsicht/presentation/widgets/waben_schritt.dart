import 'package:flutter/material.dart';
import 'package:bienen_app/core/theme/app_theme.dart';
import 'package:bienen_app/features/durchsicht/domain/wabe.dart';
import 'package:bienen_app/features/durchsicht/sprache/domain/sprach_kommando.dart';
import 'package:bienen_app/features/durchsicht/sprache/presentation/sprach_mikro.dart';
import 'package:bienen_app/features/wissen/domain/durchsicht_wissen.dart';
import 'package:bienen_app/features/wissen/presentation/widgets/wissen_info_button.dart';

/// Controlled Waben-Erfassung: die Wahrheit (Liste) hält die Wizard-Page,
/// dieses Widget rendert die aktive Wabe + meldet Änderungen via [onChanged].
class WabenSchritt extends StatefulWidget {
  final List<WabeBeobachtung> waben;
  final ValueChanged<List<WabeBeobachtung>> onChanged;
  const WabenSchritt({super.key, required this.waben, required this.onChanged});
  @override
  State<WabenSchritt> createState() => _WabenSchrittState();
}

class _WabenSchrittState extends State<WabenSchritt> {
  int _aktiv = 0;

  static const _inhaltLabel = {
    'brut': 'Brut', 'pollen': 'Pollen', 'futter': 'Futter', 'honig': 'Honig',
    'mittelwand': 'Mittelwand', 'leer': 'leer', 'baurahmen': 'Baurahmen',
  };

  List<WabeBeobachtung> get _ws => widget.waben;
  WabeBeobachtung get _w => _ws[_aktiv];

  void _ersetze(WabeBeobachtung neu) {
    final kopie = [..._ws];
    kopie[_aktiv] = neu;
    widget.onChanged(kopie);
  }

  void _toggleInhalt(String key) {
    final set = {..._w.inhalte};
    set.contains(key) ? set.remove(key) : set.add(key);
    _ersetze(WabeBeobachtung(inhalte: set, koenigin: _w.koenigin, weiselzelle: _w.weiselzelle, stifte: _w.stifte));
  }

  void _setSchied(bool on) {
    if (on) {
      // "dahinter Schluss": aktive Wabe wird Schied, Positionen dahinter entfernen.
      final kopie = _ws.sublist(0, _aktiv + 1);
      kopie[_aktiv] = const WabeBeobachtung(schied: true);
      widget.onChanged(kopie);
      setState(() {});
    } else {
      _ersetze(const WabeBeobachtung());
    }
  }

  void _wabenzahl(int delta) {
    final neu = [..._ws];
    if (delta > 0) {
      neu.add(const WabeBeobachtung());
    } else if (neu.length > 1) {
      neu.removeLast();
      if (_aktiv >= neu.length) _aktiv = neu.length - 1;
    }
    widget.onChanged(neu);
    setState(() {});
  }

  void _wendeSprachAktionAn(List<WabenAktion> aktionen) {
    if (aktionen.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('nicht erkannt'), duration: Duration(milliseconds: 900)));
      return;
    }
    final (liste, aktiv) = wendeWabenAktionen(_ws, _aktiv, aktionen);
    widget.onChanged(liste);
    setState(() => _aktiv = aktiv);
    final w = liste[aktiv];
    final teile = <String>[
      ...w.inhalte.map((k) => _inhaltLabel[k] ?? k),
      if (w.koenigin) 'Königin', if (w.weiselzelle) 'Weiselzelle', if (w.stifte) 'Stifte',
      if (w.schied) 'Schied',
    ];
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Wabe ${aktiv + 1}: ${teile.isEmpty ? '—' : teile.join(', ')}'),
        duration: const Duration(milliseconds: 1100)));
  }

  @override
  Widget build(BuildContext context) {
    // Aktive Position gegen (evtl. von aussen geschrumpfte) Liste absichern.
    if (_aktiv >= _ws.length) _aktiv = _ws.isEmpty ? 0 : _ws.length - 1;
    if (_ws.isEmpty) return const SizedBox.shrink();
    final w = _w;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SprachMikro(mikroId: 'kmd-waben', label: 'Waben-Kommando sprechen',
          onEndText: (t) => _wendeSprachAktionAn(parseWabenKommandos(t))),
      const SizedBox(height: 8),
      // Waben-Streifen
      Row(children: [
        for (var i = 0; i < _ws.length; i++)
          Expanded(child: GestureDetector(
            onTap: () => setState(() => _aktiv = i),
            child: Container(height: 30, margin: const EdgeInsets.symmetric(horizontal: 1),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(4),
                border: Border.all(color: i == _aktiv ? AppColors.honeyDark : AppColors.brown300, width: i == _aktiv ? 2 : 0.5),
                color: _ws[i].schied ? AppColors.brown300 : (_ws[i].inhalte.contains('brut') ? AppColors.honey.withAlpha(60) : null))))),
        IconButton(icon: const Icon(Icons.remove), onPressed: () => _wabenzahl(-1)),
        IconButton(icon: const Icon(Icons.add), onPressed: () => _wabenzahl(1)),
      ]),
      const SizedBox(height: 12),
      Text('Wabe ${_aktiv + 1} / ${_ws.length}', style: const TextStyle(fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      if (!w.schied) ...[
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final e in _inhaltLabel.entries)
            Row(mainAxisSize: MainAxisSize.min, children: [
              FilterChip(label: Text(e.value), selected: w.inhalte.contains(e.key),
                  onSelected: (_) => _toggleInhalt(e.key)),
              if (kDurchsichtWissen.containsKey(e.key)) WissenInfoButton(wissenKey: kDurchsichtWissen[e.key]!),
            ]),
        ]),
        const SizedBox(height: 10),
        Wrap(spacing: 8, children: [
          Row(mainAxisSize: MainAxisSize.min, children: [
            FilterChip(avatar: const Icon(Icons.star, size: 18), label: const Text('Königin'), selected: w.koenigin,
                onSelected: (s) => _ersetze(WabeBeobachtung(inhalte: w.inhalte, koenigin: s, weiselzelle: w.weiselzelle, stifte: w.stifte))),
            WissenInfoButton(wissenKey: kDurchsichtWissen['flag_koenigin']!),
          ]),
          Row(mainAxisSize: MainAxisSize.min, children: [
            FilterChip(label: const Text('Weiselzelle'), selected: w.weiselzelle,
                onSelected: (s) => _ersetze(WabeBeobachtung(inhalte: w.inhalte, koenigin: w.koenigin, weiselzelle: s, stifte: w.stifte))),
            WissenInfoButton(wissenKey: kDurchsichtWissen['flag_weiselzelle']!),
          ]),
          Row(mainAxisSize: MainAxisSize.min, children: [
            FilterChip(label: const Text('Stifte'), selected: w.stifte,
                onSelected: (s) => _ersetze(WabeBeobachtung(inhalte: w.inhalte, koenigin: w.koenigin, weiselzelle: w.weiselzelle, stifte: s))),
            WissenInfoButton(wissenKey: kDurchsichtWissen['flag_stifte']!),
          ]),
        ]),
      ],
      const SizedBox(height: 8),
      SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Trennschied (dahinter Schluss)'),
          value: w.schied, onChanged: _setSchied),
      const SizedBox(height: 8),
      Row(children: [
        OutlinedButton(onPressed: _aktiv > 0 ? () => setState(() => _aktiv--) : null, child: const Text('Zurück')),
        const SizedBox(width: 12),
        Expanded(child: FilledButton(
          onPressed: _aktiv < _ws.length - 1 ? () => setState(() => _aktiv++) : null,
          child: const Text('Nächste Wabe →'))),
      ]),
      const SizedBox(height: 12),
      Text('Brutwaben: ${brutWabenAus(_ws)}  ·  Königin: ${koeniginAus(_ws) ? 'ja' : '—'}  ·  Stifte: ${stifteAus(_ws) ? 'ja' : '—'}',
          style: const TextStyle(fontSize: 13, color: AppColors.brown600)),
    ]);
  }
}
