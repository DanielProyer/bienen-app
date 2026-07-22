import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:bienen_app/core/theme/app_tokens.dart';

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
          ? Center(
              child: Text(_error!,
                  style: const TextStyle(color: BeeTokens.gefahrText)))
          : _content == null
              ? const Center(child: CircularProgressIndicator())
              : Markdown(
                  data: _content!,
                  selectable: true,
                  padding: const EdgeInsets.all(BeeTokens.xl),
                  onTapLink: (text, href, title) {
                    if (href != null) {
                      launchUrl(Uri.parse(href),
                          mode: LaunchMode.externalApplication);
                    }
                  },
                  styleSheet: MarkdownStyleSheet(
                    h1: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: BeeTokens.textPrimaer,
                    ),
                    h2: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: BeeTokens.textPrimaer,
                    ),
                    h3: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: BeeTokens.textSekundaer,
                    ),
                    h4: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: BeeTokens.textPrimaer,
                    ),
                    p: const TextStyle(fontSize: 14, height: 1.6),
                    blockquote: const TextStyle(
                      color: BeeTokens.textGedaempft,
                      fontStyle: FontStyle.italic,
                    ),
                    blockquoteDecoration: const BoxDecoration(
                      color: BeeTokens.honigTint,
                      border: Border(
                        left: BorderSide(color: BeeTokens.honig, width: 4),
                      ),
                    ),
                    tableHead: const TextStyle(fontWeight: FontWeight.bold),
                    tableBorder: TableBorder.all(
                      color: BeeTokens.randStark,
                      width: 1,
                    ),
                    tableCellsPadding: const EdgeInsets.all(BeeTokens.sm),
                    code: const TextStyle(
                      backgroundColor: BeeTokens.honigTint,
                      fontSize: 13,
                    ),
                    codeblockDecoration: BoxDecoration(
                      color: BeeTokens.honigTint,
                      borderRadius: BorderRadius.circular(BeeTokens.sm),
                    ),
                    a: const TextStyle(
                      color: BeeTokens.infoText,
                      decoration: TextDecoration.underline,
                    ),
                    listBullet: const TextStyle(fontSize: 14),
                    horizontalRuleDecoration: const BoxDecoration(
                      border: Border(
                        top: BorderSide(color: BeeTokens.randStark, width: 1),
                      ),
                    ),
                  ),
                ),
    );
  }
}
