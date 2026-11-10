import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/widgets/widgets.dart';
import '../../features/progress/progress.dart';
import '../activity/activity_history_screen.dart';
import '../avatar/avatar_screens.dart';
import '../community/character_sheet_view.dart';
import '../community/explorers.dart';
import '../settings/settings_controller.dart';

IconData badgeIcon(String key) => switch (key) {
      'flag' => Icons.flag,
      'terrain' => Icons.terrain,
      'forest' => Icons.forest,
      'pedal_bike' => Icons.pedal_bike,
      'kayaking' => Icons.kayaking,
      'wb_twilight' => Icons.wb_twilight,
      'nightlight' => Icons.nightlight,
      'groups' => Icons.groups,
      'link' => Icons.link,
      _ => Icons.emoji_events,
    };

/// Frame 12: the player card.
class ProfileTab extends ConsumerStatefulWidget {
  const ProfileTab({super.key});
  @override
  ConsumerState<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends ConsumerState<ProfileTab> {
  int _segment = 0;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider);
    final progress = ref.watch(progressProvider);
    final avatar = ref.watch(currentAvatarProvider);
    final units = ref.watch(unitsProvider);
    final saved = ref.watch(savedProvider);

    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        actions: [IconButton(onPressed: () => context.push('/settings'), icon: const Icon(Icons.settings_outlined))],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 110), // clear of the floating bottom bar
        children: [
          Row(
            children: [
              AvatarRing(
                initials: user?.initials ?? '?',
                avatar: user == null ? null : avatar,
                avatarId: user?.avatarId,
                size: 84,
                onEdit: user == null ? null : () => context.push('/avatar'),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user == null ? 'Not signed in' : (user.username.isNotEmpty ? user.username : user.displayName), style: TsText.h2),
                    Text(user == null ? 'Sign in to track progress' : progress.title, style: TsText.caption.copyWith(color: TsColors.neon, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    XpBar(level: progress.level, xpInLevel: progress.xpInLevel, xpForLevel: progress.xpForLevel, height: 6),
                  ],
                ),
              ),
            ],
          ),
          if (user == null) ...[
            const SizedBox(height: 14),
            NeonButton(label: 'Sign in', onPressed: () => context.push('/auth?redirect=/profile')),
          ],
          const SizedBox(height: 16),
          SegmentTabs(labels: const ['Adventurer', 'History', 'Account'], selected: _segment, onChanged: (i) => setState(() => _segment = i)),
          const SizedBox(height: 16),
          switch (_segment) {
            0 => Builder(builder: (_) {
                final dir = ref.watch(explorerDirectoryProvider).value;
                final rank = dir == null ? null : 1 + dir.people.where((p) => p.xp > progress.totalXp).length;
                return CharacterSheetView(sheet: CharacterSheet(ref.watch(activitiesProvider)), rank: user == null ? null : rank, showLevel: false);
              }),
            1 => const _History(),
            _ => _Stats(progress, units, saved.length),
          },
        ],
      ),
    );
  }
}

class _Stats extends StatelessWidget {
  const _Stats(this.p, this.units, this.savedCount);
  final ProgressState p;
  final dynamic units;
  final int savedCount;

  @override
  Widget build(BuildContext context) {
    final s = p.stats;
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: StatCard(icon: Icons.hiking, value: '${s.activityCount}', label: 'Treks')),
            const SizedBox(width: 10),
            Expanded(child: StatCard(icon: Icons.verified, value: '${p.badgeCount}', label: 'Badges')),
            const SizedBox(width: 10),
            Expanded(child: StatCard(icon: Icons.emoji_events, value: '${p.achievementCount}', label: 'Achievements', color: TsColors.warning)),
          ],
        ),
        const SizedBox(height: 10),
        TsCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              _row(Icons.straighten, 'Total distance', units.distanceKm(s.totalDistanceKm)),
              const Divider(indent: 52),
              _row(Icons.trending_up, 'Elevation gain', units.elevationM(s.totalGainM)),
              const Divider(indent: 52),
              _row(Icons.route, 'Longest trek', units.distanceM(s.longestDistanceM)),
              const Divider(indent: 52),
              _row(Icons.terrain, 'Highest point', units.elevationM(s.highestAltitudeM)),
              const Divider(indent: 52),
              _row(Icons.map_outlined, 'Districts visited', '${s.districts.length}'),
              const Divider(indent: 52),
              _row(Icons.groups, 'Group sessions', '${s.groupSessions}'),
              const Divider(indent: 52),
              _row(Icons.link_off, 'Separations caught', '${s.separationsCaught}'),
              const Divider(indent: 52),
              ListTile(
                leading: const Icon(Icons.public, color: TsColors.neon),
                title: const Text('My public profile'),
                subtitle: const Text('Posts, followers and who you follow'),
                trailing: const Icon(Icons.chevron_right, color: TsColors.textMuted),
                onTap: () {
                  final id = ProviderScope.containerOf(context).read(authProvider)?.id;
                  context.push(id == null ? '/auth?redirect=/profile' : '/user/$id');
                },
              ),
              const Divider(indent: 52),
              ListTile(
                leading: const Icon(Icons.confirmation_number_outlined, color: TsColors.neon),
                title: const Text('My bookings'),
                trailing: const Icon(Icons.chevron_right, color: TsColors.textMuted),
                onTap: () => context.push('/bookings'),
              ),
              const Divider(indent: 52),
              ListTile(
                leading: const Icon(Icons.favorite_border, color: TsColors.textMuted),
                title: const Text('Saved adventures'),
                trailing: Text('$savedCount', style: TsText.h3),
                onTap: () => context.push('/saved'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        TsCard(
          onTap: () => context.push('/track/start'),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: const Row(
            children: [
              Icon(Icons.hiking, color: TsColors.neon),
              SizedBox(width: 12),
              Expanded(child: Text('Start a free trek (no trail)', style: TsText.bodyStrong)),
              Icon(Icons.chevron_right, color: TsColors.textMuted),
            ],
          ),
        ),
        const SizedBox(height: 10),
        TsCard(
          onTap: () => context.push('/trails'),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: const Row(
            children: [
              Icon(Icons.military_tech_outlined, color: TsColors.warning),
              SizedBox(width: 12),
              Expanded(child: Text('Group milestones & free sessions', style: TsText.bodyStrong)),
              Icon(Icons.chevron_right, color: TsColors.textMuted),
            ],
          ),
        ),
      ],
    );
  }

  Widget _row(IconData i, String label, String value) => ListTile(
        leading: Icon(i, color: TsColors.textMuted),
        title: Text(label),
        trailing: Text(value, style: TsText.h3),
      );
}

class _History extends StatelessWidget {
  const _History();
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const ActivityHistoryScreen(embedded: true, limit: 5),
        GhostButton(label: 'View all activities', icon: Icons.list_alt, onPressed: () => context.push('/activities')),
      ],
    );
  }
}
