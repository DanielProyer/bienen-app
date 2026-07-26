import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
        padding: const EdgeInsets.only(right: BeeTokens.sm),
        child: ChoiceChip(
          avatar: Icon(
            icon,
            size: 18,
            color: active ? BeeTokens.honig : BeeTokens.textGedaempft,
          ),
          label: Text(label),
          selected: active,
          showCheckmark: false,
          labelStyle: TextStyle(
            color: active ? BeeTokens.textPrimaer : BeeTokens.textGedaempft,
            fontWeight: FontWeight.w500,
          ),
          backgroundColor: BeeTokens.karte,
          selectedColor: BeeTokens.honigTint,
          side: const BorderSide(color: BeeTokens.rand, width: 0.5),
          onSelected: (_) =>
              ref.read(selectedBauKategorieProvider.notifier).state = k,
        ),
      );
    }

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: BeeTokens.karte,
        border: Border(bottom: BorderSide(color: BeeTokens.rand, width: 0.5)),
      ),
      padding: const EdgeInsets.only(bottom: BeeTokens.sm),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: BeeTokens.md),
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
            color: BeeTokens.karte,
            child: Container(
              decoration: const BoxDecoration(
                border: Border(
                    bottom: BorderSide(color: BeeTokens.rand, width: 0.5)),
              ),
              child: const TabBar(
                labelColor: BeeTokens.textPrimaer,
                unselectedLabelColor: BeeTokens.textGedaempft,
                indicatorColor: BeeTokens.honig,
                indicatorWeight: 3,
                tabs: [
                  Tab(text: 'Bauplan', icon: Icon(Icons.architecture)),
                  Tab(text: 'Bauschritte', icon: Icon(Icons.checklist)),
                ],
              ),
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
