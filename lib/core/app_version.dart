import 'package:flutter/material.dart';

/// Version der laufenden Fassung, beim Build eingebacken.
///
/// Bewusst NICHT aus `version.json` gelesen: Diese Datei liegt auf dem Server
/// und ist nach einem Deploy sofort neu — eine noch aus dem Zwischenspeicher
/// laufende App würde damit die neue Nummer anzeigen und genau die Frage
/// verschleiern, für die es die Anzeige gibt: Läuft der Fix schon oder nicht?
///
/// Gesetzt in `deploy.sh` über `--dart-define=APP_VERSION=<version>`. Ohne
/// dart-define (lokales `flutter run`) steht hier `dev`.
const String appVersion = String.fromEnvironment(
  'APP_VERSION',
  defaultValue: 'dev',
);

/// Wird die Version noch entwicklungsbegleitend gezeigt?
///
/// Solange die App im Entwicklungsstadium ist, gehört die Version dauerhaft
/// sichtbar in die Oberfläche — ohne sie lässt sich nach einer Rückmeldung aus
/// dem Feld nicht entscheiden, ob eine Änderung nicht wirkt oder gar nicht
/// angekommen ist. Vor dem ersten produktiven Release auf `false` setzen; die
/// Zeile in den Einstellungen bleibt davon unberührt.
const bool versionImmerZeigen = true;

/// Dezentes Versions-Etikett, das über der Oberfläche schwebt.
///
/// `IgnorePointer`, damit es keine Bedienelemente blockiert, und knapp über der
/// Navigationsleiste, weil dort auf keiner Seite etwas Wichtiges liegt.
class VersionsEtikett extends StatelessWidget {
  const VersionsEtikett({super.key});

  @override
  Widget build(BuildContext context) {
    if (!versionImmerZeigen) return const SizedBox.shrink();
    return Positioned(
      right: 6,
      bottom: 4,
      child: IgnorePointer(
        child: Opacity(
          opacity: 0.45,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              child: Text(
                'v$appVersion',
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
