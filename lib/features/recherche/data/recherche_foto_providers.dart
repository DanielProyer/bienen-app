import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bienen_app/core/supabase/supabase_config.dart';
import 'package:bienen_app/features/auth/presentation/auth_providers.dart';
import 'package:bienen_app/features/recherche/data/recherche_foto_repository.dart';
import 'package:bienen_app/features/recherche/domain/recherche_foto.dart';

final rechercheFotoRepositoryProvider = Provider<RechercheFotoRepository>(
    (ref) => RechercheFotoRepository(SupabaseConfig.client));

/// Alle eigenen Fotos eines Recherche-Dokuments (Familie über den Dokument-Key).
final rechercheFotosProvider = AsyncNotifierProvider.family<
    RechercheFotosNotifier, List<RechercheFoto>, String>(
  RechercheFotosNotifier.new,
);

class RechercheFotosNotifier
    extends FamilyAsyncNotifier<List<RechercheFoto>, String> {
  @override
  Future<List<RechercheFoto>> build(String rechercheKey) async {
    // watch → lädt bei Betriebswechsel neu
    final betriebId = ref.watch(currentBetriebIdProvider);
    if (betriebId == null) return const [];
    return ref.read(rechercheFotoRepositoryProvider).ladeFotos(
          rechercheKey: rechercheKey,
          betriebId: betriebId,
        );
  }

  Future<void> ergaenze({
    required Uint8List jpegBytes,
    String? anker,
    String? beschriftung,
  }) async {
    final betriebId = ref.read(currentBetriebIdProvider);
    if (betriebId == null) return;
    await ref.read(rechercheFotoRepositoryProvider).ergaenzeFoto(
          rechercheKey: arg,
          betriebId: betriebId,
          jpegBytes: jpegBytes,
          anker: anker,
          beschriftung: beschriftung,
        );
    ref.invalidateSelf();
  }

  Future<void> loeschen(RechercheFoto foto) async {
    await ref.read(rechercheFotoRepositoryProvider).loescheFoto(foto);
    ref.invalidateSelf();
  }
}
