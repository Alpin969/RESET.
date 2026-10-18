import 'package:flutter_test/flutter_test.dart';
import 'package:reset_app/models/task_snapshot.dart';
import 'package:reset_app/utils/task_progress.dart';

void main() {
  TaskSnapshot snapshot({required bool completed}) {
    return TaskSnapshot(
      id: 'snap-1',
      taskId: 'task-1',
      name: 'Task',
      position: 0,
      isActive: true,
      isCompleted: completed,
      checkDate: DateTime(2026, 10, 17),
    );
  }

  group('TaskProgress.dateKey', () {
    test('formats year-month-day with padding', () {
      expect(TaskProgress.dateKey(DateTime(2026, 10, 17)), '2026-10-17');
      expect(TaskProgress.dateKey(DateTime(2026, 1, 5)), '2026-01-05');
      expect(TaskProgress.dateKey(DateTime(2026, 12, 31)), '2026-12-31');
    });

    test('ignores time component', () {
      expect(
        TaskProgress.dateKey(DateTime(2026, 10, 17, 23, 59, 59)),
        '2026-10-17',
      );
    });
  });

  group('TaskProgress.normalize', () {
    test('strips time to midnight', () {
      final normalized =
          TaskProgress.normalize(DateTime(2026, 10, 17, 13, 45, 30));
      expect(normalized, DateTime(2026, 10, 17));
      expect(normalized.hour, 0);
    });
  });

  group('TaskProgress.lastSevenDays', () {
    test('returns seven consecutive days ending on the given date', () {
      final days = TaskProgress.lastSevenDays(DateTime(2026, 10, 17, 22, 15));
      expect(days.length, 7);
      expect(days.first, DateTime(2026, 10, 11));
      expect(days.last, DateTime(2026, 10, 17));
      for (var i = 1; i < days.length; i++) {
        expect(
          days[i].difference(days[i - 1]).inDays,
          1,
        );
      }
    });

    test('crosses month boundary', () {
      final days = TaskProgress.lastSevenDays(DateTime(2026, 10, 2));
      expect(days.first, DateTime(2026, 9, 26));
      expect(days.last, DateTime(2026, 10, 2));
    });

    test('crosses year boundary', () {
      final days = TaskProgress.lastSevenDays(DateTime(2026, 1, 3));
      expect(days.first, DateTime(2025, 12, 28));
      expect(days.last, DateTime(2026, 1, 3));
    });
  });

  group('TaskProgress.compute', () {
    test('returns zero progress when total is zero', () {
      final progress = TaskProgress.compute(DateTime(2026, 10, 17), []);
      expect(progress.totalTasks, 0);
      expect(progress.completedTasks, 0);
      expect(progress.percentage, 0);
      expect(progress.allCompleted, isFalse);
    });

    test('computes 5 of 6 as 83.33 percent not all completed', () {
      final snapshots = [
        for (var i = 0; i < 6; i++) snapshot(completed: i < 5),
      ];
      final progress = TaskProgress.compute(DateTime(2026, 10, 17), snapshots);
      expect(progress.totalTasks, 6);
      expect(progress.completedTasks, 5);
      expect(progress.percentage, closeTo(83.33, 0.01));
      expect(progress.allCompleted, isFalse);
    });

    test('marks allCompleted only when every task is done', () {
      final snapshots = [for (var i = 0; i < 3; i++) snapshot(completed: true)];
      final progress = TaskProgress.compute(DateTime(2026, 10, 17), snapshots);
      expect(progress.completedTasks, 3);
      expect(progress.percentage, 100);
      expect(progress.allCompleted, isTrue);
    });
  });
}
