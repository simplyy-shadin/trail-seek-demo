import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../trails/trail_layer.dart';
import '../trails/trail_store.dart';
import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models/adventure.dart';
import '../maps/offline_areas.dart';
import '../maps/offline_maps_screen.dart';
import '../maps/tile_math.dart';
import '../maps/map_tiles.dart';

import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

enum _Section { overview, trail, safety, carry }

/// One Forest Department programme: photos, price, timings, booking, then the
/// trail / safety / packing sections.
class AdventureDetailScreen extends ConsumerStatefulWidget {
  const AdventureDetailScreen({super.key, required this.id});
  final String id;
  @override
  ConsumerState<AdventureDetailScreen> createState() => _AdventureDetailScreenState();
}

class _AdventureDetailScreenState extends ConsumerState<AdventureDetailScreen> {
  _Section _section = _Section.overview;

  @override
  void initState() {
    super.initState();
    // Fetch walks other people uploaded for this adventure (cloud builds).
    WidgetsBinding.instance.addPostFrameCallback((_) => ref.read(trailStoreProvider.notifier).sync(widget.id));
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(adventureByIdProvider(widget.id));
    return async.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text('$e')),
      ),
      data: (a) {
        if (a == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('Programme not found')),
          );
        }
        final saved = ref.watch(savedProvider).contains(a.id);
        final booking = a.booking ?? const BookingInfo();
        final status = TrekCard.statusLabel(a);
        return Scaffold(
          body: CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 300,
                pinned: true,
                leading: const BackButton(),
                actions: [
                  IconButton(
                    onPressed: () => ref.read(savedProvider.notifier).toggle(a.id),
                    icon: Icon(saved ? Icons.favorite : Icons.favorite_border, color: saved ? TsColors.primary : null),
                  ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: PhotoGallery(
                    images: a.images,
                    hue: a.coverHue,
                    icon: a.primaryCategory.icon,
                    overlay: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Top shade so the back and save icons read on bright skies.
                        const Align(
                          alignment: Alignment.topCenter,
                          child: SizedBox(
                            height: 130,
                            width: double.infinity,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xCC000000), Colors.transparent]),
                              ),
                            ),
                          ),
                        ),
                        Align(
                          alignment: Alignment.bottomLeft,
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.fromLTRB(20, 60, 20, 18),
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, TsColors.bg]),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(a.name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, height: 1.1)),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    const Icon(Icons.location_on, size: 16, color: TsColors.primary),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        a.destinationName ?? '${a.district}, Kerala',
                                        style: const TextStyle(color: TsColors.muted),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (a.programType != ProgramType.coracle && a.programType != ProgramType.entry) DifficultyChip(a.difficulty),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
                sliver: SliverList.list(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: StatTile(
                            icon: a.programType.icon,
                            value: a.programType == ProgramType.coracle ? '${(a.durationHoursMax * 60).round()} min' : a.distanceLabel,
                            label: a.programType == ProgramType.coracle ? 'On water' : 'Distance',
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: StatTile(icon: Icons.schedule, value: a.durationLabel, label: 'Duration'),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: StatTile(
                            icon: Icons.payments_outlined,
                            value: a.pricing.fromAmount == null ? '—' : ProgramPricing.rupees(a.pricing.fromAmount!),
                            label: a.pricing.packageAmount != null ? 'Per ticket' : 'From',
                          ),
                        ),
                      ],
                    ),
                    if (status != null) ...[
                      const SizedBox(height: 12),
                      _StatusBanner(status.$1, status.$2, switch (booking.availability) {
                        Availability.closed => 'Paused for the season. Save it and we will tell you when dates open.',
                        Availability.soon => 'Dates are being finalised. Save it to be told when booking starts.',
                        Availability.onRequest => 'Pick your dates; we confirm within two working days or refund in full.',
                        Availability.open => null,
                      }),
                    ],
                    const SizedBox(height: 12),
                    _PriceCard(a),
                    const SizedBox(height: 12),
                    _TimingCard(a, booking),
                    const SizedBox(height: 12),
                    _TrailheadMap(a),
                    const SizedBox(height: 12),
                    if (a.isWalkable) OfflineDownloadTile(adventureId: a.id, onDownload: () => _download(context, a)),
                    if (!a.verified) ...[const SizedBox(height: 12), const UnverifiedBanner()],
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 40,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          for (final s in _Section.values)
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text(switch (s) {
                                  _Section.overview => 'Overview',
                                  _Section.trail => 'Getting there',
                                  _Section.safety => 'Safety',
                                  _Section.carry => 'Things to Carry',
                                }),
                                selected: _section == s,
                                onSelected: (_) => setState(() => _section = s),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    switch (_section) {
                      _Section.overview => _Overview(a),
                      _Section.trail => _TrailInfo(a),
                      _Section.safety => _Safety(a),
                      _Section.carry => _Carry(a),
                    },
                  ],
                ),
              ),
            ],
          ),
          bottomNavigationBar: SafeArea(
            minimum: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: GhostButton(
                    label: 'Directions',
                    icon: Icons.directions,
                    onPressed: () => launchUrl(Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${a.lat},${a.lng}&travelmode=driving'), mode: LaunchMode.externalApplication),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 3,
                  child: NeonButton(label: 'Check Slots', icon: Icons.calendar_month, onPressed: booking.bookable ? () => context.push('/book/${a.id}') : null),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

extension on _AdventureDetailScreenState {
  Future<void> _download(BuildContext context, Adventure a) async {
    final (tiles, bytes) = OfflineMapsController.estimateFor(a);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Download map for offline?'),
        content: Text('About ${humanBytes(bytes)} ($tiles tiles) for 3 km around ${a.name}. Best on Wi-Fi.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Not now')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Download')),
        ],
      ),
    );
    if (ok == true) await ref.read(offlineMapsProvider.notifier).download(a);
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner(this.title, this.color, this.note);
  final String title;
  final Color color;
  final String? note;
  @override
  Widget build(BuildContext context) {
    return TsCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontWeight: FontWeight.w800, color: color),
                ),
                if (note != null && note!.isNotEmpty) Text(note!, style: TsText.caption),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PriceCard extends StatelessWidget {
  const _PriceCard(this.a);
  final Adventure a;

  @override
  Widget build(BuildContext context) {
    final p = a.pricing;
    final rows = <(String, String, bool)>[];
    if (p.packageAmount != null) rows.add(('Ticket (up to ${p.packageCovers ?? '-'} people)', ProgramPricing.rupees(p.packageAmount!), true));
    if (p.additionalPerPerson != null) rows.add(('Each extra person', ProgramPricing.rupees(p.additionalPerPerson!), false));
    if (p.perPersonIndian != null) rows.add(('Per person, Indian', ProgramPricing.rupees(p.perPersonIndian!), true));
    if (p.perPersonForeign != null) rows.add(('Per person, foreign', ProgramPricing.rupees(p.perPersonForeign!), false));
    if (p.perPerson != null) rows.add(('Per person', ProgramPricing.rupees(p.perPerson!), true));
    if (p.minimumAmount != null) rows.add(('Minimum booking', ProgramPricing.rupees(p.minimumAmount!), false));
    final extras = <(String, Map<String, int>)>[
      if (p.entryFees.isNotEmpty) (a.programType == ProgramType.entry ? 'Entry tickets' : 'Plus sanctuary entry, per person', p.entryFees),
      if (p.vehicleFees.isNotEmpty) ('Vehicle parking', p.vehicleFees),
      if (p.cameraFees.isNotEmpty) ('Camera', p.cameraFees),
    ];
    return TsCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.payments_outlined, size: 18, color: TsColors.neon),
              const SizedBox(width: 8),
              const Expanded(child: Text('Price', style: TsText.h3)),
              Text('GST included', style: TsText.caption),
            ],
          ),
          const SizedBox(height: 6),
          if (rows.isEmpty && extras.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(a.entryFee, style: const TextStyle(height: 1.4)),
            ),
          for (final r in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  Expanded(child: Text(r.$1, style: r.$3 ? TsText.bodyStrong : null)),
                  Text(
                    r.$2,
                    style: r.$3 ? const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: TsColors.neon) : TsText.bodyStrong,
                  ),
                ],
              ),
            ),
          for (final e in extras) ...[
            const SizedBox(height: 6),
            Text(e.$1, style: TsText.caption.copyWith(fontWeight: FontWeight.w700)),
            Wrap(spacing: 12, runSpacing: 2, children: [for (final f in e.$2.entries) Text('${f.key} ${ProgramPricing.rupees(f.value)}', style: TsText.caption)]),
          ],
        ],
      ),
    );
  }
}

