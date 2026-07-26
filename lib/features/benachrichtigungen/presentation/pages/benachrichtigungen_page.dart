import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:bienen_app/core/theme/app_tokens.dart';
import 'package:bienen_app/features/benachrichtigungen/domain/benachrichtigungs_einstellungen.dart';
import 'package:bienen_app/features/benachrichtigungen/presentation/providers/benachrichtigungen_provider.dart';
import 'package:bienen_app/shared/widgets/app_button.dart';
import 'package:bienen_app/shared/widgets/app_card.dart';
import 'package:bienen_app/shared/widgets/section_header.dart';
import 'package:bienen_app/shared/widgets/status_pill.dart';

/// Persoenliche Einstellungen fuer den taeglichen Telegram-Ueberblick (F3).
class BenachrichtigungenPage extends ConsumerStatefulWidget {
  const BenachrichtigungenPage({super.key});
  @override
  ConsumerState<BenachrichtigungenPage> createState() => _BenachrichtigungenPageState();
}

class _BenachrichtigungenPageState extends ConsumerState<BenachrichtigungenPage> {
  final _chatId = TextEditingController();
  final _zeitzone = TextEditingController();

  /// Der zuletzt GESPEICHERTE Stand der Chat-ID. Weicht das Feld davon ab,
  /// wuerde eine Testnachricht an die alte ID gehen — deshalb der Riegel.
  String _gespeicherteChatId = '';
  bool _aktiv = false;
  int _sendeStunde = 6;

  /// Der Datensatz, aus dem das Formular zuletzt befuellt wurde. Trifft ein
  /// NEUER ein (nach Speichern/Test), wird neu uebernommen — sonst zeigte die
  /// Seite z.B. das von der Edge Function gesetzte `aktiv` nicht an.
  BenachrichtigungsEinstellungen? _quelle;
  bool _speichert = false;
  bool _sendet = false;

  @override
  void dispose() {
    _chatId.dispose();
    _zeitzone.dispose();
    super.dispose();
  }

  void _uebernehmen(BenachrichtigungsEinstellungen e) {
    _chatId.text = e.telegramChatId ?? '';
    _gespeicherteChatId = _chatId.text;
    _zeitzone.text = e.zeitzone;
    _aktiv = e.aktiv;
    _sendeStunde = e.sendeStunde;
  }

  BenachrichtigungsEinstellungen _ausFormular(BenachrichtigungsEinstellungen basis) {
    final chatId = _chatId.text.trim();
    return BenachrichtigungsEinstellungen(
      id: basis.id,
      telegramChatId: chatId.isEmpty ? null : chatId,
      aktiv: _aktiv,
      sendeStunde: _sendeStunde,
      zeitzone: _zeitzone.text.trim().isEmpty ? 'Europe/Zurich' : _zeitzone.text.trim(),
      zuletztGesendetAm: basis.zuletztGesendetAm,
    );
  }

  Future<void> _speichern(BenachrichtigungsEinstellungen basis) async {
    setState(() => _speichert = true);
    try {
      await ref
          .read(benachrichtigungenProvider.notifier)
          .speichern(_ausFormular(basis));
      if (!mounted) return;
      // Der Refetch fuellt das Formular neu — bis dahin gilt der eben
      // geschriebene Text als gespeicherter Stand.
      setState(() => _gespeicherteChatId = _chatId.text.trim());
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Einstellungen gespeichert.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Fehler beim Speichern: $e')));
    } finally {
      if (mounted) setState(() => _speichert = false);
    }
  }

