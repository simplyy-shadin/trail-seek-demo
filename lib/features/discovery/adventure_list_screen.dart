import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart' as geo;

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/connectivity.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models/activity_category.dart';
import '../../data/models/adventure.dart';
import '../../data/models/destination.dart';
import '../booking/booking_controller.dart';
import '../tracking/tracking_controller.dart';
import 'package:intl/intl.dart';
import 'explore_filter.dart';

/// Home: search, the Thrissur destinations, programme-type bar, programme cards.
/// Also used as a pushed list when opened with a category.
class AdventureListScreen extends ConsumerStatefulWidget {
  const AdventureListScreen({super.key, this.categoryKey, this.isTabRoot = false});
  final String? categoryKey;

  /// True when shown as the Home tab: no back button, profile in the bar.
  final bool isTabRoot;

  @override
  ConsumerState<AdventureListScreen> createState() => _AdventureListScreenState();
}

class _AdventureListScreenState extends ConsumerState<AdventureListScreen> {
  final _search = TextEditingController();
  final _searchFocus = FocusNode();
  Timer? _debounce;
  ({double lat, double lng})? _here;

  Future<void> _locate() async {
    try {
      var p = await geo.Geolocator.checkPermission();
      if (p == geo.LocationPermission.denied) p = await geo.Geolocator.requestPermission();
      if (p == geo.LocationPermission.denied || p == geo.LocationPermission.deniedForever) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Allow location to sort by distance.')));
        return;
      }
      final pos = await geo.Geolocator.getLastKnownPosition() ?? await geo.Geolocator.getCurrentPosition();
      if (mounted) setState(() => _here = (lat: pos.latitude, lng: pos.longitude));
    } catch (_) {}
  }

  @override
  void initState() {
    super.initState();
    final cat = widget.categoryKey == null ? null : ActivityCategory.fromKey(widget.categoryKey!);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final f = ref.read(exploreFilterProvider);
      _search.text = f.query;
      if (cat != null) ref.read(exploreFilterProvider.notifier).update((s) => s.copyWith(categories: {cat}));
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _useQuery(String v) {
    _search.text = v;
    _search.selection = TextSelection.collapsed(offset: v.length);
    ref.read(exploreFilterProvider.notifier).update((s) => s.copyWith(query: v));
    ref.read(recentSearchesProvider.notifier).add(v);
    _searchFocus.unfocus();
  }

  void _onQuery(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 200), () {
      ref.read(exploreFilterProvider.notifier).update((s) => s.copyWith(query: v));
    });
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(exploreFilterProvider);
    final saved = ref.watch(savedProvider);
    final all = ref.watch(adventuresProvider);
    final destinations = ref.watch(destinationsProvider).value ?? const <Destination>[];
    final notifier = ref.read(exploreFilterProvider.notifier);
    final activeGroup = widget.isTabRoot ? ref.watch(activeSessionProvider) : null;
    final tracking = widget.isTabRoot ? ref.watch(trackingProvider) : null;
    final nextTrip = widget.isTabRoot ? (ref.watch(bookingProvider), ref.read(bookingProvider.notifier).upcoming.firstOrNull).$2 : null;
    final singleCategory = filter.categories.length == 1 ? filter.categories.first : null;
    final singleType = filter.programTypes.length == 1 ? filter.programTypes.first : null;
    final typesPresent = <ProgramType>{for (final a in all.value ?? const <Adventure>[]) a.programType};

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !widget.isTabRoot,
        centerTitle: !widget.isTabRoot,
        title: widget.isTabRoot
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.asset('assets/images/logo.jpeg', width: 28, height: 28, fit: BoxFit.cover)),
                  const SizedBox(width: 10),
                  const Text('Trail Seek'),
                ],
              )
            : Text(singleCategory?.label ?? 'Programmes'),
        actions: [
          if (widget.isTabRoot)
            IconButton(
              tooltip: 'Record a trek',
              onPressed: () => context.push('/track/start'),
              icon: const Icon(Icons.fiber_manual_record, color: TsColors.danger),
            ),
          if (widget.isTabRoot)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Builder(builder: (context) {
                final user = ref.watch(authProvider);
                return GestureDetector(
                  onTap: () => context.push('/profile'),
                  child: user == null
                      ? Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(shape: BoxShape.circle, color: TsColors.surface, border: Border.all(color: TsColors.outline)),
                          child: const Icon(Icons.person_outline, size: 20),
                        )
                      : MemberAvatar(initials: user.initials, avatarId: user.avatarId, size: 36, ring: TsColors.neon),
                );
              }),
            )
          // No separate Saved button here: the "Saved" filter chip below does it.
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
            child: TextField(
              controller: _search,
              focusNode: _searchFocus,
              onChanged: _onQuery,
              onSubmitted: (v) => ref.read(recentSearchesProvider.notifier).add(v),
              onTapOutside: (_) => _searchFocus.unfocus(),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search treks, coracle rides, Athirappilly…',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: filter.query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () {
                          _search.clear();
                          notifier.update((s) => s.copyWith(query: ''));
                        },
                      ),
              ),
            ),
          ),
          ListenableBuilder(
            listenable: Listenable.merge([_searchFocus, _search]),
            builder: (context, _) {
              final recents = ref.watch(recentSearchesProvider);
              if (!_searchFocus.hasFocus || _search.text.isNotEmpty || recents.isEmpty) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Icon(Icons.history, size: 16, color: TsColors.textMuted),
                    for (final r in recents) ActionChip(label: Text(r), onPressed: () => _useQuery(r)),
                    TextButton(onPressed: () => ref.read(recentSearchesProvider.notifier).clear(), child: const Text('Clear')),
                  ],
                ),
              );
            },
          ),
          if (widget.isTabRoot && destinations.isNotEmpty)
            _DestinationStrip(
              destinations: destinations,
              selected: filter.destinationId,
              onSelect: (id) => notifier.update((s) => id == null ? s.copyWith(clearDestination: true) : s.copyWith(destinationId: id)),
              onOpen: (id) => context.push('/destination/$id'),
            ),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                IconPillButton(
                  icon: Icons.all_inclusive,
                  label: 'All',
                  selected: filter.programTypes.isEmpty && filter.categories.isEmpty && !filter.savedOnly,
                  onTap: () => notifier.update((s) => s.copyWith(programTypes: const {}, categories: const {}, savedOnly: false)),
                ),
                const SizedBox(width: 8),
                IconPillButton(
                  icon: filter.savedOnly ? Icons.favorite : Icons.favorite_border,
                  label: 'Saved',
                  selected: filter.savedOnly,
                  onTap: () => notifier.update((s) => s.copyWith(savedOnly: !s.savedOnly)),
                ),
                for (final t in ProgramType.values.where(typesPresent.contains)) ...[
                  const SizedBox(width: 8),
                  IconPillButton(
                    icon: t.icon,
                    label: t.label,
                    selected: singleType == t,
                    onTap: () => notifier.update((s) => s.copyWith(programTypes: singleType == t ? const {} : {t})),
                  ),
                ],
                const SizedBox(width: 8),
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    IconPillButton(icon: Icons.tune, label: 'Filters', onTap: () => _openFilters(context)),
                    if (filter.sheetCount > 0)
                      Positioned(
                        right: -4,
                        top: -4,
                        child: Container(
                          width: 18,
                          height: 18,
                          alignment: Alignment.center,
                          decoration: const BoxDecoration(shape: BoxShape.circle, color: TsColors.neon),
                          child: Text('${filter.sheetCount}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: TsColors.onNeon)),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 8),
                IconPillButton(
                  icon: Icons.swap_vert,
                  label: switch (filter.sort) {
                    ExploreSort.recommended => 'Sort',
                    ExploreSort.nearest => 'Nearest',
                    ExploreSort.shortest => 'Shortest',
                    ExploreSort.easiest => 'Easiest',
                    ExploreSort.cheapest => 'Cheapest',
                  },
                  selected: filter.sort != ExploreSort.recommended,
                  onTap: () => _sortSheet(context),
                ),
                if (filter.activeCount > 0) ...[
                  const SizedBox(width: 8),
                  IconPillButton(icon: Icons.clear_all, label: 'Clear', onTap: notifier.reset),
                ],
              ],
            ),
          ),
          if (widget.isTabRoot && !ref.watch(onlineProvider))
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Row(
                children: [
                  Icon(Icons.cloud_off, size: 16, color: TsColors.textMuted),
                  SizedBox(width: 8),
                  Expanded(child: Text('Offline. Programmes, recording and Digital Rope still work; maps show only downloaded areas.', style: TsText.caption)),
                ],
              ),
            ),
          if (tracking != null && tracking.isActive)
            _Banner(
              icon: Icons.fiber_manual_record,
              iconColor: tracking.status == TrackingStatus.recording ? TsColors.danger : TsColors.textMuted,
              text: '${tracking.status == TrackingStatus.recording ? 'Recording' : 'Paused'} · ${tracking.distanceKm.toStringAsFixed(1)} km',
              onTap: () => context.push('/track'),
            ),
          if (nextTrip != null)
            _Banner(
              icon: Icons.confirmation_number_outlined,
              iconColor: TsColors.neon,
              text: 'Next trip: ${nextTrip.programName} · ${DateFormat('d MMM').format(nextTrip.date)}',
              onTap: () => context.push('/booking/${nextTrip.id}'),
            ),
          if (activeGroup != null)
            _Banner(
              icon: Icons.sensors,
              iconColor: TsColors.onNeon,
              neon: true,
              text: 'Digital Rope active · ${activeGroup.name}',
              onTap: () => context.push('/group/${activeGroup.id}/live'),
            ),
          const SizedBox(height: 10),
          Expanded(
            child: all.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('$e')),
              data: (list) {
                final results = filter.sorted(list.where((a) => filter.matches(a, saved)).toList(), here: _here);
                if (results.isEmpty) {
                  return _Empty(
                    icon: Icons.search_off,
                    title: 'No programmes match',
                    body: 'Try fewer filters or a different search.',
                    action: GhostButton(label: 'Clear filters', expanded: false, onPressed: notifier.reset),
                  );
                }
                final selectedDest = filter.destinationId == null ? null : destinations.where((d) => d.id == filter.destinationId).firstOrNull;
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  itemCount: results.length + (selectedDest == null ? 0 : 1),
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    if (selectedDest != null && i == 0) return _DestinationHeader(selectedDest, onOpen: () => context.push('/destination/${selectedDest.id}'));
                    final a = results[i - (selectedDest == null ? 0 : 1)];
                    return TrekCard(
                      adventure: a,
                      saved: saved.contains(a.id),
                      onTap: () => context.push('/adventure/${a.id}'),
                      onToggleSaved: () => ref.read(savedProvider.notifier).toggle(a.id),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _sortSheet(BuildContext context) {
    final n = ref.read(exploreFilterProvider.notifier);
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(padding: EdgeInsets.all(14), child: Text('Sort programmes', style: TsText.h3)),
            for (final (sort, icon, label) in [
              (ExploreSort.recommended, Icons.auto_awesome, 'Recommended'),
              (ExploreSort.cheapest, Icons.payments_outlined, 'Cheapest first'),
              (ExploreSort.nearest, Icons.near_me, 'Nearest to me'),
              (ExploreSort.shortest, Icons.straighten, 'Shortest first'),
              (ExploreSort.easiest, Icons.flag_outlined, 'Easiest first'),
            ])
              ListTile(
                leading: Icon(icon, color: TsColors.neon),
                title: Text(label),
                trailing: ref.read(exploreFilterProvider).sort == sort ? const Icon(Icons.check, color: TsColors.neon) : null,
                onTap: () async {
                  Navigator.pop(ctx);
                  n.update((s) => s.copyWith(sort: sort));
                  if (sort == ExploreSort.nearest && _here == null) await _locate();
                },
              ),
          ],
        ),
      ),
    );
  }

  void _openFilters(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _FilterSheet(),
    );
  }
}

