import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:bienen_app/core/theme/app_tokens.dart';
import 'package:bienen_app/features/projekt/domain/meilensteine.dart';
import 'package:bienen_app/shared/widgets/app_card.dart';
import 'package:bienen_app/shared/widgets/section_header.dart';

class ProjektPage extends StatelessWidget {
  const ProjektPage({super.key});

  static const _bereiche = [
    (icon: Icons.shopping_cart, titel: 'Material & Lager', sub: 'Bestand · Einkäufe', route: '/material'),
    (icon: Icons.construction, titel: 'Bau', sub: 'Bienenstand · Honigraum', route: '/construction'),
    (icon: Icons.menu_book, titel: 'Recherche', sub: 'Fachthemen', route: '/recherche'),
    (icon: Icons.lightbulb_outline, titel: 'Wissen', sub: 'Schnelle Infos & Skizzen', route: '/wissen'),
    (icon: Icons.checklist, titel: 'Entscheidungen', sub: 'Chronik', route: '/entscheidungen'),
    (icon: Icons.monitor_weight, titel: 'Monitoring', sub: 'Waagen-Verwaltung', route: '/monitoring'),
    (icon: Icons.tune, titel: 'Betriebs-Einstellungen', sub: 'Saison-Offset · Ernten · Strategie', route: '/einstellungen'),
    (icon: Icons.account_circle, titel: 'Konto & Team', sub: 'Mitglieder · Einladungen', route: '/konto'),
    (icon: Icons.cloud_download, titel: 'Daten & Backup', sub: 'Export · Offsite-Sicherung', route: '/backup'),
  ];

  static const _facts = [
    (icon: Icons.grid_view, text: 'Dadant Blatt 10 · Holz'),
    (icon: Icons.hive, text: 'Buckfast (T. Hassler)'),
    (icon: Icons.eco, text: 'Ziel: Bio-Honig'),
    (icon: Icons.flag, text: 'max 8 Völker bis 2030'),
    (icon: Icons.group, text: 'Daniel & Lorena'),
  ];

  Widget _statusIcon(MeilensteinStatus status) => switch (status) {
        MeilensteinStatus.erledigt =>
          Icon(Icons.check_circle, size: 22, color: BeeSignal.erfolg.text),
        MeilensteinStatus.naechster =>
          const Icon(Icons.radio_button_checked, size: 22, color: BeeTokens.honig),
        MeilensteinStatus.offen =>
          const Icon(Icons.radio_button_unchecked, size: 22, color: BeeTokens.chevron),
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Projekt')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(BeeTokens.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppCard(
              child: Row(children: [
                const Text('🐝', style: TextStyle(fontSize: 32)),
                const SizedBox(width: BeeTokens.md),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Projekt Imkerei Arosa', style: BeeTokens.abschnitt),
                    const SizedBox(height: 2),
                    Text(kBetriebLaeuftSeit,
                        style: TextStyle(
                            fontSize: 12.5, color: BeeSignal.erfolg.text, fontWeight: FontWeight.w600)),
                  ]),
                ),
              ]),
            ),
            const SizedBox(height: BeeTokens.md),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: BeeTokens.md,
              crossAxisSpacing: BeeTokens.md,
              childAspectRatio: 2.1,
              children: [
                for (final b in _bereiche)
                  AppCard(
                    onTap: () => context.go(b.route),
                    padding: const EdgeInsets.symmetric(horizontal: BeeTokens.md, vertical: BeeTokens.sm),
                    child: Row(children: [
                      Icon(b.icon, size: 24, color: BeeTokens.honig),
                      const SizedBox(width: BeeTokens.md),
                      Expanded(
                        child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(b.titel,
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: BeeTokens.textPrimaer),
                                  overflow: TextOverflow.ellipsis),
                              Text(b.sub, style: BeeTokens.gedaempft, overflow: TextOverflow.ellipsis),
                            ]),
                      ),
                    ]),
                  ),
              ],
            ),
            const SizedBox(height: BeeTokens.lg),
            const SectionHeader(titel: 'Projektfortschritt'),
            AppCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                for (final m in kProjektMeilensteine)
                  Padding(
                    padding: const EdgeInsets.only(bottom: BeeTokens.sm),
                    child: Row(children: [
                      _statusIcon(m.status),
                      const SizedBox(width: BeeTokens.md),
                      Expanded(
                        child: Text(m.titel,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: m.status == MeilensteinStatus.naechster
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                              color: m.status == MeilensteinStatus.offen
                                  ? BeeTokens.textGedaempft
                                  : BeeTokens.textPrimaer,
                            )),
                      ),
                      Text(m.wann, style: BeeTokens.gedaempft),
                    ]),
                  ),
              ]),
            ),
            const SizedBox(height: BeeTokens.lg),
            Wrap(
              spacing: BeeTokens.sm,
              runSpacing: BeeTokens.sm,
              children: [
                for (final f in _facts)
                  Chip(
                    avatar: Icon(f.icon, size: 16, color: BeeTokens.textSekundaer),
                    label: Text(f.text, style: const TextStyle(fontSize: 12)),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            const SizedBox(height: BeeTokens.xl),
          ],
        ),
      ),
    );
  }
}