  Future<void> _testen() async {
    setState(() => _sendet = true);
    try {
      await ref.read(benachrichtigungenProvider.notifier).testnachricht();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Testnachricht gesendet — schau in Telegram.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _sendet = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(benachrichtigungenProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Benachrichtigungen')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(BeeTokens.xl),
            child: Text('Einstellungen konnten nicht geladen werden: $e',
                textAlign: TextAlign.center, style: BeeTokens.text),
          ),
        ),
        data: (gespeichert) {
          // Noch nie gespeichert -> mit den fail-safe Defaults starten.
          final basis = gespeichert ?? const BenachrichtigungsEinstellungen.leer();
          if (!identical(basis, _quelle)) {
            _uebernehmen(basis);
            _quelle = basis;
          }
          return _formular(basis);
        },
      ),
    );
  }

  Widget _formular(BenachrichtigungsEinstellungen basis) {
    final chatIdGeaendert = _chatId.text.trim() != _gespeicherteChatId;
    final chatIdFehlt = _gespeicherteChatId.isEmpty;
    final testGesperrt = _speichert || chatIdGeaendert || chatIdFehlt || basis.id.isEmpty;
    final sperrGrund = chatIdFehlt || basis.id.isEmpty
        ? 'Zuerst die Chat-ID eintragen und speichern.'
        : chatIdGeaendert
            ? 'Die Chat-ID wurde geändert. Zuerst speichern — sonst würde der Test an die alte ID gehen.'
            : null;

    return ListView(
      padding: const EdgeInsets.all(BeeTokens.lg),
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                      child: Text('Täglicher Überblick', style: BeeTokens.abschnitt)),
                  StatusPill(
                    label: basis.aktiv ? 'aktiv' : 'aus',
                    signal: basis.aktiv ? BeeSignal.erfolg : BeeSignal.neutral,
                  ),
                ],
              ),
              const SizedBox(height: BeeTokens.sm),
              const Text(
                'Jeden Morgen kommt eine Telegram-Nachricht mit den heute fälligen '
                'und den überfälligen Aufgaben. Steht nichts an, kommt auch nichts — '
                'die Stille ist dann die Aussage.',
                style: BeeTokens.text,
              ),
              const SizedBox(height: BeeTokens.md),
              Text(
                basis.zuletztGesendetAm == null
                    ? 'zuletzt gesendet: noch nie'
                    : 'zuletzt gesendet: '
                        '${DateFormat('dd.MM.').format(basis.zuletztGesendetAm!)}',
                style: BeeTokens.gedaempft,
              ),
            ],
          ),
        ),
        const SizedBox(height: BeeTokens.lg),
        const SectionHeader(titel: 'Verknüpfung'),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                key: const Key('ben_chat_id'),
                controller: _chatId,
                keyboardType: TextInputType.text,
                decoration: const InputDecoration(
                  labelText: 'Telegram Chat-ID',
                  helperText: 'Schreib zuerst dem Bot, hol dir die ID z. B. über @userinfobot.',
                  helperMaxLines: 2,
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: BeeTokens.md),
              SwitchListTile(
                key: const Key('ben_aktiv'),
                contentPadding: EdgeInsets.zero,
                title: const Text('Täglichen Überblick senden', style: BeeTokens.text),
                subtitle: const Text('Aus = es kommt nichts, auch wenn etwas ansteht.',
                    style: BeeTokens.gedaempft),
                value: _aktiv,
                onChanged: (v) => setState(() => _aktiv = v),
              ),
              const SizedBox(height: BeeTokens.md),
              DropdownButtonFormField<int>(
                key: const Key('ben_sende_stunde'),
                initialValue: _sendeStunde,
                decoration: const InputDecoration(labelText: 'Sendestunde'),
                items: [
                  for (var h = 0; h < 24; h++)
                    DropdownMenuItem(
                      value: h,
                      child: Text('${h.toString().padLeft(2, '0')}:00'),
                    ),
                ],
                onChanged: (v) => setState(() => _sendeStunde = v ?? _sendeStunde),
              ),
              const SizedBox(height: BeeTokens.md),
              TextField(
                key: const Key('ben_zeitzone'),
                controller: _zeitzone,
                decoration: const InputDecoration(
                  labelText: 'Zeitzone',
                  helperText: 'IANA-Name, z. B. Europe/Zurich.',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: BeeTokens.xl),
        AppButton(
          key: const Key('ben_speichern'),
          label: 'Speichern',
          full: true,
          busy: _speichert,
          onPressed: () => _speichern(basis),
        ),
        const SizedBox(height: BeeTokens.md),
        AppButton(
          key: const Key('ben_test'),
          label: 'Testnachricht senden',
          kind: AppButtonKind.sekundaer,
          full: true,
          busy: _sendet,
          onPressed: testGesperrt ? null : _testen,
        ),
        if (sperrGrund != null) ...[
          const SizedBox(height: BeeTokens.sm),
          Text(sperrGrund, textAlign: TextAlign.center, style: BeeTokens.gedaempft),
        ],
      ],
    );
  }
}
