import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:trailseek/data/models/adventure.dart';
import 'package:trailseek/data/models/destination.dart';
import 'package:trailseek/data/models/region.dart';

void main() {
  final json = jsonDecode(File('assets/data/thrissur.json').readAsStringSync()) as Map<String, dynamic>;
  final programs = (json['programs'] as List).cast<Map<String, dynamic>>().map(Adventure.fromJson).toList();
  final destinations = (json['destinations'] as List).cast<Map<String, dynamic>>().map(Destination.fromJson).toList();
  final regions = (jsonDecode(File('assets/data/regions.json').readAsStringSync()) as List).cast<Map<String, dynamic>>().map(Region.fromJson).toList();

  test('Thrissur ships its Forest Department destinations and every programme', () {
    expect(destinations.length, 4);
    expect(programs.length, greaterThanOrEqualTo(20));
    expect(programs.every((a) => a.regionId == 'thrissur' && a.district == 'Thrissur'), isTrue);
    for (final d in destinations) {
      expect(programs.where((a) => a.destinationId == d.id).length, d.programCount, reason: d.id);
      expect(d.programCount, greaterThan(0), reason: d.id);
      expect(d.howToReach, isNotEmpty, reason: d.id);
    }
  });

  test('ids are unique and slug-like', () {
    final ids = programs.map((a) => a.id).toSet();
    expect(ids.length, programs.length);
    for (final id in ids) {
      expect(RegExp(r'^[a-z0-9-]+$').hasMatch(id), isTrue, reason: id);
    }
  });

  test('every programme has the fields the detail page needs', () {
    for (final a in programs) {
      expect(a.categories, isNotEmpty, reason: a.id);
      expect(a.lat, inInclusiveRange(10.2, 10.8), reason: '${a.id} lat outside Thrissur');
      expect(a.lng, inInclusiveRange(76.3, 76.7), reason: '${a.id} lng outside Thrissur');
      expect(a.summary, isNotEmpty, reason: a.id);
      expect(a.risks, isNotEmpty, reason: a.id);
      expect(a.precautions, isNotEmpty, reason: a.id);
      expect(a.checklist, isNotEmpty, reason: a.id);
      expect(a.highlights, isNotEmpty, reason: a.id);
      expect(a.emergencyContacts.any((c) => c.phone == '112'), isTrue, reason: '${a.id} missing 112');
      expect(a.gear.hydration, isNotEmpty, reason: a.id);
      expect(a.booking, isNotNull, reason: a.id);
      if (a.booking!.availability == Availability.open) expect(a.pricing.fromAmount, isNotNull, reason: '${a.id} has no price');
    }
  });

  test('every bundled photo exists', () {
    final used = <String>{for (final a in programs) ...a.images, for (final d in destinations) ...d.images};
    expect(used, isNotEmpty);
    for (final path in used) {
      expect(File(path).existsSync(), isTrue, reason: path);
    }
    for (final a in programs) {
      expect(a.images, isNotEmpty, reason: '${a.id} has no photo');
    }
  });

  test('nothing in the dataset points users to another booking channel', () {
    final raw = File('assets/data/thrissur.json').readAsStringSync().toLowerCase();
    for (final word in ['portal', 'website', 'online booking', 'ecotourism.forest', 'book through', 'call the', 'ask at the']) {
      expect(raw.contains(word), isFalse, reason: 'found "$word"');
    }
  });

  test('only Thrissur is enabled at launch', () {
    expect(regions.where((r) => r.enabled).map((r) => r.id), ['thrissur']);
  });
}
