import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/auth_screen.dart';
import '../features/avatar/avatar_screens.dart';
import '../features/avatar/avatar_creator.dart';
import '../features/dev/gallery_screen.dart';
import '../features/discovery/adventure_detail_screen.dart';
import '../features/discovery/adventure_list_screen.dart';
import '../features/discovery/destination_screen.dart';
import '../features/booking/booking_screen.dart';
import '../features/booking/payment_screen.dart';
import '../features/booking/ticket_screen.dart';
import '../features/booking/my_bookings_screen.dart';
import '../features/booking/booking_controller.dart';
import '../features/community/community_tab.dart';
import '../features/community/compose_post_screen.dart';
import '../features/community/people_screens.dart';
import '../features/group/groups_tab.dart';
import '../features/explore/explore_tab.dart';
import '../features/explore/map_tab.dart';
import 'home_shell.dart';
import '../features/group/checklist_screen.dart';
import '../features/group/create_group_screen.dart';
import '../features/group/join_group_screen.dart';
import '../features/group/lobby_screen.dart';
import '../features/onboarding/intro_screen.dart';
import '../features/onboarding/region_select_screen.dart';
import '../features/onboarding/splash_screen.dart';
import '../features/plan/plan_adventure_screen.dart';
import '../features/profile/profile_tab.dart';
import '../features/settings/settings_screen.dart';
import '../features/settings/ble_diagnostics_screen.dart';
import '../features/maps/offline_maps_screen.dart';
import '../features/plan/saved_tab.dart';
import '../features/plan/solo_plan_screen.dart';
import '../features/plan/trails_tab.dart';
import '../features/rope/live_tracking_screen.dart';
import '../features/tracking/start_trek_screen.dart';
import '../features/tracking/tracking_screen.dart';
import '../features/activity/activity_history_screen.dart';
import '../features/activity/activity_summary_screen.dart';
import '../features/progress/reward_host.dart';
import 'providers.dart';

class _RouterRefresh extends ChangeNotifier {
  void ping() => notifyListeners();
}

