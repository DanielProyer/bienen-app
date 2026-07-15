import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:bienen_app/features/auth/domain/auth_gateway.dart';
import 'package:bienen_app/features/auth/presentation/auth_providers.dart';
import 'package:bienen_app/features/auth/presentation/widgets/auth_scaffold.dart';

/// Zustand `ohneBetrieb`: Konto da, aber keine Mitgliedschaft. Hier gruendet
/// der Nutzer seinen Betrieb (RPC betrieb_gruenden -> owner-Mitgliedschaft).
class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});
  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  bool _laeuft = false;
  String? _fehler;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _absenden() async {
    setState(() => _fehler = null);
    if (!_form.currentState!.validate()) return;
    if (_laeuft) return; // Doppel-Tap-sicher (der RPC-Guard BA003 sichert zusaetzlich)
    setState(() => _laeuft = true);
    try {
      await ref.read(authControllerProvider.notifier).betriebGruenden(_name.text);
      // Navigation macht das Router-Gate (ohneBetrieb -> angemeldet).
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
      titel: 'Betrieb gruenden',
      untertitel: 'Noch ein Schritt: Wie heisst dein Imkerei-Betrieb?',
      children: [
        Form(
          key: _form,
          child: TextFormField(
            key: const Key('onb_name'),
            controller: _name,
            decoration: const InputDecoration(
              labelText: 'Name deines Betriebs',
              hintText: 'z. B. Imkerei Arosa',
              helperText: 'Spaeter jederzeit aenderbar.',
              border: OutlineInputBorder(),
            ),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Bitte Namen eingeben' : null,
            onFieldSubmitted: (_) => _absenden(),
          ),
        ),
        AuthFehlerText(_fehler),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            key: const Key('onb_absenden'),
            onPressed: _laeuft ? null : _absenden,
            child: _laeuft
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Betrieb gruenden'),
          ),
        ),
        const SizedBox(height: 12),
        TextButton(
          key: const Key('onb_zur_einladung'),
          onPressed: () => context.go('/einladung'),
          child: const Text('Ich habe einen Einladungs-Code'),
        ),
      ],
    );
  }
}
