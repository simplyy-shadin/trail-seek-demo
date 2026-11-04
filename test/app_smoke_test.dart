
import 'package:flutter/material.dart' show Icons;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trailseek/app/providers.dart';
import 'package:trailseek/core/widgets/widgets.dart';
import 'package:trailseek/data/repositories/local_store.dart';
import 'package:trailseek/main.dart';

/// Home shows a spinner until the seed JSON is read from disk; that is real
/// IO, so give it wall-clock time instead of pumpAndSettle (which never
/// settles while the spinner animates).
Future<void> settle(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 2));
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 900)),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
}

void main() {
  testWidgets('first launch shows the splash with Get Started and Log in',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localStoreProvider.overrideWithValue(LocalStore(prefs)),
        ],
        child: const TrailSeekApp(),
      ),
    );

    expect(find.text('Explore · Track · Earn'), findsOneWidget);

    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Get Started'), findsOneWidget);
    expect(find.text('Log in'), findsOneWidget);

    // Browse-first: Get Started lands on Home (the feed), no sign-up.
    await tester.tap(find.text('Get Started'));
    await settle(tester);

    expect(find.text('Post'), findsOneWidget);
    expect(find.text('Top Explorers'), findsOneWidget);
    expect(find.text('Create Account'), findsNothing);

    // Icons-only navigation: tap Explore using its icon.
    await tester.tap(find.byIcon(Icons.explore_outlined));
    await settle(tester);

    expect(find.text('Thrissur'), findsOneWidget);
    expect(find.text('Athirappilly'), findsWidgets);
  });

  testWidgets(
      'a returning user without an account lands on Home, and a gated action asks to sign in',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'onboarded': true,
      'region': 'kerala',
    });

    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localStoreProvider.overrideWithValue(LocalStore(prefs)),
        ],
        child: const TrailSeekApp(),
      ),
    );

    await settle(tester);

    expect(find.text('Post'), findsOneWidget);
    expect(find.text('Create Account'), findsNothing);

    // Navigate to a gated route exactly as a tap on "Create Group" would.
    GoRouter.of(tester.element(find.text('Post'))).push('/group/create');

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Create Account'), findsOneWidget);
    expect(find.text('Full Name'), findsOneWidget);
  });

  testWidgets('returning user with a region lands on Home', (tester) async {
    SharedPreferences.setMockInitialValues({
      'onboarded': true,
      'region': 'kerala',
      'user':
          '{"id":"u1","displayName":"Fayaz FF","email":"f@x.io","username":"fayazff","provider":"email","createdAt":"2026-10-01T00:00:00.000","avatarId":"v1:2.1.0.3.1"}',
    });

    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localStoreProvider.overrideWithValue(LocalStore(prefs)),
        ],
        child: const TrailSeekApp(),
      ),
    );

    await settle(tester);

    expect(find.text('Post'), findsOneWidget);
    expect(find.byType(TsBottomNav), findsOneWidget);

    // Verify the four icons instead of the removed text labels.
    expect(find.byIcon(Icons.home), findsOneWidget);
    expect(find.byIcon(Icons.explore_outlined), findsOneWidget);
    expect(find.byIcon(Icons.map_outlined), findsOneWidget);
    expect(find.byIcon(Icons.account_circle_outlined), findsOneWidget);

    expect(find.text('Community'), findsNothing);
  });
}
