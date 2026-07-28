import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:bienen_app/core/theme/app_tokens.dart';
import 'package:bienen_app/features/recherche/data/recherche_foto_providers.dart';
import 'package:bienen_app/features/recherche/domain/recherche_foto.dart';
import 'package:bienen_app/shared/widgets/confirm_sheet.dart';

/// Zeigt die eigenen Fotos EINES Kapitels unter dessen Abschnitt.
///
/// Bewusst ohne eigenen Hinzufügen-Knopf: Bei bis zu 18 Kapiteln je Dokument
/// wären 18 Knöpfe mehr Rauschen als Nutzen. Das Hinzufügen läuft über die
/// Kopfzeile (siehe [fotoErgaenzenSheet]), wo das Kapitel gewählt wird.
/// Ist nichts vorhanden, rendert das Widget gar nichts.
class RechercheFotoStrip extends ConsumerWidget {
  final String rechercheKey;
  final String? anker;
  const RechercheFotoStrip({
    super.key,
    required this.rechercheKey,
    required this.anker,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alle = ref.watch(rechercheFotosProvider(rechercheKey)).valueOrNull;
    if (alle == null || alle.isEmpty) return const SizedBox.shrink();

    final meine = alle.where((f) => f.anker == anker).toList();
    if (meine.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: BeeTokens.sm, bottom: BeeTokens.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.photo_camera_outlined,
                size: 16, color: BeeTokens.textSekundaer),
            const SizedBox(width: BeeTokens.sm),
            Text('Eigene Fotos', style: BeeTokens.label),
          ]),
          const SizedBox(height: BeeTokens.sm),
          SizedBox(
            height: 96,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: meine.length,
              itemBuilder: (_, i) =>
                  _Bild(foto: meine[i], rechercheKey: rechercheKey),
            ),
          ),
        ],
      ),
    );
  }
}

