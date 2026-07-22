import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:bienen_app/core/theme/app_tokens.dart';
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
        backgroundColor: BeeTokens.honig,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(BeeTokens.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(
              title: 'Digitale Tools für Imker',
              subtitle: 'Apps, Plattformen & Online-Tools für die Schweiz',
            ),
            const SizedBox(height: BeeTokens.xl),
            _buildMustHaveSection(context),
            const SizedBox(height: BeeTokens.xl),
            const SectionHeader(title: 'Empfohlene Apps'),
            const SizedBox(height: BeeTokens.lg),
            _buildAppCard(
              context,
              name: 'BeeSmart',
              category: 'Völkerverwaltung',
              price: 'Gratis / CHF 5.-/Mt',
              platforms: 'iOS, Android',
              description:
                  'Einzige App spezifisch für die Schweiz. Behandlungsjournal nach CH-Gesetz, dreisprachig, KI-Schwarmvorhersage (BeePhone).',
              isRecommended: true,
              url: 'https://beesmart.ch',
            ),
            _buildAppCard(
              context,
              name: 'BeeTraffic',
              category: 'Wandermeldung',
              price: 'Gratis',
              platforms: 'iOS, Android, Web',
              description:
                  'Offizielle App von BienenSchweiz/Identitas für gesetzlich vorgeschriebene Wandermeldung bei Völkertransport.',
              isRecommended: true,
              url: 'https://www.beetraffic.ch',
            ),
            _buildAppCard(
              context,
              name: 'Varroa-App',
              category: 'Gesundheit',
              price: 'Gratis',
              platforms: 'iOS, Android',
              description:
                  'Wissenschaftlich fundiertes Varroa-Management. Berechnet optimale Behandlungszeitpunkte, Nachbar-Warnsystem bei hohem Befall.',
              isRecommended: true,
              url: null,
            ),
            _buildAppCard(
              context,
              name: 'Waagvölker BienenSchweiz',
              category: 'Trachtbeobachtung',
              price: 'Gratis',
              platforms: 'Web',
              description:
                  'Interaktive Schweiz-Karte mit Echtzeit-Gewichtsdaten von Referenzvölkern. Zeigt Trachtbeginn/-ende in deiner Region.',
              isRecommended: true,
              url: 'https://www.bienen.ch',
            ),
            const SizedBox(height: BeeTokens.lg),
            const SectionHeader(title: 'Weitere nützliche Apps'),
            const SizedBox(height: BeeTokens.lg),
            _buildAppCard(
              context,
              name: 'Apiary Book',
              category: 'Völkerverwaltung',
              price: 'Gratis / Pro EUR 30.-/Jahr',
              platforms: 'iOS, Android, Web',
              description:
                  'Detaillierte Inspektionsformulare, Königinnen-Stammbaum, Honigernte-Tracking, Web-Zugang.',
              url: null,
            ),
            _buildAppCard(
              context,
              name: 'KIM (Imkado)',
              category: 'Lern-App',
              price: 'Gratis',
              platforms: 'iOS, Android, Web',
              description:
                  'KI-Coach für Anfänger, Inspektionsassistent, Lernmodule. Ideal für den Einstieg.',
              url: 'https://imkado.de',
            ),
            _buildAppCard(
              context,
              name: 'HiveWatch App',
              category: 'Stockwaage',
              price: 'Inkl. bei Hardware',
              platforms: 'iOS, Android, Web',
              description:
                  'Kommt mit unserer Stockwaage. Echtzeit-Gewicht, Temperatur, Alerts.',
              url: 'https://hivewatch.ch',
            ),
            _buildAppCard(
              context,
              name: 'MeteoSchweiz',
              category: 'Wetter',
              price: 'Gratis',
              platforms: 'iOS, Android',
              description:
                  'Offizielle CH-Wetterdaten, lokale Prognosen für Arosa, Pollenflug-Info.',
              url: null,
            ),
            const SizedBox(height: BeeTokens.xl),
            const SectionHeader(title: 'Gesetzliche Pflichten (CH)'),
            const SizedBox(height: BeeTokens.lg),
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
      padding: const EdgeInsets.all(BeeTokens.lg),
      decoration: BoxDecoration(
        color: BeeTokens.honigTint,
        borderRadius: BorderRadius.circular(BeeTokens.rKarte),
        border: Border.all(color: BeeTokens.honig, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.phone_android, color: BeeTokens.honig, size: 28),
            const SizedBox(width: BeeTokens.md),
            Text('Must-Have Apps', style: BeeTokens.abschnitt),
          ]),
          const SizedBox(height: BeeTokens.md),
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
        SizedBox(
            width: 24,
            child: Text(num,
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: BeeTokens.textSekundaer))),
        SizedBox(
            width: 100,
            child: Text(name,
                style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: BeeTokens.textPrimaer))),
        Expanded(
            child: Text(desc,
                style: const TextStyle(
                    fontSize: 13, color: BeeTokens.textGedaempft))),
      ]),
    );
  }

  Widget _buildAppCard(
    BuildContext context, {
    required String name,
    required String category,
    required String price,
    required String platforms,
    required String description,
    bool isRecommended = false,
    String? url,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: BeeTokens.md),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isRecommended ? BeeTokens.honigTint : BeeTokens.karte,
        borderRadius: BorderRadius.circular(BeeTokens.rKarte),
        border: Border.all(
          color: isRecommended ? BeeTokens.honig : BeeTokens.rand,
          width: isRecommended ? 1.5 : 0.5,
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
              child: Text(name,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: BeeTokens.textPrimaer))),
          if (isRecommended)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: BeeTokens.sm, vertical: 3),
              decoration: BoxDecoration(
                  color: BeeTokens.honig,
                  borderRadius: BorderRadius.circular(BeeTokens.md)),
              child: const Text('PFLICHT',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
            ),
        ]),
        const SizedBox(height: 6),
        Wrap(spacing: BeeTokens.sm, children: [
          _tag(category, BeeTokens.textSekundaer),
          _tag(price, BeeSignal.erfolg.text),
          _tag(platforms, BeeTokens.textGedaempft),
        ]),
        const SizedBox(height: BeeTokens.sm),
        Text(description,
            style: const TextStyle(fontSize: 13, color: BeeTokens.textPrimaer)),
        if (url != null) ...[
          const SizedBox(height: BeeTokens.sm),
          GestureDetector(
            onTap: () =>
                launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
            child: Text(url,
                style: const TextStyle(
                    fontSize: 12,
                    color: BeeTokens.infoText,
                    decoration: TextDecoration.underline)),
          ),
        ],
      ]),
    );
  }

  Widget _tag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
          color: color.withAlpha(20),
          borderRadius: BorderRadius.circular(BeeTokens.xs)),
      child: Text(text,
          style: TextStyle(
              fontSize: 11, color: color, fontWeight: FontWeight.w500)),
    );
  }

  Widget _buildLegalCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(BeeTokens.lg),
      decoration: BoxDecoration(
        color: BeeSignal.gefahr.flaeche,
        borderRadius: BorderRadius.circular(BeeTokens.rKarte),
        border: Border.all(color: BeeSignal.gefahr.text, width: 0.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.gavel, color: BeeSignal.gefahr.text, size: 20),
          const SizedBox(width: BeeTokens.sm),
          Text('Gesetzliche Pflichten',
              style: TextStyle(
                  fontWeight: FontWeight.bold, color: BeeSignal.gefahr.text)),
        ]),
        const SizedBox(height: BeeTokens.md),
        _legalRow('Behandlungsjournal', 'Seit 2023 Pflicht → BeeSmart nutzen'),
        _legalRow('Wandermeldung', 'Bei Völkertransport → BeeTraffic'),
        _legalRow('Tierseuchenmeldung', 'Faulbrut/Sauerbrut → Bieneninspektor GR'),
        _legalRow('BienenSchweiz', 'Mitgliedschaft empfohlen (Versicherung!)'),
      ]),
    );
  }

  Widget _legalRow(String title, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.arrow_right, size: 18, color: BeeTokens.textGedaempft),
        const SizedBox(width: BeeTokens.xs),
        SizedBox(
            width: 130,
            child: Text(title,
                style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                    color: BeeTokens.textPrimaer))),
        Expanded(
            child: Text(desc,
                style: const TextStyle(
                    fontSize: 13, color: BeeTokens.textPrimaer))),
      ]),
    );
  }
}
