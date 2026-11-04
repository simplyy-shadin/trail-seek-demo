import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/widgets/widgets.dart';
import '../profile/profile_tab.dart' show badgeIcon;
import '../rope/rope_controller.dart';
import '../tracking/tracking_controller.dart';
import 'progress.dart';

/// Global navigator so reward moments can open routes/sheets from the root.
final rootNavigatorKey = GlobalKey<NavigatorState>();

/// Wraps the app. Listens to progress events and plays them one at a time:
/// XP toast → Level Up screen → badge sheets → achievement toasts.
/// Nothing is shown while a recording or a Digital Rope session is running,
/// or while the app is in the background; the queue drains afterwards.
class RewardHost extends ConsumerStatefulWidget {
  const RewardHost({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<RewardHost> createState() => _RewardHostState();
}

class _RewardHostState extends ConsumerState<RewardHost> with WidgetsBindingObserver {
  final Queue<ProgressEvent> _queue = Queue();
  bool _playing = false;
  bool _foreground = true;
  _Toast? _toast;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground) _drain();
  }

  bool get _busyWithSession =>
      ref.read(trackingProvider).isActive || ref.read(ropeProvider) != null;

  void _enqueue(ProgressEvent e) {
    _queue.add(e);
    _drain();
  }

  Future<void> _drain() async {
    if (_playing || !_foreground || !mounted) return;
    if (_busyWithSession) {
      // Try again when the session ends.
      Future.delayed(const Duration(seconds: 5), _drain);
      return;
    }
    _playing = true;
    while (_queue.isNotEmpty && mounted) {
      final e = _queue.removeFirst();
      await _play(e);
    }
    _playing = false;
  }

  Future<void> _play(ProgressEvent e) async {
    final ctx = rootNavigatorKey.currentContext;
    switch (e) {
      case XpGainedEvent():
        await _showToast(_Toast(icon: Icons.bolt, text: '+${e.delta.xpGained} XP'));
      case LevelUpEvent():
        if (ctx == null) return;
        HapticFeedback.mediumImpact();
        await Navigator.of(ctx).push(PageRouteBuilder<void>(
          opaque: false,
          barrierColor: Colors.transparent,
          transitionDuration: const Duration(milliseconds: 350),
          pageBuilder: (_, a, _) => FadeTransition(opacity: a, child: LevelUpScreen(delta: e.delta)),
        ));
      case BadgeUnlockedEvent():
        if (ctx == null) return;
        HapticFeedback.lightImpact();
        await showModalBottomSheet<void>(context: ctx, builder: (_) => BadgeUnlockedSheet(badgeId: e.badgeId));
      case AchievementCompletedEvent():
        final a = AchievementCatalog.byId(e.achievementId);
        await _showToast(_Toast(icon: Icons.emoji_events, text: 'Achievement: ${a?.title ?? e.achievementId}', color: TsColors.warning));
    }
  }

