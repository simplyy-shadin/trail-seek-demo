import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/widgets/widgets.dart';
import '../progress/level_table.dart';
import 'community_controller.dart';
import '../../data/models/activity_record.dart';
import 'character_sheet_view.dart';
import 'community_models.dart';
import 'explorers.dart';
import 'community_tab.dart';

/// Find explorers: search by name, handle or town; follow from the list.
class PeopleScreen extends ConsumerStatefulWidget {
  const PeopleScreen({super.key});
  @override
  ConsumerState<PeopleScreen> createState() => _PeopleScreenState();
}

class _PeopleScreenState extends ConsumerState<PeopleScreen> {
  String _q = '';
  Timer? _debounce;
  Future<List<ProfileCard>>? _future;

  @override
  void initState() {
    super.initState();
    _future = ref.read(communityProvider.notifier).people();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _search(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () => setState(() {
          _q = v;
          _future = ref.read(communityProvider.notifier).people(query: v);
        }));
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(communityProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Find explorers')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: TextField(onChanged: _search, decoration: const InputDecoration(hintText: 'Search by name, @handle or town', prefixIcon: Icon(Icons.search))),
          ),
          Expanded(
            child: FutureBuilder<List<ProfileCard>>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
                final list = snap.data ?? const [];
                if (list.isEmpty) return Center(child: Text(_q.isEmpty ? 'No explorers yet' : 'Nobody matches “$_q”', style: TsText.caption));
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (_, i) => PersonTile(card: list[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// One explorer in a list, with a live Follow button.
class PersonTile extends ConsumerWidget {
  const PersonTile({super.key, required this.card});
  final ProfileCard card;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(authProvider);
    final following = ref.watch(communityProvider).following.contains(card.id);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 4),
      onTap: () => context.push('/user/${card.id}'),
      leading: MemberAvatar(initials: card.initials, avatarId: card.avatarId, size: 44),
      title: Text(card.displayName, style: TsText.bodyStrong),
      subtitle: Text([if (card.rank != null) '#${card.rank}', 'Lv ${const LevelTable().positionFor(card.xp).level}', if (card.homeTown.isNotEmpty) card.homeTown, '${card.followers} followers'].join(' · '), style: TsText.caption),
      trailing: me == null || me.id == card.id ? null : FollowButton(userId: card.id, following: following),
    );
  }
}

class FollowButton extends ConsumerWidget {
  const FollowButton({super.key, required this.userId, required this.following, this.big = false});
  final String userId;
  final bool following;
  final bool big;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void tap() => ref.read(communityProvider.notifier).follow(userId, !following);
    if (big) {
      return following ? GhostButton(label: 'Following', icon: Icons.check, onPressed: tap) : NeonButton(label: 'Follow', icon: Icons.person_add_alt, onPressed: tap);
    }
    return following
        ? OutlinedButton(onPressed: tap, style: OutlinedButton.styleFrom(minimumSize: const Size(0, 34), padding: const EdgeInsets.symmetric(horizontal: 14)), child: const Text('Following'))
        : FilledButton(onPressed: tap, style: FilledButton.styleFrom(minimumSize: const Size(0, 34), padding: const EdgeInsets.symmetric(horizontal: 16)), child: const Text('Follow'));
  }
}

/// Another explorer's (or your own) public profile: counts, bio, posts.
class UserProfileScreen extends ConsumerStatefulWidget {
  const UserProfileScreen({super.key, required this.userId});
  final String userId;
  @override
  ConsumerState<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends ConsumerState<UserProfileScreen> {
  late Future<ProfileCard?> _future = ref.read(communityProvider.notifier).profile(widget.userId);
  late final Future<List<ActivityRecord>> _history = ref.read(communityProvider.notifier).activitiesOf(widget.userId);
  int _tab = 0;
  bool? _lastFollowing;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(communityProvider);
    final me = ref.watch(authProvider);
    final following = state.following.contains(widget.userId);
    // Re-pull counts after a follow/unfollow.
    if (_lastFollowing != null && _lastFollowing != following) _future = ref.read(communityProvider.notifier).profile(widget.userId);
    _lastFollowing = following;
    final posts = ref.read(communityProvider.notifier).postsBy(widget.userId);
    final mine = me?.id == widget.userId;
    return Scaffold(
      appBar: AppBar(
        actions: [
          if (!mine && me != null)
            PopupMenuButton<String>(
              onSelected: (v) async {
                final card = await _future;
                await ref.read(communityProvider.notifier).block(widget.userId, name: card?.displayName);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${card?.displayName ?? 'User'} blocked')));
                  context.pop();
                }
              },
              itemBuilder: (_) => const [PopupMenuItem(value: 'block', child: Text('Block'))],
            ),
        ],
      ),
      body: FutureBuilder<ProfileCard?>(
        future: _future,
        builder: (context, snap) {
          final c = snap.data;
          if (c == null) return snap.connectionState == ConnectionState.done ? const Center(child: Text('Explorer not found')) : const Center(child: CircularProgressIndicator());
          return RefreshIndicator(
            onRefresh: () async {
              await ref.read(communityProvider.notifier).refresh();
              setState(() => _future = ref.read(communityProvider.notifier).profile(widget.userId));
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
              children: [
                Row(
                  children: [
                    MemberAvatar(initials: c.initials, avatarId: c.avatarId, size: 92, ring: TsColors.neon),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(c.displayName, style: TsText.h2),
                          if (c.username.isNotEmpty) Text('@${c.username}', style: TsText.caption.copyWith(color: TsColors.neon, fontWeight: FontWeight.w700)),
                          if (c.homeTown.isNotEmpty) Text(c.homeTown, style: TsText.caption),
                        ],
                      ),
                    ),
                  ],
                ),
                if (c.bio.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 12), child: Text(c.bio, style: const TextStyle(height: 1.4))),
                const SizedBox(height: 14),
                Row(
                  children: [
                    _Count('${c.posts}', 'Posts'),
                    _Count('${c.followers}', 'Followers', onTap: () => context.push('/user/${c.id}/followers')),
                    _Count('${c.following}', 'Following', onTap: () => context.push('/user/${c.id}/following')),
                  ],
                ),
                const SizedBox(height: 14),
                if (!mine && me != null) FollowButton(userId: c.id, following: following, big: true),
                if (me == null) NeonButton(label: 'Sign in to follow', onPressed: () => context.push('/auth?redirect=/user/${c.id}')),
                const SizedBox(height: 16),
                SegmentTabs(labels: const ['Adventurer', 'Posts'], selected: _tab, onChanged: (i) => setState(() => _tab = i)),
                const SizedBox(height: 14),
                if (_tab == 0)
                  FutureBuilder<List<ActivityRecord>>(
                    future: _history,
                    builder: (context, h) {
                      if (h.connectionState != ConnectionState.done) return const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()));
                      final records = mine ? ref.watch(activitiesProvider) : (h.data ?? const <ActivityRecord>[]);
                      return CharacterSheetView(sheet: CharacterSheet(records), rank: c.rank);
                    },
                  )
                else ...[
                  if (posts.isEmpty) const Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Text('No posts yet', style: TsText.caption, textAlign: TextAlign.center)),
                  for (final p in posts) Padding(padding: const EdgeInsets.only(bottom: 12), child: PostCard(post: p)),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Count extends StatelessWidget {
  const _Count(this.value, this.label, {this.onTap});
  final String value;
  final String label;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(children: [Text(value, style: TsText.h2), Text(label, style: TsText.caption)]),
        ),
      ),
    );
  }
}

/// Followers or following of an explorer.
class FollowListScreen extends ConsumerWidget {
  const FollowListScreen({super.key, required this.userId, required this.followers});
  final String userId;
  final bool followers;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(communityProvider);
    final ctrl = ref.read(communityProvider.notifier);
    return Scaffold(
      appBar: AppBar(title: Text(followers ? 'Followers' : 'Following')),
      body: FutureBuilder<List<ProfileCard>>(
        future: followers ? ctrl.followers(userId) : ctrl.followingOf(userId),
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          final list = snap.data ?? const [];
          if (list.isEmpty) return Center(child: Text(followers ? 'No followers yet' : 'Not following anyone yet', style: TsText.caption));
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            itemCount: list.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (_, i) => PersonTile(card: list[i]),
          );
        },
      ),
    );
  }
}
