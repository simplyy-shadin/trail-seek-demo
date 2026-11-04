import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../app/backend.dart';
import '../../app/providers.dart';
import '../../data/models/adventure.dart';
import 'booking_models.dart';
import 'booking_repository.dart';

final bookingRepositoryProvider = Provider<BookingRepository>((ref) {
  if (Backend.isCloud) {
    final repo = SupabaseBookingRepository(client: Backend.client, currentUser: () => ref.read(authProvider), store: ref.read(localStoreProvider));
    ref.onDispose(repo.dispose);
    return repo;
  }
  return LocalBookingRepository(ref.read(localStoreProvider));
});

/// Draft carried from the booking form to the payment screen.
class BookingDraft {
  const BookingDraft({required this.adventure, required this.date, required this.slot, required this.party, required this.quote, this.vehicle, this.camera = false});
  final Adventure adventure;
  final DateTime date;
  final String slot;
  final Party party;
  final Quote quote;
  final String? vehicle;
  final bool camera;
}

class BookingController extends Notifier<List<Booking>> {
  BookingRepository get _repo => ref.read(bookingRepositoryProvider);

  @override
  List<Booking> build() {
    final sub = _repo.changes.listen((_) => _refresh());
    ref.onDispose(sub.cancel);
    ref.listen(authProvider, (_, _) => _refresh());
    return _mine();
  }

  List<Booking> _mine() {
    final uid = ref.read(authProvider)?.id;
    final list = _repo.all().where((b) => uid == null || b.userId == uid).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  void _refresh() => state = _mine();

  List<Booking> get upcoming => state.where((b) => b.isUpcoming).toList()..sort((a, b) => a.date.compareTo(b.date));
  List<Booking> get past => state.where((b) => !b.isUpcoming).toList();

  /// Seats already taken for a programme on a day and slot (from our bookings).
  int booked(String programId, DateTime day, String slot) => _repo.seatsTaken(programId, day, slot);

  /// Records a paid booking. Payment is simulated until the gateway is wired in.
  Future<Booking> confirm(BookingDraft d, {required String paymentMethod}) async {
    final user = ref.read(authProvider);
    if (user == null) throw StateError('Sign in to book');
    final id = const Uuid().v4();
    final b = Booking(
      id: id,
      code: _code(),
      userId: user.id,
      userName: user.displayName,
      programId: d.adventure.id,
      programName: d.adventure.name,
      destinationId: d.adventure.destinationId ?? '',
      destinationName: d.adventure.destinationName ?? d.adventure.district,
      coverImage: d.adventure.coverImage,
      date: DateTime(d.date.year, d.date.month, d.date.day),
      slot: d.slot,
      party: d.party,
      lines: d.quote.lines,
      total: d.quote.total,
      status: BookingStatus.confirmed,
      createdAt: DateTime.now(),
      paymentMethod: paymentMethod,
      paymentRef: 'TS${DateTime.now().millisecondsSinceEpoch.toRadixString(36).toUpperCase()}',
      vehicle: d.vehicle,
      camera: d.camera,
    );
    await _repo.save(b);
    _refresh();
    return b;
  }

  Future<void> cancel(String id) async {
    final b = state.where((x) => x.id == id).firstOrNull;
    if (b == null) return;
    await _repo.update(b.copyWith(status: BookingStatus.cancelled));
    _refresh();
  }

  Booking? byId(String id) => state.where((b) => b.id == id).firstOrNull;

  static String _code() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final r = Random.secure();
    return List.generate(6, (_) => chars[r.nextInt(chars.length)]).join();
  }
}

final bookingProvider = NotifierProvider<BookingController, List<Booking>>(BookingController.new);
