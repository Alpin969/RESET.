import '../models/streak_info.dart';
import 'task_progress.dart';

class StreakCalculator {
  static const int graceDays = 2;
  static const int maxActiveDateLimit = 5000;

  static StreakInfo compute({
    required List<DateTime> activeDates,
    required DateTime today,
  }) {
    final todayDate = TaskProgress.normalize(today);

    final dates = activeDates
        .map(TaskProgress.normalize)
        .where((date) => !date.isAfter(todayDate))
        .toSet()
        .toList()
      ..sort((a, b) => b.compareTo(a));

    if (dates.isEmpty) {
      return const StreakInfo(
        currentStreak: 0,
        lastActiveDate: null,
        missedDays: 0,
        isActiveToday: false,
        graceDaysRemaining: graceDays,
      );
    }

    final lastActive = dates.first;
    final isActiveToday = lastActive == todayDate;
    final missedDays = isActiveToday
        ? 0
        : todayDate.difference(lastActive).inDays - 1;

    if (missedDays > graceDays) {
      return StreakInfo(
        currentStreak: 0,
        lastActiveDate: lastActive,
        missedDays: missedDays,
        isActiveToday: false,
        graceDaysRemaining: 0,
      );
    }

    var streak = 0;
    DateTime? previous;

    for (final date in dates) {
      if (previous != null &&
          previous.difference(date).inDays > graceDays + 1) {
        break;
      }
      streak += 1;
      previous = date;
    }

    return StreakInfo(
      currentStreak: streak,
      lastActiveDate: lastActive,
      missedDays: missedDays,
      isActiveToday: isActiveToday,
      graceDaysRemaining: graceDays - missedDays,
    );
  }
}
