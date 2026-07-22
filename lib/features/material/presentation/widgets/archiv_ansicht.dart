import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bienen_app/core/theme/app_tokens.dart';
import 'package:bienen_app/features/material/presentation/providers/material_provider.dart';
import 'package:bienen_app/features/material/presentation/widgets/material_list_tile.dart';
import 'package:bienen_app/shared/widgets/app_button.dart';
import 'package:bienen_app/shared/widgets/empty_state.dart';

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
        padding: const EdgeInsets.all(BeeTokens.lg),
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: BeeTokens.md),
            child: Text(
              'Archiviertes Material zählt nicht zum aktiven Betrieb '
              '(z.B. Standbau, alte Ausrüstung).',
              style: TextStyle(fontSize: 13, color: BeeTokens.textSekundaer),
            ),
          ),
          if (archiv.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: BeeTokens.xl),
              child: EmptyState(
                icon: Icons.archive_outlined,
                titel: 'Archiv ist leer.',
              ),
            )
          else
            ...archiv.map(
              (item) => MaterialListTile(
                item: item,
                extraInfo: Padding(
                  padding: const EdgeInsets.only(top: BeeTokens.sm),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: AppButton(
                      label: 'reaktivieren',
                      icon: Icons.unarchive_outlined,
                      kind: AppButtonKind.sekundaer,
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
