import '../../../data/models/group_session.dart';
import '../engine/rope_models.dart';

/// Transport abstraction between the rope engine and the radio.
///
/// [SimulatedPeerLink] drives development, emulators and tests.
/// [BlePeerLink] is the real cross-platform Bluetooth implementation.
abstract class PeerLink {
  Stream<PeerObservation> get observations;
  Stream<RopeMessage> get messages;
  bool get isSimulated;

  Future<void> start({required GroupSession session, required Member self});
  Future<void> stop();
  Future<void> send(RopeMessage message);
}