  Future<void> _showToast(_Toast t) async {
    if (!mounted) return;
    setState(() => _toast = t);
    await Future<void>.delayed(const Duration(milliseconds: 2200));
    if (mounted) setState(() => _toast = null);
    await Future<void>.delayed(const Duration(milliseconds: 350));
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(progressEventsProvider, (_, next) {
      final e = next.value;
      if (e != null) _enqueue(e);
    });
    return Stack(
      children: [
        widget.child,
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          child: SafeArea(
            child: AnimatedSlide(
              offset: _toast == null ? const Offset(0, -1.4) : Offset.zero,
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeOutBack,
              child: AnimatedOpacity(
                opacity: _toast == null ? 0 : 1,
                duration: const Duration(milliseconds: 250),
                child: Center(
                  child: _toast == null
                      ? const SizedBox.shrink()
                      : Material(
                          color: Colors.transparent,
                          child: Container(
                            margin: const EdgeInsets.only(top: 10),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              color: TsColors.surface,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: _toast!.color),
                              boxShadow: [BoxShadow(color: _toast!.color.withValues(alpha: 0.35), blurRadius: 16)],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(_toast!.icon, color: _toast!.color, size: 20),
                                const SizedBox(width: 8),
                                Text(_toast!.text, style: TsText.h3.copyWith(color: _toast!.color)),
                              ],
                            ),
                          ),
                        ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Toast {
  const _Toast({required this.icon, required this.text, this.color = TsColors.neon});
  final IconData icon;
  final String text;
  final Color color;
}

/// Frame 15.
class LevelUpScreen extends ConsumerWidget {
  const LevelUpScreen({super.key, required this.delta});
  final ProgressDelta delta;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(progressProvider);
    final reduce = MediaQuery.of(context).disableAnimations;
    final newBadge = delta.newBadges.isEmpty ? null : BadgeCatalog.byId(delta.newBadges.first);
    final nextAchievement = AchievementCatalog.all.where((a) => !progress.achievements.containsKey(a.id)).firstOrNull;
    final levels = const LevelTable();
    return Scaffold(
      backgroundColor: TsColors.bg.withValues(alpha: 0.96),
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (!reduce) const Positioned.fill(child: _Confetti()),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
              child: Column(
                children: [
                  const Spacer(),
                  Container(
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: TsColors.neon.withValues(alpha: 0.12),
                      boxShadow: [BoxShadow(color: TsColors.neon.withValues(alpha: 0.45), blurRadius: 50)],
                    ),
                    child: const Icon(Icons.landscape, size: 84, color: TsColors.neon),
                  ),
                  const SizedBox(height: 26),
                  const Text('Level Up!', style: TsText.display),
                  const SizedBox(height: 6),
                  Text("You've reached Level ${delta.newLevel}", style: TsText.body.copyWith(color: TsColors.textMuted)),
                  const SizedBox(height: 4),
                  Text(LevelTable.titleFor(delta.newLevel), style: TsText.caption.copyWith(color: TsColors.neon, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 28),
                  Row(
                    children: [
                      _Tile(icon: Icons.bolt, title: '+${delta.xpGained} XP', subtitle: 'Earned'),
                      const SizedBox(width: 10),
                      _Tile(
                        icon: newBadge == null ? Icons.verified_outlined : badgeIcon(newBadge.iconKey),
                        title: newBadge == null ? 'New Level' : 'New Badge',
                        subtitle: newBadge?.title ?? 'Next at ${levels.xpToNext(delta.newLevel)} XP',
                      ),
                      const SizedBox(width: 10),
                      _Tile(icon: Icons.emoji_events_outlined, title: 'Unlock Next', subtitle: nextAchievement?.title ?? 'All achievements done'),
                    ],
                  ),
                  const Spacer(),
                  NeonButton(label: 'Continue', onPressed: () => Navigator.of(context).pop()),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.icon, required this.title, required this.subtitle});
  final IconData icon;
  final String title;
  final String subtitle;
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: TsCard(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        child: Column(
          children: [
            HexBadge(icon: icon, label: '', size: 48),
            Text(title, style: TsText.bodyStrong, textAlign: TextAlign.center),
            const SizedBox(height: 2),
            Text(subtitle, style: TsText.caption.copyWith(fontSize: 11), textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}

class BadgeUnlockedSheet extends StatefulWidget {
  const BadgeUnlockedSheet({super.key, required this.badgeId});
  final String badgeId;
  @override
  State<BadgeUnlockedSheet> createState() => _BadgeUnlockedSheetState();
}

class _BadgeUnlockedSheetState extends State<BadgeUnlockedSheet> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final b = BadgeCatalog.byId(widget.badgeId);
    final reduce = MediaQuery.of(context).disableAnimations;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('NEW BADGE', style: TextStyle(fontSize: 11, letterSpacing: 2, fontWeight: FontWeight.w800, color: TsColors.neon)),
            const SizedBox(height: 10),
            AnimatedBuilder(
              animation: _c,
              builder: (_, child) {
                final t = reduce ? 1.0 : Curves.easeOutBack.transform(_c.value);
                return Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.001)
                    ..rotateY((1 - t) * math.pi),
                  child: child,
                );
              },
              child: HexBadge(icon: badgeIcon(b?.iconKey ?? ''), label: '', size: 110),
            ),
            Text(b?.title ?? widget.badgeId, style: TsText.h2),
            const SizedBox(height: 6),
            Text(b?.description ?? '', style: TsText.caption, textAlign: TextAlign.center),
            const SizedBox(height: 18),
            NeonButton(label: 'Nice', onPressed: () => Navigator.of(context).pop()),
          ],
        ),
      ),
    );
  }
}

/// Lightweight falling particles. No package.
class _Confetti extends StatefulWidget {
  const _Confetti();
  @override
  State<_Confetti> createState() => _ConfettiState();
}

class _ConfettiState extends State<_Confetti> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(seconds: 4))..forward();
  final _rand = math.Random(7);
  late final _pieces = List.generate(70, (_) => _Piece(_rand));

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, _) => CustomPaint(painter: _ConfettiPainter(_pieces, _c.value)),
      ),
    );
  }
}

class _Piece {
  _Piece(math.Random r)
      : x = r.nextDouble(),
        delay = r.nextDouble() * 0.4,
        speed = 0.6 + r.nextDouble() * 0.6,
        size = 5 + r.nextDouble() * 6,
        spin = (r.nextDouble() - 0.5) * 10,
        drift = (r.nextDouble() - 0.5) * 0.2,
        color = [TsColors.neon, TsColors.warning, TsColors.info, TsColors.textPrimary][r.nextInt(4)];
  final double x, delay, speed, size, spin, drift;
  final Color color;
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.pieces, this.t);
  final List<_Piece> pieces;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in pieces) {
      final lt = ((t - p.delay) / (1 - p.delay)).clamp(0.0, 1.0);
      if (lt <= 0) continue;
      final y = -20 + lt * p.speed * (size.height + 40);
      final x = (p.x + math.sin(lt * 6 + p.spin) * p.drift) * size.width;
      final paint = Paint()..color = p.color.withValues(alpha: (1 - lt).clamp(0, 1));
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(lt * p.spin);
      canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.6), paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}
