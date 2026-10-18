import '../models/daily_progress.dart';
import '../models/task_snapshot.dart';

class TaskProgress {
  static String dateKey(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  static DateTime normalize(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  static List<DateTime> lastSevenDays(DateTime end) {
    final last = normalize(end);
    return List.generate(
      7,
      (index) => DateTime(last.year, last.month, last.day - (6 - index)),
    );
  }

  static DailyProgress compute(DateTime date, List<TaskSnapshot> snapshots) {
    final total = snapshots.length;
    final completed = snapshots.where((snapshot) => snapshot.isCompleted).length;
    final percentage = total == 0 ? 0.0 : (completed / total) * 100;
    final allCompleted = total > 0 && completed == total;

    return DailyProgress(
      date: normalize(date),
      totalTasks: total,
      completedTasks: completed,
      percentage: percentage,
      allCompleted: allCompleted,
    );
  }
}
