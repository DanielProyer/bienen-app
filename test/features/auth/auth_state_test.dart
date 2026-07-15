import 'package:flutter_test/flutter_test.dart';
import 'package:bienen_app/features/auth/domain/auth_session.dart';
import 'package:bienen_app/features/auth/domain/rolle.dart';
import 'package:bienen_app/features/auth/presentation/auth_state.dart';

void main() {
  group('Rolle', () {
    test('parst die DB-Werte', () {
      expect(Rolle.vonString('owner'), Rolle.owner);
      expect(Rolle.vonString('editor'), Rolle.editor);
      expect(Rolle.vonString('viewer'), Rolle.viewer);
    });
    test('unbekannt/null -> null', () {
      expect(Rolle.vonString(null), isNull);
      expect(Rolle.vonString('quatsch'), isNull);
    });
    test('darfSchreiben nur owner/editor', () {
      expect(Rolle.owner.darfSchreiben, isTrue);
      expect(Rolle.editor.darfSchreiben, isTrue);
      expect(Rolle.viewer.darfSchreiben, isFalse);
    });
    test('istOwner nur owner', () {
      expect(Rolle.owner.istOwner, isTrue);
      expect(Rolle.editor.istOwner, isFalse);
      expect(Rolle.viewer.istOwner, isFalse);
    });
  });

  group('AuthState', () {
    const s = AuthSession(
        userId: 'u1', email: 'a@b.ch', betriebId: 'b1', rolle: Rolle.editor);

    test('laden traegt keine Session', () {
      const st = AuthState.laden();
      expect(st.status, AuthStatus.laden);
      expect(st.session, isNull);
      expect(st.darfSchreiben, isFalse);
    });
    test('ohneBetrieb traegt bewusst keine Session', () {
      const st = AuthState.ohneBetrieb();
      expect(st.status, AuthStatus.ohneBetrieb);
      expect(st.session, isNull);
      expect(st.betriebId, isNull);
    });
    test('angemeldet liefert Rolle/Betrieb', () {
      const st = AuthState.angemeldet(s);
      expect(st.status, AuthStatus.angemeldet);
      expect(st.betriebId, 'b1');
      expect(st.rolle, Rolle.editor);
      expect(st.darfSchreiben, isTrue);
    });
    test('viewer darf nicht schreiben', () {
      const st = AuthState.angemeldet(AuthSession(
          userId: 'u', email: 'g@b.ch', betriebId: 'b1', rolle: Rolle.viewer));
      expect(st.darfSchreiben, isFalse);
    });
  });
}
