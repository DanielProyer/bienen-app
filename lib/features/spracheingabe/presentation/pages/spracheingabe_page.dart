import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:bienen_app/core/theme/app_tokens.dart';
import 'package:bienen_app/features/spracheingabe/presentation/providers/spracheingabe_provider.dart';
import 'package:bienen_app/shared/widgets/app_card.dart';
import 'package:bienen_app/shared/widgets/confirm_sheet.dart';
import 'package:bienen_app/shared/widgets/empty_state.dart';
import 'package:bienen_app/shared/widgets/section_header.dart';

class SpracheingabePage extends ConsumerWidget {
  const SpracheingabePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Spracheingabe'),
          bottom: const TabBar(
            labelColor: BeeTokens.textPrimaer,
            unselectedLabelColor: BeeTokens.textGedaempft,
            indicatorColor: BeeTokens.honig,
            tabs: [
              Tab(text: 'Üben'),
              Tab(text: 'Frei sprechen'),
              Tab(text: 'Auswertung'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _UebenAnsicht(),
            EmptyState(
              icon: Icons.mic_none,
              titel: 'Frei sprechen kommt als Nächstes',
              text:
                  'Hier wirst du reden können wie am Volk und danach '
                  'korrigieren, was die Erkennung verhört hat.',
            ),
            _AuswertungAnsicht(),
          ],
        ),
      ),
    );
  }
}

/// Die eigentliche Auswertung kommt in Bauabschnitt 4. Bis dahin steht hier
/// wenigstens der Weg zum Erkennervergleich — er ist der einzige Teil der
/// Spracherkennung, der ausserhalb der App lebt (eigene Seite, ohne Login,
/// mit Testwort). Ihn hier zu verlinken ist der Unterschied zwischen „alles an
/// einem Ort" und „man muss wissen, dass es das gibt".
class _AuswertungAnsicht extends ConsumerWidget {
  const _AuswertungAnsicht();

  static final _vergleich = Uri.parse(
    'https://danielproyer.github.io/bienen-app/erkennervergleich.html',
  );

  String _quote(double? q) => q == null ? '—' : '${(q * 100).round()} %';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final zustand = ref.watch(auswertungProvider);

    return zustand.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => EmptyState(
        icon: Icons.error_outline,
        titel: 'Die Auswertung liess sich nicht laden',
        text: '$e',
      ),
      data: (a) => ListView(
        padding: const EdgeInsets.all(BeeTokens.md),
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Bestand', style: BeeTokens.abschnitt),
                const SizedBox(height: BeeTokens.sm),
                Text('${a.proben} Aufnahmen · ${(a.sekunden / 60).toStringAsFixed(1)} Minuten'),
                Text('davon gemessen: ${a.gemessen}',
                    style: const TextStyle(color: BeeTokens.textSekundaer)),
                if (a.ungemessen > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: BeeTokens.sm),
                    child: Text(
                      '${a.ungemessen} warten noch auf ihre erste Messung — sie sind '
                      'nicht verloren, genau dafür bleibt der Ton liegen.',
                      style: const TextStyle(color: BeeTokens.textGedaempft, fontSize: 12.5),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: BeeTokens.md),
          const SectionHeader(titel: 'Anbieter im Vergleich'),
          if (a.bilanzen.isEmpty)
            const AppCard(
              child: Text(
                'Noch keine Messung. Sprich im Segment „Üben" ein paar Karten — '
                'jede erzeugt eine.',
                style: TextStyle(color: BeeTokens.textGedaempft),
              ),
            )
          else
            for (final b in a.bilanzen)
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(b.anbieter,
                            style: const TextStyle(fontWeight: FontWeight.w700)),
                        Text(_quote(b.trefferQuoteMittel),
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: b.trefferQuoteMittel == null
                                  ? BeeTokens.textGedaempft
                                  : (b.trefferQuoteMittel! >= 0.8
                                      ? BeeTokens.erfolgText
                                      : BeeTokens.gefahrText),
                            )),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${b.messungen} Messungen'
                      '${b.fehlschlaege > 0 ? " · ${b.fehlschlaege} Ausfälle" : ""}'
                      '${b.wortfehlerMittel != null ? " · Wortfehler ${(b.wortfehlerMittel! * 100).round()} %" : ""}',
                      style: const TextStyle(color: BeeTokens.textSekundaer, fontSize: 12.5),
                    ),
                    if (b.modelle.isNotEmpty)
                      Text(b.modelle.join(' · '),
                          style: const TextStyle(
                              color: BeeTokens.textGedaempft, fontSize: 12)),
                  ],
                ),
              ),
          const SizedBox(height: BeeTokens.md),
          const SectionHeader(titel: 'Gelernte Regeln'),
          if (a.korrekturen.isEmpty)
            const AppCard(
              child: Text(
                'Noch keine. Eine Regel entsteht erst, wenn derselbe Verhörer '
                'zweimal auftritt — ein einzelner wäre Zufall.',
                style: TextStyle(color: BeeTokens.textGedaempft),
              ),
            )
          else
            for (final k in a.korrekturen)
              AppCard(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('„${k.falsch}" → ${k.richtig}',
                              style: const TextStyle(fontWeight: FontWeight.w600)),
                          Text(
                            '${k.treffer}× beobachtet · ${k.quelle}'
                            '${k.aktiv ? "" : " · noch nicht scharf"}',
                            style: const TextStyle(
                                color: BeeTokens.textGedaempft, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: k.aktiv,
                      onChanged: (v) =>
                          ref.read(auswertungProvider.notifier).regelSchalten(k.id, v),
                    ),
                    IconButton(
                      tooltip: 'Regel löschen',
                      icon: const Icon(Icons.delete_outline, color: BeeTokens.textGedaempft),
                      onPressed: () async {
                        final ok = await confirmSheet(
                          context,
                          titel: 'Regel löschen?',
                          text: '„${k.falsch}" → ${k.richtig} wird endgültig entfernt.',
                          bestaetigenLabel: 'Löschen',
                        );
                        if (ok == true) {
                          await ref.read(auswertungProvider.notifier).regelLoeschen(k.id);
                        }
                      },
                    ),
                  ],
                ),
              ),
          const SizedBox(height: BeeTokens.lg),
          // Der Vollvergleich über den gespeicherten Bestand kommt als eigener
          // Schritt. Bis dahin ist die Vergleichsseite der Weg für lange
          // Aufnahmen — sie lädt einmal hoch und misst alle drei zugleich.
          OutlinedButton.icon(
            key: const Key('spracheingabe_erkennervergleich'),
            onPressed: () => launchUrl(_vergleich, mode: LaunchMode.externalApplication),
            icon: const Icon(Icons.open_in_new),
            label: const Text('Erkennervergleich öffnen'),
          ),
          const SizedBox(height: BeeTokens.xl),
        ],
      ),
    );
  }
}

