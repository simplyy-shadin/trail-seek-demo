import '../../data/models/adventure.dart';

enum BookingStatus { confirmed, cancelled, completed }

/// One price line on the quote and the ticket.
class BookingLine {
  const BookingLine(this.label, this.amount);
  factory BookingLine.fromJson(Map<String, dynamic> j) => BookingLine(j['label'] as String, (j['amount'] as num).toInt());
  final String label;
  final int amount;
  Map<String, dynamic> toJson() => {'label': label, 'amount': amount};
}

/// Who is coming. Children and students pay reduced entry where the
/// programme has such a rate; foreigners pay the foreign rate.
class Party {
  const Party({this.adults = 1, this.children = 0, this.students = 0, this.foreigners = 0});
  factory Party.fromJson(Map<String, dynamic> j) => Party(
        adults: (j['adults'] as num?)?.toInt() ?? 1,
        children: (j['children'] as num?)?.toInt() ?? 0,
        students: (j['students'] as num?)?.toInt() ?? 0,
        foreigners: (j['foreigners'] as num?)?.toInt() ?? 0,
      );
  final int adults;
  final int children;
  final int students;
  final int foreigners;
  int get total => adults + children + students + foreigners;
  int get indians => adults + children + students;
  Party copyWith({int? adults, int? children, int? students, int? foreigners}) =>
      Party(adults: adults ?? this.adults, children: children ?? this.children, students: students ?? this.students, foreigners: foreigners ?? this.foreigners);
  Map<String, dynamic> toJson() => {'adults': adults, 'children': children, 'students': students, 'foreigners': foreigners};

  String get label {
    final parts = <String>[
      if (adults > 0) '$adults adult${adults == 1 ? '' : 's'}',
      if (children > 0) '$children child${children == 1 ? '' : 'ren'}',
      if (students > 0) '$students student${students == 1 ? '' : 's'}',
      if (foreigners > 0) '$foreigners foreign',
    ];
    return parts.isEmpty ? 'Nobody' : parts.join(', ');
  }
}

/// Price for a party on a programme, computed from the programme's rate card.
class Quote {
  const Quote({required this.lines, required this.total});
  final List<BookingLine> lines;
  final int total;

  static Quote compute(Adventure a, Party party, {String? vehicle, bool camera = false}) {
    final p = a.pricing;
    final lines = <BookingLine>[];
    final n = party.total < 1 ? 1 : party.total;

    if (p.packageAmount != null) {
      final covers = p.packageCovers ?? n;
      if (p.additionalPerPerson != null || n <= covers) {
        lines.add(BookingLine('Ticket (up to $covers people)', p.packageAmount!));
        final extra = n - covers;
        if (extra > 0) lines.add(BookingLine('$extra extra ${extra == 1 ? 'person' : 'people'} × ${ProgramPricing.rupees(p.additionalPerPerson ?? 0)}', extra * (p.additionalPerPerson ?? 0)));
      } else {
        final tickets = (n / covers).ceil();
        lines.add(BookingLine('$tickets tickets × ${ProgramPricing.rupees(p.packageAmount!)} (up to $covers each)', tickets * p.packageAmount!));
      }
    } else if (p.perPersonIndian != null) {
      if (party.indians > 0) lines.add(BookingLine('${party.indians} × ${ProgramPricing.rupees(p.perPersonIndian!)}', party.indians * p.perPersonIndian!));
      if (party.foreigners > 0 && p.perPersonForeign != null) lines.add(BookingLine('${party.foreigners} foreign × ${ProgramPricing.rupees(p.perPersonForeign!)}', party.foreigners * p.perPersonForeign!));
      final sub = lines.fold(0, (s, l) => s + l.amount);
      if (p.minimumAmount != null && sub < p.minimumAmount!) lines.add(BookingLine('Minimum booking top-up', p.minimumAmount! - sub));
    } else if (p.perPerson != null) {
      lines.add(BookingLine('$n × ${ProgramPricing.rupees(p.perPerson!)}', n * p.perPerson!));
    }

    // Entry fees: either the whole ticket (falls entry) or the sanctuary entry on top of the package.
    if (p.entryFees.isNotEmpty) {
      int? feeFor(bool Function(String k) match) {
        for (final e in p.entryFees.entries) {
          if (match(e.key.toLowerCase())) return e.value;
        }
        return null;
      }
      final child = feeFor((k) => k.contains('child'));
      final student = feeFor((k) => k.contains('student'));
      final foreign = feeFor((k) => k.contains('foreign'));
      final adult = feeFor((k) => k.contains('indian') && !k.contains('child')) ?? feeFor((k) => !k.contains('foreign') && !k.contains('student') && !k.contains('child') && !k.contains('camera'));
      final prefix = a.programType == ProgramType.entry ? 'Entry' : 'Sanctuary entry';
      void add(String who, int count, int? fee, int? fallback) {
        final f = fee ?? fallback;
        if (count > 0 && f != null) lines.add(BookingLine('$prefix · $count $who × ${ProgramPricing.rupees(f)}', count * f));
      }
      add(party.adults == 1 ? 'adult' : 'adults', party.adults, adult, null);
      add(party.children == 1 ? 'child' : 'children', party.children, child, adult);
      add(party.students == 1 ? 'student' : 'students', party.students, student, adult);
      add('foreign', party.foreigners, foreign, adult);
    }
    if (vehicle != null && p.vehicleFees[vehicle] != null) lines.add(BookingLine('Parking · $vehicle', p.vehicleFees[vehicle]!));
    if (camera && p.cameraFees.isNotEmpty) {
      final e = p.cameraFees.entries.firstWhere((e) => !e.key.toLowerCase().contains('video'), orElse: () => p.cameraFees.entries.first);
      lines.add(BookingLine('Camera permit', e.value));
    }
    return Quote(lines: lines, total: lines.fold(0, (s, l) => s + l.amount));
  }
}

