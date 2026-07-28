import 'package:flutter/material.dart';
import 'package:bienen_app/core/theme/app_tokens.dart';

/// Zeigt ein Bild bildschirmfüllend mit Zoom — für Abbildungen der Recherchen
/// ebenso wie für eigene Fotos.
///
/// Warum überhaupt: Viele Abbildungen sind Zeichnungen mit Zahlen und
/// Beschriftungen (Jahresraster, Explosionsdarstellung, Fütterungsfahrplan).
/// In Dokumentbreite auf einem Handy sind die Zahlen darin nicht lesbar.
///
/// Bewusst über die **ganze** Bildschirmfläche und nicht in einem Dialog, der
/// sich auf die Bildgrösse zusammenzieht: Eine breite, flache Zeichnung ergäbe
/// sonst einen schmalen Streifen mit viel leerem Rand — also genau das
/// Gegenteil von „gross ansehen". Beschriftung und Schaltflächen liegen
/// deshalb **über** dem Bild, statt ihm Platz wegzunehmen.
///
/// [aktionen] hängt zusätzliche Schaltflächen neben „Schliessen" — die eigenen
/// Fotos reichen darüber ihr Löschen ein.
Future<void> zeigeBildGross(
  BuildContext context, {
  required ImageProvider bild,
  String? beschriftung,
  List<Widget> aktionen = const [],
}) {
  final hatText = beschriftung != null && beschriftung.trim().isNotEmpty;

  return showDialog<void>(
    context: context,
    barrierColor: Colors.black,
    // Ohne das rechnet der Dialog mit einer Mindestbreite und lässt Ränder.
    useSafeArea: false,
    builder: (dialogContext) => Dialog.fullscreen(
      backgroundColor: Colors.black,
      child: Stack(
        children: [
          // Das Bild bekommt die gesamte Fläche; BoxFit.contain hält die
          // Proportion, der Zoom holt die Details heran.
          Positioned.fill(
            child: InteractiveViewer(
              // 6× reicht, um auch kleine Beschriftungen in den Zeichnungen
              // zu lesen; darüber wird das Bild nur noch unscharf.
              maxScale: 6,
              child: Image(
                image: bild,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(BeeTokens.xl),
                    child: Text('Bild konnte nicht geladen werden.',
                        style: TextStyle(color: Colors.white)),
                  ),
                ),
              ),
            ),
          ),

          // Bedienleiste oben rechts — ausserhalb des Bildes wäre kein Platz.
          Positioned(
            top: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(BeeTokens.sm),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ...aktionen,
                    IconButton(
                      tooltip: 'Schliessen',
                      onPressed: () => Navigator.pop(dialogContext),
                      icon: const Icon(Icons.close, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
          ),

          if (hatText)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: BeeTokens.lg, vertical: BeeTokens.md),
                  color: Colors.black54,
                  child: Text(
                    beschriftung,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}
