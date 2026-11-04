import 'package:flutter/material.dart';

import '../../app/theme.dart';
import 'activity_category.dart';

enum Difficulty {
  easy('Easy', TsColors.difficultyEasy),
  moderate('Moderate', TsColors.difficultyModerate),
  hard('Very Difficult', TsColors.difficultyHard);

  const Difficulty(this.label, this.color);
  final String label;
  final Color color;

  static Difficulty fromKey(String key) =>
      values.firstWhere((d) => d.name == key, orElse: () => moderate);
}

class EmergencyContact {
  const EmergencyContact({required this.label, required this.phone});
  factory EmergencyContact.fromJson(Map<String, dynamic> j) => EmergencyContact(
        label: j['label'] as String,
        phone: j['phone'] as String? ?? '',
      );
  final String label;
  final String phone;
}

class GearGuide {
  const GearGuide({
    required this.shoes,
    required this.clothing,
    required this.food,
    required this.hydration,
    required this.firstAid,
  });
  factory GearGuide.fromJson(Map<String, dynamic> j) => GearGuide(
        shoes: j['shoes'] as String? ?? '',
        clothing: j['clothing'] as String? ?? '',
        food: j['food'] as String? ?? '',
        hydration: j['hydration'] as String? ?? '',
        firstAid: j['firstAid'] as String? ?? '',
      );
  final String shoes;
  final String clothing;
  final String food;
  final String hydration;
  final String firstAid;
}

class Suitability {
  const Suitability({
    required this.beginner,
    required this.family,
    required this.group,
  });
  factory Suitability.fromJson(Map<String, dynamic> j) => Suitability(
        beginner: j['beginner'] as bool? ?? false,
        family: j['family'] as bool? ?? false,
        group: j['group'] as bool? ?? true,
      );
  final bool beginner;
  final bool family;
  final bool group;
}

/// What kind of Forest Department programme an [Adventure] is.
enum ProgramType {
  trekking('Trekking', Icons.hiking),
  hiking('Hiking', Icons.directions_walk),
  coracle('Coracle ride', Icons.sailing),
  cycling('Cycling', Icons.pedal_bike),
  stay('Stay', Icons.night_shelter_outlined),
  entry('Entry & sightseeing', Icons.confirmation_number_outlined);

  const ProgramType(this.label, this.icon);
  final String label;
  final IconData icon;
  static ProgramType fromKey(String? k) => values.firstWhere((v) => v.name == k, orElse: () => trekking);
}

/// Prices exactly as the Forest Department portal lists them.
class ProgramPricing {
  const ProgramPricing({
    this.packageAmount,
    this.packageCovers,
    this.additionalPerPerson,
    this.perPerson,
    this.perPersonIndian,
    this.perPersonForeign,
    this.minimumAmount,
    this.entryFees = const {},
    this.vehicleFees = const {},
    this.cameraFees = const {},
    this.remarks,
  });
  factory ProgramPricing.fromJson(Map<String, dynamic> j) {
    Map<String, int> fees(String k) => ((j[k] as Map?) ?? const {}).map((key, v) => MapEntry(key.toString(), (v as num).toInt()));
    return ProgramPricing(
      packageAmount: (j['packageAmount'] as num?)?.toInt(),
      packageCovers: (j['packageCovers'] as num?)?.toInt(),
      additionalPerPerson: (j['additionalPerPerson'] as num?)?.toInt(),
      perPerson: (j['perPerson'] as num?)?.toInt(),
      perPersonIndian: (j['perPersonIndian'] as num?)?.toInt(),
      perPersonForeign: (j['perPersonForeign'] as num?)?.toInt(),
      minimumAmount: (j['minimumAmount'] as num?)?.toInt(),
      entryFees: fees('entryFees'),
      vehicleFees: fees('vehicleFees'),
      cameraFees: fees('cameraFees'),
      remarks: j['remarks'] as String?,
    );
  }
  final int? packageAmount;
  final int? packageCovers;
  final int? additionalPerPerson;
  final int? perPerson;
  final int? perPersonIndian;
  final int? perPersonForeign;
  final int? minimumAmount;
  final Map<String, int> entryFees;
  final Map<String, int> vehicleFees;
  final Map<String, int> cameraFees;
  final String? remarks;

  /// Lowest number a visitor pays to take part, for cards and sorting.
  int? get fromAmount {
    if (packageAmount != null) return packageAmount;
    if (perPersonIndian != null) return perPersonIndian;
    if (perPerson != null) return perPerson;
    if (entryFees.isNotEmpty) return entryFees.values.reduce((a, b) => a < b ? a : b);
    return null;
  }

  /// Short card line such as "₹1,200 · up to 4" or "₹1,500 / person".
  String get shortLabel {
    if (packageAmount != null) return '₹${_fmt(packageAmount!)} · up to ${packageCovers ?? '-'}';
    if (perPersonIndian != null) return '₹${_fmt(perPersonIndian!)} / person';
    if (perPerson != null) return '₹${_fmt(perPerson!)} / person';
    if (entryFees.isNotEmpty) return 'From ₹${_fmt(fromAmount!)}';
    return 'Ask at counter';
  }

