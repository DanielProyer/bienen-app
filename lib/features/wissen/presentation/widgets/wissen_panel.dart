import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:bienen_app/core/theme/app_tokens.dart';
import 'package:bienen_app/features/recherche/pages/markdown_viewer_page.dart';
import 'package:bienen_app/features/wissen/domain/wissen_katalog.dart';
import 'package:bienen_app/features/wissen/presentation/pages/wissen_skizze_page.dart';
import 'package:bienen_app/features/wissen/presentation/widgets/wissen_foto_strip.dart';
import 'package:bienen_app/shared/widgets/app_button.dart';

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
    return ListView(controller: _scroll, padding: const EdgeInsets.fromLTRB(BeeTokens.lg, 0, BeeTokens.lg, BeeTokens.xl), children: [
      Text(e.titel, style: BeeTokens.titel),
      const SizedBox(height: BeeTokens.sm),
      Text(e.kurzinfo, style: BeeTokens.text),
      if (e.foto != null) ...[
        const SizedBox(height: BeeTokens.lg),
        GestureDetector(
          onTap: () => root.push(MaterialPageRoute(
              fullscreenDialog: true,
              builder: (_) => WissenSkizzePage(assetPfad: e.foto!, titel: e.titel))),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(BeeTokens.rKarte),
            child: Image.asset(e.foto!, height: 180, width: double.infinity, fit: BoxFit.cover),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: BeeTokens.xs),
          child: GestureDetector(
            onTap: () => launchUrl(Uri.parse(e.fotoQuelle!.url), mode: LaunchMode.externalApplication),
            child: Text(e.fotoQuelle!.zeile,
                style: BeeTokens.gedaempft.copyWith(decoration: TextDecoration.underline)),
          ),
        ),
      ],
      if (e.skizze != null) ...[
        const SizedBox(height: BeeTokens.lg),
        GestureDetector(
          onTap: () => root.push(MaterialPageRoute(
              fullscreenDialog: true,
              builder: (_) => WissenSkizzePage(assetPfad: e.skizze!, titel: e.titel))),
          child: Container(
            height: 160,
            decoration: BoxDecoration(border: Border.all(color: BeeTokens.rand), borderRadius: BorderRadius.circular(BeeTokens.rKarte)),
            padding: const EdgeInsets.all(BeeTokens.sm),
            child: SvgPicture.asset(e.skizze!, fit: BoxFit.contain),
          ),
        ),
        const Padding(padding: EdgeInsets.only(top: BeeTokens.xs),
            child: Text('Skizze · antippen für Vollbild', style: BeeTokens.gedaempft)),
      ],
      const SizedBox(height: BeeTokens.lg),
      WissenFotoStrip(wissenKey: e.key),
      if (e.mehr.isNotEmpty) ...[
        const SizedBox(height: BeeTokens.lg),
        for (final l in e.mehr) ...[
          AppButton(
            label: l.label,
            icon: l.url != null ? Icons.open_in_new : Icons.menu_book,
            kind: AppButtonKind.sekundaer,
            full: true,
            onPressed: () {
              if (l.rechercheAsset != null) {
                root.push(MaterialPageRoute(
                    builder: (_) => MarkdownViewerPage(title: l.label, assetPath: l.rechercheAsset!)));
              } else if (l.url != null) {
                launchUrl(Uri.parse(l.url!), mode: LaunchMode.externalApplication);
              }
            },
          ),
          const SizedBox(height: BeeTokens.sm),
        ],
      ],
      if (e.verwandte.isNotEmpty) ...[
        const SizedBox(height: BeeTokens.sm),
        Wrap(spacing: BeeTokens.sm, runSpacing: BeeTokens.xs, children: [
          for (final v in e.verwandte)
            if (wissenVon(v) != null)
              ActionChip(label: Text('→ ${wissenVon(v)!.titel}'), onPressed: () => _wechsle(v)),
        ]),
      ],
    ]);
  }
}
