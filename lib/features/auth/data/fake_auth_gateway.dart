import 'package:bienen_app/features/auth/domain/auth_gateway.dart';
import 'package:bienen_app/features/auth/domain/auth_session.dart';
import 'package:bienen_app/features/auth/domain/rolle.dart';

/// In-Memory-Gateway fuer Tests: kein Netz, kein Supabase.
class FakeAuthGateway implements AuthGateway {
  AuthErgebnis ergebnis;
  AuthFehler? wirftBeiSignIn;
  AuthFehler? wirftBeiGruenden;
  AuthFehler? wirftBeiEinladung;
  bool signUpBestaetigungNoetig;

  int signOutAufrufe = 0;
  int refreshAufrufe = 0;
  String? letzterGruendungsName;
  String? letzterCode;

  FakeAuthGateway({
    this.ergebnis = const KeineSession(),
    this.signUpBestaetigungNoetig = true,
  });

  static const beispielSession = AuthSession(
      userId: 'u1',
      email: 'daniel@test.ch',
      betriebId: 'b1',
      rolle: Rolle.owner);

  @override
  Future<AuthErgebnis> currentSession() async => ergebnis;

  @override
  Future<AuthErgebnis> signIn(
      {required String email, required String password}) async {
    if (wirftBeiSignIn != null) throw wirftBeiSignIn!;
    return ergebnis;
  }

  @override
  Future<bool> signUp({required String email, required String password}) async =>
      signUpBestaetigungNoetig;

  @override
  Future<AuthErgebnis> refreshSession() async {
    refreshAufrufe++;
    return ergebnis;
  }

  @override
  Future<void> betriebGruenden(String name) async {
    if (wirftBeiGruenden != null) throw wirftBeiGruenden!;
    letzterGruendungsName = name;
    ergebnis = const Angemeldet(beispielSession);
  }

  @override
  Future<void> einladungAnnehmen(String code) async {
    if (wirftBeiEinladung != null) throw wirftBeiEinladung!;
    letzterCode = code;
    ergebnis = const Angemeldet(beispielSession);
  }

  @override
  Future<void> signOut() async {
    signOutAufrufe++;
    ergebnis = const KeineSession();
  }
}
