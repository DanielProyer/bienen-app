import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:bienen_app/features/auth/presentation/auth_providers.dart';
import 'package:bienen_app/features/durchsicht/domain/durchsicht_gateway.dart';
import 'package:bienen_app/features/durchsicht/presentation/pages/durchsicht_form_page.dart';
import 'package:bienen_app/features/durchsicht/presentation/providers/durchsicht_provider.dart';

class DurchsichtDetailPage extends ConsumerWidget {
  final String volkId;
  final String durchsichtId;
  const DurchsichtDetailPage({super.key, required this.volkId, required this.durchsichtId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(durchsichtenFuerVolkProvider(volkId));
    final darf = ref.watch(darfSchreibenProvider);
    return async.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Fehler: $e'))),
      data: (list) {
        final i = list.indexWhere((d) => d.id == durchsichtId);
        if (i < 0) {
          return Scaffold(appBar: AppBar(), body: const Center(child: Text('Durchsicht nicht gefunden.')));
        }
        final d = list[i];
        return Scaffold(
          appBar: AppBar(
            title: Text('${d.durchgefuehrtAm.day}.${d.durchgefuehrtAm.month}.${d.durchgefuehrtAm.year}'),
            actions: [
              if (darf) IconButton(icon: const Icon(Icons.edit), onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => DurchsichtFormPage(volkId: volkId, bestehend: d)))),
              if (darf) IconButton(icon: const Icon(Icons.delete_outline), onPressed: () async {
                final ok = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
                  title: const Text('Durchsicht löschen?'),
                  content: const Text('Der Eintrag und seine Fotos werden entfernt.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Abbrechen')),
                    FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Löschen')),
                  ],
                ));
                if (ok == true) {
                  try {
                    await ref.read(durchsichtenFuerVolkProvider(volkId).notifier).loeschen(d);
                    if (context.mounted) context.go('/voelker/$volkId');
                  } on DurchsichtFehler catch (e) {
                    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
                  } catch (e) {
                    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Löschen fehlgeschlagen: $e')));
                  }
                }
              }),
            ],
          ),
          body: ListView(padding: const EdgeInsets.all(16), children: [
            _z('Weiselzustand', d.weiselzustand),
            _z('Königin gesehen', d.koeniginGesehen ? 'ja' : 'nein'),
            _z('Stifte gesehen', d.stifteGesehen ? 'ja' : 'nein'),
            _z('Weiselzellen', d.weiselzellen),
            _z('Brutbild', d.brutbild),
            _z('Wabengassen', d.staerkeWabengassen?.toString()),
            _z('Futter (kg)', d.futterKg?.toString()),
            _z('Pollen', d.pollen),
            _z('Platz', d.platz),
            _z('Sanftmut', d.sanftmut?.toString()),
            _z('Wabensitz', d.wabensitz?.toString()),
            _z('Auffälligkeiten', d.auffaelligkeiten.isEmpty ? null : d.auffaelligkeiten.join(', ')),
            _z('Massnahmen', d.massnahmen),
            _z('Nächste Durchsicht', d.naechsteDurchsichtAm == null ? null : _datum(d.naechsteDurchsichtAm!)),
            _z('Notiz', d.notiz),
            if (d.fotoUrls.isNotEmpty) ...[
              const Padding(padding: EdgeInsets.only(top: 8, bottom: 4),
                  child: Text('Fotos', style: TextStyle(color: Colors.grey))),
              SizedBox(height: 96, child: ListView.separated(
                scrollDirection: Axis.horizontal, itemCount: d.fotoUrls.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (_, i) => FutureBuilder<String>(
                  future: ref.read(durchsichtGatewayProvider).fotoSignedUrl(d.fotoUrls[i]),
                  builder: (_, snap) => snap.hasData
                    ? ClipRRect(borderRadius: BorderRadius.circular(8),
                        child: Image.network(snap.data!, width: 96, height: 96, fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const SizedBox(width: 96, child: Icon(Icons.broken_image))))
                    : const SizedBox(width: 96, child: Center(child: CircularProgressIndicator())),
                ),
              )),
            ],
          ]),
        );
      },
    );
  }

  String _datum(DateTime d) => '${d.day}.${d.month}.${d.year}';

  Widget _z(String label, String? wert) => (wert == null || wert.isEmpty)
      ? const SizedBox.shrink()
      : Padding(padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(width: 140, child: Text(label, style: const TextStyle(color: Colors.grey))),
            Expanded(child: Text(wert)),
          ]));
}
