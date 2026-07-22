import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:bienen_app/core/supabase/supabase_config.dart';
import 'package:bienen_app/core/theme/app_tokens.dart';
import 'package:bienen_app/features/auth/presentation/auth_providers.dart';
import 'package:bienen_app/features/material/data/models/material_item.dart';
import 'package:bienen_app/features/material/data/models/material_alternatives.dart';
import 'package:bienen_app/features/material/data/models/material_purchase.dart';
import 'package:bienen_app/features/material/presentation/providers/material_provider.dart';
import 'package:bienen_app/shared/widgets/app_button.dart';
import 'package:bienen_app/shared/widgets/app_card.dart';
import 'package:bienen_app/shared/widgets/status_pill.dart';
import 'package:intl/intl.dart';

final _chf = NumberFormat('#,##0.00', 'de_CH');
final _qty = NumberFormat('#,##0.##', 'de_CH');

const _zahlungsarten = ['Barzahlung', 'Twint', 'QR-Rechnung Post', 'Andere'];

class MaterialDetailPage extends ConsumerWidget {
  final MaterialItem item;

  const MaterialDetailPage({super.key, required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Immer die aktuelle Version aus dem Provider verwenden (Bestand ändert sich).
    final items = ref.watch(materialListProvider).valueOrNull ?? [];
    final current = items.firstWhere(
      (i) => i.id == item.id,
      orElse: () => item,
    );
    final alternatives = materialAlternatives[current.name];

    return Scaffold(
      appBar: AppBar(
        title: Text(current.name),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Aktionen',
            onSelected: (value) async {
              if (value == 'archiv') {
                final neu = !current.archiviert;
                try {
                  await ref
                      .read(materialListProvider.notifier)
                      .setArchiviert(current.id, neu);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(neu
                            ? '${current.name} archiviert'
                            : '${current.name} reaktiviert'),
                      ),
                    );
                    Navigator.of(context).pop();
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Fehlgeschlagen: $e')),
                    );
                  }
                }
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'archiv',
                child: Row(
                  children: [
                    Icon(
                      current.archiviert
                          ? Icons.unarchive_outlined
                          : Icons.archive_outlined,
                      size: 20,
                      color: BeeTokens.textSekundaer,
                    ),
                    const SizedBox(width: 8),
                    Text(current.archiviert ? 'Reaktivieren' : 'Archivieren'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Main product card
            _buildMainProductCard(context, current),
            const SizedBox(height: 16),

            // Typ-Umschalter Verbrauchsmaterial / Anlagegut
            _TypeSection(item: current),
            const SizedBox(height: 16),

            // Bilder & Anleitungen (Fotos + PDF-Manuals)
            _MediaSection(item: current),
            const SizedBox(height: 16),

            // Bestand (nur Verbrauchsmaterial)
            if (current.isConsumable) ...[
              _StockSection(item: current),
              const SizedBox(height: 16),
            ],

            // Kauf-Historie
            _PurchaseHistorySection(item: current),
            const SizedBox(height: 24),

            // Alternatives
            if (alternatives != null && alternatives.isNotEmpty) ...[
              const Text(
                'Alternativen & Vergleich',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: BeeTokens.textPrimaer,
                ),
              ),
              const SizedBox(height: 12),
              ...alternatives.map((alt) => _buildAlternativeCard(context, alt)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMainProductCard(BuildContext context, MaterialItem item) {
    final productInfo = materialProductInfo[item.name];

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
            // Header with status
            Row(
              children: [
                StatusPill(
                  label: item.status.toUpperCase(),
                  signal: _statusSignal(item.status),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: BeeTokens.rand,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Phase ${item.phase}',
                    style: const TextStyle(fontSize: 11, color: BeeTokens.textSekundaer),
                  ),
                ),
                const Spacer(),
                Text(
                  item.category,
                  style: const TextStyle(
                    fontSize: 13,
                    color: BeeTokens.textSekundaer,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Name
            Text(
              item.name,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: BeeTokens.textPrimaer,
              ),
            ),
            if (item.description != null) ...[
              const SizedBox(height: 4),
              Text(
                item.description!,
                style: const TextStyle(fontSize: 14, color: BeeTokens.textSekundaer),
              ),
            ],

            // Extended product info
            if (productInfo != null) ...[
              const SizedBox(height: 12),
              Text(
                productInfo,
                style: const TextStyle(fontSize: 13, height: 1.5),
              ),
            ],

            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),

            // Price & quantity
            Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Menge', style: TextStyle(fontSize: 11, color: BeeTokens.textGedaempft)),
                    Text(
                      '${item.quantity}${item.unit != null ? ' ${item.unit}' : ''}',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(width: 32),
                if (item.priceCHF != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Stückpreis', style: TextStyle(fontSize: 11, color: BeeTokens.textGedaempft)),
                      Text(
                        'CHF ${_chf.format(item.priceCHF)}',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('Total', style: TextStyle(fontSize: 11, color: BeeTokens.textGedaempft)),
                    Text(
                      'CHF ${_chf.format(item.totalPrice)}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: BeeTokens.textSekundaer,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            // Supplier & links
            if (item.supplier != null) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 12),
              const Text('Lieferant', style: TextStyle(fontSize: 11, color: BeeTokens.textGedaempft)),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.store, size: 16, color: BeeTokens.textSekundaer),
                  const SizedBox(width: 6),
                  Text(
                    item.supplier!,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: BeeTokens.textPrimaer,
                    ),
                  ),
                ],
              ),
              if (item.supplierUrl != null) ...[
                const SizedBox(height: 8),
                AppButton(
                  label: 'Im Shop öffnen',
                  icon: Icons.open_in_new,
                  kind: AppButtonKind.sekundaer,
                  full: true,
                  onPressed: () => _openUrl(item.supplierUrl!),
                ),
              ],
            ],

            // Notes
            if (item.notes != null) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 12),
              const Text('Notizen', style: TextStyle(fontSize: 11, color: BeeTokens.textGedaempft)),
              const SizedBox(height: 4),
              Text(item.notes!, style: const TextStyle(fontSize: 13)),
            ],
        ],
      ),
    );
  }

