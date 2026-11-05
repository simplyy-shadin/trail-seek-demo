import 'dart:typed_data';

enum RopeControlType { requestStart, endGroup }

/// Organizer/member control sent only in an authenticated GATT envelope.
/// BLE advertising flags are merely untrusted synchronization hints.
class RopeControlFrame {
  const RopeControlFrame({
    required this.type,
    required this.originIndex,
    required this.sequence,
    required this.createdAt,
  });

  static const magic = 0xA9;
  static const wireLength = 9;
  static const maxAge = Duration(minutes: 2);

  final RopeControlType type;
  final int originIndex;
  final int sequence;
  final DateTime createdAt;

  String get id => '$originIndex:${type.index}:$sequence';

  Uint8List toBytes() {
    if (originIndex < 0 || originIndex > 15 || sequence < 0 || sequence > 255) {
      throw ArgumentError('Invalid group control sender or sequence');
    }
    final b = ByteData(wireLength);
    b.setUint8(0, magic);
    b.setUint8(1, type.index + 1);
    b.setUint8(2, originIndex);
    b.setUint8(3, sequence);
    b.setUint32(4, createdAt.toUtc().millisecondsSinceEpoch ~/ 1000);
    b.setUint8(8, 0);
    return b.buffer.asUint8List();
  }

  static RopeControlFrame? fromBytes(Uint8List bytes, {required DateTime now}) {
    if (bytes.length != wireLength) return null;
    final b = ByteData.sublistView(bytes);
    final typeIndex = b.getUint8(1) - 1;
    if (b.getUint8(0) != magic || typeIndex < 0 ||
        typeIndex >= RopeControlType.values.length ||
        b.getUint8(2) > 15 || b.getUint8(8) != 0) {
      return null;
    }
    final at = DateTime.fromMillisecondsSinceEpoch(
        b.getUint32(4) * 1000, isUtc: true);
    final age = now.toUtc().difference(at);
    if (age > maxAge || age < const Duration(seconds: -30)) return null;
    return RopeControlFrame(
      type: RopeControlType.values[typeIndex],
      originIndex: b.getUint8(2),
      sequence: b.getUint8(3),
      createdAt: at,
    );
  }
}
