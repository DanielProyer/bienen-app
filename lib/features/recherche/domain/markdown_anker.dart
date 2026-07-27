/// Anker-Logik für die Recherche-Dokumente.
///
/// Die Recherchen tragen ein Inhaltsverzeichnis mit Verweisen der Form
/// `[Kapitel](#1-kapitel)`. Solche Sprungmarken kennt `flutter_markdown` nicht
/// von sich aus — es gibt keine Bildlaufposition zu einem Fragment. Deshalb
/// zerlegen wir ein Dokument hier in Abschnitte (je Überschrift einer) und
/// vergeben denselben Anker, den GitHub für die Überschrift erzeugt hätte.
/// Der Viewer hängt an jeden Abschnitt einen GlobalKey und kann so gezielt
/// dorthin rollen.
///
/// Beides sind reine Funktionen — die Sprungziele lassen sich damit prüfen,
/// ohne die Seite zu bauen.
library;

/// Ein Dokumentabschnitt: die Überschriftszeile samt allem Text bis zur
/// nächsten Überschrift.
class MarkdownAbschnitt {
  /// Sprungmarke der Überschrift; `null` für den Text **vor** der ersten
  /// Überschrift (Titelblock, Vorspann).
  final String? anker;

  /// Der Abschnitt inklusive seiner Überschriftszeile — sie darf nicht
  /// verlorengehen, sonst fehlt sie beim Rendern.
  final String text;

  const MarkdownAbschnitt({required this.anker, required this.text});
}

/// Erzeugt aus einer Überschriftszeile die Sprungmarke.
///
/// Nachgebildet ist das Verfahren von GitHub, weil die Inhaltsverzeichnisse in
/// `assets/recherche/` genau danach geschrieben sind: Kleinschreibung,
/// Satzzeichen entfallen, Leerzeichen werden zu Bindestrichen — **Umlaute
/// bleiben**. Dass ein Gedankenstrich verschwindet, seine beiden Leerzeichen
/// aber je einen Bindestrich hinterlassen, erklärt die `--` in den Verweisen.
String markdownAnker(String ueberschriftZeile) {
  var t = ueberschriftZeile.replaceFirst(RegExp(r'^\s*#{1,6}\s+'), '');

  // Inline-Auszeichnung zählt nicht mit: aus [Text](Ziel) wird Text,
  // Sternchen/Unterstriche/Backticks/Tilden fallen weg.
  t = t.replaceAllMapped(
      RegExp(r'\[([^\]]*)\]\([^)]*\)'), (m) => m.group(1) ?? '');
  t = t.replaceAll(RegExp(r'[*`~]'), '');

  t = t.toLowerCase().trim();

  // Alles ausser Buchstaben (inkl. Umlaute), Ziffern, Leerzeichen, Bindestrich
  // und Unterstrich entfernen. Wichtig: OHNE die Leerzeichen mitzunehmen —
  // sie werden gleich zu Bindestrichen und erzeugen so das erwartete `--`.
  t = t.replaceAll(RegExp(r'[^\p{L}\p{N} _-]', unicode: true), '');

  return t.replaceAll(' ', '-');
}

/// Vergleichsform einer Sprungmarke — toleriert unterschiedliche Trennzeichen.
///
/// Die Inhaltsverzeichnisse der Recherchen sind von Hand geschrieben und
/// uneinheitlich: Mal trennt ein Gedankenstrich (`—`), mal zwei Bindestriche
/// (`--`). Beide ergeben nach strengem Regelwerk **verschieden viele**
/// Bindestriche im Slug — ein Verweis `…-schweiz--grundlagen` verfehlte damit
/// die Überschrift `…-schweiz----grundlagen` um zwei Zeichen.
///
/// Statt 32 Dokumente in zwei Repos umzuschreiben (und jedes künftige zu
/// bewachen), wird für den Abgleich jede Bindestrich-Folge auf einen
/// zusammengezogen. Der Sprung findet sein Ziel damit unabhängig davon, welches
/// Trennzeichen der Autor gewählt hat.
///
/// Dasselbe gilt für Umlaute: Die Verzeichnisse schreiben teils `grundzuege`,
/// die Überschrift daneben `Grundzüge` (ebenso `ch-mass` ↔ `CH-Maß`). Beide
/// Seiten werden deshalb auf die ausgeschriebene Form gefaltet — die Richtung
/// ist gleichgültig, solange sie für Verweis und Ziel dieselbe ist.
String ankerSchluessel(String anker) => anker
    .toLowerCase()
    .replaceAll('ä', 'ae')
    .replaceAll('ö', 'oe')
    .replaceAll('ü', 'ue')
    .replaceAll('ß', 'ss')
    .replaceAll(RegExp(r'-+'), '-')
    .replaceAll(RegExp(r'^-+|-+$'), '');