class _UebenAnsicht extends ConsumerWidget {
  const _UebenAnsicht();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final zustand = ref.watch(drillProvider);

    return zustand.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => EmptyState(
        icon: Icons.error_outline,
        titel: 'Der Übungsstapel liess sich nicht laden',
        text: '$e',
      ),
      data: (d) {
        final karte = d.karte;
        if (karte == null) {
          return const EmptyState(
            icon: Icons.inbox_outlined,
            titel: 'Keine Übungskarten',
            text:
                'Der Startstapel wird beim ersten Öffnen angelegt. '
                'Erscheint hier nichts, fehlt die Schreibberechtigung.',
          );
        }
        final ergebnis = d.letztes;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(BeeTokens.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppCard(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: BeeTokens.lg),
                  child: Text(
                    karte.sollText,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: BeeTokens.textPrimaer,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: BeeTokens.md),
              SizedBox(
                height: 64,
                child: FilledButton.icon(
                  key: const Key('drill_aufnahme'),
                  // Waehrend hochgeladen und erkannt wird, ist der Knopf
                  // gesperrt: Ein zweiter Druck mitten im Vorgang erzeugt sonst
                  // eine zweite Probe zur selben Karte.
                  onPressed: d.arbeitet
                      ? null
                      : () async {
                          final n = ref.read(drillProvider.notifier);
                          if (d.laeuft) {
                            await n.aufnahmeBeenden();
                          } else {
                            await n.aufnahmeStarten();
                          }
                        },
                  icon: Icon(
                    d.arbeitet ? Icons.hourglass_top : (d.laeuft ? Icons.stop : Icons.mic),
                  ),
                  label: Text(d.arbeitet ? 'Erkenne …' : (d.laeuft ? 'Fertig' : 'Sprechen')),
                  style: FilledButton.styleFrom(
                    backgroundColor: d.laeuft ? BeeTokens.gefahrText : BeeTokens.honig,
                  ),
                ),
              ),
              // Sichtbarer Fortschritt statt eines Bildschirms, der arbeitet
              // und dabei tot aussieht.
              if (d.arbeitet) ...[
                const SizedBox(height: BeeTokens.sm),
                const LinearProgressIndicator(),
                const SizedBox(height: BeeTokens.sm),
                const Text(
                  'Aufnahme wird gesichert und erkannt …',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: BeeTokens.textSekundaer),
                ),
              ],
              if (d.fehler != null) ...[
                const SizedBox(height: BeeTokens.md),
                AppCard(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.error_outline, color: BeeTokens.gefahrText),
                      const SizedBox(width: BeeTokens.sm),
                      Expanded(
                        child: Text(
                          d.fehler!,
                          key: const Key('drill_fehler'),
                          style: const TextStyle(color: BeeTokens.gefahrText),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: BeeTokens.sm),
                const Text(
                  'Die Aufnahme ist gesichert — sie geht nicht verloren und '
                  'lässt sich später erneut auswerten.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: BeeTokens.textGedaempft, fontSize: 12.5),
                ),
              ],
              if (ergebnis != null) ...[
                const SizedBox(height: BeeTokens.md),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            ergebnis.getroffen ? Icons.check_circle : Icons.cancel,
                            color: ergebnis.getroffen ? BeeTokens.erfolgText : BeeTokens.gefahrText,
                          ),
                          const SizedBox(width: BeeTokens.sm),
                          Text(
                            ergebnis.getroffen ? 'Verstanden' : 'Nicht verstanden',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                      const SizedBox(height: BeeTokens.sm),
                      Text(
                        'Erkannt: „${ergebnis.transkript}"',
                        style: const TextStyle(color: BeeTokens.textSekundaer),
                      ),
                      if (ergebnis.wortfehler != null)
                        Text(
                          'Wortfehlerrate: ${(ergebnis.wortfehler! * 100).round()} %',
                          style: const TextStyle(color: BeeTokens.textSekundaer),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: BeeTokens.sm),
                OutlinedButton(
                  key: const Key('drill_naechste'),
                  onPressed: () => ref.read(drillProvider.notifier).naechste(),
                  child: const Text('Nächste Karte'),
                ),
              ],
              const SizedBox(height: BeeTokens.lg),
              Text(
                '${d.stapel.length} Karten im Stapel · geübt: ${d.bilanz.length}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: BeeTokens.textGedaempft),
              ),
            ],
          ),
        );
      },
    );
  }
}
