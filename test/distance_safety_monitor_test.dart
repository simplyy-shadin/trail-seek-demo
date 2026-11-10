import 'package:flutter_test/flutter_test.dart';
import 'package:trailseek/features/rope/engine/distance_safety_monitor.dart';
import 'package:trailseek/features/rope/engine/geo.dart';

void main() {
  final epoch = DateTime(2026, 11, 10, 10);
  const here = GeoPoint(10, 76);

  test('does not infer precise distance from a single GPS sample', () {
    final monitor = DistanceSafetyMonitor();
    final other = GeoPoint(10.0013, 76);
    final one = monitor.observe(memberId: 'b', self: here, selfAt: epoch,
        peer: other, peerAt: epoch, now: epoch, selfAccuracyMetres: 5);
    expect(one, isNull);
    final same = monitor.observe(memberId: 'b', self: here, selfAt: epoch,
        peer: other, peerAt: epoch, now: epoch.add(const Duration(seconds: 1)), selfAccuracyMetres: 5);
    expect(same, isNull);
    final later = epoch.add(const Duration(seconds: 2));
    final two = monitor.observe(memberId: 'b', self: here, selfAt: later,
        peer: other, peerAt: later, now: later, selfAccuracyMetres: 5);
    expect(two?.level, SpacingLevel.warning);
  });

  test('stale or inaccurate GPS cannot trigger warning', () {
    final monitor = DistanceSafetyMonitor(confirmSamples: 1);
    const far = GeoPoint(10.003, 76);
    expect(monitor.observe(memberId: 'b', self: here, selfAt: epoch,
      peer: far, peerAt: epoch.subtract(const Duration(seconds: 15)),
      now: epoch, selfAccuracyMetres: 5), isNull);
    expect(monitor.observe(memberId: 'b', self: here, selfAt: epoch,
      peer: far, peerAt: epoch, now: epoch, selfAccuracyMetres: 45), isNull);
  });

  test('urgent never means missing or auto SOS', () {
    final monitor = DistanceSafetyMonitor(confirmSamples: 1);
    final result = monitor.observe(memberId: 'b', self: here, selfAt: epoch,
      peer: const GeoPoint(10.003, 76), peerAt: epoch, now: epoch,
      selfAccuracyMetres: 5);
    expect(result?.level, SpacingLevel.urgent);
  });

  test('clear warning only after confirmed close readings', () {
    final monitor = DistanceSafetyMonitor();
    const far = GeoPoint(10.0015, 76);
    const near = GeoPoint(10.0001, 76);
    SpacingChange? observe(GeoPoint pos, int second) {
      final t = epoch.add(Duration(seconds: second));
      return monitor.observe(memberId: 'b', self: here, selfAt: t,
        peer: pos, peerAt: t, now: t, selfAccuracyMetres: 5);
    }
    expect(observe(far, 0), isNull);
    expect(observe(far, 2)?.level, SpacingLevel.warning);
    expect(observe(near, 4), isNull);
    expect(observe(near, 6)?.level, SpacingLevel.normal);
  });
}
