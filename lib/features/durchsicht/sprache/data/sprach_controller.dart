import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bienen_app/features/durchsicht/sprache/domain/sprache_erkenner.dart';
import 'package:bienen_app/features/durchsicht/sprache/data/web_sprache_erkenner.dart';

final spracheErkennerProvider = Provider<SpracheErkenner>((ref) {
  final e = WebSpracheErkenner();
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

  @override
  SprachZustand build() {
    ref.onDispose(() { _subErg?.cancel(); _subSt?.cancel(); });
    return const SprachZustand();
  }

  bool get verfuegbar => _e.verfuegbar;

  /// Startet [mikroId]; ein bereits aktives anderes Mikro wird gestoppt.
  Future<void> starten(String mikroId, void Function(String endText) onEndText) async {
    if (!_e.verfuegbar) { state = state.kopie(status: ErkennerStatus.fehler); return; }
    _onEnd = onEndText;
    _subErg ??= _e.ergebnisse.listen((r) {
      if (r.endgueltig) { _onEnd?.call(r.text); state = state.kopie(interim: ''); }
      else { state = state.kopie(interim: r.text); }
    });
    _subSt ??= _e.status.listen((s) => state = state.kopie(status: s));
    await _e.starten();
    state = state.kopie(aktivesMikro: mikroId, status: ErkennerStatus.hoert, interim: '');
  }

  Future<void> stoppen() async {
    _onEnd = null;
    await _e.stoppen();
    state = state.kopie(aktivesMikro: null, status: ErkennerStatus.idle, interim: '');
  }
}
