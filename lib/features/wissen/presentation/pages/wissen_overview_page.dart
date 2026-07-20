import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:bienen_app/features/wissen/domain/wissen_eintrag.dart';
import 'package:bienen_app/features/wissen/domain/wissen_katalog.dart';
import 'package:bienen_app/features/wissen/presentation/widgets/wissen_panel.dart';

const _katIcons = <String, IconData>{'eye': Icons.visibility, 'bug': Icons.pest_control, 'droplet': Icons.water_drop};

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
      body: ListView(padding: const EdgeInsets.all(16), children: [
        TextField(
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search), hintText: 'Suchen: Stifte, Varroa, Futter …',
            border: OutlineInputBorder()),
          onChanged: (v) => setState(() => _query = v),
        ),
        const SizedBox(height: 16),
        if (treffer != null)
          ...treffer.map((e) => _EintragTile(e))
        else ...[
          for (final kat in belegteKategorien()) ...[
            Padding(padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(children: [
                  Icon(_katIcons[kat.icon] ?? Icons.menu_book, size: 18),
                  const SizedBox(width: 8),
                  Text(kat.titel, style: Theme.of(context).textTheme.titleMedium),
                ])),
            ...eintraegeDerKategorie(kat.key).map((e) => _EintragTile(e)),
          ],
        ],
        const Divider(height: 32),
        ListTile(
          leading: const Icon(Icons.library_books),
          title: const Text('Alle Recherchen & Merkblätter'),
          trailing: const Icon(Icons.arrow_forward),
          onTap: () => context.go('/recherche'),
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
    return Card(
      child: ListTile(
        leading: e.skizze != null
            ? SizedBox(width: 40, height: 40, child: SvgPicture.asset(e.skizze!, fit: BoxFit.contain))
            : const Icon(Icons.lightbulb_outline),
        title: Text(e.titel),
        subtitle: Text(e.kurzinfo, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => openWissenPanel(context, e.key),
      ),
    );
  }
}
