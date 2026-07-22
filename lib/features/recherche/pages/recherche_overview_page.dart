import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:bienen_app/core/theme/app_tokens.dart';
import 'package:bienen_app/shared/widgets/app_card.dart';

class RechercheOverviewPage extends StatelessWidget {
  const RechercheOverviewPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Recherche')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(BeeTokens.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Recherche-Übersicht', style: BeeTokens.titel),
            const SizedBox(height: BeeTokens.sm),
            Text(
              'Alle Recherchen zum Projekt, aufbereitet und strukturiert.',
              style: BeeTokens.text.copyWith(color: BeeTokens.textGedaempft),
            ),
            const SizedBox(height: BeeTokens.xl),
            _buildTopicCard(
              context,
              title: 'Imkerei Schweiz',
              subtitle: 'Grundlagen, Verbände, Gesetze, Bienenrassen',
              icon: Icons.flag,
              route: '/recherche/imkerei-schweiz',
            ),
            _buildTopicCard(
              context,
              title: 'Jahresablauf',
              subtitle: 'Monatskalender für Arosa (1570 m), Trachtpflanzen',
              icon: Icons.calendar_month,
              route: '/recherche/jahresablauf',
            ),
            _buildTopicCard(
              context,
              title: 'Beutensystem Dadant Blatt',
              subtitle: 'Specs, Vergleich, Entscheidung Holz',
              icon: Icons.grid_view,
              route: '/recherche/beutensystem',
            ),
            _buildTopicCard(
              context,
              title: 'Bienenrassen',
              subtitle: 'Buckfast vs. Dunkle Biene vs. Carnica -- Entscheidung',
              icon: Icons.pets,
              route: '/recherche/bienenrassen',
            ),
            _buildTopicCard(
              context,
              title: 'Raumkonzept Maiensäss',
              subtitle: 'Bienenstand, Schleuderraum, Lager, Phasenplan',
              icon: Icons.house,
              route: '/recherche/raumkonzept',
            ),
            const SizedBox(height: BeeTokens.xl),
            _buildGroupHeader('Weitere Dokumente'),
            const SizedBox(height: BeeTokens.md),
            _buildTopicCard(
              context,
              title: 'Bienenstand & Unterstand',
              subtitle: 'Detaillierte Recherche zum Unterstand-Bau',
              icon: Icons.roofing,
              route: '/recherche/bienenstand',
            ),
            _buildTopicCard(
              context,
              title: 'Honigverarbeitungsraum',
              subtitle: 'Schleuderraum, Hygiene, Einrichtung',
              icon: Icons.precision_manufacturing,
              route: '/recherche/schleuderraum',
            ),
            _buildTopicCard(
              context,
              title: 'Stockwaagen & Monitoring',
              subtitle: 'Digitale Stockwaagen, Liveübertragung, Systemvergleich',
              icon: Icons.monitor_weight,
              route: '/recherche/stockwaagen',
            ),
            _buildTopicCard(
              context,
              title: 'Honigschleudern',
              subtitle: 'Motorisierte Radialschleudern für Dadant Blatt',
              icon: Icons.rotate_right,
              route: '/recherche/honigschleudern',
            ),
            _buildTopicCard(
              context,
              title: 'Imkerei-Apps & Tools',
              subtitle: 'BeeSmart, BeeTraffic, Varroa-App, Waagvölker',
              icon: Icons.phone_android,
              route: '/recherche/imkerei-apps',
            ),
            _buildTopicCard(
              context,
              title: 'Erstausstattung Einkaufsliste',
              subtitle: 'Komplette Einkaufsliste mit Preisen und Lieferanten',
              icon: Icons.receipt_long,
              route: '/recherche/einkaufsliste',
            ),
            const SizedBox(height: BeeTokens.xl),
            _buildGroupHeader('Fachwissen-Bibliothek'),
            const SizedBox(height: BeeTokens.md),
            _buildTopicCard(
              context,
              title: 'Bienenbiologie: Das Bienenvolk',
              subtitle: 'Kasten, Entwicklung, Kommunikation, Volksdynamik',
              icon: Icons.emoji_nature,
              route: '/recherche/bienenbiologie',
            ),
            _buildTopicCard(
              context,
              title: 'Grundlagen & Betriebsweisen',
              subtitle: 'Imkerliches Handwerk, Betriebsweisen im Vergleich',
              icon: Icons.school,
              route: '/recherche/betriebsweisen',
            ),
            _buildTopicCard(
              context,
              title: 'Königinnenzucht',
              subtitle: 'Umlarven, Belegstellen, Zuchtplanung',
              icon: Icons.workspace_premium,
              route: '/recherche/koeniginnenzucht',
            ),
            _buildTopicCard(
              context,
              title: 'Völkervermehrung',
              subtitle: 'Ableger, Kunstschwärme, TBE, Zeitfenster alpin',
              icon: Icons.call_split,
              route: '/recherche/voelkervermehrung',
            ),
            _buildTopicCard(
              context,
              title: 'Bienengesundheit & Krankheiten CH',
              subtitle: 'Krankheitsbilder, Meldepflicht, Seuchenrecht',
              icon: Icons.health_and_safety,
              route: '/recherche/bienengesundheit',
            ),
            _buildTopicCard(
              context,
              title: 'Varroa-Konzept alpin',
              subtitle: 'Schweizer Varroakonzept, angepasst auf 1570 m',
              icon: Icons.pest_control,
              route: '/recherche/varroa-konzept',
            ),
            _buildTopicCard(
              context,
              title: 'Honig: Ernte bis Vermarktung',
              subtitle: 'Reife, Schleudern, Qualität, Deklaration, Verkauf',
              icon: Icons.water_drop,
              route: '/recherche/honig',
            ),
            _buildTopicCard(
              context,
              title: 'Wachs & Wabenmanagement',
              subtitle: 'Wachskreislauf, Wabenhygiene, Mittelwände',
              icon: Icons.hexagon,
              route: '/recherche/wachs',
            ),
            _buildTopicCard(
              context,
              title: 'Bio-Imkerei & Knospe Schweiz',
              subtitle: 'Bio-Suisse-Richtlinien, Umstellung, Nachweise',
              icon: Icons.eco,
              route: '/recherche/bio-knospe',
            ),
            _buildTopicCard(
              context,
              title: 'Recht & Bestandeskontrolle CH/GR',
              subtitle: 'Tierverkehr, Meldewesen, Journal-Pflichten',
              icon: Icons.gavel,
              route: '/recherche/recht',
            ),
            _buildTopicCard(
              context,
              title: 'Wirtschaftlichkeit & Betriebsführung',
              subtitle: 'Kosten, Ertrag, Steuern, Hobby vs. Nebenerwerb',
              icon: Icons.payments,
              route: '/recherche/wirtschaftlichkeit',
            ),
            const SizedBox(height: BeeTokens.xl),
            _buildGroupHeader('Offizielle BGD-Merkblätter (BienenSchweiz)'),
            const SizedBox(height: BeeTokens.xs),
            Text(
              'Aufbereitetes Fachwissen aus 96 offiziellen Merkblättern des '
              'Bienengesundheitsdienstes — dieselbe Grundlage wie in Lorenas Kurs.',
              style: BeeTokens.gedaempft,
            ),
            const SizedBox(height: BeeTokens.md),
            _buildTopicCard(
              context,
              title: 'Betriebskonzept & Jahresplanung',
              subtitle:
                  'Phänologischer Jahresplan (Indikatorpflanzen), Merkblatt-Systematik',
              icon: Icons.calendar_view_month,
              route: '/recherche/bgd-betriebskonzept',
            ),
            _buildTopicCard(
              context,
              title: 'Varroa-Behandlungskonzept',
              subtitle:
                  'Schwellen, Diagnose, AS-/Oxalsäure-/biotechnische Methoden',
              icon: Icons.pest_control,
              route: '/recherche/bgd-varroa',
            ),
            _buildTopicCard(
              context,
              title: 'Krankheiten & Schädlinge',
              subtitle: 'Krankheitsbilder, Diagnose, Rechtsstatus/Meldepflicht',
              icon: Icons.coronavirus,
              route: '/recherche/bgd-krankheiten',
            ),
            _buildTopicCard(
              context,
              title: 'Asiatische Hornisse (Vespa velutina)',
              subtitle: 'Identifikation, Schutz am Stand, Melde- & Nestsuche',
              icon: Icons.warning_amber,
              route: '/recherche/bgd-vespa',
            ),
            _buildTopicCard(
              context,
              title: 'Vermehrung & Jungvolkbildung',
              subtitle: 'Ableger/Kunstschwarm/Flügling, Fristen, Varroa-Nutzen',
              icon: Icons.call_split,
              route: '/recherche/bgd-vermehrung',
            ),
            _buildTopicCard(
              context,
              title: 'Zucht & Völkerbeurteilung',
              subtitle: 'Leistungsprüfung, Zuchtwert, Königin finden/zusetzen',
              icon: Icons.workspace_premium,
              route: '/recherche/bgd-zucht',
            ),
            _buildTopicCard(
              context,
              title: 'Gute imkerliche Praxis',
              subtitle:
                  'Hygiene, Fütterung, Überwinterung, Wabenpflege, Diagnose',
              icon: Icons.verified,
              route: '/recherche/bgd-praxis',
            ),
            _buildTopicCard(
              context,
              title: 'Honig-Qualität & Recht/Pflichten',
              subtitle:
                  'Grenzwerte, Etiketten-Pflichtangaben, Melde-/Aufzeichnungspflichten',
              icon: Icons.gavel,
              route: '/recherche/bgd-honig-recht',
            ),
            const SizedBox(height: BeeTokens.xs),
            Text(
              'Quellen: eigene Imkerei-Recherche + offizielle BGD-Merkblätter (BienenSchweiz), '
              'Stand Juli 2026. Zahlen und Rechtliches sind Richtwerte — verbindlich ist die Fachstelle.',
              style: BeeTokens.gedaempft,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupHeader(String title) {
    return Text(title, style: BeeTokens.abschnitt);
  }

  Widget _buildTopicCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required String route,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: BeeTokens.md),
      child: AppCard(
        onTap: () => context.go(route),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: BeeTokens.honigTint,
                borderRadius: BorderRadius.circular(BeeTokens.rKarte),
              ),
              child: Icon(icon, color: BeeTokens.honig, size: 24),
            ),
            const SizedBox(width: BeeTokens.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: BeeTokens.abschnitt),
                  const SizedBox(height: BeeTokens.xs),
                  Text(subtitle, style: BeeTokens.gedaempft),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: BeeTokens.chevron),
          ],
        ),
      ),
    );
  }
}
