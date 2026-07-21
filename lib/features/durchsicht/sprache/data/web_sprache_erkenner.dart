import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'package:bienen_app/features/durchsicht/sprache/domain/sprache_erkenner.dart';

@JS('SpeechRecognition')
external JSFunction? get _ctorStd;
@JS('webkitSpeechRecognition')
external JSFunction? get _ctorWebkit;

extension type _Recognition._(JSObject o) implements JSObject {
  external set continuous(bool v);
  external set interimResults(bool v);
  external set lang(String v);
  external set onresult(JSFunction f);
  external set onerror(JSFunction f);
  external set onend(JSFunction f);
  external void start();
  external void stop();
  external void abort();
}

class WebSpracheErkenner implements SpracheErkenner {
  final _erg = StreamController<SprachErgebnis>.broadcast();
  final _st = StreamController<ErkennerStatus>.broadcast();
  _Recognition? _rec;
  bool _aktiv = false;
  late final bool _verfuegbar = (_ctorStd ?? _ctorWebkit) != null;

  @override
  bool get verfuegbar => _verfuegbar;
  @override
  Stream<SprachErgebnis> get ergebnisse => _erg.stream;
  @override
  Stream<ErkennerStatus> get status => _st.stream;

  @override
  Future<void> starten({String sprache = 'de-CH', bool kontinuierlich = true}) async {
    if (!_verfuegbar) { _st.add(ErkennerStatus.fehler); return; }
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
      final code = (ev.getProperty('error'.toJS) as JSString?)?.toDart ?? '';
      if (code != 'no-speech' && code != 'aborted') _st.add(ErkennerStatus.fehler);
    }).toJS;
    rec.onend = ((JSObject _) {
      if (_aktiv) { rec.start(); } else { _st.add(ErkennerStatus.idle); }  // nahtloser Dauer-Modus
    }).toJS;
    _rec = rec;
    _aktiv = true;
    rec.start();
    _st.add(ErkennerStatus.hoert);
  }

  @override
  Future<void> stoppen() async {
    _aktiv = false;
    _rec?.stop();
    _st.add(ErkennerStatus.idle);
  }

  @override
  void dispose() { _aktiv = false; _rec?.abort(); _erg.close(); _st.close(); }
}