class _TimingCard extends StatelessWidget {
  const _TimingCard(this.a, this.b);
  final Adventure a;
  final BookingInfo b;

  @override
  Widget build(BuildContext context) {
    final people = a.minPersons == null && a.maxPersons == null
        ? null
        : a.minPersons != null && a.maxPersons != null
        ? (a.pricing.additionalPerPerson != null ? 'Ticket covers up to ${a.maxPersons}; more people added per head' : '${a.minPersons}–${a.maxPersons} people per ticket')
        : a.maxPersons != null
        ? 'Up to ${a.maxPersons} people per ticket'
        : 'Minimum ${a.minPersons} people';
    return TsCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.schedule, size: 18, color: TsColors.neon),
              SizedBox(width: 8),
              Text('Timings & group size', style: TsText.h3),
            ],
          ),
          const SizedBox(height: 8),
          _line(Icons.schedule, a.timing.label + (a.timing.open != null && a.timing.startTime != null && a.timing.open != a.timing.close ? ' · gate ${a.timing.open}–${a.timing.close}' : '')),
          if (a.timing.note != null) _line(Icons.notes, a.timing.note!),
          if (people != null) _line(Icons.groups_outlined, people),
          _line(Icons.event_available, 'Book up to ${b.bookingWindowDays} days ahead${b.capacityPerDay == null ? '' : ' · ${b.capacityPerDay} seats a day'}'),
          _line(Icons.verified_user_outlined, 'Instant ticket with QR · free cancellation up to 48 h before'),
        ],
      ),
    );
  }

  Widget _line(IconData icon, String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: TsColors.textMuted),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: const TextStyle(height: 1.35))),
      ],
    ),
  );
}

