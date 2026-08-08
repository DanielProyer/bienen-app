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
