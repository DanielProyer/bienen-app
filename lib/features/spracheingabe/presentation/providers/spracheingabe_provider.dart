import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bienen_app/core/supabase/supabase_config.dart';
import 'package:bienen_app/features/auth/presentation/auth_providers.dart';
import 'package:bienen_app/features/spracheingabe/data/sprach_aufnahme.dart';
import 'package:bienen_app/features/spracheingabe/data/sprach_speicher.dart';
import 'package:bienen_app/features/spracheingabe/data/spracheingabe_gateway.dart';
import 'package:bienen_app/features/spracheingabe/domain/fachwort_treffer.dart';
import 'package:bienen_app/features/spracheingabe/domain/kartenwahl.dart';
import 'package:bienen_app/features/spracheingabe/domain/sprach_modelle.dart';
import 'package:bienen_app/features/spracheingabe/domain/verhoerer_diff.dart';
import 'package:bienen_app/features/spracheingabe/domain/wortfehlerrate.dart';

final spracheingabeGatewayProvider = Provider<SpracheingabeGateway>(
  (ref) => SupabaseSpracheingabeGateway(SupabaseConfig.client),
);

final sprachSpeicherProvider = Provider<SprachSpeicher>(
  (ref) => SprachSpeicher(SupabaseConfig.client),
);

/// Live-Anbieter des Drills. Vorgabe bis zum Entscheid D-100: ElevenLabs, als
/// einziger der drei synchron und ohne Warteschlange.
final liveAnbieterProvider = Provider<String>((ref) => 'elevenlabs');

/// Was der Drill gerade anzeigt.
class DrillZustand {
  final List<SprachKarte> stapel;
  final SprachKarte? karte;
  final Map<String, Kartenbilanz> bilanz;
  final DrillErgebnis? letztes;

  /// Das Mikrofon ist offen.
  final bool laeuft;

  /// Hochladen und Erkennen laufen. Das dauert mehrere Sekunden und muss
  /// sichtbar sein — sonst sieht ein arbeitender Bildschirm aus wie ein toter.
  final bool arbeitet;

  /// Was schiefging, in Klartext. Ohne dieses Feld verschwindet jede Ausnahme
  /// still in einem `onPressed`, und der Nutzer sieht nur, dass nichts
  /// passiert. Genau daran ist der erste Feldversuch gescheitert.
  final String? fehler;

  const DrillZustand({
    this.stapel = const [],
    this.karte,
    this.bilanz = const {},
    this.letztes,
    this.laeuft = false,
    this.arbeitet = false,
    this.fehler,
  });

  DrillZustand copyWith({
    List<SprachKarte>? stapel,
    SprachKarte? karte,
    Map<String, Kartenbilanz>? bilanz,
    DrillErgebnis? letztes,
    bool? laeuft,
    bool? arbeitet,
    String? fehler,
    bool letztesLoeschen = false,
    bool fehlerLoeschen = false,
  }) => DrillZustand(
    stapel: stapel ?? this.stapel,
    karte: karte ?? this.karte,
    bilanz: bilanz ?? this.bilanz,
    letztes: letztesLoeschen ? null : (letztes ?? this.letztes),
    laeuft: laeuft ?? this.laeuft,
    arbeitet: arbeitet ?? this.arbeitet,
    fehler: fehlerLoeschen ? null : (fehler ?? this.fehler),
  );
}

/// Das Ergebnis einer gesprochenen Karte.
class DrillErgebnis {
  final String sollText;
  final String transkript;
  final bool getroffen;
  final double? wortfehler;

  const DrillErgebnis({
    required this.sollText,
    required this.transkript,
    required this.getroffen,
    this.wortfehler,
  });
}

final drillProvider = AsyncNotifierProvider<DrillNotifier, DrillZustand>(DrillNotifier.new);

class DrillNotifier extends AsyncNotifier<DrillZustand> {
  SprachAufnahme? _aufnahme;

