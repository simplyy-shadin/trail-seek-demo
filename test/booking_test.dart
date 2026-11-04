import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:trailseek/data/models/adventure.dart';
import 'package:trailseek/features/booking/booking_models.dart';

void main() {
  final json = jsonDecode(File('assets/data/thrissur.json').readAsStringSync()) as Map<String, dynamic>;
  final all = (json['programs'] as List).cast<Map<String, dynamic>>().map(Adventure.fromJson).toList();
  Adventure by(String id) => all.firstWhere((a) => a.id == id);

  test('package ticket covers the group and charges extras per head', () {
    final amphi = by('chimmony-amphi-trekking'); // ₹5,400 up to 6, +₹900
    expect(Quote.compute(amphi, const Party(adults: 4)).total, 5400);
    final q = Quote.compute(amphi, const Party(adults: 8));
    expect(q.total, 5400 + 2 * 900);
    expect(q.lines.length, 2);
  });

  test('per-person treks apply the foreign rate and the minimum booking', () {
    final trek = by('athirappilly-trekking'); // ₹1,500 / ₹3,000, minimum ₹6,000
    expect(Quote.compute(trek, const Party(adults: 2)).total, 6000);
    expect(Quote.compute(trek, const Party(adults: 4)).total, 6000);
    expect(Quote.compute(trek, const Party(adults: 4, foreigners: 1)).total, 9000);
  });

  test('sanctuary entry is added per person on top of a coracle ticket', () {
    final ride = by('peechi-coracle-20'); // ₹500 per coracle + entry ₹40 Indian / ₹35 student / ₹60 foreign
    final q = Quote.compute(ride, const Party(adults: 2, students: 1, foreigners: 1), vehicle: 'Light Motor Vehicle', camera: true);
    expect(q.total, 500 + 2 * 40 + 35 + 60 + 55 + 30);
  });

  test('falls entry is priced per category', () {
    final falls = by('athirappilly-vazhachal-falls');
    final q = Quote.compute(falls, const Party(adults: 2, children: 1, students: 1, foreigners: 1), vehicle: 'Four Wheeler');
    expect(q.total, 2 * 60 + 15 + 20 + 250 + 40);
  });

  test('slots follow the programme timing', () {
    expect(slotsFor(by('chimmony-amphi-trekking')), ['07:00 AM']);
    final coracle = slotsFor(by('peechi-coracle-20'));
    expect(coracle.first, '08:00 AM');
    expect(coracle.last, '04:00 PM');
    expect(slotsFor(by('peechi-dam-valley')), ['08:00 AM', '09:00 AM', '10:00 AM', '11:00 AM', '12:00 PM', '01:00 PM']);
    expect(slotsFor(by('chimmony-anaporu-camp')), ['Check-in 2:00 PM']);
  });

  test('a booking round-trips through json', () {
    final b = Booking(
      id: 'x', code: 'ABC234', userId: 'u', userName: 'Shad', programId: 'peechi-nasika', programName: 'Nasika', destinationId: 'peechi-vazhani',
      destinationName: 'Peechi', coverImage: null, date: DateTime(2026, 11, 2), slot: '08:00 AM', party: const Party(adults: 2),
      lines: const [BookingLine('Ticket', 1200)], total: 1200, status: BookingStatus.confirmed, createdAt: DateTime(2026, 10, 28, 9),
      paymentMethod: 'UPI', paymentRef: 'TS1',
    );
    final back = Booking.fromJson(jsonDecode(jsonEncode(b.toJson())) as Map<String, dynamic>);
    expect(back.code, 'ABC234');
    expect(back.party.adults, 2);
    expect(back.lines.single.amount, 1200);
    expect(back.isUpcoming, isTrue);
  });
}
