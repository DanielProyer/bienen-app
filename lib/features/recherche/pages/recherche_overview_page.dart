import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:bienen_app/core/theme/app_theme.dart';

class RechercheOverviewPage extends StatelessWidget {
  const RechercheOverviewPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Recherche')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recherche-Übersicht',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Alle Recherchen zum Projekt, aufbereitet und strukturiert.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.brown600,
                  ),
            ),
            const SizedBox(height: 24),
            _buildTopicCard(
              context,
              title: 'Imkerei Schweiz',
              subtitle: 'Grundlagen, Verbände, Gesetze, Bienenrassen',
              icon: Icons.flag,
              route: '/recherche/imkerei-schweiz',
              color: AppColors.amber600,
            ),
            _buildTopicCard(
              context,
              title: 'Jahresablauf',
              subtitle: 'Monatskalender für Arosa (1570 m), Trachtpflanzen',
              icon: Icons.calendar_month,
              route: '/recherche/jahresablauf',
              color: AppColors.green600,
            ),
            _buildTopicCard(
              context,
              title: 'Beutensystem Dadant Blatt',
              subtitle: 'Specs, Vergleich, Entscheidung Holz',
              icon: Icons.grid_view,
              route: '/recherche/beutensystem',
              color: AppColors.brown600,
            ),
            _buildTopicCard(
              context,
              title: 'Bienenrassen',
              subtitle: 'Buckfast vs. Dunkle Biene vs. Carnica -- Entscheidung',
              icon: Icons.pets,
              route: '/recherche/bienenrassen',
              color: AppColors.green600,
            ),
            _buildTopicCard(
              context,
              title: 'Raumkonzept Maiensäss',
              subtitle: 'Bienenstand, Schleuderraum, Lager, Phasenplan',
              icon: Icons.house,
              route: '/recherche/raumkonzept',
              color: AppColors.honeyDark,
            ),
            const SizedBox(height: 24),
            Text(
              'Weitere Dokumente',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.brown600,
                  ),
            ),
            const SizedBox(height: 12),
            _buildTopicCard(
              context,
              title: 'Bienenstand & Unterstand',
              subtitle: 'Detaillierte Recherche zum Unterstand-Bau',
              icon: Icons.roofing,
              route: '/recherche/bienenstand',
              color: AppColors.green800,
            ),
            _buildTopicCard(
              context,
              title: 'Honigverarbeitungsraum',
              subtitle: 'Schleuderraum, Hygiene, Einrichtung',
              icon: Icons.precision_manufacturing,
              route: '/recherche/schleuderraum',
              color: AppColors.amber800,
            ),
            _buildTopicCard(
              context,
              title: 'Stockwaagen & Monitoring',
              subtitle: 'Digitale Stockwaagen, Liveübertragung, Systemvergleich',
              icon: Icons.monitor_weight,
              route: '/recherche/stockwaagen',
              color: AppColors.honeyDark,
            ),
            _buildTopicCard(
              context,
              title: 'Honigschleudern',
              subtitle: 'Motorisierte Radialschleudern für Dadant Blatt',
              icon: Icons.rotate_right,
              route: '/recherche/honigschleudern',
              color: AppColors.amber800,
            ),
            _buildTopicCard(
              context,
              title: 'Imkerei-Apps & Tools',
              subtitle: 'BeeSmart, BeeTraffic, Varroa-App, Waagvölker',
              icon: Icons.phone_android,
              route: '/recherche/imkerei-apps',
              color: AppColors.green600,
            ),
            _buildTopicCard(
              context,
              title: 'Erstausstattung Einkaufsliste',
              subtitle: 'Komplette Einkaufsliste mit Preisen und Lieferanten',
              icon: Icons.receipt_long,
              route: '/recherche/einkaufsliste',
              color: AppColors.brown600,
            ),
            const SizedBox(height: 24),
            Text(
              'Fachwissen-Bibliothek',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.brown600,
                  ),
            ),
            const SizedBox(height: 12),
            _buildTopicCard(
              context,
              title: 'Bienenbiologie: Das Bienenvolk',
              subtitle: 'Kasten, Entwicklung, Kommunikation, Volksdynamik',
              icon: Icons.emoji_nature,
              route: '/recherche/bienenbiologie',
              color: AppColors.amber600,
            ),
            _buildTopicCard(
              context,
              title: 'Grundlagen & Betriebsweisen',
              subtitle: 'Imkerliches Handwerk, Betriebsweisen im Vergleich',
              icon: Icons.school,
              route: '/recherche/betriebsweisen',
              color: AppColors.brown600,
            ),
            _buildTopicCard(
              context,
              title: 'Königinnenzucht',
              subtitle: 'Umlarven, Belegstellen, Zuchtplanung',
              icon: Icons.workspace_premium,
              route: '/recherche/koeniginnenzucht',
              color: AppColors.honeyDark,
            ),
            _buildTopicCard(
              context,
              title: 'Völkervermehrung',
              subtitle: 'Ableger, Kunstschwärme, TBE, Zeitfenster alpin',
              icon: Icons.call_split,
              route: '/recherche/voelkervermehrung',
              color: AppColors.green600,
            ),
            _buildTopicCard(
              context,
              title: 'Bienengesundheit & Krankheiten CH',
              subtitle: 'Krankheitsbilder, Meldepflicht, Seuchenrecht',
              icon: Icons.health_and_safety,
              route: '/recherche/bienengesundheit',
              color: AppColors.green800,
            ),
            _buildTopicCard(
              context,
              title: 'Varroa-Konzept alpin',
              subtitle: 'Schweizer Varroakonzept, angepasst auf 1570 m',
              icon: Icons.pest_control,
              route: '/recherche/varroa-konzept',
              color: AppColors.amber800,
            ),
            _buildTopicCard(
              context,
              title: 'Honig: Ernte bis Vermarktung',
              subtitle: 'Reife, Schleudern, Qualität, Deklaration, Verkauf',
              icon: Icons.water_drop,
              route: '/recherche/honig',
              color: AppColors.honeyDark,
            ),
            _buildTopicCard(
              context,
              title: 'Wachs & Wabenmanagement',
              subtitle: 'Wachskreislauf, Wabenhygiene, Mittelwände',
              icon: Icons.hexagon,
              route: '/recherche/wachs',
              color: AppColors.amber600,
            ),
            _buildTopicCard(
              context,
              title: 'Bio-Imkerei & Knospe Schweiz',
              subtitle: 'Bio-Suisse-Richtlinien, Umstellung, Nachweise',
              icon: Icons.eco,
              route: '/recherche/bio-knospe',
              color: AppColors.green600,
            ),
            _buildTopicCard(
              context,
              title: 'Recht & Bestandeskontrolle CH/GR',
              subtitle: 'Tierverkehr, Meldewesen, Journal-Pflichten',
              icon: Icons.gavel,
              route: '/recherche/recht',
              color: AppColors.brown600,
            ),
            _buildTopicCard(
              context,
              title: 'Wirtschaftlichkeit & Betriebsführung',
              subtitle: 'Kosten, Ertrag, Steuern, Hobby vs. Nebenerwerb',
              icon: Icons.payments,
              route: '/recherche/wirtschaftlichkeit',
              color: AppColors.green800,
            ),
            const SizedBox(height: 4),
            Text(
              'Quelle: Imkerei-Recherche (02_Recherche), Stand Juli 2026. '
              'Zahlen und Rechtliches sind Richtwerte — verbindlich ist die Fachstelle.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.brown300,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopicCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required String route,
    required Color color,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () => context.go(route),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withAlpha(30),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.brown300,
                          ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.brown300),
            ],
          ),
        ),
      ),
    );
  }
}
