import 'package:flutter_test/flutter_test.dart';
import 'package:reset_app/utils/reminder_schedule.dart';

void main() {
  group('ReminderSchedule.normalizeTimeFlexible', () {
    test('accepts padded and unpadded times', () {
      expect(ReminderSchedule.normalizeTimeFlexible('08:05'), '08:05');
      expect(ReminderSchedule.normalizeTimeFlexible('8:05'), '08:05');
      expect(ReminderSchedule.normalizeTimeFlexible('08:05:30'), '08:05');
      expect(ReminderSchedule.normalizeTimeFlexible(' 23:59 '), '23:59');
      expect(ReminderSchedule.normalizeTimeFlexible('00:00'), '00:00');
    });

    test('rejects invalid values', () {
      expect(ReminderSchedule.normalizeTimeFlexible('24:00'), isNull);
      expect(ReminderSchedule.normalizeTimeFlexible('07:60'), isNull);
      expect(ReminderSchedule.normalizeTimeFlexible(''), isNull);
      expect(ReminderSchedule.normalizeTimeFlexible('pagi'), isNull);
    });
  });

  group('ReminderSchedule.normalizeDays', () {
    test('sorts and deduplicates days', () {
      expect(ReminderSchedule.normalizeDays([5, 1, 1, 3]), [1, 3, 5]);
      expect(ReminderSchedule.normalizeDays([0, 6]), [0, 6]);
    });

    test('rejects empty or out of range days', () {
      expect(ReminderSchedule.normalizeDays([]), isNull);
      expect(ReminderSchedule.normalizeDays([7]), isNull);
      expect(ReminderSchedule.normalizeDays([-1]), isNull);
    });
  });

  group('ReminderSchedule.isValidFrequency', () {
    test('daily must not include days', () {
      expect(
        ReminderSchedule.isValidFrequency(
          ReminderSchedule.frequencyDaily,
          const [],
        ),
        isTrue,
      );
      expect(
        ReminderSchedule.isValidFrequency(
          ReminderSchedule.frequencyDaily,
          const [1],
        ),
        isFalse,
      );
    });

    test('specific days requires valid day list', () {
      expect(
        ReminderSchedule.isValidFrequency(
          ReminderSchedule.frequencySpecificDays,
          const [0, 3, 6],
        ),
        isTrue,
      );
      expect(
        ReminderSchedule.isValidFrequency(
          ReminderSchedule.frequencySpecificDays,
          const [],
        ),
        isFalse,
      );
      expect(
        ReminderSchedule.isValidFrequency('weekly', const [1]),
        isFalse,
      );
    });
  });

  group('ReminderSchedule.matchesDay', () {
    final sunday = DateTime(2026, 10, 18);
    final monday = DateTime(2026, 10, 19);

    test('daily matches every day', () {
      expect(
        ReminderSchedule.matchesDay(
          localDate: sunday,
          frequency: ReminderSchedule.frequencyDaily,
          daysOfWeek: const [],
        ),
        isTrue,
      );
      expect(
        ReminderSchedule.matchesDay(
          localDate: monday,
          frequency: ReminderSchedule.frequencyDaily,
          daysOfWeek: const [],
        ),
        isTrue,
      );
    });

    test('specific days uses 0=sunday notation', () {
      expect(
        ReminderSchedule.matchesDay(
          localDate: sunday,
          frequency: ReminderSchedule.frequencySpecificDays,
          daysOfWeek: const [0],
        ),
        isTrue,
      );
      expect(
        ReminderSchedule.matchesDay(
          localDate: monday,
          frequency: ReminderSchedule.frequencySpecificDays,
          daysOfWeek: const [0],
        ),
        isFalse,
      );
      expect(
        ReminderSchedule.matchesDay(
          localDate: monday,
          frequency: ReminderSchedule.frequencySpecificDays,
          daysOfWeek: const [1, 3, 5],
        ),
        isTrue,
      );
    });
  });

  group('ReminderSchedule.isDueAt', () {
    test('is due at reminder time and within grace window', () {
      expect(
        ReminderSchedule.isDueAt(
          localNow: DateTime(2026, 10, 17, 8, 0),
          hour: 8,
          minute: 0,
          frequency: ReminderSchedule.frequencyDaily,
          daysOfWeek: const [],
        ),
        isTrue,
      );
      expect(
        ReminderSchedule.isDueAt(
          localNow: DateTime(2026, 10, 17, 8, 4),
          hour: 8,
          minute: 0,
          frequency: ReminderSchedule.frequencyDaily,
          daysOfWeek: const [],
        ),
        isTrue,
      );
    });

    test('is not due after grace window or before reminder time', () {
      expect(
        ReminderSchedule.isDueAt(
          localNow: DateTime(2026, 10, 17, 8, 5),
          hour: 8,
          minute: 0,
          frequency: ReminderSchedule.frequencyDaily,
          daysOfWeek: const [],
        ),
        isFalse,
      );
      expect(
        ReminderSchedule.isDueAt(
          localNow: DateTime(2026, 10, 17, 7, 59),
          hour: 8,
          minute: 0,
          frequency: ReminderSchedule.frequencyDaily,
          daysOfWeek: const [],
        ),
        isFalse,
      );
    });

    test('is not due when day does not match frequency', () {
      expect(
        ReminderSchedule.isDueAt(
          localNow: DateTime(2026, 10, 18, 8, 0),
          hour: 8,
          minute: 0,
          frequency: ReminderSchedule.frequencySpecificDays,
          daysOfWeek: const [1],
        ),
        isFalse,
      );
    });
  });

  group('ReminderSchedule.nextOccurrence', () {
    test('daily later today stays today', () {
      final next = ReminderSchedule.nextOccurrence(
        fromLocal: DateTime(2026, 10, 17, 7, 0),
        hour: 8,
        minute: 0,
        frequency: ReminderSchedule.frequencyDaily,
        daysOfWeek: const [],
      );

      expect(next, DateTime(2026, 10, 17, 8, 0));
    });

    test('daily already passed rolls to next day across midnight', () {
      final next = ReminderSchedule.nextOccurrence(
        fromLocal: DateTime(2026, 10, 17, 23, 59),
        hour: 0,
        minute: 0,
        frequency: ReminderSchedule.frequencyDaily,
        daysOfWeek: const [],
      );

      expect(next, DateTime(2026, 10, 18, 0, 0));
    });

    test('daily rolls across month and year boundary', () {
      final next = ReminderSchedule.nextOccurrence(
        fromLocal: DateTime(2026, 12, 31, 23, 0),
        hour: 8,
        minute: 0,
        frequency: ReminderSchedule.frequencyDaily,
        daysOfWeek: const [],
      );

      expect(next, DateTime(2027, 1, 1, 8, 0));
    });

    test('specific days skips non matching days across year boundary', () {
      final next = ReminderSchedule.nextOccurrence(
        fromLocal: DateTime(2026, 12, 31, 9, 0),
        hour: 8,
        minute: 0,
        frequency: ReminderSchedule.frequencySpecificDays,
        daysOfWeek: const [1],
      );

      expect(next, DateTime(2027, 1, 4, 8, 0));
    });

    test('specific days same day when time still ahead', () {
      final next = ReminderSchedule.nextOccurrence(
        fromLocal: DateTime(2026, 10, 19, 7, 0),
        hour: 8,
        minute: 0,
        frequency: ReminderSchedule.frequencySpecificDays,
        daysOfWeek: const [1],
      );

      expect(next, DateTime(2026, 10, 19, 8, 0));
    });

    test('specific days jumps to following week when time passed', () {
      final next = ReminderSchedule.nextOccurrence(
        fromLocal: DateTime(2026, 10, 19, 9, 0),
        hour: 8,
        minute: 0,
        frequency: ReminderSchedule.frequencySpecificDays,
        daysOfWeek: const [1],
      );

      expect(next, DateTime(2026, 10, 26, 8, 0));
    });
  });

  group('ReminderSchedule.scheduledInstant', () {
    test('converts local time using fixed utc offset', () {
      final instant = ReminderSchedule.scheduledInstant(
        localDate: DateTime(2026, 10, 17),
        hour: 8,
        minute: 0,
        utcOffset: const Duration(hours: 7),
      );

      expect(instant, DateTime.utc(2026, 10, 17, 1, 0));
    });

    test('timezone change keeps local time and shifts utc instant', () {
      final jakarta = ReminderSchedule.scheduledInstant(
        localDate: DateTime(2026, 10, 17),
        hour: 8,
        minute: 0,
        utcOffset: const Duration(hours: 7),
      );
      final tokyo = ReminderSchedule.scheduledInstant(
        localDate: DateTime(2026, 10, 17),
        hour: 8,
        minute: 0,
        utcOffset: const Duration(hours: 9),
      );

      expect(jakarta, DateTime.utc(2026, 10, 17, 1, 0));
      expect(tokyo, DateTime.utc(2026, 10, 16, 23, 0));
      expect(jakarta.difference(tokyo), const Duration(hours: 2));
    });

    test('dst offset shift moves utc instant by one hour', () {
      final beforeDst = ReminderSchedule.scheduledInstant(
        localDate: DateTime(2026, 3, 29),
        hour: 2,
        minute: 30,
        utcOffset: const Duration(hours: 1),
      );
      final afterDst = ReminderSchedule.scheduledInstant(
        localDate: DateTime(2026, 3, 29),
        hour: 2,
        minute: 30,
        utcOffset: const Duration(hours: 2),
      );

      expect(beforeDst, DateTime.utc(2026, 3, 29, 1, 30));
      expect(afterDst, DateTime.utc(2026, 3, 29, 0, 30));
      expect(beforeDst.difference(afterDst), const Duration(hours: 1));
    });
  });

  group('ReminderSchedule.deliveryKey', () {
    test('builds stable idempotency key', () {
      final key = ReminderSchedule.deliveryKey(
        reminderId: 'rem-1',
        localDate: DateTime(2026, 10, 17),
        timeOfDay: '08:00',
        subscriptionId: 'sub-1',
      );

      expect(key, 'rem-1|2026-10-17|08:00|sub-1');
    });

    test('key differs across local dates for month change', () {
      final october = ReminderSchedule.deliveryKey(
        reminderId: 'rem-1',
        localDate: DateTime(2026, 10, 31),
        timeOfDay: '08:00',
        subscriptionId: 'sub-1',
      );
      final november = ReminderSchedule.deliveryKey(
        reminderId: 'rem-1',
        localDate: DateTime(2026, 11, 1),
        timeOfDay: '08:00',
        subscriptionId: 'sub-1',
      );

      expect(october, 'rem-1|2026-10-31|08:00|sub-1');
      expect(november, 'rem-1|2026-11-01|08:00|sub-1');
      expect(october == november, isFalse);
    });
  });

  group('ReminderSchedule.skipReason', () {
    test('returns null when reminder can be sent', () {
      expect(
        ReminderSchedule.skipReason(
          reminderEnabled: true,
          notificationsEnabled: true,
          taskDeleted: false,
          taskInactive: false,
          taskCompletedToday: false,
          hasSubscription: true,
        ),
        isNull,
      );
    });

    test('skips when notifications disabled', () {
      expect(
        ReminderSchedule.skipReason(
          reminderEnabled: true,
          notificationsEnabled: false,
          taskDeleted: false,
          taskInactive: false,
          taskCompletedToday: false,
          hasSubscription: true,
        ),
        'notifications_disabled',
      );
    });

    test('skips when reminder disabled', () {
      expect(
        ReminderSchedule.skipReason(
          reminderEnabled: false,
          notificationsEnabled: true,
          taskDeleted: false,
          taskInactive: false,
          taskCompletedToday: false,
          hasSubscription: true,
        ),
        'reminder_disabled',
      );
    });

    test('skips when task removed', () {
      expect(
        ReminderSchedule.skipReason(
          reminderEnabled: true,
          notificationsEnabled: true,
          taskDeleted: true,
          taskInactive: false,
          taskCompletedToday: false,
          hasSubscription: true,
        ),
        'task_removed',
      );
    });

    test('skips when task inactive', () {
      expect(
        ReminderSchedule.skipReason(
          reminderEnabled: true,
          notificationsEnabled: true,
          taskDeleted: false,
          taskInactive: true,
          taskCompletedToday: false,
          hasSubscription: true,
        ),
        'task_inactive',
      );
    });

    test('skips when task already completed today', () {
      expect(
        ReminderSchedule.skipReason(
          reminderEnabled: true,
          notificationsEnabled: true,
          taskDeleted: false,
          taskInactive: false,
          taskCompletedToday: true,
          hasSubscription: true,
        ),
        'task_completed_today',
      );
    });

    test('skips when device has no subscription', () {
      expect(
        ReminderSchedule.skipReason(
          reminderEnabled: true,
          notificationsEnabled: true,
          taskDeleted: false,
          taskInactive: false,
          taskCompletedToday: false,
          hasSubscription: false,
        ),
        'no_subscription',
      );
    });
  });

  group('ReminderSchedule.retryLimit', () {
    test('caps delivery attempts at three', () {
      expect(ReminderSchedule.retryLimit, 3);
    });
  });
}
