import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:bienen_app/features/auth/domain/auth_gateway.dart';
import 'package:bienen_app/features/auth/domain/auth_session.dart';
import 'package:bienen_app/features/auth/domain/rolle.dart';

/// Dekodiert den Payload eines JWT (mittlerer Teil, base64url) zu einer Map.
/// WICHTIG: Der Custom-Access-Token-Hook (A05) setzt betrieb_id/rolle in die
/// JWT-CLAIMS (`app_metadata`), NICHT in `auth.users.raw_app_meta_data`. Deshalb
/// darf man sie NICHT aus `session.user.appMetadata` lesen (das ist das
/// DB-Feld) — sondern aus dem dekodierten Access-Token.
Map<String, dynamic> jwtPayload(String token) {
  final parts = token.split('.');
  if (parts.length != 3) return const {};
  try {
    final decoded =
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
    final map = json.decode(decoded);
    return map is Map<String, dynamic> ? map : const {};
  } catch (_) {
    return const {};
  }
}

/// Supabase-Implementierung. betrieb_id/rolle kommen NICHT aus einer Query,
/// sondern aus dem JWT-app_metadata-Claim (Auth-Hook `custom_access_token`,
/// Migration A05) -> deterministisch + ohne Extra-Roundtrip.
class SupabaseAuthGateway implements AuthGateway {
  final SupabaseClient _client;
  const SupabaseAuthGateway(this._client);

  AuthErgebnis _ausSession(Session? session) {
    final user = session?.user;
    if (session == null || user == null) return const KeineSession();
    // Claims aus dem Access-Token (JWT), NICHT aus user.appMetadata (s.o.).
    final claims = jwtPayload(session.accessToken);
    final meta = claims['app_metadata'];
    final betriebId = (meta is Map) ? meta['betrieb_id'] as String? : null;
    final rolle =
        Rolle.vonString((meta is Map) ? meta['rolle'] as String? : null);
    // Ohne gueltigen Claim gibt es keinen Mandanten-Kontext -> Onboarding.
    if (betriebId == null || rolle == null) return const OhneBetrieb();
    return Angemeldet(AuthSession(
      userId: user.id,
      email: user.email ?? '',
      betriebId: betriebId,
      rolle: rolle,
    ));
  }

  @override
  Future<AuthErgebnis> currentSession() async =>
      _ausSession(_client.auth.currentSession);

  @override
  Future<AuthErgebnis> signIn(
      {required String email, required String password}) async {
    try {
      final res = await _client.auth
          .signInWithPassword(email: email, password: password);
      return _ausSession(res.session);
    } on AuthException catch (e) {
      throw AuthFehler(_klartext(e), code: e.code);
    }
  }

  @override
  Future<bool> signUp({required String email, required String password}) async {
    try {
      final res = await _client.auth.signUp(email: email, password: password);
      // Bei aktiver Confirm-Email liefert signUp KEINE Session.
      return res.session == null;
    } on AuthException catch (e) {
      throw AuthFehler(_klartext(e), code: e.code);
    }
  }

  @override
  Future<AuthErgebnis> refreshSession() async {
    try {
      final res = await _client.auth.refreshSession();
      return _ausSession(res.session);
    } on AuthException catch (e) {
      throw AuthFehler(_klartext(e), code: e.code);
    }
  }

  @override
  Future<void> betriebGruenden(String name) =>
      _rpc('betrieb_gruenden', {'p_name': name});

  @override
  Future<void> einladungAnnehmen(String code) =>
      _rpc('einladung_annehmen', {'p_code': code});

  @override
  Future<String> mitgliedEinladen(
      {required String email, required Rolle rolle}) async {
    try {
      final code = await _client.rpc('mitglied_einladen',
          params: {'p_email': email.trim(), 'p_rolle': rolle.name});
      return code as String;
    } on PostgrestException catch (e) {
      throw AuthFehler(_rpcKlartext(e.code), code: e.code);
    }
  }

  Future<void> _rpc(String fn, Map<String, dynamic> params) async {
    try {
      await _client.rpc(fn, params: params);
    } on PostgrestException catch (e) {
      // Stabile BA0xx-Codes aus den RPCs (A06) — nie Prosa matchen.
      throw AuthFehler(_rpcKlartext(e.code), code: e.code);
    }
  }

  @override
  Future<void> signOut() => _client.auth.signOut();

  String _klartext(AuthException e) => switch (e.code) {
        'invalid_credentials' => 'E-Mail oder Passwort stimmt nicht.',
        'email_not_confirmed' => 'Bitte bestaetige zuerst deine E-Mail-Adresse.',
        'user_already_exists' ||
        'email_exists' =>
          'Diese E-Mail ist bereits registriert — bitte anmelden.',
        'weak_password' => 'Passwort zu schwach (mindestens 8 Zeichen).',
        'over_email_send_rate_limit' =>
          'Zu viele E-Mails angefordert. Bitte etwas warten.',
        _ => e.message,
      };

  String _rpcKlartext(String? code) => switch (code) {
        'BA001' => 'Nicht angemeldet.',
        'BA002' => 'Der Name darf nicht leer sein.',
        'BA003' || 'BA009' => 'Du gehoerst bereits zu einem Betrieb.',
        'BA004' => 'Dir ist kein Betrieb zugeordnet.',
        'BA007' => 'Einladungs-Code ungueltig oder abgelaufen.',
        'BA008' => 'Dieses Konto gehoert nicht zur eingeladenen E-Mail.',
        'BA010' => 'Dafuer fehlen dir die Rechte (nur Inhaber).',
        'BA012' => 'E-Mail-Adresse fehlt oder ist ungueltig.',
        'BA013' => 'Der letzte Inhaber kann nicht entfernt werden.',
        _ => 'Unerwarteter Fehler. Bitte nochmals versuchen.',
      };
}
