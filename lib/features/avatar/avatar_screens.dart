import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models/avatar.dart';
import 'avatar_creator.dart';
import 'avatar_files.dart';

/// Draft avatar being edited across the two setup screens.
class AvatarDraftController extends Notifier<Avatar> {
  @override
  Avatar build() => Avatar.decode(ref.read(authProvider)?.avatarId);
  void set(Avatar a) => state = a;
  void update(Avatar Function(Avatar) fn) => state = fn(state);
}

final avatarDraftProvider = NotifierProvider<AvatarDraftController, Avatar>(AvatarDraftController.new);

/// The signed-in user's avatar (default avatar when none chosen yet).
final currentAvatarProvider = Provider<Avatar>((ref) => Avatar.decode(ref.watch(authProvider)?.avatarId));

/// Frame 3: "Choose Your Avatar".
class ProfileCreatedScreen extends ConsumerWidget {
  const ProfileCreatedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider);
    final avatar = ref.watch(currentAvatarProvider);
    final progress = ref.watch(progressProvider);
    final hero = AvatarFiles.fullBodyFileFor(user?.avatarId);
    final character = CharacterCatalog.parse(user?.avatarId);
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (character != null)
            Opacity(opacity: 0.55, child: Image.asset(CharacterCatalog.full(character), fit: BoxFit.cover, alignment: Alignment.topCenter))
          else if (hero != null && hero.existsSync())
            Image.file(hero, fit: BoxFit.cover, alignment: Alignment.topCenter)
          else
            Image.asset('assets/images/thrissur/peechi-sunset.jpg', fit: BoxFit.cover),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, stops: [0, 0.35, 1], colors: [TsColors.scrim, TsColors.bg, TsColors.bg]),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              child: Column(
                children: [
                  const SizedBox(height: 24),
                  AvatarRing(initials: user?.initials ?? '?', avatar: avatar, avatarId: user?.avatarId, size: 150, ringWidth: 4),
                  const SizedBox(height: 16),
                  Text(user?.username.isNotEmpty == true ? user!.username : (user?.displayName ?? 'Explorer'), style: TsText.h1),
                  Text(progress.title, style: TsText.caption.copyWith(color: TsColors.neon, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 18),
                  XpBar(level: progress.level, xpInLevel: progress.xpInLevel, xpForLevel: progress.xpForLevel),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(child: StatCard(icon: Icons.hiking, value: '${progress.stats.activityCount}', label: 'Treks')),
                      const SizedBox(width: 10),
                      Expanded(child: StatCard(icon: Icons.verified, value: '${progress.badgeCount}', label: 'Badges')),
                      const SizedBox(width: 10),
                      Expanded(child: StatCard(icon: Icons.emoji_events, value: '${progress.achievementCount}', label: 'Achievements', color: TsColors.warning)),
                    ],
                  ),
                  const Spacer(),
                  const Text('"Higher mountains.\nBigger dreams."', textAlign: TextAlign.center, style: TextStyle(fontSize: 16, fontStyle: FontStyle.italic, color: TsColors.textMuted, height: 1.4)),
                  const Spacer(),
                  NeonButton(
                    label: 'Continue',
                    trailingIcon: Icons.arrow_forward,
                    onPressed: () => context.go('/home'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
