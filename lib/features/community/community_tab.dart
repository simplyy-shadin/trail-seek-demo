import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models/avatar.dart';
import '../progress/level_table.dart';
import 'community_controller.dart';
import 'community_models.dart';

/// Frame 11: All / Following / Nearby feed.
class CommunityTab extends ConsumerStatefulWidget {
  const CommunityTab({super.key});
  @override
  ConsumerState<CommunityTab> createState() => _CommunityTabState();
}

class _CommunityTabState extends ConsumerState<CommunityTab> {
  FeedScope _scope = FeedScope.all;
  geo.Position? _here;
  String? _nearbyProblem;

  Future<void> _locate() async {
    try {
      var p = await geo.Geolocator.checkPermission();
      if (p == geo.LocationPermission.denied) p = await geo.Geolocator.requestPermission();
      if (p == geo.LocationPermission.denied || p == geo.LocationPermission.deniedForever) {
        setState(() => _nearbyProblem = 'Nearby needs your location. Allow it in system settings to see posts within 50 km.');
        return;
      }
      final pos = await geo.Geolocator.getLastKnownPosition() ?? await geo.Geolocator.getCurrentPosition();
      setState(() {
        _here = pos;
        _nearbyProblem = null;
      });
    } catch (e) {
      setState(() => _nearbyProblem = 'Could not get a location fix: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(communityProvider);
    final ctrl = ref.read(communityProvider.notifier);
    final user = ref.watch(authProvider);
    final posts = ctrl.feed(_scope, lat: _here?.latitude, lng: _here?.longitude);

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        leading: IconButton(tooltip: 'Find explorers', onPressed: () => context.push(user == null ? '/auth?redirect=/people' : '/people'), icon: const Icon(Icons.person_search_outlined)),
        actions: [
          if (state.tag != null)
            TextButton.icon(onPressed: () => ctrl.setTag(null), icon: const Icon(Icons.close, size: 16), label: Text('#${state.tag}')),
          // Trek groups (create, join by QR, Digital Rope), not messages.
          IconButton(tooltip: 'My groups', onPressed: () => context.push('/groups'), icon: const Icon(Icons.groups_outlined)),
        ],
      ),
      // Lifted above the floating bottom bar, which the feed scrolls under.
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 64),
        child: FloatingActionButton.extended(
        heroTag: 'post',
        onPressed: () => context.push(user == null ? '/auth?redirect=/community/compose' : '/community/compose'),
        backgroundColor: TsColors.bg,
        foregroundColor: Colors.white,
        elevation: 0,
        extendedPadding: const EdgeInsets.symmetric(horizontal: 18),
        shape: const StadiumBorder(side: BorderSide(color: Colors.white, width: 1.4)),
        icon: const Icon(Icons.add_circle_outline),
        label: const Text('Post', style: TextStyle(fontWeight: FontWeight.w800)),
        ),
      ),
      body: Column(
        children: [
          const _TopExplorers(),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
            child: SegmentTabs(
              labels: const ['All', 'Following', 'Nearby'],
              selected: _scope.index,
              onChanged: (i) {
                setState(() => _scope = FeedScope.values[i]);
                if (_scope == FeedScope.nearby && _here == null) _locate();
              },
            ),
          ),
          if (user == null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
              child: TsCard(
                highlighted: true,
                onTap: () => context.push('/auth?redirect=/community'),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: const Row(children: [
                  Icon(Icons.login, color: TsColors.neon, size: 18),
                  SizedBox(width: 10),
                  Expanded(child: Text('Sign in to like, comment and follow explorers', style: TsText.bodyStrong)),
                  Icon(Icons.chevron_right, color: TsColors.textMuted),
                ]),
              ),
            ),
          Expanded(
            child: _scope == FeedScope.nearby && _nearbyProblem != null
                ? _Empty(icon: Icons.location_off, title: 'Nearby is off', body: _nearbyProblem!)
                : posts.isEmpty
                    ? _Empty(
                        icon: _scope == FeedScope.following ? Icons.person_add_alt : Icons.forum_outlined,
                        title: switch (_scope) { FeedScope.all => 'No posts yet', FeedScope.following => 'Follow some explorers', FeedScope.nearby => 'Nothing within 50 km yet' },
                        body: switch (_scope) {
                          FeedScope.all => 'Be the first to share a moment from the trail.',
                          FeedScope.following => 'Posts from people you follow show up here. Tap the search icon to find explorers.',
                          FeedScope.nearby => _here == null ? 'Finding your location…' : 'Share something from your next trek.'
                        },
                      )
                    : RefreshIndicator(
                        onRefresh: ctrl.refresh,
                        child: ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 150), // clear of the bar and the Post button
                          itemCount: posts.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 12),
                          itemBuilder: (_, i) => PostCard(post: posts[i]),
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

/// "Top Explorers": the most-followed explorers as round avatars.
class _TopExplorers extends ConsumerStatefulWidget {
  const _TopExplorers();
  @override
  ConsumerState<_TopExplorers> createState() => _TopExplorersState();
}

class _TopExplorersState extends ConsumerState<_TopExplorers> {
  late final Future<List<ProfileCard>> _top = ref.read(communityProvider.notifier).people();
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ProfileCard>>(
      future: _top,
      builder: (context, snap) {
        final list = (snap.data ?? const <ProfileCard>[]).take(10).toList();
        if (list.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 12, 4),
              child: Row(children: [const Expanded(child: Text('Top Explorers', style: TsText.bodyStrong)), TextButton(onPressed: () => context.push('/people'), child: const Text('Leaderboard'))]),
            ),
            SizedBox(
              height: 102,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: list.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (_, i) {
                  final c = list[i];
                  return GestureDetector(
                    onTap: () => context.push('/user/${c.id}'),
                    child: SizedBox(
                      width: 60,
                      child: Column(children: [
                        Stack(clipBehavior: Clip.none, children: [
                          MemberAvatar(initials: c.initials, avatarId: c.avatarId, size: 56, ring: i < 3 ? TsColors.neon : Colors.white70),
                          if (i < 3)
                            Positioned(
                              right: -2,
                              bottom: -2,
                              child: Container(
                                width: 20,
                                height: 20,
                                alignment: Alignment.center,
                                decoration: const BoxDecoration(color: TsColors.neon, shape: BoxShape.circle),
                                child: Text('${i + 1}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: TsColors.onNeon)),
                              ),
                            ),
                        ]),
                        const SizedBox(height: 4),
                        Text(c.displayName.split(' ').first, maxLines: 1, overflow: TextOverflow.ellipsis, style: TsText.caption.copyWith(color: TsColors.textPrimary, fontWeight: FontWeight.w700)),
                        Text('Lv ${const LevelTable().positionFor(c.xp).level}', style: const TextStyle(fontSize: 10, color: TsColors.neon, fontWeight: FontWeight.w800)),
                      ]),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
        );
      },
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.icon, required this.title, required this.body});
  final IconData icon;
  final String title;
  final String body;
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: TsColors.textMuted),
            const SizedBox(height: 12),
            Text(title, style: TsText.h3, textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text(body, style: TsText.caption, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class PostCard extends ConsumerWidget {
  const PostCard({super.key, required this.post});
  final Post post;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = post;
    final ctrl = ref.read(communityProvider.notifier);
    final me = ref.watch(authProvider);
    final following = ref.watch(communityProvider).following.contains(p.authorId);
    final mine = me?.id == p.authorId;
    return TsCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => context.push('/user/${p.authorId}'),
                child: MemberAvatar(initials: _initials(p.authorName), avatar: p.authorAvatarId == null ? null : Avatar.decode(p.authorAvatarId), avatarId: p.authorAvatarId, size: 40),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => context.push('/user/${p.authorId}'),
                  child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(child: Text(p.authorName, style: TsText.bodyStrong, overflow: TextOverflow.ellipsis)),
                      ],
                    ),
                    Text('${_ago(p.createdAt)}${p.placeName == null ? '' : ' · ${p.placeName}'}', style: TsText.caption),
                  ],
                ),
                ),
              ),
              if (!mine && me != null)
                TextButton(
                  onPressed: () => ctrl.follow(p.authorId, !following),
                  style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 10), minimumSize: const Size(0, 32)),
                  child: Text(following ? 'Following' : 'Follow'),
                ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_horiz, color: TsColors.textMuted),
                onSelected: (v) => _menu(context, ref, v),
                itemBuilder: (_) => [
                  if (mine) const PopupMenuItem(value: 'edit', child: Text('Edit post')),
                  if (mine) const PopupMenuItem(value: 'delete', child: Text('Delete post')),
                  if (!mine) const PopupMenuItem(value: 'report', child: Text('Report')),
                  if (!mine) const PopupMenuItem(value: 'block', child: Text('Block user')),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          _RichText(text: p.text, onTag: (t) => ctrl.setTag(t)),
          if (p.photoPaths.isNotEmpty) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                height: 200,
                width: double.infinity,
                child: p.photoPaths.first.startsWith('http')
                    ? Image.network(p.photoPaths.first, fit: BoxFit.cover, errorBuilder: (_, _, _) => const CoverArt(hue: 150, icon: Icons.photo_outlined))
                    : File(p.photoPaths.first).existsSync()
                        ? Image.file(File(p.photoPaths.first), fit: BoxFit.cover)
                        : const CoverArt(hue: 150, icon: Icons.photo_outlined),
              ),
            ),
          ] else if (_placePhoto(p) != null) ...[
            const SizedBox(height: 10),
            ClipRRect(borderRadius: BorderRadius.circular(14), child: SizedBox(height: 180, width: double.infinity, child: Image.asset(_placePhoto(p)!, fit: BoxFit.cover))),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              _Action(icon: p.likedByMe ? Icons.favorite : Icons.favorite_border, label: '${p.likeCount}', color: p.likedByMe ? TsColors.danger : null, onTap: me == null ? null : () => ctrl.toggleLike(p.id)),
              const SizedBox(width: 16),
              _Action(icon: Icons.mode_comment_outlined, label: '${p.commentCount}', onTap: () => _comments(context, ref)),
              const Spacer(),
              _Action(icon: Icons.share_outlined, label: 'Share', onTap: () => SharePlus.instance.share(ShareParams(text: '${p.authorName} on Trail Seek: ${p.text}'))),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _menu(BuildContext context, WidgetRef ref, String v) async {
    final ctrl = ref.read(communityProvider.notifier);
    switch (v) {
      case 'edit':
        final c = TextEditingController(text: post.text);
        final text = await showDialog<String>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Edit post'),
            content: TextField(controller: c, maxLines: 6, minLines: 2, maxLength: 500, autofocus: true),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              FilledButton(onPressed: () => Navigator.pop(ctx, c.text), child: const Text('Save')),
            ],
          ),
        );
        if (text != null) await ctrl.edit(post.id, text);
      case 'delete':
        await ctrl.delete(post.id);
      case 'report':
        final reason = await showModalBottomSheet<String>(
          context: context,
          builder: (ctx) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Padding(padding: EdgeInsets.all(16), child: Text('Report this post', style: TsText.h3)),
                for (final r in ['Harassment or hate', 'Unsafe advice', 'Sensitive location', 'Spam', 'Other'])
                  ListTile(title: Text(r), onTap: () => Navigator.pop(ctx, r)),
              ],
            ),
          ),
        );
        if (reason != null) {
          await ctrl.report(post.id, reason);
          if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Thanks. Reports are reviewed; content is hidden after three.')));
        }
      case 'block':
        await ctrl.block(post.authorId, name: post.authorName);
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${post.authorName} blocked')));
    }
  }

  void _comments(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(context: context, isScrollControlled: true, builder: (_) => CommentsSheet(postId: post.id));
  }

  /// Demo explorers post without uploads; show the destination's own photo.
  static String? _placePhoto(Post p) {
    final t = '${p.placeName ?? ''} ${p.text}'.toLowerCase();
    if (!p.authorId.startsWith('demo-') && !p.authorId.startsWith('11111111-')) return null;
    const base = 'assets/images/thrissur/';
    if (t.contains('coracle') && t.contains('peechi')) return '${base}peechi-coracle-jackets.jpg';
    if (t.contains('dam valley') || t.contains('digital rope')) return '${base}peechi-dhole.jpg';
    if (t.contains('elephant saga') || t.contains('guide')) return '${base}peechi-trail.jpg';
    if (t.contains('moodal')) return '${base}peechi-stream-2.jpg';
    if (t.contains('peechi')) return '${base}peechi-sunset.jpg';
    if (t.contains('choorathala')) return '${base}chimmony-waterfall.jpg';
    if (t.contains('amphi')) return '${base}chimmony-coracle-2.jpg';
    if (t.contains('climate walk')) return '${base}chimmony-elephant-2.jpg';
    if (t.contains('panther') || t.contains('chimmony')) return '${base}chimmony-reservoir.jpg';
    if (t.contains('ayakurisi')) return '${base}chulannur-rest.jpg';
    if (t.contains('chilambathodi')) return '${base}chulannur-walk.jpg';
    if (t.contains('chulannur')) return '${base}chulannur-peacocks.jpg';
    if (t.contains('vazhachal')) return '${base}vazhachal-rapids.jpg';
    if (t.contains('charpa')) return '${base}commons-charpa.jpg';
    if (t.contains('thumboormuzhi')) return '${base}commons-thumboormuzhi-bridge.jpg';
    if (t.contains('athirappilly')) return '${base}athirappilly-top.jpg';
    return null;
  }

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    return parts.length == 1 ? parts.first[0].toUpperCase() : (parts.first[0] + parts.last[0]).toUpperCase();
  }

  static String _ago(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'just now';
    if (d.inHours < 1) return '${d.inMinutes}m ago';
    if (d.inDays < 1) return '${d.inHours}h ago';
    if (d.inDays < 7) return '${d.inDays}d ago';
    return '${t.day}/${t.month}/${t.year}';
  }
}

