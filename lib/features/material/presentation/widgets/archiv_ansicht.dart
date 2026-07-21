import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bienen_app/core/theme/app_theme.dart';
import 'package:bienen_app/features/material/presentation/providers/material_provider.dart';
import 'package:bienen_app/features/material/presentation/widgets/material_list_tile.dart';

// ---------------------------------------------------------------------------
// Eigene Seite: archiviertes Material (ausgemustert/Standbau) + reaktivieren.
// ---------------------------------------------------------------------------
class ArchivAnsicht extends ConsumerWidget {
  const ArchivAnsicht({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final archiv = ref.watch(archivItemsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Archiv')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text(
              'Archiviertes Material zählt nicht zum aktiven Betrieb '
              '(z.B. Standbau, alte Ausrüstung).',
              style: TextStyle(fontSize: 13, color: AppColors.brown600),
            ),
          ),
          if (archiv.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Text(
                  'Archiv ist leer.',
                  style: TextStyle(color: AppColors.brown300),
                ),
              ),
            )
          else
            ...archiv.map(
              (item) => MaterialListTile(
                item: item,
                extraInfo: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.honeyDark,
                        side: const BorderSide(color: AppColors.honey),
                        visualDensity: VisualDensity.compact,
                      ),
                      icon: const Icon(Icons.unarchive_outlined, size: 16),
                      label: const Text('reaktivieren'),
                      onPressed: () async {
                        await ref
                            .read(materialListProvider.notifier)
                            .setArchiviert(item.id, false);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('${item.name} reaktiviert'),
                            ),
                          );
                        }
                      },
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