class Booking {
  const Booking({
    required this.id,
    required this.code,
    required this.userId,
    required this.userName,
    required this.programId,
    required this.programName,
    required this.destinationId,
    required this.destinationName,
    required this.coverImage,
    required this.date,
    required this.slot,
    required this.party,
    required this.lines,
    required this.total,
    required this.status,
    required this.createdAt,
    required this.paymentMethod,
    required this.paymentRef,
    this.vehicle,
    this.camera = false,
    this.operatorSynced = false,
  });

  factory Booking.fromJson(Map<String, dynamic> j) => Booking(
        id: j['id'] as String,
        code: j['code'] as String? ?? (j['id'] as String).substring(0, 6).toUpperCase(),
        userId: j['userId'] as String? ?? '',
        userName: j['userName'] as String? ?? '',
        programId: j['programId'] as String,
        programName: j['programName'] as String? ?? '',
        destinationId: j['destinationId'] as String? ?? '',
        destinationName: j['destinationName'] as String? ?? '',
        coverImage: j['coverImage'] as String?,
        date: DateTime.parse(j['date'] as String),
        slot: j['slot'] as String? ?? '',
        party: Party.fromJson((j['party'] as Map?)?.cast<String, dynamic>() ?? const {}),
        lines: (j['lines'] as List? ?? const []).map((e) => BookingLine.fromJson((e as Map).cast<String, dynamic>())).toList(),
        total: (j['total'] as num?)?.toInt() ?? 0,
        status: BookingStatus.values.byName(j['status'] as String? ?? 'confirmed'),
        createdAt: DateTime.parse(j['createdAt'] as String),
        paymentMethod: j['paymentMethod'] as String? ?? '',
        paymentRef: j['paymentRef'] as String? ?? '',
        vehicle: j['vehicle'] as String?,
        camera: j['camera'] as bool? ?? false,
        operatorSynced: j['operatorSynced'] as bool? ?? false,
      );

  final String id;

  /// Short code shown on the ticket and read at the gate.
  final String code;
  final String userId;
  final String userName;
  final String programId;
  final String programName;
  final String destinationId;
  final String destinationName;
  final String? coverImage;

  /// Day of the visit (local midnight).
  final DateTime date;
  final String slot;
  final Party party;
  final List<BookingLine> lines;
  final int total;
  final BookingStatus status;
  final DateTime createdAt;
  final String paymentMethod;
  final String paymentRef;
  final String? vehicle;
  final bool camera;

  /// Set once the booking has been pushed to the operator's system.
  final bool operatorSynced;

  bool get isUpcoming => status == BookingStatus.confirmed && !date.isBefore(DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day));
  bool get isPast => status == BookingStatus.completed || (status == BookingStatus.confirmed && !isUpcoming);

  Booking copyWith({BookingStatus? status, bool? operatorSynced}) => Booking(
        id: id, code: code, userId: userId, userName: userName, programId: programId, programName: programName, destinationId: destinationId,
        destinationName: destinationName, coverImage: coverImage, date: date, slot: slot, party: party, lines: lines, total: total,
        status: status ?? this.status, createdAt: createdAt, paymentMethod: paymentMethod, paymentRef: paymentRef, vehicle: vehicle, camera: camera,
        operatorSynced: operatorSynced ?? this.operatorSynced,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'code': code,
        'userId': userId,
        'userName': userName,
        'programId': programId,
        'programName': programName,
        'destinationId': destinationId,
        'destinationName': destinationName,
        'coverImage': coverImage,
        'date': date.toIso8601String(),
        'slot': slot,
        'party': party.toJson(),
        'lines': lines.map((l) => l.toJson()).toList(),
        'total': total,
        'status': status.name,
        'createdAt': createdAt.toIso8601String(),
        'paymentMethod': paymentMethod,
        'paymentRef': paymentRef,
        'vehicle': vehicle,
        'camera': camera,
        'operatorSynced': operatorSynced,
      };
}

/// Time slots a programme can be booked for on a day.
List<String> slotsFor(Adventure a) {
  final t = a.timing;
  if (a.programType == ProgramType.stay) return const ['Check-in 2:00 PM'];
  if (t.startTime != null) return [t.startTime!];
  if (t.open == null || t.close == null) return const ['Morning'];
  if (t.open == t.close) return [t.open!];
  final open = _parse(t.open!);
  final close = _parse(t.close!);
  if (open == null || close == null) return [t.open!];
  final step = a.programType == ProgramType.coracle ? 30 : 60;
  // Last start must leave time for the programme; short rides can start until close.
  final lastStart = a.programType == ProgramType.coracle ? close - 30 : close;
  final out = <String>[];
  for (var m = open; m <= lastStart; m += step) {
    out.add(_fmt(m));
  }
  return out.isEmpty ? [t.open!] : out;
}

int? _parse(String s) {
  final m = RegExp(r'^(\d{1,2}):(\d{2})\s*(AM|PM)$', caseSensitive: false).firstMatch(s.trim());
  if (m == null) return null;
  var h = int.parse(m.group(1)!);
  final min = int.parse(m.group(2)!);
  final pm = m.group(3)!.toUpperCase() == 'PM';
  if (h == 12) h = 0;
  return (pm ? h + 12 : h) * 60 + min;
}

String _fmt(int minutes) {
  final h24 = minutes ~/ 60;
  final m = minutes % 60;
  final h = h24 % 12 == 0 ? 12 : h24 % 12;
  return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')} ${h24 < 12 ? 'AM' : 'PM'}';
}
