import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trailseek/app/providers.dart';
import 'package:trailseek/app/theme.dart';
import 'package:trailseek/core/widgets/widgets.dart';
import 'package:trailseek/data/repositories/local_store.dart';
import 'package:trailseek/features/dev/gallery_screen.dart';

void main() {
  testWidgets('design gallery renders every component without errors', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    tester.view.physicalSize = const Size(1080, 6000);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [localStoreProvider.overrideWithValue(LocalStore(prefs))],
      child: MaterialApp(theme: buildTheme(), home: const GalleryScreen()),
    ));
    // pumpAndSettle would never finish: the gallery shows a spinning loading button.
    await tester.pump();
    // Let the asset bundle actually read the seed JSON (real IO, not fake-async time).
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 800)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(NeonButton), findsNWidgets(4));
    expect(find.byType(HexBadge), findsNWidgets(6));
    expect(find.byType(XpBar), findsNWidgets(2));
    expect(find.byType(TsBottomNav), findsOneWidget);
    expect(find.text('Very Difficult'), findsOneWidget);
    expect(find.byType(TrekCard), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('XpBar formats thousands and clamps overflow', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: buildTheme(),
      home: const Scaffold(body: XpBar(level: 4, xpInLevel: 1500, xpForLevel: 1250)),
    ));
    expect(find.text('1,500 / 1,250 XP'), findsOneWidget);
  });
}
