import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:bienen_app/features/spracheingabe/domain/lernschwelle.dart';
import 'package:bienen_app/features/spracheingabe/domain/sprach_modelle.dart';
import 'package:bienen_app/features/spracheingabe/domain/startstapel.dart';

/// Was ein Erkenner geliefert hat.
///
/// `modell` und `dauerMs` gehoeren mit in die Ergebniszeile, nicht nur der
/// Text: Ohne die Modellangabe ist spaeter nicht mehr feststellbar, WOMIT
/// gemessen wurde — etwa ob die Fachwortliste dabei war (der Rueckfallweg der
/// Edge Function haengt genau das an den Namen). Messwerte ohne diese Angabe
/// sind untereinander nicht vergleichbar, und Vergleichbarkeit ist der einzige
/// Grund, warum der Bestand ueberhaupt aufbewahrt wird.
class Erkennungsergebnis {
  final String text;
  final String modell;
  final int? dauerMs;
  const Erkennungsergebnis({required this.text, this.modell = '', this.dauerMs});
}

/// Zugriff auf den Trainingsbestand.
///
/// RLS laesst nur die eigenen Zeilen durch (T01-T04) — deshalb braucht keine
/// Abfrage hier einen person_id-Filter. Beim SCHREIBEN muss die person_id
/// trotzdem mit, weil sie Teil der `with check`-Bedingung ist.
abstract class SpracheingabeGateway {
  Future<List<SprachKarte>> kartenLaden();
  Future<SprachKarte> karteAnlegen(SprachKarte karte);
  Future<SprachProbe> probeAnlegen(SprachProbe probe);
  Future<SprachErgebnis> ergebnisAnlegen(SprachErgebnis ergebnis);
  Future<List<SprachErgebnis>> ergebnisseZu(String probeId);
  Future<List<SprachKorrektur>> korrekturenLaden();

  /// Zaehlt einen beobachteten Verhoerer hoch und schaltet die Regel scharf,
  /// sobald die Lernschwelle erreicht ist.
  ///
  /// `betriebId` muss mitkommen und wird NICHT dem Default ueberlassen: RLS
  /// laesst die eigenen Zeilen ALLER Betriebe durch, in denen man Mitglied
  /// ist. Ohne die Einschraenkung faende die Vorabfrage bei einem Mitglied
  /// zweier Betriebe zwei Zeilen (harter Fehler) oder den Zaehler des falschen
  /// Betriebs — die Regel im zweiten Betrieb waere dann sofort scharf und die
  /// Lernschwelle ausgehebelt.
  Future<SprachKorrektur?> verhoererMelden({
    required String betriebId,
    required String personId,
    required String falsch,
    required String richtig,
    required String quelle,
  });

  /// Schickt eine Aufnahme an EINEN Erkenner und gibt zurueck, was er lieferte.
  ///
  /// Nur der schnelle Live-Anbieter — der Vollvergleich ueber alle drei laeuft
  /// spaeter ueber den gespeicherten Ton (Bauabschnitt 4). Das Warten auf alle
  /// waere rund zwanzig Sekunden je Karte und toetete den Drill.
  Future<Erkennungsergebnis> transkribieren({
    required Uint8List bytes,
    required String dateiname,
    required String anbieter,
    required bool mitWortliste,
  });

  /// Legt den Startstapel an, falls der Betrieb noch keinen hat.
  /// Gibt zurueck, wie viele Karten angelegt wurden (0 = war schon da).
  Future<int> startstapelSicherstellen();
}

class SupabaseSpracheingabeGateway implements SpracheingabeGateway {
  final SupabaseClient _c;
  SupabaseSpracheingabeGateway(this._c);

  @override
  Future<List<SprachKarte>> kartenLaden() async {
    final res = await _c.from('sprach_karten').select().eq('aktiv', true);
    return (res as List).map((j) => SprachKarte.fromJson(j as Map<String, dynamic>)).toList();
  }

  @override
  Future<SprachKarte> karteAnlegen(SprachKarte karte) async {
    final res = await _c.from('sprach_karten').insert(karte.toInsertJson()).select().single();
    return SprachKarte.fromJson(res);
  }

  @override
  Future<SprachProbe> probeAnlegen(SprachProbe probe) async {
    final res = await _c.from('sprach_proben').insert(probe.toInsertJson()).select().single();
    return SprachProbe.fromJson(res);
  }

  @override
  Future<SprachErgebnis> ergebnisAnlegen(SprachErgebnis ergebnis) async {
    final res = await _c
        .from('sprach_ergebnisse')
        .insert(ergebnis.toInsertJson())
        .select()
        .single();
    return SprachErgebnis.fromJson(res);
  }

