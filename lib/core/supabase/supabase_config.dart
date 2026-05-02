import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  static const String supabaseUrl = 'https://dcdcohktxbhdxnxjvcyp.supabase.co';
  static const String supabaseAnonKey = 'sb_publishable_oom_C1ge27zL43WKG9UB0Q_60SjI02N';

  static Future<void> initialize() async {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );
  }

  static SupabaseClient get client => Supabase.instance.client;
}
