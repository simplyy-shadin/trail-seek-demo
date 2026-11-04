/// One of the Thrissur eco-tourism destinations (a Forest Department eco-centre
/// or a pair of them, such as Athirappilly – Vazhachal). Programmes hang off it.
class NearbyPlace {
  const NearbyPlace({required this.name, required this.distanceKm, required this.note});
  factory NearbyPlace.fromJson(Map<String, dynamic> j) =>
      NearbyPlace(name: j['name'] as String, distanceKm: (j['distanceKm'] as num?)?.toDouble() ?? 0, note: j['note'] as String? ?? '');
  final String name;
  final double distanceKm;
  final String note;
}

class Destination {
  const Destination({
    required this.id,
    required this.name,
    required this.tagline,
    required this.district,
    required this.division,
    required this.nearestTown,
    required this.description,
    required this.officialDescription,
    required this.images,
    required this.lat,
    required this.lng,
    required this.elevationM,
    required this.phones,
    required this.email,
    required this.address,
    required this.howToReach,
    required this.timings,
    required this.entryFees,
    required this.highlights,
    required this.nearby,
    required this.bestSeason,
    required this.sourceUrls,
    required this.programCount,
  });

  factory Destination.fromJson(Map<String, dynamic> j) => Destination(
        id: j['id'] as String,
        name: j['name'] as String,
        tagline: j['tagline'] as String? ?? '',
        district: j['district'] as String? ?? 'Thrissur',
        division: j['division'] as String? ?? '',
        nearestTown: j['nearestTown'] as String? ?? '',
        description: j['description'] as String? ?? '',
        officialDescription: j['officialDescription'] as String? ?? '',
        images: (j['images'] as List? ?? const []).map((e) => e.toString()).toList(),
        lat: (j['lat'] as num).toDouble(),
        lng: (j['lng'] as num).toDouble(),
        elevationM: (j['elevationM'] as num?)?.toInt() ?? 0,
        phones: (j['phones'] as List? ?? const []).map((e) => e.toString()).toList(),
        email: j['email'] as String?,
        address: j['address'] as String? ?? '',
        howToReach: j['howToReach'] as String? ?? '',
        timings: j['timings'] as String? ?? '',
        entryFees: ((j['entryFees'] as Map?) ?? const {}).map((k, v) => MapEntry(k.toString(), (v as num).toInt())),
        highlights: (j['highlights'] as List? ?? const []).map((e) => e.toString()).toList(),
        nearby: (j['nearby'] as List? ?? const []).map((e) => NearbyPlace.fromJson((e as Map).cast<String, dynamic>())).toList(),
        bestSeason: j['bestSeason'] as String? ?? '',
        sourceUrls: (j['sourceUrls'] as List? ?? const []).map((e) => e.toString()).toList(),
        programCount: (j['programCount'] as num?)?.toInt() ?? 0,
      );

  final String id;
  final String name;
  final String tagline;
  final String district;
  final String division;
  final String nearestTown;
  final String description;
  final String officialDescription;
  final List<String> images;
  final double lat;
  final double lng;
  final int elevationM;
  final List<String> phones;
  final String? email;
  final String address;
  final String howToReach;
  final String timings;
  final Map<String, int> entryFees;
  final List<String> highlights;
  final List<NearbyPlace> nearby;
  final String bestSeason;
  final List<String> sourceUrls;
  final int programCount;

  String? get coverImage => images.isEmpty ? null : images.first;

  /// Short name for chips: "Athirappilly", "Peechi", "Chimmony", "Chulannur".
  String get shortName => name.split(RegExp(r'[–-]| Wildlife| Peafowl')).first.trim();
}
