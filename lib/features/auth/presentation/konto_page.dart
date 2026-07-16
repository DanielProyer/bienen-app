import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bienen_app/features/auth/domain/auth_gateway.dart';
import 'package:bienen_app/features/auth/domain/rolle.dart';
import 'package:bienen_app/features/auth/presentation/auth_providers.dart';

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
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.person_outline),
                        title: const Text('Angemeldet als'),
                        subtitle: Text(session.email),
                      ),
                      ListTile(
                        leading: const Icon(Icons.badge_outlined),
                        title: const Text('Rolle'),
                        subtitle: Text(session.rolle.anzeige),
                      ),
                    ],
                  ),
                ),
                if (session.rolle.istOwner) ...[
                  const SizedBox(height: 16),
                  Card(
                    child: Column(
                      children: [
                        const ListTile(
                          leading: Icon(Icons.group_add_outlined),
                          title: Text('Team'),
                          subtitle: Text(
                              'Lade jemanden per Code ein. Der Code ist nur einmal sichtbar.'),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: FilledButton.tonalIcon(
                              key: const Key('konto_einladen'),
                              icon: const Icon(Icons.person_add_alt),
                              label: const Text('Mitglied einladen'),
                              onPressed: () => _einladenDialog(context, ref),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  key: const Key('konto_logout'),
                  icon: const Icon(Icons.logout),
                  label: const Text('Abmelden'),
                  onPressed: () =>
                      ref.read(authControllerProvider.notifier).signOut(),
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