/// Härteste Vergleichsform: nur Buchstaben und Ziffern.
///
/// Letzte Stufe für Verzeichnisse, die Sonderzeichen uneinheitlich behandeln —
/// `3-km-/50-%-Regel` steht im Verzeichnis als `3-km50`, `1→8` als `1-8`. Wo
/// jede Variante nachzubauen fragil wäre, entscheidet nur noch die Buchstaben-
/// und Ziffernfolge.
String _kern(String anker) => ankerSchluessel(anker)
    .replaceAll(RegExp(r'[^a-z0-9]', unicode: true), '');

/// Sucht zu einem Verweis (`#…`) die passende Überschrift.
///
/// Gestaffelt, und jede unscharfe Stufe greift **nur bei Eindeutigkeit** —
/// lieber kein Sprung als ein Sprung ins falsche Kapitel:
/// 1. exakt derselbe Slug,
/// 2. gleiche Vergleichsform (Trennzeichen/Umlaute egal),
/// 3. gleicher Kern (alle Sonderzeichen ignoriert),
/// 4. der Verweis ist Anfang einer längeren Überschrift — Verzeichnisse kürzen
///    gern: „11. Varroa — nur Einordnung" statt „… (Detail siehe Dok. 15)".
String? findeAnkerZiel(Iterable<String> vorhandene, String verweis) {
  final liste = vorhandene.toList();

  final exakt = liste.where((a) => a == verweis);
  if (exakt.isNotEmpty) return exakt.first;

  final v = ankerSchluessel(verweis);
  final gleich = liste.where((a) => ankerSchluessel(a) == v);
  if (gleich.length == 1) return gleich.single;

  final k = _kern(verweis);
  if (k.isEmpty) return null;

  final kernGleich = liste.where((a) => _kern(a) == k);
  if (kernGleich.length == 1) return kernGleich.single;

  final beginnt = liste.where((a) => _kern(a).startsWith(k));
  if (beginnt.length == 1) return beginnt.single;

  return null;
}

/// Zerlegt ein Markdown-Dokument an seinen Überschriften.
///
/// Zwei Fallstricke sind hier bewusst behandelt:
/// * **Code-Blöcke** dürfen nicht mitzählen — eine Zeile `# Kommentar` in einem
///   Shell-Beispiel ist keine Überschrift.
/// * **Gleichnamige Überschriften** (mehrere „Quellen") bekommen fortlaufende
///   Anker (`quellen`, `quellen-1`, …), sonst führt jeder Verweis zum ersten
///   Vorkommen.
List<MarkdownAbschnitt> zerlegeInAbschnitte(String markdown) {
  if (markdown.trim().isEmpty) return const [];

  final zeilen = markdown.split('\n');
  final abschnitte = <MarkdownAbschnitt>[];
  final vergeben = <String, int>{};

  final puffer = <String>[];
  String? aktuellerAnker;
  var imCodeBlock = false;

  void abschliessen() {
    if (puffer.isEmpty) return;
    final text = puffer.join('\n');
    if (text.trim().isEmpty && aktuellerAnker == null) {
      puffer.clear();
      return; // reiner Leerraum vor der ersten Überschrift
    }
    abschnitte.add(MarkdownAbschnitt(anker: aktuellerAnker, text: text));
    puffer.clear();
  }

  for (final zeile in zeilen) {
    // Ein Zaun (``` oder ~~~) schaltet den Code-Modus um. Innerhalb davon
    // bleibt jede Raute Text.
    if (RegExp(r'^\s*(```|~~~)').hasMatch(zeile)) {
      imCodeBlock = !imCodeBlock;
      puffer.add(zeile);
      continue;
    }

    final istUeberschrift =
        !imCodeBlock && RegExp(r'^\s*#{1,6}\s+\S').hasMatch(zeile);

    if (istUeberschrift) {
      abschliessen();
      final basis = markdownAnker(zeile);
      final schonDa = vergeben[basis] ?? 0;
      vergeben[basis] = schonDa + 1;
      aktuellerAnker = schonDa == 0 ? basis : '$basis-$schonDa';
    }

    puffer.add(zeile);
  }
  abschliessen();

  return abschnitte;
}
