import 'dart:async';

/// Shares one native stream between callers while any listener needs it.
///
/// Unlike Stream.asBroadcastStream(), cancelling the final listener also
/// cancels the underlying subscription. A later listener starts a fresh
/// subscription, so a second trek can receive GPS fixes normally.
class RefCountedBroadcastStream<T> {
  RefCountedBroadcastStream(this._source) {
    _controller = StreamController<T>.broadcast(
      onListen: _connect,
      onCancel: _disconnect,
    );
  }

  final Stream<T> Function() _source;
  late final StreamController<T> _controller;
  StreamSubscription<T>? _upstream;
  Future<void>? _cancelling;
  bool _disposed = false;

  Stream<T> get stream => _controller.stream;

  void _connect() {
    if (_disposed || !_controller.hasListener ||
        _upstream != null || _cancelling != null) {
      return;
    }
    _upstream = _source().listen(
      (value) {
        if (!_disposed) _controller.add(value);
      },
      onError: (Object error, StackTrace stack) {
        if (!_disposed) _controller.addError(error, stack);
      },
      onDone: () {
        _upstream = null;
      },
    );
  }

  void _disconnect() {
    final subscription = _upstream;
    if (subscription == null) return;
    _upstream = null;
    final pending = subscription.cancel();
    _cancelling = pending;
    // Wait for native cancellation before opening another location request.
    unawaited(pending.then(
      (_) {
        if (identical(_cancelling, pending)) _cancelling = null;
        _connect();
      },
      onError: (Object error, StackTrace stack) {
        if (identical(_cancelling, pending)) _cancelling = null;
        // A future session can retry; do not leak an unhandled async error.
        _connect();
      },
    ));
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _disconnect();
    await _cancelling;
    await _controller.close();
  }
}
