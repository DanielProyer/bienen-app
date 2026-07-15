import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:bienen_app/features/auth/presentation/widgets/auth_scaffold.dart';

/// Nach der Registrierung mit aktiver Confirm-Email: signUp liefert KEINE
/// Session — der Nutzer muss erst den Link in der Mail anklicken.
class MailBestaetigenPage extends StatelessWidget {
  final String email;
  const MailBestaetigenPage({super.key, required this.email});

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      titel: 'Bestaetige deine E-Mail',
      children: [
        Text(
          email.isEmpty
              ? 'Wir haben dir eine Bestaetigungs-Mail geschickt.'
              : 'Wir haben dir eine Bestaetigungs-Mail an $email geschickt.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 12),
        Text(
          'Bitte den Link darin anklicken und dich danach anmelden. '
          'Schau notfalls im Spam-Ordner nach.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            key: const Key('mail_zum_login'),
            onPressed: () => context.go('/login'),
            child: const Text('Zur Anmeldung'),
          ),
        ),
      ],
    );
  }
}
