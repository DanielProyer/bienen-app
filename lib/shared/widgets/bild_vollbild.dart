import 'package:flutter/material.dart';
import 'package:bienen_app/core/theme/app_tokens.dart';

/// Zeigt ein Bild formatfüllend mit Zoom — für Abbildungen der Recherchen
/// ebenso wie für eigene Fotos.
///
/// Warum überhaupt: Viele Abbildungen sind Zeichnungen mit Zahlen und
/// Beschriftungen (Jahresraster, Explosionsdarstellung, Fütterungsfahrplan).
/// In Dokumentbreite auf einem Handy sind die Zahlen darin nicht lesbar; ohne
/// Zoom ist die Abbildung dort wertlos.
///
/// [aktionen] hängt zusätzliche Schaltflächen neben „Schliessen" — die eigenen
/// Fotos reichen darüber ihr Löschen ein.
Future<void> zeigeBildGross(
  BuildContext context, {
  required ImageProvider bild,
  String? beschriftung,
  List<Widget> aktionen = const [],
}) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black87,
    builder: (dialogContext) => Dialog(
      insetPadding: const EdgeInsets.all(BeeTokens.md),
      backgroundColor: Colors.transparent,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: InteractiveViewer(
              // 6× reicht, um auch kleine Beschriftungen in den Zeichnungen
              // zu lesen; darüber wird das Bild nur noch unscharf.
              maxScale: 6,
              child: Image(
                image: bild,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => const Padding(
                  padding: EdgeInsets.all(BeeTokens.xl),
                  child: Text('Bild konnte nicht geladen werden.',
                      style: TextStyle(color: Colors.white)),
                ),
              ),
            ),
          ),
          if (beschriftung != null && beschriftung.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(
                  top: BeeTokens.md, left: BeeTokens.md, right: BeeTokens.md),
              child: Text(
                beschriftung,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(top: BeeTokens.sm),
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: BeeTokens.md,
              children: [
                ...aktionen,
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Schliessen',
                      style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
