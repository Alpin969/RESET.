import '../models/activity_day.dart';
import '../models/activity_month.dart';
import '../models/activity_summary.dart';
import '../models/task_snapshot.dart';
import 'task_progress.dart';

class ActivityCalculator {
  static int daysInMonth(int year, int month) {
    return DateTime(year, month + 1, 0).day;
  }

  static List<TaskSnapshot> _clean(List<TaskSnapshot> snapshots) {
    final byKey = <String, TaskSnapshot>{};
    for (final snapshot in snapshots) {
      final key =
          '${TaskProgress.dateKey(snapshot.checkDate)}|${snapshot.taskId}';
      byKey[key] ??= snapshot;
    }

    final list = byKey.values.toList();
    list.sort((a, b) {
      final byDate = TaskProgress.dateKey(a.checkDate)
          .compareTo(TaskProgress.dateKey(b.checkDate));
      if (byDate != 0) return byDate;
      if (a.position != b.position) {
        return a.position.compareTo(b.position);
      }
      return a.taskId.compareTo(b.taskId);
    });
    return list;
  }

  static List<ActivityDay> buildDays({
    required DateTime firstDay,
    required DateTime lastDay,
    required List<TaskSnapshot> snapshots,
    bool includeTaskDetails = false,
  }) {
    final first = TaskProgress.normalize(firstDay);
    final last = TaskProgress.normalize(lastDay);
    if (last.isBefore(first)) return const [];

    final grouped = <String, List<TaskSnapshot>>{};
    for (final snapshot in _clean(snapshots)) {
      grouped
          .putIfAbsent(TaskProgress.dateKey(snapshot.checkDate), () => [])
          .add(snapshot);
    }

    final days = <ActivityDay>[];
    var cursor = first;
    while (!cursor.isAfter(last)) {
      final list =
          grouped[TaskProgress.dateKey(cursor)] ?? const <TaskSnapshot>[];
      final total = list.length;
      final completed = list.where((snapshot) => snapshot.isCompleted).length;

      days.add(ActivityDay(
        date: cursor,
        completedCount: completed,
        totalCount: total,
        percentage: total == 0 ? 0.0 : (completed / total) * 100,
        allCompleted: total > 0 && completed == total,
        tasks: includeTaskDetails ? List<TaskSnapshot>.of(list) : const [],
      ));

      cursor = DateTime(cursor.year, cursor.month, cursor.day + 1);
    }
    return days;
  }

  static ActivitySummary summaryFromDays({
    required DateTime firstDay,
    required DateTime lastDay,
    required List<ActivityDay> days,
    List<ActivityMonth> months = const [],
  }) {
    final totalAvailable = days.fold<int>(0, (sum, day) => sum + day.totalCount);
    final totalCompleted =
        days.fold<int>(0, (sum, day) => sum + day.completedCount);

    return ActivitySummary(
      startDate: TaskProgress.normalize(firstDay),
      endDate: TaskProgress.normalize(lastDay),
      totalCompleted: totalCompleted,
      totalAvailable: totalAvailable,
      percentage:
          totalAvailable == 0 ? 0.0 : (totalCompleted / totalAvailable) * 100,
      activeDays: days.where((day) => day.completedCount > 0).length,
      allCompletedDays: days.where((day) => day.allCompleted).length,
      days: days,
      months: months,
    );
  }

  static ActivitySummary buildSummary({
    required DateTime firstDay,
    required DateTime lastDay,
    required List<TaskSnapshot> snapshots,
    bool includeTaskDetails = false,
  }) {
    final days = buildDays(
      firstDay: firstDay,
      lastDay: lastDay,
      snapshots: snapshots,
      includeTaskDetails: includeTaskDetails,
    );
    return summaryFromDays(firstDay: firstDay, lastDay: lastDay, days: days);
  }

  static List<ActivityMonth> buildMonths({
    required int year,
    required List<ActivityDay> days,
  }) {
    return List.generate(12, (index) {
      final month = index + 1;
      final inMonth = days
          .where((day) => day.date.year == year && day.date.month == month)
          .toList();

      final totalAvailable =
          inMonth.fold<int>(0, (sum, day) => sum + day.totalCount);
      final totalCompleted =
          inMonth.fold<int>(0, (sum, day) => sum + day.completedCount);

      return ActivityMonth(
        year: year,
        month: month,
        completedCount: totalCompleted,
        totalCount: totalAvailable,
        percentage: totalAvailable == 0
            ? 0.0
            : (totalCompleted / totalAvailable) * 100,
        activeDays: inMonth.where((day) => day.completedCount > 0).length,
        allCompletedDays: inMonth.where((day) => day.allCompleted).length,
      );
    });
  }

  static ActivitySummary paginate(
    ActivitySummary summary, {
    int limit = 31,
    int offset = 0,
  }) {
    final safeOffset = offset.clamp(0, summary.days.length);
    final safeLimit = limit.clamp(1, 400);
    final end = (safeOffset + safeLimit).clamp(0, summary.days.length);

    return ActivitySummary(
      startDate: summary.startDate,
      endDate: summary.endDate,
      totalCompleted: summary.totalCompleted,
      totalAvailable: summary.totalAvailable,
      percentage: summary.percentage,
      activeDays: summary.activeDays,
      allCompletedDays: summary.allCompletedDays,
      days: summary.days.sublist(safeOffset, end),
      months: summary.months,
    );
  }
}
