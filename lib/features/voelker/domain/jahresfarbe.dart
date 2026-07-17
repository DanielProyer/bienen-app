/// Internationale Koeniginnen-Jahresfarben (fixer 5er-Zyklus ueber die Endziffer
/// des Schlupfjahrs). KEIN Mandanten-Config — international einheitlich.
enum Jahresfarbe { weiss, gelb, rot, gruen, blau }

Jahresfarbe jahresfarbe(int schlupfjahr) {
  switch (schlupfjahr % 5) {
    case 1:
      return Jahresfarbe.weiss; // …1 / …6
    case 2:
      return Jahresfarbe.gelb;
    case 3:
      return Jahresfarbe.rot;
    case 4:
      return Jahresfarbe.gruen;
    default:
      return Jahresfarbe.blau; // …0 / …5
  }
}

extension JahresfarbeLabel on Jahresfarbe {
  String get label => switch (this) {
        Jahresfarbe.weiss => 'weiss',
        Jahresfarbe.gelb => 'gelb',
        Jahresfarbe.rot => 'rot',
        Jahresfarbe.gruen => 'gruen',
        Jahresfarbe.blau => 'blau',
      };
}
