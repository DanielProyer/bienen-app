import 'package:bienen_app/features/spracheingabe/domain/korrektur_anwendung.dart';

enum KartenArt { wort, satz }

enum ProbenModus { drill, frei }

T _ausText<T extends Enum>(List<T> werte, Object? roh, T standard) {
  final s = (roh as String?)?.trim();
  for (final w in werte) {
    if (w.name == s) return w;
  }
  return standard;
}

/// Eine Uebungskarte.
class SprachKarte {
  final String id;
  final String? personId;
  final KartenArt art;
  final String sollText;
  final List<String> pruefbegriffe;
  final String herkunft;
  final bool aktiv;

  const SprachKarte({
    required this.id,
    required this.art,
    required this.sollText,
    this.personId,
    this.pruefbegriffe = const [],
    this.herkunft = 'eigen',
    this.aktiv = true,
  });

  /// Was fuer die Trefferzaehlung erwartet wird.
  ///
  /// Bei einer Wortkarte ist der Soll-Text selbst der einzige Pruefbegriff —
  /// sonst haette sie nichts zu zaehlen. Bei einer Satzkarte gelten die
  /// hinterlegten Begriffe.
  List<String> get zuZaehlen => art == KartenArt.wort ? [sollText.trim()] : pruefbegriffe;

  factory SprachKarte.fromJson(Map<String, dynamic> j) => SprachKarte(
    id: j['id'] as String,
    personId: j['person_id'] as String?,
    art: _ausText(KartenArt.values, j['art'], KartenArt.wort),
    sollText: (j['soll_text'] as String?) ?? '',
    pruefbegriffe: ((j['pruefbegriffe'] as List?) ?? const []).map((e) => e as String).toList(),
    herkunft: (j['herkunft'] as String?) ?? 'eigen',
    aktiv: (j['aktiv'] as bool?) ?? true,
  );

  Map<String, dynamic> toInsertJson() => {
    if (personId != null) 'person_id': personId,
    'art': art.name,
    'soll_text': sollText,
    'pruefbegriffe': pruefbegriffe,
    'herkunft': herkunft,
    'aktiv': aktiv,
  };
}

/// Eine Aufnahme.
class SprachProbe {
  final String id;
  final String personId;
  final String? karteId;
  final String sollText;
  final ProbenModus modus;
  final String storagePath;
  final int dauerMs;
  final int groesseB;
  final String mime;

  const SprachProbe({
    required this.id,
    required this.personId,
    required this.sollText,
    required this.modus,
    required this.storagePath,
    required this.dauerMs,
    required this.groesseB,
    this.karteId,
    this.mime = 'audio/webm',
  });

  factory SprachProbe.fromJson(Map<String, dynamic> j) => SprachProbe(
    id: j['id'] as String,
    personId: j['person_id'] as String,
    karteId: j['karte_id'] as String?,
    sollText: (j['soll_text'] as String?) ?? '',
    modus: _ausText(ProbenModus.values, j['modus'], ProbenModus.frei),
    storagePath: j['storage_path'] as String,
    dauerMs: (j['dauer_ms'] as num?)?.toInt() ?? 0,
    groesseB: (j['groesse_b'] as num?)?.toInt() ?? 0,
    mime: (j['mime'] as String?) ?? 'audio/webm',
  );

  Map<String, dynamic> toInsertJson() => {
    'person_id': personId,
    if (karteId != null) 'karte_id': karteId,
    'soll_text': sollText,
    'modus': modus.name,
    'storage_path': storagePath,
    'dauer_ms': dauerMs,
    'groesse_b': groesseB,
    'mime': mime,
  };
}

/// Eine Messung: was ein Anbieter aus einer Probe gemacht hat.
class SprachErgebnis {
  final String id;
  final String probeId;
  final String anbieter;
  final String modell;
  final bool mitWortliste;
  final String transkript;
  final double? trefferQuote;
  final double? wortfehlerrate;
  final int? dauerMs;
  final String? fehler;

  const SprachErgebnis({
    required this.id,
    required this.probeId,
    required this.anbieter,
    required this.mitWortliste,
    this.modell = '',
    this.transkript = '',
    this.trefferQuote,
    this.wortfehlerrate,
    this.dauerMs,
    this.fehler,
  });

  factory SprachErgebnis.fromJson(Map<String, dynamic> j) => SprachErgebnis(
    id: j['id'] as String,
    probeId: j['probe_id'] as String,
    anbieter: j['anbieter'] as String,
    modell: (j['modell'] as String?) ?? '',
    mitWortliste: (j['mit_wortliste'] as bool?) ?? false,
    transkript: (j['transkript'] as String?) ?? '',
    trefferQuote: (j['treffer_quote'] as num?)?.toDouble(),
    wortfehlerrate: (j['wortfehlerrate'] as num?)?.toDouble(),
    dauerMs: (j['dauer_ms'] as num?)?.toInt(),
    fehler: j['fehler'] as String?,
  );

  Map<String, dynamic> toInsertJson() => {
    'probe_id': probeId,
    'anbieter': anbieter,
    'modell': modell,
    'mit_wortliste': mitWortliste,
    'transkript': transkript,
    'treffer_quote': trefferQuote,
    'wortfehlerrate': wortfehlerrate,
    'dauer_ms': dauerMs,
    'fehler': fehler,
  };
}

/// Eine beobachtete oder gelernte Lautvariante.
class SprachKorrektur {
  final String id;
  final String personId;
  final String falsch;
  final String richtig;
  final int treffer;
  final String quelle;
  final bool aktiv;

  const SprachKorrektur({
    required this.id,
    required this.personId,
    required this.falsch,
    required this.richtig,
    this.treffer = 1,
    this.quelle = 'training',
    this.aktiv = false,
  });

  factory SprachKorrektur.fromJson(Map<String, dynamic> j) => SprachKorrektur(
    id: j['id'] as String,
    personId: j['person_id'] as String,
    falsch: j['falsch'] as String,
    richtig: j['richtig'] as String,
    treffer: (j['treffer'] as num?)?.toInt() ?? 1,
    quelle: (j['quelle'] as String?) ?? 'training',
    aktiv: (j['aktiv'] as bool?) ?? false,
  );

  /// Uebersetzt in die Form, die `korrekturenAnwenden` erwartet.
  ///
  /// Steht hier und nicht beim Aufrufer, damit es genau EINE Stelle gibt, an
  /// der aus einer gespeicherten Zeile eine wirksame Regel wird — sonst
  /// entstuende die Umwandlung in jedem Verbraucher neu, und irgendeiner
  /// vergaesse `aktiv` zu pruefen.
  Korrekturregel get regel => Korrekturregel(falsch: falsch, richtig: richtig);

  /// Nur scharfe Regeln aus einer Liste — der uebliche Einstieg.
  static List<Korrekturregel> nurAktive(Iterable<SprachKorrektur> alle) =>
      alle.where((k) => k.aktiv).map((k) => k.regel).toList();
}
