import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:bienen_app/core/theme/app_theme.dart';
import 'package:bienen_app/features/construction/data/models/build_step_content.dart';
import 'package:bienen_app/features/construction/presentation/providers/construction_provider.dart';
import 'package:bienen_app/features/construction/presentation/widgets/build_step_card.dart';

/// Honigverarbeitung/Schleuderraum: zwei Ansichten – „Info" (Bau & Ausstattung
/// als Markdown) und „Bauschritte" (geführte, abhakbare Schritte, Supabase-
/// synchron wie beim Bienenstand). Inhalt aus tiefer Recherche.
class HonigverarbeitungView extends StatelessWidget {
  const HonigverarbeitungView({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Material(
            color: AppColors.brown600,
            child: const TabBar(
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              indicatorColor: AppColors.amber400,
              indicatorWeight: 3,
              tabs: [
                Tab(text: 'Info', icon: Icon(Icons.info_outline)),
                Tab(text: 'Bauschritte', icon: Icon(Icons.checklist)),
              ],
            ),
          ),
          const Expanded(
            child: TabBarView(
              children: [
                _HvInfoView(),
                _HvBauschritteView(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Info: Bau & Ausstattung als Markdown-Asset
// ---------------------------------------------------------------------------
class _HvInfoView extends StatefulWidget {
  const _HvInfoView();

  @override
  State<_HvInfoView> createState() => _HvInfoViewState();
}

class _HvInfoViewState extends State<_HvInfoView>
    with AutomaticKeepAliveClientMixin {
  String? _content;
  String? _error;

  static const _assetMd = 'assets/honigverarbeitung/schleuderraum.md';

  @override
  bool get wantKeepAlive => true;

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
    super.build(context);
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
                  'Bau & Ausstattung des Schleuderraums (aus Recherche). '
                  'Preise/Masse sind Richtwerte – konkrete Angaben folgen.',
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

// ---------------------------------------------------------------------------
// Bauschritte: geführte Schritte für den Schleuderraum-Ausbau
// ---------------------------------------------------------------------------
class _HvBauschritteView extends ConsumerWidget {
  const _HvBauschritteView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(honigverarbeitungProgressProvider);
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          color: AppColors.amber50,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Fortschritt: ${progress.done}/${progress.total} Schritte erledigt',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress.total == 0
                      ? 0
                      : progress.done / progress.total,
                  minHeight: 8,
                  backgroundColor: AppColors.brown100,
                  color: AppColors.green600,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Ablauf aus der Recherche – konkrete Masse/Produkte folgen, '
                'wenn der Schleuderraum feststeht.',
                style: TextStyle(fontSize: 11, color: AppColors.brown600),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.only(bottom: 24),
            itemCount: kHonigverarbeitungSteps.length,
            itemBuilder: (_, i) => BuildStepCard(
              content: kHonigverarbeitungSteps[i],
              stepNumber: i + 1,
            ),
          ),
        ),
      ],
    );
  }
}
