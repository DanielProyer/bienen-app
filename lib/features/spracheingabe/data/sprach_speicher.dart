import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Bucket aus Migration T02, privat.
const sprachProbenBucket = 'sprach-proben';

/// Baut den Ablagepfad einer Probe.
///
/// Muss zeichengenau zum CHECK der Tabelle passen
/// (`storage_path like betrieb_id || '/' || person_id || '/%'`) und zu den
/// Storage-Policies, die BEIDE Pfadebenen pruefen. Ein falscher Pfad scheitert
/// an der Policy mit einer Meldung, die den Grund nicht nennt — deshalb steht
/// der Bau hier als eigene, geprueft Funktion.
String probenPfad({
  required String betriebId,
  required String personId,
  required String dateiname,
}) {
  if (betriebId.trim().isEmpty) throw ArgumentError('betriebId fehlt');
  if (personId.trim().isEmpty) throw ArgumentError('personId fehlt');
  if (dateiname.trim().isEmpty) throw ArgumentError('dateiname fehlt');
  return '${betriebId.trim()}/${personId.trim()}/${dateiname.trim()}';
}

/// Endung passend zum aufgenommenen Format. Unbekanntes landet auf `.webm` —
/// der Erkenner erkennt das Format ohnehin am Inhalt, aber eine sinnvolle
/// Endung hilft beim Herunterladen und beim Nachhoeren.
String probenDateiname({required String mime, required String kennung}) {
  final endung = switch (mime.split(';').first.trim()) {
    'audio/mp4' => 'mp4',
    'audio/mpeg' => 'mp3',
    'audio/ogg' => 'ogg',
    'audio/wav' => 'wav',
    _ => 'webm',
  };
  return '$kennung.$endung';
}

/// Legt Tonaufnahmen im privaten Bucket ab. Muster wie `FotoSpeicher`.
class SprachSpeicher {
  final SupabaseClient _c;
  SprachSpeicher(this._c);

  /// Laedt hoch und gibt den Pfad zurueck (nicht die URL — die Tabelle haelt
  /// Pfade, damit sie beim Anzeigen frisch signiert werden koennen).
  ///
  /// `upsert: false` mit Absicht: Die Kennung ist eine UUID, eine Kollision
  /// waere ein Fehler und soll auffallen statt still zu ueberschreiben.
  Future<String> hochladen({
    required String betriebId,
    required String personId,
    required Uint8List bytes,
    required String mime,
    required String kennung,
  }) async {
    final pfad = probenPfad(
      betriebId: betriebId,
      personId: personId,
      dateiname: probenDateiname(mime: mime, kennung: kennung),
    );
    await _c.storage
        .from(sprachProbenBucket)
        .uploadBinary(pfad, bytes, fileOptions: FileOptions(upsert: false, contentType: mime));
    return pfad;
  }

  Future<String> signierteUrl(String pfad, {int ablaufSekunden = 3600}) =>
      _c.storage.from(sprachProbenBucket).createSignedUrl(pfad, ablaufSekunden);
}
