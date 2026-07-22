import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:bienen_app/core/theme/app_tokens.dart';
import 'package:bienen_app/features/wissen/domain/wissen_eintrag.dart';
import 'package:bienen_app/features/wissen/domain/wissen_katalog.dart';
import 'package:bienen_app/features/wissen/presentation/widgets/wissen_panel.dart';
import 'package:bienen_app/shared/widgets/app_card.dart';
import 'package:bienen_app/shared/widgets/app_list_tile.dart';
import 'package:bienen_app/shared/widgets/section_header.dart';

class WissenOverviewPage extends StatefulWidget {
  const WissenOverviewPage({super.key});
  @override
  State<WissenOverviewPage> createState() => _WissenOverviewPageState();
}

class _WissenOverviewPageState extends State<WissenOverviewPage> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final treffer = _query.trim().isEmpty ? null : sucheWissen(_query);
    return Scaffold(
      appBar: AppBar(title: const Text('Wissen')),
      body: ListView(padding: const EdgeInsets.all(BeeTokens.lg), children: [
        TextField(
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search), hintText: 'Suchen: Stifte, Varroa, Futter …'),
          onChanged: (v) => setState(() => _query = v),
        ),
        const SizedBox(height: BeeTokens.lg),
        if (treffer != null)
          ...treffer.map((e) => _EintragTile(e))
        else ...[
          for (final kat in belegteKategorien()) ...[
            Padding(padding: const EdgeInsets.only(top: BeeTokens.sm),
                child: SectionHeader(titel: kat.titel)),
            ...eintraegeDerKategorie(kat.key).map((e) => _EintragTile(e)),
          ],
        ],
        const SizedBox(height: BeeTokens.lg),
        AppCard(
          padding: EdgeInsets.zero,
          child: AppListTile(
            leading: const Icon(Icons.library_books, color: BeeTokens.textSekundaer),
            titel: 'Alle Recherchen & Merkblätter',
            onTap: () => context.go('/recherche'),
          ),
        ),
      ]),
    );
  }
}

class _EintragTile extends StatelessWidget {
  final WissensEintrag e;
  const _EintragTile(this.e);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: BeeTokens.sm),
      child: AppCard(
        padding: EdgeInsets.zero,
        child: AppListTile(
          leading: e.skizze != null
              ? SizedBox(width: 40, height: 40, child: SvgPicture.asset(e.skizze!, fit: BoxFit.contain))
              : const Icon(Icons.lightbulb_outline, color: BeeTokens.textSekundaer),
          titel: e.titel,
          untertitel: e.kurzinfo,
          onTap: () => openWissenPanel(context, e.key),
        ),
      ),
    );
  }
}
