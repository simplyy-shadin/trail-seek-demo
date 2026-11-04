import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models/adventure.dart';

/// Debug route `/gallery`: every design-system component in each of its states.
class GalleryScreen extends ConsumerStatefulWidget {
  const GalleryScreen({super.key});
  @override
  ConsumerState<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends ConsumerState<GalleryScreen> {
  int _segment = 1;
  int _nav = 0;
  bool _saved = false;

  @override
  Widget build(BuildContext context) {
    final adventures = ref.watch(adventuresProvider).value ?? const <Adventure>[];
    return Scaffold(
      appBar: AppBar(title: const Text('Design gallery')),
      bottomNavigationBar: TsBottomNav(
        items: TsBottomNav.defaultItems,
        selected: _nav,
        onSelected: (i) => setState(() => _nav = i),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          _title('Colours'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final e in {
                'bg': TsColors.bg,
                'surface': TsColors.surface,
                'surfaceHigh': TsColors.surfaceHigh,
                'outline': TsColors.outline,
                'neon': TsColors.neon,
                'neonDeep': TsColors.neonDeep,
                'warning': TsColors.warning,
                'danger': TsColors.danger,
                'info': TsColors.info,
                'textMuted': TsColors.textMuted,
              }.entries)
                Column(
                  children: [
                    Container(
                      width: 56,
                      height: 40,
                      decoration: BoxDecoration(color: e.value, borderRadius: BorderRadius.circular(8), border: Border.all(color: TsColors.outline)),
                    ),
                    const SizedBox(height: 4),
                    Text(e.key, style: const TextStyle(fontSize: 10, color: TsColors.textMuted)),
                  ],
                ),
            ],
          ),
          _title('Typography'),
          const Text('Display 32', style: TsText.display),
          const Text('Heading 1', style: TsText.h1),
          const Text('Heading 2', style: TsText.h2),
          const Text('Heading 3', style: TsText.h3),
          const Text('Body text runs at fourteen points with comfortable line height.', style: TsText.body),
          const Text('Caption · muted', style: TsText.caption),
          const Text('LABEL', style: TsText.label),
          _title('Buttons'),
          const NeonButton(label: 'Get Started', trailingIcon: Icons.arrow_forward, onPressed: _noop),
          const SizedBox(height: 8),
          const NeonButton(label: 'Loading', loading: true),
          const SizedBox(height: 8),
          const NeonButton(label: 'Disabled'),
          const SizedBox(height: 8),
          const NeonButton(label: 'End session', danger: true, icon: Icons.stop_circle_outlined, onPressed: _noop),
          const SizedBox(height: 8),
          const GhostButton(label: 'Continue with Google', icon: Icons.g_mobiledata, onPressed: _noop),
          const SizedBox(height: 8),
          const Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              IconPillButton(icon: Icons.place, label: 'Kerala', selected: true),
              IconPillButton(icon: Icons.public, label: 'Outside Kerala'),
              IconPillButton(icon: Icons.tune, label: 'Filters'),
              RoundIconButton(icon: Icons.my_location),
              RoundIconButton(icon: Icons.pause, neon: true, size: 56),
            ],
          ),
          _title('Segments'),
          SegmentTabs(
            labels: const ['Stats', 'Badges', 'Achievements', 'History'],
            selected: _segment,
            onChanged: (i) => setState(() => _segment = i),
          ),
          _title('Progress'),
          const LevelChip(level: 3),
          const SizedBox(height: 12),
          const XpBar(level: 3, xpInLevel: 520, xpForLevel: 1000),
          const SizedBox(height: 12),
          const XpBar(level: 12, xpInLevel: 3250, xpForLevel: 3250, showLabels: false, height: 6),
          _title('Stats'),
          const Row(
            children: [
              Expanded(child: StatCard(icon: Icons.hiking, value: '12', label: 'Treks')),
              SizedBox(width: 10),
              Expanded(child: StatCard(icon: Icons.verified, value: '8', label: 'Badges')),
              SizedBox(width: 10),
              Expanded(child: StatCard(icon: Icons.emoji_events, value: '4', label: 'Achievements', color: TsColors.warning)),
            ],
          ),
          const SizedBox(height: 10),
          const TsCard(
            child: Row(
              children: [
                Expanded(child: InlineStat(icon: Icons.straighten, value: '4.8 km', label: 'Distance')),
                Expanded(child: InlineStat(icon: Icons.terrain, value: '420 m', label: 'Elevation gain')),
              ],
            ),
          ),
          _title('Badges'),
          const Wrap(
            spacing: 14,
            runSpacing: 14,
            children: [
              HexBadge(icon: Icons.flag, label: 'First Trek Completed', accent: TsColors.warning),
              HexBadge(icon: Icons.terrain, label: 'Mountain Explorer'),
              HexBadge(icon: Icons.forest, label: 'Forest Walker'),
              HexBadge(icon: Icons.pedal_bike, label: 'Cycling Enthusiast', accent: TsColors.danger),
              HexBadge(icon: Icons.kayaking, label: 'Kayaking Beginner', accent: TsColors.info),
              HexBadge(icon: Icons.lock, label: 'More to come…', unlocked: false),
            ],
          ),
          _title('Identity'),
          Wrap(
            spacing: 16,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              AvatarRing(initials: 'FF', onEdit: _noop),
              const AvatarRing(initials: 'RS', size: 56, ringColor: TsColors.warning),
              const MemberAvatar(initials: 'AN', color: TsColors.ropeConnected, ring: Colors.white),
              const MemberAvatar(initials: 'JK', color: TsColors.ropeSeparated, ring: Colors.white),
              const Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  StatusDot(color: TsColors.neon, text: 'Online · 2.4 km'),
                  StatusDot(color: TsColors.textMuted, text: 'Offline · 12 min ago'),
                ],
              ),
            ],
          ),
          _title('Chips'),
          const Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              DifficultyChip(Difficulty.easy),
              DifficultyChip(Difficulty.moderate),
              DifficultyChip(Difficulty.hard),
              Chip(label: Text('Verified'), avatar: Icon(Icons.verified, size: 16, color: TsColors.neon)),
            ],
          ),
          _title('Trek card'),
          if (adventures.isNotEmpty)
            TrekCard(
              adventure: adventures.first,
              saved: _saved,
              onTap: _noop,
              onToggleSaved: () => setState(() => _saved = !_saved),
            ),
          const SizedBox(height: 10),
          SizedBox(
            height: 160,
            child: CoverArt(
              hue: 140,
              icon: Icons.hiking,
              borderRadius: BorderRadius.circular(TsSpace.radiusLg),
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: Align(alignment: Alignment.bottomLeft, child: Text('Cover art placeholder', style: TsText.h2)),
              ),
            ),
          ),
          _title('Section header'),
          SectionHeader('Upcoming', actionLabel: 'View All', onAction: _noop, top: 0),
          const UnverifiedBanner(),
          _title('Inputs'),
          const TextField(decoration: InputDecoration(hintText: 'Search treks, destinations, guides…', prefixIcon: Icon(Icons.search))),
          const SizedBox(height: 8),
          const TextField(decoration: InputDecoration(labelText: 'Email Address', prefixIcon: Icon(Icons.mail_outline))),
          const SizedBox(height: 8),
          SwitchListTile(value: true, onChanged: (_) {}, title: const Text('Demo mode'), contentPadding: EdgeInsets.zero),
          CheckboxListTile(value: true, onChanged: (_) {}, title: const Text('Offline maps downloaded'), contentPadding: EdgeInsets.zero, controlAffinity: ListTileControlAffinity.leading),
        ],
      ),
    );
  }

  static void _noop() {}

  Widget _title(String t) => Padding(
        padding: const EdgeInsets.only(top: 24, bottom: 10),
        child: Text(t.toUpperCase(), style: TsText.label.copyWith(color: TsColors.neon)),
      );
}