class _TrailheadMap extends ConsumerWidget {
  const _TrailheadMap(this.a);
  final Adventure a;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = LatLng(a.lat, a.lng);
    final trail = ref.watch(learnedTrailProvider(a.id));
    final trailPts = [for (final s in trail.segments) for (final q in s) LatLng(q.lat, q.lng)];
    return TsCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(TsSpace.radiusLg)),
            child: SizedBox(
              height: 150,
              child: IgnorePointer(
                child: FlutterMap(
                  options: MapOptions(
                    initialCenter: p,
                    initialZoom: 12,
                    initialCameraFit: trailPts.length < 2 ? null : CameraFit.coordinates(coordinates: [p, ...trailPts], padding: const EdgeInsets.all(24), maxZoom: 16),
                    interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
                    backgroundColor: TsColors.surface,
                  ),
                  children: [
                    const TsTileLayer(),
                    LearnedTrailLayer(adventureId: a.id),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: p,
                          width: 36,
                          height: 36,
                          child: const Icon(Icons.place, color: TsColors.neon, size: 34),
                        ),
                      ],
                    ),
                    tsAttribution,
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
            child: Row(
              children: [
                Icon(trail.isEmpty ? Icons.route_outlined : Icons.route, size: 18, color: trail.isEmpty ? TsColors.textMuted : TsColors.neon),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    trail.isEmpty
                        ? 'No trail line yet. It is drawn once 3 trekkers have walked it.'
                        : 'Trail walked by ${trail.walkers} trekkers · ${(trail.lengthM / 1000).toStringAsFixed(1)} km',
                    style: TsText.caption,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
            child: Row(
              children: [
                const Icon(Icons.near_me_outlined, size: 18, color: TsColors.textMuted),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Counter near ${a.nearestTown}, ${a.district}', style: TsText.caption, maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
                TextButton.icon(
                  onPressed: () => launchUrl(Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${a.lat},${a.lng}&travelmode=driving'), mode: LaunchMode.externalApplication),
                  icon: const Icon(Icons.directions, size: 18),
                  label: const Text('Directions'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Overview extends StatefulWidget {
  const _Overview(this.a);
  final Adventure a;
  @override
  State<_Overview> createState() => _OverviewState();
}

class _OverviewState extends State<_Overview> {
  bool _official = false;
  @override
  Widget build(BuildContext context) {
    final a = widget.a;
    final tags = <String>[
      if (a.suitability.beginner) 'Beginner friendly',
      if (a.suitability.family) 'Family friendly',
      if (a.suitability.group) 'Great for groups',
      if (a.guideRequired) 'Forest guide included',
    ];
    final official = a.officialDescription.trim();
    final showOfficial = official.isNotEmpty && official != a.description.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(a.description.isEmpty ? a.summary : a.description, style: const TextStyle(height: 1.5)),
        if (showOfficial) ...[
          const SizedBox(height: 8),
          InkWell(
            onTap: () => setState(() => _official = !_official),
            child: Row(
              children: [
                Icon(_official ? Icons.expand_less : Icons.expand_more, size: 18, color: TsColors.neon),
                const SizedBox(width: 4),
                const Text(
                  'More about this programme',
                  style: TextStyle(color: TsColors.neon, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          if (_official)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(official, style: TsText.caption.copyWith(height: 1.5)),
            ),
        ],
        if (a.inclusions.isNotEmpty) ...[const SectionTitle('Included'), BulletList(a.inclusions, icon: Icons.check_circle_outline, iconColor: TsColors.green, iconSize: 18)],
        const SectionTitle('Highlights'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final h in a.highlights)
              Chip(
                label: Text(h),
                avatar: const Icon(Icons.star, size: 16, color: TsColors.amber),
              ),
          ],
        ),
        const SectionTitle('Good to know'),
        Wrap(spacing: 8, runSpacing: 8, children: [for (final t in tags) Chip(label: Text(t))]),
        const SectionTitle('Activities'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [for (final c in a.categories) Chip(avatar: CategoryIcon(c, size: 16), label: Text(c.label))],
        ),
      ],
    );
  }
}

class _TrailInfo extends StatelessWidget {
  const _TrailInfo(this.a);
  final Adventure a;
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InfoRow(icon: Icons.directions, label: 'How to reach', value: a.howToReach),
        InfoRow(icon: Icons.local_parking, label: 'Parking', value: a.parking),
        InfoRow(icon: Icons.landscape, label: 'Terrain', value: a.terrain),
        InfoRow(icon: Icons.wb_sunny_outlined, label: 'Best season', value: a.bestSeason),
        InfoRow(icon: Icons.badge_outlined, label: 'Permit', value: a.permit),
        InfoRow(icon: Icons.person_pin_circle_outlined, label: 'Guide', value: a.guideRequired ? 'Local forest guide, included' : 'Not needed'),
        InfoRow(icon: Icons.signal_cellular_alt, label: 'Network', value: a.network, color: TsColors.amber),
        InfoRow(icon: Icons.store_mall_directory_outlined, label: 'Facilities', value: a.facilities.join(', ')),
        InfoRow(icon: Icons.water_drop_outlined, label: 'Water', value: a.waterAvailability),
      ],
    );
  }
}

class _Safety extends StatelessWidget {
  const _Safety(this.a);
  final Adventure a;
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle('Common risks'),
        BulletList(a.risks, icon: Icons.warning_amber_rounded, iconColor: TsColors.amber, iconSize: 18),
        if (a.dangerousSections.isNotEmpty) ...[const SectionTitle('Dangerous sections'), BulletList(a.dangerousSections, icon: Icons.dangerous_outlined, iconColor: TsColors.red, iconSize: 18)],
        const SectionTitle('Wildlife'),
        Text(a.wildlife, style: const TextStyle(height: 1.5)),
        const SectionTitle('Precautions'),
        BulletList(a.precautions, icon: Icons.shield_outlined, iconColor: TsColors.green, iconSize: 18),
        const SectionTitle('Emergency contacts'),
        for (final c in a.emergencyContacts)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.call, color: TsColors.red),
            title: Text(c.label),
            subtitle: Text(c.phone.isEmpty ? 'Number pending verification' : c.phone, style: TextStyle(color: c.phone.isEmpty ? TsColors.amber : TsColors.muted)),
            trailing: c.phone.isEmpty ? null : const Icon(Icons.phone_forwarded, color: TsColors.neon),
            onTap: c.phone.isEmpty ? null : () => launchUrl(Uri.parse('tel:${c.phone}')),
          ),
      ],
    );
  }
}

class _Carry extends StatelessWidget {
  const _Carry(this.a);
  final Adventure a;
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InfoRow(icon: Icons.snowshoeing, label: 'Shoes', value: a.gear.shoes),
        InfoRow(icon: Icons.checkroom, label: 'Clothing', value: a.gear.clothing),
        InfoRow(icon: Icons.lunch_dining_outlined, label: 'Food', value: a.gear.food),
        InfoRow(icon: Icons.local_drink_outlined, label: 'Hydration', value: a.gear.hydration),
        InfoRow(icon: Icons.medical_services_outlined, label: 'First aid', value: a.gear.firstAid, color: TsColors.red),
        const SectionTitle('Before you go'),
        BulletList(a.checklist, icon: Icons.check_circle_outline, iconColor: TsColors.green, iconSize: 18),
      ],
    );
  }
}
