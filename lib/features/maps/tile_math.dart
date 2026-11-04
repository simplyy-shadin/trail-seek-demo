import 'dart:math' as math;

/// Slippy-map tile arithmetic (Web Mercator), pure Dart.
class TileId {
  const TileId(this.z, this.x, this.y);
  final int z;
  final int x;
  final int y;
  String get key => '$z/$x/$y.png';
  @override
  bool operator ==(Object other) => other is TileId && other.z == z && other.x == x && other.y == y;
  @override
  int get hashCode => Object.hash(z, x, y);
}

int lonToTileX(double lon, int z) => ((lon + 180) / 360 * (1 << z)).floor().clamp(0, (1 << z) - 1);

int latToTileY(double lat, int z) {
  final r = lat * math.pi / 180;
  final n = 1 << z;
  final y = ((1 - math.log(math.tan(r) + 1 / math.cos(r)) / math.pi) / 2 * n).floor();
  return y.clamp(0, n - 1);
}

/// Bounding box with [paddingKm] around a point.
({double south, double west, double north, double east}) boundsAround(double lat, double lng, double paddingKm) {
  final dLat = paddingKm / 111.0;
  final dLng = paddingKm / (111.0 * math.cos(lat * math.pi / 180));
  return (south: lat - dLat, west: lng - dLng, north: lat + dLat, east: lng + dLng);
}

List<TileId> tilesFor({required double south, required double west, required double north, required double east, required int minZoom, required int maxZoom}) {
  final out = <TileId>[];
  for (var z = minZoom; z <= maxZoom; z++) {
    final x0 = lonToTileX(west, z), x1 = lonToTileX(east, z);
    final y0 = latToTileY(north, z), y1 = latToTileY(south, z);
    for (var x = x0; x <= x1; x++) {
      for (var y = y0; y <= y1; y++) {
        out.add(TileId(z, x, y));
      }
    }
  }
  return out;
}

/// Rough OSM raster tile size; used for the pre-download estimate.
const averageTileBytes = 22 * 1024;

int estimateBytes(int tileCount) => tileCount * averageTileBytes;

String humanBytes(int bytes) {
  if (bytes < 1024 * 1024) return '${(bytes / 1024).round()} KB';
  if (bytes < 1024 * 1024 * 1024) return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
  return '${(bytes / 1024 / 1024 / 1024).toStringAsFixed(2)} GB';
}
