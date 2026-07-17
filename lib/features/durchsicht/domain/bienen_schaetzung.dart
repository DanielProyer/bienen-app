/// Grobe Bienenzahl-Schaetzung aus besetzten Wabengassen (~1000/Gasse, Dadant;
/// Recherche 11). Nur Anzeige, nicht gespeichert.
int? bienenSchaetzung(num? wabengassen) =>
    wabengassen == null ? null : (wabengassen * 1000).round();