  SpracheingabeGateway get _gw => ref.read(spracheingabeGatewayProvider);
  SprachSpeicher get _speicher => ref.read(sprachSpeicherProvider);

  @override
  Future<DrillZustand> build() async {
    await _gw.startstapelSicherstellen();
    final karten = await _gw.kartenLaden();
    final zustand = DrillZustand(stapel: karten);
    return zustand.copyWith(
      karte: naechsteKarte(karten: karten, bilanz: const {}),
    );
  }

  /// Uebersetzt eine Ausnahme in einen Satz, der dem Nutzer weiterhilft.
  ///
  /// Die haeufigsten Faelle stehen zuerst und beim Namen: „nichts passiert" ist
  /// die schlechteste aller Rueckmeldungen, „Mikrofon nicht erlaubt" die
  /// beste.
  static String _klartext(Object e) {
    final t = e.toString();
    if (t.contains('NotAllowedError') || t.contains('Permission')) {
      return 'Das Mikrofon ist nicht freigegeben. Im Browser die Erlaubnis '
          'erteilen (Schloss-Symbol in der Adresszeile) und erneut versuchen.';
    }
    if (t.contains('NotFoundError')) {
      return 'Es wurde kein Mikrofon gefunden.';
    }
    if (t.contains('Nicht berechtigt')) {
      return 'Die Erkennung hat die Anmeldung nicht akzeptiert. Einmal ab- und '
          'wieder anmelden; bleibt es dabei, stimmt etwas am Server nicht.';
    }
    return t.replaceFirst('Exception: ', '');
  }

  Future<void> aufnahmeStarten() async {
    final jetzt = state.valueOrNull;
    if (jetzt == null || jetzt.laeuft || jetzt.arbeitet) return;
    try {
      _aufnahme = SprachAufnahme();
      await _aufnahme!.starten();
      state = AsyncData(jetzt.copyWith(laeuft: true, letztesLoeschen: true, fehlerLoeschen: true));
    } catch (e) {
      // Ohne diesen Fang bleibt eine verweigerte Mikrofon-Erlaubnis
      // vollstaendig unsichtbar — der Knopf sieht aus, als tue er nichts.
      _aufnahme = null;
      state = AsyncData(jetzt.copyWith(laeuft: false, fehler: _klartext(e)));
    }
  }

