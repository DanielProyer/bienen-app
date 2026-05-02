import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:bienen_app/core/theme/app_theme.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Projekt Bienen Arosa')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            const SizedBox(height: 32),
            _buildProjectPhases(context),
            const SizedBox(height: 32),
            _buildQuickLinks(context),
            const SizedBox(height: 32),
            _buildKeyFacts(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          children: [
            const Text('🐝', style: TextStyle(fontSize: 48)),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Imkerei-Projekt Arosa',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.brown800,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Maiensäss Tannen 85a · 1570 m ü.M. · Start Herbst 2026',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppColors.brown600,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProjectPhases(BuildContext context) {
    final phases = [
      _Phase('Recherche & Planung', 'Beutensystem, Standort, Material', true),
      _Phase('Entscheidungen treffen', 'Beute, Rasse, Lieferant', true),
      _Phase('Material bestellen', 'Phase 1 Einkauf', false),
      _Phase('Unterstand vorbereiten', 'Bienenstand einrichten', false),
      _Phase('1. Volk einsetzen', 'Herbst 2026', false),
      _Phase('Schleuderraum ausbauen', 'Stall OG, 2027/2028', false),
      _Phase('Erweiterung auf 8 Völker', 'Langfristziel', false),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Projektfortschritt',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 16),
        ...phases.asMap().entries.map((entry) {
          final index = entry.key;
          final phase = entry.value;
          return _buildPhaseItem(context, index + 1, phase);
        }),
      ],
    );
  }

  Widget _buildPhaseItem(BuildContext context, int number, _Phase phase) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: phase.done ? AppColors.green600 : AppColors.brown100,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: phase.done
                  ? const Icon(Icons.check, color: Colors.white, size: 20)
                  : Text(
                      '$number',
                      style: TextStyle(
                        color: phase.done ? Colors.white : AppColors.brown600,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  phase.title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: phase.done ? AppColors.green800 : AppColors.brown800,
                    decoration:
                        phase.done ? TextDecoration.lineThrough : null,
                  ),
                ),
                Text(
                  phase.subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.brown300,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickLinks(BuildContext context) {
    final links = [
      _QuickLink('Recherche', Icons.menu_book, '/recherche',
          'Alle Recherchen aufbereitet'),
      _QuickLink('Entscheidungen', Icons.checklist, '/entscheidungen',
          'Getroffene & offene Entscheide'),
      _QuickLink('Materialliste', Icons.shopping_cart, '/material',
          'Interaktive Einkaufsliste'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Schnellzugriff',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: links
              .map((link) => _buildQuickLinkCard(context, link))
              .toList(),
        ),
      ],
    );
  }

  Widget _buildQuickLinkCard(BuildContext context, _QuickLink link) {
    return SizedBox(
      width: 280,
      child: Card(
        child: InkWell(
          onTap: () => context.go(link.route),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Icon(link.icon, size: 32, color: AppColors.honey),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        link.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        link.subtitle,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildKeyFacts(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Eckdaten',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            _buildFactChip('Dadant Blatt 10', Icons.grid_view),
            _buildFactChip('Holzbeuten', Icons.park),
            _buildFactChip('Max. 8 Völker', Icons.hive),
            _buildFactChip('Bio-Honig Ziel', Icons.eco),
            _buildFactChip('CHF 27-36k Invest', Icons.payments),
            _buildFactChip('CHF 20-28k Ersparnis', Icons.savings),
          ],
        ),
      ],
    );
  }

  Widget _buildFactChip(String label, IconData icon) {
    return Chip(
      avatar: Icon(icon, size: 18, color: AppColors.honeyDark),
      label: Text(label),
      backgroundColor: AppColors.amber50,
    );
  }
}

class _Phase {
  final String title;
  final String subtitle;
  final bool done;
  _Phase(this.title, this.subtitle, this.done);
}

class _QuickLink {
  final String title;
  final IconData icon;
  final String route;
  final String subtitle;
  _QuickLink(this.title, this.icon, this.route, this.subtitle);
}
