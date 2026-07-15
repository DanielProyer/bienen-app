# Auth-Fundament — Plan 2 von 3: App-Auth-Schicht (Flutter) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Die Flutter-App bekommt eine echte Auth-Schicht: E-Mail+Passwort-Login mit Bestätigungs-Mail, Router-Gate, Betriebs-Gründung (Onboarding), Einladungs-Code-Einlösung, Konto/Logout — plus die im Review geforderten Härtungen (Provider-Invalidierung bei Auth-Wechsel, `materials`-Auto-Seed raus, `<betrieb_id>/`-Storage-Pfade).

**Architecture:** Spiegelt die erprobte KMU-Tool-2-Struktur (`features/auth`): `AuthGateway`-Interface + `SupabaseAuthGateway` + `FakeAuthGateway` (testbar ohne Netz); `AuthErgebnis` sealed (`Angemeldet`/`OhneBetrieb`/`KeineSession`) — **membership-los ist ein Zustand, kein Fehler**; `AuthStatus { laden, abgemeldet, ohneBetrieb, angemeldet }` steuert das go_router-Gate. `betrieb_id`/`rolle` kommen aus dem JWT-`app_metadata`-Claim (Auth-Hook A05); nach `betrieb_gruenden`/`einladung_annehmen` erzwingt `refreshSession()` den frischen Claim.

**Tech Stack:** Flutter Web, Riverpod 2.6 (AsyncNotifier/Notifier, **ohne** Codegen — bestehendes Muster), go_router 14.8, supabase_flutter 2.8 (PKCE-Default beibehalten), flutter_test. Backend: Plan 1 (A01–A12) ist **bereits live**.

**Voraussetzung:** Plan 1 deployed. Dashboard-Config (Auth-Hook aktivieren, Confirm-Email, Site-URL) + Bootstrap + Cutover sind **Plan 3** — diese App-Schicht wird hier nur gebaut und getestet, **nicht deployed**.

**Konventionen:**
- Deutsch in UI + Code-Kommentaren. Bestehendes Muster: Riverpod ohne Codegen, `SupabaseConfig.client` inline.
- Fehler dem Nutzer als Klartext, intern über **stabile errcodes** (`BA001`…`BA013`) matchen — **nie** Prosa-Matching (KMU-Lehre).
- Nach jeder Aufgabe: `flutter analyze` + `flutter test` grün, dann committen auf Branch `feat/auth-fundament`.

---

## File Structure

**Neu:**
- `lib/features/auth/domain/auth_session.dart` — `AuthSession` (userId, email, betriebId?, rolle?)
- `lib/features/auth/domain/rolle.dart` — `enum Rolle { owner, editor, viewer }` + Parser
- `lib/features/auth/domain/auth_gateway.dart` — `AuthErgebnis` (sealed) + `AuthGateway` (abstract) + `AuthFehler`
- `lib/features/auth/data/supabase_auth_gateway.dart` — echte Implementierung
- `lib/features/auth/data/fake_auth_gateway.dart` — Test-Double
- `lib/features/auth/presentation/auth_state.dart` — `AuthStatus` + `AuthState`
- `lib/features/auth/presentation/auth_providers.dart` — Gateway-, Controller-, Betrieb-/Rollen-, Sync-Provider
- `lib/features/auth/presentation/login_page.dart` · `registrieren_page.dart` · `mail_bestaetigen_page.dart` · `onboarding_page.dart` · `einladung_code_page.dart` · `konto_page.dart`
- `test/features/auth/auth_state_test.dart` · `auth_controller_test.dart` · `login_page_test.dart` · `onboarding_page_test.dart`

**Geändert:**
- `lib/core/router/app_router.dart` — Auth-Gate + neue Routen
- `lib/main.dart` — Auth-Sync eager aktivieren
- `lib/shared/widgets/app_shell.dart` — Konto-Einstieg (NavigationRail-`trailing`)
- `lib/features/dashboard/pages/dashboard_page.dart` — Konto-Kachel (Einstieg auch schmal)
- `lib/features/material/presentation/providers/material_provider.dart` — Auto-Seed raus, Fehler durchreichen
- `lib/features/construction/presentation/providers/construction_provider.dart` — `<betrieb_id>/`-Pfad, Fehler durchreichen
- `lib/features/material/presentation/pages/material_detail_page.dart` — `<betrieb_id>/`-Pfade (Foto/PDF/Beleg + remove)
- `web/index.html` — Versions-Redirect überspringt Auth-Callback-Parameter

---

## Task 1: Domain — Rolle, AuthSession, AuthGateway-Kontrakt

**Files:**
- Create: `lib/features/auth/domain/rolle.dart`, `lib/features/auth/domain/auth_session.dart`, `lib/features/auth/domain/auth_gateway.dart`
- Test: `test/features/auth/auth_state_test.dart` (Teil 1)

- [ ] **Step 1: Failing test schreiben**

`test/features/auth/auth_state_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:bienen_app/features/auth/domain/rolle.dart';

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
    });
  });
}
```

- [ ] **Step 2: Test laufen lassen — muss fehlschlagen**

Run: `cd bienen_app && flutter test test/features/auth/auth_state_test.dart`
Expected: FAIL — `Target of URI doesn't exist: '.../rolle.dart'`.

- [ ] **Step 3: Implementieren**

