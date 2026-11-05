import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:trailseek/features/tracking/ref_counted_broadcast_stream.dart';

void main() {
  test('GPS starts lazily and is shared by all active listeners', () async {
    final sources = <StreamController<int>>[];
    var cancelled = 0;
    final shared = RefCountedBroadcastStream<int>(() {
      final source = StreamController<int>(onCancel: () { cancelled++; });
      sources.add(source);
      return source.stream;
    });

    expect(sources, isEmpty);
    final first = <int>[];
    final second = <int>[];
    final a = shared.stream.listen(first.add);
    final b = shared.stream.listen(second.add);
    expect(sources.length, 1);

    sources.single.add(7);
    await Future<void>.delayed(Duration.zero);
    expect(first, [7]);
    expect(second, [7]);

    await a.cancel();
    expect(cancelled, 0, reason: 'Other active sessions still need GPS');
    await b.cancel();
    await Future<void>.delayed(Duration.zero);
    expect(cancelled, 1, reason: 'Ending the last session must stop native GPS');
    await shared.dispose();
  });

  test('a new trek opens a fresh GPS stream after the previous one ends', () async {
    final sources = <StreamController<int>>[];
    var cancelled = 0;
    final shared = RefCountedBroadcastStream<int>(() {
      final source = StreamController<int>(onCancel: () { cancelled++; });
      sources.add(source);
      return source.stream;
    });

    final first = shared.stream.listen((_) {});
    await first.cancel();
    await Future<void>.delayed(Duration.zero);
    expect(cancelled, 1);

    final values = <int>[];
    final second = shared.stream.listen(values.add);
    expect(sources.length, 2);
    sources.last.add(42);
    await Future<void>.delayed(Duration.zero);
    expect(values, [42]);

    await second.cancel();
    await shared.dispose();
    expect(cancelled, 2);
  });

  test('disposing the owner releases the upstream stream', () async {
    var cancelled = 0;
    final shared = RefCountedBroadcastStream<int>(
      () => StreamController<int>(onCancel: () { cancelled++; }).stream,
    );
    final subscription = shared.stream.listen((_) {});
    await shared.dispose();
    expect(cancelled, 1);
    await subscription.cancel();
  });
}
