import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

// Minimale eigene Interop-Kapsel (kein `package:web` — das Paket ist nicht in
// pubspec.yaml und soll es nicht werden). Muster wie
// features/durchsicht/sprache/data/web_sprache_erkenner.dart.

@JS('Blob')
extension type _Blob._(JSObject _) implements JSObject {
  external factory _Blob(JSArray<JSAny> teile, _BlobOptionen optionen);
}

extension type _BlobOptionen._(JSObject _) implements JSObject {
  external factory _BlobOptionen({String type});
}

@JS('URL')
extension type _Url._(JSObject _) implements JSObject {
  external static String createObjectURL(JSObject objekt);
  external static void revokeObjectURL(String url);
}

@JS('Image')
extension type _Bild._(JSObject _) implements JSObject {
  external factory _Bild();
  external set onload(JSFunction f);
  external set onerror(JSFunction f);
  external set src(String v);
  external int get naturalWidth;
  external int get naturalHeight;
}

@JS('document')
external _Dokument get _document;

extension type _Dokument._(JSObject _) implements JSObject {
  external _Leinwand createElement(String tag);
}

extension type _Leinwand._(JSObject _) implements JSObject {
  external set width(int v);
  external set height(int v);
  external _Kontext? getContext(String art);
  external String toDataURL(String typ, num qualitaet);
}

extension type _Kontext._(JSObject _) implements JSObject {
  external void drawImage(JSObject bild, num dx, num dy, num dw, num dh);
}

/// Canvas-Re-Encode: laedt die Bytes als Blob-URL in ein Image, zeichnet es in
/// ein Canvas und liest es als JPEG zurueck. Metadaten existieren danach nicht
/// mehr. Die EXIF-Drehung wenden Browser beim Zeichnen selbst an, das Bild
/// kippt also nicht.
Future<Uint8List> ohneMetadaten(
  Uint8List bytes, {
  int maxBreite = 2000,
  double qualitaet = 0.85,
}) async {
  final blob = _Blob(
    <JSAny>[bytes.toJS].toJS,
    _BlobOptionen(type: 'image/jpeg'),
  );
  final blobUrl = _Url.createObjectURL(blob);
  try {
    final bild = _Bild();
    final fertig = Completer<void>();
    bild.onload = ((JSAny? _) {
      if (!fertig.isCompleted) fertig.complete();
    }).toJS;
    bild.onerror = ((JSAny? _) {
      if (!fertig.isCompleted) {
        fertig.completeError(StateError('Bild konnte nicht dekodiert werden'));
      }
    }).toJS;
    bild.src = blobUrl;
    await fertig.future;

    final breiteOrig = bild.naturalWidth;
    final hoeheOrig = bild.naturalHeight;
    if (breiteOrig == 0 || hoeheOrig == 0) {
      throw StateError('Bild hat keine Groesse');
    }
    final skala = breiteOrig > maxBreite ? maxBreite / breiteOrig : 1.0;
    final breite = (breiteOrig * skala).round();
    final hoehe = (hoeheOrig * skala).round();

    final leinwand = _document.createElement('canvas');
    leinwand.width = breite;
    leinwand.height = hoehe;
    final ctx = leinwand.getContext('2d');
    if (ctx == null) throw StateError('Canvas-Kontext nicht verfuegbar');
    ctx.drawImage(bild, 0, 0, breite, hoehe);

    // toDataURL ist synchron und in allen Ziel-Browsern verfuegbar.
    final dataUrl = leinwand.toDataURL('image/jpeg', qualitaet);
    final komma = dataUrl.indexOf(',');
    if (komma < 0) throw StateError('Canvas lieferte kein JPEG');
    return Uint8List.fromList(base64Decode(dataUrl.substring(komma + 1)));
  } finally {
    _Url.revokeObjectURL(blobUrl);
  }
}
