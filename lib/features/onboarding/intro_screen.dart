import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/widgets/widgets.dart';

class IntroScreen extends ConsumerWidget {
  const IntroScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              const Text('TRAIL SEEK',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 40, fontWeight: FontWeight.w900, letterSpacing: 2, color: TsColors.primary)),
              const SizedBox(height: 10),
              const Text('Discover Amazing Places\nGo Together. Stay Together.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 17, height: 1.4, color: TsColors.text, fontWeight: FontWeight.w500)),
              const SizedBox(height: 40),
              const FeatureRow(
                icon: Icons.hiking,
                title: 'Explore Trails',
                subtitle: 'Find trekking, hiking and adventure destinations',
              ),
              const FeatureRow(
                icon: Icons.checklist_rtl,
                title: 'Plan Your Adventure',
                subtitle: 'Get complete info, gear list and safety tips',
              ),
              const FeatureRow(
                icon: Icons.groups,
                title: 'Go Together, Stay Safe',
                subtitle: 'Real-time group tracking with Digital Rope',
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: () async {
                  await ref.read(onboardedProvider.notifier).complete();
                  if (context.mounted) context.go('/region');
                },
                icon: const Text('Get Started'),
                label: const Icon(Icons.arrow_forward, size: 20),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
