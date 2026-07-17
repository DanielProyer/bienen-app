import 'package:bienen_app/features/voelker/domain/koenigin.dart';
import 'package:bienen_app/features/voelker/domain/standort.dart';

class Volk {
  final String id;
  final String name;
  final String status; // aktiv|aufgeloest|vereinigt|verkauft|verloren
  final String? standortId;
  final String? koeniginId;
  final String? mutterVolkId;
  final String? beutentyp;
  final int? zargen;
  final int? brutwaben;
  final String bioStatus;
  final String gesundheitsstatus;
  final DateTime? einweiselungAm;
  final String? herkunft;
  final String? notes;
  final int sortOrder;
  final Koenigin? koenigin; // via Relation
  final Standort? standort; // via Relation

  const Volk({
    required this.id,
    required this.name,
    this.status = 'aktiv',
    this.standortId,
    this.koeniginId,
    this.mutterVolkId,
    this.beutentyp,
    this.zargen,
    this.brutwaben,
    this.bioStatus = 'unbekannt',
    this.gesundheitsstatus = 'unauffaellig',
    this.einweiselungAm,
    this.herkunft,
    this.notes,
    this.sortOrder = 0,
    this.koenigin,
    this.standort,
  });

  factory Volk.fromJson(Map<String, dynamic> j) {
    final k = j['koenigin'];
    final s = j['standort'];
    return Volk(
      id: j['id'] as String,
      name: j['name'] as String,
      status: (j['status'] as String?) ?? 'aktiv',
      standortId: j['standort_id'] as String?,
      koeniginId: j['koenigin_id'] as String?,
      mutterVolkId: j['mutter_volk_id'] as String?,
      beutentyp: j['beutentyp'] as String?,
      zargen: j['zargen'] as int?,
      brutwaben: j['brutwaben'] as int?,
      bioStatus: (j['bio_status'] as String?) ?? 'unbekannt',
      gesundheitsstatus: (j['gesundheitsstatus'] as String?) ?? 'unauffaellig',
      einweiselungAm: j['einweiselung_am'] != null ? DateTime.parse(j['einweiselung_am'] as String) : null,
      herkunft: j['herkunft'] as String?,
      notes: j['notes'] as String?,
      sortOrder: (j['sort_order'] as int?) ?? 0,
      koenigin: k is Map<String, dynamic> ? Koenigin.fromJson(k) : null,
      standort: s is Map<String, dynamic> ? Standort.fromJson(s) : null,
    );
  }

  Map<String, dynamic> toInsertJson() => {
        'name': name,
        'status': status,
        'standort_id': standortId,
        'koenigin_id': koeniginId,
        'mutter_volk_id': mutterVolkId,
        'beutentyp': beutentyp,
        'zargen': zargen,
        'brutwaben': brutwaben,
        'bio_status': bioStatus,
        'gesundheitsstatus': gesundheitsstatus,
        'einweiselung_am': einweiselungAm?.toIso8601String(),
        'herkunft': herkunft,
        'notes': notes,
        'sort_order': sortOrder,
      };
}
