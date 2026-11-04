import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/widgets/widgets.dart';

class SoloPlanScreen extends ConsumerStatefulWidget {
  const SoloPlanScreen({super.key, required this.adventureId});
  final String adventureId;
  @override
  ConsumerState<SoloPlanScreen> createState() => _SoloPlanScreenState();
}

class _SoloPlanScreenState extends ConsumerState<SoloPlanScreen> {
  final Set<String> _done = {};

  @override
  Widget build(BuildContext context) {
    final a = ref.watch(adventureByIdProvider(widget.adventureId)).value;
    if (a == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final items = [
      ...a.checklist,
      'Shoes: ${a.gear.shoes}',
      'Hydration: ${a.gear.hydration}',
      'First aid: ${a.gear.firstAid}',
      'Tell someone your route and return time',
    ];
    final progress = items.isEmpty ? 0.0 : _done.length / items.length;
    return Scaffold(
      appBar: AppBar(title: const Text('Solo plan')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 120),
        children: [
          Text(a.name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text('${a.distanceLabel} · ${a.durationLabel} · ${a.difficulty.label}', style: const TextStyle(color: TsColors.muted)),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(value: progress, minHeight: 8, color: TsColors.green, backgroundColor: TsColors.surfaceHigh),
          ),
          const SizedBox(height: 6),
          Text('${_done.length} of ${items.length} ready', style: const TextStyle(fontSize: 12, color: TsColors.muted)),
          const SectionTitle('Preparation checklist'),
          for (final item in items)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              activeColor: TsColors.green,
              value: _done.contains(item),
              onChanged: (v) => setState(() => v == true ? _done.add(item) : _done.remove(item)),
              title: Text(item, style: TextStyle(decoration: _done.contains(item) ? TextDecoration.lineThrough : null)),
            ),
          const SectionTitle('Before you go'),
          BulletList(a.precautions, icon: Icons.shield_outlined, iconColor: TsColors.green, iconSize: 18),
          const SectionTitle('Emergency contacts'),
          for (final c in a.emergencyContacts)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.call, color: TsColors.red),
              title: Text(c.label),
              subtitle: Text(c.phone.isEmpty ? 'Number pending verification' : c.phone),
              trailing: c.phone.isEmpty ? null : const Icon(Icons.phone_forwarded, color: TsColors.neon),
              onTap: c.phone.isEmpty ? null : () => launchUrl(Uri.parse('tel:${c.phone}')),
            ),
          const SizedBox(height: 12),
          const Text(
            'Going solo? Digital Rope only works with a group. Share your plan with someone at home instead.',
            style: TextStyle(color: TsColors.muted, fontSize: 13, height: 1.4),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: FilledButton.icon(
          onPressed: () => SharePlus.instance.share(ShareParams(
            text: 'My plan: ${a.name} (${a.district}, Kerala). ${a.distanceLabel}, about ${a.durationLabel}. '
                'Difficulty ${a.difficulty.label}. Best season ${a.bestSeason}. Planned with Trail Seek.',
          )),
          icon: const Icon(Icons.share),
          label: const Text('Share plan'),
        ),
      ),
    );
  }
}