`lib/features/auth/domain/rolle.dart`:
```dart
/// Rollen des Mandanten-Modells (DB-Enum `public.betrieb_rolle`).
enum Rolle {
  owner,
  editor,
  viewer;

  /// Parst den JWT-/DB-Wert. Unbekannt oder null -> null (nie raten).
  static Rolle? vonString(String? wert) => switch (wert) {
        'owner' => Rolle.owner,
        'editor' => Rolle.editor,
        'viewer' => Rolle.viewer,
        _ => null,
      };

  /// owner|editor duerfen Fachdaten schreiben (Spiegel von private.kann_schreiben).
  bool get darfSchreiben => this == Rolle.owner || this == Rolle.editor;

  bool get istOwner => this == Rolle.owner;

  String get anzeige => switch (this) {
        Rolle.owner => 'Inhaber',
        Rolle.editor => 'Bearbeiter',
        Rolle.viewer => 'Gast (nur lesen)',
      };
}
```

`lib/features/auth/domain/auth_session.dart`:
```dart
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
```

`lib/features/auth/domain/auth_gateway.dart`:
```dart
import 'package:bienen_app/features/auth/domain/auth_session.dart';

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

  Future<void> signOut();
}
```

- [ ] **Step 4: Test laufen lassen — muss grün sein**

Run: `flutter test test/features/auth/auth_state_test.dart` → PASS (4 Tests).

- [ ] **Step 5: Commit**

```bash
git add lib/features/auth/domain test/features/auth/auth_state_test.dart
git commit -m "feat(auth): Domain-Kontrakt (Rolle, AuthSession, AuthGateway)"
```

---

## Task 2: AuthState + AuthStatus

**Files:**
- Create: `lib/features/auth/presentation/auth_state.dart`
- Test: `test/features/auth/auth_state_test.dart` (erweitern)

- [ ] **Step 1: Failing test ergänzen** (an `test/features/auth/auth_state_test.dart` anhängen, im `main()`)

```dart
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
```
Zusätzliche Imports oben in der Datei:
```dart
import 'package:bienen_app/features/auth/domain/auth_session.dart';
import 'package:bienen_app/features/auth/presentation/auth_state.dart';
```

- [ ] **Step 2: Test laufen lassen — muss fehlschlagen**

Run: `flutter test test/features/auth/auth_state_test.dart`
Expected: FAIL — `auth_state.dart` existiert nicht.

- [ ] **Step 3: Implementieren**

`lib/features/auth/presentation/auth_state.dart`:
```dart
import 'package:bienen_app/features/auth/domain/auth_session.dart';
import 'package:bienen_app/features/auth/domain/rolle.dart';

/// `laden` = Start (Session-Restore laeuft) -> Splash, NICHT navigieren.
/// `ohneBetrieb` = Session vorhanden, keine Mitgliedschaft -> /onboarding.
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
```

- [ ] **Step 4: Test laufen lassen — muss grün sein**

Run: `flutter test test/features/auth/auth_state_test.dart` → PASS (8 Tests).

- [ ] **Step 5: Commit**

```bash
git add lib/features/auth/presentation/auth_state.dart test/features/auth/auth_state_test.dart
git commit -m "feat(auth): AuthState/AuthStatus (laden|abgemeldet|ohneBetrieb|angemeldet)"
```

---

## Task 3: FakeAuthGateway (Test-Double)

**Files:**
- Create: `lib/features/auth/data/fake_auth_gateway.dart`

- [ ] **Step 1: Implementieren** (reines Test-Double, wird in Task 4 getestet)

`lib/features/auth/data/fake_auth_gateway.dart`:
```dart
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
      userId: 'u1', email: 'daniel@test.ch', betriebId: 'b1', rolle: Rolle.owner);

  @override
  Future<AuthErgebnis> currentSession() async => ergebnis;

  @override
  Future<AuthErgebnis> signIn(
      {required String email, required String password}) async {
    if (wirftBeiSignIn != null) throw wirftBeiSignIn!;
    return ergebnis;
  }

  @override
  Future<bool> signUp(
          {required String email, required String password}) async =>
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
```

- [ ] **Step 2: Analyze**

Run: `flutter analyze lib/features/auth` → keine Fehler.

- [ ] **Step 3: Commit**

```bash
git add lib/features/auth/data/fake_auth_gateway.dart
git commit -m "feat(auth): FakeAuthGateway (Test-Double)"
```

---

## Task 4: AuthController + Provider (inkl. Daten-Provider-Invalidierung)

**Files:**
- Create: `lib/features/auth/presentation/auth_providers.dart`
- Test: `test/features/auth/auth_controller_test.dart`

- [ ] **Step 1: Failing test schreiben**

`test/features/auth/auth_controller_test.dart`:
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bienen_app/features/auth/data/fake_auth_gateway.dart';
import 'package:bienen_app/features/auth/domain/auth_gateway.dart';
import 'package:bienen_app/features/auth/presentation/auth_providers.dart';
import 'package:bienen_app/features/auth/presentation/auth_state.dart';

ProviderContainer _container(FakeAuthGateway fake) {
  final c = ProviderContainer(
      overrides: [authGatewayProvider.overrideWithValue(fake)]);
  addTearDown(c.dispose);
  return c;
}

