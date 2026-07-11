import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bienen_app/core/theme/app_theme.dart';
import 'package:bienen_app/features/construction/data/models/build_step_content.dart';
import 'package:bienen_app/features/construction/presentation/pages/bauplan_view.dart';
import 'package:bienen_app/features/construction/presentation/providers/construction_provider.dart';
import 'package:bienen_app/features/construction/presentation/widgets/build_step_card.dart';

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
        body: const TabBarView(
          children: [
            BauplanView(),
            _BauschritteTab(),
          ],
        ),
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
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.only(bottom: 24),
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
