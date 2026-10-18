class TaskSnapshot {
  final String id;
  final String taskId;
  final String name;
  final String? icon;
  final int position;
  final bool isActive;
  final bool isCompleted;
  final DateTime? completedAt;
  final DateTime checkDate;

  const TaskSnapshot({
    required this.id,
    required this.taskId,
    required this.name,
    this.icon,
    required this.position,
    required this.isActive,
    required this.isCompleted,
    this.completedAt,
    required this.checkDate,
  });

  factory TaskSnapshot.fromMap(Map<String, dynamic> map) {
    return TaskSnapshot(
      id: map['id'] as String,
      taskId: map['task_id'] as String,
      name: map['name'] as String,
      icon: map['icon'] as String?,
      position: (map['position'] as num?)?.toInt() ?? 0,
      isActive: map['is_active'] as bool? ?? true,
      isCompleted: map['completed'] as bool? ?? false,
      completedAt: DateTime.tryParse(map['completed_at']?.toString() ?? ''),
      checkDate: DateTime.parse(map['check_date'].toString()),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'task_id': taskId,
      'name': name,
      'icon': icon,
      'position': position,
      'is_active': isActive,
      'completed': isCompleted,
      'completed_at': completedAt?.toIso8601String(),
      'check_date': checkDate.toIso8601String(),
    };
  }
}