/// Horizontal row of destination cards. Tap to filter, tap again to clear,
/// tap the arrow to open the destination page.
class _DestinationStrip extends StatelessWidget {
  const _DestinationStrip({required this.destinations, required this.selected, required this.onSelect, required this.onOpen});
  final List<Destination> destinations;
  final String? selected;
  final ValueChanged<String?> onSelect;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 124,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        itemCount: destinations.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final d = destinations[i];
          final sel = d.id == selected;
          return GestureDetector(
            onTap: () => onSelect(sel ? null : d.id),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 168,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(TsSpace.radiusMd),
                border: Border.all(color: sel ? TsColors.neon : Colors.transparent, width: 2),
              ),
              child: AdventureCover(
                image: d.coverImage,
                hue: 140,
                icon: Icons.forest,
                borderRadius: BorderRadius.circular(TsSpace.radiusMd - 2),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black.withValues(alpha: 0.85)]),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 10,
                      right: 34,
                      bottom: 8,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(d.shortName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Colors.white)),
                          Text('${d.programCount} programmes', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: sel ? TsColors.neon : Colors.white70)),
                        ],
                      ),
                    ),
                    Positioned(
                      right: 4,
                      bottom: 4,
                      child: IconButton(
                        visualDensity: VisualDensity.compact,
                        tooltip: 'About ${d.shortName}',
                        onPressed: () => onOpen(d.id),
                        icon: const Icon(Icons.arrow_circle_right_outlined, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _DestinationHeader extends StatelessWidget {
  const _DestinationHeader(this.d, {required this.onOpen});
  final Destination d;
  final VoidCallback onOpen;
  @override
  Widget build(BuildContext context) {
    return TsCard(
      onTap: onOpen,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(d.name, style: TsText.h3),
                const SizedBox(height: 2),
                Text(d.tagline, style: TsText.caption, maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Text('About', style: TextStyle(color: TsColors.neon, fontWeight: FontWeight.w700)),
          const Icon(Icons.chevron_right, color: TsColors.neon),
        ],
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.icon, required this.iconColor, required this.text, required this.onTap, this.neon = false});
  final IconData icon;
  final Color iconColor;
  final String text;
  final VoidCallback onTap;
  final bool neon;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
      child: TsCard(
        color: neon ? TsColors.neon : null,
        highlighted: !neon,
        onTap: onTap,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 16, color: iconColor),
            const SizedBox(width: 10),
            Expanded(child: Text(text, style: TsText.bodyStrong.copyWith(color: neon ? TsColors.onNeon : null))),
            Icon(Icons.chevron_right, color: neon ? TsColors.onNeon : TsColors.textMuted),
          ],
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.icon, required this.title, required this.body, this.action});
  final IconData icon;
  final String title;
  final String body;
  final Widget? action;
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
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    );
  }
}

