import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bienen_app/core/supabase/supabase_config.dart';
import 'package:bienen_app/features/auth/presentation/auth_providers.dart';
import 'package:bienen_app/features/wissen/data/wissen_foto_repository.dart';
import 'package:bienen_app/features/wissen/domain/wissen_foto.dart';

final wissenFotoRepositoryProvider =
    Provider<WissenFotoRepository>((ref) => WissenFotoRepository(SupabaseConfig.client));

final wissenFotosProvider =
    AsyncNotifierProvider.family<WissenFotosNotifier, List<WissenFoto>, String>(WissenFotosNotifier.new);

class WissenFotosNotifier extends FamilyAsyncNotifier<List<WissenFoto>, String> {
  @override
  Future<List<WissenFoto>> build(String wissenKey) async {
    final betriebId = ref.watch(currentBetriebIdProvider); // watch → Reload bei Betriebswechsel
    if (betriebId == null) return const [];
    return ref.read(wissenFotoRepositoryProvider).ladeFotos(wissenKey: wissenKey, betriebId: betriebId);
  }

  Future<void> ergaenze({required Uint8List jpegBytes, String? beschriftung}) async {
    final betriebId = ref.read(currentBetriebIdProvider);
    if (betriebId == null) return;
    await ref.read(wissenFotoRepositoryProvider)
        .ergaenzeFoto(wissenKey: arg, betriebId: betriebId, jpegBytes: jpegBytes, beschriftung: beschriftung);
    ref.invalidateSelf();
  }

  Future<void> loeschen(WissenFoto foto) async {
    await ref.read(wissenFotoRepositoryProvider).loescheFoto(foto);
    ref.invalidateSelf();
  }
}
