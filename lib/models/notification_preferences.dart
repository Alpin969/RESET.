import 'task_reminder.dart';

class NotificationPreferences {
  final bool notificationsEnabled;
  final String reminderDefaultTime;
  final String? timezone;

  const NotificationPreferences({
    required this.notificationsEnabled,
    required this.reminderDefaultTime,
    this.timezone,
  });

  factory NotificationPreferences.fromMap(Map<String, dynamic> map) {
    final rawTime = map['reminder_default_time']?.toString() ?? '08:00';
    final normalized = TaskReminder.normalizeTime(rawTime);
    return NotificationPreferences(
      notificationsEnabled: map['notifications_enabled'] as bool? ?? true,
      reminderDefaultTime: normalized.isEmpty ? '08:00' : normalized,
      timezone: map['timezone'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'notifications_enabled': notificationsEnabled,
      'reminder_default_time': reminderDefaultTime,
      'timezone': timezone,
    };
  }

  NotificationPreferences copyWith({
    bool? notificationsEnabled,
    String? reminderDefaultTime,
    String? timezone,
  }) {
    return NotificationPreferences(
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      reminderDefaultTime: reminderDefaultTime ?? this.reminderDefaultTime,
      timezone: timezone ?? this.timezone,
    );
  }
}