class _Bild extends ConsumerWidget {
  final RechercheFoto foto;
  final String rechercheKey;
  const _Bild({required this.foto, required this.rechercheKey});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(rechercheFotoRepositoryProvider);
    return Padding(
      padding: const EdgeInsets.only(right: BeeTokens.sm),
      child: GestureDetector(
        // Antippen öffnet das Foto gross — dort liegt auch das Löschen.
        // Der Langdruck bleibt als Abkürzung, war aber als EINZIGER Weg
        // unauffindbar: Auf dem Handy sieht man einer Vorschau nicht an,
        // dass sie lange gedrückt werden will.
        onTap: () => zeigeFotoGross(context, ref,
            foto: foto, rechercheKey: rechercheKey),
        onLongPress: () => _loeschenFragen(context, ref),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FutureBuilder<String>(
              future: repo.signierteUrl(foto.storagePath),
              builder: (context, snap) => ClipRRect(
                borderRadius: BorderRadius.circular(BeeTokens.sm),
                child: snap.hasData
                    ? Image.network(snap.data!,
                        width: 96, height: 72, fit: BoxFit.cover)
                    : Container(
                        width: 96,
                        height: 72,
                        color: BeeTokens.rand,
                        child: const Icon(Icons.image, color: BeeTokens.chevron),
                      ),
              ),
            ),
            if (foto.beschriftung != null)
              SizedBox(
                width: 96,
                child: Text(foto.beschriftung!,
                    style: BeeTokens.gedaempft,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _loeschenFragen(BuildContext context, WidgetRef ref) async {
    final ok = await confirmSheet(context,
        titel: 'Foto löschen?', bestaetigenLabel: 'Löschen', gefahr: true);
    if (!ok) return;
    await ref.read(rechercheFotosProvider(rechercheKey).notifier).loeschen(foto);
  }
}

/// Zeigt ein eigenes Foto formatfüllend — mit Zoom, Beschriftung und der
/// Möglichkeit, es zu löschen.
///
/// Die Vorschau im Streifen ist nur 96 x 72 gross; ohne diese Ansicht gäbe es
/// keinen Weg, das eigene Foto überhaupt anzusehen.
Future<void> zeigeFotoGross(
  BuildContext context,
  WidgetRef ref, {
  required RechercheFoto foto,
  required String rechercheKey,
}) async {
  final repo = ref.read(rechercheFotoRepositoryProvider);
  await showDialog<void>(
    context: context,
    barrierColor: Colors.black87,
    builder: (dialogContext) => Dialog(
      insetPadding: const EdgeInsets.all(BeeTokens.md),
      backgroundColor: Colors.transparent,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: FutureBuilder<String>(
              future: repo.signierteUrl(foto.storagePath),
              builder: (context, snap) {
                if (snap.hasError) {
                  return const Padding(
                    padding: EdgeInsets.all(BeeTokens.xl),
                    child: Text('Foto konnte nicht geladen werden.',
                        style: TextStyle(color: Colors.white)),
                  );
                }
                if (!snap.hasData) {
                  return const Padding(
                    padding: EdgeInsets.all(BeeTokens.xl),
                    child: CircularProgressIndicator(),
                  );
                }
                return InteractiveViewer(
                  maxScale: 5,
                  child: Image.network(snap.data!, fit: BoxFit.contain),
                );
              },
            ),
          ),
          const SizedBox(height: BeeTokens.md),
          if (foto.beschriftung != null)
            Padding(
              padding: const EdgeInsets.only(bottom: BeeTokens.sm),
              child: Text(foto.beschriftung!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white)),
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton.icon(
                onPressed: () async {
                  final ok = await confirmSheet(dialogContext,
                      titel: 'Foto löschen?',
                      bestaetigenLabel: 'Löschen',
                      gefahr: true);
                  if (!ok) return;
                  await ref
                      .read(rechercheFotosProvider(rechercheKey).notifier)
                      .loeschen(foto);
                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                },
                icon: const Icon(Icons.delete_outline, color: Colors.white),
                label: const Text('Löschen',
                    style: TextStyle(color: Colors.white)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Schliessen',
                    style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

/// Fragt Kapitel, Beschriftung und Bildquelle ab und lädt das Foto hoch.
///
/// [kapitel] ist die Liste der Anker mit ihrer Überschrift; der erste Eintrag
/// darf `null` als Anker haben (= „ganzes Dokument").
Future<void> fotoErgaenzenSheet(
  BuildContext context,
  WidgetRef ref, {
  required String rechercheKey,
  required List<({String? anker, String titel})> kapitel,
  String? vorauswahl,
}) async {
  String? gewaehlt = vorauswahl ?? (kapitel.isNotEmpty ? kapitel.first.anker : null);
  final beschriftung = TextEditingController();

  final quelle = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => StatefulBuilder(
      builder: (sheetContext, setSheetState) => SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            left: BeeTokens.xl,
            right: BeeTokens.xl,
            top: BeeTokens.xl,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + BeeTokens.xl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Eigenes Foto ergänzen', style: BeeTokens.titel),
              const SizedBox(height: BeeTokens.md),
              DropdownButtonFormField<String?>(
                initialValue: gewaehlt,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Zu welchem Kapitel?',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final k in kapitel)
                    DropdownMenuItem<String?>(
                      value: k.anker,
                      child: Text(k.titel, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (v) => setSheetState(() => gewaehlt = v),
              ),
              const SizedBox(height: BeeTokens.md),
              TextField(
                controller: beschriftung,
                decoration: const InputDecoration(
                  labelText: 'Beschriftung (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: BeeTokens.lg),
              Wrap(spacing: BeeTokens.sm, children: [
                FilledButton.icon(
                  onPressed: () => Navigator.pop(sheetContext, 'kamera'),
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Kamera'),
                ),
                OutlinedButton.icon(
                  onPressed: () => Navigator.pop(sheetContext, 'galerie'),
                  icon: const Icon(Icons.photo_library),
                  label: const Text('Galerie'),
                ),
                OutlinedButton.icon(
                  onPressed: () => Navigator.pop(sheetContext, 'datei'),
                  icon: const Icon(Icons.insert_drive_file),
                  label: const Text('Datei'),
                ),
              ]),
            ],
          ),
        ),
      ),
    ),
  );

  if (quelle == null) return;

  Uint8List? bytes;
  if (quelle == 'datei') {
    final res = await FilePicker.platform
        .pickFiles(type: FileType.image, withData: true);
    if (res != null && res.files.isNotEmpty) bytes = res.files.first.bytes;
  } else {
    final x = await ImagePicker().pickImage(
      source: quelle == 'kamera' ? ImageSource.camera : ImageSource.gallery,
      imageQuality: 75,
      maxWidth: 2000,
    );
    if (x != null) bytes = await x.readAsBytes();
  }
  if (bytes == null) return;

  await ref.read(rechercheFotosProvider(rechercheKey).notifier).ergaenze(
        jpegBytes: bytes,
        anker: gewaehlt,
        beschriftung: beschriftung.text,
      );
}