  Widget _buildAlternativeCard(BuildContext context, ProductAlternative alt) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: alt.isRecommended ? BeeTokens.honigTint : BeeTokens.karte,
        borderRadius: BorderRadius.circular(BeeTokens.rKarte),
        border: Border.all(
          color: alt.isRecommended ? BeeTokens.honig : BeeTokens.rand,
          width: alt.isRecommended ? 2 : 0.5,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Expanded(
                  child: Text(
                    alt.name,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
                if (alt.isRecommended)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: BeeTokens.honig,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'EMPFEHLUNG',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
              ],
            ),

            // Supplier & Price
            const SizedBox(height: 6),
            Row(
              children: [
                Text(
                  alt.supplier,
                  style: const TextStyle(fontSize: 12, color: BeeTokens.textSekundaer),
                ),
                const Spacer(),
                Text(
                  alt.price,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: BeeTokens.textSekundaer,
                  ),
                ),
              ],
            ),

            // Pros
            if (alt.pros.isNotEmpty) ...[
              const SizedBox(height: 10),
              ...alt.pros.map((pro) => Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.add_circle, size: 14, color: BeeSignal.erfolg.text),
                        const SizedBox(width: 6),
                        Expanded(child: Text(pro, style: const TextStyle(fontSize: 12))),
                      ],
                    ),
                  )),
            ],

            // Cons
            if (alt.cons.isNotEmpty) ...[
              const SizedBox(height: 6),
              ...alt.cons.map((con) => Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.remove_circle, size: 14, color: BeeSignal.gefahr.text),
                        const SizedBox(width: 6),
                        Expanded(child: Text(con, style: const TextStyle(fontSize: 12))),
                      ],
                    ),
                  )),
            ],

            // Link
            if (alt.url != null) ...[
              const SizedBox(height: 10),
              InkWell(
                onTap: () => _openUrl(alt.url!),
                child: Row(
                  children: [
                    Icon(Icons.open_in_new, size: 14, color: BeeSignal.info.text),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        alt.url!,
                        style: TextStyle(
                          fontSize: 11,
                          color: BeeSignal.info.text,
                          decoration: TextDecoration.underline,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  BeeSignal _statusSignal(String status) {
    switch (status) {
      case 'bestellt':
        return BeeSignal.warnung;
      case 'gekauft':
        return BeeSignal.erfolg;
      default:
        return BeeSignal.neutral;
    }
  }

  void _openUrl(String url) {
    launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }
}

// ---------------------------------------------------------------------------
// Typ-Umschalter: Verbrauchsmaterial <-> Anlagegut. Steuert u.a., ob der
// Bestand-Abschnitt (nur Verbrauch) sichtbar ist.
// ---------------------------------------------------------------------------
class _TypeSection extends ConsumerWidget {
  final MaterialItem item;
  const _TypeSection({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
            const Text(
              'Materialtyp',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: BeeTokens.textPrimaer,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Verbrauch wird regelmäßig nachgekauft; Anlagegut einmalig '
              '(Beute, Werkzeug…).',
              style: TextStyle(fontSize: 12, color: BeeTokens.textSekundaer),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(
                    value: true,
                    label: Text('Verbrauch'),
                    icon: Icon(Icons.inventory_2_outlined, size: 18),
                  ),
                  ButtonSegment(
                    value: false,
                    label: Text('Anlagegut'),
                    icon: Icon(Icons.build_outlined, size: 18),
                  ),
                ],
                selected: {item.isConsumable},
                onSelectionChanged: (sel) async {
                  final wert = sel.first;
                  if (wert == item.isConsumable) return;
                  try {
                    await ref
                        .read(materialListProvider.notifier)
                        .updateIsConsumable(item.id, wert);
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Umstellen fehlgeschlagen: $e')),
                      );
                    }
                  }
                },
              ),
            ),
          ],
        ),
    );
  }
}

