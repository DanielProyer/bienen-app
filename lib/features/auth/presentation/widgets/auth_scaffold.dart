import 'package:flutter/material.dart';

/// Gemeinsames, zentriertes Layout aller Auth-Screens (Login, Registrieren,
/// Onboarding, Einladung). Haelt die Screens frei von Layout-Duplikaten.
class AuthScaffold extends StatelessWidget {
  final String titel;
  final String? untertitel;
  final List<Widget> children;

  const AuthScaffold({
    super.key,
    required this.titel,
    this.untertitel,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🐝', style: TextStyle(fontSize: 48)),
                const SizedBox(height: 8),
                Text(titel,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall),
                if (untertitel != null) ...[
                  const SizedBox(height: 8),
                  Text(untertitel!,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium),
                ],
                const SizedBox(height: 24),
                ...children,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Einheitliche Fehleranzeige (Klartext, aus AuthFehler).
class AuthFehlerText extends StatelessWidget {
  final String? fehler;
  const AuthFehlerText(this.fehler, {super.key});

  @override
  Widget build(BuildContext context) {
    if (fehler == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Text(
        fehler!,
        textAlign: TextAlign.center,
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      ),
    );
  }
}
