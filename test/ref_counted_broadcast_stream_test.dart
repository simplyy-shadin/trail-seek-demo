import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:trailseek/features/tracking/ref_counted_broadcast_stream.dart';

void main() {
  test('shares one upstream, cancels after final listener, can restart', () async {
    var starts = 0;
    var stops = 0;
    final upstreams = <StreamController<int>>[];
    final shared = RefCountedBroadcastStream<int>(() {
      starts++;
      final controller = StreamController<int>(onCancel: () { stops++; });
      upstreams.add(controller);
      return controller.stream;
    });
    final receivedA = <int>[];
    final receivedB = <int>[];
    final a = shared.listen(receivedA.add);
    final b = shared.listen(receivedB.add);
    await Future<void>.delayed(Duration.zero);
    expect(starts, 1);
    upstreams.last.add(7);
    await Future<void>.delayed(Duration.zero);
    expect(receivedA, [7]);
    expect(receivedB, [7]);
    await a.cancel();
    await Future<void>.delayed(Duration.zero);
    expect(stops, 0);
    await b.cancel();
    await Future<void>.delayed(Duration.zero);
    expect(stops, 1);
    final c = shared.listen(receivedA.add);
    await Future<void>.delayed(Duration.zero);
    expect(starts, 2);
    upstreams.last.add(8);
    await Future<void>.delayed(Duration.zero);
    expect(receivedA, [7, 8]);
    await c.cancel();
    await shared.dispose();
  });
}
