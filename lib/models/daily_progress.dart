class DailyProgress {
  final DateTime date;
  final int totalTasks;
  final int completedTasks;
  final double percentage;
  final bool allCompleted;

  const DailyProgress({
    required this.date,
    required this.totalTasks,
    required this.completedTasks,
    required this.percentage,
    required this.allCompleted,
  });
}