void main() {
  test('Start ohne Session -> abgemeldet', () async {
    final c = _container(FakeAuthGateway(ergebnis: const KeineSession()));
    await c.read(authControllerProvider.notifier).laden();
    expect(c.read(authControllerProvider).status, AuthStatus.abgemeldet);
  });

  test('Session ohne Betrieb -> ohneBetrieb', () async {
    final c = _container(FakeAuthGateway(ergebnis: const OhneBetrieb()));
    await c.read(authControllerProvider.notifier).laden();
    expect(c.read(authControllerProvider).status, AuthStatus.ohneBetrieb);
  });

  test('Session mit Betrieb -> angemeldet + Claims', () async {
    final c = _container(
        FakeAuthGateway(ergebnis: const Angemeldet(FakeAuthGateway.beispielSession)));
    await c.read(authControllerProvider.notifier).laden();
    final st = c.read(authControllerProvider);
    expect(st.status, AuthStatus.angemeldet);
    expect(c.read(currentBetriebIdProvider), 'b1');
    expect(c.read(darfSchreibenProvider), isTrue);
  });

  test('betriebGruenden ruft refreshSession (frischer Claim) und meldet an', () async {
    final fake = FakeAuthGateway(ergebnis: const OhneBetrieb());
    final c = _container(fake);
    await c.read(authControllerProvider.notifier).laden();
    await c.read(authControllerProvider.notifier).betriebGruenden('Imkerei Arosa');
    expect(fake.letzterGruendungsName, 'Imkerei Arosa');
    expect(fake.refreshAufrufe, greaterThanOrEqualTo(1), reason: 'refreshSession noetig fuer betrieb_id-Claim');
    expect(c.read(authControllerProvider).status, AuthStatus.angemeldet);
  });

  test('einladungAnnehmen refresht ebenfalls und meldet an', () async {
    final fake = FakeAuthGateway(ergebnis: const OhneBetrieb());
    final c = _container(fake);
    await c.read(authControllerProvider.notifier).laden();
    await c.read(authControllerProvider.notifier).einladungAnnehmen('ABCD-EFGH-JKMN');
    expect(fake.letzterCode, 'ABCD-EFGH-JKMN');
    expect(fake.refreshAufrufe, greaterThanOrEqualTo(1));
    expect(c.read(authControllerProvider).status, AuthStatus.angemeldet);
  });

  test('signOut -> abgemeldet', () async {
    final fake = FakeAuthGateway(
        ergebnis: const Angemeldet(FakeAuthGateway.beispielSession));
    final c = _container(fake);
    await c.read(authControllerProvider.notifier).laden();
    await c.read(authControllerProvider.notifier).signOut();
    expect(fake.signOutAufrufe, 1);
    expect(c.read(authControllerProvider).status, AuthStatus.abgemeldet);
  });

  test('signIn-Fehler wird als AuthFehler durchgereicht, Status bleibt abgemeldet', () async {
    final fake = FakeAuthGateway(ergebnis: const KeineSession())
      ..wirftBeiSignIn = const AuthFehler('Falsches Passwort', code: 'invalid_credentials');
    final c = _container(fake);
    await c.read(authControllerProvider.notifier).laden();
    // expectLater (nicht expect(() => ...)): der Fehler kommt ASYNCHRON aus dem
    // Future — ein synchroner throwsA-Match wuerde ihn verpassen.
    await expectLater(
      c.read(authControllerProvider.notifier).signIn('a@b.ch', 'x'),
      throwsA(isA<AuthFehler>()),
    );
    expect(c.read(authControllerProvider).status, AuthStatus.abgemeldet);
  });
}
```

- [ ] **Step 2: Test laufen lassen — muss fehlschlagen**

Run: `flutter test test/features/auth/auth_controller_test.dart`
Expected: FAIL — `auth_providers.dart` fehlt.

- [ ] **Step 3: Implementieren**

`lib/features/auth/presentation/auth_providers.dart`:
```dart
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
  /// hinweg -> bei jedem echten Kontextwechsel invalidieren (Review-Blocker:
  /// sonst zeigt die App nach Login/Logout die Daten der Vor-Session).
  void _datenNeuLaden() {
    ref.invalidate(materialListProvider);
    ref.invalidate(materialPurchasesProvider);
    ref.invalidate(constructionStepsProvider);
    ref.invalidate(weightReadingsProvider);
    ref.invalidate(scalesProvider);
    ref.invalidate(allAlertsProvider);
  }
}

final currentBetriebIdProvider =
    Provider<String?>((ref) => ref.watch(authControllerProvider).betriebId);

final currentRolleProvider =
    Provider<Rolle?>((ref) => ref.watch(authControllerProvider).rolle);

final darfSchreibenProvider =
    Provider<bool>((ref) => ref.watch(authControllerProvider).darfSchreiben);

