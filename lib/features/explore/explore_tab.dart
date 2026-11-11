
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/adventure_colors.dart';
import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../data/models/adventure.dart';
import '../../data/models/destination.dart';
import 'home_banners.dart';

class ExploreTab extends ConsumerStatefulWidget {
  const ExploreTab({super.key});

  @override
  ConsumerState<ExploreTab> createState() => _ExploreTabState();
}

class _ExploreTabState extends ConsumerState<ExploreTab> {
  String _state = 'Kerala';
  String _district = 'Thrissur';
  String _type = 'All';

  static const districts = <String>[
    'All districts',
    'Thiruvananthapuram',
    'Kollam',
    'Pathanamthitta',
    'Alappuzha',
    'Kottayam',
    'Idukki',
    'Ernakulam',
    'Thrissur',
    'Palakkad',
    'Malappuram',
    'Kozhikode',
    'Wayanad',
    'Kannur',
    'Kasaragod',
  ];

  static const types = <String>[
    'All',
    'Trekking',
    'Hiking',
    'Cycling',
    'Kayaking',
    'Camping',
  ];

  late final Future<List<_DiscoveryLead>> _leads =
      _loadLeads();

  Future<List<_DiscoveryLead>> _loadLeads() async {
    final source = await rootBundle.loadString(
      'assets/data/kerala_discovery.json',
    );

    final decoded = jsonDecode(source) as List;

    return decoded
        .map(
          (e) => _DiscoveryLead.fromJson(
            (e as Map).cast<String, dynamic>(),
          ),
        )
        .toList();
  }

