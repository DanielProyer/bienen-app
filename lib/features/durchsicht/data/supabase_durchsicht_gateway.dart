import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:bienen_app/core/storage/foto_speicher.dart';
import 'package:bienen_app/features/durchsicht/domain/durchsicht.dart';
import 'package:bienen_app/features/durchsicht/domain/durchsicht_gateway.dart';

class SupabaseDurchsichtGateway implements DurchsichtGateway {
  final SupabaseClient _c;
  late final FotoSpeicher _fotos = FotoSpeicher(_c, 'inspection-photos');
  SupabaseDurchsichtGateway(this._c);

  Never _rethrow(Object e) {
    if (e is PostgrestException && e.code != null) {
      throw DurchsichtFehler(e.code!, e.message);
    }
    throw e;
  }

  @override
  Future<List<Durchsicht>> fuerVolk(String volkId) async {
    try {
      final res = await _c
          .from('inspections')
          .select()
          .eq('volk_id', volkId)
          .order('durchgefuehrt_am', ascending: false);
      return (res as List).map((j) => Durchsicht.fromJson(j as Map<String, dynamic>)).toList();
    } catch (e) {
      _rethrow(e);
    }
  }

  @override
  Future<List<Durchsicht>> letzteJeVolk() async {
    final res = await _c.from('v_letzte_durchsichten').select();
    return (res as List).map((j) => Durchsicht.fromJson(j as Map<String, dynamic>)).toList();
  }

  @override
  Future<void> speichern(Durchsicht d) async {
    try {
      final json = d.toInsertJson();
      if (d.id.isEmpty) {
        await _c.from('inspections').insert(json);
      } else {
        await _c.from('inspections').update(json).eq('id', d.id);
      }
    } catch (e) {
      _rethrow(e);
    }
  }

  @override
  Future<void> loeschen(Durchsicht d) async {
    // Loeschpflicht: erst Storage-Objekte, dann die Zeile.
    await fotoEntfernen(d.fotoUrls);
    await _c.from('inspections').delete().eq('id', d.id);
  }

  @override
  Future<String> fotoHochladen({required String betriebId, required String gruppeId, required Uint8List bytes}) =>
      _fotos.hochladen(betriebId: betriebId, gruppeId: gruppeId, bytes: bytes);

  @override
  Future<String> fotoSignedUrl(String pfad) => _fotos.signedUrl(pfad);

  @override
  Future<void> fotoEntfernen(List<String> pfade) async {
    try {
      await _fotos.entfernen(pfade);
    } catch (_) {
      // best-effort: Foto-Reste blockieren das Loeschen der Durchsicht nicht.
    }
  }
}
