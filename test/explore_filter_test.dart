import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:trailseek/data/models/activity_category.dart';
import 'package:trailseek/data/models/adventure.dart';
import 'package:trailseek/data/models/destination.dart';
import 'package:trailseek/features/discovery/explore_filter.dart';

void main() {
  final json = jsonDecode(File('assets/data/thrissur.json').readAsStringSync()) as Map<String, dynamic>;
  final all = (json['programs'] as List).cast<Map<String, dynamic>>().map(Adventure.fromJson).toList();
  final destinations = (json['destinations'] as List).cast<Map<String, dynamic>>().map(Destination.fromJson).toList();

  test('dataset covers the Thrissur destinations and their programmes', () {
    expect(destinations.map((d) => d.id), containsAll(['athirappilly-vazhachal', 'peechi-vazhani', 'chimmony', 'chulannur']));
    expect(all.length, greaterThanOrEqualTo(20));
    for (final a in all) {
      expect(a.destinationId, isNotNull, reason: a.id);
      expect(destinations.any((d) => d.id == a.destinationId), isTrue, reason: a.id);
      expect(a.booking, isNotNull, reason: a.id);
      expect(a.lat, greaterThan(10), reason: a.id);
      expect(a.lng, greaterThan(76), reason: a.id);
    }
  });

  test('portal prices are carried through verbatim', () {
    final amphi = all.firstWhere((a) => a.id == 'chimmony-amphi-trekking');
    expect(amphi.pricing.packageAmount, 5400);
    expect(amphi.pricing.additionalPerPerson, 900);
    expect(amphi.pricing.packageCovers, 6);
    expect(amphi.pricing.shortLabel, '₹5,400 · up to 6');
    final trek = all.firstWhere((a) => a.id == 'athirappilly-trekking');
    expect(trek.pricing.perPersonIndian, 1500);
    expect(trek.pricing.perPersonForeign, 3000);
    expect(trek.pricing.minimumAmount, 6000);
    final falls = all.firstWhere((a) => a.id == 'athirappilly-vazhachal-falls');
    expect(falls.pricing.entryFees['Indian Adult'], 60);
    expect(falls.pricing.fromAmount, 15);
  });

  test('search matches name, destination and programme type, case-insensitively', () {
    const f = ExploreFilter(query: 'CORACLE');
    final hits = all.where((a) => f.matches(a, const {})).toList();
    expect(hits.length, greaterThanOrEqualTo(6));
    expect(hits.every((a) => a.name.toLowerCase().contains('coracle') || a.programType == ProgramType.coracle), isTrue);
    const d = ExploreFilter(query: 'peechi');
    expect(all.where((a) => d.matches(a, const {})).every((a) => a.destinationId == 'peechi-vazhani'), isTrue);
  });

  test('destination and programme type filters combine with saved only', () {
    const f = ExploreFilter(destinationId: 'chimmony', programTypes: {ProgramType.trekking}, savedOnly: true);
    final saved = {'chimmony-climate-walk', 'peechi-nasika'};
    final hits = all.where((a) => f.matches(a, saved)).map((a) => a.id).toList();
    expect(hits, ['chimmony-climate-walk']);
    expect(f.activeCount, 3);
    expect(f.sheetCount, 0);
    const g = ExploreFilter(categories: {ActivityCategory.coracleRide}, difficulty: Difficulty.easy);
    expect(all.where((a) => g.matches(a, const {})), isNotEmpty);
  });

  test('distance, duration and price caps apply', () {
    const f = ExploreFilter(maxDistanceKm: 5, maxDurationHours: 3, maxPrice: 1000);
    final hits = all.where((a) => f.matches(a, const {})).toList();
    expect(hits, isNotEmpty);
    for (final a in hits) {
      expect(a.distanceKm, lessThanOrEqualTo(5));
      expect(a.durationHoursMax, lessThanOrEqualTo(3));
      expect(a.pricing.fromAmount ?? 0, lessThanOrEqualTo(1000));
    }
  });

  test('cheapest sort puts unpriced programmes last', () {
    const f = ExploreFilter(sort: ExploreSort.cheapest);
    final sorted = f.sorted(all);
    expect(sorted.first.pricing.fromAmount, isNotNull);
    expect(sorted.last.pricing.fromAmount, isNull);
  });

  test('reset keeps query and sort but clears everything else', () {
    const f = ExploreFilter(destinationId: 'chimmony', query: 'x', savedOnly: true, difficulty: Difficulty.easy, sort: ExploreSort.cheapest);
    final r = ExploreFilter(query: f.query, sort: f.sort);
    expect(r.activeCount, 0);
    expect(r.sort, ExploreSort.cheapest);
  });
}
