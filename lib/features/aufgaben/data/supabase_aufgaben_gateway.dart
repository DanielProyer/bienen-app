import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:bienen_app/features/aufgaben/domain/aufgabe.dart';
import 'package:bienen_app/features/aufgaben/domain/aufgaben_gateway.dart';

class SupabaseAufgabenGateway implements AufgabenGateway {
  final SupabaseClient _c;
  SupabaseAufgabenGateway(this._c);

  Never _rethrow(Object e) {
    if (e is PostgrestException && e.code != null) {
      throw AufgabenFehler(e.code!, e.message);
    }
    throw e;
  }

  @override
  Future<List<Aufgabe>> alle() async {
    try {
      final res = await _c.from('aufgaben').select().order('faellig_am', ascending: true);
      return (res as List).map((j) => Aufgabe.fromJson(j as Map<String, dynamic>)).toList();
    } catch (e) {
      _rethrow(e);
    }
  }

  @override
  Future<void> speichern(Aufgabe a) async {
    try {
      final json = a.toInsertJson();
      if (a.id.isEmpty) {
        await _c.from('aufgaben').insert(json);
      } else {
        await _c.from('aufgaben').update(json).eq('id', a.id);
      }
    } catch (e) {
      _rethrow(e);
    }
  }

  @override
  Future<void> speichernBatch(List<Aufgabe> aufgaben) async {
    if (aufgaben.isEmpty) return;
    try {
      await _c.from('aufgaben').insert(aufgaben.map((a) => a.toInsertJson()).toList());
    } on PostgrestException catch (e) {
      if (e.code == '23505') return; // Dedup-Index: Doppelklick, still ignorieren
      _rethrow(e);
    } catch (e) {
      _rethrow(e);
    }
  }

  @override
  Future<void> setzeStatus(String id, String status, {DateTime? erledigtAm}) async {
    try {
      await _c.from('aufgaben').update({
        'status': status,
        'erledigt_am': erledigtAm?.toIso8601String(),
      }).eq('id', id);
    } catch (e) {
      _rethrow(e);
    }
  }

  @override
  Future<void> loeschen(String id) async {
    try {
      await _c.from('aufgaben').delete().eq('id', id);
    } catch (e) {
      _rethrow(e);
    }
  }
}
