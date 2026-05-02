import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:bienen_app/core/theme/app_theme.dart';

class MarkdownViewerPage extends StatefulWidget {
  final String title;
  final String assetPath;

  const MarkdownViewerPage({
    super.key,
    required this.title,
    required this.assetPath,
  });

  @override
  State<MarkdownViewerPage> createState() => _MarkdownViewerPageState();
}

class _MarkdownViewerPageState extends State<MarkdownViewerPage> {
  String? _content;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadMarkdown();
  }

  Future<void> _loadMarkdown() async {
    try {
      final content = await rootBundle.loadString(widget.assetPath);
      setState(() => _content = content);
    } catch (e) {
      setState(() => _error = 'Datei konnte nicht geladen werden: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: _error != null
          ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
          : _content == null
              ? const Center(child: CircularProgressIndicator())
              : Markdown(
                  data: _content!,
                  selectable: true,
                  padding: const EdgeInsets.all(24),
                  onTapLink: (text, href, title) {
                    if (href != null) {
                      launchUrl(Uri.parse(href), mode: LaunchMode.externalApplication);
                    }
                  },
                  styleSheet: MarkdownStyleSheet(
                    h1: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.brown800,
                    ),
                    h2: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.brown800,
                    ),
                    h3: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: AppColors.honeyDark,
                    ),
                    h4: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.brown600,
                    ),
                    p: const TextStyle(fontSize: 14, height: 1.6),
                    blockquote: TextStyle(
                      color: AppColors.brown600,
                      fontStyle: FontStyle.italic,
                    ),
                    blockquoteDecoration: BoxDecoration(
                      color: AppColors.amber50,
                      border: Border(
                        left: BorderSide(color: AppColors.honey, width: 4),
                      ),
                    ),
                    tableHead: const TextStyle(fontWeight: FontWeight.bold),
                    tableBorder: TableBorder.all(
                      color: AppColors.brown100,
                      width: 1,
                    ),
                    tableCellsPadding: const EdgeInsets.all(8),
                    code: TextStyle(
                      backgroundColor: AppColors.brown50,
                      fontSize: 13,
                    ),
                    codeblockDecoration: BoxDecoration(
                      color: AppColors.brown50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    a: TextStyle(
                      color: Colors.blue.shade700,
                      decoration: TextDecoration.underline,
                    ),
                    listBullet: const TextStyle(fontSize: 14),
                    horizontalRuleDecoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(color: AppColors.brown100, width: 1),
                      ),
                    ),
                  ),
                ),
    );
  }
}
