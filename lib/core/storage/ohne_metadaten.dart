import 'dart:typed_data';
// Bedingter Import: Web bekommt die dart:js_interop-Kapsel (Canvas), VM/Tests
// einen Durchlauf-Stub (js_interop baut nur auf dem Web-Ziel).
import 'package:bienen_app/core/storage/ohne_metadaten_stub.dart'
    if (dart.library.js_interop) 'package:bienen_app/core/storage/ohne_metadaten_web.dart'
    as impl;

/// Entfernt ALLE Bildmetadaten (GPS, Aufnahmezeit, Geraet) durch Neu-Encodieren
/// in ein Canvas — ein Canvas kennt kein EXIF. Verkleinert gleich mit, weil der
/// „Dokumente"-Upload-Pfad kein vorheriges Resize hat.
///
/// WIRFT bei Dekodier-Fehlern (z. B. HEIC vom iPhone) statt das Original
/// zurueckzugeben: ein abgelehnter Upload ist sichtbar und behebbar, ein
/// stillschweigend mit GPS hochgeladenes Foto ist es nicht.
Future<Uint8List> ohneMetadaten(
  Uint8List bytes, {
  int maxBreite = 2000,
  double qualitaet = 0.85,
}) =>
    impl.ohneMetadaten(bytes, maxBreite: maxBreite, qualitaet: qualitaet);
