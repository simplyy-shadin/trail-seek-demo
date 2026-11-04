import 'dart:async';
import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/models/app_user.dart';
import '../../data/repositories/local_store.dart';
import 'booking_models.dart';

/// Bookings live in Trail Seek's own database. Local mode keeps them on the
/// phone; cloud mode keeps them in Firestore under `bookings/{id}` so the
/// operator dashboard and the phone see the same record (Supabase `bookings`).
abstract class BookingRepository {
  Stream<void> get changes;
  List<Booking> all();

  /// Seats already taken on a slot, across all visitors where the backend knows them.
  int seatsTaken(String programId, DateTime day, String slot);
  Future<void> save(Booking b);
  Future<void> update(Booking b);
}

class LocalBookingRepository implements BookingRepository {
  LocalBookingRepository(this._store);
  final LocalStore _store;
  static const _key = 'bookings_v1';
  List<Booking>? _cache;

  @override
  Stream<void> get changes => const Stream.empty();

  @override
  List<Booking> all() {
    if (_cache != null) return _cache!;
    final raw = _store.rawString(_key);
    _cache = raw == null ? [] : (jsonDecode(raw) as List).map((e) => Booking.fromJson((e as Map).cast<String, dynamic>())).toList();
    return _cache!;
  }

  Future<void> _persist() => _store.setRaw(_key, jsonEncode(all().map((b) => b.toJson()).toList()));

  @override
  Future<void> save(Booking b) async {
    all().removeWhere((x) => x.id == b.id);
    all().add(b);
    await _persist();
  }

  @override
  Future<void> update(Booking b) => save(b);

  @override
  int seatsTaken(String programId, DateTime day, String slot) => all()
      .where((b) => b.programId == programId && b.status == BookingStatus.confirmed && b.slot == slot && b.date.year == day.year && b.date.month == day.month && b.date.day == day.day)
      .fold(0, (s, b) => s + b.party.total);
}

class SupabaseBookingRepository implements BookingRepository {
  SupabaseBookingRepository({required SupabaseClient client, required AppUser? Function() currentUser, required LocalStore store})
      : _c = client,
        _me = currentUser,
        _local = LocalBookingRepository(store);

  final SupabaseClient _c;
  final AppUser? Function() _me;
  final LocalBookingRepository _local;
  final _changes = StreamController<void>.broadcast();
  String? _uid;
  List<Booking> _remote = [];

  /// Seats taken per "program|date|slot", across every user, from the server.
  final Map<String, int> _seats = {};

  @override
  Stream<void> get changes => _changes.stream;

  void _ping() {
    if (!_changes.isClosed) _changes.add(null);
  }

  void _ensure() {
    final uid = _me()?.id;
    if (uid == _uid) return;
    _uid = uid;
    _remote = [];
    if (uid != null) unawaited(_pull());
  }

  Future<void> _pull() async {
    try {
      final rows = await _c.from('bookings').select().eq('user_id', _uid!).order('created_at', ascending: false);
      _remote = [for (final r in rows) _fromRow(r)];
      _ping();
    } catch (_) {}
  }

  static Booking _fromRow(Map<String, dynamic> r) => Booking.fromJson({
        'id': r['id'], 'code': r['code'], 'userId': r['user_id'], 'userName': r['user_name'], 'programId': r['program_id'],
        'programName': r['program_name'], 'destinationId': r['destination_id'], 'destinationName': r['destination_name'],
        'coverImage': r['cover_image'], 'date': r['visit_date'], 'slot': r['slot'], 'party': r['party'], 'lines': r['lines'],
        'total': r['total'], 'status': r['status'], 'createdAt': r['created_at'], 'paymentMethod': r['payment_method'],
        'paymentRef': r['payment_ref'], 'vehicle': r['vehicle'], 'camera': r['camera'], 'operatorSynced': r['operator_synced'],
      });

  @override
  List<Booking> all() {
    _ensure();
    final ids = {for (final b in _remote) b.id};
    return [..._remote, ..._local.all().where((b) => !ids.contains(b.id) && b.userId == _uid)];
  }

  @override
  int seatsTaken(String programId, DateTime day, String slot) {
    final key = '$programId|${_d(day)}|$slot';
    if (!_seats.containsKey(key)) {
      _seats[key] = 0;
      unawaited(() async {
        try {
          final n = await _c.rpc('booked_seats', params: {'p_program_id': programId, 'p_date': _d(day), 'p_slot': slot});
          _seats[key] = (n as num).toInt();
          _ping();
        } catch (_) {}
      }());
    }
    return _seats[key]!;
  }

  static String _d(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Future<void> save(Booking b) async {
    await _local.save(b);
    await _c.from('bookings').upsert({
      'id': b.id, 'code': b.code, 'user_id': b.userId, 'user_name': b.userName, 'program_id': b.programId, 'program_name': b.programName,
      'destination_id': b.destinationId, 'destination_name': b.destinationName, 'cover_image': b.coverImage, 'visit_date': _d(b.date),
      'slot': b.slot, 'party': b.party.toJson(), 'lines': b.lines.map((l) => l.toJson()).toList(), 'total': b.total, 'status': b.status.name,
      'payment_method': b.paymentMethod, 'payment_ref': b.paymentRef, 'vehicle': b.vehicle, 'camera': b.camera, 'operator_synced': b.operatorSynced,
      'created_at': b.createdAt.toUtc().toIso8601String(),
    });
    _remote = [b, ..._remote.where((x) => x.id != b.id)];
    _seats.removeWhere((k, _) => k.startsWith('${b.programId}|${_d(b.date)}|'));
    _ping();
  }

  @override
  Future<void> update(Booking b) => save(b);

  void dispose() => _changes.close();
}
