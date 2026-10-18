import 'task_snapshot.dart';

class ActivityDay {
  final DateTime date;
  final int completedCount;
  final int totalCount;
  final double percentage;
  final bool allCompleted;
  final List<TaskSnapshot> tasks;

  const ActivityDay({
    required this.date,
    required this.completedCount,
    required this.totalCount,
    required this.percentage,
    required this.allCompleted,
    this.tasks = const [],
  });
}
