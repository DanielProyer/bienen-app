import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import 'package:bienen_app/core/supabase/supabase_config.dart';
import 'package:bienen_app/features/auth/data/supabase_auth_gateway.dart';
import 'package:bienen_app/features/auth/domain/auth_gateway.dart';
import 'package:bienen_app/features/auth/domain/rolle.dart';
import 'package:bienen_app/features/auth/presentation/auth_state.dart';
import 'package:bienen_app/features/construction/presentation/providers/construction_provider.dart';
import 'package:bienen_app/features/material/presentation/providers/material_provider.dart';
import 'package:bienen_app/features/monitoring/presentation/providers/monitoring_provider.dart';
import 'package:bienen_app/features/voelker/presentation/providers/voelker_provider.dart';

final authGatewayProvider =
    Provider<AuthGateway>((ref) => SupabaseAuthGateway(SupabaseConfig.client));

final authControllerProvider =
    NotifierProvider<AuthController, AuthState>(AuthController.new);

class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() => const AuthState.laden();

  AuthGateway get _gw => ref.read(authGatewayProvider);

  AuthState _ausErgebnis(AuthErgebnis e) => switch (e) {
        Angemeldet(:final session) => AuthState.angemeldet(session),
        OhneBetrieb() => const AuthState.ohneBetrieb(),
        KeineSession() => const AuthState.abgemeldet(),
      };

  /// Beim App-Start: bestehende Session aufloesen.
  Future<void> laden() async {
    state = _ausErgebnis(await _gw.currentSession());
  }

  Future<void> signIn(String email, String password) async {
    final e = await _gw.signIn(email: email.trim(), password: password);
    state = _ausErgebnis(e);
    _datenNeuLaden();
  }

  /// true = Bestaetigungs-Mail steht aus.
  Future<bool> signUp(String email, String password) =>
      _gw.signUp(email: email.trim(), password: password);

  /// Gruendung + PFLICHT-refreshSession: der betrieb_id-Claim entsteht erst
  /// im neuen JWT (Auth-Hook A05).
  Future<void> betriebGruenden(String name) async {
    await _gw.betriebGruenden(name.trim());
    state = _ausErgebnis(await _gw.refreshSession());
    _datenNeuLaden();
  }

  Future<void> einladungAnnehmen(String code) async {
    await _gw.einladungAnnehmen(code.trim());
    state = _ausErgebnis(await _gw.refreshSession());
    _datenNeuLaden();
  }

  Future<void> signOut() async {
    await _gw.signOut();
    state = const AuthState.abgemeldet();
    _datenNeuLaden();
  }

  /// Daten-Provider sind NICHT autoDispose und cachen ueber den Auth-Wechsel
  /// hinweg -> bei jedem echten Kontextwechsel invalidieren. Sonst zeigt die
  /// App nach Login/Logout die Daten der vorherigen Session.
  void _datenNeuLaden() {
    ref.invalidate(materialListProvider);
    ref.invalidate(materialPurchasesProvider);
    ref.invalidate(constructionStepsProvider);
    ref.invalidate(weightReadingsProvider);
    ref.invalidate(scalesProvider);
    ref.invalidate(allAlertsProvider);
    ref.invalidate(voelkerListProvider);
    ref.invalidate(standorteProvider);
    ref.invalidate(koeniginnenProvider);
    ref.invalidate(betriebsEinstellungenProvider);
  }
}

final currentBetriebIdProvider =
    Provider<String?>((ref) => ref.watch(authControllerProvider).betriebId);

final currentRolleProvider =
    Provider<Rolle?>((ref) => ref.watch(authControllerProvider).rolle);

final darfSchreibenProvider =
    Provider<bool>((ref) => ref.watch(authControllerProvider).darfSchreiben);

/// Haengt den Controller an Supabase-Auth-Events (Session-Ablauf, Logout in
/// einem anderen Tab). `tokenRefreshed` bewusst NICHT behandeln — feuert
/// periodisch und wuerde Refetch-Thrash ausloesen.
final authSyncProvider = Provider<void>((ref) {
  final sub = SupabaseConfig.client.auth.onAuthStateChange.listen((data) {
    switch (data.event) {
      case sb.AuthChangeEvent.signedOut:
      case sb.AuthChangeEvent.userUpdated:
        ref.read(authControllerProvider.notifier).laden();
      default:
        break;
    }
  });
  ref.onDispose(sub.cancel);
});

/// Listenable fuer go_router: feuert bei jeder Auth-Zustandsaenderung.
class AuthGateNotifier extends ChangeNotifier {
  AuthGateNotifier(Ref ref) {
    ref.listen<AuthState>(authControllerProvider, (_, _) => notifyListeners());
  }
}

final authGateNotifierProvider =
    Provider<AuthGateNotifier>((ref) => AuthGateNotifier(ref));
