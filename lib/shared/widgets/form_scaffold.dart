import 'package:flutter/material.dart';
import 'package:bienen_app/core/theme/app_tokens.dart';

/// Einhand-Gerüst: Titel oben, Inhalt scrollt, Hauptaktion(en) unten angeheftet
/// (Daumen-erreichbar). Sekundäre/zerstörerische Aktionen gehören in [kopfAktionen]
/// (Overflow oben), nie in die Bodenleiste.
class FormScaffold extends StatelessWidget {
  final String titel;
  final String? untertitel;
  final List<Widget> kopfAktionen;
  final Widget child;
  final Widget bodenleiste;
  final bool busy;
  const FormScaffold({super.key, required this.titel, this.untertitel,
      this.kopfAktionen = const [], required this.child, required this.bodenleiste, this.busy = false});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BeeTokens.oberflaeche,
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(titel),
          if (untertitel != null) Text(untertitel!,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: BeeTokens.textGedaempft)),
        ]),
        actions: kopfAktionen,
      ),
      body: Column(children: [
        Expanded(child: AbsorbPointer(absorbing: busy, child: child)),
        SafeArea(top: false, child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(BeeTokens.lg, BeeTokens.sm, BeeTokens.lg, BeeTokens.lg),
          decoration: const BoxDecoration(color: BeeTokens.karte, border: Border(top: BorderSide(color: BeeTokens.rand, width: 0.5))),
          child: bodenleiste,
        )),
      ]),
    );
  }
}
