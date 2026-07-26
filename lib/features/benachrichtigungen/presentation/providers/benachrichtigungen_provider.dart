import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bienen_app/core/supabase/supabase_config.dart';
import 'package:bienen_app/features/auth/presentation/auth_providers.dart';
import 'package:bienen_app/features/benachrichtigungen/data/benachrichtigungen_gateway.dart';
import 'package:bienen_app/features/benachrichtigungen/domain/benachrichtigungs_einstellungen.dart';

final benachrichtigungenGatewayProvider = Provider<BenachrichtigungenGateway>(
    (ref) => BenachrichtigungenGateway(SupabaseConfig.client));

/// `null` = fuer dieses Mitglied wurde noch nie etwas gespeichert.
final benachrichtigungenProvider = AsyncNotifierProvider<BenachrichtigungenNotifier,
    BenachrichtigungsEinstellungen?>(BenachrichtigungenNotifier.new);

class BenachrichtigungenNotifier
    extends AsyncNotifier<BenachrichtigungsEinstellungen?> {
  BenachrichtigungenGateway get _gw => ref.read(benachrichtigungenGatewayProvider);

  @override
  Future<BenachrichtigungsEinstellungen?> build() => _gw.laden();

  Future<void> speichern(BenachrichtigungsEinstellungen e) async {
    final userId = ref.read(authControllerProvider).session?.userId;
    if (userId == null) {
      throw Exception('Nicht angemeldet — Einstellungen koennen nicht gespeichert werden.');
    }
    await _gw.speichern(e, userId);
    ref.invalidateSelf();
  }

  /// Danach neu laden: die Function schaltet nach erfolgreichem Test `aktiv`
  /// ein — ohne Refetch bliebe die Seite auf dem alten Stand stehen.
  Future<void> testnachricht() async {
    try {
      await _gw.testnachricht();
    } finally {
      ref.invalidateSelf();
    }
  }
}
