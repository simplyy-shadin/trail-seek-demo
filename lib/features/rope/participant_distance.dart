import 'engine/geo.dart';

/// Distance between two members, **from GPS only**, and only when both fixes
/// are fresh. Bluetooth signal strength is never turned into a distance
/// (product plan §6). Returns null when it should not be shown.
String? coarseDistance({
  required GeoPoint? a,
  required DateTime? aAt,
  required GeoPoint? b,
  required DateTime? bAt,
  required DateTime now,
  Duration maxAge = const Duration(seconds: 30),
  bool metric = true,
}) {
  if (a == null || b == null || aAt == null || bAt == null) return null;
  if (now.difference(aAt) > maxAge || now.difference(bAt) > maxAge) return null;
  final m = haversineMetres(a, b);
  if (!metric) {
    final ft = m * 3.28084;
    if (ft < 1500) return '< 0.3 mi';
    final mi = m / 1609.344;
    return mi < 2 ? '~${mi.toStringAsFixed(1)} mi' : '~${mi.round()} mi';
  }
  if (m < 500) return '< 500 m';
  final km = m / 1000;
  return km < 2 ? '~${km.toStringAsFixed(1)} km' : '~${km.round()} km';
}
