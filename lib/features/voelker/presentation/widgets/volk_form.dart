import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bienen_app/features/voelker/domain/koenigin.dart';
import 'package:bienen_app/features/voelker/domain/standort.dart';
import 'package:bienen_app/features/voelker/domain/voelker_gateway.dart';
import 'package:bienen_app/features/voelker/domain/volk.dart';
import 'package:bienen_app/features/voelker/presentation/providers/voelker_provider.dart';

/// Sentinel-Wert fuer den Standort-Dropdown im Volk-Formular ("+ neuer Standort").
const _neuerStandortWert = '__neu__';

/// Stellt sicher, dass die Stammdaten-Provider geladen sind, BEVOR ein Formular
/// oeffnet. Sonst liefert der AsyncNotifier beim ersten Read `AsyncLoading` (kein
/// Wert) und Dropdowns/Vorbelegungen blieben beim ersten Aufruf pro Session leer.
/// Fehler werden bewusst geschluckt — sie tauchen beim Speichern als SnackBar auf,
/// und das Formular soll sich trotzdem oeffnen lassen.
Future<void> _stammdatenLaden(WidgetRef ref) async {
  try {
    await Future.wait([
      ref.read(standorteProvider.future),
      ref.read(koeniginnenProvider.future),
      ref.read(betriebsEinstellungenProvider.future),
    ]);
  } catch (_) {
    // absichtlich ignoriert (siehe Doc-Kommentar)
  }
}

Future<void> showVolkForm(BuildContext context, WidgetRef ref, {Volk? volk}) async {
  await _stammdatenLaden(ref);
  if (!context.mounted) return;
  final einst = ref.read(betriebsEinstellungenProvider).valueOrNull;
  final nameCtrl = TextEditingController(text: volk?.name ?? '');
  final beuteCtrl = TextEditingController(text: volk?.beutentyp ?? einst?.beutensystemDefault ?? '');
  String? standortId = volk?.standortId;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => Consumer(
      builder: (ctx, ref, _) {
        // Reaktiv: aktualisiert sich, sobald Standorte eintreffen oder ein neuer
        // Stand angelegt wird. Aufgeloeste Staende ausblenden (Spec §7), den aktuell
        // zugeordneten Stand aber weiter zeigen, damit die Auswahl sichtbar bleibt.
        final alle = ref.watch(standorteProvider).valueOrNull ?? const <Standort>[];
        final standorte = alle
            .where((s) => s.status != 'aufgeloest' || s.id == volk?.standortId)
            .toList();
        return StatefulBuilder(
          builder: (ctx, setState) => Padding(
            padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 16, right: 16, top: 16),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(volk == null ? 'Volk anlegen' : 'Volk bearbeiten',
                  style: Theme.of(ctx).textTheme.titleLarge),
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name')),
              TextField(controller: beuteCtrl, decoration: const InputDecoration(labelText: 'Beutentyp')),
              DropdownButtonFormField<String?>(
                key: ValueKey(standortId),
                initialValue: standortId,
                decoration: const InputDecoration(labelText: 'Standort'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('— kein —')),
                  for (final s in standorte) DropdownMenuItem(value: s.id, child: Text(s.name)),
                  const DropdownMenuItem(value: _neuerStandortWert, child: Text('+ neuer Standort')),
                ],
                onChanged: (v) async {
                  if (v == _neuerStandortWert) {
                    final vorherIds = standorte.map((s) => s.id).toSet();
                    await showStandortForm(context, ref);
                    if (!ctx.mounted) return;
                    final neueListe = await ref.read(standorteProvider.future);
                    if (!ctx.mounted) return;
                    final neue = neueListe.where((s) => !vorherIds.contains(s.id));
                    setState(() => standortId = neue.isNotEmpty ? neue.first.id : standortId);
                  } else {
                    setState(() => standortId = v);
                  }
                },
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () async {
                  final neu = Volk(
                    id: volk?.id ?? '',
                    name: nameCtrl.text.trim(),
                    status: volk?.status ?? 'aktiv',
                    standortId: standortId,
                    koeniginId: volk?.koeniginId,
                    beutentyp: beuteCtrl.text.trim().isEmpty ? null : beuteCtrl.text.trim(),
                  );
                  try {
                    await ref.read(voelkerListProvider.notifier).speichern(neu);
                    if (ctx.mounted) Navigator.pop(ctx);
                  } on VoelkerFehler catch (e) {
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(e.message)));
                    }
                  } catch (e) {
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx)
                          .showSnackBar(SnackBar(content: Text('Speichern fehlgeschlagen: $e')));
                    }
                  }
                },
                child: const Text('Speichern'),
              ),
              const SizedBox(height: 16),
            ]),
          ),
        );
      },
    ),
  );
}

