import 'dart:convert';
import 'dart:ui' show Color;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import 'engine/geo.dart';

/// A distinct line colour per member slot, so ten paths on one map stay
/// tellable apart (the pin ring still shows the member's rope state).
const memberPathColors = <Color>[
  Color(0xFFFF8A00), Color(0xFF00C2FF), Color(0xFFFF4FA3), Color(0xFFB57BFF),
  Color(0xFFFFD400), Color(0xFF00E0A4), Color(0xFFFF5A5A), Color(0xFFE040FB),
  Color(0xFF4F7BFF), Color(0xFFFF9EDB), Color(0xFF00FFF0), Color(0xFFE0A060),
  Color(0xFFBCAAA4), Color(0xFFFF7A3C), Color(0xFF9AA8FF), Color(0xFFFFFFFF),
];

Color memberPathColor(int memberIndex) => memberPathColors[memberIndex % memberPathColors.length];

/// One member's walked path, kept with the trek so it can be looked at later.
class MemberPath {
  const MemberPath({required this.memberId, required this.name, required this.memberIndex, required this.isSelf, required this.points});

  factory MemberPath.fromJson(Map<String, dynamic> j) => MemberPath(
        memberId: j['id'] as String,
        name: j['name'] as String? ?? '',
        memberIndex: (j['index'] as num?)?.toInt() ?? 0,
        isSelf: j['self'] == true,
        points: [for (final p in (j['pts'] as List? ?? const [])) GeoPoint((p[0] as num).toDouble(), (p[1] as num).toDouble())],
      );

  final String memberId;
  final String name;
  final int memberIndex;
  final bool isSelf;
  final List<GeoPoint> points;

  Map<String, dynamic> toJson() => {
        'id': memberId,
        'name': name,
        'index': memberIndex,
        'self': isSelf,
        'pts': [for (final p in points) [double.parse(p.lat.toStringAsFixed(7)), double.parse(p.lng.toStringAsFixed(7))]],
      };
}

/// Every member's path for a finished group trek (key: the activity id).
class GroupTrailStore {
  GroupTrailStore(this._ref);
  final Ref _ref;

  static String _key(String activityId) => 'group_trails_$activityId';

  List<MemberPath> load(String activityId) {
    final raw = _ref.read(localStoreProvider).rawString(_key(activityId));
    if (raw == null) return const [];
    try {
      return [for (final e in jsonDecode(raw) as List) MemberPath.fromJson(e as Map<String, dynamic>)];
    } catch (_) {
      return const [];
    }
  }

  Future<void> save(String activityId, List<MemberPath> paths) =>
      _ref.read(localStoreProvider).setRaw(_key(activityId), jsonEncode([for (final p in paths) p.toJson()]));

  Future<void> delete(String activityId) => _ref.read(localStoreProvider).removeRaw(_key(activityId));
}

final groupTrailStoreProvider = Provider<GroupTrailStore>((ref) => GroupTrailStore(ref));

final groupTrailsProvider = Provider.family<List<MemberPath>, String>((ref, id) {
  ref.watch(activitiesProvider); // refresh when activities change
  return ref.read(groupTrailStoreProvider).load(id);
});
