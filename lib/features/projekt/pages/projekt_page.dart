import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:bienen_app/core/theme/app_theme.dart';
import 'package:bienen_app/features/projekt/domain/meilensteine.dart';

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
  ];

  static const _facts = [
    (icon: Icons.grid_view, text: 'Dadant Blatt 10 · Holz'),
    (icon: Icons.hive, text: 'Buckfast (T. Hassler)'),
    (icon: Icons.eco, text: 'Ziel: Bio-Honig'),
    (icon: Icons.flag, text: 'max 8 Völker bis 2030'),
    (icon: Icons.group, text: 'Daniel & Lorena'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Projekt')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(children: [
                  const Text('🐝', style: TextStyle(fontSize: 32)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Projekt Imkerei Arosa',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.brown800)),
                      Text(kBetriebLaeuftSeit,
                          style: TextStyle(fontSize: 12.5, color: Colors.green.shade700, fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ]),
              ),
            ),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 2.1,
              children: [
                for (final b in _bereiche)
                  Card(
                    margin: EdgeInsets.zero,
                    child: InkWell(
                      onTap: () => context.go(b.route),
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Row(children: [
                          Icon(b.icon, size: 24, color: AppColors.honey),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(b.titel,
                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                      overflow: TextOverflow.ellipsis),
                                  Text(b.sub,
                                      style: const TextStyle(fontSize: 10.5, color: AppColors.brown300),
                                      overflow: TextOverflow.ellipsis),
                                ]),
                          ),
                        ]),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Projektfortschritt', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  for (final m in kProjektMeilensteine)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(children: [
                        Container(
                          width: 22, height: 22, alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: m.status == MeilensteinStatus.erledigt ? AppColors.green600 : null,
                            border: m.status == MeilensteinStatus.erledigt
                                ? null
                                : Border.all(
                                    color: m.status == MeilensteinStatus.naechster
                                        ? AppColors.honeyDark
                                        : AppColors.brown100,
                                    width: 2),
                          ),
                          child: m.status == MeilensteinStatus.erledigt
                              ? const Icon(Icons.check, size: 14, color: Colors.white)
                              : null,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(m.titel,
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: m.status == MeilensteinStatus.naechster
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                                color: m.status == MeilensteinStatus.offen
                                    ? AppColors.brown300
                                    : AppColors.brown800,
                              )),
                        ),
                        Text(m.wann, style: const TextStyle(fontSize: 11, color: AppColors.brown300)),
                      ]),
                    ),
                ]),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final f in _facts)
                  Chip(
                    avatar: Icon(f.icon, size: 16, color: AppColors.brown600),
                    label: Text(f.text, style: const TextStyle(fontSize: 12)),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
