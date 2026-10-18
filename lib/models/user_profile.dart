class UserProfile {
  final String id;
  final String username;
  final String? avatarUrl;
  final String? motivation;
  final String? ageGroup;
  final String timezone;
  final String? email;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const UserProfile({
    required this.id,
    required this.username,
    this.avatarUrl,
    this.motivation,
    this.ageGroup,
    this.timezone = 'Asia/Jakarta',
    this.email,
    this.createdAt,
    this.updatedAt,
  });

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      id: map['id'] as String,
      username: map['username'] as String,
      avatarUrl: map['avatar_url'] as String?,
      motivation: map['motivation'] as String?,
      ageGroup: map['age_group'] as String?,
      timezone: map['timezone'] as String? ?? 'Asia/Jakarta',
      email: map['email'] as String?,
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? ''),
      updatedAt: DateTime.tryParse(map['updated_at']?.toString() ?? ''),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'username': username,
      'avatar_url': avatarUrl,
      'motivation': motivation,
      'age_group': ageGroup,
      'timezone': timezone,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  UserProfile copyWith({
    String? username,
    String? avatarUrl,
    String? motivation,
    String? ageGroup,
    String? timezone,
    String? email,
  }) {
    return UserProfile(
      id: id,
      username: username ?? this.username,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      motivation: motivation ?? this.motivation,
      ageGroup: ageGroup ?? this.ageGroup,
      timezone: timezone ?? this.timezone,
      email: email ?? this.email,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
