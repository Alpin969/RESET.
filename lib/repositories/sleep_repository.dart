import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/sleep_log.dart';
import '../models/sleep_stats.dart';
import '../utils/sleep_calculator.dart';
import '../utils/task_progress.dart';

class SleepRepository {
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

  Future<SleepLog> createSleepLog({
    required DateTime sleepStart,
    required DateTime wakeTime,
  }) async {
    _requireUid();

    final error = SleepCalculator.validate(sleepStart, wakeTime);
    if (error != null) throw AuthException(error);

    final data = await _client.rpc('sleep_create', params: {
      'p_sleep_start': sleepStart.toUtc().toIso8601String(),
      'p_wake_time': wakeTime.toUtc().toIso8601String(),
    });
    return SleepLog.fromMap(_asMap(data));
  }

  Future<List<SleepLog>> getMySleepLogs({int limit = 400, int offset = 0}) async {
    _requireUid();
    final data = await _client.rpc('sleep_list_my', params: {
      'p_limit': limit,
      'p_offset': offset,
    });
    return (data as List)
        .map((row) => SleepLog.fromMap(_asMap(row)))
        .toList();
  }

  Future<SleepLog?> getLatestSleepLog() async {
    _requireUid();
    final data = await _client.rpc('sleep_latest');
    if (data == null) return null;
    return SleepLog.fromMap(_asMap(data));
  }

  Future<SleepLog> getSleepLogById(String id) async {
    _requireUid();
    final data = await _client.rpc('sleep_get', params: {'p_id': id});
    return SleepLog.fromMap(_asMap(data));
  }

  Future<SleepLog> updateSleepLog({
    required String id,
    required DateTime sleepStart,
    required DateTime wakeTime,
  }) async {
    _requireUid();

    final error = SleepCalculator.validate(sleepStart, wakeTime);
    if (error != null) throw AuthException(error);

    final data = await _client.rpc('sleep_update', params: {
      'p_id': id,
      'p_sleep_start': sleepStart.toUtc().toIso8601String(),
      'p_wake_time': wakeTime.toUtc().toIso8601String(),
    });
    return SleepLog.fromMap(_asMap(data));
  }

  Future<void> deleteSleepLog(String id) async {
    _requireUid();
    await _client.rpc('sleep_delete', params: {'p_id': id});
  }

  Future<SleepStats> getWeeklySleepStats({String? ageGroup}) async {
    final today = await getLocalToday();
    final first = DateTime(today.year, today.month, today.day - 6);
    final logs = await _fetchLogsBetween(first, today);
    return SleepCalculator.computeDaily(
      logs: logs,
      firstDay: first,
      lastDay: today,
      ageGroup: ageGroup,
    );
  }

  Future<SleepStats> getMonthlySleepStats({String? ageGroup}) async {
    final today = await getLocalToday();
    final first = DateTime(today.year, today.month, today.day - 29);
    final logs = await _fetchLogsBetween(first, today);
    return SleepCalculator.computeDaily(
      logs: logs,
      firstDay: first,
      lastDay: today,
      ageGroup: ageGroup,
    );
  }

  Future<SleepStats> getYearlySleepStats({String? ageGroup}) async {
    final today = await getLocalToday();
    final first = DateTime(today.year, 1, 1);
    final last = DateTime(today.year, 12, 31);
    final logs = await _fetchLogsBetween(first, last);
    return SleepCalculator.computeMonthly(
      logs: logs,
      year: today.year,
      ageGroup: ageGroup,
    );
  }

  Future<List<SleepLog>> _fetchLogsBetween(DateTime from, DateTime to) async {
    final data = await _client.rpc('sleep_logs_between', params: {
      'p_from': TaskProgress.dateKey(from),
      'p_to': TaskProgress.dateKey(to),
    });
    return (data as List)
        .map((row) => SleepLog.fromMap(_asMap(row)))
        .toList();
  }
}
