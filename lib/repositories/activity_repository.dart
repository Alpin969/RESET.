import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/activity_day.dart';
import '../models/activity_summary.dart';
import '../models/task_snapshot.dart';
import '../utils/activity_calculator.dart';
import '../utils/task_progress.dart';

class ActivityRepository {
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

  Future<List<TaskSnapshot>> _fetchSnapshotsBetween(
    DateTime from,
    DateTime to,
  ) async {
    final uid = _requireUid();
    final data = await _client
        .from('task_daily_snapshots')
        .select()
        .eq('user_id', uid)
        .gte('check_date', TaskProgress.dateKey(from))
        .lte('check_date', TaskProgress.dateKey(to))
        .order('check_date', ascending: true)
        .order('position', ascending: true)
        .order('created_at', ascending: true);

    return (data as List)
        .map((row) => TaskSnapshot.fromMap(_asMap(row)))
        .toList();
  }

  Future<void> _ensureTodaySnapshot(DateTime today) async {
    await _client.rpc(
      'task_ensure_snapshot',
      params: {'p_date': TaskProgress.dateKey(today)},
    );
  }

  Future<void> _ensureTodayIfInRange(
    DateTime today,
    DateTime first,
    DateTime last,
  ) async {
    if (!first.isAfter(today) && !last.isBefore(today)) {
      await _ensureTodaySnapshot(today);
    }
  }

  Future<List<TaskSnapshot>> getTaskHistoryForDate(DateTime date) async {
    final normalized = TaskProgress.normalize(date);
    final today = await getLocalToday();
    await _ensureTodayIfInRange(today, normalized, normalized);
    return _fetchSnapshotsBetween(normalized, normalized);
  }

  Future<ActivityDay> getDailyActivity(DateTime date) async {
    final snapshots = await getTaskHistoryForDate(date);
    final days = ActivityCalculator.buildDays(
      firstDay: date,
      lastDay: date,
      snapshots: snapshots,
      includeTaskDetails: true,
    );
    return days.first;
  }

  Future<ActivitySummary> getWeeklyActivity({DateTime? startDate}) async {
    final today = await getLocalToday();
    final start = TaskProgress.normalize(
      startDate ?? DateTime(today.year, today.month, today.day - 6),
    );
    final end = DateTime(start.year, start.month, start.day + 6);

    await _ensureTodayIfInRange(today, start, end);

    final snapshots = await _fetchSnapshotsBetween(start, end);
    return ActivityCalculator.buildSummary(firstDay: start, lastDay: end, snapshots: snapshots);
  }

  Future<ActivitySummary> getMonthlyActivity(int year, int month) async {
    final today = await getLocalToday();
    final first = DateTime(year, month, 1);
    final last = DateTime(year, month + 1, 0);

    await _ensureTodayIfInRange(today, first, last);

    final snapshots = await _fetchSnapshotsBetween(first, last);
    return ActivityCalculator.buildSummary(firstDay: first, lastDay: last, snapshots: snapshots);
  }

  Future<ActivitySummary> getYearlyActivity(int year) async {
    final today = await getLocalToday();
    final first = DateTime(year, 1, 1);
    final last = DateTime(year, 12, 31);

    await _ensureTodayIfInRange(today, first, last);

    final snapshots = await _fetchSnapshotsBetween(first, last);
    final days = ActivityCalculator.buildDays(firstDay: first, lastDay: last, snapshots: snapshots);
    final months = ActivityCalculator.buildMonths(year: year, days: days);
    return ActivityCalculator.summaryFromDays(
      firstDay: first,
      lastDay: last,
      days: days,
      months: months,
    );
  }

  Future<ActivitySummary> getActivityHistory(
    DateTime startDate,
    DateTime endDate, {
    int limit = 31,
    int offset = 0,
  }) async {
    final today = await getLocalToday();
    final first = TaskProgress.normalize(startDate);
    final last = TaskProgress.normalize(endDate);
    if (last.isBefore(first)) {
      throw AuthException('Rentang tanggal tidak valid.');
    }

    await _ensureTodayIfInRange(today, first, last);

    final snapshots = await _fetchSnapshotsBetween(first, last);
    final summary = ActivityCalculator.buildSummary(firstDay: first, lastDay: last, snapshots: snapshots);
    return ActivityCalculator.paginate(summary, limit: limit, offset: offset);
  }

  Future<ActivitySummary> getActivitySummary(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final today = await getLocalToday();
    final first = TaskProgress.normalize(startDate);
    final last = TaskProgress.normalize(endDate);
    if (last.isBefore(first)) {
      throw AuthException('Rentang tanggal tidak valid.');
    }

    await _ensureTodayIfInRange(today, first, last);

    final snapshots = await _fetchSnapshotsBetween(first, last);
    return ActivityCalculator.buildSummary(firstDay: first, lastDay: last, snapshots: snapshots);
  }
}
