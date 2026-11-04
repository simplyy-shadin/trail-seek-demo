/// Player avatar as a set of layer choices. Encoded into `AppUser.avatarId`
/// as `v1:base.outfit.accessory.hairStyle.hairColor` so storage and sync
/// stay a single string.
class Avatar {
  const Avatar({this.base = 0, this.outfit = 0, this.accessory = 0, this.hairStyle = 0, this.hairColor = 0});

  final int base; // 0..7 skin / build
  final int outfit; // 0..3
  final int accessory; // 0..3 (none, cap, glasses, backpack)
  final int hairStyle; // 0..5
  final int hairColor; // 0..5

  static const bases = 8;
  static const outfits = 4;
  static const accessories = 4;
  static const hairStyles = 6;
  static const hairColors = 6;

  static const outfitNames = ['Trail Jacket', 'Summit Shell', 'Forest Tee', 'River Vest'];
  static const accessoryNames = ['None', 'Cap', 'Sunglasses', 'Backpack'];
  static const hairStyleNames = ['Short', 'Crop', 'Wavy', 'Bun', 'Long', 'Shaved'];

  static Avatar decode(String? id) {
    if (id == null || !id.startsWith('v1:')) return const Avatar();
    final parts = id.substring(3).split('.').map((p) => int.tryParse(p) ?? 0).toList();
    if (parts.length != 5) return const Avatar();
    return Avatar(
      base: parts[0].clamp(0, bases - 1),
      outfit: parts[1].clamp(0, outfits - 1),
      accessory: parts[2].clamp(0, accessories - 1),
      hairStyle: parts[3].clamp(0, hairStyles - 1),
      hairColor: parts[4].clamp(0, hairColors - 1),
    );
  }

  String encode() => 'v1:$base.$outfit.$accessory.$hairStyle.$hairColor';

  Avatar copyWith({int? base, int? outfit, int? accessory, int? hairStyle, int? hairColor}) => Avatar(
        base: base ?? this.base,
        outfit: outfit ?? this.outfit,
        accessory: accessory ?? this.accessory,
        hairStyle: hairStyle ?? this.hairStyle,
        hairColor: hairColor ?? this.hairColor,
      );

  @override
  bool operator ==(Object other) => other is Avatar && other.encode() == encode();
  @override
  int get hashCode => encode().hashCode;
}
