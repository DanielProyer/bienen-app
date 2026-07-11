import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:bienen_app/core/theme/app_theme.dart';
import 'package:bienen_app/features/construction/data/models/build_step_content.dart';
import 'package:bienen_app/features/construction/data/models/construction_step.dart';
import 'package:bienen_app/features/construction/presentation/providers/construction_provider.dart';

class BuildStepCard extends ConsumerWidget {
  final BuildStepContent content;
  final int stepNumber;

  const BuildStepCard({
    super.key,
    required this.content,
    required this.stepNumber,
  });

  Future<void> _choosePhotoSource(BuildContext context, WidgetRef ref) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('Kamera'),
              subtitle: const Text('Direkt aufnehmen'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Galerie'),
              subtitle: const Text('Vorhandenes Bild wählen'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source != null && context.mounted) {
      await _pickPhoto(context, ref, source);
    }
  }

  Future<void> _pickPhoto(
      BuildContext context, WidgetRef ref, ImageSource source) async {
    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(
        source: source,
        imageQuality: 70,
        maxWidth: 2000,
      );
      if (file == null) return;
      final Uint8List bytes = await file.readAsBytes();
      await ref
          .read(constructionStepsProvider.notifier)
          .attachPhoto(content.key, bytes);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Foto fehlgeschlagen: $e')),
        );
      }
    }
  }

  Future<void> _editNote(BuildContext context, WidgetRef ref, String? current) async {
    final controller = TextEditingController(text: current ?? '');
    try {
      final result = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Notiz · Schritt $stepNumber'),
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
              .updateNote(content.key, result);
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

  Future<void> _toggle(BuildContext context, WidgetRef ref, bool done) async {
    try {
      await ref
          .read(constructionStepsProvider.notifier)
          .toggleDone(content.key, done);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Speichern fehlgeschlagen: $e')),
        );
      }
    }
  }

  void _showImage(BuildContext context, ImageProvider image) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        child: InteractiveViewer(
          child: Image(
            image: image,
            errorBuilder: (_, _, _) => const Padding(
              padding: EdgeInsets.all(24),
              child: Icon(Icons.broken_image, size: 48),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(constructionProgressMapProvider)[content.key] ??
        ConstructionStep(stepKey: content.key);
    final done = progress.isDone;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Kopf: Nummer + Titel + Checkbox
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: done ? AppColors.green600 : AppColors.honey,
                    shape: BoxShape.circle,
                  ),
                  child: done
                      ? const Icon(Icons.check, color: Colors.white, size: 18)
                      : Text('$stepNumber',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    content.title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: done ? AppColors.brown300 : AppColors.brown800,
                      decoration: done ? TextDecoration.lineThrough : null,
                    ),
                  ),
                ),
                Checkbox(
                  value: done,
                  onChanged: (v) => _toggle(context, ref, v ?? false),
                ),
              ],
            ),

            // Zeichnungen
            if (content.drawings.isNotEmpty) ...[
              const SizedBox(height: 8),
              SizedBox(
                height: 160,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: content.drawings.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final asset = content.drawings[i];
                    return GestureDetector(
                      onTap: () => _showImage(context, AssetImage(asset)),
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.brown100),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Image.asset(asset, fit: BoxFit.contain),
                      ),
                    );
                  },
                ),
              ),
            ],

            // Anleitung
            const SizedBox(height: 10),
            const Text('So geht\'s',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            const SizedBox(height: 4),
            for (var i = 0; i < content.instructions.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${i + 1}. ',
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13)),
                    Expanded(
                      child: Text(content.instructions[i],
                          style: const TextStyle(fontSize: 13, height: 1.4)),
                    ),
                  ],
                ),
              ),

            // Soll
            if (content.soll != null) ...[
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.straighten,
                      size: 16, color: AppColors.green800),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text('Soll: ${content.soll}',
                        style: const TextStyle(
                            fontSize: 12.5,
                            color: AppColors.green800,
                            fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ],

            // Tipp
            if (content.tip != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.amber50,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.amber200),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.lightbulb_outline,
                        size: 16, color: AppColors.honeyDark),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(content.tip!,
                          style: const TextStyle(
                              fontSize: 12.5, color: AppColors.brown800)),
                    ),
                  ],
                ),
              ),
            ],

            // Notiz-Anzeige
            if (progress.note != null && progress.note!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('📝 ${progress.note}',
                  style: const TextStyle(
                      fontSize: 12.5,
                      color: AppColors.brown600,
                      fontStyle: FontStyle.italic)),
            ],

            const Divider(height: 20),

            // Aktionen + Foto
            Row(
              children: [
                TextButton.icon(
                  onPressed: () => _choosePhotoSource(context, ref),
                  icon: Icon(
                    progress.photoUrl == null
                        ? Icons.add_a_photo_outlined
                        : Icons.cameraswitch_outlined,
                    size: 18,
                  ),
                  label: Text(progress.photoUrl == null ? 'Foto' : 'Ersetzen'),
                ),
                TextButton.icon(
                  onPressed: () => _editNote(context, ref, progress.note),
                  icon: const Icon(Icons.edit_note, size: 18),
                  label: const Text('Notiz'),
                ),
                const Spacer(),
                if (progress.photoUrl != null)
                  GestureDetector(
                    onTap: () =>
                        _showImage(context, NetworkImage(progress.photoUrl!)),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.network(
                        progress.photoUrl!,
                        width: 52,
                        height: 52,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) =>
                            const Icon(Icons.broken_image),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
