import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:bienen_app/core/theme/app_tokens.dart';
import 'package:bienen_app/shared/widgets/app_button.dart';

class BauplanView extends StatefulWidget {
  const BauplanView({super.key});

  @override
  State<BauplanView> createState() => _BauplanViewState();
}

class _BauplanViewState extends State<BauplanView> {
  String? _content;
  String? _error;

  static const _assetMd = 'assets/bauplan/bienenstand_bauplan.md';
  static const _assetPdf =
      'assets/assets/bauplan/bienenstand_variante2_bauplan.pdf';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final c = await rootBundle.loadString(_assetMd);
      setState(() => _content = c);
    } catch (e) {
      setState(() => _error = 'Bauplan konnte nicht geladen werden: $e');
    }
  }

  Future<void> _openPdf() async {
    // Flutter-Web legt deklarierte Assets unter assets/<pfad> ab; Uri.base
    // berücksichtigt das GitHub-Pages base-href (/bienen-app/).
    final uri = Uri.base.resolve(_assetPdf);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Center(
        child: Text(_error!, style: const TextStyle(color: BeeTokens.gefahrText)),
      );
    }
    if (_content == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return ListView(
      padding: const EdgeInsets.all(BeeTokens.lg),
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(BeeTokens.rKarte),
          child: Image.asset('assets/bauplan/bienenstand_iso.png'),
        ),
        const SizedBox(height: BeeTokens.md),
        Wrap(
          spacing: BeeTokens.sm,
          runSpacing: BeeTokens.sm,
          children: [
            AppButton(
              label: 'Bauplan als PDF öffnen',
              icon: Icons.picture_as_pdf,
              onPressed: _openPdf,
            ),
            AppButton(
              label: 'Zur Einkaufsliste',
              icon: Icons.shopping_cart,
              kind: AppButtonKind.sekundaer,
              onPressed: () => context.go('/material'),
            ),
          ],
        ),
        const SizedBox(height: BeeTokens.sm),
        MarkdownBody(
          data: _content!,
          selectable: true,
          styleSheet: MarkdownStyleSheet(
            h1: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: BeeTokens.textPrimaer),
            h2: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: BeeTokens.textPrimaer),
            h3: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: BeeTokens.textSekundaer),
            p: const TextStyle(fontSize: 14, height: 1.6),
            tableHead: const TextStyle(fontWeight: FontWeight.bold),
            tableBorder:
                TableBorder.all(color: BeeTokens.randStark, width: 1),
            tableCellsPadding: const EdgeInsets.all(6),
            listBullet: const TextStyle(fontSize: 14),
          ),
        ),
      ],
    );
  }
}
