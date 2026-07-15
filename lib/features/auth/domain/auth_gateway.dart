import 'package:bienen_app/features/auth/domain/auth_session.dart';
import 'package:bienen_app/features/auth/domain/rolle.dart';

/// Ergebnis von currentSession/signIn: der Betriebs-lose Fall ist ein
/// ZUSTAND (-> Onboarding), kein Fehler.
sealed class AuthErgebnis {
  const AuthErgebnis();
}

class Angemeldet extends AuthErgebnis {
  final AuthSession session;
  const Angemeldet(this.session);
}

/// Konto existiert + bestaetigt, aber (noch) keine Betriebs-Mitgliedschaft.
class OhneBetrieb extends AuthErgebnis {
  const OhneBetrieb();
}

class KeineSession extends AuthErgebnis {
  const KeineSession();
}

/// Fachfehler mit stabilem Code (BA0xx aus den RPCs) — nie Prosa matchen.
class AuthFehler implements Exception {
  final String? code;
  final String nachricht;
  const AuthFehler(this.nachricht, {this.code});
  @override
  String toString() => 'AuthFehler($code): $nachricht';
}

/// Backend-Abstraktion: kapselt alle Auth-Zugriffe, damit der Provider
/// (Supabase/anderer) ohne App-Umbau austauschbar bleibt.
abstract class AuthGateway {
  Future<AuthErgebnis> currentSession();
  Future<AuthErgebnis> signIn({required String email, required String password});

  /// true = Bestaetigungs-Mail steht aus (kein Auto-Login).
  Future<bool> signUp({required String email, required String password});

  /// Erzwingt einen frischen JWT (nach Gruendung/Einladung: betrieb_id-Claim
  /// aus dem Auth-Hook A05) und liefert den neuen Zustand.
  Future<AuthErgebnis> refreshSession();

  /// Legt Betrieb + owner-Mitgliedschaft an (RPC betrieb_gruenden).
  Future<void> betriebGruenden(String name);

  /// Loest einen Einladungs-Code ein (RPC einladung_annehmen).
  Future<void> einladungAnnehmen(String code);

  /// Erzeugt eine Einladung (RPC mitglied_einladen, nur owner) und liefert den
  /// Klartext-Code — der wird serverseitig NUR gehasht gespeichert und ist
  /// daher EINMALIG sichtbar.
  Future<String> mitgliedEinladen({required String email, required Rolle rolle});

  Future<void> signOut();
}
