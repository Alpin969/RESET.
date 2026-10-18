class StreakInfo {
  final int currentStreak;
  final DateTime? lastActiveDate;
  final int missedDays;
  final bool isActiveToday;
  final int graceDaysRemaining;

  const StreakInfo({
    required this.currentStreak,
    required this.lastActiveDate,
    required this.missedDays,
    required this.isActiveToday,
    required this.graceDaysRemaining,
  });
}
