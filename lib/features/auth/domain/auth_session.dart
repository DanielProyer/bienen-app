import 'package:bienen_app/features/auth/domain/rolle.dart';

/// Angemeldeter Nutzer inkl. aktivem Betrieb aus dem JWT-app_metadata-Claim
/// (gesetzt vom Auth-Hook `custom_access_token`, Migration A05).
class AuthSession {
  final String userId;
  final String email;
  final String betriebId;
  final Rolle rolle;

  const AuthSession({
    required this.userId,
    required this.email,
    required this.betriebId,
    required this.rolle,
  });
}
