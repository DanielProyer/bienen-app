import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'package:bienen_app/features/durchsicht/sprache/domain/ergebnis_auswahl.dart';
import 'package:bienen_app/features/durchsicht/sprache/domain/sprach_neustart.dart';
import 'package:bienen_app/features/durchsicht/sprache/domain/sprache_erkenner.dart';

@JS('SpeechRecognition')
external JSFunction? get _ctorStd;
@JS('webkitSpeechRecognition')
external JSFunction? get _ctorWebkit;

extension type _Recognition._(JSObject o) implements JSObject {
  external set continuous(bool v);
  external set interimResults(bool v);
  external set lang(String v);
  external set onresult(JSFunction? f);
  external set onerror(JSFunction? f);
  external set onend(JSFunction? f);
  external void start();
  external void stop();
  external void abort();
}

/// Spracherkennung über die Web Speech API.
///
/// Der Dauer-Modus startet die Erkennung nach jedem `onend` neu, damit man am
/// Bienenstand durchsprechen kann. Genau daran hing der Fehler vom 2026-07-27
/// („Mikro kommt in einen Loop, der nicht mehr aufhört"). Vier Ursachen wirkten
/// zusammen, alle vier sind hier behandelt:
///
/// 1. **Verwaiste Erkenner.** `starten()` baute jedes Mal ein neues
///    Recognition-Objekt, ohne das alte zu beenden. Beim Mikro-Wechsel im
///    Wizard (Durchsicht → Wetter) liefen mehrere parallel und starteten sich
///    gegenseitig endlos neu. → [_beende] räumt zuerst auf, und eine
///    [_generation] sorgt dafür, dass sich nur der jeweils jüngste Erkenner
///    wieder starten darf.
/// 2. **Fatale Fehler wurden ignoriert.** Bei verweigertem Mikrofon endete die
///    Erkennung sofort und wurde blind neu gestartet — mit voller Drehzahl.
///    → [istFatalerFehler] beendet den Dauer-Modus.
/// 3. **Kein Bremsklotz.** `rec.start()` stand ohne Pause direkt in `onend`.
///    → [NeustartBremse] begrenzt die Neustarts in einem Zeitfenster, danach
///    Fehlerstatus statt Endlosschleife.
/// 4. **Handler blieben hängen.** Beim Stoppen wurden `onend`/`onresult` nicht
///    abgeklemmt, ein spätes Ereignis konnte alles wieder anwerfen.
///
/// Dazu kam am 2026-07-28 ein fünfter, davon unabhängiger Fehler:
///
/// 5. **Fertige Satzstücke wurden mehrfach ausgeliefert.** `onresult` lief über
///    das ganze `results`-Array, das aber die **gesamte Sitzung** enthält, nicht
///    nur das Neue. Jedes weitere Ereignis schickte damit alle früheren
///    Endergebnisse noch einmal — und weil die Formularfelder anhängen, wurde
///    aus „schönes Wetter" ein „schönes schönes schönes wetter".
///    → [ErgebnisAuswahl] gibt nur heraus, was noch nicht geliefert wurde.
///
/// 6. **Der Filter verschluckte den zweiten Satz.** Der erste Anlauf gegen (5)
///    verglich Ergebnis-Indizes und musste dafür den Neustart-Zeitpunkt genau
///    treffen. Traf er ihn nicht, galt der erste Satz des neuen Laufs als
///    „schon geliefert" — gemeldet als „nur schönes wird übernommen".
///    → [ErgebnisAuswahl] vergleicht jetzt Text statt Indizes und braucht
///    keine Annahme über die Zählweise des Browsers.
///
/// 7. **Kurze Kommandos lösten den Bremsklotz aus.** Wer ein Kommando spricht
///    und dann schweigt, erzeugt regelmässig `no-speech` und einen Neustart.
///    Bei vier erlaubten Runden in zehn Sekunden landete man so im
///    Fehlerzustand, obwohl alles normal lief. → Fenster erweitert, und ein
///    Lauf gilt schon nach drei Sekunden als geglückt.
class WebSpracheErkenner implements SpracheErkenner {
  final _erg = StreamController<SprachErgebnis>.broadcast();
  final _st = StreamController<ErkennerStatus>.broadcast();
  final _bremse = NeustartBremse();
  final _auswahl = ErgebnisAuswahl();

  _Recognition? _rec;
  bool _aktiv = false;
  int _generation = 0;
  Timer? _neustartTimer;
  DateTime? _laufBegonnen;
  bool _dauermodus = true;
  late final bool _verfuegbar = (_ctorStd ?? _ctorWebkit) != null;

  @override
  bool get verfuegbar => _verfuegbar;
  @override
  Stream<SprachErgebnis> get ergebnisse => _erg.stream;
  @override
  Stream<ErkennerStatus> get status => _st.stream;

  /// Klemmt einen Erkenner vollständig ab und bricht ihn ab.
  ///
  /// Die Handler MÜSSEN vor `abort()` entfernt werden: `abort()` löst selbst
  /// noch ein `onend` aus, und ein daran hängender Neustart wäre genau der
  /// Loop, den wir abstellen wollen.
  void _beende(_Recognition? rec) {
    if (rec == null) return;
    rec.onend = null;
    rec.onresult = null;
    rec.onerror = null;
    try {
      rec.abort();
    } catch (_) {
      // Ein bereits beendeter Erkenner wirft — das ist hier folgenlos.
    }
  }

