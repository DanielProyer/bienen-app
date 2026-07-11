import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:bienen_app/core/theme/app_theme.dart';
import 'package:bienen_app/features/construction/data/models/construction_step.dart';
import 'package:bienen_app/features/construction/presentation/providers/construction_provider.dart';

class ConstructionStepTile extends ConsumerWidget {
  final ConstructionStep step;
  const ConstructionStepTile({super.key, required this.step});

  Future<void> _pickPhoto(BuildContext context, WidgetRef ref) async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
      maxWidth: 2000,
    );
    if (file == null) return;
    final Uint8List bytes = await file.readAsBytes();
    try {
      await ref
          .read(constructionStepsProvider.notifier)
          .attachPhoto(step.id, bytes);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Foto-Upload fehlgeschlagen: $e')),
        );
      }
    }
  }

  Future<void> _editNote(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController(text: step.note ?? '');
    try {
      final result = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Notiz · ${step.fotoCode}'),
          content: TextField(
            controller: controller,
            maxLines: 4,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Notiz eingeben…'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Abbrechen'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, controller.text),
              child: const Text('Speichern'),
            ),
          ],
        ),
      );
      if (result != null) {
        try {
          await ref
              .read(constructionStepsProvider.notifier)
              .updateNote(step.id, result);
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Notiz speichern fehlgeschlagen: $e')),
            );
          }
        }
      }
    } finally {
      controller.dispose();
    }
  }

  void _showPhoto(BuildContext context) {
    if (step.photoUrl == null) return;
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        child: InteractiveViewer(
          child: Image.network(
            step.photoUrl!,
            errorBuilder: (_, _, _) => const Padding(
              padding: EdgeInsets.all(24),
              child: Icon(Icons.broken_image, size: 48),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _toggle(BuildContext context, WidgetRef ref, bool done) async {
    try {
      await ref
          .read(constructionStepsProvider.notifier)
          .toggleDone(step.id, done);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Speichern fehlgeschlagen: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              value: step.isDone,
              onChanged: (v) => _toggle(context, ref, v ?? false),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.honey,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          step.fotoCode,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          step.title,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            decoration: step.isDone
                                ? TextDecoration.lineThrough
                                : null,
                            color: step.isDone ? AppColors.brown300 : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (step.soll != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Soll: ${step.soll}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.green800,
                      ),
                    ),
                  ],
                  if (step.note != null && step.note!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      '📝 ${step.note}',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.brown600,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      TextButton.icon(
                        onPressed: () => _pickPhoto(context, ref),
                        icon: Icon(
                          step.photoUrl == null
                              ? Icons.add_a_photo_outlined
                              : Icons.cameraswitch_outlined,
                          size: 18,
                        ),
                        label: Text(step.photoUrl == null ? 'Foto' : 'Ersetzen'),
                      ),
                      TextButton.icon(
                        onPressed: () => _editNote(context, ref),
                        icon: const Icon(Icons.edit_note, size: 18),
                        label: const Text('Notiz'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (step.photoUrl != null)
              GestureDetector(
                onTap: () => _showPhoto(context),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.network(
                    step.photoUrl!,
                    width: 56,
                    height: 56,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const Icon(Icons.broken_image),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
