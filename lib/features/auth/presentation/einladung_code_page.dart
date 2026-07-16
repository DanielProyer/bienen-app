import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:bienen_app/features/auth/domain/auth_gateway.dart';
import 'package:bienen_app/features/auth/presentation/auth_providers.dart';
import 'package:bienen_app/features/auth/presentation/widgets/auth_scaffold.dart';

/// Einladungs-Code einloesen (RPC einladung_annehmen). Der Code beweist die
/// Einladung; zusaetzlich prueft der RPC, dass das Konto zur eingeladenen
/// E-Mail gehoert (BA008).
class EinladungCodePage extends ConsumerStatefulWidget {
  const EinladungCodePage({super.key});
  @override
  ConsumerState<EinladungCodePage> createState() => _EinladungCodePageState();
}

class _EinladungCodePageState extends ConsumerState<EinladungCodePage> {
  final _form = GlobalKey<FormState>();
  final _code = TextEditingController();
  bool _laeuft = false;
  String? _fehler;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _absenden() async {
    setState(() => _fehler = null);
    if (!_form.currentState!.validate()) return;
    if (_laeuft) return;
    setState(() => _laeuft = true);
    try {
      await ref.read(authControllerProvider.notifier).einladungAnnehmen(_code.text);
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
      titel: 'Einladungs-Code',
      untertitel: 'Gib den Code ein, den du vom Inhaber bekommen hast.',
      children: [
        Form(
          key: _form,
          child: TextFormField(
            key: const Key('einl_code'),
            controller: _code,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              labelText: 'Einladungs-Code',
              hintText: 'XXXX-XXXX-XXXX',
              border: OutlineInputBorder(),
            ),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Bitte Code eingeben' : null,
            onFieldSubmitted: (_) => _absenden(),
          ),
        ),
        AuthFehlerText(_fehler),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            key: const Key('einl_absenden'),
            onPressed: _laeuft ? null : _absenden,
            child: _laeuft
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Einladung annehmen'),
          ),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () => context.go('/onboarding'),
          child: const Text('Zurueck zur Gruendung'),
        ),
      ],
    );
  }
}
