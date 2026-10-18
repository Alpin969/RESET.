import 'package:flutter_test/flutter_test.dart';
import 'package:reset_app/models/task_reminder.dart';

void main() {
  group('TaskReminder.fromMap', () {
    test('parses full reminder row', () {
      final reminder = TaskReminder.fromMap({
        'id': 'rem-1',
        'user_id': 'uid-1',
        'task_id': 'task-1',
        'task_name': 'Minum air',
        'task_is_active': true,
        'task_deleted': false,
        'time_of_day': '08:30:00',
        'frequency': 'specific_days',
        'days_of_week': [1, 3, 5],
        'is_enabled': true,
        'created_at': '2026-10-17T08:00:00.000Z',
        'updated_at': '2026-10-17T09:00:00.000Z',
      });

      expect(reminder.id, 'rem-1');
      expect(reminder.userId, 'uid-1');
      expect(reminder.taskId, 'task-1');
      expect(reminder.taskName, 'Minum air');
      expect(reminder.taskIsActive, isTrue);
      expect(reminder.taskDeleted, isFalse);
      expect(reminder.timeOfDay, '08:30');
      expect(reminder.frequency, 'specific_days');
      expect(reminder.daysOfWeek, [1, 3, 5]);
      expect(reminder.isEnabled, isTrue);
      expect(reminder.createdAt, isNotNull);
      expect(reminder.updatedAt, isNotNull);
    });

    test('parses reminder with optional values missing', () {
      final reminder = TaskReminder.fromMap({
        'id': 'rem-2',
        'user_id': 'uid-1',
        'task_id': 'task-2',
        'time_of_day': '21:05',
      });

      expect(reminder.taskName, isNull);
      expect(reminder.taskIsActive, isTrue);
      expect(reminder.taskDeleted, isFalse);
      expect(reminder.timeOfDay, '21:05');
      expect(reminder.frequency, TaskReminder.frequencyDaily);
      expect(reminder.daysOfWeek, isEmpty);
      expect(reminder.isEnabled, isTrue);
      expect(reminder.createdAt, isNull);
    });

    test('normalizeTime pads single digits and rejects invalid input', () {
      expect(TaskReminder.normalizeTime('07:05:00'), '07:05');
      expect(TaskReminder.normalizeTime('23:59:59'), '23:59');
      expect(TaskReminder.normalizeTime('9:5'), '09:05');
      expect(TaskReminder.normalizeTime('24:00'), '');
      expect(TaskReminder.normalizeTime(''), '');
    });

    test('copyWith updates only provided fields', () {
      final reminder = TaskReminder.fromMap({
        'id': 'rem-3',
        'user_id': 'uid-1',
        'task_id': 'task-3',
        'time_of_day': '08:00',
        'frequency': 'daily',
        'is_enabled': true,
      });

      final updated = reminder.copyWith(
        timeOfDay: '19:45',
        isEnabled: false,
      );

      expect(updated.id, 'rem-3');
      expect(updated.taskId, 'task-3');
      expect(updated.timeOfDay, '19:45');
      expect(updated.isEnabled, isFalse);
      expect(updated.frequency, 'daily');
    });

    test('toMap round trips core fields', () {
      final reminder = TaskReminder.fromMap({
        'id': 'rem-4',
        'user_id': 'uid-1',
        'task_id': 'task-4',
        'time_of_day': '06:15:00',
        'frequency': 'specific_days',
        'days_of_week': [0, 6],
        'is_enabled': false,
      });

      final map = reminder.toMap();
      final parsed = TaskReminder.fromMap(map);

      expect(parsed.id, reminder.id);
      expect(parsed.timeOfDay, '06:15');
      expect(parsed.frequency, 'specific_days');
      expect(parsed.daysOfWeek, [0, 6]);
      expect(parsed.isEnabled, isFalse);
    });
  });
}
