import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:bienen_app/core/theme/app_tokens.dart';
import 'package:bienen_app/features/wissen/data/wissen_foto_providers.dart';
import 'package:bienen_app/features/wissen/domain/wissen_foto.dart';
import 'package:bienen_app/shared/widgets/confirm_sheet.dart';

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
        const Icon(Icons.photo, size: 16, color: BeeTokens.textSekundaer),
        const SizedBox(width: BeeTokens.sm),
        Text('Meine Beispiele', style: BeeTokens.label),
      ]),
      const SizedBox(height: BeeTokens.sm),
      SizedBox(
        height: 72,
        child: ListView(scrollDirection: Axis.horizontal, children: [
          ...(fotos.valueOrNull ?? const <WissenFoto>[]).map((f) => _Thumb(foto: f, wissenKey: wissenKey)),
          OutlinedButton(
            onPressed: () => _quelleWaehlen(context, ref),
            child: const Column(mainAxisSize: MainAxisSize.min,
                children: [Icon(Icons.add), Text('Foto', style: BeeTokens.gedaempft)]),
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
      padding: const EdgeInsets.only(right: BeeTokens.sm),
      child: GestureDetector(
        onLongPress: () async {
          final ok = await confirmSheet(context,
              titel: 'Foto löschen?', bestaetigenLabel: 'Löschen', gefahr: true);
          if (ok) await ref.read(wissenFotosProvider(wissenKey).notifier).loeschen(foto);
        },
        child: FutureBuilder<String>(
          future: repo.signierteUrl(foto.storagePath),
          builder: (context, snap) => ClipRRect(
            borderRadius: BorderRadius.circular(BeeTokens.sm),
            child: snap.hasData
                ? Image.network(snap.data!, width: 72, height: 72, fit: BoxFit.cover)
                : Container(width: 72, height: 72, color: BeeTokens.rand,
                    child: const Icon(Icons.image, color: BeeTokens.chevron)),
          ),
        ),
      ),
    );
  }
}
