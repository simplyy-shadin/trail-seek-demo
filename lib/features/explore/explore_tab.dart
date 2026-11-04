import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/widgets/big_cards.dart';
import '../../data/models/destination.dart';

/// Explore tab: State + District pickers, then one big photo card per destination.
/// Thrissur, Kerala is live; other places show as coming soon.
class ExploreTab extends ConsumerStatefulWidget {
  const ExploreTab({super.key});
  @override
  ConsumerState<ExploreTab> createState() => _ExploreTabState();
}

class _ExploreTabState extends ConsumerState<ExploreTab> {
  String? _state = 'Kerala';
  String? _district = 'Thrissur';

  static const _states = ['Kerala', 'Tamil Nadu', 'Karnataka'];
  static const _districts = ['Thrissur', 'Idukki', 'Wayanad', 'Palakkad', 'Ernakulam', 'Thiruvananthapuram'];

  Future<void> _pick(String title, List<String> options, String live, ValueChanged<String> onPick) async {
    final v = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          children: [
            Text(title, style: TsText.h2),
            const SizedBox(height: 8),
            for (final o in options)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(o == live ? Icons.place : Icons.lock_outline, color: o == live ? TsColors.neon : TsColors.textMuted),
                title: Text(o, style: TextStyle(fontWeight: FontWeight.w700, color: o == live ? TsColors.textPrimary : TsColors.textMuted)),
                subtitle: Text(o == live ? 'Live' : 'Coming soon'),
                onTap: o == live ? () => Navigator.pop(ctx, o) : null,
              ),
          ],
        ),
      ),
    );
    if (v != null) onPick(v);
  }

  @override
  Widget build(BuildContext context) {
    final destinations = ref.watch(destinationsProvider).value ?? const <Destination>[];
    final live = _state == 'Kerala' && _district == 'Thrissur';
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        actions: [IconButton(tooltip: 'Search programmes', onPressed: () => context.push('/adventures'), icon: const Icon(Icons.manage_search))],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Row(
            children: [
              Expanded(child: PillField(hint: 'State', value: _state, onTap: () => _pick('State', _states, 'Kerala', (v) => setState(() => _state = v)))),
              const SizedBox(width: 10),
              Expanded(child: PillField(hint: 'District', value: _district, onTap: () => _pick('District', _districts, 'Thrissur', (v) => setState(() => _district = v)))),
            ],
          ),
          const SizedBox(height: 22),
          if (!live)
            const Padding(padding: EdgeInsets.only(top: 40), child: Text('Coming soon', textAlign: TextAlign.center, style: TsText.h3))
          else
            for (final d in destinations)
              Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: DestinationBigCard(d: d, onTap: () => context.push('/destination/${d.id}')),
              ),
        ],
      ),
    );
  }
}
