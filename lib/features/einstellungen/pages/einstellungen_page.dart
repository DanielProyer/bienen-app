import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:bienen_app/core/theme/app_tokens.dart';
import 'package:bienen_app/features/auth/presentation/auth_providers.dart';
import 'package:bienen_app/features/einstellungen/domain/winterfutter_warnung.dart';
import 'package:bienen_app/features/phaenologie/presentation/widgets/phaenologie_sektion.dart';
import 'package:bienen_app/features/voelker/domain/betriebs_einstellungen.dart';
import 'package:bienen_app/features/voelker/presentation/providers/voelker_provider.dart';
import 'package:bienen_app/shared/widgets/app_button.dart';
import 'package:bienen_app/shared/widgets/empty_state.dart';
import 'package:bienen_app/shared/widgets/form_scaffold.dart';

/// Betriebsprofil (F4): editierbare Strategie-Weichen + Saison-Offset + Winterfutter-Ziel.
/// Amtliche Felder (Ident-Nummer/Kanton) sind bewusst NICHT editierbar (Column-Grant I01).
class EinstellungenPage extends ConsumerStatefulWidget {
  const EinstellungenPage({super.key});
  @override
  ConsumerState<EinstellungenPage> createState() => _EinstellungenPageState();
}

class _EinstellungenPageState extends ConsumerState<EinstellungenPage> {
  final _formKey = GlobalKey<FormState>();
  final _offset = TextEditingController();
  final _winterfutter = TextEditingController();
  int _anzahlErnten = 1;
  String _methode = 'ameisensaeure';
  bool _vermehrung = false;
  bool _initialisiert = false;

  static const _methoden = {
    'ameisensaeure': 'Ameisensäure',
    'biotechnisch': 'Biotechnisch',
    'beide': 'Beide',
  };

  @override
  void dispose() {
    _offset.dispose();
    _winterfutter.dispose();
    super.dispose();
  }

  void _uebernehmen(BetriebsEinstellungen e) {
    _offset.text = e.saisonOffsetDefaultTage.toString();
    _winterfutter.text = e.winterfutterZielKg.toString();
    _anzahlErnten = e.anzahlErnten;
    _methode = e.sommerbehandlungMethode;
    _vermehrung = e.vermehrungAktiv;
  }

  Future<void> _speichern() async {
    if (!_formKey.currentState!.validate()) return;
    final neu = BetriebsEinstellungen(
      saisonOffsetDefaultTage: int.parse(_offset.text.trim()),
      winterfutterZielKg: num.parse(_winterfutter.text.trim().replaceAll(',', '.')),
      anzahlErnten: _anzahlErnten,
      sommerbehandlungMethode: _methode,
      vermehrungAktiv: _vermehrung,
    );
    try {
      await ref.read(betriebsEinstellungenProvider.notifier).speichern(neu);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Einstellungen gespeichert.')));
      context.go('/projekt');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fehler: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Rollen-Guard: viewer hat hier nichts verloren.
    if (!ref.watch(darfSchreibenProvider)) {
      return Scaffold(
        appBar: AppBar(title: const Text('Betriebs-Einstellungen')),
        body: const EmptyState(icon: Icons.lock_outline, titel: 'Nur mit Schreibrechten verfügbar.'),
      );
    }
    // Erst rendern, wenn die Einstellungen geladen sind.
    final einstAsync = ref.watch(betriebsEinstellungenProvider);
    if (!einstAsync.hasValue) {
      return Scaffold(
        appBar: AppBar(title: const Text('Betriebs-Einstellungen')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (!_initialisiert) {
      _uebernehmen(einstAsync.value!);
      _initialisiert = true;
    }

    final zielRaw = num.tryParse(_winterfutter.text.trim().replaceAll(',', '.'));
    final unterMinimum = zielRaw != null && unterBgdMinimum(zielRaw);

    return FormScaffold(
      titel: 'Betriebs-Einstellungen',
      bodenleiste: AppButton(label: 'Speichern', full: true, onPressed: _speichern),
      child: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(BeeTokens.lg),
          children: [
            TextFormField(
              controller: _offset,
              decoration: const InputDecoration(
                labelText: 'Saison-Offset (Tage)',
                helperText: 'Verschiebt Frühjahrs-/Trachtregeln (alpin ~+42).',
                suffixText: 'Tage',
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9-]'))],
              validator: (v) {
                final n = int.tryParse((v ?? '').trim());
                if (n == null) return 'Ganze Zahl angeben';
                return null;
              },
            ),
            const SizedBox(height: BeeTokens.md),
            TextFormField(
              controller: _winterfutter,
              decoration: InputDecoration(
                labelText: 'Winterfutter-Ziel',
                suffixText: 'kg',
                // Weiche Warnung (Speichern bleibt erlaubt) — kein errorText.
                helperText: unterMinimum
                    ? 'unter BGD-Minimum 20 kg'
                    : 'BGD-Minimum: 20 kg (Mittelland).',
                helperStyle: unterMinimum
                    ? TextStyle(color: BeeSignal.warnung.text, fontWeight: FontWeight.w600)
                    : null,
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
              onChanged: (_) => setState(() {}),
              validator: (v) {
                // Nur >0 erzwingen; Werte < 20 kg sind erlaubt (weiche Warnung).
                final n = num.tryParse((v ?? '').trim().replaceAll(',', '.'));
                if (n == null || n <= 0) return 'Positive Zahl angeben';
                return null;
              },
            ),
            const SizedBox(height: BeeTokens.xl),
            const Text('Anzahl Honigernten', style: BeeTokens.abschnitt),
            const SizedBox(height: BeeTokens.sm),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 1, label: Text('1 Ernte')),
                ButtonSegment(value: 2, label: Text('2 Ernten')),
              ],
              selected: {_anzahlErnten},
              onSelectionChanged: (s) => setState(() => _anzahlErnten = s.first),
            ),
            const SizedBox(height: BeeTokens.xl),
            const Text('Sommerbehandlung-Methode', style: BeeTokens.abschnitt),
            const SizedBox(height: BeeTokens.sm),
            SegmentedButton<String>(
              segments: [
                for (final e in _methoden.entries)
                  ButtonSegment(value: e.key, label: Text(e.value)),
              ],
              selected: {_methode},
              onSelectionChanged: (s) => setState(() => _methode = s.first),
            ),
            const SizedBox(height: BeeTokens.md),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Vermehrung aktiv'),
              subtitle: const Text('Blendet Ableger-/Zucht-Aufgaben im Generator ein.'),
              value: _vermehrung,
              onChanged: (on) => setState(() => _vermehrung = on),
            ),
            const Divider(height: BeeTokens.xxl),
            const PhaenologieSektion(),
            const SizedBox(height: BeeTokens.lg),
          ],
        ),
      ),
    );
  }
}
