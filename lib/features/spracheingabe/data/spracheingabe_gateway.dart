import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:bienen_app/features/spracheingabe/domain/lernschwelle.dart';
import 'package:bienen_app/features/spracheingabe/domain/sprach_modelle.dart';

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
  Future<SprachKorrektur?> verhoererMelden({
    required String personId,
    required String falsch,
    required String richtig,
    required String quelle,
  });
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
    final res =
        await _c.from('sprach_karten').insert(karte.toInsertJson()).select().single();
    return SprachKarte.fromJson(res);
  }

  @override
  Future<SprachProbe> probeAnlegen(SprachProbe probe) async {
    final res =
        await _c.from('sprach_proben').insert(probe.toInsertJson()).select().single();
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
    return (res as List)
        .map((j) => SprachErgebnis.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<List<SprachKorrektur>> korrekturenLaden() async {
    final res = await _c.from('sprach_korrekturen').select();
    return (res as List)
        .map((j) => SprachKorrektur.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<SprachKorrektur?> verhoererMelden({
    required String personId,
    required String falsch,
    required String richtig,
    required String quelle,
  }) async {
    final schluessel = falsch.trim().toLowerCase();
    if (schluessel.isEmpty || richtig.trim().isEmpty) return null;

    final vorhanden = await _c
        .from('sprach_korrekturen')
        .select()
        .eq('falsch', schluessel)
        .maybeSingle();

    final treffer = vorhanden == null ? 1 : ((vorhanden['treffer'] as num).toInt() + 1);
    final aktiv = darfRegelWerden(treffer: treffer, richtig: richtig);

    final res = await _c
        .from('sprach_korrekturen')
        .upsert({
          'person_id': personId,
          'falsch': schluessel,
          'richtig': richtig,
          'treffer': treffer,
          'quelle': quelle,
          'aktiv': aktiv,
          'zuletzt_am': DateTime.now().toUtc().toIso8601String(),
        }, onConflict: 'betrieb_id,person_id,falsch')
        .select()
        .single();
    return SprachKorrektur.fromJson(res);
  }
}
