import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:bienen_app/features/wissen/data/wissen_foto_providers.dart';
import 'package:bienen_app/features/wissen/domain/wissen_foto.dart';

class WissenFotoStrip extends ConsumerWidget {
  final String wissenKey;
  const WissenFotoStrip({super.key, required this.wissenKey});

  Future<void> _upload(WidgetRef ref, Uint8List? bytes) async {
    if (bytes == null) return;
    await ref.read(wissenFotosProvider(wissenKey).notifier).ergaenze(jpegBytes: bytes);
  }

  Future<void> _quelleWaehlen(BuildContext context, WidgetRef ref) async {
    final quelle = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(leading: const Icon(Icons.camera_alt), title: const Text('Kamera'),
              onTap: () => Navigator.pop(context, 'kamera')),
          ListTile(leading: const Icon(Icons.photo_library), title: const Text('Galerie'),
              onTap: () => Navigator.pop(context, 'galerie')),
          ListTile(leading: const Icon(Icons.insert_drive_file), title: const Text('Dokumente'),
              onTap: () => Navigator.pop(context, 'datei')),
        ]),
      ),
    );
    if (quelle == null) return;
    if (quelle == 'datei') {
      final res = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
      final f = (res != null && res.files.isNotEmpty) ? res.files.first : null;
      if (f?.bytes != null) await _upload(ref, f!.bytes);
    } else {
      final x = await ImagePicker().pickImage(
        source: quelle == 'kamera' ? ImageSource.camera : ImageSource.gallery,
        imageQuality: 75, maxWidth: 2000,
      );
      if (x != null) await _upload(ref, await x.readAsBytes());
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fotos = ref.watch(wissenFotosProvider(wissenKey));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Icon(Icons.photo, size: 16),
        const SizedBox(width: 6),
        Text('Meine Beispiele', style: Theme.of(context).textTheme.labelMedium),
      ]),
      const SizedBox(height: 8),
      SizedBox(
        height: 72,
        child: ListView(scrollDirection: Axis.horizontal, children: [
          ...(fotos.valueOrNull ?? const <WissenFoto>[]).map((f) => _Thumb(foto: f, wissenKey: wissenKey)),
          OutlinedButton(
            onPressed: () => _quelleWaehlen(context, ref),
            child: const Column(mainAxisSize: MainAxisSize.min,
                children: [Icon(Icons.add), Text('Foto', style: TextStyle(fontSize: 11))]),
          ),
        ]),
      ),
    ]);
  }
}

class _Thumb extends ConsumerWidget {
  final WissenFoto foto;
  final String wissenKey;
  const _Thumb({required this.foto, required this.wissenKey});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(wissenFotoRepositoryProvider);
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onLongPress: () async {
          final ok = await showDialog<bool>(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text('Foto löschen?'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Abbrechen')),
                TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Löschen')),
              ],
            ),
          );
          if (ok == true) await ref.read(wissenFotosProvider(wissenKey).notifier).loeschen(foto);
        },
        child: FutureBuilder<String>(
          future: repo.signierteUrl(foto.storagePath),
          builder: (context, snap) => ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: snap.hasData
                ? Image.network(snap.data!, width: 72, height: 72, fit: BoxFit.cover)
                : Container(width: 72, height: 72, color: Colors.black12,
                    child: const Icon(Icons.image, color: Colors.black26)),
          ),
        ),
      ),
    );
  }
}
