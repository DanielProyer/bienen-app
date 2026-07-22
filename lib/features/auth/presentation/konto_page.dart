import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bienen_app/core/theme/app_tokens.dart';
import 'package:bienen_app/features/auth/domain/auth_gateway.dart';
import 'package:bienen_app/features/auth/domain/rolle.dart';
import 'package:bienen_app/features/auth/presentation/auth_providers.dart';
import 'package:bienen_app/shared/widgets/app_button.dart';
import 'package:bienen_app/shared/widgets/app_card.dart';
import 'package:bienen_app/shared/widgets/app_list_tile.dart';
import 'package:bienen_app/shared/widgets/confirm_sheet.dart';
import 'package:bienen_app/shared/widgets/status_pill.dart';

class KontoPage extends ConsumerWidget {
  const KontoPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final st = ref.watch(authControllerProvider);
    final session = st.session;

    return Scaffold(
      appBar: AppBar(title: const Text('Konto & Team')),
      body: session == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(BeeTokens.lg),
              children: [
                AppCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      AppListTile(
                        leading: const Icon(Icons.person_outline, color: BeeTokens.textSekundaer),
                        titel: 'Angemeldet als',
                        untertitel: session.email,
                      ),
                      AppListTile(
                        leading: const Icon(Icons.badge_outlined, color: BeeTokens.textSekundaer),
                        titel: 'Rolle',
                        trailing: StatusPill(label: session.rolle.anzeige, signal: BeeSignal.info),
                      ),
                    ],
                  ),
                ),
                if (session.rolle.istOwner) ...[
                  const SizedBox(height: BeeTokens.lg),
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.group_add_outlined, color: BeeTokens.textSekundaer),
                            const SizedBox(width: BeeTokens.md),
                            const Expanded(child: Text('Team', style: BeeTokens.abschnitt)),
                          ],
                        ),
                        const SizedBox(height: BeeTokens.xs),
                        const Text(
                          'Lade jemanden per Code ein. Der Code ist nur einmal sichtbar.',
                          style: BeeTokens.gedaempft,
                        ),
                        const SizedBox(height: BeeTokens.md),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: AppButton(
                            key: const Key('konto_einladen'),
                            label: 'Mitglied einladen',
                            icon: Icons.person_add_alt,
                            kind: AppButtonKind.sekundaer,
                            onPressed: () => _einladenDialog(context, ref),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: BeeTokens.xl),
                AppButton(
                  key: const Key('konto_logout'),
                  label: 'Abmelden',
                  icon: Icons.logout,
                  kind: AppButtonKind.sekundaer,
                  onPressed: () async {
                    final ok = await confirmSheet(
                      context,
                      titel: 'Abmelden?',
                      text: 'Du wirst von diesem Gerät abgemeldet.',
                      bestaetigenLabel: 'Abmelden',
                    );
                    if (ok) ref.read(authControllerProvider.notifier).signOut();
                  },
                ),
              ],
            ),
    );
  }

  Future<void> _einladenDialog(BuildContext context, WidgetRef ref) async {
    final email = TextEditingController();
    var rolle = Rolle.editor;
    final formKey = GlobalKey<FormState>();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Mitglied einladen'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  key: const Key('einladen_email'),
                  controller: email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'E-Mail'),
                  validator: (v) => (v == null || !v.contains('@'))
                      ? 'Bitte gueltige E-Mail eingeben'
                      : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<Rolle>(
                  initialValue: rolle,
                  decoration: const InputDecoration(labelText: 'Rolle'),
                  items: const [
                    DropdownMenuItem(
                        value: Rolle.editor, child: Text('Bearbeiter')),
                    DropdownMenuItem(
                        value: Rolle.viewer, child: Text('Gast (nur lesen)')),
                  ],
                  onChanged: (v) => setDialogState(() => rolle = v ?? Rolle.editor),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Abbrechen'),
            ),
            FilledButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                final messenger = ScaffoldMessenger.of(context);
                Navigator.of(dialogContext).pop();
                try {
                  final code = await ref
                      .read(authGatewayProvider)
                      .mitgliedEinladen(email: email.text, rolle: rolle);
                  if (context.mounted) _codeAnzeigen(context, code);
                } on AuthFehler catch (e) {
                  messenger.showSnackBar(SnackBar(content: Text(e.nachricht)));
                }
              },
              child: const Text('Code erzeugen'),
            ),
          ],
        ),
      ),
    );
    email.dispose();
  }

  void _codeAnzeigen(BuildContext context, String code) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Einladungs-Code'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SelectableText(code,
                style: const TextStyle(
                    fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 2)),
            const SizedBox(height: 12),
            const Text(
              'Der Code wird nur JETZT angezeigt — serverseitig ist nur sein '
              'Hash gespeichert. Gib ihn weiter; die Person registriert sich und '
              'loest ihn unter "Ich habe einen Einladungs-Code" ein. Gueltig 7 Tage.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Clipboard.setData(ClipboardData(text: code)),
            child: const Text('Kopieren'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Fertig'),
          ),
        ],
      ),
    );
  }
}
