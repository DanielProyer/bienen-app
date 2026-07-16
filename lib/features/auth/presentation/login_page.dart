import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:bienen_app/features/auth/domain/auth_gateway.dart';
import 'package:bienen_app/features/auth/presentation/auth_providers.dart';
import 'package:bienen_app/features/auth/presentation/widgets/auth_scaffold.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});
  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
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
      await ref
          .read(authControllerProvider.notifier)
          .signIn(_email.text, _passwort.text);
      // Navigation macht das Router-Gate (AuthStatus-Wechsel).
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
      titel: 'Bienen Arosa',
      children: [
        Form(
          key: _form,
          child: Column(
            children: [
              TextFormField(
                key: const Key('login_email'),
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.username],
                decoration: const InputDecoration(
                    labelText: 'E-Mail', border: OutlineInputBorder()),
                validator: (v) => (v == null || !v.contains('@'))
                    ? 'Bitte gueltige E-Mail eingeben'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('login_passwort'),
                controller: _passwort,
                obscureText: true,
                autofillHints: const [AutofillHints.password],
                decoration: const InputDecoration(
                    labelText: 'Passwort', border: OutlineInputBorder()),
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Bitte Passwort eingeben' : null,
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
            key: const Key('login_absenden'),
            onPressed: _laeuft ? null : _absenden,
            child: _laeuft
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Anmelden'),
          ),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () => context.go('/registrieren'),
          child: const Text('Neu hier? Betrieb registrieren'),
        ),
      ],
    );
  }
}
