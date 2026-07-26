import 'dart:typed_data';

/// Nicht-Web-Ziele (VM/Tests): Canvas gibt es hier nicht, die Bytes gehen
/// unveraendert durch. ACHTUNG: Der Stub ist KEINE Zusage — der echte Strip
/// passiert ausschliesslich im Browser (ohne_metadaten_web.dart) und wird dort
/// verifiziert.
Future<Uint8List> ohneMetadaten(
  Uint8List bytes, {
  int maxBreite = 2000,
  double qualitaet = 0.85,
}) async =>
    bytes;
