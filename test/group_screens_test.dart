import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trailseek/app/providers.dart';
import 'package:trailseek/app/theme.dart';
import 'package:trailseek/data/models/group_session.dart';
import 'package:trailseek/data/repositories/local_store.dart';
import 'package:trailseek/features/group/create_group_screen.dart';
import 'package:trailseek/features/group/groups_tab.dart';
import 'package:trailseek/features/group/join_group_screen.dart';
import 'package:trailseek/features/group/lobby_screen.dart';
import 'package:trailseek/features/tracking/start_trek_screen.dart';
import 'package:trailseek/features/tracking/tracking_screen.dart';

const _user = '{"id":"u1","displayName":"Fayaz FF","email":"f@x.io","username":"fayazff","provider":"email","createdAt":"2026-10-01T00:00:00.000","avatarId":"v1:2.1.0.3.1"}';

GroupSession demoSession({SessionStatus status = SessionStatus.lobby, int members = 3}) => GroupSession(
      id: 'g1',
      code: '8UH2E4',
      name: 'Test',
      adventureId: 'meesapulimala',
      adventureName: 'Meesapulimala',
      date: DateTime.now(),
      expectedStart: DateTime.now().add(const Duration(hours: 1)),
      plannedSize: 10,
      organizerId: 'u1',
      members: [
        const Member(id: 'u1', displayName: 'Fayaz FF', role: MemberRole.organizer, memberIndex: 0, isSelf: true),
        for (var i = 1; i < members; i++) Member(id: 'sim-$i', displayName: 'Member $i', role: MemberRole.member, memberIndex: i),
      ],
      status: status,
      simulated: true,
    );

Future<ProviderContainer> pump(WidgetTester tester, Widget home, {Map<String, Object> prefs = const {}}) async {
  SharedPreferences.setMockInitialValues({'onboarded': true, 'region': 'kerala', 'user': _user, ...prefs});
  final p = await SharedPreferences.getInstance();
  final c = ProviderContainer(overrides: [localStoreProvider.overrideWithValue(LocalStore(p))]);
  addTearDown(c.dispose);
  // Phone-sized viewport so below-the-fold widgets exist in the tree.
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.5;
  addTearDown(tester.view.reset);
  final router = GoRouter(routes: [
    GoRoute(path: '/', builder: (_, _) => home),
    GoRoute(path: '/group/create', builder: (_, _) => const CreateGroupScreen()),
    GoRoute(path: '/group/join', builder: (_, _) => const JoinGroupScreen()),
    GoRoute(path: '/group/:id/lobby', builder: (_, s) => LobbyScreen(sessionId: s.pathParameters['id']!)),
    GoRoute(path: '/group/:id/checklist', builder: (_, _) => const Scaffold(body: Text('CHECKLIST'))),
    GoRoute(path: '/track/start', builder: (_, _) => const StartTrekScreen()),
  ]);
  await tester.pumpWidget(UncontrolledProviderScope(container: c, child: MaterialApp.router(theme: buildTheme(), routerConfig: router)));
  await tester.pump();
  return c;
}

void main() {
  testWidgets('Groups tab: empty state explains the rope and offers create/join', (tester) async {
    await pump(tester, const GroupsTab());
    expect(find.text('Go together, stay together'), findsOneWidget);
    expect(find.text('Create Group'), findsOneWidget);
    expect(find.text('Join'), findsOneWidget);
  });

  testWidgets('Groups tab lists live, upcoming and past sessions', (tester) async {
    final sessions = [demoSession(status: SessionStatus.active), demoSession(status: SessionStatus.completed)];
    final json = jsonEncode([for (final (i, s) in sessions.indexed) (s.toJson()..['id'] = 'g$i')]);
    await pump(tester, const GroupsTab(), prefs: {'sessions': json});
    expect(find.text('LIVE'), findsOneWidget);
    expect(find.text('Past'), findsOneWidget);
    expect(find.text('Test'), findsNWidgets(2));
  });

  testWidgets('Create Group defaults to a real Bluetooth group, not demo', (tester) async {
    await pump(tester, const CreateGroupScreen());
    final sw = tester.widget<SwitchListTile>(find.byType(SwitchListTile));
    expect(sw.value, isFalse);
    expect(find.text('Try a demo instead (no other phones)'), findsOneWidget);
    expect(find.text('Create Group'), findsOneWidget);
  });

  testWidgets('Join screen rejects short codes and pre-fills from a deep link', (tester) async {
    await pump(tester, const JoinGroupScreen(prefillCode: 'ab12'));
    expect(find.text('Join a Group'), findsOneWidget);
    final field = tester.widget<TextField>(find.byType(TextField).first);
    expect(field.controller!.text, isEmpty); // 4 chars → not auto-filled
    await tester.tap(find.text('Join Group'));
    await tester.pump();
    expect(find.text('Codes are 6 characters.'), findsOneWidget);
  });

  testWidgets('Lobby shows code, QR, members, and per-phone start wording for demo groups', (tester) async {
    await pump(tester, LobbyScreen(sessionId: 'g1'), prefs: {'sessions': jsonEncode([demoSession().toJson()])});
    await tester.pump();
    expect(find.text('8UH2E4'), findsOneWidget);
    expect(find.text('3 / 10 Members Joined'), findsOneWidget);
    expect(find.text('Add demo members'), findsOneWidget);
    expect(find.text('Start Adventure'), findsOneWidget);
    expect(find.text('Fayaz FF (you)'), findsOneWidget);
  });

  testWidgets('Lobby with one member cannot start yet', (tester) async {
    await pump(tester, LobbyScreen(sessionId: 'g1'), prefs: {'sessions': jsonEncode([demoSession(members: 1).toJson()])});
    await tester.pump();
    expect(find.text('Need at least 2 members to start Digital Rope.'), findsOneWidget);
    final btn = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Start Adventure'));
    expect(btn.onPressed, isNull);
  });

  testWidgets('Start Trek shows activity types and a trail picker; tracking screen idles without a session', (tester) async {
    await pump(tester, const StartTrekScreen());
    expect(find.text('Trekking'), findsOneWidget);
    expect(find.text('Kayaking'), findsOneWidget);
    expect(find.text('Free trek'), findsOneWidget);
    expect(find.text('Start Recording'), findsOneWidget);

    await pump(tester, const TrackingScreen());
    expect(find.text('Start a trek'), findsOneWidget);
  });
}
