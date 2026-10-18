class ChecklistEntry {
  final String id;
  final String userId;
  final String taskId;
  final DateTime checkDate;
  final bool completed;
  final DateTime? completedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const ChecklistEntry({
    required this.id,
    required this.userId,
    required this.taskId,
    required this.checkDate,
    required this.completed,
    this.completedAt,
    this.createdAt,
    this.updatedAt,
  });

  factory ChecklistEntry.fromMap(Map<String, dynamic> map) {
    return ChecklistEntry(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      taskId: map['task_id'] as String,
      checkDate: DateTime.parse(map['check_date'].toString()),
      completed: map['completed'] as bool? ?? false,
      completedAt: DateTime.tryParse(map['completed_at']?.toString() ?? ''),
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? ''),
      updatedAt: DateTime.tryParse(map['updated_at']?.toString() ?? ''),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'task_id': taskId,
      'check_date': checkDate.toIso8601String().split('T').first,
      'completed': completed,
      'completed_at': completedAt?.toUtc().toIso8601String(),
      'created_at': createdAt?.toUtc().toIso8601String(),
      'updated_at': updatedAt?.toUtc().toIso8601String(),
    };
  }
}
