import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:bienen_app/core/theme/app_tokens.dart';
import 'package:bienen_app/features/auth/presentation/auth_providers.dart';
import 'package:bienen_app/features/construction/data/models/build_step_content.dart';
import 'package:bienen_app/features/construction/data/models/construction_step.dart';
import 'package:bienen_app/features/construction/presentation/providers/construction_provider.dart';
import 'package:bienen_app/shared/widgets/app_button.dart';
import 'package:bienen_app/shared/widgets/app_card.dart';

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
      final betriebId = ref.read(currentBetriebIdProvider);
      if (betriebId == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Kein Betrieb aktiv — bitte neu anmelden.')));
        }
        return;
      }
      await ref
          .read(constructionStepsProvider.notifier)
          .attachPhoto(content.key, bytes, betriebId);
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
              padding: EdgeInsets.all(BeeTokens.xl),
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

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: BeeTokens.md, vertical: 6),
      child: AppCard(
        padding: const EdgeInsets.all(BeeTokens.md),
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
                    color: done ? BeeSignal.erfolg.text : BeeTokens.honig,
                    shape: BoxShape.circle,
                  ),
                  child: done
                      ? const Icon(Icons.check, color: Colors.white, size: 18)
                      : Text('$stepNumber',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: BeeTokens.sm + 2),
                Expanded(
                  child: Text(
                    content.title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: done
                          ? BeeTokens.textGedaempft
                          : BeeTokens.textPrimaer,
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
              const SizedBox(height: BeeTokens.sm),
              SizedBox(
                height: 160,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: content.drawings.length,
                  separatorBuilder: (_, _) => const SizedBox(width: BeeTokens.sm),
                  itemBuilder: (_, i) {
                    final asset = content.drawings[i];
                    return GestureDetector(
                      onTap: () => _showImage(context, AssetImage(asset)),
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: BeeTokens.rand),
                          borderRadius: BorderRadius.circular(BeeTokens.sm),
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
            const SizedBox(height: BeeTokens.sm + 2),
            const Text('So geht\'s',
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: BeeTokens.textPrimaer)),
            const SizedBox(height: BeeTokens.xs),
            for (var i = 0; i < content.instructions.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: BeeTokens.xs),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${i + 1}. ',
                        style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: BeeTokens.textPrimaer)),
                    Expanded(
                      child: Text(content.instructions[i],
                          style: const TextStyle(
                              fontSize: 13,
                              height: 1.4,
                              color: BeeTokens.textPrimaer)),
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
                  Icon(Icons.straighten,
                      size: 16, color: BeeSignal.erfolg.text),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text('Soll: ${content.soll}',
                        style: TextStyle(
                            fontSize: 12.5,
                            color: BeeSignal.erfolg.text,
                            fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ],

            // Tipp
            if (content.tip != null) ...[
              const SizedBox(height: BeeTokens.sm),
              Container(
                padding: const EdgeInsets.all(BeeTokens.sm),
                decoration: BoxDecoration(
                  color: BeeTokens.honigTint,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: BeeTokens.honig, width: 0.5),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.lightbulb_outline,
                        size: 16, color: BeeTokens.textSekundaer),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(content.tip!,
                          style: const TextStyle(
                              fontSize: 12.5,
                              color: BeeTokens.textPrimaer)),
                    ),
                  ],
                ),
              ),
            ],

            // Notiz-Anzeige
            if (progress.note != null && progress.note!.isNotEmpty) ...[
              const SizedBox(height: BeeTokens.sm),
              Text('📝 ${progress.note}',
                  style: const TextStyle(
                      fontSize: 12.5,
                      color: BeeTokens.textGedaempft,
                      fontStyle: FontStyle.italic)),
            ],

            const Divider(height: 20),

            // Aktionen + Foto
            Row(
              children: [
                AppButton(
                  label: progress.photoUrl == null ? 'Foto' : 'Ersetzen',
                  icon: progress.photoUrl == null
                      ? Icons.add_a_photo_outlined
                      : Icons.cameraswitch_outlined,
                  kind: AppButtonKind.text,
                  onPressed: () => _choosePhotoSource(context, ref),
                ),
                AppButton(
                  label: 'Notiz',
                  icon: Icons.edit_note,
                  kind: AppButtonKind.text,
                  onPressed: () => _editNote(context, ref, progress.note),
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
