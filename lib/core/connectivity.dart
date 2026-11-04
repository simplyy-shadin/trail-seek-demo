import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// True when a DNS lookup succeeds; checked every 20 s and on demand.
/// Deliberately simple: no extra plugin, works on every platform.
class OnlineController extends Notifier<bool> {
  Timer? _timer;

  @override
  bool build() {
    _timer = Timer.periodic(const Duration(seconds: 20), (_) => refresh());
    ref.onDispose(() => _timer?.cancel());
    refresh();
    return true;
  }

  Future<void> refresh() async {
    try {
      final r = await InternetAddress.lookup('tile.openstreetmap.org').timeout(const Duration(seconds: 4));
      state = r.isNotEmpty && r.first.rawAddress.isNotEmpty;
    } catch (_) {
      state = false;
    }
  }
}

final onlineProvider = NotifierProvider<OnlineController, bool>(OnlineController.new);
