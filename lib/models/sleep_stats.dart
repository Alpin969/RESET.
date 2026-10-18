class SleepDayStat {
  final DateTime date;
  final int logCount;
  final int totalMinutes;
  final int averageMinutes;

  const SleepDayStat({
    required this.date,
    required this.logCount,
    required this.totalMinutes,
    required this.averageMinutes,
  });
}

class SleepMonthStat {
  final int year;
  final int month;
  final int logCount;
  final int totalMinutes;
  final int averageMinutes;

  const SleepMonthStat({
    required this.year,
    required this.month,
    required this.logCount,
    required this.totalMinutes,
    required this.averageMinutes,
  });
}

class SleepStats {
  final int totalCount;
  final int averageMinutes;
  final int? belowNights;
  final int? withinNights;
  final int? aboveNights;
  final List<SleepDayStat> daily;
  final List<SleepMonthStat> monthly;

  const SleepStats({
    required this.totalCount,
    required this.averageMinutes,
    this.belowNights,
    this.withinNights,
    this.aboveNights,
    this.daily = const [],
    this.monthly = const [],
  });
}
