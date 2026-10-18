class TaskReminder {
  static const String frequencyDaily = 'daily';
  static const String frequencySpecificDays = 'specific_days';

  final String id;
  final String userId;
  final String taskId;
  final String? taskName;
  final bool taskIsActive;
  final bool taskDeleted;
  final String timeOfDay;
  final String frequency;
  final List<int> daysOfWeek;
  final bool isEnabled;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const TaskReminder({
    required this.id,
    required this.userId,
    required this.taskId,
    this.taskName,
    required this.taskIsActive,
    required this.taskDeleted,
    required this.timeOfDay,
    required this.frequency,
    required this.daysOfWeek,
    required this.isEnabled,
    this.createdAt,
    this.updatedAt,
  });

  static String normalizeTime(String raw) {
    final parts = raw.trim().split(':');
    if (parts.length < 2) {
      return '';
    }
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) {
      return '';
    }
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) {
      return '';
    }
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }

  factory TaskReminder.fromMap(Map<String, dynamic> map) {
    final rawTime = map['time_of_day']?.toString() ?? '';
    final normalized = normalizeTime(rawTime);
    final rawDays = map['days_of_week'] as List?;
    return TaskReminder(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      taskId: map['task_id'] as String,
      taskName: map['task_name'] as String?,
      taskIsActive: map['task_is_active'] as bool? ?? true,
      taskDeleted: map['task_deleted'] as bool? ?? false,
      timeOfDay: normalized.isEmpty ? rawTime : normalized,
      frequency: map['frequency'] as String? ?? frequencyDaily,
      daysOfWeek:
          rawDays?.map((dynamic e) => (e as num).toInt()).toList() ?? const [],
      isEnabled: map['is_enabled'] as bool? ?? true,
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? ''),
      updatedAt: DateTime.tryParse(map['updated_at']?.toString() ?? ''),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'task_id': taskId,
      'task_name': taskName,
      'task_is_active': taskIsActive,
      'task_deleted': taskDeleted,
      'time_of_day': timeOfDay,
      'frequency': frequency,
      'days_of_week': daysOfWeek,
      'is_enabled': isEnabled,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  TaskReminder copyWith({
    String? timeOfDay,
    String? frequency,
    List<int>? daysOfWeek,
    bool? isEnabled,
    bool? taskIsActive,
    bool? taskDeleted,
  }) {
    return TaskReminder(
      id: id,
      userId: userId,
      taskId: taskId,
      taskName: taskName,
      taskIsActive: taskIsActive ?? this.taskIsActive,
      taskDeleted: taskDeleted ?? this.taskDeleted,
      timeOfDay: timeOfDay ?? this.timeOfDay,
      frequency: frequency ?? this.frequency,
      daysOfWeek: daysOfWeek ?? this.daysOfWeek,
      isEnabled: isEnabled ?? this.isEnabled,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
