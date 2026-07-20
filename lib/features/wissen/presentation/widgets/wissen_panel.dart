import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:bienen_app/features/recherche/pages/markdown_viewer_page.dart';
import 'package:bienen_app/features/wissen/domain/wissen_katalog.dart';
import 'package:bienen_app/features/wissen/presentation/pages/wissen_skizze_page.dart';
import 'package:bienen_app/features/wissen/presentation/widgets/wissen_foto_strip.dart';

/// Öffnet das Wissens-Panel (schnelle Info + Skizze + eigene Fotos + Mehr) für [startKey].
Future<void> openWissenPanel(BuildContext context, String startKey) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => FractionallySizedBox(
      heightFactor: 0.75,
      child: _WissenPanel(startKey: startKey),
    ),
  );
}

class _WissenPanel extends StatefulWidget {
  final String startKey;
  const _WissenPanel({required this.startKey});
  @override
  State<_WissenPanel> createState() => _WissenPanelState();
}

class _WissenPanelState extends State<_WissenPanel> {
  late String _key = widget.startKey;
  final _scroll = ScrollController();

  void _wechsle(String neu) {
    setState(() => _key = neu);
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  @override
  Widget build(BuildContext context) {
    final e = wissenVon(_key);
    if (e == null) return const SizedBox.shrink();
    final root = Navigator.of(context, rootNavigator: true);
    return ListView(controller: _scroll, padding: const EdgeInsets.fromLTRB(16, 0, 16, 24), children: [
      Text(e.titel, style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 8),
      Text(e.kurzinfo, style: Theme.of(context).textTheme.bodyMedium),
      if (e.skizze != null) ...[
        const SizedBox(height: 16),
        GestureDetector(
          onTap: () => root.push(MaterialPageRoute(
              fullscreenDialog: true,
              builder: (_) => WissenSkizzePage(assetPfad: e.skizze!, titel: e.titel))),
          child: Container(
            height: 160,
            decoration: BoxDecoration(border: Border.all(color: Colors.black12), borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.all(8),
            child: SvgPicture.asset(e.skizze!, fit: BoxFit.contain),
          ),
        ),
        const Padding(padding: EdgeInsets.only(top: 4),
            child: Text('Skizze · antippen für Vollbild', style: TextStyle(fontSize: 11, color: Colors.black54))),
      ],
      const SizedBox(height: 16),
      WissenFotoStrip(wissenKey: e.key),
      if (e.mehr.isNotEmpty) ...[
        const Divider(height: 24),
        for (final l in e.mehr)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(l.url != null ? Icons.open_in_new : Icons.menu_book),
            title: Text(l.label),
            onTap: () {
              if (l.rechercheAsset != null) {
                root.push(MaterialPageRoute(
                    builder: (_) => MarkdownViewerPage(title: l.label, assetPath: l.rechercheAsset!)));
              } else if (l.url != null) {
                launchUrl(Uri.parse(l.url!), mode: LaunchMode.externalApplication);
              }
            },
          ),
      ],
      if (e.verwandte.isNotEmpty) ...[
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 4, children: [
          for (final v in e.verwandte)
            if (wissenVon(v) != null)
              ActionChip(label: Text('→ ${wissenVon(v)!.titel}'), onPressed: () => _wechsle(v)),
        ]),
      ],
    ]);
  }
}
