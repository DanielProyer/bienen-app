import 'package:bienen_app/features/spracheingabe/domain/sprach_modelle.dart';

/// Der Übungsstapel, mit dem ein Betrieb startet.
///
/// Die Wortkarten sind zeichengleich mit `FACHWOERTER` aus
/// `supabase/functions/transkription/fachwoerter.ts` — ein Test haelt das fest.
/// Zwei Wahrheiten fuer dieselbe Liste waeren eine Zeitbombe: Der Erkenner
/// boostete dann andere Begriffe, als der Drill uebt.
///
/// Was hier BEWUSST fehlt (Entscheid D-99d): Seuchenbegriffe und Alltagswoerter
/// mit imkerlicher Sonderbedeutung. Sie stehen in `gesperrteBegriffe`.
///
/// Die `id` bleibt leer — sie wird beim Anlegen von der Datenbank vergeben.
const List<SprachKarte> startstapel = [
  SprachKarte(id: '', art: KartenArt.wort, sollText: 'Varroa', herkunft: 'start'),
  SprachKarte(id: '', art: KartenArt.wort, sollText: 'Varroamilbe', herkunft: 'start'),
  SprachKarte(id: '', art: KartenArt.wort, sollText: 'Milben', herkunft: 'start'),
  SprachKarte(id: '', art: KartenArt.wort, sollText: 'Weiselzellen', herkunft: 'start'),
  SprachKarte(id: '', art: KartenArt.wort, sollText: 'Weiselrichtigkeit', herkunft: 'start'),
  SprachKarte(id: '', art: KartenArt.wort, sollText: 'weiselrichtig', herkunft: 'start'),
  SprachKarte(id: '', art: KartenArt.wort, sollText: 'weisellos', herkunft: 'start'),
  SprachKarte(id: '', art: KartenArt.wort, sollText: 'Drohnenbrut', herkunft: 'start'),
  SprachKarte(id: '', art: KartenArt.wort, sollText: 'Drohnenrahmen', herkunft: 'start'),
  SprachKarte(id: '', art: KartenArt.wort, sollText: 'Schwarmtrieb', herkunft: 'start'),
  SprachKarte(id: '', art: KartenArt.wort, sollText: 'Schwarmzellen', herkunft: 'start'),
  SprachKarte(id: '', art: KartenArt.wort, sollText: 'Ableger', herkunft: 'start'),
  SprachKarte(id: '', art: KartenArt.wort, sollText: 'Kunstschwarm', herkunft: 'start'),
  SprachKarte(id: '', art: KartenArt.wort, sollText: 'Dadant', herkunft: 'start'),
  SprachKarte(id: '', art: KartenArt.wort, sollText: 'Zander', herkunft: 'start'),
  SprachKarte(id: '', art: KartenArt.wort, sollText: 'Mittelwand', herkunft: 'start'),
  SprachKarte(id: '', art: KartenArt.wort, sollText: 'Absperrgitter', herkunft: 'start'),
  SprachKarte(id: '', art: KartenArt.wort, sollText: 'Honigraum', herkunft: 'start'),
  SprachKarte(id: '', art: KartenArt.wort, sollText: 'Brutraum', herkunft: 'start'),
  SprachKarte(id: '', art: KartenArt.wort, sollText: 'Wabengasse', herkunft: 'start'),
  SprachKarte(id: '', art: KartenArt.wort, sollText: 'Gemüll', herkunft: 'start'),
  SprachKarte(id: '', art: KartenArt.wort, sollText: 'Ameisensäure', herkunft: 'start'),
  SprachKarte(id: '', art: KartenArt.wort, sollText: 'Oxalsäure', herkunft: 'start'),
  SprachKarte(id: '', art: KartenArt.wort, sollText: 'Sublimation', herkunft: 'start'),
  SprachKarte(id: '', art: KartenArt.wort, sollText: 'Trachtende', herkunft: 'start'),
  SprachKarte(id: '', art: KartenArt.wort, sollText: 'Räuberei', herkunft: 'start'),
  SprachKarte(id: '', art: KartenArt.wort, sollText: 'Kalkbrut', herkunft: 'start'),
  SprachKarte(id: '', art: KartenArt.wort, sollText: 'Buckfast', herkunft: 'start'),
  SprachKarte(id: '', art: KartenArt.wort, sollText: 'Bienenflucht', herkunft: 'start'),
  SprachKarte(id: '', art: KartenArt.wort, sollText: 'Futterteig', herkunft: 'start'),
];
