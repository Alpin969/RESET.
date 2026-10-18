class SleepLog {
  final String id;
  final String userId;
  final DateTime sleepStart;
  final DateTime wakeTime;
  final int durationMinutes;
  final DateTime? wakeLocalDate;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const SleepLog({
    required this.id,
    required this.userId,
    required this.sleepStart,
    required this.wakeTime,
    required this.durationMinutes,
    this.wakeLocalDate,
    this.createdAt,
    this.updatedAt,
  });

  factory SleepLog.fromMap(Map<String, dynamic> map) {
    return SleepLog(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      sleepStart: DateTime.parse(map['sleep_start'] as String),
      wakeTime: DateTime.parse(map['wake_time'] as String),
      durationMinutes: (map['duration_minutes'] as num).toInt(),
      wakeLocalDate: DateTime.tryParse(map['wake_local_date']?.toString() ?? ''),
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? ''),
      updatedAt: DateTime.tryParse(map['updated_at']?.toString() ?? ''),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'sleep_start': sleepStart.toUtc().toIso8601String(),
      'wake_time': wakeTime.toUtc().toIso8601String(),
      'duration_minutes': durationMinutes,
      'wake_local_date': wakeLocalDate?.toIso8601String().split('T').first,
      'created_at': createdAt?.toUtc().toIso8601String(),
      'updated_at': updatedAt?.toUtc().toIso8601String(),
    };
  }

  SleepLog copyWith({
    DateTime? sleepStart,
    DateTime? wakeTime,
    int? durationMinutes,
    DateTime? wakeLocalDate,
  }) {
    return SleepLog(
      id: id,
      userId: userId,
      sleepStart: sleepStart ?? this.sleepStart,
      wakeTime: wakeTime ?? this.wakeTime,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      wakeLocalDate: wakeLocalDate ?? this.wakeLocalDate,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
