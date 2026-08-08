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