  @override
  Future<List<SprachErgebnis>> ergebnisseZu(String probeId) async {
    final res = await _c
        .from('sprach_ergebnisse')
        .select()
        .eq('probe_id', probeId)
        .order('gemessen_am', ascending: false);
    return (res as List).map((j) => SprachErgebnis.fromJson(j as Map<String, dynamic>)).toList();
  }

  @override
  Future<List<SprachKorrektur>> korrekturenLaden() async {
    final res = await _c.from('sprach_korrekturen').select();
    return (res as List).map((j) => SprachKorrektur.fromJson(j as Map<String, dynamic>)).toList();
  }

  @override
  Future<SprachKorrektur?> verhoererMelden({
    required String betriebId,
    required String personId,
    required String falsch,
    required String richtig,
    required String quelle,
  }) async {
    final schluessel = falsch.trim().toLowerCase();
    if (schluessel.isEmpty || richtig.trim().isEmpty) return null;

    // Betrieb und Person ausdruecklich einschraenken: RLS liefert die eigenen
    // Zeilen aller Betriebe, in denen man Mitglied ist.
    final vorhanden = await _c
        .from('sprach_korrekturen')
        .select()
        .eq('betrieb_id', betriebId)
        .eq('person_id', personId)
        .eq('falsch', schluessel)
        .maybeSingle();

    final treffer = vorhanden == null ? 1 : ((vorhanden['treffer'] as num).toInt() + 1);
    final aktiv = darfRegelWerden(treffer: treffer, falsch: schluessel, richtig: richtig);

    final res = await _c
        .from('sprach_korrekturen')
        .upsert({
          'betrieb_id': betriebId,
          'person_id': personId,
          'falsch': schluessel,
          'richtig': richtig.trim(),
          'treffer': treffer,
          'quelle': quelle,
          'aktiv': aktiv,
          'zuletzt_am': DateTime.now().toUtc().toIso8601String(),
        }, onConflict: 'betrieb_id,person_id,falsch')
        .select()
        .single();
    return SprachKorrektur.fromJson(res);
  }

  @override
  Future<Erkennungsergebnis> transkribieren({
    required Uint8List bytes,
    required String dateiname,
    required String anbieter,
    required bool mitWortliste,
  }) async {
    // Die Function erkennt den App-Weg am mitgeschickten JWT; supabase_flutter
    // haengt es bei invoke() automatisch an.
    final FunctionResponse res;
    try {
      res = await _c.functions.invoke(
        'transkription',
        method: HttpMethod.post,
        queryParameters: {'aktion': anbieter},
        files: [MultipartFile.fromBytes('audio', bytes, filename: dateiname)],
        body: {'wortliste': mitWortliste ? 'ja' : 'nein'},
      );
    } on FunctionException catch (e) {
      throw Exception(_funktionsKlartext(e));
    }

    final daten = res.data;
    if (daten is! Map) throw Exception('Unerwartete Antwort der Erkennung.');
    if (daten['fehler'] != null) throw Exception('Erkennung: ${daten['fehler']}');
    final ergebnis = daten['ergebnis'];
    if (ergebnis is! Map) throw Exception('Die Erkennung lieferte kein Ergebnis.');
    if (ergebnis['fehler'] != null) throw Exception('$anbieter: ${ergebnis['fehler']}');
    return Erkennungsergebnis(
      text: (ergebnis['text'] as String?) ?? '',
      modell: (ergebnis['modell'] as String?) ?? '',
      dauerMs: (ergebnis['dauerMs'] as num?)?.toInt(),
    );
  }

  String _funktionsKlartext(FunctionException e) => switch (e.status) {
    401 => 'Nicht berechtigt — bitte neu anmelden.',
    404 => 'Die Erkennung ist nicht erreichbar (Function fehlt).',
    504 => 'Die Erkennung hat zu lange gebraucht. Kürzere Aufnahme versuchen.',
    _ => 'Erkennung fehlgeschlagen (Status ${e.status}).',
  };

  @override
  Future<int> startstapelSicherstellen() async {
    final vorhanden = await _c.from('sprach_karten').select('id').eq('herkunft', 'start').limit(1);
    if ((vorhanden as List).isNotEmpty) return 0;

    // person_id bleibt leer: Der Startstapel gilt fuer alle im Betrieb.
    // betrieb_id kommt aus dem Default — hier ist das richtig, weil die Karten
    // ausdruecklich zum aktiven Betrieb gehoeren sollen.
    final zeilen = startstapel.map((k) => k.toInsertJson()).toList();
    await _c.from('sprach_karten').insert(zeilen);
    return zeilen.length;
  }
}
