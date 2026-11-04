class Region {
  const Region({
    required this.id,
    required this.name,
    required this.state,
    required this.tagline,
    required this.enabled,
    required this.coverHue,
  });

  factory Region.fromJson(Map<String, dynamic> json) => Region(
        id: json['id'] as String,
        name: json['name'] as String,
        state: json['state'] as String,
        tagline: json['tagline'] as String? ?? '',
        enabled: json['enabled'] as bool? ?? false,
        coverHue: (json['coverHue'] as num?)?.toDouble() ?? 140,
      );

  final String id;
  final String name;
  final String state;
  final String tagline;
  final bool enabled;

  /// Hue used for the placeholder gradient until real photography lands.
  final double coverHue;
}
