import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:bienen_app/core/theme/app_theme.dart';

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
        child: Text(_error!, style: const TextStyle(color: Colors.red)),
      );
    }
    if (_content == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.asset('assets/bauplan/bienenstand_iso.png'),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: _openPdf,
              icon: const Icon(Icons.picture_as_pdf),
              label: const Text('Bauplan als PDF öffnen'),
            ),
            OutlinedButton.icon(
              onPressed: () => context.go('/material'),
              icon: const Icon(Icons.shopping_cart),
              label: const Text('Zur Einkaufsliste'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        MarkdownBody(
          data: _content!,
          selectable: true,
          styleSheet: MarkdownStyleSheet(
            h1: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.brown800),
            h2: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.brown800),
            h3: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.honeyDark),
            p: const TextStyle(fontSize: 14, height: 1.6),
            tableHead: const TextStyle(fontWeight: FontWeight.bold),
            tableBorder:
                TableBorder.all(color: AppColors.brown100, width: 1),
            tableCellsPadding: const EdgeInsets.all(6),
            listBullet: const TextStyle(fontSize: 14),
          ),
        ),
      ],
    );
  }
}
