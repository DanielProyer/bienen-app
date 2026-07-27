import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
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
///    → [NeustartBremse] begrenzt auf vier Neustarts in zehn Sekunden, danach
///    Fehlerstatus statt Endlosschleife.
/// 4. **Handler blieben hängen.** Beim Stoppen wurden `onend`/`onresult` nicht
///    abgeklemmt, ein spätes Ereignis konnte alles wieder anwerfen.
class WebSpracheErkenner implements SpracheErkenner {
  final _erg = StreamController<SprachErgebnis>.broadcast();
  final _st = StreamController<ErkennerStatus>.broadcast();
  final _bremse = NeustartBremse();

  _Recognition? _rec;
  bool _aktiv = false;
  int _generation = 0;
  Timer? _neustartTimer;
  DateTime? _laufBegonnen;
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

    final meine = ++_generation;
    final ctor = _ctorStd ?? _ctorWebkit;
    final rec = ctor!.callAsConstructor<_Recognition>();
    rec.continuous = kontinuierlich;
    rec.interimResults = true;
    rec.lang = sprache;

    rec.onresult = ((JSObject ev) {
      final results = ev.getProperty('results'.toJS) as JSObject;
      final len = (results.getProperty('length'.toJS) as JSNumber).toDartInt;
      for (var i = 0; i < len; i++) {
        final res = results.getProperty(i.toString().toJS) as JSObject;
        final isFinal = (res.getProperty('isFinal'.toJS) as JSBoolean).toDart;
        final alt = res.getProperty('0'.toJS) as JSObject;
        final text = (alt.getProperty('transcript'.toJS) as JSString).toDart;
        _erg.add(SprachErgebnis(text, endgueltig: isFinal));
      }
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
      // Lief die Erkennung eine Weile, war es eine normale Sprechpause und
      // kein Absturz — dann den Zähler entlasten.
      final begonnen = _laufBegonnen;
      if (begonnen != null &&
          DateTime.now().difference(begonnen) > const Duration(seconds: 5)) {
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