class _FilterSheet extends ConsumerWidget {
  const _FilterSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = ref.watch(exploreFilterProvider);
    final n = ref.read(exploreFilterProvider.notifier);
    final destinations = ref.watch(destinationsProvider).value ?? const <Destination>[];
    final all = ref.watch(adventuresProvider).value ?? const <Adventure>[];
    final categories = ActivityCategory.values.where((c) => all.any((a) => a.categories.contains(c))).toList();
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      builder: (ctx, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
        children: [
          Row(
            children: [
              const Expanded(child: Text('Filters', style: TsText.h2)),
              TextButton(onPressed: n.reset, child: const Text('Reset')),
            ],
          ),
          const SectionHeader('Destination', top: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(label: const Text('All Thrissur'), selected: f.destinationId == null, onSelected: (_) => n.update((s) => s.copyWith(clearDestination: true))),
              for (final d in destinations)
                ChoiceChip(label: Text(d.shortName), selected: f.destinationId == d.id, onSelected: (_) => n.update((s) => s.copyWith(destinationId: d.id))),
            ],
          ),
          const SectionHeader('Programme type'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final t in ProgramType.values.where((t) => all.any((a) => a.programType == t)))
                FilterChip(
                  avatar: Icon(t.icon, size: 16, color: f.programTypes.contains(t) ? TsColors.onNeon : TsColors.neon),
                  label: Text(t.label),
                  selected: f.programTypes.contains(t),
                  onSelected: (sel) => n.update((s) {
                    final next = {...s.programTypes};
                    sel ? next.add(t) : next.remove(t);
                    return s.copyWith(programTypes: next);
                  }),
                ),
            ],
          ),
          const SectionHeader('Activity'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in categories)
                FilterChip(
                  avatar: Icon(c.icon, size: 16, color: f.categories.contains(c) ? TsColors.onNeon : TsColors.neon),
                  label: Text(c.label),
                  selected: f.categories.contains(c),
                  onSelected: (sel) => n.update((s) {
                    final next = {...s.categories};
                    sel ? next.add(c) : next.remove(c);
                    return s.copyWith(categories: next);
                  }),
                ),
            ],
          ),
          const SectionHeader('Difficulty'),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(label: const Text('Any'), selected: f.difficulty == null, onSelected: (_) => n.update((s) => s.copyWith(clearDifficulty: true))),
              for (final d in Difficulty.values)
                ChoiceChip(label: Text(d.label), selected: f.difficulty == d, onSelected: (_) => n.update((s) => s.copyWith(difficulty: d))),
            ],
          ),
          SectionHeader('Max price${f.maxPrice == null ? '' : ' · ${ProgramPricing.rupees(f.maxPrice!)}'}'),
          Slider(
            value: (f.maxPrice ?? 15000).clamp(300, 15000).toDouble(),
            min: 300,
            max: 15000,
            divisions: 49,
            label: f.maxPrice == null ? 'Any' : ProgramPricing.rupees(f.maxPrice!),
            onChanged: (v) => n.update((s) => v >= 15000 ? s.copyWith(clearPrice: true) : s.copyWith(maxPrice: v.round())),
          ),
          SectionHeader('Max distance${f.maxDistanceKm == null ? '' : ' · ${f.maxDistanceKm!.round()} km'}'),
          Slider(
            value: (f.maxDistanceKm ?? 15).clamp(1, 15),
            min: 1,
            max: 15,
            divisions: 14,
            label: f.maxDistanceKm == null ? 'Any' : '${f.maxDistanceKm!.round()} km',
            onChanged: (v) => n.update((s) => v >= 15 ? s.copyWith(clearDistance: true) : s.copyWith(maxDistanceKm: v)),
          ),
          SectionHeader('Max duration${f.maxDurationHours == null ? '' : ' · ${f.maxDurationHours!.round()} hrs'}'),
          Slider(
            value: (f.maxDurationHours ?? 24).clamp(1, 24),
            min: 1,
            max: 24,
            divisions: 23,
            label: f.maxDurationHours == null ? 'Any' : '${f.maxDurationHours!.round()} hrs',
            onChanged: (v) => n.update((s) => v >= 24 ? s.copyWith(clearDuration: true) : s.copyWith(maxDurationHours: v)),
          ),
          const SectionHeader('Good for'),
          SwitchListTile(value: f.savedOnly, onChanged: (v) => n.update((s) => s.copyWith(savedOnly: v)), title: const Text('Saved only'), contentPadding: EdgeInsets.zero),
          SwitchListTile(value: f.groupFriendly, onChanged: (v) => n.update((s) => s.copyWith(groupFriendly: v)), title: const Text('Group friendly'), contentPadding: EdgeInsets.zero),
          SwitchListTile(value: f.beginnerFriendly, onChanged: (v) => n.update((s) => s.copyWith(beginnerFriendly: v)), title: const Text('Beginner friendly'), contentPadding: EdgeInsets.zero),
          const SizedBox(height: 12),
          NeonButton(label: 'Show results', onPressed: () => Navigator.pop(ctx)),
        ],
      ),
    );
  }
}
