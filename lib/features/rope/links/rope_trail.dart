import 'dart:typed_data';

import '../engine/geo.dart';

/// One breadcrumb of a member's walked path.
class TrailPoint {
  const TrailPoint(this.lat, this.lng, this.at);
  final double lat;
  final double lng;
  final DateTime at;

  GeoPoint get geo => GeoPoint(lat, lng);
}

/// A member's path from one run of their phone's rope (a run restarts if the
/// app is reopened mid-trek, so one member can have several runs).
typedef TrailKey = ({int index, int run});

/// Every member's full walked path, shared phone to phone over BLE so each
/// phone ends up with everyone's complete line, not just the latest fix.
///
/// Each phone only ever holds a gap-free prefix of every line: the owner
/// appends, and a copy is extended only by points that follow straight on
/// from what it already has. So "how many points I have" is the whole
/// request, and anything a phone serves is safe to pass on hop by hop.
///
/// Wire formats (both carried inside the group's MAC / AES-GCM envelope):
/// * request  `0x54 1 n {index u8, run u32, have u16} * n`
/// * response `1 {index u8, run u32, start u16, n u8, {lat i32, lng i32, t u32} * n} *`
///   with latitude and longitude in units of 1e-7 degrees (about 1 cm).
class TrailBook {
  /// Own breadcrumbs: a new point after this much movement…
  static const minStepM = 5.0;

  /// …or after this long standing still, so the pin stays fresh.
  static const maxGap = Duration(seconds: 30);

  static const requestType = 0x54;
  static const version = 1;
  static const _pointBytes = 12;
  static const _blockHeader = 8;

  final Map<TrailKey, List<TrailPoint>> _lines = {};

  Iterable<TrailKey> get keys => _lines.keys;
  int count(TrailKey k) => _lines[k]?.length ?? 0;
  List<TrailPoint> line(TrailKey k) => _lines[k] ?? const [];

  /// [index]'s whole path, runs in the order they started.
  List<TrailPoint> pathOf(int index) {
    final runs = _lines.keys.where((k) => k.index == index).toList()..sort((a, b) => a.run.compareTo(b.run));
    return [for (final k in runs) ..._lines[k]!];
  }

  /// Our own new GPS fix. Returns true when it became a breadcrumb.
  bool addOwn(TrailKey k, TrailPoint p) {
    final line = _lines.putIfAbsent(k, () => []);
    if (line.length >= 0xFFFF) return false;
    if (line.isNotEmpty) {
      final last = line.last;
      if (haversineMetres(last.geo, p.geo) < minStepM && p.at.difference(last.at) < maxGap) return false;
    }
    line.add(p);
    return true;
  }

  /// Adds the points of a received block that extend our copy. Returns the
  /// points that were new (empty when it overlapped or left a gap).
  List<TrailPoint> merge(TrailKey k, int start, List<TrailPoint> points) {
    final line = _lines.putIfAbsent(k, () => []);
    if (start > line.length) return const []; // would leave a gap; ask again later
    final fresh = points.skip(line.length - start).toList();
    if (line.length + fresh.length > 0xFFFF) return const [];
    line.addAll(fresh);
    return fresh;
  }

  // ------------------------------------------------------------- request

  /// What we already have, so the neighbour sends only the rest.
  Uint8List encodeRequest({int maxBytes = 512}) {
    final keys = _lines.keys.where((k) => _lines[k]!.isNotEmpty).toList();
    final fit = ((maxBytes - 3) ~/ 7).clamp(0, 255);
    // A line left out is simply sent again from the start; merge skips the overlap.
    final listed = keys.take(fit).toList();
    final b = BytesBuilder()..add([requestType, version, listed.length]);
    for (final k in listed) {
      b.add(_u8(k.index));
      b.add(_u32(k.run));
      b.add(_u16(count(k)));
    }
    return b.toBytes();
  }

