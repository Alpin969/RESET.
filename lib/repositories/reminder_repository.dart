import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/task_reminder.dart';
import '../utils/reminder_schedule.dart';

class ReminderRepository {
  SupabaseClient get _client => Supabase.instance.client;

  String _requireUid() {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) {
      throw AuthException('Sesi tidak ditemukan. Silakan login ulang.');
    }
    return uid;
  }

  Map<String, dynamic> _asMap(dynamic value) {
    return Map<String, dynamic>.from(value as Map);
  }

  ({int hour, int minute, String normalized}) _parseTime(String raw) {
    final normalized = ReminderSchedule.normalizeTimeFlexible(raw);
    if (normalized == null) {
      throw AuthException('Waktu reminder tidak valid.');
    }
    final parts = normalized.split(':');
    return (
      hour: int.parse(parts[0]),
      minute: int.parse(parts[1]),
      normalized: normalized,
    );
  }

  List<int> _parseFrequency(String frequency, List<int> days) {
    if (!ReminderSchedule.isValidFrequency(frequency, days)) {
      throw AuthException('Frekuensi atau daftar hari tidak valid.');
    }
    if (frequency == TaskReminder.frequencyDaily) {
      return const [];
    }
    return ReminderSchedule.normalizeDays(days) ?? const [];
  }

  Future<List<TaskReminder>> getMyReminders() async {
    _requireUid();
    final data = await _client.rpc('reminder_list_my');
    return (data as List)
        .map((row) => TaskReminder.fromMap(_asMap(row)))
        .toList();
  }

  Future<TaskReminder> createReminder({
    required String taskId,
    required String timeOfDay,
    String frequency = TaskReminder.frequencyDaily,
    List<int> daysOfWeek = const [],
  }) async {
    _requireUid();

    if (taskId.trim().isEmpty) {
      throw AuthException('Task wajib dipilih.');
    }

    final time = _parseTime(timeOfDay);
    final days = _parseFrequency(frequency, daysOfWeek);

    final data = await _client.rpc('reminder_create', params: {
      'p_task_id': taskId,
      'p_time': '${time.normalized}:00',
      'p_frequency': frequency,
      'p_days': days.isEmpty ? null : days,
    });
    return TaskReminder.fromMap(_asMap(data));
  }

  Future<TaskReminder> updateReminder({
    required String reminderId,
    String? timeOfDay,
    String? frequency,
    List<int>? daysOfWeek,
  }) async {
    _requireUid();

    if (reminderId.trim().isEmpty) {
      throw AuthException('Reminder wajib dipilih.');
    }

    String? normalizedTime;
    if (timeOfDay != null) {
      normalizedTime = _parseTime(timeOfDay).normalized;
    }

    String? normalizedFrequency;
    List<int>? normalizedDays;
    if (frequency != null || daysOfWeek != null) {
      final effectiveFrequency = frequency ?? TaskReminder.frequencyDaily;
      final effectiveDays = daysOfWeek ?? const [];
      normalizedFrequency = effectiveFrequency;
      normalizedDays =
          _parseFrequency(effectiveFrequency, effectiveDays).toList();
    }

    final data = await _client.rpc('reminder_update', params: {
      'p_reminder_id': reminderId,
      'p_time': normalizedTime == null ? null : '$normalizedTime:00',
      'p_frequency': normalizedFrequency,
      'p_days': normalizedDays == null || normalizedDays.isEmpty
          ? null
          : normalizedDays,
      'p_is_enabled': null,
    });
    return TaskReminder.fromMap(_asMap(data));
  }

  Future<TaskReminder> toggleReminder({
    required String reminderId,
    required bool isEnabled,
  }) async {
    _requireUid();

    if (reminderId.trim().isEmpty) {
      throw AuthException('Reminder wajib dipilih.');
    }

    final data = await _client.rpc('reminder_toggle', params: {
      'p_reminder_id': reminderId,
      'p_is_enabled': isEnabled,
    });
    return TaskReminder.fromMap(_asMap(data));
  }

  Future<void> deleteReminder(String reminderId) async {
    _requireUid();
    if (reminderId.trim().isEmpty) {
      throw AuthException('Reminder wajib dipilih.');
    }
    await _client.rpc('reminder_delete', params: {'p_reminder_id': reminderId});
  }
}
