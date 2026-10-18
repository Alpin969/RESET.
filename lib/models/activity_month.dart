class ActivityMonth {
  final int year;
  final int month;
  final int completedCount;
  final int totalCount;
  final double percentage;
  final int activeDays;
  final int allCompletedDays;

  const ActivityMonth({
    required this.year,
    required this.month,
    required this.completedCount,
    required this.totalCount,
    required this.percentage,
    required this.activeDays,
    required this.allCompletedDays,
  });
}