Future<void> showUmweiselnDialog(BuildContext context, WidgetRef ref, Volk volk) async {
  await _stammdatenLaden(ref);
  if (!context.mounted) return;
  String? neueId;
  String altGrund = 'ersetzt';

  await showDialog<void>(
    context: context,
    builder: (ctx) => Consumer(
      builder: (ctx, ref, _) {
        // Reaktiv: neu angelegte Koeniginnen erscheinen sofort in der Auswahl.
        final koeniginnen = (ref.watch(koeniginnenProvider).valueOrNull ?? const <Koenigin>[])
            .where((k) => k.volkId == null || k.id == volk.koeniginId)
            .toList();
        return StatefulBuilder(
          builder: (ctx, setState) => AlertDialog(
            title: const Text('Umweiseln'),
            content: Column(mainAxisSize: MainAxisSize.min, children: [
              DropdownButtonFormField<String?>(
                initialValue: neueId,
                decoration: const InputDecoration(labelText: 'Neue Koenigin'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('— ohne (weisellos) —')),
                  for (final k in koeniginnen)
                    DropdownMenuItem(value: k.id, child: Text(k.kennung ?? k.id)),
                ],
                onChanged: (v) => neueId = v,
              ),
              DropdownButtonFormField<String>(
                initialValue: altGrund,
                decoration: const InputDecoration(labelText: 'Alte Koenigin'),
                items: const [
                  DropdownMenuItem(value: 'ersetzt', child: Text('ersetzt')),
                  DropdownMenuItem(value: 'tot', child: Text('tot')),
                  DropdownMenuItem(value: 'verschollen', child: Text('verschollen')),
                ],
                onChanged: (v) => altGrund = v ?? 'ersetzt',
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('Koenigin anlegen'),
                  onPressed: () async {
                    await showKoeniginForm(context, ref);
                    if (!ctx.mounted) return;
                    // Liste per await sicher aktualisieren; Consumer rebuildet ohnehin.
                    await ref.read(koeniginnenProvider.future);
                    if (ctx.mounted) setState(() {});
                  },
                ),
              ),
            ]),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Abbrechen')),
              FilledButton(
                onPressed: () async {
                  try {
                    await ref.read(voelkerListProvider.notifier).umweiseln(
                          volkId: volk.id, neueKoeniginId: neueId, altGrund: altGrund,
                        );
                    if (ctx.mounted) Navigator.pop(ctx);
                  } on VoelkerFehler catch (e) {
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(e.message)));
                    }
                  } catch (e) {
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx)
                          .showSnackBar(SnackBar(content: Text('Umweiseln fehlgeschlagen: $e')));
                    }
                  }
                },
                child: const Text('Umweiseln'),
              ),
            ],
          ),
        );
      },
    ),
  );
}

