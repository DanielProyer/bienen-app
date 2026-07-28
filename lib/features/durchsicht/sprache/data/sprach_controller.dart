import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bienen_app/features/durchsicht/sprache/domain/sprache_erkenner.dart';
// Bedingter Import: Web bekommt die dart:js_interop-Kapsel, VM/Tests einen No-op-Stub
// (js_interop baut nur auf dem Web-Ziel). Öffentliche Schnittstelle bleibt SpracheErkenner.
import 'package:bienen_app/features/durchsicht/sprache/data/erkenner_plattform_stub.dart'
    if (dart.library.js_interop) 'package:bienen_app/features/durchsicht/sprache/data/erkenner_plattform_web.dart';

final spracheErkennerProvider = Provider<SpracheErkenner>((ref) {
  final e = spracheErkennerErstellen();
  ref.onDispose(e.dispose);
  return e;
});

class SprachZustand {
  final String? aktivesMikro;   // null = kein Mikro aktiv
  final ErkennerStatus status;
  final String interim;         // Live-Teiltranskript
  const SprachZustand({this.aktivesMikro, this.status = ErkennerStatus.idle, this.interim = ''});
  SprachZustand kopie({String? aktivesMikro = _keep, ErkennerStatus? status, String? interim}) => SprachZustand(
        aktivesMikro: aktivesMikro == _keep ? this.aktivesMikro : aktivesMikro,
        status: status ?? this.status, interim: interim ?? this.interim);
  static const _keep = '__keep__';
}

final sprachControllerProvider = NotifierProvider<SprachController, SprachZustand>(SprachController.new);

class SprachController extends Notifier<SprachZustand> {
  SpracheErkenner get _e => ref.read(spracheErkennerProvider);
  StreamSubscription? _subErg, _subSt;
  void Function(String endText)? _onEnd;

  /// Im Einzelsatz-Modus endet die Aufnahme nach dem ersten fertigen Satz.
  bool _einzelsatz = false;

  @override
  SprachZustand build() {
    ref.onDispose(() { _subErg?.cancel(); _subSt?.cancel(); });
    return const SprachZustand();
  }

  bool get verfuegbar => _e.verfuegbar;

  /// Startet [mikroId]; ein bereits aktives anderes Mikro wird gestoppt.
  ///
  /// [einzelsatz] schaltet den Dauer-Modus ab: Die Aufnahme endet nach dem
  /// ersten abgeschlossenen Satz von selbst. Das ist der richtige Modus für
  /// Kommandos — man sagt „Temperatur zwanzig Grad", und danach soll Ruhe sein.
  /// Fürs Diktat bleibt der Dauer-Modus, weil man dort durchspricht.
  Future<void> starten(
    String mikroId,
    void Function(String endText) onEndText, {
    bool einzelsatz = false,
  }) async {
    if (!_e.verfuegbar) { state = state.kopie(status: ErkennerStatus.fehler); return; }
    // Das stand bisher nur im Kommentar: Beim Wechsel auf ein anderes Mikro
    // (Wizard-Seite gewechselt) muss der laufende Erkenner erst enden. Sonst
    // liefen zwei parallel und starteten sich endlos gegenseitig neu — der
    // gemeldete Mikro-Loop vom 2026-07-27.
    if (state.aktivesMikro != null && state.aktivesMikro != mikroId) {
      await _e.stoppen();
    }
    _onEnd = onEndText;
    _einzelsatz = einzelsatz;

    _subErg ??= _e.ergebnisse.listen((r) {
      if (!r.endgueltig) { state = state.kopie(interim: r.text); return; }
      _onEnd?.call(r.text);
      state = state.kopie(interim: '');
      // Ein Kommando ist mit dem Satz erledigt — Mikro aus, ohne Zutun.
      if (_einzelsatz) stoppen();
    });

    _subSt ??= _e.status.listen((s) {
      // Endet die Erkennung von selbst (Einzelsatz, Zeitablauf, Fehler), muss
      // auch der Knopf zurückfallen. Sonst sieht das Mikro aktiv aus, obwohl
      // nichts mehr aufgenommen wird.
      state = s == ErkennerStatus.idle
          ? state.kopie(aktivesMikro: null, status: s, interim: '')
          : state.kopie(status: s);
    });

    await _e.starten(kontinuierlich: !einzelsatz);
    state = state.kopie(aktivesMikro: mikroId, status: ErkennerStatus.hoert, interim: '');
  }

  Future<void> stoppen() async {
    _onEnd = null;
    await _e.stoppen();
    state = state.kopie(aktivesMikro: null, status: ErkennerStatus.idle, interim: '');
  }
}
