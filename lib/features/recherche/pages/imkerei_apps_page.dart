import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:bienen_app/core/theme/app_theme.dart';
import 'package:bienen_app/features/recherche/widgets/section_header.dart';

class ImkereiAppsPage extends StatelessWidget {
  const ImkereiAppsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Imkerei-Apps')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/recherche/imkerei-apps/detail'),
        icon: const Icon(Icons.article),
        label: const Text('Vollständige Recherche'),
        backgroundColor: AppColors.honey,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(
              title: 'Digitale Tools für Imker',
              subtitle: 'Apps, Plattformen & Online-Tools für die Schweiz',
            ),
            const SizedBox(height: 24),
            _buildMustHaveSection(context),
            const SizedBox(height: 24),
            const SectionHeader(title: 'Empfohlene Apps'),
            const SizedBox(height: 16),
            _buildAppCard(
              context,
              name: 'BeeSmart',
              category: 'Völkerverwaltung',
              price: 'Gratis / CHF 5.-/Mt',
              platforms: 'iOS, Android',
              description: 'Einzige App spezifisch für die Schweiz. Behandlungsjournal nach CH-Gesetz, dreisprachig, KI-Schwarmvorhersage (BeePhone).',
              isRecommended: true,
              url: 'https://beesmart.ch',
            ),
            _buildAppCard(
              context,
              name: 'BeeTraffic',
              category: 'Wandermeldung',
              price: 'Gratis',
              platforms: 'iOS, Android, Web',
              description: 'Offizielle App von BienenSchweiz/Identitas für gesetzlich vorgeschriebene Wandermeldung bei Völkertransport.',
              isRecommended: true,
              url: 'https://www.beetraffic.ch',
            ),
            _buildAppCard(
              context,
              name: 'Varroa-App',
              category: 'Gesundheit',
              price: 'Gratis',
              platforms: 'iOS, Android',
              description: 'Wissenschaftlich fundiertes Varroa-Management. Berechnet optimale Behandlungszeitpunkte, Nachbar-Warnsystem bei hohem Befall.',
              isRecommended: true,
              url: null,
            ),
            _buildAppCard(
              context,
              name: 'Waagvölker BienenSchweiz',
              category: 'Trachtbeobachtung',
              price: 'Gratis',
              platforms: 'Web',
              description: 'Interaktive Schweiz-Karte mit Echtzeit-Gewichtsdaten von Referenzvölkern. Zeigt Trachtbeginn/-ende in deiner Region.',
              isRecommended: true,
              url: 'https://www.bienen.ch',
            ),
            const SizedBox(height: 16),
            const SectionHeader(title: 'Weitere nützliche Apps'),
            const SizedBox(height: 16),
            _buildAppCard(
              context,
              name: 'Apiary Book',
              category: 'Völkerverwaltung',
              price: 'Gratis / Pro EUR 30.-/Jahr',
              platforms: 'iOS, Android, Web',
              description: 'Detaillierte Inspektionsformulare, Königinnen-Stammbaum, Honigernte-Tracking, Web-Zugang.',
              url: null,
            ),
            _buildAppCard(
              context,
              name: 'KIM (Imkado)',
              category: 'Lern-App',
              price: 'Gratis',
              platforms: 'iOS, Android, Web',
              description: 'KI-Coach für Anfänger, Inspektionsassistent, Lernmodule. Ideal für den Einstieg.',
              url: 'https://imkado.de',
            ),
            _buildAppCard(
              context,
              name: 'HiveWatch App',
              category: 'Stockwaage',
              price: 'Inkl. bei Hardware',
              platforms: 'iOS, Android, Web',
              description: 'Kommt mit unserer Stockwaage. Echtzeit-Gewicht, Temperatur, Alerts.',
              url: 'https://hivewatch.ch',
            ),
            _buildAppCard(
              context,
              name: 'MeteoSchweiz',
              category: 'Wetter',
              price: 'Gratis',
              platforms: 'iOS, Android',
              description: 'Offizielle CH-Wetterdaten, lokale Prognosen für Arosa, Pollenflug-Info.',
              url: null,
            ),
            const SizedBox(height: 24),
            const SectionHeader(title: 'Gesetzliche Pflichten (CH)'),
            const SizedBox(height: 16),
            _buildLegalCard(context),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildMustHaveSection(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [AppColors.amber50, AppColors.green50]),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.amber400),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.phone_android, color: AppColors.honey, size: 28),
            const SizedBox(width: 12),
            Text('Must-Have Apps', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 12),
          _buildMustRow('1.', 'BeeSmart', 'Völker & Behandlungsjournal (CH-Pflicht)'),
          _buildMustRow('2.', 'BeeTraffic', 'Wandermeldung (gesetzlich vorgeschrieben)'),
          _buildMustRow('3.', 'Varroa-App', 'Optimale Behandlungszeitpunkte'),
          _buildMustRow('4.', 'bienen.ch', 'Trachtbeobachtung Schweiz'),
          _buildMustRow('5.', 'HiveWatch', 'Kommt mit unserer Stockwaage'),
        ],
      ),
    );
  }

  Widget _buildMustRow(String num, String name, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(children: [
        SizedBox(width: 24, child: Text(num, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.honeyDark))),
        SizedBox(width: 100, child: Text(name, style: const TextStyle(fontWeight: FontWeight.w600))),
        Expanded(child: Text(desc, style: const TextStyle(fontSize: 13, color: AppColors.brown600))),
      ]),
    );
  }

  Widget _buildAppCard(BuildContext context, {
    required String name, required String category, required String price,
    required String platforms, required String description,
    bool isRecommended = false, String? url,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: isRecommended ? AppColors.amber50 : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isRecommended ? const BorderSide(color: AppColors.honey, width: 1.5) : BorderSide(color: AppColors.brown100),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15))),
            if (isRecommended) Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: AppColors.honey, borderRadius: BorderRadius.circular(12)),
              child: const Text('PFLICHT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ]),
          const SizedBox(height: 6),
          Wrap(spacing: 8, children: [
            _tag(category, AppColors.honeyDark),
            _tag(price, AppColors.green600),
            _tag(platforms, AppColors.brown600),
          ]),
          const SizedBox(height: 8),
          Text(description, style: const TextStyle(fontSize: 13)),
          if (url != null) ...[
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
              child: Text(url, style: TextStyle(fontSize: 12, color: Colors.blue.shade700, decoration: TextDecoration.underline)),
            ),
          ],
        ]),
      ),
    );
  }

  Widget _tag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: color.withAlpha(20), borderRadius: BorderRadius.circular(4)),
      child: Text(text, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500)),
    );
  }

  Widget _buildLegalCard(BuildContext context) {
    return Card(
      color: Colors.red.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.gavel, color: Colors.red.shade700, size: 20),
            const SizedBox(width: 8),
            Text('Gesetzliche Pflichten', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red.shade700)),
          ]),
          const SizedBox(height: 12),
          _legalRow('Behandlungsjournal', 'Seit 2023 Pflicht → BeeSmart nutzen'),
          _legalRow('Wandermeldung', 'Bei Völkertransport → BeeTraffic'),
          _legalRow('Tierseuchenmeldung', 'Faulbrut/Sauerbrut → Bieneninspektor GR'),
          _legalRow('BienenSchweiz', 'Mitgliedschaft empfohlen (Versicherung!)'),
        ]),
      ),
    );
  }

  Widget _legalRow(String title, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.arrow_right, size: 18, color: AppColors.brown600),
        const SizedBox(width: 4),
        SizedBox(width: 130, child: Text(title, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13))),
        Expanded(child: Text(desc, style: const TextStyle(fontSize: 13))),
      ]),
    );
  }
}