  static String _fmt(int n) {
    final s = n.toString();
    if (s.length <= 3) return s;
    final head = s.substring(0, s.length - 3);
    final tail = s.substring(s.length - 3);
    final buf = StringBuffer();
    for (var i = 0; i < head.length; i++) {
      if (i > 0 && (head.length - i) % 2 == 0) buf.write(',');
      buf.write(head[i]);
    }
    return '$buf,$tail';
  }

  static String rupees(int n) => '₹${_fmt(n)}';
}

class ProgramTiming {
  const ProgramTiming({this.open, this.close, this.startTime, this.note});
  factory ProgramTiming.fromJson(Map<String, dynamic> j) =>
      ProgramTiming(open: j['open'] as String?, close: j['close'] as String?, startTime: j['startTime'] as String?, note: j['note'] as String?);
  final String? open;
  final String? close;
  final String? startTime;
  final String? note;
  String get label {
    if (startTime != null) return 'Starts $startTime';
    if (open != null && close != null) return open == close ? 'Reporting $open' : '$open – $close';
    return 'By arrangement';
  }
}

/// How a programme can be booked in Trail Seek.
enum Availability {
  open('Bookable'),
  onRequest('On request'),
  soon('Opening soon'),
  closed('Not available now');

  const Availability(this.label);
  final String label;
  static Availability fromKey(String? k) => values.firstWhere((v) => v.name == k, orElse: () => open);
}

class BookingInfo {
  const BookingInfo({this.availability = Availability.open, this.bookingWindowDays = 30, this.capacityPerDay});
  factory BookingInfo.fromJson(Map<String, dynamic> j) => BookingInfo(
        availability: Availability.fromKey(j['availability'] as String?),
        bookingWindowDays: (j['bookingWindowDays'] as num?)?.toInt() ?? 30,
        capacityPerDay: (j['capacityPerDay'] as num?)?.toInt(),
      );
  final Availability availability;

  /// How far ahead a date can be picked.
  final int bookingWindowDays;

  /// Seats per day across all slots; null when unlimited.
  final int? capacityPerDay;

  bool get isClosed => availability == Availability.closed;
  bool get notStarted => availability == Availability.soon;
  bool get bookable => availability == Availability.open || availability == Availability.onRequest;
}

class Adventure {
  const Adventure({
    required this.id,
    required this.name,
    required this.regionId,
    required this.district,
    required this.nearestTown,
    required this.categories,
    required this.difficulty,
    required this.distanceKm,
    required this.durationHoursMin,
    required this.durationHoursMax,
    required this.elevationM,
    required this.elevationGainM,
    required this.terrain,
    required this.bestSeason,
    required this.entryFee,
    required this.permit,
    required this.guideRequired,
    required this.howToReach,
    required this.parking,
    required this.network,
    required this.facilities,
    required this.waterAvailability,
    required this.emergencyContacts,
    required this.risks,
    required this.dangerousSections,
    required this.wildlife,
    required this.gear,
    required this.suitability,
    required this.checklist,
    required this.precautions,
    required this.highlights,
    required this.lat,
    required this.lng,
    required this.coverHue,
    required this.verified,
    this.destinationId,
    this.destinationName,
    this.programType = ProgramType.trekking,
    this.summaryText,
    this.description = '',
    this.officialDescription = '',
    this.images = const [],
    this.pricing = const ProgramPricing(),
    this.timing = const ProgramTiming(),
    this.minPersons,
    this.maxPersons,
    this.inclusions = const [],
    this.booking,
  });