// ---------------------------------------------------------------------------
// Bilder & Anleitungen: bis 4 Produktfotos + bis 4 PDF-Manuals je Artikel.
// Standard 1 Foto / 0 PDF; zeigt nur was vorhanden ist. Storage: material-media.
// ---------------------------------------------------------------------------
class _MediaSection extends ConsumerStatefulWidget {
  final MaterialItem item;
  const _MediaSection({required this.item});

  @override
  ConsumerState<_MediaSection> createState() => _MediaSectionState();
}

class _MediaSectionState extends ConsumerState<_MediaSection> {
  static const _bucket = 'material-media';
  static const _maxPhotos = 4;
  static const _maxPdfs = 4;
  bool _busy = false;

  MaterialItem get _item {
    final items = ref.watch(materialListProvider).valueOrNull ?? [];
    return items.firstWhere((i) => i.id == widget.item.id,
        orElse: () => widget.item);
  }

  void _snack(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  Future<ImageSource?> _pickSource() => showModalBottomSheet<ImageSource>(
        context: context,
        builder: (ctx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_camera),
                title: const Text('Kamera'),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Galerie'),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
            ],
          ),
        ),
      );

  Future<void> _addPhoto() async {
    final item = _item;
    if (item.photoUrls.length >= _maxPhotos) return;
    final source = await _pickSource();
    if (source == null) return;
    setState(() => _busy = true);
    try {
      final file = await ImagePicker()
          .pickImage(source: source, imageQuality: 75, maxWidth: 2000);
      if (file == null) return;
      final bytes = await file.readAsBytes();
      final betriebId = ref.read(currentBetriebIdProvider);
      if (betriebId == null) {
        _snack('Kein Betrieb aktiv — bitte neu anmelden.');
        return;
      }
      // <betrieb_id>/-Praefix: mandanten-scoped (Storage-Policies A10).
      final path =
          '$betriebId/${item.id}/photo_${DateTime.now().millisecondsSinceEpoch}.jpg';
      await SupabaseConfig.client.storage.from(_bucket).uploadBinary(
            path,
            bytes,
            fileOptions:
                const FileOptions(upsert: true, contentType: 'image/jpeg'),
          );
      final url = SupabaseConfig.client.storage.from(_bucket).getPublicUrl(path);
      await ref
          .read(materialListProvider.notifier)
          .updatePhotoUrls(item.id, [...item.photoUrls, url]);
    } catch (e) {
      _snack('Foto fehlgeschlagen: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _removePhoto(String url) async {
    final item = _item;
    final updated = item.photoUrls.where((u) => u != url).toList();
    try {
      await ref
          .read(materialListProvider.notifier)
          .updatePhotoUrls(item.id, updated);
      await _removeStorageObject(url);
    } catch (e) {
      _snack('Löschen fehlgeschlagen: $e');
    }
  }

  Future<void> _addPdf() async {
    final item = _item;
    if (item.pdfUrls.length >= _maxPdfs) return;
    setState(() => _busy = true);
    try {
      final res = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: true,
      );
      if (res == null || res.files.isEmpty) return;
      final f = res.files.first;
      final bytes = f.bytes;
      if (bytes == null) {
        _snack('PDF konnte nicht gelesen werden.');
        return;
      }
      final betriebId = ref.read(currentBetriebIdProvider);
      if (betriebId == null) {
        _snack('Kein Betrieb aktiv — bitte neu anmelden.');
        return;
      }
      final path =
          '$betriebId/${item.id}/pdf_${DateTime.now().millisecondsSinceEpoch}.pdf';
      await SupabaseConfig.client.storage.from(_bucket).uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(
                upsert: true, contentType: 'application/pdf'),
          );
      final url = SupabaseConfig.client.storage.from(_bucket).getPublicUrl(path);
      final name =
          f.name.trim().isNotEmpty ? f.name.trim() : 'Anleitung ${item.pdfUrls.length + 1}.pdf';
      await ref.read(materialListProvider.notifier).updatePdfs(
        item.id,
        [...item.pdfUrls, url],
        [...item.pdfNames, name],
      );
    } catch (e) {
      _snack('PDF fehlgeschlagen: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _removePdf(int index) async {
    final item = _item;
    if (index < 0 || index >= item.pdfUrls.length) return;
    final removedUrl = item.pdfUrls[index];
    final urls = [...item.pdfUrls]..removeAt(index);
    final names = [...item.pdfNames];
    if (index < names.length) names.removeAt(index);
    try {
      await ref.read(materialListProvider.notifier).updatePdfs(item.id, urls, names);
      await _removeStorageObject(removedUrl);
    } catch (e) {
      _snack('Löschen fehlgeschlagen: $e');
    }
  }

  Future<void> _removeStorageObject(String url) async {
    const marker = '/$_bucket/';
    final i = url.indexOf(marker);
    if (i < 0) return;
    final path = url.substring(i + marker.length).split('?').first;
    try {
      await SupabaseConfig.client.storage.from(_bucket).remove([path]);
    } catch (_) {}
  }

  void _viewImage(String url) {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        child: InteractiveViewer(
          child: Image.network(
            url,
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
  Widget build(BuildContext context) {
    final item = _item;
    final photos = item.photoUrls;
    final pdfs = item.pdfUrls;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
            Row(
              children: [
                const Icon(Icons.perm_media_outlined,
                    size: 18, color: BeeTokens.textSekundaer),
                const SizedBox(width: 6),
                const Text(
                  'Bilder & Anleitungen',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: BeeTokens.textPrimaer),
                ),
                const Spacer(),
                if (_busy)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // Fotos
            const Text('Fotos',
                style: TextStyle(fontSize: 12, color: BeeTokens.textGedaempft)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final url in photos) _photoThumb(url),
                if (photos.length < _maxPhotos)
                  _addTile(Icons.add_a_photo_outlined, 'Foto',
                      _busy ? null : _addPhoto),
              ],
            ),
            const SizedBox(height: 16),

            // PDFs
            const Text('Anleitungen (PDF)',
                style: TextStyle(fontSize: 12, color: BeeTokens.textGedaempft)),
            const SizedBox(height: 6),
            if (pdfs.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 2),
                child: Text('Keine Anleitung hinterlegt.',
                    style: TextStyle(fontSize: 12, color: BeeTokens.textGedaempft)),
              ),
            for (int i = 0; i < pdfs.length; i++) _pdfRow(i, pdfs[i]),
            if (pdfs.length < _maxPdfs) ...[
              const SizedBox(height: 6),
              AppButton(
                label: 'PDF hinzufügen',
                icon: Icons.picture_as_pdf_outlined,
                kind: AppButtonKind.sekundaer,
                onPressed: _busy ? null : _addPdf,
              ),
            ],
          ],
        ),
    );
  }

  Widget _photoThumb(String url) {
    return SizedBox(
      width: 76,
      height: 76,
      child: Stack(
        children: [
          GestureDetector(
            onTap: () => _viewImage(url),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                url,
                width: 76,
                height: 76,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  width: 76,
                  height: 76,
                  color: BeeTokens.rand,
                  child: const Icon(Icons.broken_image,
                      color: BeeTokens.textGedaempft),
                ),
              ),
            ),
          ),
          Positioned(
            top: 0,
            right: 0,
            child: GestureDetector(
              onTap: _busy ? null : () => _removePhoto(url),
              child: Container(
                margin: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                    color: Colors.black54, shape: BoxShape.circle),
                padding: const EdgeInsets.all(2),
                child: const Icon(Icons.close, size: 14, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _addTile(IconData icon, String label, VoidCallback? onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 76,
        height: 76,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: BeeTokens.honig),
          color: BeeTokens.honigTint,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: BeeTokens.textSekundaer, size: 22),
            const SizedBox(height: 2),
            Text(label,
                style:
                    const TextStyle(fontSize: 11, color: BeeTokens.textSekundaer)),
          ],
        ),
      ),
    );
  }

  Widget _pdfRow(int i, String url) {
    final item = _item;
    final name = i < item.pdfNames.length && item.pdfNames[i].isNotEmpty
        ? item.pdfNames[i]
        : 'Anleitung ${i + 1}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(Icons.picture_as_pdf, color: BeeSignal.gefahr.text, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(name,
                style: const TextStyle(fontSize: 13),
                overflow: TextOverflow.ellipsis),
          ),
          IconButton(
            icon: const Icon(Icons.open_in_new, size: 18),
            color: BeeTokens.textSekundaer,
            tooltip: 'Öffnen',
            onPressed: () =>
                launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
          ),
          IconButton(
            icon: Icon(Icons.delete_outline, size: 18, color: BeeSignal.gefahr.text),
            tooltip: 'Entfernen',
            onPressed: _busy ? null : () => _removePdf(i),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Bestand-Abschnitt (Verbrauchsmaterial): Bestand +/- / setzen, Mindestbestand
// ---------------------------------------------------------------------------
class _StockSection extends ConsumerWidget {
  final MaterialItem item;
  const _StockSection({required this.item});

  Future<void> _editValue(
    BuildContext context,
    WidgetRef ref, {
    required String title,
    required double initial,
    required Future<void> Function(double) onSave,
  }) async {
    final controller =
        TextEditingController(text: _qty.format(initial).replaceAll("'", ''));
    try {
      final result = await showDialog<double>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(title),
          content: TextField(
            controller: controller,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(hintText: 'Zahl eingeben…'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Abbrechen'),
            ),
            FilledButton(
              onPressed: () {
                final v = double.tryParse(
                    controller.text.replaceAll(',', '.').trim());
                if (v != null) Navigator.pop(ctx, v);
              },
              child: const Text('Speichern'),
            ),
          ],
        ),
      );
      if (result != null) {
        try {
          await onSave(result);
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Speichern fehlgeschlagen: $e')),
            );
          }
        }
      }
    } finally {
      controller.dispose();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(materialListProvider.notifier);
    final low = item.stockQty < item.minQty;

    Future<void> setStock(double v) =>
        notifier.updateStock(item.id, v < 0 ? 0 : v);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
            const Text(
              'Bestand',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: BeeTokens.textPrimaer,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text('Aktueller Bestand',
                    style: TextStyle(fontSize: 13, color: BeeTokens.textSekundaer)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  color: BeeTokens.textSekundaer,
                  onPressed: () => setStock(item.stockQty - 1),
                ),
                InkWell(
                  onTap: () => _editValue(
                    context,
                    ref,
                    title: 'Bestand setzen',
                    initial: item.stockQty,
                    onSave: setStock,
                  ),
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: Text(
                      _qty.format(item.stockQty),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: low ? BeeSignal.gefahr.text : BeeTokens.textPrimaer,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  color: BeeTokens.textSekundaer,
                  onPressed: () => setStock(item.stockQty + 1),
                ),
              ],
            ),
            const Divider(),
            Row(
              children: [
                const Text('Mindestbestand',
                    style: TextStyle(fontSize: 13, color: BeeTokens.textSekundaer)),
                const Spacer(),
                InkWell(
                  onTap: () => _editValue(
                    context,
                    ref,
                    title: 'Mindestbestand setzen',
                    initial: item.minQty,
                    onSave: (v) => notifier.updateMinQty(item.id, v < 0 ? 0 : v),
                  ),
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _qty.format(item.minQty),
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(width: 6),
                        const Icon(Icons.edit, size: 14, color: BeeTokens.textGedaempft),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            if (low) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.warning_amber, size: 15, color: BeeSignal.gefahr.text),
                  const SizedBox(width: 6),
                  Text(
                    'Unter Mindestbestand – nachkaufen',
                    style: TextStyle(fontSize: 12, color: BeeSignal.gefahr.text),
                  ),
                ],
              ),
            ],
          ],
        ),
    );
  }
}

