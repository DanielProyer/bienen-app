/// Unterscheidet gespeicherte Foto-Werte: Nach P01 stehen in der DB PFADE
/// (die zur Laufzeit signiert werden). Ein Wert, der noch eine volle URL ist
/// (uebersehener Altbestand, kuenftiger Import), wird direkt verwendet — so
/// bleibt die Galerie in jedem Fall sichtbar statt leer.
bool istVolleUrl(String wert) {
  final w = wert.trim();
  return w.startsWith('http://') || w.startsWith('https://');
}