  /// Null when [bytes] is not a trail request.
  static Map<TrailKey, int>? parseRequest(Uint8List bytes) {
    if (bytes.length < 3 || bytes[0] != requestType || bytes[1] != version) return null;
    final n = bytes[2];
    if (bytes.length < 3 + n * 7) return null;
    final d = ByteData.sublistView(bytes);
    final have = <TrailKey, int>{};
    for (var i = 0; i < n; i++) {
      final o = 3 + i * 7;
      have[(index: d.getUint8(o), run: d.getUint32(o + 1))] = d.getUint16(o + 5);
    }
    return have;
  }

  // ------------------------------------------------------------ response

  /// The points [have] is missing, shared out fairly across members so one
  /// long line cannot starve the others, within [maxBytes].
  Uint8List encodeResponse(Map<TrailKey, int> have, {int maxBytes = 483}) {
    final want = <TrailKey, int>{}; // first index the neighbour needs
    for (final k in _lines.keys) {
      final from = have[k] ?? 0;
      if (from < _lines[k]!.length) want[k] = from;
    }
    final take = <TrailKey, int>{};
    var used = 1;
    var progress = true;
    while (progress) {
      progress = false;
      for (final k in want.keys) {
        final missing = _lines[k]!.length - want[k]! - (take[k] ?? 0);
        if (missing <= 0 || (take[k] ?? 0) >= 255) continue;
        final header = take.containsKey(k) ? 0 : _blockHeader;
        final room = (maxBytes - used - header) ~/ _pointBytes;
        if (room <= 0) continue;
        final n = [missing, room, 8, 255 - (take[k] ?? 0)].reduce((a, b) => a < b ? a : b);
        take[k] = (take[k] ?? 0) + n;
        used += header + n * _pointBytes;
        progress = true;
      }
    }
    final b = BytesBuilder()..add([version]);
    for (final e in take.entries) {
      final k = e.key;
      final start = want[k]!;
      b.add(_u8(k.index));
      b.add(_u32(k.run));
      b.add(_u16(start));
      b.add(_u8(e.value));
      for (final p in _lines[k]!.sublist(start, start + e.value)) {
        b.add(_i32((p.lat * 1e7).round()));
        b.add(_i32((p.lng * 1e7).round()));
        b.add(_u32(p.at.toUtc().millisecondsSinceEpoch ~/ 1000));
      }
    }
    return b.toBytes();
  }

  /// Blocks of a response; empty for anything malformed.
  static List<({TrailKey key, int start, List<TrailPoint> points})> parseResponse(Uint8List bytes) {
    final out = <({TrailKey key, int start, List<TrailPoint> points})>[];
    if (bytes.isEmpty || bytes[0] != version) return out;
    final d = ByteData.sublistView(bytes);
    var o = 1;
    while (o + _blockHeader <= bytes.length) {
      final key = (index: d.getUint8(o), run: d.getUint32(o + 1));
      final start = d.getUint16(o + 5);
      final n = d.getUint8(o + 7);
      o += _blockHeader;
      if (o + n * _pointBytes > bytes.length) return const [];
      final points = <TrailPoint>[];
      for (var i = 0; i < n; i++) {
        final lat = d.getInt32(o) / 1e7;
        final lng = d.getInt32(o + 4) / 1e7;
        final at = DateTime.fromMillisecondsSinceEpoch(d.getUint32(o + 8) * 1000, isUtc: true).toLocal();
        o += _pointBytes;
        if (lat.abs() > 90 || lng.abs() > 180) continue;
        points.add(TrailPoint(lat, lng, at));
      }
      if (points.length != n) continue; // a corrupt point would shift the prefix
      out.add((key: key, start: start, points: points));
    }
    return out;
  }

  static List<int> _u8(int v) => [v & 0xFF];
  static List<int> _u16(int v) => [(v >> 8) & 0xFF, v & 0xFF];
  static List<int> _u32(int v) => [(v >> 24) & 0xFF, (v >> 16) & 0xFF, (v >> 8) & 0xFF, v & 0xFF];
  static List<int> _i32(int v) => _u32(v & 0xFFFFFFFF);
}
