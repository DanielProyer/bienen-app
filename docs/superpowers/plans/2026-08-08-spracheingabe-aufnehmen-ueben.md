# Spracheingabe — Bauabschnitt 2: Aufnehmen und Üben

> **Für agentische Ausführung:** ERFORDERLICHE SUB-SKILL: `superpowers:subagent-driven-development`
> (empfohlen) oder `superpowers:executing-plans`. Schritte nutzen Kästchen (`- [ ]`) zur Nachverfolgung.

**Ziel:** Der Screen `/spracheingabe` wird benutzbar. Man spricht eine Übungskarte ein, sieht nach
wenigen Sekunden grün oder rot, und die Aufnahme liegt danach im Bestand.

**Architektur:** Die Aufnahme läuft im Browser über `dart:js_interop` mit VM-Stub (Muster
`ohne_metadaten*.dart`). Die Datei geht in den privaten Bucket `sprach-proben`, die Zeile in
`sprach_proben`, danach ruft die App die Edge Function `transkription` — die dafür einen **zweiten
Eingang** bekommt, der ein Nutzer-JWT prüft statt des Testworts der öffentlichen Seite.

**Tech-Stack:** Flutter Web 3.41, Riverpod AsyncNotifier ohne Codegen, Go Router (Hash-Routing),
Supabase (Storage, Edge Functions), Deno.

**Grundlage:** `docs/superpowers/specs/2026-08-08-spracheingabe-training-design.md`.
**Vorgänger:** `2026-08-08-spracheingabe-fundament.md` (Bauabschnitt 1, abgeschlossen; T01–T04 live).

---

## Was schon steht und benutzt wird

`lib/features/spracheingabe/domain/` — `fachwort_treffer.dart`, `wortfehlerrate.dart`,
`korrektur_anwendung.dart`, `verhoerer_diff.dart`, `lernschwelle.dart`, `sprach_modelle.dart`,
`startstapel.dart`. `lib/features/spracheingabe/data/` — `spracheingabe_gateway.dart` (abstrakte
Schnittstelle + Supabase-Umsetzung) und `fake_spracheingabe_gateway.dart`.

Die Tabellen `sprach_karten`, `sprach_proben` (+ Bucket), `sprach_ergebnisse` und
`sprach_korrekturen` sind angewandt.

## Dateien

| Datei | Verantwortung |
|---|---|
| `supabase/functions/transkription/index.ts` | **ändern:** zweiter Eingang mit Nutzer-JWT |
| `lib/features/spracheingabe/data/sprach_aufnahme.dart` | Fassade mit bedingter Einbindung |
| `lib/features/spracheingabe/data/sprach_aufnahme_stub.dart` | VM-Stub, damit Tests laufen |
| `lib/features/spracheingabe/data/sprach_aufnahme_web.dart` | MediaRecorder über `dart:js_interop` |
| `lib/features/spracheingabe/data/sprach_speicher.dart` | Upload in den Bucket, Pfadbau |
| `lib/features/spracheingabe/domain/kartenwahl.dart` | welche Karte als Nächste — reine Funktion |
| `lib/features/spracheingabe/presentation/providers/spracheingabe_provider.dart` | Zustand |
| `lib/features/spracheingabe/presentation/pages/spracheingabe_page.dart` | Screen, drei Segmente |
| `lib/core/router/app_router.dart` | **ändern:** Route |
| `lib/features/auth/presentation/konto_page.dart` | **ändern:** Einstieg |

**Warum der Einstieg unter „Konto" liegt:** Der Trainingsbestand ist personenbezogen — Aufnahmen,
Messwerte und gelernte Regeln gehören einer Stimme, nicht dem Betrieb (T02–T04). Damit gehört er
dorthin, wo auch die Benachrichtigungen liegen, und nicht in einen Betriebs-Tab.

---

## Task 1: Zweiter Eingang für die Edge Function

**Dateien:**
- Ändern: `supabase/functions/transkription/index.ts`

