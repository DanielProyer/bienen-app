import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:bienen_app/features/auth/domain/auth_gateway.dart';
import 'package:bienen_app/features/auth/presentation/auth_providers.dart';
import 'package:bienen_app/features/auth/presentation/widgets/auth_scaffold.dart';

class RegistrierenPage extends ConsumerStatefulWidget {
  const RegistrierenPage({super.key});
  @override
  ConsumerState<RegistrierenPage> createState() => _RegistrierenPageState();
}

class _RegistrierenPageState extends ConsumerState<RegistrierenPage> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _passwort = TextEditingController();
  bool _laeuft = false;
  String? _fehler;

  @override
  void dispose() {
    _email.dispose();
    _passwort.dispose();
    super.dispose();
  }

  Future<void> _absenden() async {
    setState(() => _fehler = null);
    if (!_form.currentState!.validate()) return;
    setState(() => _laeuft = true);
    try {
      final bestaetigungNoetig = await ref
          .read(authControllerProvider.notifier)
          .signUp(_email.text, _passwort.text);
      if (!mounted) return;
      if (bestaetigungNoetig) {
        context.go(
            '/mail-bestaetigen?email=${Uri.encodeComponent(_email.text.trim())}');
      } else {
        // Ohne Confirm-Email liefert signUp direkt eine Session -> Gate greift.
        await ref.read(authControllerProvider.notifier).laden();
      }
    } on AuthFehler catch (e) {
      if (mounted) setState(() => _fehler = e.nachricht);
    } catch (_) {
      if (mounted) {
        setState(() => _fehler = 'Verbindungsfehler. Bitte nochmals versuchen.');
      }
    } finally {
      if (mounted) setState(() => _laeuft = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      titel: 'Betrieb registrieren',
      untertitel: 'Du legst ein Konto an und gruendest danach deinen Betrieb.',
      children: [
        Form(
          key: _form,
          child: Column(
            children: [
              TextFormField(
                key: const Key('reg_email'),
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                decoration: const InputDecoration(
                    labelText: 'E-Mail', border: OutlineInputBorder()),
                validator: (v) => (v == null || !v.contains('@'))
                    ? 'Bitte gueltige E-Mail eingeben'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('reg_passwort'),
                controller: _passwort,
                obscureText: true,
                autofillHints: const [AutofillHints.newPassword],
                decoration: const InputDecoration(
                    labelText: 'Passwort',
                    helperText: 'Mindestens 8 Zeichen',
                    border: OutlineInputBorder()),
                validator: (v) => (v == null || v.length < 8)
                    ? 'Mindestens 8 Zeichen'
                    : null,
                onFieldSubmitted: (_) => _absenden(),
              ),
            ],
          ),
        ),
        AuthFehlerText(_fehler),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            key: const Key('reg_absenden'),
            onPressed: _laeuft ? null : _absenden,
            child: _laeuft
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Konto anlegen'),
          ),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () => context.go('/login'),
          child: const Text('Ich habe schon ein Konto — anmelden'),
        ),
      ],
    );
  }
}