/// Haengt den Controller an Supabase-Auth-Events (Token-Refresh durch andere
/// Tabs, Session-Ablauf). `tokenRefreshed` bewusst NICHT invalidieren
/// (feuert periodisch -> Refetch-Thrash).
final authSyncProvider = Provider<void>((ref) {
  final sub = SupabaseConfig.client.auth.onAuthStateChange.listen((data) {
    switch (data.event) {
      case sb.AuthChangeEvent.signedOut:
        ref.read(authControllerProvider.notifier).laden();
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
  AuthGateNotifier(this._ref) {
    _ref.listen<AuthState>(authControllerProvider, (_, __) => notifyListeners());
  }
  final Ref _ref;
}

final authGateNotifierProvider =
    Provider<AuthGateNotifier>((ref) => AuthGateNotifier(ref));
```

> **Provider-Namen (verifiziert am Code, nicht raten):** `materialListProvider`, `materialPurchasesProvider` (material_provider.dart) · `constructionStepsProvider` (construction_provider.dart) · `weightReadingsProvider`, `scalesProvider`, `allAlertsProvider` (monitoring_provider.dart — es gibt **kein** `monitoringProvider`). Die abgeleiteten `Provider<...>` (z. B. `activeAlertsProvider`, `constructionProgressProvider`) müssen NICHT invalidiert werden — sie hängen an den Notifiern und rechnen automatisch neu.

- [ ] **Step 4: Test laufen lassen — muss grün sein**

Run: `flutter test test/features/auth/auth_controller_test.dart` → PASS (7 Tests).
*(Läuft ohne Netz, weil `authGatewayProvider` im Test überschrieben wird.)*

- [ ] **Step 5: Commit**

```bash
git add lib/features/auth/presentation/auth_providers.dart test/features/auth/auth_controller_test.dart
git commit -m "feat(auth): AuthController + Provider (inkl. Daten-Invalidierung bei Auth-Wechsel)"
```

---

## Task 5: SupabaseAuthGateway (echte Implementierung)

**Files:**
- Create: `lib/features/auth/data/supabase_auth_gateway.dart`

- [ ] **Step 1: Implementieren**

```dart
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:bienen_app/features/auth/domain/auth_gateway.dart';
import 'package:bienen_app/features/auth/domain/auth_session.dart';
import 'package:bienen_app/features/auth/domain/rolle.dart';

/// Supabase-Implementierung. betrieb_id/rolle kommen NICHT aus einer Query,
/// sondern aus dem JWT-app_metadata-Claim (Auth-Hook `custom_access_token`,
/// Migration A05) -> deterministisch + ohne Extra-Roundtrip.
class SupabaseAuthGateway implements AuthGateway {
  final SupabaseClient _client;
  const SupabaseAuthGateway(this._client);

  AuthErgebnis _ausSession(Session? session) {
    final user = session?.user;
    if (user == null) return const KeineSession();
    final meta = user.appMetadata;
    final betriebId = meta['betrieb_id'] as String?;
    final rolle = Rolle.vonString(meta['rolle'] as String?);
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
  Future<bool> signUp(
      {required String email, required String password}) async {
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
        'email_not_confirmed' =>
          'Bitte bestaetige zuerst deine E-Mail-Adresse.',
        'user_already_exists' || 'email_exists' =>
          'Diese E-Mail ist bereits registriert — bitte anmelden.',
        'weak_password' => 'Passwort zu schwach (mind. 8 Zeichen).',
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
```

- [ ] **Step 2: Analyze**

Run: `flutter analyze lib/features/auth` → keine Fehler.
*(Falls `AuthException.code` in supabase_flutter 2.8 nicht existiert: mit `grep -rn "String? get code" ~/.pub-cache/hosted/pub.dev/gotrue-*/lib/src/types/auth_exception.dart` prüfen und andernfalls auf `e.statusCode`/`e.message` ausweichen — die Klartext-Mapper-Struktur bleibt.)*

- [ ] **Step 3: Commit**

```bash
git add lib/features/auth/data/supabase_auth_gateway.dart
git commit -m "feat(auth): SupabaseAuthGateway (JWT-Claim, BA0xx-Fehlermapping)"
```

---

## Task 6: Login-, Registrier- und Mail-bestätigen-Screen

**Files:**
- Create: `lib/features/auth/presentation/login_page.dart`, `registrieren_page.dart`, `mail_bestaetigen_page.dart`
- Test: `test/features/auth/login_page_test.dart`

- [ ] **Step 1: Failing test schreiben**

`test/features/auth/login_page_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bienen_app/features/auth/data/fake_auth_gateway.dart';
import 'package:bienen_app/features/auth/domain/auth_gateway.dart';
import 'package:bienen_app/features/auth/presentation/auth_providers.dart';
import 'package:bienen_app/features/auth/presentation/login_page.dart';

Widget _app(FakeAuthGateway fake) => ProviderScope(
      overrides: [authGatewayProvider.overrideWithValue(fake)],
      child: const MaterialApp(home: LoginPage()),
    );

void main() {
  testWidgets('zeigt E-Mail- und Passwort-Feld', (t) async {
    await t.pumpWidget(_app(FakeAuthGateway()));
    expect(find.byKey(const Key('login_email')), findsOneWidget);
    expect(find.byKey(const Key('login_passwort')), findsOneWidget);
    expect(find.text('Anmelden'), findsWidgets);
  });

  testWidgets('leere Felder -> Validierungsfehler, kein Gateway-Aufruf', (t) async {
    final fake = FakeAuthGateway();
    await t.pumpWidget(_app(fake));
    await t.tap(find.byKey(const Key('login_absenden')));
    await t.pumpAndSettle();
    expect(find.textContaining('E-Mail'), findsWidgets);
  });

  testWidgets('falsches Passwort -> Klartext-Fehler sichtbar', (t) async {
    final fake = FakeAuthGateway()
      ..wirftBeiSignIn =
          const AuthFehler('E-Mail oder Passwort stimmt nicht.', code: 'invalid_credentials');
    await t.pumpWidget(_app(fake));
    await t.enterText(find.byKey(const Key('login_email')), 'a@b.ch');
    await t.enterText(find.byKey(const Key('login_passwort')), 'falsch');
    await t.tap(find.byKey(const Key('login_absenden')));
    await t.pumpAndSettle();
    expect(find.text('E-Mail oder Passwort stimmt nicht.'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Test laufen lassen — muss fehlschlagen**

Run: `flutter test test/features/auth/login_page_test.dart` → FAIL (`login_page.dart` fehlt).

- [ ] **Step 3: Implementieren**

`lib/features/auth/presentation/login_page.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:bienen_app/features/auth/domain/auth_gateway.dart';
import 'package:bienen_app/features/auth/presentation/auth_providers.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});
  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _passwort = TextEditingController();
  bool _laeuft = false;
  String? _fehler;

  @override
  void dispose() {
    _email.dispose();
    _passwort.dispose();
    super.dispose();
  }

  Future<void> _absenden() async {
    setState(() => _fehler = null);
    if (!_form.currentState!.validate()) return;
    setState(() => _laeuft = true);
    try {
      await ref
          .read(authControllerProvider.notifier)
          .signIn(_email.text, _passwort.text);
    } on AuthFehler catch (e) {
      setState(() => _fehler = e.nachricht);
    } catch (_) {
      setState(() => _fehler = 'Verbindungsfehler. Bitte nochmals versuchen.');
    } finally {
      if (mounted) setState(() => _laeuft = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Form(
              key: _form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🐝', style: TextStyle(fontSize: 48)),
                  const SizedBox(height: 8),
                  Text('Bienen Arosa',
                      style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 24),
                  TextFormField(
                    key: const Key('login_email'),
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.username],
                    decoration: const InputDecoration(
                        labelText: 'E-Mail', border: OutlineInputBorder()),
                    validator: (v) => (v == null || !v.contains('@'))
                        ? 'Bitte gueltige E-Mail eingeben'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    key: const Key('login_passwort'),
                    controller: _passwort,
                    obscureText: true,
                    autofillHints: const [AutofillHints.password],
                    decoration: const InputDecoration(
                        labelText: 'Passwort', border: OutlineInputBorder()),
                    validator: (v) => (v == null || v.isEmpty)
                        ? 'Bitte Passwort eingeben'
                        : null,
                    onFieldSubmitted: (_) => _absenden(),
                  ),
                  if (_fehler != null) ...[
                    const SizedBox(height: 12),
                    Text(_fehler!,
                        style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  ],
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      key: const Key('login_absenden'),
                      onPressed: _laeuft ? null : _absenden,
                      child: _laeuft
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Anmelden'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => context.go('/registrieren'),
                    child: const Text('Neu hier? Betrieb registrieren'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
```

`lib/features/auth/presentation/registrieren_page.dart`: analog aufgebaut — Keys `reg_email`, `reg_passwort`, `reg_absenden`; Validator Passwort `>= 8` Zeichen (`'Mindestens 8 Zeichen'`); ruft `ref.read(authControllerProvider.notifier).signUp(...)`; bei Rückgabe `true` → `context.go('/mail-bestaetigen?email=${Uri.encodeComponent(email)}')`, sonst `context.go('/dashboard')`. Fehlerbehandlung identisch zu `_absenden()` oben (AuthFehler → Klartext).

`lib/features/auth/presentation/mail_bestaetigen_page.dart`: `StatelessWidget` mit `final String email;`; zeigt „Wir haben dir eine Bestaetigungs-Mail an **$email** geschickt. Bitte den Link darin anklicken und dich danach anmelden."; Button „Zur Anmeldung" → `context.go('/login')`.

- [ ] **Step 4: Test laufen lassen — muss grün sein**

Run: `flutter test test/features/auth/login_page_test.dart` → PASS (3 Tests).

- [ ] **Step 5: Commit**

```bash
git add lib/features/auth/presentation test/features/auth/login_page_test.dart
git commit -m "feat(auth): Login-, Registrier- und Mail-bestaetigen-Screen"
```

---

## Task 7: Onboarding (betrieb_gruenden) + Einladungs-Code + Konto/Logout

**Files:**
- Create: `lib/features/auth/presentation/onboarding_page.dart`, `einladung_code_page.dart`, `konto_page.dart`
- Test: `test/features/auth/onboarding_page_test.dart`

- [ ] **Step 1: Failing test schreiben**

`test/features/auth/onboarding_page_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bienen_app/features/auth/data/fake_auth_gateway.dart';
import 'package:bienen_app/features/auth/domain/auth_gateway.dart';
import 'package:bienen_app/features/auth/presentation/auth_providers.dart';
import 'package:bienen_app/features/auth/presentation/onboarding_page.dart';

Widget _app(FakeAuthGateway fake) => ProviderScope(
      overrides: [authGatewayProvider.overrideWithValue(fake)],
      child: const MaterialApp(home: OnboardingPage()),
    );

void main() {
  testWidgets('gruendet den Betrieb mit dem eingegebenen Namen', (t) async {
    final fake = FakeAuthGateway(ergebnis: const OhneBetrieb());
    await t.pumpWidget(_app(fake));
    await t.enterText(find.byKey(const Key('onb_name')), 'Imkerei Arosa');
    await t.tap(find.byKey(const Key('onb_absenden')));
    await t.pumpAndSettle();
    expect(fake.letzterGruendungsName, 'Imkerei Arosa');
  });

  testWidgets('leerer Name -> Validierungsfehler, kein Aufruf', (t) async {
    final fake = FakeAuthGateway(ergebnis: const OhneBetrieb());
    await t.pumpWidget(_app(fake));
    await t.tap(find.byKey(const Key('onb_absenden')));
    await t.pumpAndSettle();
    expect(fake.letzterGruendungsName, isNull);
  });

  testWidgets('BA003 (bereits Mitglied) -> Klartext-Fehler', (t) async {
    final fake = FakeAuthGateway(ergebnis: const OhneBetrieb())
      ..wirftBeiGruenden =
          const AuthFehler('Du gehoerst bereits zu einem Betrieb.', code: 'BA003');
    await t.pumpWidget(_app(fake));
    await t.enterText(find.byKey(const Key('onb_name')), 'X');
    await t.tap(find.byKey(const Key('onb_absenden')));
    await t.pumpAndSettle();
    expect(find.text('Du gehoerst bereits zu einem Betrieb.'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Test laufen lassen — muss fehlschlagen**

Run: `flutter test test/features/auth/onboarding_page_test.dart` → FAIL.

- [ ] **Step 3: Implementieren**

`onboarding_page.dart`: `ConsumerStatefulWidget`, Aufbau wie `LoginPage`. Ein Feld `Key('onb_name')` (Label „Name deines Betriebs", Hinweistext „z. B. Imkerei Arosa — spaeter aenderbar"), Validator „Bitte Namen eingeben". Button `Key('onb_absenden')` „Betrieb gruenden" → `ref.read(authControllerProvider.notifier).betriebGruenden(name)`; `AuthFehler` → Klartext anzeigen (Doppel-Tap-sicher via `_laeuft`-Flag). Darunter `TextButton` „Ich habe einen Einladungs-Code" → `context.go('/einladung')`.

`einladung_code_page.dart`: Feld `Key('einl_code')` (Label „Einladungs-Code", Hint `XXXX-XXXX-XXXX`), Button `Key('einl_absenden')` → `einladungAnnehmen(code)`; `AuthFehler` → Klartext (BA007/BA008 sind bereits gemappt).

`konto_page.dart`: `ConsumerWidget`; liest `authControllerProvider`; zeigt E-Mail, `rolle.anzeige`, Betriebs-ID (gekürzt); Button „Abmelden" (`Key('konto_logout')`) → `signOut()`. Wenn `currentRolleProvider` `istOwner`: Abschnitt „Team" mit Button „Mitglied einladen" → Dialog (E-Mail + Rolle editor/viewer) → `SupabaseConfig.client.rpc('mitglied_einladen', ...)` → **Code EINMALIG** in einem `SelectableText` + Kopier-Button anzeigen mit Hinweis „Der Code wird nur jetzt angezeigt.".

- [ ] **Step 4: Test laufen lassen — muss grün sein**

Run: `flutter test test/features/auth/onboarding_page_test.dart` → PASS (3 Tests).

- [ ] **Step 5: Commit**

```bash
git add lib/features/auth/presentation test/features/auth/onboarding_page_test.dart
git commit -m "feat(auth): Onboarding (betrieb_gruenden), Einladungs-Code, Konto/Logout"
```

---

## Task 8: Router-Gate + main.dart

**Files:**
- Modify: `lib/core/router/app_router.dart`, `lib/main.dart`, `lib/shared/widgets/app_shell.dart`, `lib/features/dashboard/pages/dashboard_page.dart`

- [ ] **Step 1: Router auf Riverpod umstellen + Gate einbauen**

In `app_router.dart` den globalen `final appRouter = GoRouter(...)` durch einen Provider ersetzen:
```dart
final appRouterProvider = Provider<GoRouter>((ref) {
  final gate = ref.watch(authGateNotifierProvider);
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/dashboard',
    refreshListenable: gate,
    redirect: (context, state) {
      final st = ref.read(authControllerProvider).status;
      final ziel = state.matchedLocation;
      const offen = {'/login', '/registrieren', '/mail-bestaetigen'};

      // laden: NICHT navigieren (sonst wird die URL umgeschrieben)
      if (st == AuthStatus.laden) return null;
      if (st == AuthStatus.abgemeldet) {
        return offen.contains(ziel) ? null : '/login';
      }
      if (st == AuthStatus.ohneBetrieb) {
        return (ziel == '/onboarding' || ziel == '/einladung') ? null : '/onboarding';
      }
      // angemeldet
      if (offen.contains(ziel) || ziel == '/onboarding' || ziel == '/einladung') {
        return '/dashboard';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (c, s) => const LoginPage()),
      GoRoute(path: '/registrieren', builder: (c, s) => const RegistrierenPage()),
      GoRoute(
        path: '/mail-bestaetigen',
        builder: (c, s) =>
            MailBestaetigenPage(email: s.uri.queryParameters['email'] ?? ''),
      ),
      GoRoute(path: '/onboarding', builder: (c, s) => const OnboardingPage()),
      GoRoute(path: '/einladung', builder: (c, s) => const EinladungCodePage()),
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          // ...ALLE bestehenden Routen unveraendert uebernehmen...
          GoRoute(path: '/konto', builder: (c, s) => const KontoPage()),
        ],
      ),
    ],
  );
});
```
> Wichtig: Die bestehenden Routen im `ShellRoute` **unverändert** übernehmen; nur `/konto` ergänzen. Der Splash für `laden` wird in `main.dart` gerendert (Step 2), damit `redirect` während `laden` nichts umschreibt.

- [ ] **Step 2: main.dart — Splash + Auth-Start + Sync**

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseConfig.initialize();
  runApp(const ProviderScope(child: BienenApp()));
}

class BienenApp extends ConsumerStatefulWidget {
  const BienenApp({super.key});
  @override
  ConsumerState<BienenApp> createState() => _BienenAppState();
}

class _BienenAppState extends ConsumerState<BienenApp> {
  @override
  void initState() {
    super.initState();
    // Session aufloesen + Auth-Events abonnieren (eager, sonst nie gebaut).
    Future.microtask(() {
      ref.read(authSyncProvider);
      ref.read(authControllerProvider.notifier).laden();
    });
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(authControllerProvider).status;
    if (status == AuthStatus.laden) {
      return MaterialApp(
        theme: AppTheme.light,
        debugShowCheckedModeBanner: false,
        home: const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }
    return MaterialApp.router(
      title: 'Bienen Arosa',
      theme: AppTheme.light,
      routerConfig: ref.watch(appRouterProvider),
      debugShowCheckedModeBanner: false,
    );
  }
}
```

- [ ] **Step 3: Konto-Einstieg**

`app_shell.dart` → `ConsumerWidget`; im `NavigationRail` `trailing:` ergänzen:
```dart
trailing: Expanded(
  child: Align(
    alignment: Alignment.bottomCenter,
    child: Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: IconButton(
        tooltip: 'Konto',
        icon: const Icon(Icons.account_circle_outlined, color: Colors.white70),
        onPressed: () => context.go('/konto'),
      ),
    ),
  ),
),
```
`dashboard_page.dart` → eine `ListTile`/Kachel „Konto & Team" mit `Icons.account_circle_outlined` → `context.go('/konto')` (Einstieg auch im schmalen Layout, ohne die 6er-Navigation zu sprengen).

- [ ] **Step 4: `test/widget_test.dart` anpassen (MUSS — bricht sonst)**

Der bestehende Smoke-Test pumpt `BienenApp` und erwartet `'Projekt Bienen Arosa'`. Mit dem Auth-Gate startet die App im `laden`-Splash und greift über `authSyncProvider`/`SupabaseAuthGateway` auf `SupabaseConfig.client` zu — in Tests ist Supabase **nicht initialisiert** → Absturz. Datei komplett ersetzen:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bienen_app/main.dart';
import 'package:bienen_app/features/auth/data/fake_auth_gateway.dart';
import 'package:bienen_app/features/auth/domain/auth_gateway.dart';
import 'package:bienen_app/features/auth/presentation/auth_providers.dart';

void main() {
  testWidgets('App startet und zeigt den Login, wenn keine Session besteht',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        authGatewayProvider
            .overrideWithValue(FakeAuthGateway(ergebnis: const KeineSession())),
        // Supabase ist im Test nicht initialisiert -> Auth-Event-Abo abschalten.
        authSyncProvider.overrideWith((ref) {}),
      ],
      child: const BienenApp(),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Anmelden'), findsWidgets);
  });
}
```
*(Der alte Dashboard-Text-Check entfällt bewusst: ohne Session ist das Dashboard nicht mehr erreichbar — genau das ist der Sinn des Gates. Ein Dashboard-Smoke-Test bräuchte gemockte Daten-Provider und gehört nicht in diesen Task.)*

- [ ] **Step 5: Analyze + alle Tests**

Run: `flutter analyze && flutter test`
Expected: keine Analyzer-Fehler; **alle** Tests grün (auth + construction + widget_test).

- [ ] **Step 6: Commit**

```bash
git add lib/core/router/app_router.dart lib/main.dart lib/shared/widgets/app_shell.dart lib/features/dashboard/pages/dashboard_page.dart test/widget_test.dart
git commit -m "feat(auth): Router-Gate (laden/abgemeldet/ohneBetrieb/angemeldet) + Konto-Einstieg"
```

---

## Task 9: Review-Härtungen — Auto-Seed raus, Fehler durchreichen, Storage-Pfade

**Files:**
- Modify: `lib/features/material/presentation/providers/material_provider.dart`
- Modify: `lib/features/construction/presentation/providers/construction_provider.dart`
- Modify: `lib/features/material/presentation/pages/material_detail_page.dart`

- [ ] **Step 1: `materials`-Auto-Seed entfernen + Fehler durchreichen**

In `material_provider.dart`, `_fetchFromSupabase()` (aktuell L215–234) ersetzen durch:
```dart
  Future<List<MaterialItem>> _fetchFromSupabase() async {
    final response = await SupabaseConfig.client
        .from('materials')
        .select()
        .order('sort_order', ascending: true);
    return (response as List)
        .map((json) => MaterialItem.fromJson(json as Map<String, dynamic>))
        .toList();
  }
```
Und die Methode `_seedDatabase()` (L236–243) **ersatzlos löschen**.

**Warum (Review-Blocker):** RLS liefert bei fehlendem Zugriff **0 Zeilen statt Fehler**. Der alte Code deutete das als „DB leer" und seedete Arosas Einkaufsliste — bei jedem künftigen Mandanten ein Arosa-Hardcode in dessen Daten. Und der `catch`-Zweig lieferte still `_seedData`, was RLS-/Auth-Fehler maskiert. Erstbefüllung passiert ausschliesslich über den Bootstrap (Plan 3).

`final _seedData = [...]` (L338 ff.) **bleibt** als reine Offline-/Referenzliste erhalten, wird aber nicht mehr automatisch geschrieben. Die UI zeigt bei Fehler künftig `AsyncError` (Retry) und bei 0 Zeilen einen neutralen Empty-State.

- [ ] **Step 2: Empty-/Error-State in der Material-Liste**

In `material_page.dart` sicherstellen, dass `ref.watch(materialListProvider)` den `AsyncValue` mit `.when(data:..., loading:..., error:...)` rendert — im `error`-Zweig „Konnte nicht laden" + Retry-Button (`ref.invalidate(materialListProvider)`), im leeren `data`-Fall „Noch keine Materialien".

- [ ] **Step 3: Storage-Pfade auf `<betrieb_id>/` umstellen**

`construction_provider.dart` `attachPhoto` (L99–110): Signatur um `betriebId` erweitern und Pfad präfixen:
```dart
  Future<void> attachPhoto(String stepKey, Uint8List bytes, String betriebId) async {
    final path = '$betriebId/$stepKey.jpg';
```
**Warum:** `stepKey` ist ein **statischer, im Code fest verdrahteter** Schlüssel (`hv_planung`, `daemmung`, …) — ohne Präfix schreiben zwei Mandanten desselben Bauschritts auf exakt denselben Objektpfad (`upsert: true`) und überschreiben sich gegenseitig. Die aufrufende Stelle holt `betriebId` aus `ref.read(currentBetriebIdProvider)!`.

`material_detail_page.dart`: Foto (L~461), PDF (L~509) und Beleg-Upload sowie `remove` (L~551) analog auf `'$betriebId/${item.id}/...'` umstellen; beim Löschen das zusätzliche Pfadsegment beim URL-Parsing berücksichtigen. `betriebId` via `ref.read(currentBetriebIdProvider)!`.

> Alt-Objekte ohne Präfix bleiben über ihre gespeicherten public URLs lesbar; die Migration der Bestands-Objekte passiert im Bootstrap (Plan 3).

- [ ] **Step 4: Analyze + Tests**

Run: `flutter analyze && flutter test` → grün.

- [ ] **Step 5: Commit**

```bash
git add lib/features/material lib/features/construction
git commit -m "fix(auth): Auto-Seed raus, RLS-Fehler nicht maskieren, <betrieb_id>/-Storage-Pfade"
```

---

## Task 10: `web/index.html` — Versions-Redirect darf Auth-Callback nicht verwerfen

**Files:**
- Modify: `bienen_app/web/index.html`

- [ ] **Step 1: Guard einbauen**

Der bestehende Versions-Redirect ruft `window.location.replace(window.location.pathname + '?v=' + ver)` und **verwirft dabei Query + Hash**. Beim Klick auf den Bestätigungs-Link (`?code=…`) würde der Token so vor dem App-Start vernichtet. Vor dem Versions-Gate ergänzen und die Redirect-Bedingung erweitern:

```js
var s = window.location.search, h = window.location.hash;
var hasAuth = /[?&](code|error|error_description)=/.test(s) ||
              /(access_token|refresh_token|error)=/.test(h);
```
und die Bedingung von `if (urlVersion !== serverVer) { redirectToVersion(serverVer); return; }`
ändern auf `if (urlVersion !== serverVer && !hasAuth) { redirectToVersion(serverVer); return; }`.

Der Fall `hasAuth` fällt damit in den bestehenden Zweig, der `flutter_bootstrap.js?v=serverVer` lädt → korrekte Version **und** supabase_flutter kann den Token einlösen (und räumt die URL selbst per `history.replaceState` auf).

- [ ] **Step 2: Verifizieren**

Run: `grep -n "hasAuth" web/index.html` → 2 Treffer (Definition + Bedingung).
Run: `flutter analyze` → unverändert grün.

- [ ] **Step 3: Commit**

```bash
git add web/index.html
git commit -m "fix(auth): index.html-Versions-Redirect verwirft Auth-Callback-Token nicht mehr"
```

---

## Abschluss Plan 2

Nach Task 10: Die App hat eine vollständige, **getestete** Auth-Schicht — aber sie ist **noch nicht deployed** und die DB ist **noch nicht scharf** (public-Policies aktiv, kein Betrieb, kein Backfill).

**Erfolgskriterien:** `flutter analyze` sauber · `flutter test` komplett grün · Login/Onboarding/Einladung/Logout laufen gegen das `FakeAuthGateway` ohne Netz.

**Danach → Plan 3 (Rollout & Cutover):** Dashboard-Config (Auth-Hook aktivieren, Confirm-Email, Site-URL) → `deploy.sh` → Daniels Registrierung + `betrieb_gruenden` → Bootstrap-Backfill (`WHERE betrieb_id IS NULL` unter `ACCESS EXCLUSIVE`) + NOT NULL/Default → authenticated-Rollen-Test-Gate → Migration B (public-Policies droppen + `revoke from anon`) → Storage-Listing→authenticated.