class _RichText extends StatelessWidget {
  const _RichText({required this.text, required this.onTag});
  final String text;
  final ValueChanged<String> onTag;

  @override
  Widget build(BuildContext context) {
    final spans = <InlineSpan>[];
    final re = RegExp(r'#([A-Za-z0-9_]+)');
    var last = 0;
    for (final m in re.allMatches(text)) {
      if (m.start > last) spans.add(TextSpan(text: text.substring(last, m.start)));
      final tag = m.group(1)!;
      spans.add(WidgetSpan(
        alignment: PlaceholderAlignment.baseline,
        baseline: TextBaseline.alphabetic,
        child: GestureDetector(
          onTap: () => onTag(tag.toLowerCase()),
          child: Text('#$tag', style: TsText.body.copyWith(color: TsColors.neon, fontWeight: FontWeight.w700)),
        ),
      ));
      last = m.end;
    }
    if (last < text.length) spans.add(TextSpan(text: text.substring(last)));
    return Text.rich(TextSpan(style: TsText.body, children: spans));
  }
}

class _Action extends StatelessWidget {
  const _Action({required this.icon, required this.label, this.onTap, this.color});
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color? color;
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Row(children: [Icon(icon, size: 20, color: color ?? TsColors.textMuted), const SizedBox(width: 6), Text(label, style: TsText.caption.copyWith(color: color ?? TsColors.textMuted))]),
      ),
    );
  }
}

