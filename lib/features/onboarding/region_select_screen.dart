import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/widgets/widgets.dart';

class RegionSelectScreen extends ConsumerStatefulWidget {
  const RegionSelectScreen({super.key});
  @override
  ConsumerState<RegionSelectScreen> createState() => _RegionSelectScreenState();
}

class _RegionSelectScreenState extends ConsumerState<RegionSelectScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final regions = ref.watch(regionsProvider);
    final selected = ref.watch(selectedRegionProvider);
    return Scaffold(
      appBar: AppBar(
        leading: context.canPop() ? const BackButton() : null,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Where do you want\nto explore?',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, height: 1.2)),
              const SizedBox(height: 18),
              TextField(
                onChanged: (v) => setState(() => _query = v),
                decoration: const InputDecoration(hintText: 'Search state or region', prefixIcon: Icon(Icons.search)),
              ),
              const SizedBox(height: 18),
              Expanded(
                child: regions.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('Could not load regions: $e')),
                  data: (list) {
                    final filtered = list
                        .where((r) => r.name.toLowerCase().contains(_query.toLowerCase()))
                        .toList();
                    return ListView.separated(
                      padding: const EdgeInsets.only(bottom: 24),
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, i) {
                        final r = filtered[i];
                        final isSelected = r.id == selected;
                        return InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: r.enabled
                              ? () async {
                                  await ref.read(selectedRegionProvider.notifier).select(r.id);
                                  if (context.mounted) context.go('/home');
                                }
                              : () => ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('${r.name} is coming soon. Kerala is live first.')),
                                  ),
                          child: Container(
                            height: r.enabled ? 120 : 84,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: isSelected ? TsColors.primary : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            child: CoverArt(
                              hue: r.coverHue,
                              borderRadius: BorderRadius.circular(16),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.end,
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(r.name,
                                              style: TextStyle(
                                                  fontSize: r.enabled ? 22 : 18,
                                                  fontWeight: FontWeight.w800,
                                                  shadows: const [Shadow(blurRadius: 8, color: Colors.black54)])),
                                          if (!r.enabled)
                                            const Text('Coming soon', style: TextStyle(fontSize: 12, color: Colors.white70)),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: r.enabled ? TsColors.primary : Colors.black38,
                                      ),
                                      child: Icon(r.enabled ? Icons.arrow_forward : Icons.lock_outline, size: 18),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
