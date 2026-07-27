// Einmal-Werkzeug: kompiliert alle Wissens-Skizzen mit dem Parser, den
// flutter_svg zur Laufzeit benutzt. Faengt Konstrukte, die reines XML-Parsen
// durchlaesst, die aber still verworfen werden (z. B. <marker>).
// Aufruf: dart run tool/svg_check.dart
// ignore_for_file: depend_on_referenced_packages, avoid_print
import 'dart:io';

import 'package:vector_graphics_compiler/vector_graphics_compiler.dart';

void main() {
  final dateien = Directory('assets/wissen')
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.svg'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  var fehler = 0;
  for (final f in dateien) {
    try {
      encodeSvg(
        xml: f.readAsStringSync(),
        debugName: f.path,
        warningsAsErrors: true,
        // Die Optimizer brauchen die native PathOps-Lib, die hier nicht
        // initialisiert ist. Geprueft werden soll das Parsen, nicht das
        // Optimieren.
        enableMaskingOptimizer: false,
        enableClippingOptimizer: false,
        enableOverdrawOptimizer: false,
      );
    } catch (e) {
      fehler++;
      print('FEHLER ${f.uri.pathSegments.last}: $e');
    }
  }
  print('${dateien.length} Skizzen geprueft, $fehler mit Befund.');
  if (fehler > 0) exitCode = 1;
}
