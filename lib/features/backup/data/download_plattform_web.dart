import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

/// Web-Ziel: Blob → Objekt-URL → unsichtbarer Anker-Klick → URL wieder freigeben.
/// Bewusst nur `dart:js_interop` (+ `_unsafe`) wie beim Sprach-Erkenner — das
/// Projekt nutzt kein `package:web` und kein `dart:html`.

@JS('Blob')
external JSFunction get _blobKonstruktor;

@JS('URL')
external JSObject get _url;

@JS('document')
external JSObject get _document;

void downloadImBrowser(Uint8List bytes, String dateiname) {
  final teile = <JSAny>[bytes.toJS].toJS;
  final blob = _blobKonstruktor.callAsConstructor<JSObject>(teile);
  final objektUrl =
      (_url.callMethod<JSString>('createObjectURL'.toJS, blob)).toDart;
  final anker =
      _document.callMethod<JSObject>('createElement'.toJS, 'a'.toJS);
  anker.setProperty('href'.toJS, objektUrl.toJS);
  anker.setProperty('download'.toJS, dateiname.toJS);
  anker.callMethod<JSAny?>('click'.toJS);
  _url.callMethod<JSAny?>('revokeObjectURL'.toJS, objektUrl.toJS);
}
