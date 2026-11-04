import 'dart:typed_data';

import '../engine/rope_models.dart';

/// User-initiated group action, stable across BLE forwarding hops.
/// A GATT write response acknowledges the neighbouring device only;
/// it must never be shown as proof of delivery to the entire group.
class RopeActionFrame {
  const RopeActionFrame({
    required this.sessionHash,
    required this.originIndex,
    required this.sequence,
    required this.type,
    required this.sentAt,
    this.hops = 0,
  });

  static const magic = 0xA8;
  static const wireLength = 12;
  static const maxHops = 12;
  static const maxAge = Duration(minutes: 5);

  final int sessionHash;
  final int originIndex;
  final int sequence;
  final RopeMessageType type;
  final DateTime sentAt;
  final int hops;

  /// The 8-bit advertisement sequence is stable across repeated heartbeats.
  /// This ID is unique only within the bounded, five-minute event cache.
  String get id => '$sessionHash:$originIndex:$sequence';

  static bool isAction(RopeMessageType type) =>
      type != RopeMessageType.position;

  Uint8List toBytes() {
    if (!isAction(type) ||
        originIndex < 0 || originIndex > 15 ||
        sequence < 0 || sequence > 255 ||
        hops < 0 || hops > maxHops) {
      throw StateError('Invalid quick action frame');
    }
    final b = ByteData(wireLength);
    b.setUint8(0, magic);
    b.setUint16(1, sessionHash & 0xFFFF);
    b.setUint8(3, originIndex);
    b.setUint8(4, sequence);
    b.setUint8(5, type.index + 1);
    b.setUint8(6, hops);
    b.setUint32(7, sentAt.toUtc().millisecondsSinceEpoch ~/ 1000);
    b.setUint8(11, 0); // Protocol version 1.
    return b.buffer.asUint8List();
  }

  static RopeActionFrame? fromBytes(Uint8List bytes) {
    if (bytes.length != wireLength) return null;
    final b = ByteData.sublistView(bytes);
    final code = b.getUint8(5);
    if (b.getUint8(0) != magic ||
        code < 1 || code > RopeMessageType.stopGroup.index + 1 ||
        b.getUint8(3) >= 16 ||
        b.getUint8(6) > maxHops ||
        b.getUint8(11) != 0) {
      return null;
    }
    final type = RopeMessageType.values[code - 1];
    if (!isAction(type)) return null;
    return RopeActionFrame(
      sessionHash: b.getUint16(1),
      originIndex: b.getUint8(3),
      sequence: b.getUint8(4),
      type: type,
      hops: b.getUint8(6),
      sentAt: DateTime.fromMillisecondsSinceEpoch(
          b.getUint32(7) * 1000, isUtc: true),
    );
  }

  RopeActionFrame relayed() => RopeActionFrame(
        sessionHash: sessionHash,
        originIndex: originIndex,
        sequence: sequence,
        type: type,
        sentAt: sentAt,
        hops: hops + 1,
      );
}

/// Bounded, pure Dart store-and-forward queue for SOS/STOP/WAIT/OK.
/// Received events need validation against the current group roster.
class RopeActionRelay {
  RopeActionRelay({required this.sessionHash});

  final int sessionHash;
  final Map<String, RopeActionFrame> _seen = {};
  int _nextSequence = 0;

  RopeActionFrame create({
    required int originIndex,
    required RopeMessageType type,
    required DateTime now,
  }) {
    if (originIndex < 0 || originIndex > 15 ||
        !RopeActionFrame.isAction(type)) {
      throw ArgumentError('Invalid origin or group action');
    }
    final frame = RopeActionFrame(
      sessionHash: sessionHash,
      originIndex: originIndex,
      sequence: _nextSequence++ & 0xFF,
      type: type,
      sentAt: now,
    );
    if (!accept(frame, now: now)) {
      // Do not silently reuse an ID while it is still in the cache.
      throw StateError('Quick-message sequence exhausted: try later');
    }
    return frame;
  }

  bool accept(RopeActionFrame frame, {required DateTime now}) {
    if (frame.sessionHash != sessionHash ||
        frame.originIndex < 0 || frame.originIndex >= 16 ||
        frame.sequence < 0 || frame.sequence > 255 ||
        !RopeActionFrame.isAction(frame.type) ||
        frame.hops < 0 || frame.hops > RopeActionFrame.maxHops) {
      return false;
    }
    final age = now.toUtc().difference(frame.sentAt.toUtc());
    if (age > RopeActionFrame.maxAge ||
        age < const Duration(seconds: -30)) {
      return false;
    }
    prune(now);
    if (_seen.containsKey(frame.id)) return false;
    _seen[frame.id] = frame;
    return true;
  }

  void prune(DateTime now) {
    _seen.removeWhere((_, frame) =>
        now.toUtc().difference(frame.sentAt.toUtc()) >
            RopeActionFrame.maxAge);
  }

  /// Priority forwarding. The per-neighbour write response is hop-level
  /// confirmation, not an end-to-end delivery acknowledgement.
  List<RopeActionFrame> pending(DateTime now, {int limit = 4}) {
    prune(now);
    int priority(RopeMessageType type) => switch (type) {
      RopeMessageType.needHelp => 0,
      RopeMessageType.stopGroup => 1,
      RopeMessageType.waitForMe => 2,
      RopeMessageType.groupAlert => 3,
      RopeMessageType.imOk => 4,
      RopeMessageType.position => 5,
    };
    final values = _seen.values
        .where((a) => a.hops < RopeActionFrame.maxHops)
        .toList()
      ..sort((a, b) {
        final p = priority(a.type).compareTo(priority(b.type));
        return p == 0 ? b.sentAt.compareTo(a.sentAt) : p;
      });
    return values.take(limit).map((a) => a.relayed()).toList();
  }
}