/// Königin anlegen — analog zu [showVolkForm]. Rasse wird aus
/// `betriebsEinstellungenProvider.rasseDefault` vorbelegt.
Future<void> showKoeniginForm(BuildContext context, WidgetRef ref, {Koenigin? koenigin}) async {
  await _stammdatenLaden(ref);
  if (!context.mounted) return;
  final einst = ref.read(betriebsEinstellungenProvider).valueOrNull;
  final kennungCtrl = TextEditingController(text: koenigin?.kennung ?? '');
  final schlupfjahrCtrl =
      TextEditingController(text: koenigin?.schlupfjahr?.toString() ?? DateTime.now().year.toString());
  final rasseCtrl = TextEditingController(text: koenigin?.rasse ?? einst?.rasseDefault ?? '');
  final linieCtrl = TextEditingController(text: koenigin?.linie ?? '');
  String begattungsart = koenigin?.begattungsart ?? 'unbekannt';

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 16, right: 16, top: 16),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(koenigin == null ? 'Koenigin anlegen' : 'Koenigin bearbeiten',
              style: Theme.of(ctx).textTheme.titleLarge),
          TextField(controller: kennungCtrl, decoration: const InputDecoration(labelText: 'Kennung')),
          TextField(
            controller: schlupfjahrCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Schlupfjahr'),
          ),
          TextField(controller: rasseCtrl, decoration: const InputDecoration(labelText: 'Rasse')),
          TextField(controller: linieCtrl, decoration: const InputDecoration(labelText: 'Linie')),
          DropdownButtonFormField<String>(
            initialValue: begattungsart,
            decoration: const InputDecoration(labelText: 'Begattungsart'),
            items: const [
              DropdownMenuItem(value: 'standbegattung', child: Text('Standbegattung')),
              DropdownMenuItem(value: 'belegstelle', child: Text('Belegstelle')),
              DropdownMenuItem(value: 'instrumentell', child: Text('Instrumentell')),
              DropdownMenuItem(value: 'unbekannt', child: Text('Unbekannt')),
            ],
            onChanged: (v) => setState(() => begattungsart = v ?? 'unbekannt'),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () async {
              final neu = Koenigin(
                id: koenigin?.id ?? '',
                kennung: kennungCtrl.text.trim().isEmpty ? null : kennungCtrl.text.trim(),
                schlupfjahr: int.tryParse(schlupfjahrCtrl.text.trim()),
                rasse: rasseCtrl.text.trim().isEmpty ? null : rasseCtrl.text.trim(),
                linie: linieCtrl.text.trim().isEmpty ? null : linieCtrl.text.trim(),
                begattungsart: begattungsart,
                status: koenigin?.status ?? 'aktiv',
                mutterKoeniginId: koenigin?.mutterKoeniginId,
              );
              try {
                await ref.read(koeniginnenProvider.notifier).speichern(neu);
                if (ctx.mounted) Navigator.pop(ctx);
              } on VoelkerFehler catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(e.message)));
                }
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx)
                      .showSnackBar(SnackBar(content: Text('Speichern fehlgeschlagen: $e')));
                }
              }
            },
            child: const Text('Speichern'),
          ),
          const SizedBox(height: 16),
        ]),
      ),
    ),
  );
}

/// Standort anlegen — analog zu [showVolkForm]. Beute wird aus
/// `betriebsEinstellungenProvider.beutensystemDefault` und die Hoehe aus
/// `hoeheDefaultM` vorbelegt.
Future<void> showStandortForm(BuildContext context, WidgetRef ref, {Standort? standort}) async {
  await _stammdatenLaden(ref);
  if (!context.mounted) return;
  final einst = ref.read(betriebsEinstellungenProvider).valueOrNull;
  final nameCtrl = TextEditingController(text: standort?.name ?? '');
  final adresseCtrl = TextEditingController(text: standort?.adresse ?? '');
  final hoeheCtrl =
      TextEditingController(text: (standort?.hoeheM ?? einst?.hoeheDefaultM)?.toString() ?? '');
  final kantonCtrl = TextEditingController(text: standort?.kanton ?? einst?.kanton ?? '');

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 16, right: 16, top: 16),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(standort == null ? 'Standort anlegen' : 'Standort bearbeiten',
            style: Theme.of(ctx).textTheme.titleLarge),
        TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name')),
        TextField(controller: adresseCtrl, decoration: const InputDecoration(labelText: 'Adresse')),
        TextField(
          controller: hoeheCtrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Hoehe (m)'),
        ),
        TextField(controller: kantonCtrl, decoration: const InputDecoration(labelText: 'Kanton')),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: () async {
            final neu = Standort(
              id: standort?.id ?? '',
              name: nameCtrl.text.trim(),
              adresse: adresseCtrl.text.trim().isEmpty ? null : adresseCtrl.text.trim(),
              hoeheM: int.tryParse(hoeheCtrl.text.trim()),
              kanton: kantonCtrl.text.trim().isEmpty ? null : kantonCtrl.text.trim(),
              status: standort?.status ?? 'besetzt',
            );
            try {
              await ref.read(standorteProvider.notifier).speichern(neu);
              if (ctx.mounted) Navigator.pop(ctx);
            } on VoelkerFehler catch (e) {
              if (ctx.mounted) {
                ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(e.message)));
              }
            } catch (e) {
              if (ctx.mounted) {
                ScaffoldMessenger.of(ctx)
                    .showSnackBar(SnackBar(content: Text('Speichern fehlgeschlagen: $e')));
              }
            }
          },
          child: const Text('Speichern'),
        ),
        const SizedBox(height: 16),
      ]),
    ),
  );
}
