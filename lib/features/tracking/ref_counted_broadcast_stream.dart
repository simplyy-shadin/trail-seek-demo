import 'dart:async';

/// A restartable broadcast stream that owns exactly one underlying source.
///
/// Unlike `asBroadcastStream()` with its default onCancel behavior, the source
/// is cancelled once the last listener leaves. When a new listener arrives,
/// a *new* native source stream is opened. Shutdown/startup are serialized.
class RefCountedBroadcastStream<T> extends Stream<T> {
  RefCountedBroadcastStream(this._openSource) {
    _controller = StreamController<T>.broadcast(
      onListen: _queueStart,
      onCancel: _queueStop,
    );
  }

  final Stream<T> Function() _openSource;
  late final StreamController<T> _controller;
  StreamSubscription<T>? _source;
  Future<void> _transition = Future<void>.value();
  bool _disposed = false;

  void _queueStart() {
    _transition = _transition.then((_) {
      if (_disposed || !_controller.hasListener || _source != null) return;
      _source = _openSource().listen(
        (value) { if (!_disposed) _controller.add(value); },
        onError: (Object error, StackTrace stack) {
          if (!_disposed) _controller.addError(error, stack);
        },
        onDone: () { _source = null; },
      );
    });
  }

  void _queueStop() {
    _transition = _transition.then((_) async {
      if (_controller.hasListener) return;
      final current = _source;
      _source = null;
      await current?.cancel();
    });
  }

  @override
  StreamSubscription<T> listen(
    void Function(T)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => _controller.stream.listen(
    onData, onError: onError, onDone: onDone, cancelOnError: cancelOnError,
  );

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _transition;
    await _source?.cancel();
    _source = null;
    await _controller.close();
  }
}
