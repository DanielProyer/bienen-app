import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bienen_app/core/theme/app_theme.dart';
import 'package:bienen_app/features/construction/data/models/construction_step.dart';
import 'package:bienen_app/features/construction/presentation/pages/bauplan_view.dart';
import 'package:bienen_app/features/construction/presentation/providers/construction_provider.dart';
import 'package:bienen_app/features/construction/presentation/widgets/construction_step_tile.dart';

const _phaseLabels = <String, String>{
  'vorbereitung': 'Vorbereitung',
  'einkauf': 'Einkauf',
  'bau': 'Bau',
  'abnahme': 'Endabnahme',
  'nachkontrolle': 'Nachkontrolle',
};

class ConstructionPage extends StatelessWidget {
  const ConstructionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Bienenstand-Bau'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Bauplan', icon: Icon(Icons.architecture)),
              Tab(text: 'Dokumentation', icon: Icon(Icons.checklist)),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            BauplanView(),
            _DocumentationTab(),
          ],
        ),
      ),
    );
  }
}

class _DocumentationTab extends ConsumerWidget {
  const _DocumentationTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stepsAsync = ref.watch(constructionStepsProvider);
    final progress = ref.watch(constructionProgressProvider);

    return stepsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Fehler: $e')),
      data: (steps) {
        // Nach Phase gruppieren, Reihenfolge über sort_order erhalten
        final phases = <String, List<ConstructionStep>>{};
        for (final s in steps) {
          phases.putIfAbsent(s.phase, () => []).add(s);
        }
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
                    'Fortschritt: ${progress.done}/${progress.total} dokumentiert',
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
                ],
              ),
            ),
            Expanded(
              child: ListView(
                children: [
                  for (final entry in phases.entries) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                      child: Text(
                        _phaseLabels[entry.key] ?? entry.key,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.brown800,
                        ),
                      ),
                    ),
                    for (final step in entry.value)
                      ConstructionStepTile(step: step),
                  ],
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
