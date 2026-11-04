import 'dart:typed_data';

/// Safety warning levels exchanged between authenticated group members.
/// These are connectivity warnings, not proof that someone needs rescue.
enum SafetySignal { weak, fallingBehind, separated, critical, recovered }

/// Twelve-byte, versioned BLE GATT message; fits the minimum 20-byte write.
/// Reporter + sequence identifies an event across every forwarding hop.
class SafetyAlert {
  const SafetyAlert({
    required this.sessionHash,
    required this.reporterIndex,
    required this.subjectIndex,
    required this.sequence,
    required this.signal,
    required this.createdAt,
    this.hops = 0,
  });

  static const magic = 0xA7;
  static const wireLength = 12;
  static const maxHops = 12;

  final int sessionHash;
  final int reporterIndex;
  final int subjectIndex;
  final int sequence;
  final SafetySignal signal;
  final DateTime createdAt;
  final int hops;

  String get id => '$sessionHash:$reporterIndex:$sequence';

  Uint8List toBytes() {
    final b = ByteData(wireLength);
    b.setUint8(0, magic);
    b.setUint16(1, sessionHash & 0xFFFF);
    b.setUint8(3, reporterIndex);
    b.setUint8(4, subjectIndex);
    b.setUint8(5, sequence);
    b.setUint8(6, signal.index + 1);
    b.setUint32(7, createdAt.toUtc().millisecondsSinceEpoch ~/ 1000);
    b.setUint8(11, hops);
    return b.buffer.asUint8List();
  }

  static SafetyAlert? fromBytes(Uint8List bytes) {
    if (bytes.length != wireLength) return null;
    final b = ByteData.sublistView(bytes);
    final code = b.getUint8(6);
    if (b.getUint8(0) != magic || code < 1 || code > SafetySignal.values.length ||
        b.getUint8(3) > 15 || b.getUint8(4) > 15 || b.getUint8(11) > maxHops) {
      return null;
    }
    return SafetyAlert(
      sessionHash: b.getUint16(1),
      reporterIndex: b.getUint8(3),
      subjectIndex: b.getUint8(4),
      sequence: b.getUint8(5),
      signal: SafetySignal.values[code - 1],
      createdAt: DateTime.fromMillisecondsSinceEpoch(b.getUint32(7) * 1000, isUtc: true),
      hops: b.getUint8(11),
    );
  }

  SafetyAlert forwarded() => SafetyAlert(
        sessionHash: sessionHash,
        reporterIndex: reporterIndex,
        subjectIndex: subjectIndex,
        sequence: sequence,
        signal: signal,
        createdAt: createdAt,
        hops: hops + 1,
      );
}

/// Store-and-forward across BLE neighbours; no server or organizer required.
/// Expiry, deduplication and bounded forwarding prevent message storms.
class SafetyAlertRelay {
  SafetyAlertRelay({required this.sessionHash});
  final int sessionHash;
  static const lifetime = Duration(minutes: 3);
  static const futureTolerance = Duration(seconds: 30);
  final Map<String, SafetyAlert> _seen = {};
  int _sequence = 0;
  SafetyAlert? _latestLocal;

  SafetyAlert create({
    required int reporterIndex,
    required int subjectIndex,
    required SafetySignal signal,
    required DateTime now,
  }) {
    final alert = SafetyAlert(
      sessionHash: sessionHash,
      reporterIndex: reporterIndex,
      subjectIndex: subjectIndex,
      sequence: _sequence++ & 0xFF,
      signal: signal,
      createdAt: now,
    );
    if (!accept(alert, now: now)) throw StateError('Invalid local BLE alert');
    _latestLocal = alert;
    return alert;
  }

  bool accept(SafetyAlert alert, {required DateTime now}) {
    if (alert.sessionHash != sessionHash ||
        alert.reporterIndex > 15 || alert.subjectIndex > 15 ||
        alert.reporterIndex < 0 || alert.subjectIndex < 0 ||
        alert.hops > SafetyAlert.maxHops) return false;
    final age = now.toUtc().difference(alert.createdAt.toUtc());
    if (age > lifetime || age < -futureTolerance) return false;
    prune(now);
    if (_seen.containsKey(alert.id)) return false;
    _seen[alert.id] = alert;
    return true;
  }

  void prune(DateTime now) {
    _seen.removeWhere((_, a) => now.toUtc().difference(a.createdAt.toUtc()) > lifetime);
  }

  /// Most recent distinct warnings first. One 12-byte GATT write per warning.
  List<SafetyAlert> outgoing(DateTime now, {int limit = 5}) {
    prune(now);
    return (_seen.values.where((a) => a.hops < SafetyAlert.maxHops).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt)))
        .take(limit)
        .map((a) => a.forwarded())
        .toList();
  }

  /// Only locally originated warnings appear in our fast advertising beacon.
  SafetyAlert? localBeacon(DateTime now) {
    final a = _latestLocal;
    if (a == null || now.toUtc().difference(a.createdAt.toUtc()) > const Duration(seconds: 20)) return null;
    return a;
  }
}
