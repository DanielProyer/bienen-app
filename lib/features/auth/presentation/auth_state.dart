import 'package:bienen_app/features/auth/domain/auth_session.dart';
import 'package:bienen_app/features/auth/domain/rolle.dart';

/// `laden` = Start (Session-Restore laeuft) -> Splash, NICHT navigieren.
/// `ohneBetrieb` = Session vorhanden, keine Mitgliedschaft -> /onboarding;
/// traegt BEWUSST keine AuthSession (ohne betrieb_id-Claim gibt es keinen
/// gueltigen Mandanten-Kontext).
enum AuthStatus { laden, abgemeldet, ohneBetrieb, angemeldet }

class AuthState {
  final AuthStatus status;
  final AuthSession? session;

  const AuthState._(this.status, this.session);
  const AuthState.laden() : this._(AuthStatus.laden, null);
  const AuthState.abgemeldet() : this._(AuthStatus.abgemeldet, null);
  const AuthState.ohneBetrieb() : this._(AuthStatus.ohneBetrieb, null);
  const AuthState.angemeldet(AuthSession session)
      : this._(AuthStatus.angemeldet, session);

  String? get betriebId => session?.betriebId;
  Rolle? get rolle => session?.rolle;

  /// Spiegel von private.kann_schreiben — nur zum Ausblenden von UI.
  /// Die echte Durchsetzung macht RLS.
  bool get darfSchreiben => session?.rolle.darfSchreiben ?? false;
}
