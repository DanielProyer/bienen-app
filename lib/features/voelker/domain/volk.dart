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

  /// Kopie mit geaenderten Feldern (Muster wie `MaterialItem.copyWith`).
  ///
  /// Ohne das musste jede Aenderung an EINEM Feld das Volk komplett von Hand
  /// neu bauen — dabei fielen still Felder wie `einweiselungAm`, `herkunft`,
  /// `notes` oder `sortOrder` heraus (Datenverlust beim Speichern).
  ///
  /// [standortEntfernen] / [koeniginEntfernen] setzen die jeweilige Zuordnung
  /// explizit auf null. Ein blosses `standortId: null` kann das nicht: das
  /// `??`-Muster unterscheidet nicht zwischen „nicht angegeben" und „null
  /// gewuenscht". Genau das braucht aber ON DELETE SET NULL (Standort bzw.
  /// Koenigin geloescht → Volk verliert die Zuordnung, behaelt alles andere).
  Volk copyWith({
    String? id,
    String? name,
    String? status,
    String? standortId,
    String? koeniginId,
    String? mutterVolkId,
    String? beutentyp,
    int? zargen,
    int? brutwaben,
    String? bioStatus,
    String? gesundheitsstatus,
    DateTime? einweiselungAm,
    String? herkunft,
    String? notes,
    int? sortOrder,
    Koenigin? koenigin,
    Standort? standort,
    bool standortEntfernen = false,
    bool koeniginEntfernen = false,
  }) {
    return Volk(
      id: id ?? this.id,
      name: name ?? this.name,
      status: status ?? this.status,
      standortId: standortEntfernen ? null : (standortId ?? this.standortId),
      koeniginId: koeniginEntfernen ? null : (koeniginId ?? this.koeniginId),
      mutterVolkId: mutterVolkId ?? this.mutterVolkId,
      beutentyp: beutentyp ?? this.beutentyp,
      zargen: zargen ?? this.zargen,
      brutwaben: brutwaben ?? this.brutwaben,
      bioStatus: bioStatus ?? this.bioStatus,
      gesundheitsstatus: gesundheitsstatus ?? this.gesundheitsstatus,
      einweiselungAm: einweiselungAm ?? this.einweiselungAm,
      herkunft: herkunft ?? this.herkunft,
      notes: notes ?? this.notes,
      sortOrder: sortOrder ?? this.sortOrder,
      koenigin: koeniginEntfernen ? null : (koenigin ?? this.koenigin),
      standort: standortEntfernen ? null : (standort ?? this.standort),
    );
  }

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
