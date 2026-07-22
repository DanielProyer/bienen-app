import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bienen_app/core/theme/app_theme.dart';
import 'package:bienen_app/core/theme/app_tokens.dart';
import 'package:bienen_app/features/construction/data/models/build_step_content.dart';
import 'package:bienen_app/features/construction/presentation/pages/bauplan_view.dart';
import 'package:bienen_app/features/construction/presentation/pages/honigverarbeitung_view.dart';
import 'package:bienen_app/features/construction/presentation/providers/construction_provider.dart';
import 'package:bienen_app/features/construction/presentation/widgets/build_step_card.dart';

class ConstructionPage extends ConsumerWidget {
  const ConstructionPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kat = ref.watch(selectedBauKategorieProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Bau')),
      body: Column(
        children: [
          const _KategorieSelector(),
          Expanded(
            child: switch (kat) {
              BauKategorie.bienenstand => const _BienenstandView(),
              BauKategorie.honigverarbeitung => const HonigverarbeitungView(),
            },
          ),
        ],
      ),
    );
  }
}

/// Horizontal scrollbarer Kategorie-Umschalter (skaliert für spätere Bereiche).
class _KategorieSelector extends ConsumerWidget {
  const _KategorieSelector();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sel = ref.watch(selectedBauKategorieProvider);

    Widget chip(BauKategorie k, String label, IconData icon) {
      final active = sel == k;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          avatar: Icon(
            icon,
            size: 18,
            color: active ? AppColors.brown800 : Colors.white70,
          ),
          label: Text(label),
          selected: active,
          showCheckmark: false,
          labelStyle: TextStyle(
            color: active ? AppColors.brown800 : Colors.white,
            fontWeight: FontWeight.w600,
          ),
          backgroundColor: AppColors.brown600,
          selectedColor: AppColors.amber400,
          side: const BorderSide(color: Colors.white24),
          onSelected: (_) =>
              ref.read(selectedBauKategorieProvider.notifier).state = k,
        ),
      );
    }

    return Container(
      width: double.infinity,
      color: AppColors.brown800,
      padding: const EdgeInsets.only(bottom: 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            chip(BauKategorie.bienenstand, 'Bienenstand', Icons.deck),
            chip(BauKategorie.honigverarbeitung, 'Honigverarbeitung',
                Icons.water_drop),
          ],
        ),
      ),
    );
  }
}

/// Bienenstand: die bestehenden zwei Ansichten (Bauplan / Bauschritte).
class _BienenstandView extends StatelessWidget {
  const _BienenstandView();

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
                Tab(text: 'Bauplan', icon: Icon(Icons.architecture)),
                Tab(text: 'Bauschritte', icon: Icon(Icons.checklist)),
              ],
            ),
          ),
          const Expanded(
            child: TabBarView(
              children: [
                BauplanView(),
                _BauschritteTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BauschritteTab extends ConsumerWidget {
  const _BauschritteTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(constructionProgressProvider);
    // Fortschritt wird per stepKey aus dem Provider gelesen (in der Karte);
    // hier nur den Balken + die Liste der Schritte aufbauen.
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(BeeTokens.md),
          color: BeeTokens.honigTint,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Fortschritt: ${progress.done}/${progress.total} Schritte erledigt',
                style: const TextStyle(
                    fontWeight: FontWeight.w600, color: BeeTokens.textPrimaer),
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(BeeTokens.xs),
                child: LinearProgressIndicator(
                  value: progress.total == 0
                      ? 0
                      : progress.done / progress.total,
                  minHeight: 8,
                  backgroundColor: BeeTokens.rand,
                  color: BeeSignal.erfolg.text,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.only(bottom: BeeTokens.xl),
            itemCount: kBuildSteps.length,
            itemBuilder: (_, i) => BuildStepCard(
              content: kBuildSteps[i],
              stepNumber: i + 1,
            ),
          ),
        ),
      ],
    );
  }
}
