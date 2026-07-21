import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bienen_app/core/theme/app_theme.dart';
import 'package:bienen_app/features/material/presentation/providers/material_provider.dart';
import 'package:bienen_app/features/material/presentation/widgets/verbrauch_ansicht.dart';
import 'package:bienen_app/features/material/presentation/widgets/anlagen_ansicht.dart';
import 'package:bienen_app/features/material/presentation/widgets/archiv_ansicht.dart';
import 'package:bienen_app/features/material/presentation/widgets/kosten_dashboard.dart';

class MaterialPage extends ConsumerWidget {
  const MaterialPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final materialsAsync = ref.watch(materialListProvider);
    final nachkaufenCount = ref.watch(nachkaufenCountProvider);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Material & Lager'),
          actions: [
            IconButton(
              icon: const Icon(Icons.archive_outlined),
              tooltip: 'Archiv',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ArchivAnsicht()),
              ),
            ),
          ],
          bottom: TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: AppColors.amber400,
            tabs: [
              // Verbrauch mit Nachkauf-Badge (fällige Nachkäufe).
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Verbrauch'),
                    if (nachkaufenCount > 0) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.amber400,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$nachkaufenCount',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppColors.brown800,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Tab(text: 'Anlagen'),
              const Tab(text: 'Ausgaben'),
            ],
          ),
        ),
        body: materialsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Fehler: $e')),
          data: (_) => const TabBarView(
            children: [
              VerbrauchAnsicht(),
              AnlagenAnsicht(),
              KostenDashboardAnsicht(),
            ],
          ),
        ),
      ),
    );
  }
}