class CommentsSheet extends ConsumerStatefulWidget {
  const CommentsSheet({super.key, required this.postId});
  final String postId;
  @override
  ConsumerState<CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends ConsumerState<CommentsSheet> {
  final _c = TextEditingController();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(communityProvider);
    final comments = ref.read(communityProvider.notifier).comments(widget.postId);
    final me = ref.watch(authProvider);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.6,
          child: Column(
            children: [
              const Padding(padding: EdgeInsets.all(12), child: Text('Comments', style: TsText.h3)),
              Expanded(
                child: comments.isEmpty
                    ? const Center(child: Text('No comments yet', style: TsText.caption))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: comments.length,
                        itemBuilder: (_, i) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          onTap: () => context.push('/user/${comments[i].authorId}'),
                          leading: MemberAvatar(initials: comments[i].authorName.substring(0, 1).toUpperCase(), size: 32),
                          title: Text(comments[i].authorName, style: TsText.bodyStrong),
                          subtitle: Text(comments[i].text),
                        ),
                      ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _c,
                        enabled: me != null,
                        decoration: InputDecoration(hintText: me == null ? 'Sign in to comment' : 'Add a comment…', isDense: true),
                        onSubmitted: (_) => _send(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    RoundIconButton(icon: Icons.send, neon: true, onTap: me == null ? null : _send),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _send() async {
    final t = _c.text;
    if (t.trim().isEmpty) return;
    _c.clear();
    await ref.read(communityProvider.notifier).comment(widget.postId, t);
    setState(() {});
  }
}
