import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/daily_progress.dart';
import '../models/daily_task.dart';
import '../models/task_snapshot.dart';
import '../models/weekly_activity_day.dart';
import '../utils/task_progress.dart';

class TaskRepository {
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

  Future<DateTime> getLocalToday() async {
    _requireUid();
    final data = await _client.rpc('get_local_today');
    return TaskProgress.normalize(DateTime.parse(data.toString()));
  }

  Future<void> _ensureSnapshot(DateTime date) async {
    await _client.rpc(
      'task_ensure_snapshot',
      params: {'p_date': TaskProgress.dateKey(date)},
    );
  }

  Future<List<DailyTask>> getMyTasks() async {
    _requireUid();
    final data = await _client.rpc('task_list_my');
    return (data as List)
        .map((row) => DailyTask.fromMap(_asMap(row)))
        .toList();
  }

  Future<DailyTask> createTask({required String name, String? icon}) async {
    _requireUid();

    final trimmed = name.trim();
    if (trimmed.isEmpty || trimmed.length > 100) {
      throw AuthException('Nama task 1-100 karakter.');
    }

    final data = await _client.rpc(
      'task_create',
      params: {'p_name': trimmed, 'p_icon': icon},
    );
    return DailyTask.fromMap(_asMap(data));
  }

  Future<DailyTask> updateTask({
    required String taskId,
    String? name,
    String? icon,
    bool clearIcon = false,
    bool? isActive,
  }) async {
    _requireUid();

    if (name != null) {
      final trimmed = name.trim();
      if (trimmed.isEmpty || trimmed.length > 100) {
        throw AuthException('Nama task 1-100 karakter.');
      }
    }

    final iconChanged = icon != null || clearIcon;
    final data = await _client.rpc('task_update', params: {
      'p_task_id': taskId,
      'p_name': name?.trim(),
      'p_icon': clearIcon ? null : icon,
      'p_icon_changed': iconChanged,
      'p_is_active': isActive,
    });
    return DailyTask.fromMap(_asMap(data));
  }

  Future<void> deleteTask(String taskId) async {
    _requireUid();
    await _client.rpc('task_delete', params: {'p_task_id': taskId});
  }

  Future<void> reorderTasks(List<String> taskIds) async {
    _requireUid();
    if (taskIds.isEmpty) {
      throw AuthException('Daftar urutan task tidak valid.');
    }
    await _client.rpc('task_reorder', params: {'p_task_ids': taskIds});
  }

  Future<List<TaskSnapshot>> getDailyChecklist(DateTime date) async {
    final uid = _requireUid();
    final key = TaskProgress.dateKey(date);

    await _ensureSnapshot(date);

    final rows = await _client
        .from('task_daily_snapshots')
        .select()
        .eq('user_id', uid)
        .eq('check_date', key)
        .order('position', ascending: true)
        .order('created_at', ascending: true);

    return rows
        .map((row) => TaskSnapshot.fromMap(_asMap(row)))
        .toList();
  }

  Future<void> setTaskCompleted({
    required String taskId,
    required DateTime date,
    required bool completed,
  }) async {
    _requireUid();

    await _client.rpc('task_set_completed', params: {
      'p_task_id': taskId,
      'p_check_date': TaskProgress.dateKey(date),
      'p_completed': completed,
    });
  }

  Future<DailyProgress> getDailyProgress(DateTime date) async {
    final snapshots = await getDailyChecklist(date);
    return TaskProgress.compute(date, snapshots);
  }

  Future<List<WeeklyActivityDay>> getWeeklyActivity() async {
    final uid = _requireUid();
    final today = await getLocalToday();
    final days = TaskProgress.lastSevenDays(today);

    await _ensureSnapshot(today);

    final rows = await _client
        .from('task_daily_snapshots')
        .select()
        .eq('user_id', uid)
        .gte('check_date', TaskProgress.dateKey(days.first))
        .lte('check_date', TaskProgress.dateKey(today));

    final grouped = <String, List<TaskSnapshot>>{};
    for (final row in rows) {
      final snapshot = TaskSnapshot.fromMap(_asMap(row));
      final key = TaskProgress.dateKey(snapshot.checkDate);
      grouped.putIfAbsent(key, () => []).add(snapshot);
    }

    return days.map((day) {
      final snapshots = grouped[TaskProgress.dateKey(day)] ?? [];
      final completed =
          snapshots.where((snapshot) => snapshot.isCompleted).length;
      return WeeklyActivityDay(
        date: day,
        totalTasks: snapshots.length,
        completedTasks: completed,
      );
    }).toList();
  }
}
