import '../models/sleep_log.dart';
import '../models/sleep_stats.dart';
import 'task_progress.dart';

class SleepCalculator {
  static const int minDurationMinutes = 1;
  static const int maxDurationMinutes = 24 * 60;

  static const String statusAgeGroupRequired = 'ageGroupRequired';
  static const String statusBelow = 'below';
  static const String statusWithin = 'within';
  static const String statusAbove = 'above';

  static const Map<String, List<int>> recommendedMinutes = {
    '13-17': [480, 600],
    '18+': [420, 540],
  };

  static int durationMinutes(DateTime sleepStart, DateTime wakeTime) {
    final start = sleepStart.toUtc();
    final wake = wakeTime.toUtc();
    return (wake.difference(start).inSeconds / 60).round();
  }

  static String? validate(DateTime? sleepStart, DateTime? wakeTime) {
    if (sleepStart == null || wakeTime == null) {
      return 'Waktu tidur dan bangun wajib diisi.';
    }
    if (!wakeTime.isAfter(sleepStart)) {
      return 'Waktu bangun harus setelah waktu mulai tidur.';
    }
    final seconds = wakeTime.toUtc().difference(sleepStart.toUtc()).inSeconds;
    if (seconds < 60) {
      return 'Durasi tidur minimal 1 menit.';
    }
    final minutes = durationMinutes(sleepStart, wakeTime);
    if (minutes > maxDurationMinutes) {
      return 'Durasi tidur maksimal 24 jam.';
    }
    return null;
  }

  static bool overlaps(
    DateTime aStart,
    DateTime aWake,
    DateTime bStart,
    DateTime bWake,
  ) {
    return aStart.isBefore(bWake) && bStart.isBefore(aWake);
  }

  static List<int>? recommendedRange(String? ageGroup) {
    return recommendedMinutes[ageGroup];
  }

  static String statusFor(int duration, String? ageGroup) {
    final range = recommendedRange(ageGroup);
    if (range == null) return statusAgeGroupRequired;
    if (duration < range[0]) return statusBelow;
    if (duration > range[1]) return statusAbove;
    return statusWithin;
  }

  static SleepStats computeDaily({
    required List<SleepLog> logs,
    required DateTime firstDay,
    required DateTime lastDay,
    String? ageGroup,
  }) {
    final start = _dateOnly(firstDay);
    final end = _dateOnly(lastDay);

    final windowLogs = logs.where((log) {
      final localDate = log.wakeLocalDate;
      if (localDate == null) return false;
      final date = _dateOnly(localDate);
      return !date.isBefore(start) && !date.isAfter(end);
    }).toList();

    final grouped = _groupByWakeDate(windowLogs);
    final daily = <SleepDayStat>[];
    var day = start;

    while (!day.isAfter(end)) {
      final list = grouped[TaskProgress.dateKey(day)] ?? const <SleepLog>[];
      final total = _totalMinutes(list);
      daily.add(SleepDayStat(
        date: day,
        logCount: list.length,
        totalMinutes: total,
        averageMinutes: list.isEmpty ? 0 : (total / list.length).round(),
      ));
      day = DateTime(day.year, day.month, day.day + 1);
    }

    return _stats(windowLogs, ageGroup, daily: daily);
  }

  static SleepStats computeMonthly({
    required List<SleepLog> logs,
    required int year,
    String? ageGroup,
  }) {
    final yearLogs = logs
        .where((log) => log.wakeLocalDate?.year == year)
        .toList();

    final grouped = <String, List<SleepLog>>{};
    for (final log in yearLogs) {
      final localDate = log.wakeLocalDate!;
      final key = '${localDate.year}-${localDate.month.toString().padLeft(2, '0')}';
      grouped.putIfAbsent(key, () => []).add(log);
    }

    final monthly = <SleepMonthStat>[];
    for (var month = 1; month <= 12; month++) {
      final key = '$year-${month.toString().padLeft(2, '0')}';
      final list = grouped[key] ?? const <SleepLog>[];
      final total = _totalMinutes(list);
      monthly.add(SleepMonthStat(
        year: year,
        month: month,
        logCount: list.length,
        totalMinutes: total,
        averageMinutes: list.isEmpty ? 0 : (total / list.length).round(),
      ));
    }

    return _stats(yearLogs, ageGroup, monthly: monthly);
  }

  static Map<String, List<SleepLog>> _groupByWakeDate(List<SleepLog> logs) {
    final grouped = <String, List<SleepLog>>{};
    for (final log in logs) {
      final localDate = log.wakeLocalDate;
      if (localDate == null) continue;
      grouped.putIfAbsent(TaskProgress.dateKey(localDate), () => []).add(log);
    }
    return grouped;
  }

  static int _totalMinutes(List<SleepLog> logs) {
    return logs.fold<int>(0, (sum, log) => sum + log.durationMinutes);
  }

  static SleepStats _stats(
    List<SleepLog> logs,
    String? ageGroup, {
    List<SleepDayStat> daily = const [],
    List<SleepMonthStat> monthly = const [],
  }) {
    final total = _totalMinutes(logs);

    int? below;
    int? within;
    int? above;

    if (ageGroup != null) {
      below = 0;
      within = 0;
      above = 0;
      for (final log in logs) {
        final status = statusFor(log.durationMinutes, ageGroup);
        if (status == statusBelow) below = below! + 1;
        if (status == statusWithin) within = within! + 1;
        if (status == statusAbove) above = above! + 1;
      }
    }

    return SleepStats(
      totalCount: logs.length,
      averageMinutes: logs.isEmpty ? 0 : (total / logs.length).round(),
      belowNights: below,
      withinNights: within,
      aboveNights: above,
      daily: daily,
      monthly: monthly,
    );
  }

  static DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }
}
