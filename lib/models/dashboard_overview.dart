import 'activity_day.dart';
import 'daily_progress.dart';
import 'sleep_log.dart';

class DashboardOverview {
  final int currentStreak;
  final int totalSavings;
  final DailyProgress todayProgress;
  final List<ActivityDay> weeklyActivity;
  final SleepLog? latestSleep;
  final DateTime generatedAt;

  const DashboardOverview({
    required this.currentStreak,
    required this.totalSavings,
    required this.todayProgress,
    required this.weeklyActivity,
    this.latestSleep,
    required this.generatedAt,
  });
}
