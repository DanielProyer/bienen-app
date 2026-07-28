import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:bienen_app/core/theme/app_tokens.dart';
import 'package:bienen_app/features/recherche/domain/markdown_anker.dart';
import 'package:bienen_app/features/recherche/domain/recherche_foto.dart';
import 'package:bienen_app/features/recherche/presentation/widgets/recherche_eigene_fotos.dart';

/// Zeigt ein Recherche-Dokument aus `assets/recherche/`.
///
/// Das Dokument wird nicht als ein Block gerendert, sondern in Abschnitte je
/// Überschrift zerlegt (siehe `markdown_anker.dart`). Nur so gibt es überhaupt
/// Sprungziele: `flutter_markdown` kennt keine Anker, und ein Verweis der Form
/// `[Kapitel](#1-kapitel)` lief zuvor in `launchUrl` — eine URI, die nur aus
/// einem Fragment besteht, kann der Browser nicht öffnen, es passierte nichts.
class MarkdownViewerPage extends ConsumerStatefulWidget {
  final String title;
  final String assetPath;

  const MarkdownViewerPage({
    super.key,
    required this.title,
    required this.assetPath,
  });

  @override
  ConsumerState<MarkdownViewerPage> createState() => _MarkdownViewerPageState();
}

class _MarkdownViewerPageState extends ConsumerState<MarkdownViewerPage> {
  final _rollen = ScrollController();

  List<MarkdownAbschnitt>? _abschnitte;
  String? _fehler;

  /// Ein Schlüssel je Anker — das Ziel eines Verweises.
  final _schluessel = <String, GlobalKey>{};

  /// Zeigt den Zurück-nach-oben-Knopf erst, wenn er gebraucht wird.
  bool _weitUnten = false;

  @override
  void initState() {
    super.initState();
    _rollen.addListener(_pruefePosition);
    _lade();
  }

  @override
  void dispose() {
    _rollen.removeListener(_pruefePosition);
    _rollen.dispose();
    super.dispose();
  }

  void _pruefePosition() {
    final weit = _rollen.hasClients && _rollen.offset > 600;
    if (weit != _weitUnten) setState(() => _weitUnten = weit);
  }

  Future<void> _lade() async {
    try {
      final inhalt = await rootBundle.loadString(widget.assetPath);
      final abschnitte = zerlegeInAbschnitte(inhalt);
      _schluessel.clear();
      for (final a in abschnitte) {
        if (a.anker != null) _schluessel[a.anker!] = GlobalKey();
      }
      if (mounted) setState(() => _abschnitte = abschnitte);
    } catch (e) {
      if (mounted) {
        setState(() => _fehler = 'Datei konnte nicht geladen werden: $e');
      }
    }
  }

  void _zumAnker(String anker) {
    final ziel = _schluessel[anker]?.currentContext;
    if (ziel == null) {
      // Verweis ohne passende Überschrift — lieber sagen als stumm bleiben.
      _melde('Zu diesem Verweis gibt es kein Kapitel im Dokument.');
      return;
    }
    Scrollable.ensureVisible(
      ziel,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
      alignment: 0.05, // knapp unter die Kopfzeile statt exakt an den Rand
    );
  }

