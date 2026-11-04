import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../progress/progress.dart';

/// Demo explorers bundled with the app (assets/data/explorers.json, generated
/// by tools/explorers/build.py): real-looking faces and trekking histories.
class ExplorerDirectory {
  ExplorerDirectory(this.people, this.activities);
  final List<DemoExplorer> people;
  final Map<String, List<ActivityRecord>> activities;

  static ExplorerDirectory? _cache;

  static Future<ExplorerDirectory> load([AssetBundle? bundle]) async {
    if (_cache != null) return _cache!;
    final raw = jsonDecode(await (bundle ?? rootBundle).loadString('assets/data/explorers.json')) as Map<String, dynamic>;
    final people = (raw['explorers'] as List).map((e) => DemoExplorer.fromJson((e as Map).cast<String, dynamic>())).toList();
    final acts = <String, List<ActivityRecord>>{};
    (raw['activities'] as Map).forEach((k, v) => acts[k as String] = [for (final r in v as List) ActivityRecord.fromJson((r as Map).cast<String, dynamic>())]);
    return _cache = ExplorerDirectory(people, acts);
  }

  DemoExplorer? byId(String id) {
    for (final p in people) {
      if (p.id == id || p.cloudId == id) return p;
    }
    return null;
  }
}

class DemoExplorer {
  const DemoExplorer({required this.id, required this.cloudId, required this.name, required this.username, required this.town, required this.bio, required this.avatar, required this.xp});
  factory DemoExplorer.fromJson(Map<String, dynamic> j) => DemoExplorer(
        id: j['id'] as String,
        cloudId: j['cloudId'] as String,
        name: j['name'] as String,
        username: j['username'] as String,
        town: j['town'] as String,
        bio: j['bio'] as String,
        avatar: j['avatar'] as String,
        xp: (j['xp'] as num).toInt(),
      );
  final String id;
  final String cloudId;
  final String name;
  final String username;
  final String town;
  final String bio;
  final String avatar;
  final int xp;
}

final explorerDirectoryProvider = FutureProvider<ExplorerDirectory>((ref) => ExplorerDirectory.load());

/// One skill on the character sheet ("Trekking Lv 7").
class Skill {
  const Skill({required this.label, required this.icon, required this.count, required this.km, required this.level, required this.progress});
  final String label;
  final IconData icon;
  final int count;
  final double km;
  final int level;

  /// 0..1 towards the next skill level.
  final double progress;
}

/// Everything the explorer profile shows, derived from the activity history
/// with the same engine that scores the signed-in user.
class CharacterSheet {
  CharacterSheet(this.records) : state = const ProgressEngine().rebuild(records);
  final List<ActivityRecord> records;
  final ProgressState state;

  static const _groups = <(String, IconData, List<ActivityType>)>[
    ('Trekking', Icons.hiking, [ActivityType.trekking, ActivityType.mountaineering]),
    ('Hiking', Icons.terrain, [ActivityType.hiking]),
    ('Forest & falls', Icons.forest, [ActivityType.forestWalk, ActivityType.waterfallTrail]),
    ('Coracle & water', Icons.sailing, [ActivityType.kayaking, ActivityType.rafting]),
    ('Cycling', Icons.pedal_bike, [ActivityType.cycling, ActivityType.mountainBiking]),
  ];

  /// Skill level: every 3 outings or 25 km in that kind, whichever is further.
  List<Skill> get skills {
    final out = <Skill>[];
    for (final (label, icon, types) in _groups) {
      final rs = records.where((r) => types.contains(r.type)).toList();
      final km = rs.fold<double>(0, (s, r) => s + r.distanceM / 1000);
      final points = rs.length / 3 + km / 25;
      out.add(Skill(label: label, icon: icon, count: rs.length, km: km, level: 1 + points.floor(), progress: points - points.floor()));
    }
    out.sort((a, b) => b.count.compareTo(a.count));
    return out;
  }

  /// "Peak Hunter", "Forest Ranger"… from what this explorer does most and best.
  String get archetype {
    final s = state.stats;
    if (s.highestAltitudeM >= 2000 && s.peaksAbove1500 >= 2) return 'Peak Hunter';
    final top = skills.first;
    if (top.count == 0) return 'Newcomer';
    return switch (top.label) {
      'Trekking' => s.groupSessions >= 10 ? 'Group Leader' : 'Trail Trekker',
      'Hiking' => 'Ridge Hiker',
      'Forest & falls' => 'Forest Ranger',
      'Coracle & water' => 'River Explorer',
      'Cycling' => 'Sanctuary Rider',
      _ => 'Explorer',
    };
  }

  List<ActivityRecord> get recent => [...records]..sort((a, b) => b.endedAt.compareTo(a.endedAt));

  ActivityRecord? get longest => records.isEmpty ? null : records.reduce((a, b) => a.distanceM >= b.distanceM ? a : b);
  ActivityRecord? get highest => records.isEmpty ? null : records.reduce((a, b) => a.maxAltitudeM >= b.maxAltitudeM ? a : b);
}