  /// Beendet die Aufnahme, legt sie ab, laesst sie erkennen und bewertet.
  ///
  /// Reihenfolge mit Absicht: **zuerst ablegen, dann erkennen.** Faellt die
  /// Erkennung aus, ist die Aufnahme trotzdem im Bestand und beim naechsten
  /// Vollvergleich auswertbar — der ganze Sinn davon, den Ton zu behalten.
  Future<void> aufnahmeBeenden() async {
    final jetzt = state.valueOrNull;
    final karte = jetzt?.karte;
    final aufnahme = _aufnahme;
    if (jetzt == null || karte == null || aufnahme == null) return;

    final Tonaufnahme ton;
    try {
      ton = await aufnahme.beenden();
    } catch (e) {
      _aufnahme = null;
      state = AsyncData(jetzt.copyWith(laeuft: false, fehler: _klartext(e)));
      return;
    }
    _aufnahme = null;

    // Ab hier wird gearbeitet: hochladen, erkennen, bewerten. Das dauert
    // mehrere Sekunden und muss sichtbar sein.
    state = AsyncData(jetzt.copyWith(laeuft: false, arbeitet: true, fehlerLoeschen: true));

    try {
      final betriebId = ref.read(currentBetriebIdProvider);
      final personId = ref.read(authControllerProvider).session?.userId;
      if (betriebId == null || personId == null) {
        throw Exception('Nicht angemeldet oder kein Betrieb gewählt.');
      }

      final kennung = DateTime.now().microsecondsSinceEpoch.toString();
      final pfad = await _speicher.hochladen(
        betriebId: betriebId,
        personId: personId,
        bytes: ton.bytes,
        mime: ton.mime,
        kennung: kennung,
      );

      final probe = await _gw.probeAnlegen(
        SprachProbe(
          id: '',
          personId: personId,
          karteId: karte.id,
          sollText: karte.sollText,
          modus: ProbenModus.drill,
          storagePath: pfad,
          dauerMs: ton.dauerMs,
          groesseB: ton.bytes.lengthInBytes,
          mime: ton.mime,
        ),
      );

      final anbieter = ref.read(liveAnbieterProvider);
      final erkannt = await _gw.transkribieren(
        bytes: ton.bytes,
        dateiname: pfad.split('/').last,
        anbieter: anbieter,
        mitWortliste: true,
      );

      final transkript = erkannt.text;
      final treffer = zaehleTreffer(transkript: transkript, erwartet: karte.zuZaehlen);
      final wer = karte.art == KartenArt.satz
          ? wortfehlerrate(soll: karte.sollText, ist: transkript)
          : null;

      await _gw.ergebnisAnlegen(
        SprachErgebnis(
          id: '',
          probeId: probe.id,
          anbieter: anbieter,
          // Was der Dienst TATSAECHLICH benutzt hat — der Rueckfallweg der Edge
          // Function haengt "(ohne Wortliste)" an den Namen. Ohne diese Angabe
          // waeren spaetere Messungen nicht vergleichbar.
          modell: erkannt.modell,
          mitWortliste: true,
          transkript: transkript,
          trefferQuote: treffer.quote,
          wortfehlerrate: wer,
          dauerMs: erkannt.dauerMs,
        ),
      );

      // Danebengegangene Begriffe als Verhoerer melden. Erst der zweite gleiche
      // macht daraus eine Regel (lernschwelle.dart) — ein einzelner Fehltreffer
      // waere Zufall.
      if (treffer.fehlend.isNotEmpty) {
        for (final paar in verhoererAus(erkannt: transkript, korrigiert: karte.sollText)) {
          await _gw.verhoererMelden(
            betriebId: betriebId,
            personId: personId,
            falsch: paar.falsch,
            richtig: paar.richtig,
            quelle: 'training',
          );
        }
      }

      final bilanz = Map<String, Kartenbilanz>.from(jetzt.bilanz);
      final alt = bilanz[karte.sollText];
      final getroffen = treffer.fehlend.isEmpty;
      bilanz[karte.sollText] = Kartenbilanz(
        versuche: (alt?.versuche ?? 0) + 1,
        treffer: (alt?.treffer ?? 0) + (getroffen ? 1 : 0),
      );

      state = AsyncData(
        jetzt.copyWith(
          laeuft: false,
          arbeitet: false,
          bilanz: bilanz,
          letztes: DrillErgebnis(
            sollText: karte.sollText,
            transkript: transkript,
            getroffen: getroffen,
            wortfehler: wer,
          ),
        ),
      );
    } catch (e) {
      // Die Aufnahme liegt bereits im Bestand — sie wird hier ausdruecklich
      // NICHT verworfen. Genau dafuer wird zuerst abgelegt und erst danach
      // erkannt: Was heute nicht erkannt wurde, ist beim naechsten
      // Vollvergleich immer noch da.
      state = AsyncData(jetzt.copyWith(laeuft: false, arbeitet: false, fehler: _klartext(e)));
    }
  }

  void naechste() {
    final jetzt = state.valueOrNull;
    if (jetzt == null) return;
    state = AsyncData(
      jetzt.copyWith(
        karte: naechsteKarte(
          karten: jetzt.stapel,
          bilanz: jetzt.bilanz,
          zuletzt: jetzt.karte?.sollText,
        ),
        letztesLoeschen: true,
      ),
    );
  }

  void abbrechen() {
    _aufnahme?.abbrechen();
    _aufnahme = null;
    final jetzt = state.valueOrNull;
    if (jetzt != null) state = AsyncData(jetzt.copyWith(laeuft: false));
  }
}
