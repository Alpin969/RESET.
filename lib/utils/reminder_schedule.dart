class ReminderSchedule {
  static const String frequencyDaily = 'daily';
  static const String frequencySpecificDays = 'specific_days';
  static const int retryLimit = 3;
  static const int graceMinutes = 5;

  static String? normalizeTime(String raw) {
    final trimmed = raw.trim();
    final match = RegExp(r'^([01]\d|2[0-3]):([0-5]\d)$').firstMatch(trimmed);
    if (match == null) {
      return null;
    }
    return '${match.group(1)}:${match.group(2)}';
  }

  static String? normalizeTimeFlexible(String raw) {
    final trimmed = raw.trim();
    final full = RegExp(
      r'^([01]?\d|2[0-3]):([0-5]\d)(?::([0-5]\d))?$',
    ).firstMatch(trimmed);
    if (full == null) {
      return null;
    }
    final hour = int.parse(full.group(1)!);
    final minute = int.parse(full.group(2)!);
    if (hour > 23 || minute > 59) {
      return null;
    }
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }

  static List<int>? normalizeDays(List<int> days) {
    final unique = days.toSet().toList()..sort();
    if (unique.isEmpty || unique.length > 7) {
      return null;
    }
    for (final day in unique) {
      if (day < 0 || day > 6) {
        return null;
      }
    }
    return unique;
  }

  static bool isValidFrequency(String frequency, List<int> days) {
    if (frequency == frequencyDaily) {
      return days.isEmpty;
    }
    if (frequency == frequencySpecificDays) {
      return normalizeDays(days) != null;
    }
    return false;
  }

  static bool matchesDay({
    required DateTime localDate,
    required String frequency,
    required List<int> daysOfWeek,
  }) {
    if (frequency == frequencyDaily) {
      return true;
    }
    if (frequency == frequencySpecificDays) {
      return daysOfWeek.contains(localDate.weekday % 7);
    }
    return false;
  }

  static bool isDueAt({
    required DateTime localNow,
    required int hour,
    required int minute,
    required String frequency,
    required List<int> daysOfWeek,
    int grace = graceMinutes,
  }) {
    if (!matchesDay(
      localDate: localNow,
      frequency: frequency,
      daysOfWeek: daysOfWeek,
    )) {
      return false;
    }
    final due = DateTime(
      localNow.year,
      localNow.month,
      localNow.day,
      hour,
      minute,
    );
    final until = due.add(Duration(minutes: grace));
    return !localNow.isBefore(due) && localNow.isBefore(until);
  }

  static DateTime nextOccurrence({
    required DateTime fromLocal,
    required int hour,
    required int minute,
    required String frequency,
    required List<int> daysOfWeek,
  }) {
    var day = DateTime(fromLocal.year, fromLocal.month, fromLocal.day);
    if (frequency != frequencySpecificDays) {
      var candidate = DateTime(day.year, day.month, day.day, hour, minute);
      if (!candidate.isAfter(fromLocal)) {
        candidate = candidate.add(const Duration(days: 1));
      }
      return candidate;
    }
    for (var offset = 0; offset <= 7; offset++) {
      final candidateDay = day.add(Duration(days: offset));
      if (!matchesDay(
        localDate: candidateDay,
        frequency: frequencySpecificDays,
        daysOfWeek: daysOfWeek,
      )) {
        continue;
      }
      final candidate = DateTime(
        candidateDay.year,
        candidateDay.month,
        candidateDay.day,
        hour,
        minute,
      );
      if (candidate.isAfter(fromLocal)) {
        return candidate;
      }
    }
    return DateTime(day.year, day.month, day.day, hour, minute)
        .add(const Duration(days: 7));
  }

  static DateTime scheduledInstant({
    required DateTime localDate,
    required int hour,
    required int minute,
    required Duration utcOffset,
  }) {
    final local = DateTime.utc(
      localDate.year,
      localDate.month,
      localDate.day,
      hour,
      minute,
    );
    return local.subtract(utcOffset);
  }

  static String deliveryKey({
    required String reminderId,
    required DateTime localDate,
    required String timeOfDay,
    required String subscriptionId,
  }) {
    final dateKey =
        '${localDate.year.toString().padLeft(4, '0')}-${localDate.month.toString().padLeft(2, '0')}-${localDate.day.toString().padLeft(2, '0')}';
    return '$reminderId|$dateKey|$timeOfDay|$subscriptionId';
  }

  static String? skipReason({
    required bool reminderEnabled,
    required bool notificationsEnabled,
    required bool taskDeleted,
    required bool taskInactive,
    required bool taskCompletedToday,
    required bool hasSubscription,
  }) {
    if (!notificationsEnabled) {
      return 'notifications_disabled';
    }
    if (!reminderEnabled) {
      return 'reminder_disabled';
    }
    if (taskDeleted) {
      return 'task_removed';
    }
    if (taskInactive) {
      return 'task_inactive';
    }
    if (taskCompletedToday) {
      return 'task_completed_today';
    }
    if (!hasSubscription) {
      return 'no_subscription';
    }
    return null;
  }
}
