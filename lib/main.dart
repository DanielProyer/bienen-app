import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bienen_app/core/theme/app_theme.dart';
import 'package:bienen_app/core/router/app_router.dart';
import 'package:bienen_app/core/supabase/supabase_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseConfig.initialize();
  runApp(const ProviderScope(child: BienenApp()));
}

class BienenApp extends StatelessWidget {
  const BienenApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Bienen Arosa',
      theme: AppTheme.light,
      routerConfig: appRouter,
      debugShowCheckedModeBanner: false,
    );
  }
}
