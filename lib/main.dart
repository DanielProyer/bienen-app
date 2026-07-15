import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bienen_app/core/theme/app_theme.dart';
import 'package:bienen_app/core/router/app_router.dart';
import 'package:bienen_app/core/supabase/supabase_config.dart';
import 'package:bienen_app/features/auth/presentation/auth_providers.dart';
import 'package:bienen_app/features/auth/presentation/auth_state.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseConfig.initialize();
  runApp(const ProviderScope(child: BienenApp()));
}

class BienenApp extends ConsumerStatefulWidget {
  const BienenApp({super.key});

  @override
  ConsumerState<BienenApp> createState() => _BienenAppState();
}

class _BienenAppState extends ConsumerState<BienenApp> {
  @override
  void initState() {
    super.initState();
    // Session aufloesen + Auth-Events abonnieren. Eager, sonst wird
    // authSyncProvider nie gebaut. Nach dem ersten Frame, damit initState
    // nicht waehrend des Builds Provider veraendert.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(authSyncProvider);
      ref.read(authControllerProvider.notifier).laden();
    });
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(authControllerProvider).status;

    // Waehrend `laden` bewusst KEIN Router: sonst wuerde das redirect-Gate die
    // URL umschreiben, bevor die Session aufgeloest ist.
    if (status == AuthStatus.laden) {
      return MaterialApp(
        title: 'Bienen Arosa',
        theme: AppTheme.light,
        debugShowCheckedModeBanner: false,
        home: const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return MaterialApp.router(
      title: 'Bienen Arosa',
      theme: AppTheme.light,
      routerConfig: ref.watch(appRouterProvider),
      debugShowCheckedModeBanner: false,
    );
  }
}
