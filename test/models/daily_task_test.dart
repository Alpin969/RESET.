import 'package:flutter_test/flutter_test.dart';
import 'package:reset_app/models/daily_task.dart';
import 'package:reset_app/models/task_snapshot.dart';

void main() {
  group('DailyTask.fromMap', () {
    test('parses full task row', () {
      final task = DailyTask.fromMap({
        'id': 'task-1',
        'user_id': 'uid-1',
        'name': 'Minum air',
        'icon': 'water_drop',
        'position': 2,
        'is_active': true,
        'created_at': '2026-10-17T08:00:00.000Z',
        'updated_at': '2026-10-17T09:00:00.000Z',
        'deleted_at': null,
      });

      expect(task.id, 'task-1');
      expect(task.userId, 'uid-1');
      expect(task.name, 'Minum air');
      expect(task.icon, 'water_drop');
      expect(task.position, 2);
      expect(task.isActive, isTrue);
      expect(task.createdAt, isNotNull);
    });

    test('parses task with optional values missing', () {
      final task = DailyTask.fromMap({
        'id': 'task-2',
        'user_id': 'uid-1',
        'name': 'Olahraga',
        'position': null,
        'is_active': null,
      });

      expect(task.icon, isNull);
      expect(task.position, 0);
      expect(task.isActive, isTrue);
      expect(task.createdAt, isNull);
    });

    test('copyWith updates only provided fields', () {
      final task = DailyTask.fromMap({
        'id': 'task-3',
        'user_id': 'uid-1',
        'name': 'Lari',
        'position': 1,
        'is_active': true,
      });

      final updated = task.copyWith(name: 'Lari pagi');

      expect(updated.name, 'Lari pagi');
      expect(updated.id, 'task-3');
      expect(updated.position, 1);
      expect(updated.isActive, isTrue);
    });
  });

  group('TaskSnapshot.fromMap', () {
    test('parses snapshot row with yyyy-MM-dd date', () {
      final snapshot = TaskSnapshot.fromMap({
        'id': 'snap-1',
        'task_id': 'task-1',
        'name': 'Minum air',
        'icon': null,
        'position': 0,
        'is_active': true,
        'completed': true,
        'completed_at': '2026-10-17T02:15:00.000Z',
        'check_date': '2026-10-17',
        'created_at': '2026-10-17T00:00:00.000Z',
      });

      expect(snapshot.taskId, 'task-1');
      expect(snapshot.name, 'Minum air');
      expect(snapshot.isCompleted, isTrue);
      expect(snapshot.completedAt, isNotNull);
      expect(snapshot.checkDate, DateTime(2026, 10, 17));
    });

    test('defaults completed to false when missing', () {
      final snapshot = TaskSnapshot.fromMap({
        'id': 'snap-2',
        'task_id': 'task-2',
        'name': 'Olahraga',
        'position': 1,
        'check_date': '2026-10-18',
      });

      expect(snapshot.isCompleted, isFalse);
      expect(snapshot.completedAt, isNull);
      expect(snapshot.checkDate, DateTime(2026, 10, 18));
    });
  });
}
