import '../models/activity_summary.dart';
import '../models/dashboard_overview.dart';
import '../models/daily_progress.dart';
import '../models/sleep_log.dart';
import '../models/streak_info.dart';
import '../repositories/activity_repository.dart';
import '../repositories/savings_repository.dart';
import '../repositories/sleep_repository.dart';
import '../repositories/streak_repository.dart';
import '../repositories/task_repository.dart';
import '../utils/task_progress.dart';

class DashboardService {
  DashboardService({
    TaskRepository? taskRepository,
    StreakRepository? streakRepository,
    SavingsRepository? savingsRepository,
    ActivityRepository? activityRepository,
    SleepRepository? sleepRepository,
  })  : _tasks = taskRepository ?? TaskRepository(),
        _streaks = streakRepository ?? StreakRepository(),
        _savings = savingsRepository ?? SavingsRepository(),
        _activity = activityRepository ?? ActivityRepository(),
        _sleep = sleepRepository ?? SleepRepository();

  final TaskRepository _tasks;
  final StreakRepository _streaks;
  final SavingsRepository _savings;
  final ActivityRepository _activity;
  final SleepRepository _sleep;

  Future<DashboardOverview> getOverview() async {
    final today = await _tasks.getLocalToday();

    final results = await Future.wait<Object?>([
      _streaks.getStreakInfo(),
      _savings.getCurrentBalance(),
      _tasks.getDailyProgress(today),
      _activity.getWeeklyActivity(
        startDate: TaskProgress.normalize(
          DateTime(today.year, today.month, today.day - 6),
        ),
      ),
      _sleep.getLatestSleepLog(),
    ]);

    final streakInfo = results[0] as StreakInfo;
    final totalSavings = (results[1] as num).toInt();
    final todayProgress = results[2] as DailyProgress;
    final weekly = results[3] as ActivitySummary;
    final latestSleep = results[4] as SleepLog?;

    return DashboardOverview(
      currentStreak: streakInfo.currentStreak,
      totalSavings: totalSavings,
      todayProgress: todayProgress,
      weeklyActivity: weekly.days,
      latestSleep: latestSleep,
      generatedAt: DateTime.now(),
    );
  }
}