Die Function kennt bisher nur das Testwort der öffentlichen Seite. Aus der App kommt stattdessen ein
gültiges Nutzer-JWT. Beide Wege müssen nebeneinander bestehen: Die Testseite bleibt vorerst
(Bauabschnitt 1, Abschnitt „Was bewusst nicht gebaut wird").

Muster 1:1 aus `taeglicher-ueberblick/index.ts` — dort laufen Cron-Secret und Nutzer-JWT ebenfalls
nebeneinander. `verify_jwt` bleibt deshalb `false`: Die Function prüft ihre Berechtigung selbst,
und die Plattform würde sonst den Testwort-Weg abweisen, bevor die Function läuft.

- [ ] **Schritt 1: Import und Schlüsselwahl ergänzen**

Ganz oben in `index.ts`, nach dem bestehenden Import:

```typescript
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

// Der Service-Key wird nur zum PRUEFEN des Nutzer-JWT gebraucht, nie zum
// Lesen von Daten. Moderne Schluessel zuerst (D-87: die Legacy-Keys sind
// deaktiviert), Fallback fuer den Fall, dass nur der alte Name gesetzt ist.
function serviceKey(): string {
  const modern = Deno.env.get('SUPABASE_SECRET_KEYS');
  if (modern) return modern.split(',')[0].trim();
  return Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
}
```

- [ ] **Schritt 2: Berechtigungsprüfung um den JWT-Weg erweitern**

Die bestehende Funktion `testwortStimmt` bleibt unverändert. Darunter neu:

```typescript
/// Zweiter Eingang: ein eingeloggter Nutzer der App.
///
/// Die oeffentliche Testseite hat keinen Login und weist sich mit dem Testwort
/// aus; die App hat einen und schickt ihr JWT. Beide Wege muessen nebeneinander
/// bestehen, solange die Testseite existiert.
///
/// Geprueft wird NUR, ob das JWT gueltig ist — welchem Betrieb der Nutzer
/// angehoert, spielt hier keine Rolle: Die Function liest nichts aus der
/// Datenbank, sie reicht Audio an die Erkenner weiter und gibt Text zurueck.
async function nutzerIstEingeloggt(anfrage: Request): Promise<boolean> {
  const kopf = anfrage.headers.get('Authorization') ?? '';
  const jwt = kopf.startsWith('Bearer ') ? kopf.slice(7) : '';
  if (!jwt) return false;
  const schluessel = serviceKey();
  if (!schluessel) return false;
  try {
    const admin = createClient(Deno.env.get('SUPABASE_URL')!, schluessel);
    const { data, error } = await admin.auth.getUser(jwt);
    return !error && !!data.user;
  } catch {
    return false;
  }
}
```

- [ ] **Schritt 3: Die Torprüfung austauschen**

Den bestehenden Block

```typescript
  if (!testwortStimmt(anfrage)) {
    return antwort({ fehler: 'Testwort fehlt oder stimmt nicht' }, 401);
  }
```

ersetzen durch:

```typescript
  // Reihenfolge mit Absicht: Das Testwort kostet einen Zeichenvergleich, die
  // JWT-Pruefung einen Netzaufruf. Wer das Testwort mitschickt, zahlt den
  // Aufruf nicht.
  if (!testwortStimmt(anfrage) && !(await nutzerIstEingeloggt(anfrage))) {
    return antwort({ fehler: 'Nicht berechtigt: weder gültiges Testwort noch Anmeldung' }, 401);
  }
```

- [ ] **Schritt 4: CORS-Kopf um den Authorization-Header erweitern**

`supabase_flutter` schickt beim `functions.invoke` einen `Authorization`-Header. Ohne Freigabe im
Preflight lehnt der Browser die Anfrage ab, **bevor** die Function läuft — das ist die Falle aus
D-86, die schon einmal einen halben Tag gekostet hat.

```typescript
const KOPF = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, content-type, x-testwort, x-client-info, apikey',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Content-Type': 'application/json',
};
```

- [ ] **Schritt 5: Ausrollen**

Über den Supabase-MCP `deploy_edge_function`, Name `transkription`, `verify_jwt: false`, mit allen
drei Dateien (`index.ts`, `anbieter.ts`, `fachwoerter.ts`).

- [ ] **Schritt 6: Beide Tore prüfen**

```bash
curl -s -o /dev/null -w "%{http_code}\n" -X POST "https://dcdcohktxbhdxnxjvcyp.supabase.co/functions/v1/transkription?aktion=ping"
```

Erwartet: `401`

```bash
curl -s -o /dev/null -w "%{http_code}\n" -X POST -H "Authorization: Bearer ungueltig" "https://dcdcohktxbhdxnxjvcyp.supabase.co/functions/v1/transkription?aktion=ping"
```

Erwartet: `401` — ein erfundenes JWT darf nicht durchkommen.

- [ ] **Schritt 7: Committen**

```bash
git add supabase/functions/transkription/index.ts
git commit -m "Transkription: zweiter Eingang mit Nutzer-JWT fuer den App-Weg"
```

---

## Task 2: Kartenwahl als reine Funktion (TDD)

**Dateien:**
- Erstellen: `lib/features/spracheingabe/domain/kartenwahl.dart`
- Test: `test/spracheingabe/kartenwahl_test.dart`

Welche Karte kommt als Nächste? Nicht die Listenreihenfolge — bevorzugt, was zuletzt schlecht lief
oder lange nicht dran war.

- [ ] **Schritt 1: Fehlschlagenden Test schreiben**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:bienen_app/features/spracheingabe/domain/kartenwahl.dart';
import 'package:bienen_app/features/spracheingabe/domain/sprach_modelle.dart';

SprachKarte _k(String text) =>
    SprachKarte(id: text, art: KartenArt.wort, sollText: text);

void main() {
  test('ohne Karten kommt nichts zurück', () {
    expect(naechsteKarte(karten: const [], bilanz: const {}), isNull);
  });

  test('eine noch nie geübte Karte hat Vorrang vor einer gelungenen', () {
    final gewaehlt = naechsteKarte(
      karten: [_k('Varroa'), _k('Weiselzellen')],
      bilanz: const {'Varroa': Kartenbilanz(versuche: 3, treffer: 3)},
    );
    expect(gewaehlt!.sollText, 'Weiselzellen');
  });

  test('unter geübten Karten kommt die mit der schlechteren Quote zuerst', () {
    final gewaehlt = naechsteKarte(
      karten: [_k('Varroa'), _k('Weiselzellen')],
      bilanz: const {
        'Varroa': Kartenbilanz(versuche: 4, treffer: 4),
        'Weiselzellen': Kartenbilanz(versuche: 4, treffer: 1),
      },
    );
    expect(gewaehlt!.sollText, 'Weiselzellen');
  });

  test('bei gleicher Quote kommt die seltener geübte zuerst', () {
    final gewaehlt = naechsteKarte(
      karten: [_k('Varroa'), _k('Weiselzellen')],
      bilanz: const {
        'Varroa': Kartenbilanz(versuche: 8, treffer: 4),
        'Weiselzellen': Kartenbilanz(versuche: 2, treffer: 1),
      },
    );
    expect(gewaehlt!.sollText, 'Weiselzellen');
  });

  test('die zuletzt gesprochene Karte kommt nicht sofort noch einmal', () {
    // Sonst haengt man bei einem hartnaeckigen Wort fest und uebt nichts sonst.
    final gewaehlt = naechsteKarte(
      karten: [_k('Varroa'), _k('Weiselzellen')],
      bilanz: const {
        'Varroa': Kartenbilanz(versuche: 1, treffer: 0),
        'Weiselzellen': Kartenbilanz(versuche: 1, treffer: 1),
      },
      zuletzt: 'Varroa',
    );
    expect(gewaehlt!.sollText, 'Weiselzellen');
  });

  test('bei nur einer Karte wird sie auch dann gewählt, wenn sie zuletzt dran war', () {
    final gewaehlt = naechsteKarte(
      karten: [_k('Varroa')],
      bilanz: const {},
      zuletzt: 'Varroa',
    );
    expect(gewaehlt!.sollText, 'Varroa');
  });
}
```

- [ ] **Schritt 2: Test laufen lassen, Fehlschlag bestätigen**

Run: `flutter test test/spracheingabe/kartenwahl_test.dart`
Erwartet: FEHLER — Datei/Symbol nicht gefunden

- [ ] **Schritt 3: Umsetzung schreiben**

```dart
import 'package:bienen_app/features/spracheingabe/domain/sprach_modelle.dart';

/// Wie eine Karte bisher gelaufen ist.
class Kartenbilanz {
  final int versuche;
  final int treffer;
  const Kartenbilanz({required this.versuche, required this.treffer});

  /// 0.0 bis 1.0; ohne Versuch gilt sie als ungeuebt, nicht als schlecht.
  double get quote => versuche == 0 ? 0.0 : treffer / versuche;
}

/// Waehlt die naechste Uebungskarte.
///
/// Reihenfolge der Kriterien:
///  1. **Noch nie geuebt** kommt zuerst — was man nie gesprochen hat, ist die
///     groesste Wissensluecke.
///  2. Dann die **schlechteste Trefferquote** — geuebt wird, was klemmt, nicht
///     was ohnehin sitzt.
///  3. Bei gleicher Quote die **seltener geuebte**.
///
/// Die zuletzt gesprochene Karte wird uebersprungen, solange es eine Alternative
/// gibt: Sonst haengt man bei einem hartnaeckigen Wort fest und uebt nichts
/// sonst. Bei nur einer Karte gilt die Regel nicht — sonst bliebe der Stapel
/// stehen.
SprachKarte? naechsteKarte({
  required List<SprachKarte> karten,
  required Map<String, Kartenbilanz> bilanz,
  String? zuletzt,
}) {
  if (karten.isEmpty) return null;

  var auswahl = karten.where((k) => k.sollText != zuletzt).toList();
  if (auswahl.isEmpty) auswahl = karten;

  auswahl.sort((a, b) {
    final ba = bilanz[a.sollText];
    final bb = bilanz[b.sollText];
    final aNeu = ba == null || ba.versuche == 0;
    final bNeu = bb == null || bb.versuche == 0;
    if (aNeu != bNeu) return aNeu ? -1 : 1;
    if (aNeu && bNeu) return 0;
    final quote = ba!.quote.compareTo(bb!.quote);
    if (quote != 0) return quote;
    return ba.versuche.compareTo(bb.versuche);
  });
  return auswahl.first;
}
```

- [ ] **Schritt 4: Test laufen lassen, Erfolg bestätigen**

Run: `flutter test test/spracheingabe/kartenwahl_test.dart`
Erwartet: `All tests passed!` (6 Tests)

- [ ] **Schritt 5: Committen**

```bash
git add lib/features/spracheingabe/domain/kartenwahl.dart test/spracheingabe/kartenwahl_test.dart
git commit -m "Spracheingabe: Kartenwahl uebt, was klemmt, 6 Tests"
```

---

## Task 3: Aufnahme im Browser (js-interop mit VM-Stub)

**Dateien:**
- Erstellen: `lib/features/spracheingabe/data/sprach_aufnahme.dart`
- Erstellen: `lib/features/spracheingabe/data/sprach_aufnahme_stub.dart`
- Erstellen: `lib/features/spracheingabe/data/sprach_aufnahme_web.dart`

Muster exakt wie `lib/core/storage/ohne_metadaten*.dart`: eine Fassade mit bedingter Einbindung,
ein VM-Stub, damit `flutter test` läuft, und die Web-Umsetzung mit eigenen Interop-Kapseln.
**Kein `package:web`** — das Paket steht nicht in `pubspec.yaml` und soll da nicht hinein.

- [ ] **Schritt 1: Fassade anlegen**

```dart
import 'dart:typed_data';

import 'package:bienen_app/features/spracheingabe/data/sprach_aufnahme_stub.dart'
    if (dart.library.js_interop) 'package:bienen_app/features/spracheingabe/data/sprach_aufnahme_web.dart'
    as impl;

/// Was eine beendete Aufnahme hergibt.
class Tonaufnahme {
  final Uint8List bytes;
  final int dauerMs;
  final String mime;
  const Tonaufnahme({required this.bytes, required this.dauerMs, required this.mime});
}

/// Nimmt Ton im Browser auf.
///
/// Bewusst OHNE den stillen 30-Hz-Dauerton aus D-98c: Der loest das Einfrieren
/// untaetiger Tabs im Hintergrund, und beim Drill bleibt der Bildschirm an.
/// Fuer den spaeteren Durchsicht-Mitschnitt kommt er wieder dazu.
abstract class SprachAufnahme {
  Future<void> starten();
  Future<Tonaufnahme> beenden();
  void abbrechen();

  factory SprachAufnahme() => impl.aufnahmeErzeugen();
}
```

- [ ] **Schritt 2: VM-Stub anlegen**

```dart
import 'package:bienen_app/features/spracheingabe/data/sprach_aufnahme.dart';

/// Auf der VM (Tests, Analyse) gibt es kein Mikrofon. Der Stub wirft beim
/// BENUTZEN, nicht beim Erzeugen — so bleibt jeder Test uebersetzbar, der die
/// Klasse nur referenziert, und ein versehentlicher Aufruf faellt sofort auf.
SprachAufnahme aufnahmeErzeugen() => _StubAufnahme();

class _StubAufnahme implements SprachAufnahme {
  Never _nein() => throw UnsupportedError(
      'Tonaufnahme gibt es nur im Browser (dart.library.js_interop).');

  @override
  Future<void> starten() => _nein();

  @override
  Future<Tonaufnahme> beenden() => _nein();

  @override
  void abbrechen() => _nein();
}
```

- [ ] **Schritt 3: Web-Umsetzung anlegen**

```dart
import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:bienen_app/features/spracheingabe/data/sprach_aufnahme.dart';

// Minimale eigene Interop-Kapsel (kein `package:web`). Muster wie
// core/storage/ohne_metadaten_web.dart.

@JS('navigator')
external _Navigator get _navigator;

extension type _Navigator._(JSObject _) implements JSObject {
  external _Geraete get mediaDevices;
}

extension type _Geraete._(JSObject _) implements JSObject {
  external JSPromise<_Strom> getUserMedia(_Wunsch wunsch);
}

extension type _Wunsch._(JSObject _) implements JSObject {
  external factory _Wunsch({bool audio});
}

extension type _Strom._(JSObject _) implements JSObject {
  external JSArray<_Spur> getTracks();
}

extension type _Spur._(JSObject _) implements JSObject {
  external void stop();
}

@JS('MediaRecorder')
extension type _Rekorder._(JSObject _) implements JSObject {
  external factory _Rekorder(_Strom strom, _RekorderWunsch wunsch);
  external static bool isTypeSupported(String typ);
  external void start(int scheibeMs);
  external void stop();
  external String get mimeType;
  external set ondataavailable(JSFunction f);
  external set onstop(JSFunction f);
}

extension type _RekorderWunsch._(JSObject _) implements JSObject {
  external factory _RekorderWunsch({String mimeType, int audioBitsPerSecond});
}

extension type _DatenEreignis._(JSObject _) implements JSObject {
  external _Brocken get data;
}

@JS('Blob')
extension type _Brocken._(JSObject _) implements JSObject {
  external factory _Brocken(JSArray<JSAny> teile, _BrockenWunsch wunsch);
  external int get size;
  external JSPromise<JSArrayBuffer> arrayBuffer();
}

extension type _BrockenWunsch._(JSObject _) implements JSObject {
  external factory _BrockenWunsch({String type});
}

/// 24 kbit/s Opus — im Tontest gemessene 0,08 MB je Tonminute. Beide Erkenner
/// nehmen webm/opus direkt an, es wird also nichts umgewandelt.
const _wunschFormat = 'audio/webm;codecs=opus';
const _bitrate = 24000;

SprachAufnahme aufnahmeErzeugen() => _WebAufnahme();

class _WebAufnahme implements SprachAufnahme {
  _Strom? _strom;
  _Rekorder? _rekorder;
  final List<JSAny> _teile = [];
  int _startMs = 0;

  @override
  Future<void> starten() async {
    _teile.clear();
    _strom = await _navigator.mediaDevices.getUserMedia(_Wunsch(audio: true)).toDart;

    // Nicht jeder Browser kennt das Sparformat. Faellt es aus, nimmt der
    // Rekorder seine Vorgabe — ein groesseres, aber gueltiges Format ist
    // besser als gar keine Aufnahme.
    final rekorder = _Rekorder.isTypeSupported(_wunschFormat)
        ? _Rekorder(_strom!,
            _RekorderWunsch(mimeType: _wunschFormat, audioBitsPerSecond: _bitrate))
        : _Rekorder(_strom!, _RekorderWunsch());

    rekorder.ondataavailable = ((JSAny ereignis) {
      final brocken = (ereignis as _DatenEreignis).data;
      if (brocken.size > 0) _teile.add(brocken);
    }).toJS;

    _rekorder = rekorder;
    _startMs = DateTime.now().millisecondsSinceEpoch;
    // Eine Sekunde Zeitscheibe: Bei einer Drill-Karte von wenigen Sekunden
    // liefert der Rekorder sonst erst beim Stoppen ueberhaupt Daten.
    rekorder.start(1000);
  }

  @override
  Future<Tonaufnahme> beenden() async {
    final rekorder = _rekorder;
    if (rekorder == null) throw StateError('Es läuft keine Aufnahme.');
    final dauerMs = DateTime.now().millisecondsSinceEpoch - _startMs;

    // Auf onstop warten, nicht blind stoppen: Das letzte Datenpaket kommt
    // NACH dem stop()-Aufruf. Wer sofort weiterliest, verliert das Ende des
    // gesprochenen Wortes — bei einer Ein-Wort-Karte also alles.
    final fertig = Completer<void>();
    rekorder.onstop = ((JSAny? _) {
      if (!fertig.isCompleted) fertig.complete();
    }).toJS;
    rekorder.stop();
    await fertig.future;

    final mime = rekorder.mimeType.isEmpty ? 'audio/webm' : rekorder.mimeType;
    _mikrofonFreigeben();
    _rekorder = null;

    final ganzes = _Brocken(_teile.toJS, _BrockenWunsch(type: mime));
    final puffer = await ganzes.arrayBuffer().toDart;
    return Tonaufnahme(
      bytes: puffer.toDart.asUint8List(),
      dauerMs: dauerMs,
      mime: mime.split(';').first,
    );
  }

  @override
  void abbrechen() {
    try {
      if (_rekorder != null) _rekorder!.stop();
    } catch (_) {
      // Ein bereits gestoppter Rekorder wirft — das ist hier kein Fehler.
    }
    _rekorder = null;
    _teile.clear();
    _mikrofonFreigeben();
  }

  /// Ohne das leuchtet die Aufnahme-Anzeige des Browsers weiter, obwohl
  /// niemand mehr zuhoert — fuer den Nutzer sieht das aus wie eine Wanze.
  void _mikrofonFreigeben() {
    final strom = _strom;
    if (strom == null) return;
    final spuren = strom.getTracks().toDart;
    for (final spur in spuren) {
      spur.stop();
    }
    _strom = null;
  }
}
```

- [ ] **Schritt 4: Übersetzbarkeit beider Zweige beweisen**

Run: `flutter analyze lib test`
Erwartet: `No issues found!`

Run: `flutter build web --release`
Erwartet: `√ Built build\web` — **das ist der eigentliche js-interop-Beweis.** `analyze` allein
übersetzt den Web-Zweig nicht.

- [ ] **Schritt 5: Committen**

```bash
git add lib/features/spracheingabe/data/sprach_aufnahme.dart lib/features/spracheingabe/data/sprach_aufnahme_stub.dart lib/features/spracheingabe/data/sprach_aufnahme_web.dart
git commit -m "Spracheingabe: Tonaufnahme im Browser, js-interop mit VM-Stub"
```

---

## Task 4: Ablage der Aufnahme

**Dateien:**
- Erstellen: `lib/features/spracheingabe/data/sprach_speicher.dart`
- Test: `test/spracheingabe/sprach_speicher_test.dart`

Der Pfad muss zeichengenau zum CHECK der Tabelle und zu den Storage-Policies passen
(`<betrieb_id>/<person_id>/<datei>`). Ein falscher Pfad scheitert an der Policy, und die
Fehlermeldung sagt nicht, warum — deshalb wird der Pfadbau als **reine Funktion** getestet, getrennt
vom Upload.

- [ ] **Schritt 1: Fehlschlagenden Test schreiben**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:bienen_app/features/spracheingabe/data/sprach_speicher.dart';

void main() {
  test('der Pfad folgt <betrieb>/<person>/<datei>', () {
    final p = probenPfad(betriebId: 'b1', personId: 'u1', dateiname: 'x.webm');
    expect(p, 'b1/u1/x.webm');
  });

  test('der Pfad beginnt mit der Betriebs-ID — sonst greift der CHECK nicht', () {
    // storage_path like (betrieb_id || '/' || person_id || '/%')
    final p = probenPfad(betriebId: 'b1', personId: 'u1', dateiname: 'x.webm');
    expect(p.startsWith('b1/u1/'), isTrue);
  });

  test('leere Angaben werden abgelehnt statt einen kaputten Pfad zu bauen', () {
    expect(() => probenPfad(betriebId: '', personId: 'u1', dateiname: 'x.webm'),
        throwsArgumentError);
    expect(() => probenPfad(betriebId: 'b1', personId: '', dateiname: 'x.webm'),
        throwsArgumentError);
    expect(() => probenPfad(betriebId: 'b1', personId: 'u1', dateiname: '  '),
        throwsArgumentError);
  });

  test('der Dateiname endet auf die Endung des Formats', () {
    expect(probenDateiname(mime: 'audio/webm', kennung: 'abc'), 'abc.webm');
    expect(probenDateiname(mime: 'audio/mp4', kennung: 'abc'), 'abc.mp4');
    expect(probenDateiname(mime: 'audio/unbekannt', kennung: 'abc'), 'abc.webm');
  });
}
```

- [ ] **Schritt 2: Test laufen lassen, Fehlschlag bestätigen**

Run: `flutter test test/spracheingabe/sprach_speicher_test.dart`
Erwartet: FEHLER — Datei/Symbol nicht gefunden

- [ ] **Schritt 3: Umsetzung schreiben**

```dart
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Bucket aus Migration T02, privat.
const sprachProbenBucket = 'sprach-proben';

/// Baut den Ablagepfad einer Probe.
///
/// Muss zeichengenau zum CHECK der Tabelle passen
/// (`storage_path like betrieb_id || '/' || person_id || '/%'`) und zu den
/// Storage-Policies, die BEIDE Pfadebenen pruefen. Ein falscher Pfad scheitert
/// an der Policy mit einer Meldung, die den Grund nicht nennt — deshalb steht
/// der Bau hier als eigene, geprueft Funktion.
String probenPfad({
  required String betriebId,
  required String personId,
  required String dateiname,
}) {
  if (betriebId.trim().isEmpty) throw ArgumentError('betriebId fehlt');
  if (personId.trim().isEmpty) throw ArgumentError('personId fehlt');
  if (dateiname.trim().isEmpty) throw ArgumentError('dateiname fehlt');
  return '${betriebId.trim()}/${personId.trim()}/${dateiname.trim()}';
}

/// Endung passend zum aufgenommenen Format. Unbekanntes landet auf `.webm` —
/// der Erkenner erkennt das Format ohnehin am Inhalt, aber eine sinnvolle
/// Endung hilft beim Herunterladen und beim Nachhoeren.
String probenDateiname({required String mime, required String kennung}) {
  final endung = switch (mime.split(';').first.trim()) {
    'audio/mp4' => 'mp4',
    'audio/mpeg' => 'mp3',
    'audio/ogg' => 'ogg',
    'audio/wav' => 'wav',
    _ => 'webm',
  };
  return '$kennung.$endung';
}

/// Legt Tonaufnahmen im privaten Bucket ab. Muster wie `FotoSpeicher`.
class SprachSpeicher {
  final SupabaseClient _c;
  SprachSpeicher(this._c);

  /// Laedt hoch und gibt den Pfad zurueck (nicht die URL — die Tabelle haelt
  /// Pfade, damit sie beim Anzeigen frisch signiert werden koennen).
  ///
  /// `upsert: false` mit Absicht: Die Kennung ist eine UUID, eine Kollision
  /// waere ein Fehler und soll auffallen statt still zu ueberschreiben.
  Future<String> hochladen({
    required String betriebId,
    required String personId,
    required Uint8List bytes,
    required String mime,
    required String kennung,
  }) async {
    final pfad = probenPfad(
      betriebId: betriebId,
      personId: personId,
      dateiname: probenDateiname(mime: mime, kennung: kennung),
    );
    await _c.storage.from(sprachProbenBucket).uploadBinary(
          pfad,
          bytes,
          fileOptions: FileOptions(upsert: false, contentType: mime),
        );
    return pfad;
  }

  Future<String> signierteUrl(String pfad, {int ablaufSekunden = 3600}) =>
      _c.storage.from(sprachProbenBucket).createSignedUrl(pfad, ablaufSekunden);
}
```

- [ ] **Schritt 4: Test laufen lassen, Erfolg bestätigen**

Run: `flutter test test/spracheingabe/sprach_speicher_test.dart`
Erwartet: `All tests passed!` (4 Tests)

- [ ] **Schritt 5: Committen**

```bash
git add lib/features/spracheingabe/data/sprach_speicher.dart test/spracheingabe/sprach_speicher_test.dart
git commit -m "Spracheingabe: Ablage der Proben, Pfadbau geprueft, 4 Tests"
```

---

## Task 5: Gateway um Erkennung und Startstapel erweitern

**Dateien:**
- Ändern: `lib/features/spracheingabe/data/spracheingabe_gateway.dart`
- Ändern: `lib/features/spracheingabe/data/fake_spracheingabe_gateway.dart`
- Ändern: `test/spracheingabe/fake_gateway_test.dart`

- [ ] **Schritt 1: Schnittstelle erweitern**

In `spracheingabe_gateway.dart` in die abstrakte Klasse `SpracheingabeGateway` einfügen:

```dart
  /// Schickt eine Aufnahme an EINEN Erkenner und gibt das Transkript zurueck.
  ///
  /// Nur der schnelle Live-Anbieter — der Vollvergleich ueber alle drei laeuft
  /// spaeter ueber den gespeicherten Ton (Bauabschnitt 4). Das Warten auf alle
  /// waere rund zwanzig Sekunden je Karte und toetete den Drill.
  Future<String> transkribieren({
    required Uint8List bytes,
    required String dateiname,
    required String anbieter,
    required bool mitWortliste,
  });

  /// Legt den Startstapel an, falls der Betrieb noch keinen hat.
  /// Gibt zurueck, wie viele Karten angelegt wurden (0 = war schon da).
  Future<int> startstapelSicherstellen();
```

- [ ] **Schritt 2: Supabase-Umsetzung ergänzen**

Oben in derselben Datei die Importe ergänzen:

```dart
import 'dart:typed_data';

import 'package:bienen_app/features/spracheingabe/domain/startstapel.dart';
```

> **`MultipartFile` und `HttpMethod` kommen über `supabase_flutter` mit** — nachgeschlagen:
> `functions_client` exportiert `package:http/http.dart show ByteStream, MultipartFile`.
> **Kein neuer Eintrag im `pubspec.yaml`**, `http` bleibt eine transitive Abhängigkeit.
>
> Ebenfalls nachgeschlagen: `invoke(..., files:, body:)` baut einen `MultipartRequest`, und
> **`body` wird dabei zu den Formularfeldern** — es muss deshalb ein `Map<String, String>` sein
> (die Bibliothek prüft das mit einem `assert`). Genau darauf greift die Function mit
> `form.get('wortliste')` zu.

In `SupabaseSpracheingabeGateway` einfügen:

```dart
  @override
  Future<String> transkribieren({
    required Uint8List bytes,
    required String dateiname,
    required String anbieter,
    required bool mitWortliste,
  }) async {
    // Die Function erkennt den App-Weg am mitgeschickten JWT; supabase_flutter
    // haengt es bei invoke() automatisch an.
    final FunctionResponse res;
    try {
      res = await _c.functions.invoke(
        'transkription',
        method: HttpMethod.post,
        queryParameters: {'aktion': anbieter},
        files: [MultipartFile.fromBytes('audio', bytes, filename: dateiname)],
        body: {'wortliste': mitWortliste ? 'ja' : 'nein'},
      );
    } on FunctionException catch (e) {
      throw Exception(_funktionsKlartext(e));
    }

    final daten = res.data;
    if (daten is! Map) throw Exception('Unerwartete Antwort der Erkennung.');
    if (daten['fehler'] != null) throw Exception('Erkennung: ${daten['fehler']}');
    final ergebnis = daten['ergebnis'];
    if (ergebnis is! Map) throw Exception('Die Erkennung lieferte kein Ergebnis.');
    if (ergebnis['fehler'] != null) throw Exception('$anbieter: ${ergebnis['fehler']}');
    return (ergebnis['text'] as String?) ?? '';
  }

  String _funktionsKlartext(FunctionException e) => switch (e.status) {
        401 => 'Nicht berechtigt — bitte neu anmelden.',
        404 => 'Die Erkennung ist nicht erreichbar (Function fehlt).',
        504 => 'Die Erkennung hat zu lange gebraucht. Kürzere Aufnahme versuchen.',
        _ => 'Erkennung fehlgeschlagen (Status ${e.status}).',
      };

  @override
  Future<int> startstapelSicherstellen() async {
    final vorhanden = await _c
        .from('sprach_karten')
        .select('id')
        .eq('herkunft', 'start')
        .limit(1);
    if ((vorhanden as List).isNotEmpty) return 0;

    // person_id bleibt leer: Der Startstapel gilt fuer alle im Betrieb.
    // betrieb_id kommt aus dem Default — hier ist das richtig, weil die Karten
    // ausdruecklich zum aktiven Betrieb gehoeren sollen.
    final zeilen = startstapel.map((k) => k.toInsertJson()).toList();
    await _c.from('sprach_karten').insert(zeilen);
    return zeilen.length;
  }
```

- [ ] **Schritt 3: Fake ergänzen**

In `fake_spracheingabe_gateway.dart`, oben `import 'dart:typed_data';` und
`import 'package:bienen_app/features/spracheingabe/domain/startstapel.dart';` ergänzen, in der
Klasse:

```dart
  /// Was der Fake als Transkript zurueckgibt. Tests setzen es passend zur
  /// erwarteten Karte.
  String antwort = '';
  int transkriptionen = 0;

  @override
  Future<String> transkribieren({
    required Uint8List bytes,
    required String dateiname,
    required String anbieter,
    required bool mitWortliste,
  }) async {
    transkriptionen++;
    return antwort;
  }

  @override
  Future<int> startstapelSicherstellen() async {
    if (karten.any((k) => k.herkunft == 'start')) return 0;
    for (final k in startstapel) {
      await karteAnlegen(k);
    }
    return startstapel.length;
  }
```

- [ ] **Schritt 4: Tests ergänzen**

An `test/spracheingabe/fake_gateway_test.dart` anhängen (innerhalb von `main`):

```dart
  test('der Startstapel wird nur einmal angelegt', () async {
    final g = FakeSpracheingabeGateway();
    final erst = await g.startstapelSicherstellen();
    expect(erst, 30);
    final zweit = await g.startstapelSicherstellen();
    expect(zweit, 0, reason: 'ein zweiter Aufruf darf keine Dubletten erzeugen');
    expect((await g.kartenLaden()).length, 30);
  });
```

- [ ] **Schritt 5: Prüfen und committen**

Run: `flutter analyze lib test` → `No issues found!`
Run: `flutter test test/spracheingabe/` → alle grün

```bash
git add lib/features/spracheingabe/data test/spracheingabe/fake_gateway_test.dart
git commit -m "Spracheingabe: Gateway kann transkribieren und den Startstapel anlegen"
```

---

## Task 6: Zustand (Riverpod)

**Dateien:**
- Erstellen: `lib/features/spracheingabe/presentation/providers/spracheingabe_provider.dart`

Muster aus `benachrichtigungen_provider.dart`: ein `Provider` für das Gateway, ein
`AsyncNotifierProvider` für den Zustand, nach jedem Schreiben `ref.invalidateSelf()`.

- [ ] **Schritt 1: Datei anlegen**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bienen_app/core/config/supabase_config.dart';
import 'package:bienen_app/features/auth/presentation/auth_providers.dart';
import 'package:bienen_app/features/spracheingabe/data/sprach_aufnahme.dart';
import 'package:bienen_app/features/spracheingabe/data/sprach_speicher.dart';
import 'package:bienen_app/features/spracheingabe/data/spracheingabe_gateway.dart';
import 'package:bienen_app/features/spracheingabe/domain/fachwort_treffer.dart';
import 'package:bienen_app/features/spracheingabe/domain/kartenwahl.dart';
import 'package:bienen_app/features/spracheingabe/domain/sprach_modelle.dart';
import 'package:bienen_app/features/spracheingabe/domain/verhoerer_diff.dart';
import 'package:bienen_app/features/spracheingabe/domain/wortfehlerrate.dart';

final spracheingabeGatewayProvider = Provider<SpracheingabeGateway>(
    (ref) => SupabaseSpracheingabeGateway(SupabaseConfig.client));

final sprachSpeicherProvider =
    Provider<SprachSpeicher>((ref) => SprachSpeicher(SupabaseConfig.client));

/// Live-Anbieter des Drills. Vorgabe bis zum Entscheid D-100: ElevenLabs, als
/// einziger der drei synchron und ohne Warteschlange.
final liveAnbieterProvider = Provider<String>((ref) => 'elevenlabs');

/// Was der Drill gerade anzeigt.
class DrillZustand {
  final List<SprachKarte> stapel;
  final SprachKarte? karte;
  final Map<String, Kartenbilanz> bilanz;
  final DrillErgebnis? letztes;
  final bool laeuft;

  const DrillZustand({
    this.stapel = const [],
    this.karte,
    this.bilanz = const {},
    this.letztes,
    this.laeuft = false,
  });

  DrillZustand copyWith({
    List<SprachKarte>? stapel,
    SprachKarte? karte,
    Map<String, Kartenbilanz>? bilanz,
    DrillErgebnis? letztes,
    bool? laeuft,
    bool letztesLoeschen = false,
  }) =>
      DrillZustand(
        stapel: stapel ?? this.stapel,
        karte: karte ?? this.karte,
        bilanz: bilanz ?? this.bilanz,
        letztes: letztesLoeschen ? null : (letztes ?? this.letztes),
        laeuft: laeuft ?? this.laeuft,
      );
}

/// Das Ergebnis einer gesprochenen Karte.
class DrillErgebnis {
  final String sollText;
  final String transkript;
  final bool getroffen;
  final double? wortfehler;

  const DrillErgebnis({
    required this.sollText,
    required this.transkript,
    required this.getroffen,
    this.wortfehler,
  });
}

final drillProvider =
    AsyncNotifierProvider<DrillNotifier, DrillZustand>(DrillNotifier.new);

class DrillNotifier extends AsyncNotifier<DrillZustand> {
  SprachAufnahme? _aufnahme;

  SpracheingabeGateway get _gw => ref.read(spracheingabeGatewayProvider);
  SprachSpeicher get _speicher => ref.read(sprachSpeicherProvider);

  @override
  Future<DrillZustand> build() async {
    await _gw.startstapelSicherstellen();
    final karten = await _gw.kartenLaden();
    final zustand = DrillZustand(stapel: karten);
    return zustand.copyWith(
        karte: naechsteKarte(karten: karten, bilanz: const {}));
  }

  Future<void> aufnahmeStarten() async {
    final jetzt = state.valueOrNull;
    if (jetzt == null || jetzt.laeuft) return;
    _aufnahme = SprachAufnahme();
    await _aufnahme!.starten();
    state = AsyncData(jetzt.copyWith(laeuft: true, letztesLoeschen: true));
  }

  /// Beendet die Aufnahme, legt sie ab, laesst sie erkennen und bewertet.
  ///
  /// Reihenfolge mit Absicht: **zuerst ablegen, dann erkennen.** Faellt die
  /// Erkennung aus, ist die Aufnahme trotzdem im Bestand und beim naechsten
  /// Vollvergleich auswertbar — der ganze Sinn davon, den Ton zu behalten.
  Future<void> aufnahmeBeenden() async {
    final jetzt = state.valueOrNull;
    final karte = jetzt?.karte;
    final aufnahme = _aufnahme;
    if (jetzt == null || karte == null || aufnahme == null) return;

    final ton = await aufnahme.beenden();
    _aufnahme = null;
    state = AsyncData(jetzt.copyWith(laeuft: false));

    final betriebId = ref.read(currentBetriebIdProvider);
    final personId = ref.read(authControllerProvider).session?.userId;
    if (betriebId == null || personId == null) {
      throw Exception('Nicht angemeldet oder kein Betrieb gewählt.');
    }

    final kennung = DateTime.now().microsecondsSinceEpoch.toString();
    final pfad = await _speicher.hochladen(
      betriebId: betriebId,
      personId: personId,
      bytes: ton.bytes,
      mime: ton.mime,
      kennung: kennung,
    );

    final probe = await _gw.probeAnlegen(SprachProbe(
      id: '',
      personId: personId,
      karteId: karte.id,
      sollText: karte.sollText,
      modus: ProbenModus.drill,
      storagePath: pfad,
      dauerMs: ton.dauerMs,
      groesseB: ton.bytes.lengthInBytes,
      mime: ton.mime,
    ));

    final anbieter = ref.read(liveAnbieterProvider);
    final transkript = await _gw.transkribieren(
      bytes: ton.bytes,
      dateiname: pfad.split('/').last,
      anbieter: anbieter,
      mitWortliste: true,
    );

    final treffer = zaehleTreffer(transkript: transkript, erwartet: karte.zuZaehlen);
    final wer = karte.art == KartenArt.satz
        ? wortfehlerrate(soll: karte.sollText, ist: transkript)
        : null;

    await _gw.ergebnisAnlegen(SprachErgebnis(
      id: '',
      probeId: probe.id,
      anbieter: anbieter,
      mitWortliste: true,
      transkript: transkript,
      trefferQuote: treffer.quote,
      wortfehlerrate: wer,
    ));

    // Danebengegangene Begriffe als Verhoerer melden. Erst der zweite gleiche
    // macht daraus eine Regel (lernschwelle.dart) — ein einzelner Fehltreffer
    // waere Zufall.
    if (treffer.fehlend.isNotEmpty) {
      for (final paar in verhoererAus(erkannt: transkript, korrigiert: karte.sollText)) {
        await _gw.verhoererMelden(
          betriebId: betriebId,
          personId: personId,
          falsch: paar.falsch,
          richtig: paar.richtig,
          quelle: 'training',
        );
      }
    }

    final bilanz = Map<String, Kartenbilanz>.from(jetzt.bilanz);
    final alt = bilanz[karte.sollText];
    final getroffen = treffer.fehlend.isEmpty;
    bilanz[karte.sollText] = Kartenbilanz(
      versuche: (alt?.versuche ?? 0) + 1,
      treffer: (alt?.treffer ?? 0) + (getroffen ? 1 : 0),
    );

    state = AsyncData(jetzt.copyWith(
      laeuft: false,
      bilanz: bilanz,
      letztes: DrillErgebnis(
        sollText: karte.sollText,
        transkript: transkript,
        getroffen: getroffen,
        wortfehler: wer,
      ),
    ));
  }

  void naechste() {
    final jetzt = state.valueOrNull;
    if (jetzt == null) return;
    state = AsyncData(jetzt.copyWith(
      karte: naechsteKarte(
        karten: jetzt.stapel,
        bilanz: jetzt.bilanz,
        zuletzt: jetzt.karte?.sollText,
      ),
      letztesLoeschen: true,
    ));
  }

  void abbrechen() {
    _aufnahme?.abbrechen();
    _aufnahme = null;
    final jetzt = state.valueOrNull;
    if (jetzt != null) state = AsyncData(jetzt.copyWith(laeuft: false));
  }
}
```

- [ ] **Schritt 2: Prüfen und committen**

Run: `flutter analyze lib test` → `No issues found!`

```bash
git add lib/features/spracheingabe/presentation/providers/spracheingabe_provider.dart
git commit -m "Spracheingabe: Drill-Zustand, ablegen vor erkennen"
```

---

## Task 7: Der Screen

**Dateien:**
- Erstellen: `lib/features/spracheingabe/presentation/pages/spracheingabe_page.dart`

Drei Segmente nach dem Muster von `material_page.dart`. **Nur „Üben" ist in diesem Bauabschnitt
gefüllt**; die beiden anderen zeigen ehrlich, dass sie noch kommen — eine leere Fläche ohne
Erklärung sieht aus wie ein Fehler.

- [ ] **Schritt 1: Datei anlegen**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bienen_app/core/theme/app_tokens.dart';
import 'package:bienen_app/features/spracheingabe/presentation/providers/spracheingabe_provider.dart';
import 'package:bienen_app/shared/widgets/app_card.dart';
import 'package:bienen_app/shared/widgets/empty_state.dart';

class SpracheingabePage extends ConsumerWidget {
  const SpracheingabePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Spracheingabe'),
          bottom: const TabBar(
            labelColor: BeeTokens.textPrimaer,
            unselectedLabelColor: BeeTokens.textGedaempft,
            indicatorColor: BeeTokens.honig,
            tabs: [
              Tab(text: 'Üben'),
              Tab(text: 'Frei sprechen'),
              Tab(text: 'Auswertung'),
            ],
          ),
        ),
        body: const TabBarView(children: [
          _UebenAnsicht(),
          EmptyState(
            icon: Icons.mic_none,
            titel: 'Frei sprechen kommt als Nächstes',
            text: 'Hier wirst du reden können wie am Volk und danach '
                'korrigieren, was die Erkennung verhört hat.',
          ),
          EmptyState(
            icon: Icons.insights_outlined,
            titel: 'Die Auswertung kommt zuletzt',
            text: 'Hier stehen später der Bestand, der Vergleich aller '
                'Anbieter und die gelernten Regeln.',
          ),
        ]),
      ),
    );
  }
}

class _UebenAnsicht extends ConsumerWidget {
  const _UebenAnsicht();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final zustand = ref.watch(drillProvider);

    return zustand.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => EmptyState(
        icon: Icons.error_outline,
        titel: 'Der Übungsstapel liess sich nicht laden',
        text: '$e',
      ),
      data: (d) {
        final karte = d.karte;
        if (karte == null) {
          return const EmptyState(
            icon: Icons.inbox_outlined,
            titel: 'Keine Übungskarten',
            text: 'Der Startstapel wird beim ersten Öffnen angelegt. '
                'Erscheint hier nichts, fehlt die Schreibberechtigung.',
          );
        }
        final ergebnis = d.letztes;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(BeeTokens.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppCard(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: BeeTokens.lg),
                  child: Text(
                    karte.sollText,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: BeeTokens.textPrimaer,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: BeeTokens.md),
              SizedBox(
                height: 64,
                child: FilledButton.icon(
                  key: const Key('drill_aufnahme'),
                  onPressed: () async {
                    final n = ref.read(drillProvider.notifier);
                    if (d.laeuft) {
                      await n.aufnahmeBeenden();
                    } else {
                      await n.aufnahmeStarten();
                    }
                  },
                  icon: Icon(d.laeuft ? Icons.stop : Icons.mic),
                  label: Text(d.laeuft ? 'Fertig' : 'Sprechen'),
                  style: FilledButton.styleFrom(
                    backgroundColor: d.laeuft ? BeeTokens.gefahrText : BeeTokens.honig,
                  ),
                ),
              ),
              if (ergebnis != null) ...[
                const SizedBox(height: BeeTokens.md),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Icon(
                          ergebnis.getroffen ? Icons.check_circle : Icons.cancel,
                          color: ergebnis.getroffen ? BeeTokens.erfolgText : BeeTokens.gefahrText,
                        ),
                        const SizedBox(width: BeeTokens.sm),
                        Text(
                          ergebnis.getroffen ? 'Verstanden' : 'Nicht verstanden',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ]),
                      const SizedBox(height: BeeTokens.sm),
                      Text('Erkannt: „${ergebnis.transkript}"',
                          style: const TextStyle(color: BeeTokens.textSekundaer)),
                      if (ergebnis.wortfehler != null)
                        Text(
                          'Wortfehlerrate: ${(ergebnis.wortfehler! * 100).round()} %',
                          style: const TextStyle(color: BeeTokens.textSekundaer),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: BeeTokens.sm),
                OutlinedButton(
                  key: const Key('drill_naechste'),
                  onPressed: () => ref.read(drillProvider.notifier).naechste(),
                  child: const Text('Nächste Karte'),
                ),
              ],
              const SizedBox(height: BeeTokens.lg),
              Text(
                '${d.stapel.length} Karten im Stapel · geübt: ${d.bilanz.length}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: BeeTokens.textGedaempft),
              ),
            ],
          ),
        );
      },
    );
  }
}
```

**Die verwendeten Signaturen sind nachgeschlagen, nicht vermutet:**
`EmptyState({icon, titel, text?, aktion?})` · `AppCard({child, padding, onTap})` ·
`AppListTile({leading, statusFarbe, titel, untertitel, trailing, onTap})`.
Farben: **`BeeTokens.erfolgText` und `gefahrText`** — ein `BeeTokens.erfolg`/`.gefahr` gibt es
**nicht**, dort heissen die Paare `…Flaeche`/`…Text`. Abstände `sm/md/lg` existieren.

- [ ] **Schritt 2: Prüfen**

Run: `flutter analyze lib test`
Erwartet: `No issues found!`

- [ ] **Schritt 3: Committen**

```bash
git add lib/features/spracheingabe/presentation/pages/spracheingabe_page.dart
git commit -m "Spracheingabe: Screen mit drei Segmenten, Ueben gefuellt"
```

---

## Task 8: Route und Einstieg

**Dateien:**
- Ändern: `lib/core/router/app_router.dart`
- Ändern: `lib/features/auth/presentation/konto_page.dart`

- [ ] **Schritt 1: Route ergänzen**

Import oben, dann innerhalb der `routes`-Liste der `ShellRoute` — direkt neben der bestehenden
`/benachrichtigungen`-Route:

```dart
        GoRoute(
          path: '/spracheingabe',
          builder: (c, s) => const SpracheingabePage(),
        ),
```

Der Auth-Schutz kommt automatisch: Alles innerhalb der `ShellRoute`, was nicht in `_offeneRouten`
steht, liegt hinter dem Login.

- [ ] **Schritt 2: Einstieg unter „Konto" ergänzen**

Nach der bestehenden Benachrichtigungs-Kachel:

```dart
            AppCard(
              padding: EdgeInsets.zero,
              child: AppListTile(
                key: const Key('konto_spracheingabe'),
                leading: const Icon(Icons.record_voice_over_outlined,
                    color: BeeTokens.textSekundaer),
                titel: 'Spracheingabe',
                untertitel: 'Fachwörter üben, damit die Erkennung dich versteht',
                onTap: () => context.go('/spracheingabe'),
              ),
            ),
```

**Warum unter „Konto":** Der Trainingsbestand ist personenbezogen — Aufnahmen, Messwerte und
gelernte Regeln gehören einer Stimme, nicht dem Betrieb (T02–T04). Daniel und Lorena üben getrennt.

- [ ] **Schritt 3: Prüfen**

Run: `flutter analyze lib test` → `No issues found!`
Run: `flutter test` → alle grün

- [ ] **Schritt 4: Committen**

```bash
git add lib/core/router/app_router.dart lib/features/auth/presentation/konto_page.dart
git commit -m "Spracheingabe: Route und Einstieg unter Konto"
```

---

## Task 9: Ausliefern und im Feld prüfen

- [ ] **Schritt 1: Version anheben**

```bash
sed -i 's/^version: 1.74.0+108/version: 1.75.0+109/' pubspec.yaml
```

- [ ] **Schritt 2: Gates**

Run: `flutter analyze lib test` → `No issues found!`
Run: `flutter test` → alle grün
Run: `flutter build web --release` → `√ Built build\web`

- [ ] **Schritt 3: Ausliefern**

```bash
bash deploy.sh
```

Erwartet: `✓ Live bestaetigt: v1.75.0 ist publiziert.`

- [ ] **Schritt 4: Committen**

```bash
git add pubspec.yaml && git commit -m "Release v1.75.0: Spracheingabe, Segment Ueben"
```

- [ ] **Schritt 5: Was Daniel prüfen muss** (nicht automatisierbar)

1. **Konto → Spracheingabe** öffnen. Der Startstapel muss beim ersten Öffnen erscheinen (30 Karten).
2. Eine Karte sprechen. Das Mikrofon muss **nach der Aufnahme wieder ausgehen** — die Anzeige des
   Browsers darf nicht weiterleuchten.
3. Ergebnis erscheint innerhalb weniger Sekunden, grün oder rot, mit dem erkannten Text.
4. Zweimal dasselbe Wort falsch: Nach dem zweiten Mal muss in `sprach_korrekturen` eine Zeile mit
   `aktiv = true` stehen (per SQL prüfbar).
5. **Erwarteter Fehlerfall:** Verweigert man die Mikrofon-Erlaubnis, muss eine verständliche Meldung
   kommen — kein stiller Stillstand. Genau das war der Fehler von heute Nachmittag (D-102).

---

## Was dieser Abschnitt bewusst nicht tut

- **Kein „Frei sprechen"** und **keine Auswertung** — Bauabschnitte 3 und 4.
- **Keine Kostenanzeige**: Sie gehört zum Vollvergleich, der hier nicht läuft.
- **Kein Abhören der Aufnahme im Screen.** `SprachSpeicher.signierteUrl` ist vorbereitet, aber die
  Wiedergabe kommt mit der Auswertung.
- **Die drei zurückgestellten Befunde aus Bauabschnitt 1** bleiben offen: Read-Modify-Write beim
  Hochzählen, mögliche Doppelanlage des Startstapels bei gleichzeitigem Öffnen auf zwei Geräten,
  `check (falsch = lower(falsch))`. Für die ersten beiden ist die Lösung dieselbe — eine RPC mit
  atomarem `on conflict do update`. Sie sind hier **nicht** eingeplant, weil sie eine fünfte
  Migration brauchen und dieser Abschnitt ohne Migration auskommen soll.
