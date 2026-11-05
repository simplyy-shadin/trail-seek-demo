import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as digest;
import 'package:cryptography/cryptography.dart';

/// Shared group credentials distributed only in the organizer's private
/// invitation QR/link. The six-character discovery code is NOT a secret.
/// This is group-level possession authentication, not per-member identity.
class RopeSecurity {
  RopeSecurity(String keyHex)
      : _keyBytes = decodeKey(keyHex),
        _aes = AesGcm.with256bits();

  static const rosterMagic = 0xB5;
  static const messageMagic = 0xB6;
  static const tagBytes = 16;
  static const nonceBytes = 12;
  static const encryptedRosterOverhead = 1 + nonceBytes + tagBytes;
  static const maxRosterPlaintextBytes = 512 - encryptedRosterOverhead;

  final List<int> _keyBytes;
  final AesGcm _aes;

  static String generateKey() {
    final random = Random.secure();
    return List<int>.generate(32, (_) => random.nextInt(256))
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
  }

  static bool validKey(String? key) {
    if (key == null || !RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(key)) return false;
    return true;
  }

  static List<int> decodeKey(String key) {
    if (!validKey(key)) throw ArgumentError('Invalid 256-bit group credential');
    return [for (var i = 0; i < key.length; i += 2) int.parse(key.substring(i, i + 2), radix: 16)];
  }

  // Domain-separated MAC. Group participants can authenticate a message as
  // belonging to their group; it does not prove which member sent it.
  List<int> _mac(Uint8List data) {
    final h = digest.Hmac(digest.sha256, _keyBytes);
    return h.convert([...utf8.encode('trailseek-ble-message-v2'), ...data]).bytes.take(tagBytes).toList();
  }

  Uint8List signMessage(Uint8List raw) {
    final data = Uint8List.fromList([messageMagic, ...raw]);
    return Uint8List.fromList([...data, ..._mac(data)]);
  }

  /// Unauthenticated messages are rejected, never passed to action handlers.
  Uint8List? verifyMessage(Uint8List wire) {
    if (wire.length < 2 + tagBytes || wire.first != messageMagic) return null;
    final data = Uint8List.sublistView(wire, 0, wire.length - tagBytes);
    final expected = _mac(data);
    var diff = 0;
    for (var i = 0; i < tagBytes; i++) {
      diff |= expected[i] ^ wire[wire.length - tagBytes + i];
    }
    if (diff != 0) return null;
    return Uint8List.fromList(wire.sublist(1, wire.length - tagBytes));
  }

  /// AES-256-GCM with random nonce: an arbitrary BLE reader gets ciphertext,
  /// not names, locations, or the group's code.
  Future<Uint8List> encryptRoster(Uint8List plaintext) async {
    if (plaintext.length > maxRosterPlaintextBytes) {
      throw ArgumentError('Roster exceeds encrypted GATT attribute budget');
    }
    final nonce = _aes.newNonce();
    final box = await _aes.encrypt(
      plaintext,
      secretKey: SecretKey(_keyBytes),
      nonce: nonce,
      aad: utf8.encode('trailseek-ble-roster-v2'),
    );
    return Uint8List.fromList([rosterMagic, ...box.nonce, ...box.cipherText, ...box.mac.bytes]);
  }

  /// Returns null for corrupt, unknown-version, or unauthenticated rosters.
  Future<Uint8List?> decryptRoster(Uint8List data) async {
    if (data.length < encryptedRosterOverhead || data.length > 512 ||
        data.first != rosterMagic) return null;
    try {
      final box = SecretBox(
        data.sublist(1 + nonceBytes, data.length - tagBytes),
        nonce: data.sublist(1, 1 + nonceBytes),
        mac: Mac(data.sublist(data.length - tagBytes)),
      );
      final plain = await _aes.decrypt(
        box, secretKey: SecretKey(_keyBytes),
        aad: utf8.encode('trailseek-ble-roster-v2'),
      );
      return Uint8List.fromList(plain);
    } on SecretBoxAuthenticationError {
      return null;
    } catch (_) {
      return null;
    }
  }
}
