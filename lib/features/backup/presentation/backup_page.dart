import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bienen_app/core/theme/app_tokens.dart';
import 'package:bienen_app/features/auth/presentation/auth_providers.dart';
import 'package:bienen_app/features/backup/data/export_service.dart';
import 'package:bienen_app/shared/widgets/app_button.dart';
import 'package:bienen_app/shared/widgets/app_card.dart';
import 'package:bienen_app/shared/widgets/section_header.dart';

/// Seite „Daten & Backup": erklaert die automatische Offsite-Sicherung und
/// bietet den manuellen Sofort-Export als ZIP an.
class BackupPage extends ConsumerStatefulWidget {
  const BackupPage({super.key});

  @override
  ConsumerState<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends ConsumerState<BackupPage> {
  bool _laeuft = false;
  String _schritt = '';
  double? _anteil;

  static String _heute() {
    final n = DateTime.now();
    final m = n.month.toString().padLeft(2, '0');
    final t = n.day.toString().padLeft(2, '0');
    return '${n.year}-$m-$t';
  }

  Future<void> _export() async {
    final betriebId = ref.read(currentBetriebIdProvider);
    final messenger = ScaffoldMessenger.of(context);
    if (betriebId == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Kein aktiver Betrieb — Export nicht moeglich.')),
      );
      return;
    }
    setState(() {
      _laeuft = true;
      _schritt = 'Export wird vorbereitet …';
      _anteil = null;
    });
    try {
      final ergebnis = await ExportService.paketBauen(
        betriebId: betriebId,
        fortschritt: (schritt, erledigt, gesamt) {
          if (!mounted) return;
          setState(() {
            _schritt = schritt;
            _anteil = gesamt == 0 ? null : erledigt / gesamt;
          });
        },
      );
      ExportService.herunterladen(ergebnis.bytes, 'bienen-export-${_heute()}.zip');
      if (!mounted) return;
      final anzahl = ergebnis.warnungen.length;
      messenger.showSnackBar(
        anzahl == 0
            ? const SnackBar(content: Text('Export erstellt — Download gestartet.'))
            : SnackBar(
                backgroundColor: BeeTokens.warnungText,
                content: Text('Export erstellt — mit $anzahl Warnung(en).'),
              ),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          backgroundColor: BeeTokens.gefahrText,
          content: Text('Export fehlgeschlagen: $e'),
        ),
      );
    } finally {
      if (mounted) setState(() => _laeuft = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Daten & Backup')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(BeeTokens.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(titel: 'Automatisches Backup'),
            const AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Jede Nacht um 03:15 werden alle Daten und Fotos in ein privates '
                    'GitHub-Repository gesichert — ausserhalb von Supabase.',
                    style: BeeTokens.text,
                  ),
                  SizedBox(height: BeeTokens.sm),
                  Text(
                    'Jeder Lauf wird als eigener Stand abgelegt, die Historie aller '
                    'frueheren Tage bleibt erhalten. Schlaegt ein Lauf fehl, meldet '
                    'GitHub das per E-Mail.',
                    style: BeeTokens.text,
                  ),
                ],
              ),
            ),
            const SizedBox(height: BeeTokens.lg),
            const SectionHeader(titel: 'Jetzt exportieren'),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Laedt alle Daten und Fotos deines Betriebs als ZIP herunter.',
                    style: BeeTokens.text,
                  ),
                  const SizedBox(height: BeeTokens.md),
                  AppButton(
                    label: 'Jetzt exportieren',
                    icon: Icons.download,
                    full: true,
                    busy: _laeuft,
                    onPressed: _export,
                  ),
                  if (_laeuft) ...[
                    const SizedBox(height: BeeTokens.md),
                    LinearProgressIndicator(value: _anteil),
                    const SizedBox(height: BeeTokens.sm),
                    Text(_schritt, style: BeeTokens.gedaempft),
                  ],
                ],
              ),
            ),
            const SizedBox(height: BeeTokens.xl),
          ],
        ),
      ),
    );
  }
}