/// Paths that require a signed-in user. The gate fires on the first
/// meaningful action, never on launch, and returns to the interrupted flow.
bool _isGated(String path) =>
    path.startsWith('/group') || path.startsWith('/track') || path.startsWith('/avatar') || path.startsWith('/book') || path == '/community/compose' || path == '/people' || path.endsWith('/plan') || path.endsWith('/solo');

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _RouterRefresh();
  ref.listen(authProvider, (_, _) => refresh.ping());
  ref.onDispose(refresh.dispose);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/splash',
    refreshListenable: refresh,
    redirect: (context, state) {
      // trailseek://join/8UH2E4 (QR / invite link) → the join screen with the code filled in.
      if (state.uri.scheme == 'trailseek' || state.uri.host == 'join' || state.uri.host == 'diag') {
        if (state.uri.host == 'diag') {
          final q = state.uri.queryParameters;
          return Uri(path: '/settings/ble', queryParameters: {for (final e in q.entries) e.key: e.value}).toString();
        }
        final code = state.uri.pathSegments.isNotEmpty ? state.uri.pathSegments.last : state.uri.queryParameters['code'];
        if (code != null && code.isNotEmpty) {
          return Uri(path: '/group/join', queryParameters: {
            'code': code,
            if (state.uri.queryParameters['key'] != null) 'key': state.uri.queryParameters['key']!,
          }).toString();
        }
        return '/home';
      }
      final signedIn = ref.read(authProvider) != null;
      final path = state.uri.path;
      if (!signedIn && _isGated(path)) {
        return Uri(path: '/auth', queryParameters: {'redirect': state.uri.toString()}).toString();
      }
      if (signedIn && path == '/auth') {
        return state.uri.queryParameters['redirect'] ?? '/home';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, _) => const SplashScreen()),
      GoRoute(path: '/intro', builder: (_, _) => const IntroScreen()),
      GoRoute(path: '/region', builder: (_, _) => const RegionSelectScreen()),
      GoRoute(
        path: '/auth',
        builder: (_, s) => AuthScreen(
          redirect: s.uri.queryParameters['redirect'],
          initialMode: s.uri.queryParameters['mode'] == 'login' ? AuthMode.login : AuthMode.signup,
        ),
      ),
      GoRoute(path: '/avatar', builder: (_, _) => const AvatarCreatorScreen()),
      GoRoute(path: '/avatar/photo', redirect: (_, _) => '/avatar'),
      GoRoute(path: '/avatar/customize', redirect: (_, _) => '/avatar'),
      GoRoute(path: '/avatar/done', builder: (_, _) => const ProfileCreatedScreen()),
      GoRoute(path: '/gallery', builder: (_, _) => const GalleryScreen()),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => HomeShell(shell: shell),
        branches: [
          // Explore first: the app opens on programmes; the social feed is second.
          StatefulShellBranch(routes: [GoRoute(path: '/home', builder: (_, _) => const ExploreTab())]),
          StatefulShellBranch(routes: [GoRoute(path: '/feed', builder: (_, _) => const CommunityTab())]),
          StatefulShellBranch(routes: [GoRoute(path: '/map', builder: (_, _) => const MapTab())]),
          StatefulShellBranch(routes: [GoRoute(path: '/profile', builder: (_, _) => const ProfileTab())]),
        ],
      ),
      GoRoute(path: '/groups', builder: (_, _) => const GroupsTab()),
      GoRoute(path: '/community', redirect: (_, _) => '/feed'),
      GoRoute(path: '/explore', redirect: (_, _) => '/home'),
      GoRoute(path: '/saved', builder: (_, _) => const SavedTab()),
      GoRoute(path: '/community/compose', builder: (_, _) => const ComposePostScreen()),
      GoRoute(path: '/people', builder: (_, _) => const PeopleScreen()),
      GoRoute(path: '/user/:id', builder: (_, s) => UserProfileScreen(userId: s.pathParameters['id']!)),
      GoRoute(path: '/user/:id/followers', builder: (_, s) => FollowListScreen(userId: s.pathParameters['id']!, followers: true)),
      GoRoute(path: '/user/:id/following', builder: (_, s) => FollowListScreen(userId: s.pathParameters['id']!, followers: false)),
      GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
      GoRoute(path: '/settings/ble', builder: (_, s) => BleDiagnosticsScreen(autoCode: s.uri.queryParameters['code'], autoHost: s.uri.queryParameters['host'] == '1', autoName: s.uri.queryParameters['name'], autoSendAfter: int.tryParse(s.uri.queryParameters['send'] ?? ''))),
      GoRoute(path: '/settings/offline-maps', builder: (_, _) => const OfflineMapsScreen()),
      GoRoute(path: '/activities', builder: (_, _) => const ActivityHistoryScreen()),
      GoRoute(path: '/track/start', builder: (_, s) => StartTrekScreen(adventureId: s.uri.queryParameters['adventure'])),
      GoRoute(path: '/track', builder: (_, _) => const TrackingScreen()),
      GoRoute(
        path: '/activity/:id',
        builder: (_, s) => ActivitySummaryScreen(activityId: s.pathParameters['id']!, celebrate: s.uri.queryParameters['celebrate'] == '1'),
      ),
      GoRoute(path: '/trails', builder: (_, _) => const TrailsTab()),
      GoRoute(path: '/destination/:id', builder: (_, s) => DestinationScreen(id: s.pathParameters['id']!)),
      GoRoute(path: '/book/:id', builder: (_, s) => BookingScreen(adventureId: s.pathParameters['id']!)),
      GoRoute(path: '/book/:id/pay', builder: (_, s) => PaymentScreen(draft: s.extra as BookingDraft)),
      GoRoute(path: '/bookings', builder: (_, _) => const MyBookingsScreen()),
      GoRoute(path: '/booking/:id', builder: (_, s) => TicketScreen(bookingId: s.pathParameters['id']!)),
      GoRoute(
        path: '/adventures',
        builder: (_, s) => AdventureListScreen(categoryKey: s.uri.queryParameters['category']),
      ),
      GoRoute(
        path: '/adventure/:id',
        builder: (_, s) => AdventureDetailScreen(id: s.pathParameters['id']!),
        routes: [
          GoRoute(path: 'plan', builder: (_, s) => PlanAdventureScreen(adventureId: s.pathParameters['id']!)),
          GoRoute(path: 'solo', builder: (_, s) => SoloPlanScreen(adventureId: s.pathParameters['id']!)),
        ],
      ),
      GoRoute(path: '/group/create', builder: (_, s) => CreateGroupScreen(adventureId: s.uri.queryParameters['adventure'])),
      GoRoute(path: '/group/join', builder: (_, s) => JoinGroupScreen(adventureId: s.uri.queryParameters['adventure'], prefillCode: s.uri.queryParameters['code'], prefillKey: s.uri.queryParameters['key'])),
      GoRoute(path: '/group/:id/lobby', builder: (_, s) => LobbyScreen(sessionId: s.pathParameters['id']!)),
      GoRoute(path: '/group/:id/checklist', builder: (_, s) => ChecklistScreen(sessionId: s.pathParameters['id']!)),
      GoRoute(path: '/group/:id/live', builder: (_, s) => LiveTrackingScreen(sessionId: s.pathParameters['id']!)),
      GoRoute(path: '/group/:id/summary', builder: (_, s) => ActivitySummaryScreen(activityId: 'session-${s.pathParameters['id']!}', celebrate: true)),
    ],
  );
});
