import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/widgets/widgets.dart';

class SavedTab extends ConsumerWidget {
  const SavedTab({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saved = ref.watch(savedProvider);
    final all = ref.watch(adventuresProvider).value ?? const [];
    final list = all.where((a) => saved.contains(a.id)).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Saved')),
      body: list.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.bookmark_outline, size: 56, color: TsColors.muted),
                    const SizedBox(height: 12),
                    const Text('Nothing saved yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    const Text('Tap the heart on any adventure to keep it here.',
                        textAlign: TextAlign.center, style: TextStyle(color: TsColors.muted)),
                    const SizedBox(height: 20),
                    FilledButton(onPressed: () => context.go('/home'), child: const Text('Browse adventures')),
                  ],
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              itemCount: list.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (_, i) => TrekCard(
                adventure: list[i],
                saved: true,
                onTap: () => context.push('/adventure/${list[i].id}'),
                onToggleSaved: () => ref.read(savedProvider.notifier).toggle(list[i].id),
              ),
            ),
    );
  }
}
