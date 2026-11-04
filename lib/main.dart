import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/group_secret_vault.dart';
import 'app/backend.dart';
import 'app/providers.dart';
import 'app/router.dart';
import 'app/theme.dart';
import 'data/repositories/local_store.dart';
import 'features/avatar/avatar_files.dart';
import 'features/progress/reward_host.dart';
import 'features/rope/rope_alerts.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: TsColors.surface,
  ));
  await Backend.init();
  final prefs = await SharedPreferences.getInstance();
  // Load encryption keys before GroupSession.fromJson rehydrates stored groups.
  // If Keychain/Keystore access fails, Bluetooth will fail closed; other app
  // features remain usable.
  try {
    await GroupSecretVault.initialize();
  } catch (e) {
    debugPrint('[SECURITY] Group key vault unavailable: $e');
  }
  AvatarFiles.root = Directory('${(await getApplicationDocumentsDirectory()).path}/avatars');
  await RopeAlerts.instance.init();
  runApp(
    ProviderScope(
      overrides: [localStoreProvider.overrideWithValue(LocalStore(prefs))],
      child: const TrailSeekApp(),
    ),
  );
}

class TrailSeekApp extends ConsumerWidget {
  const TrailSeekApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Trail Seek',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      routerConfig: ref.watch(routerProvider),
      builder: (context, child) => RewardHost(child: child ?? const SizedBox.shrink()),
    );
  }
}
