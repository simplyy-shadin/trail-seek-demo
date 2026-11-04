import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/widgets/widgets.dart';

class PlanAdventureScreen extends ConsumerWidget {
  const PlanAdventureScreen({super.key, required this.adventureId});
  final String adventureId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final a = ref.watch(adventureByIdProvider(adventureId)).value;
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          a == null ? const CoverArt(hue: 120) : AdventureCover.of(a),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [TsColors.scrim, TsColors.bg, TsColors.bg],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const BackButton(),
                  const Spacer(),
                  const Text('Plan Your Adventure', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 6),
                  Text(a == null ? 'How do you want to go?' : '${a.name} · How do you want to go?',
                      style: const TextStyle(color: TsColors.muted)),
                  const SizedBox(height: 28),
                  _Choice(
                    icon: Icons.directions_walk,
                    title: 'Solo',
                    subtitle: 'Plan and explore on your own',
                    onTap: () => context.push('/adventure/$adventureId/solo'),
                  ),
                  const SizedBox(height: 14),
                  _Choice(
                    icon: Icons.groups,
                    title: 'With a Group',
                    subtitle: 'Create or join a group and enable Digital Rope safety tracking',
                    highlighted: true,
                    onTap: () => _groupSheet(context),
                  ),
                  const Spacer(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _groupSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Go with a group', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  context.push('/group/create?adventure=$adventureId');
                },
                icon: const Icon(Icons.add),
                label: const Text('Create a Group'),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  context.push('/group/join?adventure=$adventureId');
                },
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text('Join with Code / QR'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice({required this.icon, required this.title, required this.subtitle, required this.onTap, this.highlighted = false});
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: TsColors.surface.withValues(alpha: 0.85),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: highlighted ? TsColors.primary : TsColors.outline, width: highlighted ? 2 : 1),
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: (highlighted ? TsColors.primary : TsColors.green).withValues(alpha: 0.18),
                ),
                child: Icon(icon, size: 28, color: highlighted ? TsColors.primary : TsColors.green),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text(subtitle, style: const TextStyle(color: TsColors.muted, height: 1.3)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: TsColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}