// ---------------------------------------------------------------------------
// Kauf-Historie + „Kauf erfassen"
// ---------------------------------------------------------------------------
class _PurchaseHistorySection extends ConsumerWidget {
  final MaterialItem item;
  const _PurchaseHistorySection({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final purchases = ref.watch(purchasesByMaterialProvider)[item.id] ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Kauf-Historie',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: BeeTokens.textPrimaer,
              ),
            ),
            const Spacer(),
            AppButton(
              label: 'Kauf erfassen',
              icon: Icons.add,
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                builder: (_) => _PurchaseForm(item: item),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (purchases.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Noch keine Käufe erfasst.',
              style: TextStyle(color: BeeTokens.textGedaempft),
            ),
          )
        else
          ...purchases.map((p) => _PurchaseTile(purchase: p)),
      ],
    );
  }
}

class _PurchaseTile extends ConsumerWidget {
  final MaterialPurchase purchase;
  const _PurchaseTile({required this.purchase});

  void _showImage(BuildContext context, String url) {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        child: InteractiveViewer(
          child: Image.network(
            url,
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
    final p = purchase;
    final subtitleParts = <String>[];
    if (p.menge != null) subtitleParts.add('${_qty.format(p.menge)} Stk');
    if (p.stueckpreis != null) {
      subtitleParts.add('à CHF ${_chf.format(p.stueckpreis)}');
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: BeeTokens.sm),
      child: AppCard(
        padding: const EdgeInsets.all(BeeTokens.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (p.belegFoto != null && p.belegFoto!.isNotEmpty) ...[
              GestureDetector(
                onTap: () => _showImage(context, p.belegFoto!),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.network(
                    p.belegFoto!,
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const Icon(Icons.broken_image),
                  ),
                ),
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        p.gekauftAm != null
                            ? DateFormat('dd.MM.yyyy').format(p.gekauftAm!)
                            : 'Ohne Datum',
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                      const Spacer(),
                      if (p.gesamtpreis != null)
                        Text(
                          'CHF ${_chf.format(p.gesamtpreis)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: BeeTokens.textSekundaer,
                          ),
                        ),
                    ],
                  ),
                  if (subtitleParts.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(subtitleParts.join(' · '),
                        style: const TextStyle(
                            fontSize: 12, color: BeeTokens.textSekundaer)),
                  ],
                  if (p.shop != null && p.shop!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.store,
                            size: 13, color: BeeTokens.textGedaempft),
                        const SizedBox(width: 4),
                        Text(p.shop!,
                            style: const TextStyle(
                                fontSize: 12, color: BeeTokens.textSekundaer)),
                      ],
                    ),
                  ],
                  if (p.zahlungsart != null && p.zahlungsart!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.payments_outlined,
                            size: 13, color: BeeTokens.textGedaempft),
                        const SizedBox(width: 4),
                        Text(p.zahlungsart!,
                            style: const TextStyle(
                                fontSize: 12, color: BeeTokens.textSekundaer)),
                      ],
                    ),
                  ],
                  if (p.belegNr != null && p.belegNr!.isNotEmpty)
                    Text('Beleg-Nr: ${p.belegNr}',
                        style: const TextStyle(
                            fontSize: 11, color: BeeTokens.textGedaempft)),
                  if (p.notiz != null && p.notiz!.isNotEmpty)
                    Text(p.notiz!,
                        style: const TextStyle(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                            color: BeeTokens.textSekundaer)),
                ],
              ),
            ),
            IconButton(
              icon: Icon(Icons.delete_outline, color: BeeSignal.gefahr.text),
              tooltip: 'Kauf löschen',
              onPressed: () async {
                try {
                  await ref
                      .read(materialPurchasesProvider.notifier)
                      .deletePurchase(p.id);
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Löschen fehlgeschlagen: $e')),
                    );
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Formular „Kauf erfassen"
// ---------------------------------------------------------------------------
class _PurchaseForm extends ConsumerStatefulWidget {
  final MaterialItem item;
  const _PurchaseForm({required this.item});

  @override
  ConsumerState<_PurchaseForm> createState() => _PurchaseFormState();
}

class _PurchaseFormState extends ConsumerState<_PurchaseForm> {
  late DateTime _date;
  late final TextEditingController _mengeCtrl;
  late final TextEditingController _stueckpreisCtrl;
  late final TextEditingController _shopCtrl;
  late final TextEditingController _belegNrCtrl;
  late final TextEditingController _notizCtrl;
  String? _zahlungsart;
  Uint8List? _photoBytes;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _date = DateTime.now();
    _mengeCtrl =
        TextEditingController(text: widget.item.quantity.toString());
    _stueckpreisCtrl = TextEditingController(
        text: widget.item.priceCHF != null
            ? widget.item.priceCHF!.toStringAsFixed(2)
            : '');
    _shopCtrl = TextEditingController(
        text: widget.item.supplier ?? 'Imkerhof Maienfeld');
    _belegNrCtrl = TextEditingController();
    _notizCtrl = TextEditingController();
    _mengeCtrl.addListener(_recalc);
    _stueckpreisCtrl.addListener(_recalc);
  }

  @override
  void dispose() {
    _mengeCtrl.dispose();
    _stueckpreisCtrl.dispose();
    _shopCtrl.dispose();
    _belegNrCtrl.dispose();
    _notizCtrl.dispose();
    super.dispose();
  }

  void _recalc() => setState(() {});

  double? get _menge =>
      double.tryParse(_mengeCtrl.text.replaceAll(',', '.').trim());
  double? get _stueckpreis =>
      double.tryParse(_stueckpreisCtrl.text.replaceAll(',', '.').trim());
  double get _gesamt => (_menge ?? 0) * (_stueckpreis ?? 0);

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('Kamera'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Galerie'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(
          source: source, imageQuality: 70, maxWidth: 2000);
      if (file == null) return;
      final bytes = await file.readAsBytes();
      setState(() => _photoBytes = bytes);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Foto fehlgeschlagen: $e')),
        );
      }
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final item = widget.item;
    try {
      String? photoUrl;
      if (_photoBytes != null) {
        final betriebId = ref.read(currentBetriebIdProvider);
        if (betriebId == null) {
          setState(() => _saving = false);
          return;
        }
        // Belege sind finanz-/personenbezogen -> mandanten-scoped Pfad.
        final path =
            '$betriebId/${item.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';
        await SupabaseConfig.client.storage
            .from('material-receipts')
            .uploadBinary(
              path,
              _photoBytes!,
              fileOptions:
                  const FileOptions(upsert: true, contentType: 'image/jpeg'),
            );
        photoUrl = SupabaseConfig.client.storage
            .from('material-receipts')
            .getPublicUrl(path);
      }

      final purchase = MaterialPurchase(
        id: '',
        materialId: item.id,
        gekauftAm: _date,
        menge: _menge,
        stueckpreis: _stueckpreis,
        gesamtpreis: _gesamt > 0 ? _gesamt : null,
        shop: _shopCtrl.text.trim().isEmpty ? null : _shopCtrl.text.trim(),
        belegNr:
            _belegNrCtrl.text.trim().isEmpty ? null : _belegNrCtrl.text.trim(),
        belegFoto: photoUrl,
        notiz: _notizCtrl.text.trim().isEmpty ? null : _notizCtrl.text.trim(),
        zahlungsart: _zahlungsart,
      );

      await ref.read(materialPurchasesProvider.notifier).addPurchase(purchase);
      if (item.isConsumable) {
        await ref
            .read(materialListProvider.notifier)
            .updateStock(item.id, item.stockQty + (_menge ?? 0));
      }
      await ref
          .read(materialListProvider.notifier)
          .updateStatus(item.id, 'gekauft');

      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Kauf speichern fehlgeschlagen: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Kauf erfassen',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: BeeTokens.textPrimaer,
              ),
            ),
            const SizedBox(height: 4),
            Text(widget.item.name,
                style: const TextStyle(fontSize: 13, color: BeeTokens.textSekundaer)),
            const SizedBox(height: 16),

            // Datum
            InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(8),
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Datum',
                  border: OutlineInputBorder(),
                  suffixIcon: Icon(Icons.calendar_today, size: 18),
                ),
                child: Text(DateFormat('dd.MM.yyyy').format(_date)),
              ),
            ),
            const SizedBox(height: 12),

            // Menge + Stückpreis
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _mengeCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Menge',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _stueckpreisCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Stückpreis CHF',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                'Gesamt: CHF ${_chf.format(_gesamt)}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: BeeTokens.textSekundaer,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Shop
            TextField(
              controller: _shopCtrl,
              decoration: const InputDecoration(
                labelText: 'Shop',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),

            // Zahlungsart
            DropdownButtonFormField<String>(
              initialValue: _zahlungsart,
              decoration: const InputDecoration(
                labelText: 'Zahlungsart',
                border: OutlineInputBorder(),
              ),
              items: _zahlungsarten
                  .map((z) => DropdownMenuItem(value: z, child: Text(z)))
                  .toList(),
              onChanged: (v) => setState(() => _zahlungsart = v),
            ),
            const SizedBox(height: 12),

            // Beleg-Nr
            TextField(
              controller: _belegNrCtrl,
              decoration: const InputDecoration(
                labelText: 'Beleg-Nr (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),

            // Beleg-Foto
            Row(
              children: [
                AppButton(
                  label: _photoBytes == null ? 'Beleg-Foto' : 'Ersetzen',
                  icon: _photoBytes == null
                      ? Icons.add_a_photo_outlined
                      : Icons.cameraswitch_outlined,
                  kind: AppButtonKind.sekundaer,
                  onPressed: _pickPhoto,
                ),
                const Spacer(),
                if (_photoBytes != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.memory(
                      _photoBytes!,
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // Notiz
            TextField(
              controller: _notizCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Notiz (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            AppButton(
              label: 'Speichern',
              full: true,
              busy: _saving,
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }
}
