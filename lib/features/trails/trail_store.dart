import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart' as digest;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/backend.dart';
import '../../app/providers.dart';
import '../rope/engine/geo.dart';
import 'trail_learner.dart';

/// Keeps every walk recorded on each adventure and the trail learned from
/// them. The state is a version number that bumps when a trail changes.
///
/// Walks come from finished treks: your own, plus every group member's path
/// (shared phone to phone during the trek). With the cloud on, walks are
/// uploaded and other people's are pulled in, so a trail forms from
/// different groups on different days.
class TrailStore extends Notifier<int> {
  /// Walks kept per adventure (newest first); older ones add little.
  static const maxWalks = 80;

  /// The ends of an uploaded walk are trimmed so it never shows where
  /// someone parked or lives.
  static const trimEndsM = 50.0;

  static const learner = TrailLearner();

  @override
  int build() => 0;

  static String _walksKey(String adventureId) => 'trail_walks_$adventureId';
  static String _trailKey(String adventureId) => 'trail_$adventureId';

  List<Walk> walks(String adventureId) {
    final raw = ref.read(localStoreProvider).rawString(_walksKey(adventureId));
    if (raw == null) return const [];
    try {
      return [for (final e in jsonDecode(raw) as List) Walk.fromJson(e as Map<String, dynamic>)];
    } catch (_) {
      return const [];
    }
  }

  LearnedTrail trail(String adventureId) {
    final raw = ref.read(localStoreProvider).rawString(_trailKey(adventureId));
    if (raw == null) return LearnedTrail.none;
    try {
      return LearnedTrail.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return LearnedTrail.none;
    }
  }

  /// Records finished walks, re-learns the trail and (cloud) uploads [own].
  Future<void> addWalks(String adventureId, List<Walk> walks, {Walk? own}) async {
    final fresh = [for (final w in walks) if (w.points.length >= 2) Walk(walkerId: w.walkerId, at: w.at, points: thin(w.points))];
    if (fresh.isEmpty) return;
    await _merge(adventureId, fresh);
    if (own != null && Backend.isCloud) unawaited(_upload(adventureId, own));
  }

  /// Pulls other people's walks for [adventureId] from the cloud.
  Future<void> sync(String adventureId) async {
    if (!Backend.isCloud) return;
    try {
      final rows = await Backend.client
          .from('trail_walks')
          .select('walker_key, walked_at, points')
          .eq('adventure_id', adventureId)
          .order('walked_at', ascending: false)
          .limit(maxWalks);
      final cloud = <Walk>[
        for (final r in rows)
          Walk(
            walkerId: r['walker_key'] as String,
            at: DateTime.tryParse(r['walked_at'] as String? ?? ''),
            points: [for (final p in r['points'] as List) GeoPoint((p[0] as num).toDouble(), (p[1] as num).toDouble())],
          ),
      ];
      if (cloud.isNotEmpty) await _merge(adventureId, cloud);
    } catch (e) {
      debugPrint('[TRAILS] sync failed: $e');
    }
  }

  Future<void> _merge(String adventureId, List<Walk> incoming) async {
    String key(Walk w) => '${w.walkerId}@${w.at?.millisecondsSinceEpoch ?? w.points.first}';
    final all = {for (final w in walks(adventureId)) key(w): w};
    for (final w in incoming) {
      all[key(w)] = w;
    }
    final kept = all.values.toList()
      ..sort((a, b) => (b.at ?? DateTime(2000)).compareTo(a.at ?? DateTime(2000)));
    final list = kept.take(maxWalks).toList();
    final store = ref.read(localStoreProvider);
    await store.setRaw(_walksKey(adventureId), jsonEncode([for (final w in list) w.toJson()]));
    final learned = learner.learn(list);
    await store.setRaw(_trailKey(adventureId), jsonEncode(learned.toJson()));
    debugPrint('[TRAILS] $adventureId: ${list.length} walks, ${learned.walkers} walkers, ${learned.segments.length} pieces, ${learned.lengthM.round()} m');
    state = state + 1;
  }

  Future<void> _upload(String adventureId, Walk own) async {
    final pts = trimEnds(thin(own.points), trimEndsM);
    if (pts.length < 2) return;
    try {
      await Backend.client.from('trail_walks').insert({
        'adventure_id': adventureId,
        'walker_key': walkerKey(own.walkerId),
        'walked_at': (own.at ?? DateTime.now()).toUtc().toIso8601String(),
        'points': [for (final p in pts) [double.parse(p.lat.toStringAsFixed(6)), double.parse(p.lng.toStringAsFixed(6))]],
      });
    } catch (e) {
      debugPrint('[TRAILS] upload failed: $e');
    }
  }

  /// Same person → same key, but the key does not reveal who.
  static String walkerKey(String id) => digest.sha256.convert(utf8.encode('trailseek-walker-v1:$id')).toString().substring(0, 16);

  /// One point every 5 m at most; enough for learning, small to store.
  static List<GeoPoint> thin(List<GeoPoint> pts, {double minM = 5}) {
    if (pts.length <= 2) return pts;
    final out = <GeoPoint>[pts.first];
    for (final p in pts.skip(1)) {
      if (haversineMetres(out.last, p) >= minM) out.add(p);
    }
    if (out.last != pts.last) out.add(pts.last);
    return out;
  }

  /// Drops the first and last [m] metres of a path.
  static List<GeoPoint> trimEnds(List<GeoPoint> pts, double m) {
    int cut(List<GeoPoint> p) {
      var d = 0.0;
      for (var i = 1; i < p.length; i++) {
        d += haversineMetres(p[i - 1], p[i]);
        if (d >= m) return i;
      }
      return p.length;
    }

    final head = cut(pts);
    final tail = pts.length - cut(pts.reversed.toList());
    return head < tail ? pts.sublist(head, tail) : const [];
  }
}

final trailStoreProvider = NotifierProvider<TrailStore, int>(TrailStore.new);

/// The crowd-learned trail for an adventure; empty until 3+ people walked it.
final learnedTrailProvider = Provider.family<LearnedTrail, String>((ref, adventureId) {
  ref.watch(trailStoreProvider);
  return ref.read(trailStoreProvider.notifier).trail(adventureId);
});
