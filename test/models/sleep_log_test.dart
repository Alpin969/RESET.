import 'package:flutter_test/flutter_test.dart';
import 'package:reset_app/models/sleep_log.dart';

void main() {
  Map<String, dynamic> row() {
    return {
      'id': 'log-1',
      'user_id': 'user-1',
      'sleep_start': '2026-10-17T16:00:00.000Z',
      'wake_time': '2026-10-17T23:30:00.000Z',
      'duration_minutes': 450,
      'wake_local_date': '2026-10-18',
      'created_at': '2026-10-18T01:00:00.000Z',
      'updated_at': '2026-10-18T01:00:00.000Z',
    };
  }

  test('SleepLog.fromMap parses full row', () {
    final log = SleepLog.fromMap(row());

    expect(log.id, 'log-1');
    expect(log.userId, 'user-1');
    expect(log.sleepStart, DateTime.utc(2026, 10, 17, 16));
    expect(log.wakeTime, DateTime.utc(2026, 10, 17, 23, 30));
    expect(log.durationMinutes, 450);
    expect(log.wakeLocalDate, DateTime(2026, 10, 18));
    expect(log.createdAt, DateTime.utc(2026, 10, 18, 1));
    expect(log.updatedAt, DateTime.utc(2026, 10, 18, 1));
  });

  test('SleepLog.fromMap defaults optional values to null', () {
    final log = SleepLog.fromMap({
      'id': 'log-2',
      'user_id': 'user-1',
      'sleep_start': '2026-10-17T16:00:00.000Z',
      'wake_time': '2026-10-17T23:00:00.000Z',
      'duration_minutes': 420,
    });

    expect(log.wakeLocalDate, isNull);
    expect(log.createdAt, isNull);
    expect(log.updatedAt, isNull);
  });

  test('SleepLog.toMap round trips through fromMap', () {
    final log = SleepLog.fromMap(row());
    final restored = SleepLog.fromMap(log.toMap());

    expect(restored.id, log.id);
    expect(restored.userId, log.userId);
    expect(restored.sleepStart, log.sleepStart);
    expect(restored.wakeTime, log.wakeTime);
    expect(restored.durationMinutes, log.durationMinutes);
    expect(restored.wakeLocalDate, log.wakeLocalDate);
  });

  test('SleepLog.copyWith updates only provided fields', () {
    final log = SleepLog.fromMap(row());
    final updated = log.copyWith(
      sleepStart: DateTime.utc(2026, 10, 17, 15),
      wakeTime: DateTime.utc(2026, 10, 17, 23),
      durationMinutes: 480,
    );

    expect(updated.id, log.id);
    expect(updated.userId, log.userId);
    expect(updated.sleepStart, DateTime.utc(2026, 10, 17, 15));
    expect(updated.wakeTime, DateTime.utc(2026, 10, 17, 23));
    expect(updated.durationMinutes, 480);
    expect(updated.wakeLocalDate, log.wakeLocalDate);
  });
}
