import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/activity_category.dart';
import '../models/adventure.dart';
import '../models/destination.dart';
import '../models/region.dart';

/// Reads the bundled discovery content. Offline by design.
///
/// Content is Thrissur district's Forest Department eco-tourism programmes,
/// generated into assets/data/thrissur.json by tools/thrissur/build_data.py.
class AdventureRepository {
  AdventureRepository({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;
  final AssetBundle _bundle;

  List<Adventure>? _adventures;
  List<Destination>? _destinations;
  List<Region>? _regions;
  String? _generatedAt;

  Future<List<Region>> regions() async {
    if (_regions != null) return _regions!;
    final raw = await _bundle.loadString('assets/data/regions.json');
    final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    return _regions = list.map(Region.fromJson).toList();
  }

  Future<void> _load() async {
    if (_adventures != null) return;
    final raw = await _bundle.loadString('assets/data/thrissur.json');
    final json = jsonDecode(raw) as Map<String, dynamic>;
    _generatedAt = json['generatedAt'] as String?;
    _destinations = (json['destinations'] as List).cast<Map<String, dynamic>>().map(Destination.fromJson).toList();
    _adventures = (json['programs'] as List).cast<Map<String, dynamic>>().map(Adventure.fromJson).toList();
  }

  /// When the programme data was last pulled from the Forest Department portal.
  Future<String?> generatedAt() async {
    await _load();
    return _generatedAt;
  }

  Future<List<Adventure>> all() async {
    await _load();
    return _adventures!;
  }

  Future<List<Destination>> destinations() async {
    await _load();
    return _destinations!;
  }

  Future<Destination?> destinationById(String id) async {
    for (final d in await destinations()) {
      if (d.id == id) return d;
    }
    return null;
  }

  Future<Adventure?> byId(String id) async {
    for (final a in await all()) {
      if (a.id == id) return a;
    }
    return null;
  }

  Future<List<Adventure>> search({
    String? regionId,
    ActivityCategory? category,
    Difficulty? difficulty,
    String query = '',
  }) async {
    final q = query.trim().toLowerCase();
    return (await all()).where((a) {
      if (regionId != null && a.regionId != regionId) return false;
      if (category != null && !a.categories.contains(category)) return false;
      if (difficulty != null && a.difficulty != difficulty) return false;
      if (q.isNotEmpty &&
          !a.name.toLowerCase().contains(q) &&
          !a.district.toLowerCase().contains(q) &&
          !a.nearestTown.toLowerCase().contains(q) &&
          !(a.destinationName ?? '').toLowerCase().contains(q)) {
        return false;
      }
      return true;
    }).toList();
  }
}
