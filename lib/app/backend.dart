import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Which backend this build talks to. Cloud mode needs the Supabase URL and
/// anon key passed as dart-defines (see supabase.env.example); without them
/// everything stays on the phone so the app still works end to end.
class Backend {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static bool _cloud = false;
  static bool get isCloud => _cloud;
  static bool get isConfigured => supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  static SupabaseClient get client => Supabase.instance.client;

  static Future<void> init() async {
    if (!isConfigured) return;
    try {
      await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey, authOptions: const FlutterAuthClientOptions(authFlowType: AuthFlowType.pkce));
      _cloud = true;
    } catch (e) {
      debugPrint('[BACKEND] Supabase init failed, running local: $e');
    }
  }

  /// For tests and tools that want to force a mode.
  @visibleForTesting
  static set cloudForTesting(bool v) => _cloud = v;
}
