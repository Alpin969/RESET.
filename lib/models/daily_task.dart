class DailyTask {
  final String id;
  final String userId;
  final String name;
  final String? icon;
  final int position;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const DailyTask({
    required this.id,
    required this.userId,
    required this.name,
    this.icon,
    required this.position,
    required this.isActive,
    this.createdAt,
    this.updatedAt,
  });

  factory DailyTask.fromMap(Map<String, dynamic> map) {
    return DailyTask(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      name: map['name'] as String,
      icon: map['icon'] as String?,
      position: (map['position'] as num?)?.toInt() ?? 0,
      isActive: map['is_active'] as bool? ?? true,
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? ''),
      updatedAt: DateTime.tryParse(map['updated_at']?.toString() ?? ''),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'name': name,
      'icon': icon,
      'position': position,
      'is_active': isActive,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  DailyTask copyWith({
    String? name,
    String? icon,
    int? position,
    bool? isActive,
  }) {
    return DailyTask(
      id: id,
      userId: userId,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      position: position ?? this.position,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
