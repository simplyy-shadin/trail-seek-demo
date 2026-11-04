import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';

import '../../data/models/activity_category.dart';
import '../../data/models/adventure.dart';

enum ExploreSort { recommended, nearest, shortest, easiest, cheapest }

/// Explore filter state. Lives in a provider so it survives tab switches.
class ExploreFilter {
  const ExploreFilter({
    this.destinationId,
    this.query = '',
    this.categories = const {},
    this.programTypes = const {},
    this.difficulty,
    this.maxDistanceKm,
    this.maxDurationHours,
    this.maxPrice,
    this.savedOnly = false,
    this.groupFriendly = false,
    this.beginnerFriendly = false,
    this.sort = ExploreSort.recommended,
  });

  /// One of the Thrissur destinations, or null for all.
  final String? destinationId;
  final String query;
  final Set<ActivityCategory> categories;
  final Set<ProgramType> programTypes;
  final Difficulty? difficulty;
  final double? maxDistanceKm;
  final double? maxDurationHours;

  /// Upper bound on the lowest ticket price (package or per person).
  final int? maxPrice;
  final bool savedOnly;
  final bool groupFriendly;
  final bool beginnerFriendly;
  final ExploreSort sort;

  /// Number of non-default filters, shown as a badge on the filter button.
  int get activeCount =>
      categories.length +
      programTypes.length +
      (destinationId != null ? 1 : 0) +
      (difficulty != null ? 1 : 0) +
      (maxDistanceKm != null ? 1 : 0) +
      (maxDurationHours != null ? 1 : 0) +
      (maxPrice != null ? 1 : 0) +
      (savedOnly ? 1 : 0) +
      (groupFriendly ? 1 : 0) +
      (beginnerFriendly ? 1 : 0);

  /// Filters that live in the sheet (everything except the bar's own chips).
  int get sheetCount => activeCount - programTypes.length - (destinationId != null ? 1 : 0) - (savedOnly ? 1 : 0);

  bool matches(Adventure a, Set<String> saved) {
    if (destinationId != null && a.destinationId != destinationId) return false;
    if (programTypes.isNotEmpty && !programTypes.contains(a.programType)) return false;
    if (categories.isNotEmpty && !a.categories.any(categories.contains)) return false;
    if (difficulty != null && a.difficulty != difficulty) return false;
    if (maxDistanceKm != null && a.distanceKm > maxDistanceKm!) return false;
    if (maxDurationHours != null && a.durationHoursMax > maxDurationHours!) return false;
    if (maxPrice != null && (a.pricing.fromAmount ?? 0) > maxPrice!) return false;
    if (savedOnly && !saved.contains(a.id)) return false;
    if (groupFriendly && !a.suitability.group) return false;
    if (beginnerFriendly && !a.suitability.beginner) return false;
    final q = query.trim().toLowerCase();
    if (q.isNotEmpty) {
      final hay = '${a.name} ${a.destinationName ?? ''} ${a.district} ${a.nearestTown} ${a.programType.label} ${a.categories.map((c) => c.label).join(' ')} ${a.summary}'.toLowerCase();
      if (!hay.contains(q)) return false;
    }
    return true;
  }

  ExploreFilter copyWith({
    String? destinationId,
    bool clearDestination = false,
    String? query,
    Set<ActivityCategory>? categories,
    Set<ProgramType>? programTypes,
    Difficulty? difficulty,
    bool clearDifficulty = false,
    double? maxDistanceKm,
    bool clearDistance = false,
    double? maxDurationHours,
    bool clearDuration = false,
    int? maxPrice,
    bool clearPrice = false,
    bool? savedOnly,
    bool? groupFriendly,
    bool? beginnerFriendly,
    ExploreSort? sort,
  }) =>
      ExploreFilter(
        destinationId: clearDestination ? null : (destinationId ?? this.destinationId),
        query: query ?? this.query,
        categories: categories ?? this.categories,
        programTypes: programTypes ?? this.programTypes,
        difficulty: clearDifficulty ? null : (difficulty ?? this.difficulty),
        maxDistanceKm: clearDistance ? null : (maxDistanceKm ?? this.maxDistanceKm),
        maxDurationHours: clearDuration ? null : (maxDurationHours ?? this.maxDurationHours),
        maxPrice: clearPrice ? null : (maxPrice ?? this.maxPrice),
        savedOnly: savedOnly ?? this.savedOnly,
        groupFriendly: groupFriendly ?? this.groupFriendly,
        beginnerFriendly: beginnerFriendly ?? this.beginnerFriendly,
        sort: sort ?? this.sort,
      );

  /// Orders [list]; [here] enables "nearest".
  List<Adventure> sorted(List<Adventure> list, {({double lat, double lng})? here}) {
    final out = List<Adventure>.of(list);
    switch (sort) {
      case ExploreSort.recommended:
        break;
      case ExploreSort.nearest:
        if (here == null) break;
        double d(Adventure a) => (a.lat - here.lat) * (a.lat - here.lat) + (a.lng - here.lng) * (a.lng - here.lng);
        out.sort((a, b) => d(a).compareTo(d(b)));
      case ExploreSort.shortest:
        out.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
      case ExploreSort.easiest:
        out.sort((a, b) => a.difficulty.index.compareTo(b.difficulty.index));
      case ExploreSort.cheapest:
        out.sort((a, b) => (a.pricing.fromAmount ?? 1 << 30).compareTo(b.pricing.fromAmount ?? 1 << 30));
    }
    return out;
  }

  static const empty = ExploreFilter();
}

class ExploreFilterController extends Notifier<ExploreFilter> {
  @override
  ExploreFilter build() => ExploreFilter.empty;
  void set(ExploreFilter f) => state = f;
  void update(ExploreFilter Function(ExploreFilter) fn) => state = fn(state);

  /// Keeps the search text and sort; clears every filter including destination.
  void reset() => state = ExploreFilter(query: state.query, sort: state.sort);
}

final exploreFilterProvider = NotifierProvider<ExploreFilterController, ExploreFilter>(ExploreFilterController.new);

/// Last eight searches, most recent first.
class RecentSearchesController extends Notifier<List<String>> {
  static const _key = 'recent_searches';
  @override
  List<String> build() => (ref.read(localStoreProvider).rawString(_key) ?? '').split('\u0001').where((s) => s.isNotEmpty).toList();

  Future<void> add(String q) async {
    final t = q.trim();
    if (t.length < 2) return;
    final next = [t, ...state.where((s) => s.toLowerCase() != t.toLowerCase())].take(8).toList();
    state = next;
    await ref.read(localStoreProvider).setRaw(_key, next.join('\u0001'));
  }

  Future<void> clear() async {
    state = const [];
    await ref.read(localStoreProvider).removeRaw(_key);
  }
}

final recentSearchesProvider = NotifierProvider<RecentSearchesController, List<String>>(RecentSearchesController.new);