  Future<void> _pickDistrict() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(ctx).height * 0.68,
          child: ListView(
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(
                  20, 18, 20, 10,
                ),
                child: Text(
                  'Choose district',
                  style: TsText.h2,
                ),
              ),
              for (final d in districts)
                ListTile(
                  title: Text(d),
                  leading: Icon(
                    d == _district
                        ? Icons.check_circle
                        : Icons.location_on_outlined,
                    color: d == _district
                        ? TsColors.neon
                        : TsColors.textMuted,
                  ),
                  onTap: () => Navigator.pop(ctx, d),
                ),
            ],
          ),
        ),
      ),
    );

    if (choice != null && mounted) {
      setState(() => _district = choice);
    }
  }

  Widget _picker(
    String label,
    VoidCallback? onTap,
  ) {
    return Expanded(
      child: Material(
        color: TsColors.surfaceHigh,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 13,
              vertical: 15,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TsText.bodyStrong,
                  ),
                ),
                const Icon(
                  Icons.keyboard_arrow_down,
                  color: TsColors.neon,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  bool _matchesProgram(
    Adventure adventure,
    String type,
  ) {
    final key = type.toLowerCase();
    final programType =
        adventure.programType.name.toLowerCase();
    final name = adventure.name.toLowerCase();

    if (key == 'kayaking') {
      return name.contains('kayak') ||
          name.contains('canoe');
    }

    if (key == 'camping') {
      return name.contains('camp') ||
          name.contains('tent');
    }

    return programType == key ||
        name.contains(key);
  }

  Widget _card({
    required String title,
    required String subtitle,
    required String detail,
    required IconData icon,
    VoidCallback? onTap,
    bool isExistingDestination = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: TsColors.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    color: TsColors.surfaceHigh,
                    borderRadius:
                        BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    size: 31,
                    color: TsColors.neon,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TsText.bodyStrong,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TsText.caption,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        detail,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: isExistingDestination
                              ? TsColors.neon
                              : TsColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  onTap == null
                      ? Icons.info_outline
                      : Icons.chevron_right,
                  color: TsColors.textMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _destinationCard(
    Destination destination,
    List<Adventure> adventures,
  ) {
    final matches = adventures
        .where(
          (a) => a.destinationId == destination.id,
        )
        .toList();

    if (_type != 'All' &&
        !matches.any(
          (a) => _matchesProgram(a, _type),
        )) {
      return const SizedBox.shrink();
    }

    return _card(
      title: destination.shortName,
      subtitle:
          '${destination.nearestTown} · ${destination.district}',
      detail: '${matches.length} listed programmes',
      icon: Icons.forest_outlined,
      isExistingDestination: true,
      onTap: () {
        context.push(
          '/destination/${destination.id}',
        );
      },
    );
  }

  IconData _activityIcon(_DiscoveryLead lead) {
    if (_type == 'Cycling' ||
        lead.types.contains('Cycling')) {
      return Icons.pedal_bike;
    }

    if (_type == 'Kayaking' ||
        lead.types.contains('Kayaking')) {
      return Icons.kayaking;
    }

    if (_type == 'Camping' ||
        lead.types.contains('Camping')) {
      return Icons.landscape_outlined;
    }

    return Icons.terrain;
  }

  @override
  Widget build(BuildContext context) {
    final destinations =
        ref.watch(destinationsProvider).value ??
            const <Destination>[];

    final adventures =
        ref.watch(adventuresProvider).value ??
            const <Adventure>[];

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        leading: IconButton(
          tooltip: 'My groups',
          onPressed: () => context.push('/groups'),
          icon: const Icon(Icons.groups_outlined),
        ),
        title: const Text('Explore'),
        actions: [
          IconButton(
            tooltip: 'Search programmes',
            onPressed: () =>
                context.push('/adventures'),
            icon: const Icon(Icons.manage_search),
          ),
        ],
      ),
      body: FutureBuilder<List<_DiscoveryLead>>(
        future: _leads,
        builder: (context, snapshot) {
          final leads =
              snapshot.data ?? const <_DiscoveryLead>[];

          final activeDestinations =
              destinations.where((d) {
            return _district == 'All districts' ||
                d.district == _district;
          }).toList();

          final filteredLeads = leads.where((d) {
            final districtMatches =
                _district == 'All districts' ||
                    d.district == _district;

            final typeMatches =
                _type == 'All' ||
                    d.types.contains(_type);

            return districtMatches && typeMatches;
          }).toList();

          final activeCount =
              activeDestinations.where((d) {
            return _type == 'All' ||
                adventures.any(
                  (a) =>
                      a.destinationId == d.id &&
                      _matchesProgram(a, _type),
                );
          }).length;

          return ListView(
            padding: const EdgeInsets.fromLTRB(
              20, 8, 20, 110,
            ),
            children: [
              const HomeBanners(inset: 0),

              // STATE AND DISTRICT SELECTORS
              Row(
                children: [
                  _picker(_state, () {
                    ScaffoldMessenger.of(context)
                        .showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Kerala is available. More states are planned.',
                        ),
                      ),
                    );
                  }),
                  const SizedBox(width: 10),
                  _picker(
                    _district,
                    _pickDistrict,
                  ),
                ],
              ),

              const SizedBox(height: 18),

              // ADVENTURE TYPE FILTERS
              const Text(
                'Adventure types',
                style: TsText.h3,
              ),

              const SizedBox(height: 10),

              SizedBox(
                height: 37,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: types.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final type = types[index];
                    final selected = _type == type;

                    return ChoiceChip(
                      label: Text(type),
                      selected: selected,
                      showCheckmark: false,
                      onSelected: (_) {
                        setState(() => _type = type);
                      },
                      labelStyle: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: selected
                            ? TsColors.onNeon
                            : TsColors.textPrimary,
                      ),
                      selectedColor: TsColors.neon,
                      backgroundColor:
                          TsColors.surfaceHigh,
                      side: BorderSide.none,
                      padding:
                          const EdgeInsets.symmetric(
                        horizontal: 6,
                      ),
                      visualDensity:
                          VisualDensity.compact,
                    );
                  },
                ),
              ),

              const SizedBox(height: 18),

              Text(
                _district == 'All districts'
                    ? 'Kerala adventures'
                    : '$_district adventures',
                style: TsText.h3,
              ),

              const SizedBox(height: 5),

              const Text(
                'Discover destinations and listed programmes. '
                'Government approval and booking availability '
                'must be checked for each programme.',
                style: TsText.caption,
              ),

              const SizedBox(height: 14),

              // EXISTING DESTINATIONS
              for (final destination
                  in activeDestinations)
                _destinationCard(
                  destination,
                  adventures,
                ),

              // ADDITIONAL KERALA DESTINATIONS
              for (final lead in filteredLeads)
                _card(
                  title: lead.name,
                  subtitle:
                      '${lead.locality} · ${lead.district}',
                  detail:
                      '${lead.types.join(' · ')} · Verification pending',
                  icon: _activityIcon(lead),
                ),

              if (snapshot.hasError)
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    'Could not load Kerala destinations.',
                    textAlign: TextAlign.center,
                  ),
                ),

              if (snapshot.connectionState ==
                  ConnectionState.waiting)
                const Center(
                  child: CircularProgressIndicator(),
                ),

              if (snapshot.connectionState ==
                      ConnectionState.done &&
                  !snapshot.hasError &&
                  activeCount +
                          filteredLeads.length ==
                      0)
                const Padding(
                  padding: EdgeInsets.symmetric(
                    vertical: 32,
                  ),
                  child: Text(
                    'No destinations found for this filter.',
                    textAlign: TextAlign.center,
                    style: TsText.caption,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _DiscoveryLead {
  const _DiscoveryLead({
    required this.name,
    required this.district,
    required this.locality,
    required this.types,
  });

  factory _DiscoveryLead.fromJson(
    Map<String, dynamic> json,
  ) {
    return _DiscoveryLead(
      name: json['name'] as String,
      district: json['district'] as String,
      locality: json['locality'] as String,
      types: (json['types'] as List)
          .cast<String>(),
    );
  }

  final String name;
  final String district;
  final String locality;
  final List<String> types;
}
