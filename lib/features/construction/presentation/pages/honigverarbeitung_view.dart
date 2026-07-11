import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:go_router/go_router.dart';
import 'package:bienen_app/core/theme/app_theme.dart';

/// Info- und Ausstattungsseite für den Honigverarbeitungs-/Schleuderraum.
/// Inhalt liegt als Markdown-Asset (aus tiefer Recherche abgeleitet).
/// Geführte Bauschritte (Abhaken/Foto, Supabase-synchron) folgen später.
class HonigverarbeitungView extends StatefulWidget {
  const HonigverarbeitungView({super.key});

  @override
  State<HonigverarbeitungView> createState() => _HonigverarbeitungViewState();
}

class _HonigverarbeitungViewState extends State<HonigverarbeitungView> {
  String? _content;
  String? _error;

  static const _assetMd = 'assets/honigverarbeitung/schleuderraum.md';

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
      setState(() => _error = 'Inhalt konnte nicht geladen werden: $e');
    }
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
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.amber50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.amber200),
          ),
          child: Row(
            children: const [
              Icon(Icons.info_outline, color: AppColors.honeyDark, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Bau & Ausstattung des Schleuderraums. Geführte Bauschritte '
                  '(Abhaken/Foto) folgen, sobald es konkret wird.',
                  style: TextStyle(fontSize: 13, color: AppColors.brown800),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: () => context.go('/material'),
              icon: const Icon(Icons.shopping_cart),
              label: const Text('Zur Materialliste'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        MarkdownBody(
          data: _content!,
          selectable: true,
          styleSheet: MarkdownStyleSheet(
            h1: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.brown800),
            h2: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.brown800),
            h3: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.honeyDark),
            p: const TextStyle(fontSize: 14, height: 1.6),
            tableHead: const TextStyle(fontWeight: FontWeight.bold),
            tableBorder: TableBorder.all(color: AppColors.brown100, width: 1),
            tableCellsPadding: const EdgeInsets.all(6),
            listBullet: const TextStyle(fontSize: 14),
          ),
        ),
      ],
    );
  }
}
