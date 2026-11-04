import 'dart:async';
import 'dart:math' as math;

import '../../../data/models/group_session.dart';
import '../engine/geo.dart';
import '../engine/rope_config.dart';
import '../engine/rope_models.dart';
import 'peer_link.dart';

/// How a simulated member behaves on the radio.
enum SimBehaviour {
  /// Strong, steady heartbeat; keeps pace with the group.
  connected,

  /// Heard, but weak and noisy signal.
  weakSignal,

  /// Only a neighbour can hear this member (chain relay).
  viaChain,

  /// Signal fades over ~20 heartbeats, then goes silent. Member stops moving.
  drifting,

  /// Went silent immediately (stopped to tie a shoelace, phone in bag).
  silent,
}

/// Generates heartbeats, RSSI and positions for the other members of a
/// group so the whole Digital Rope UI works on an emulator with no
/// Bluetooth at all.
class SimulatedPeerLink implements PeerLink {
  SimulatedPeerLink({
    required this.route,
    this.config = const RopeConfig(),
    math.Random? random,
    this.walkingSpeedMps = 1.1,
  }) : _random = random ?? math.Random();

  final Route route;
  final RopeConfig config;
  final math.Random _random;
  final double walkingSpeedMps;

  final _obs = StreamController<PeerObservation>.broadcast();
  final _msg = StreamController<RopeMessage>.broadcast();
  final Map<String, SimBehaviour> _behaviour = {};
  final Map<String, double> _progress = {};
  final Map<String, int> _driftStep = {};
  Timer? _timer;
  Member? _self;
  double selfProgress = 0;

  @override
  Stream<PeerObservation> get observations => _obs.stream;
  @override
  Stream<RopeMessage> get messages => _msg.stream;
  @override
  bool get isSimulated => true;

  Map<String, SimBehaviour> get behaviours => Map.unmodifiable(_behaviour);
  Map<String, double> get progress => Map.unmodifiable(_progress);

  GeoPoint positionOf(String memberId) => route.at(_progress[memberId] ?? 0);
  GeoPoint get selfPosition => route.at(selfProgress);

  @override
  Future<void> start({required GroupSession session, required Member self}) async {
    _self = self;
    for (final m in session.members) {
      if (m.id == self.id) continue;
      _behaviour[m.id] = SimBehaviour.connected;
      _progress[m.id] = 0.0 - _random.nextDouble() * 0.004;
    }
    _timer?.cancel();
    _timer = Timer.periodic(config.heartbeatInterval, (_) => _beat());
  }

  @override
  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
  }

  @override
  Future<void> send(RopeMessage message) async {
    // Local echo so the UI log shows what we sent; peers are imaginary.
    _msg.add(message);
  }

  void setBehaviour(String memberId, SimBehaviour behaviour) {
    _behaviour[memberId] = behaviour;
    _driftStep[memberId] = 0;
  }

  /// The product plan's shoelace scenario: one member stops, the group
  /// walks on, then the member catches up after [stoppedFor].
  void runShoelaceScenario(String memberId, {Duration stoppedFor = const Duration(seconds: 50)}) {
    setBehaviour(memberId, SimBehaviour.silent);
    Timer(stoppedFor, () {
      if (_behaviour[memberId] == SimBehaviour.silent) {
        setBehaviour(memberId, SimBehaviour.connected);
      }
    });
  }

  void _beat() {
    final self = _self;
    if (self == null) return;
    final now = DateTime.now();
    final step = walkingSpeedMps * config.heartbeatInterval.inMilliseconds / 1000 / math.max(route.lengthMetres, 1);
    selfProgress = math.min(1, selfProgress + step * (0.95 + _random.nextDouble() * 0.1));

    _behaviour.forEach((id, b) {
      final moving = b == SimBehaviour.connected || b == SimBehaviour.weakSignal || b == SimBehaviour.viaChain;
      if (moving) {
        _progress[id] = math.min(1, (_progress[id] ?? 0) + step * (0.9 + _random.nextDouble() * 0.2));
      }
      final pos = route.at(_progress[id] ?? 0);
      switch (b) {
        case SimBehaviour.connected:
          _obs.add(PeerObservation(memberId: id, at: now, rssi: -58 + _noise(6), position: pos));
        case SimBehaviour.weakSignal:
          _obs.add(PeerObservation(memberId: id, at: now, rssi: -84 + _noise(5), position: pos));
        case SimBehaviour.viaChain:
          _obs.add(PeerObservation(memberId: id, at: now, viaChain: true, hops: 1, position: pos));
        case SimBehaviour.drifting:
          final n = _driftStep[id] = (_driftStep[id] ?? 0) + 1;
          final rssi = -60 - n * 2 + _noise(3);
          if (rssi > -96) {
            _obs.add(PeerObservation(memberId: id, at: now, rssi: rssi, position: pos));
          }
        case SimBehaviour.silent:
          break;
      }
    });
  }

  int _noise(int amplitude) => _random.nextInt(amplitude * 2 + 1) - amplitude;

  void dispose() {
    _timer?.cancel();
    _obs.close();
    _msg.close();
  }
}
