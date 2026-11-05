import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Platform-protected persistence for BLE group invitation credentials.
/// Sessions in SharedPreferences carry *no key material*.
///
/// Call [initialize] before building any GroupSession from local JSON.
abstract final class GroupSecretVault {
  static const _prefix = 'trailseek.group-key.';
  static const _storage = FlutterSecureStorage();
  static final Map<String, String> _cache = {};
  static bool _loaded = false;

  static Future<void> initialize() async {
    if (_loaded) return;
    final values = await _storage.readAll();
    _cache.clear();
    for (final e in values.entries) {
      if (e.key.startsWith(_prefix)) {
        _cache[e.key.substring(_prefix.length)] = e.value;
      }
    }
    _loaded = true;
  }

  static String? get(String id) => _cache[id];

  static Future<void> save(String id, String keyHex) async {
    if (!RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(keyHex)) {
      throw ArgumentError('Invalid group credential');
    }
    await _storage.write(key: '$_prefix$id', value: keyHex.toLowerCase());
    _cache[id] = keyHex.toLowerCase();
  }

  static Future<void> remove(String id) async {
    await _storage.delete(key: '$_prefix$id');
    _cache.remove(id);
  }

  /// Delete every Trailseek group credential when the account/data is wiped.
  /// Fail instead of silently leaving credentials behind.
  static Future<void> clearAll() async {
    final stored = await _storage.readAll();
    for (final key in stored.keys.where((k) => k.startsWith(_prefix))) {
      await _storage.delete(key: key);
    }
    _cache.clear();
    _loaded = true;
  }
}