  @override
  Future<void> starten({String sprache = 'de-CH', bool kontinuierlich = true}) async {
    if (!_verfuegbar) {
      _st.add(ErkennerStatus.fehler);
      return;
    }

    // Immer erst aufräumen: Ein zweiter Aufruf (anderes Mikro im Wizard) darf
    // keinen zweiten Erkenner neben dem ersten laufen lassen.
    _neustartTimer?.cancel();
    _beende(_rec);
    _rec = null;
    _bremse.zuruecksetzen(); // bewusster Start durch den Nutzer
    _auswahl.zuruecksetzen();

    final meine = ++_generation;
    final ctor = _ctorStd ?? _ctorWebkit;
    final rec = ctor!.callAsConstructor<_Recognition>();
    _dauermodus = kontinuierlich;
    rec.continuous = kontinuierlich;
    rec.interimResults = true;
    rec.lang = sprache;

    rec.onresult = ((JSObject ev) {
      if (meine != _generation) return; // Nachzügler eines alten Erkenners
      final results = ev.getProperty('results'.toJS) as JSObject;
      final len = (results.getProperty('length'.toJS) as JSNumber).toDartInt;

      // `results` enthält die GANZE Sitzung, nicht nur das Neue. Was davon
      // noch nicht ausgeliefert wurde, entscheidet [ErgebnisAuswahl] —
      // sonst wird jedes fertige Satzstück bei jedem weiteren Ereignis
      // erneut angehängt („schönes schönes schönes wetter").
      final liste = <({String text, bool endgueltig})>[];
      for (var i = 0; i < len; i++) {
        final res = results.getProperty(i.toString().toJS) as JSObject;
        final isFinal = (res.getProperty('isFinal'.toJS) as JSBoolean).toDart;
        final alt = res.getProperty('0'.toJS) as JSObject;
        final text = (alt.getProperty('transcript'.toJS) as JSString).toDart;
        liste.add((text: text, endgueltig: isFinal));
      }
      // Bewusst ohne `event.resultIndex`: Der Index ist nur zuverlässig, wenn
      // man den Neustart-Zeitpunkt des Browsers genau trifft. Der Vergleich
      // über den zusammengesetzten Text kommt ohne diese Annahme aus.
      final zuwachs = _auswahl.verarbeite(liste);
      if (zuwachs.interim.isNotEmpty) {
        _erg.add(SprachErgebnis(zuwachs.interim, endgueltig: false));
      }
      final neu = zuwachs.neuerEndtext;
      if (neu != null) _erg.add(SprachErgebnis(neu, endgueltig: true));
    }).toJS;

    rec.onerror = ((JSObject ev) {
      if (meine != _generation) return; // Nachzügler eines alten Erkenners
      final code = (ev.getProperty('error'.toJS) as JSString?)?.toDart ?? '';
      if (istFatalerFehler(code)) {
        // Kein Neustart: ohne Freigabe oder Aufnahmegerät wird es nie gehen.
        _aktiv = false;
        _st.add(ErkennerStatus.fehler);
        return;
      }
      if (code != 'no-speech' && code != 'aborted') _st.add(ErkennerStatus.fehler);
    }).toJS;

    rec.onend = ((JSObject _) {
      if (meine != _generation) return; // alter Erkenner — nicht wiederbeleben
      if (!_aktiv) {
        _st.add(ErkennerStatus.idle);
        return;
      }
      // Einzelsatz-Modus (Kommando): Nach dem Satz ist Schluss — kein
      // Neustart. Genau daraus entstand der Eindruck, das Kommando-Mikro
      // laufe in einer Schleife.
      if (!_dauermodus) {
        _aktiv = false;
        _st.add(ErkennerStatus.idle);
        return;
      }
      // Lief die Erkennung ein paar Sekunden, war es eine normale Sprechpause
      // und kein Absturz — dann den Zähler entlasten. Drei Sekunden reichen:
      // Ein kurzes Kommando plus Stille kommt oft nicht über fünf hinaus.
      final begonnen = _laufBegonnen;
      if (begonnen != null &&
          DateTime.now().difference(begonnen) > const Duration(seconds: 3)) {
        _bremse.erfolgreichGelaufen();
      }
      if (!_bremse.darfNeuStarten(DateTime.now())) {
        _aktiv = false;
        _st.add(ErkennerStatus.fehler);
        return;
      }
      // Kurz warten statt sofort neu anwerfen: Ein unmittelbarer Neustart im
      // onend-Handler ist genau die Kette, die das Mikro nicht zur Ruhe kommen
      // liess.
      _neustartTimer?.cancel();
      _neustartTimer = Timer(const Duration(milliseconds: 250), () {
        if (!_aktiv || meine != _generation) return;
        try {
          _laufBegonnen = DateTime.now();
          rec.start();
        } catch (_) {
          _aktiv = false;
          _st.add(ErkennerStatus.fehler);
        }
      });
    }).toJS;

    _rec = rec;
    _aktiv = true;
    try {
      _laufBegonnen = DateTime.now();
      rec.start();
      _st.add(ErkennerStatus.hoert);
    } catch (_) {
      // InvalidStateError, wenn schon eine Erkennung läuft.
      _aktiv = false;
      _st.add(ErkennerStatus.fehler);
    }
  }

  @override
  Future<void> stoppen() async {
    _aktiv = false;
    _neustartTimer?.cancel();
    _generation++; // alles Bisherige gilt als veraltet
    _beende(_rec);
    _rec = null;
    _st.add(ErkennerStatus.idle);
  }

  @override
  void dispose() {
    _aktiv = false;
    _neustartTimer?.cancel();
    _generation++;
    _beende(_rec);
    _rec = null;
    _erg.close();
    _st.close();
  }
}