  void _melde(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  /// Behandelt die drei Linkarten der Recherchen getrennt.
  Future<void> _linkGetippt(String? href) async {
    if (href == null || href.isEmpty) return;

    if (href.startsWith('#')) {
      _zumAnker(href.substring(1));
      return;
    }

    final ziel = Uri.tryParse(href);
    if (ziel != null && (ziel.scheme == 'http' || ziel.scheme == 'https')) {
      if (!await launchUrl(ziel, mode: LaunchMode.externalApplication)) {
        _melde('Der Link konnte nicht geöffnet werden.');
      }
      return;
    }

    // Querverweise auf andere Recherchen (`15_Varroa_….md`) — die liegen in der
    // App unter eigenen Routen, ein Dateipfad führt hier ins Leere. Statt
    // stumm zu bleiben, den gemeinten Titel nennen.
    final name = href.split('/').last.replaceAll('.md', '').replaceAll('_', ' ');
    _melde('Verweis auf „$name" — über die Recherche-Übersicht erreichbar.');
  }

  /// Löst einen Bildverweis aus dem Markdown auf einen Asset-Pfad auf.
  ///
  /// In den Dokumenten stehen die Bilder relativ (`bilder/30_x.jpg`), damit sie
  /// auch ausserhalb der App lesbar bleiben. Hier wird der Ordner des Dokuments
  /// davorgesetzt.
  String _bildPfad(String verweis) {
    if (verweis.startsWith('assets/')) return verweis;
    final schnitt = widget.assetPath.lastIndexOf('/');
    final ordner = schnitt < 0 ? '' : widget.assetPath.substring(0, schnitt + 1);
    return '$ordner$verweis';
  }

  Widget _bild(MarkdownImageConfig config) {
    // Netzwerkbilder bewusst nicht: Die App soll offline am Bienenstand
    // funktionieren, und die Recherchen bringen ihre Abbildungen selbst mit.
    if (config.uri.scheme == 'http' || config.uri.scheme == 'https') {
      return _bildHinweis(config.alt ?? 'Externes Bild wird nicht geladen');
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: BeeTokens.md),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(BeeTokens.sm),
        child: Image.asset(
          _bildPfad(config.uri.toString()),
          width: config.width ?? double.infinity,
          height: config.height,
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) =>
              _bildHinweis(config.alt ?? 'Abbildung nicht gefunden'),
        ),
      ),
    );
  }

  Widget _bildHinweis(String text) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(BeeTokens.md),
        decoration: BoxDecoration(
          color: BeeTokens.honigTint,
          borderRadius: BorderRadius.circular(BeeTokens.sm),
        ),
        child: Row(
          children: [
            const Icon(Icons.image_not_supported_outlined,
                size: 18, color: BeeTokens.textGedaempft),
            const SizedBox(width: BeeTokens.sm),
            Expanded(child: Text(text, style: BeeTokens.gedaempft)),
          ],
        ),
      );

  MarkdownStyleSheet _stil() => MarkdownStyleSheet(
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
        tableBorder: TableBorder.all(color: BeeTokens.randStark, width: 1),
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
      );

  /// Die Kapitel als Auswahl für den Foto-Dialog: lesbare Überschrift je Anker.
  List<({String? anker, String titel})> _kapitelListe() {
    final liste = <({String? anker, String titel})>[
      (anker: null, titel: 'Ganzes Dokument'),
    ];
    for (final a in _abschnitte ?? const <MarkdownAbschnitt>[]) {
      if (a.anker == null) continue;
      // Erste Zeile ohne Rauten = die Überschrift, wie sie im Text steht.
      final kopf = a.text
          .split('\n')
          .first
          .replaceFirst(RegExp(r'^\s*#{1,6}\s+'), '')
          .replaceAll(RegExp(r'[*`]'), '')
          .trim();
      liste.add((anker: a.anker, titel: kopf.isEmpty ? a.anker! : kopf));
    }
    return liste;
  }

  @override
  Widget build(BuildContext context) {
    final rechercheKey = rechercheKeyAusAssetPfad(widget.assetPath);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            tooltip: 'Eigenes Foto ergänzen',
            icon: const Icon(Icons.add_a_photo_outlined),
            onPressed: _abschnitte == null
                ? null
                : () => fotoErgaenzenSheet(
                      context,
                      ref,
                      rechercheKey: rechercheKey,
                      kapitel: _kapitelListe(),
                    ),
          ),
        ],
      ),
      floatingActionButton: _weitUnten
          ? FloatingActionButton.small(
              onPressed: () => _rollen.animateTo(
                0,
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOutCubic,
              ),
              tooltip: 'Zum Inhaltsverzeichnis',
              child: const Icon(Icons.arrow_upward),
            )
          : null,
      body: _fehler != null
          ? Center(
              child: Text(_fehler!,
                  style: const TextStyle(color: BeeTokens.gefahrText)))
          : _abschnitte == null
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  // Bewusst kein ListView.builder: Nur wenn alle Abschnitte
                  // gebaut sind, hat jeder Anker einen BuildContext — sonst
                  // fände ein Sprung sein Ziel nicht.
                  controller: _rollen,
                  padding: const EdgeInsets.all(BeeTokens.xl),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final a in _abschnitte!) ...[
                        MarkdownBody(
                          key: a.anker == null ? null : _schluessel[a.anker!],
                          data: a.text,
                          selectable: true,
                          styleSheet: _stil(),
                          sizedImageBuilder: _bild,
                          onTapLink: (text, href, title) => _linkGetippt(href),
                        ),
                        // Eigene Fotos direkt beim zugehörigen Kapitel; zeigt
                        // sich nur, wenn zu diesem Anker welche vorliegen.
                        RechercheEigeneFotos(
                          rechercheKey: rechercheKey,
                          anker: a.anker,
                        ),
                      ],
                    ],
                  ),
                ),
    );
  }
}
