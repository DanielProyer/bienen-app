/// Rollen des Mandanten-Modells (DB-Enum `public.betrieb_rolle`).
enum Rolle {
  owner,
  editor,
  viewer;

  /// Parst den JWT-/DB-Wert. Unbekannt oder null -> null (nie raten).
  static Rolle? vonString(String? wert) => switch (wert) {
        'owner' => Rolle.owner,
        'editor' => Rolle.editor,
        'viewer' => Rolle.viewer,
        _ => null,
      };

  /// owner|editor duerfen Fachdaten schreiben (Spiegel von private.kann_schreiben).
  /// Dient NUR dem Ausblenden von UI — durchgesetzt wird es von RLS.
  bool get darfSchreiben => this == Rolle.owner || this == Rolle.editor;

  bool get istOwner => this == Rolle.owner;

  String get anzeige => switch (this) {
        Rolle.owner => 'Inhaber',
        Rolle.editor => 'Bearbeiter',
        Rolle.viewer => 'Gast (nur lesen)',
      };
}
