import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:bienen_app/features/benachrichtigungen/domain/benachrichtigungs_einstellungen.dart';

/// Zugriff auf die persoenlichen Benachrichtigungs-Einstellungen.
/// RLS laesst nur die EIGENE Zeile durch (Migration O01) — deshalb braucht
/// keine Abfrage hier einen user_id-Filter.
class BenachrichtigungenGateway {
  final SupabaseClient _c;
  BenachrichtigungenGateway(this._c);

  static const _tabelle = 'benachrichtigungs_einstellungen';

  /// Die eigene Zeile — oder null, solange noch keine angelegt wurde.
  Future<BenachrichtigungsEinstellungen?> laden() async {
    final res = await _c.from(_tabelle).select().maybeSingle();
    return res == null ? null : BenachrichtigungsEinstellungen.fromJson(res);
  }

  /// Legt an oder aktualisiert. Gibt die gespeicherte Zeile MIT id zurueck
  /// (`.select().single()`) — ohne die id koennte der Aufrufer den frisch
  /// angelegten Datensatz nicht weiterverwenden (Lehre aus D-76).
  Future<BenachrichtigungsEinstellungen> speichern(
    BenachrichtigungsEinstellungen e,
    String userId,
  ) async {
    final json = e.toUpdateJson();
    final res = e.id.isEmpty
        ? await _c
            .from(_tabelle)
            .insert({...json, 'user_id': userId})
            .select()
            .single()
        : await _c.from(_tabelle).update(json).eq('id', e.id).select().single();
    return BenachrichtigungsEinstellungen.fromJson(res);
  }

  /// Loest eine Testnachricht aus. Die Edge Function erkennt den Nutzer am
  /// mitgeschickten JWT und sendet nur an die eigene Chat-ID.
  Future<void> testnachricht() async {
    final FunctionResponse res;
    try {
      res = await _c.functions.invoke('taeglicher-ueberblick');
    } on FunctionException catch (e) {
      throw Exception(_klartext(e));
    }
    // Die Function antwortet auch dann mit 200, wenn sie NICHT gesendet hat
    // (z.B. fehlende Chat-ID). Das still als Erfolg zu melden waere die
    // schlimmste Variante — der Nutzer wartet dann auf eine Nachricht, die nie
    // kommt. Also den gemeldeten Status auswerten.
    final daten = res.data;
    final status = daten is Map ? daten['status'] as String? : null;
    if (status != null && status != 'gesendet') {
      throw Exception(_statusKlartext(status));
    }
  }

  String _statusKlartext(String status) => switch (status) {
        'keine-chat-id' => 'Keine Chat-ID hinterlegt — zuerst eintragen und speichern.',
        'blockiert-deaktiviert' =>
          'Der Bot ist in Telegram blockiert. Blockierung aufheben, dann erneut testen.',
        'nichts-zu-tun' => 'Aktuell steht nichts an — es wurde nichts gesendet.',
        _ => 'Testnachricht nicht gesendet ($status).',
      };

  String _klartext(FunctionException e) {
    final details = e.details;
    final text = details is String ? details.trim() : '';
    return switch (e.status) {
      401 => 'Nicht berechtigt — bitte neu anmelden.',
      404 => 'Noch keine Einstellungen gespeichert. Zuerst speichern, dann testen.',
      _ => text.isEmpty
          ? 'Testnachricht fehlgeschlagen (Status ${e.status}).'
          : 'Testnachricht fehlgeschlagen: $text',
    };
  }
}
