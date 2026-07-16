import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:bienen_app/features/auth/data/supabase_auth_gateway.dart';

/// Baut einen JWT-String (header.payload.signature) mit dem gegebenen Payload.
String _jwt(Map<String, dynamic> payload) {
  String enc(Map<String, dynamic> m) =>
      base64Url.encode(utf8.encode(json.encode(m))).replaceAll('=', '');
  return '${enc({'alg': 'HS256', 'typ': 'JWT'})}.${enc(payload)}.signatur';
}

void main() {
  group('jwtPayload (Regression: betrieb_id kommt aus dem JWT-Claim, NICHT aus '
      'user.appMetadata/raw_app_meta_data)', () {
    test('liest app_metadata.betrieb_id + rolle aus dem Claim', () {
      final token = _jwt({
        'sub': 'u1',
        'app_metadata': {'betrieb_id': 'b-123', 'rolle': 'owner'},
      });
      final meta = jwtPayload(token)['app_metadata'] as Map;
      expect(meta['betrieb_id'], 'b-123');
      expect(meta['rolle'], 'owner');
    });

    test('JWT ohne betrieb_id-Claim -> kein betrieb_id (=> OhneBetrieb-Pfad)', () {
      final token = _jwt({
        'sub': 'u1',
        'app_metadata': {'provider': 'email'},
      });
      final meta = jwtPayload(token)['app_metadata'] as Map;
      expect(meta['betrieb_id'], isNull);
    });

    test('base64url ohne Padding wird korrekt normalisiert', () {
      // Payload-Laenge so waehlen, dass Padding noetig waere.
      final token = _jwt({'app_metadata': {'betrieb_id': 'x'}});
      expect((jwtPayload(token)['app_metadata'] as Map)['betrieb_id'], 'x');
    });

    test('kaputtes/leeres Token -> leere Map (kein Crash)', () {
      expect(jwtPayload('nur.zwei'), isEmpty);
      expect(jwtPayload('quatsch'), isEmpty);
      expect(jwtPayload(''), isEmpty);
      expect(jwtPayload('a.!!!.c'), isEmpty);
    });
  });
}
