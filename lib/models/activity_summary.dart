import 'activity_day.dart';
import 'activity_month.dart';

class ActivitySummary {
  final DateTime startDate;
  final DateTime endDate;
  final int totalCompleted;
  final int totalAvailable;
  final double percentage;
  final int activeDays;
  final int allCompletedDays;
  final List<ActivityDay> days;
  final List<ActivityMonth> months;

  const ActivitySummary({
    required this.startDate,
    required this.endDate,
    required this.totalCompleted,
    required this.totalAvailable,
    required this.percentage,
    required this.activeDays,
    required this.allCompletedDays,
    this.days = const [],
    this.months = const [],
  });
}