  factory Adventure.fromJson(Map<String, dynamic> j) {
    final duration = (j['durationHours'] as List?)?.cast<num>() ?? const [2, 3];
    List<String> strings(String key) =>
        (j[key] as List?)?.cast<String>() ?? const [];
    return Adventure(
      id: j['id'] as String,
      name: j['name'] as String,
      regionId: j['regionId'] as String,
      district: j['district'] as String? ?? '',
      nearestTown: j['nearestTown'] as String? ?? '',
      categories: strings('categories')
          .map(ActivityCategory.fromKey)
          .whereType<ActivityCategory>()
          .toList(),
      difficulty: Difficulty.fromKey(j['difficulty'] as String? ?? 'moderate'),
      distanceKm: (j['distanceKm'] as num?)?.toDouble() ?? 0,
      durationHoursMin: duration.first.toDouble(),
      durationHoursMax: duration.last.toDouble(),
      elevationM: (j['elevationM'] as num?)?.toInt() ?? 0,
      elevationGainM: (j['elevationGainM'] as num?)?.toInt() ?? 0,
      terrain: j['terrain'] as String? ?? '',
      bestSeason: j['bestSeason'] as String? ?? '',
      entryFee: j['entryFee'] as String? ?? '',
      permit: j['permit'] as String? ?? '',
      guideRequired: j['guideRequired'] as bool? ?? false,
      howToReach: j['howToReach'] as String? ?? '',
      parking: j['parking'] as String? ?? '',
      network: j['network'] as String? ?? '',
      facilities: strings('facilities'),
      waterAvailability: j['waterAvailability'] as String? ?? '',
      emergencyContacts: (j['emergencyContacts'] as List? ?? const [])
          .map((e) => EmergencyContact.fromJson(e as Map<String, dynamic>))
          .toList(),
      risks: strings('risks'),
      dangerousSections: strings('dangerousSections'),
      wildlife: j['wildlife'] as String? ?? '',
      gear: GearGuide.fromJson((j['gear'] as Map?)?.cast<String, dynamic>() ?? {}),
      suitability: Suitability.fromJson(
          (j['suitability'] as Map?)?.cast<String, dynamic>() ?? {}),
      checklist: strings('checklist'),
      precautions: strings('precautions'),
      highlights: strings('highlights'),
      lat: (j['lat'] as num?)?.toDouble() ?? 0,
      lng: (j['lng'] as num?)?.toDouble() ?? 0,
      coverHue: (j['coverHue'] as num?)?.toDouble() ?? 140,
      verified: j['verified'] as bool? ?? false,
      destinationId: j['destinationId'] as String?,
      destinationName: j['destinationName'] as String?,
      programType: ProgramType.fromKey(j['programType'] as String?),
      summaryText: j['summary'] as String?,
      description: j['description'] as String? ?? '',
      officialDescription: j['officialDescription'] as String? ?? '',
      images: strings('images'),
      pricing: ProgramPricing.fromJson((j['pricing'] as Map?)?.cast<String, dynamic>() ?? const {}),
      timing: ProgramTiming.fromJson((j['timing'] as Map?)?.cast<String, dynamic>() ?? const {}),
      minPersons: (j['minPersons'] as num?)?.toInt(),
      maxPersons: (j['maxPersons'] as num?)?.toInt(),
      inclusions: strings('inclusions'),
      booking: j['booking'] == null ? null : BookingInfo.fromJson((j['booking'] as Map).cast<String, dynamic>()),
    );
  }

  final String id;
  final String name;
  final String regionId;
  final String district;
  final String nearestTown;
  final List<ActivityCategory> categories;
  final Difficulty difficulty;
  final double distanceKm;
  final double durationHoursMin;
  final double durationHoursMax;
  final int elevationM;
  final int elevationGainM;
  final String terrain;
  final String bestSeason;
  final String entryFee;
  final String permit;
  final bool guideRequired;
  final String howToReach;
  final String parking;
  final String network;
  final List<String> facilities;
  final String waterAvailability;
  final List<EmergencyContact> emergencyContacts;
  final List<String> risks;
  final List<String> dangerousSections;
  final String wildlife;
  final GearGuide gear;
  final Suitability suitability;
  final List<String> checklist;
  final List<String> precautions;
  final List<String> highlights;
  final double lat;
  final double lng;
  final double coverHue;

  /// False until product research has validated fees, permits and contacts.
  final bool verified;

  // ---- Forest Department programme fields (null/empty for plain trails).
  final String? destinationId;
  final String? destinationName;
  final ProgramType programType;
  final String? summaryText;
  final String description;
  final String officialDescription;

  /// Bundled asset paths; first is the cover.
  final List<String> images;
  final ProgramPricing pricing;
  final ProgramTiming timing;
  final int? minPersons;
  final int? maxPersons;
  final List<String> inclusions;
  final BookingInfo? booking;

  String? get coverImage => images.isEmpty ? null : images.first;
  bool get isProgram => destinationId != null;
  bool get isBookable => (booking ?? const BookingInfo()).bookable;

  /// Walking programmes can be tracked with GPS and the Digital Rope.
  bool get isWalkable => programType == ProgramType.trekking || programType == ProgramType.hiking || programType == ProgramType.entry;

  String get durationLabel {
    String f(double h) => h == h.roundToDouble() ? h.toInt().toString() : h.toString();
    if (durationHoursMax >= 12) {
      final days = (durationHoursMax / 8).ceil();
      return '$days ${days == 1 ? 'Day' : 'Days'}';
    }
    return durationHoursMin == durationHoursMax
        ? '${f(durationHoursMin)} hrs'
        : '${f(durationHoursMin)}-${f(durationHoursMax)} hrs';
  }

  String get distanceLabel {
    final d = distanceKm;
    return d == d.roundToDouble() ? '${d.toInt()} km' : '$d km';
  }

  /// Two-line blurb for list cards.
  String get summary {
    if (summaryText != null && summaryText!.isNotEmpty) return summaryText!;
    final t = terrain.trim();
    final terrainPart = t.isEmpty ? '' : (t.endsWith('.') ? t : '$t.');
    final guide = guideRequired ? ' Guide required.' : '';
    return '$terrainPart Best $bestSeason.$guide'.trim();
  }

  ActivityCategory get primaryCategory =>
      categories.isEmpty ? ActivityCategory.hiking : categories.first;
}
