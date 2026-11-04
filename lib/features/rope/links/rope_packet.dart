import 'dart:convert';
import 'dart:typed_data';

import 'rope_safety_relay.dart';

/// The 8-byte heartbeat that rides inside every BLE advertisement.
///
/// Layout: sessionHash(2) memberIndex(1) seq(1) flags(1) gossip(2) extra(1).
/// extra bit 0 = "start together" countdown running (organizer only),
/// bit 1 = member asks the organizer to start, bit 2 = organizer ends the trek for everyone.
/// It is encoded as an 11-character base64url string and sent as the
/// advertisement's local name, because that is the one payload field both
/// Android and iOS can advertise *and* read in the foreground. Service data
/// and manufacturer data are invisible to iOS centrals.
class RopePacket {
  const RopePacket({
    required this.sessionHash,
    required this.memberIndex,
    required this.seq,
    required this.flags,
    required this.gossip,
    this.starting = false,
    this.requestStart = false,
    this.ending = false,
    this.safetySubjectIndex,
    this.safetySignal,
  });

  final int sessionHash;
  final int memberIndex;
  final int seq;
  final int flags;

  /// Bit n set = "I heard member n directly within the last 10 s".
  final int gossip;

  /// The organizer has a "start together" countdown running.
  final bool starting;

  /// A member asks the organizer to start the group.
  final bool requestStart;

  /// The organizer is ending the trek for everyone.
  final bool ending;

  /// Optional fast one-hop safety warning in otherwise unused packet bits.
  /// Full event identity and multi-hop forwarding use the GATT relay.
  final int? safetySubjectIndex;
  final SafetySignal? safetySignal;

  static const flagImOk = 0x01;
  static const flagWaitForMe = 0x02;
  static const flagNeedHelp = 0x04;
  static const flagGroupAlert = 0x08;
  static const flagStopGroup = 0x10;

  Uint8List toBytes() {
    final b = ByteData(8);
    b.setUint16(0, sessionHash & 0xFFFF);
    b.setUint8(2, memberIndex & 0xFF);
    b.setUint8(3, seq & 0xFF);
    final code = safetySignal == null ? 0 : safetySignal!.index + 1;
    b.setUint8(4, (flags & 0x1F) | (code << 5));
    b.setUint16(5, gossip & 0xFFFF);
    b.setUint8(7, (starting ? 1 : 0) | (requestStart ? 2 : 0) | (ending ? 4 : 0) |
        (code == 0 ? 0 : ((safetySubjectIndex ?? 0) & 0x0F) << 3));
    return b.buffer.asUint8List();
  }

  String encode() => base64Url.encode(toBytes()).replaceAll('=', '');

  static RopePacket? decode(String? name) {
    if (name == null || name.length != 11) return null;
    try {
      final bytes = base64Url.decode('$name=');
      if (bytes.length != 8) return null;
      final b = ByteData.sublistView(bytes);
      final code = b.getUint8(4) >> 5;
      if (code > SafetySignal.values.length) return null;
      return RopePacket(
        sessionHash: b.getUint16(0),
        memberIndex: b.getUint8(2),
        seq: b.getUint8(3),
        flags: b.getUint8(4) & 0x1F,
        gossip: b.getUint16(5),
        starting: b.getUint8(7) & 1 == 1,
        requestStart: b.getUint8(7) & 2 == 2,
        ending: b.getUint8(7) & 4 == 4,
        safetySubjectIndex: code == 0 ? null : ((b.getUint8(7) >> 3) & 0x0F),
        safetySignal: code == 0 ? null : SafetySignal.values[code - 1],
      );
    } on FormatException {
      return null;
    }
  }

  bool hears(int memberIndex) => (gossip >> memberIndex) & 1 == 1;

  /// FNV-1a folded to 16 bits. Collisions between two groups on the same
  /// trail are possible but harmless: member indices will not line up and
  /// the join code is still checked on the GATT path.
  static int hashCode16(String code) {
    var h = 0x811C9DC5;
    for (final c in code.codeUnits) {
      h ^= c;
      h = (h * 0x01000193) & 0xFFFFFFFF;
    }
    return (h ^ (h >> 16)) & 0xFFFF;
  }
}
