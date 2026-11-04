enum AuthProviderKind { google, apple, phone, email }

class AppUser {
  const AppUser({
    required this.id,
    required this.displayName,
    required this.email,
    required this.username,
    required this.provider,
    required this.createdAt,
    this.avatarId,
  });

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
        id: j['id'] as String,
        displayName: j['displayName'] as String,
        email: j['email'] as String? ?? '',
        username: j['username'] as String? ?? '',
        provider: AuthProviderKind.values.byName(j['provider'] as String),
        createdAt: j['createdAt'] == null ? DateTime(2026) : DateTime.parse(j['createdAt'] as String),
        avatarId: j['avatarId'] as String?,
      );

  final String id;
  final String displayName;
  final String email;

  /// Public handle shown in groups and the community (e.g. `fayazff`).
  final String username;
  final AuthProviderKind provider;
  final DateTime createdAt;

  /// Set by avatar setup (task 04).
  final String? avatarId;

  String get firstName => displayName.trim().split(RegExp(r'\s+')).first;

  String get initials {
    final parts = displayName.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
  }

  AppUser copyWith({String? displayName, String? username, String? avatarId}) => AppUser(
        id: id,
        displayName: displayName ?? this.displayName,
        email: email,
        username: username ?? this.username,
        provider: provider,
        createdAt: createdAt,
        avatarId: avatarId ?? this.avatarId,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'displayName': displayName,
        'email': email,
        'username': username,
        'provider': provider.name,
        'createdAt': createdAt.toIso8601String(),
        'avatarId': avatarId,
      };
}
