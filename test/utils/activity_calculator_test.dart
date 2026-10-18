import 'package:flutter_test/flutter_test.dart';
import 'package:reset_app/models/activity_summary.dart';
import 'package:reset_app/models/task_snapshot.dart';
import 'package:reset_app/utils/activity_calculator.dart';
import 'package:reset_app/utils/task_progress.dart';

TaskSnapshot snap({
  required String taskId,
  required String name,
  required DateTime date,
  bool completed = false,
  int position = 0,
}) {
  return TaskSnapshot(
    id: '$taskId-${TaskProgress.dateKey(date)}',
    taskId: taskId,
    name: name,
    position: position,
    isActive: true,
    isCompleted: completed,
    checkDate: TaskProgress.normalize(date),
  );
}

void main() {
  group('ActivityCalculator.buildDays', () {
    test('hari tanpa task menghasilkan 0/0 dengan persentase 0', () {
      final days = ActivityCalculator.buildDays(
        firstDay: DateTime(2026, 10, 17),
        lastDay: DateTime(2026, 10, 17),
        snapshots: const [],
      );

      expect(days, hasLength(1));
      expect(days.first.totalCount, 0);
      expect(days.first.completedCount, 0);
      expect(days.first.percentage, 0.0);
      expect(days.first.allCompleted, false);
    });

    test('hari dengan 5/6 task', () {
      final date = DateTime(2026, 10, 17);
      final snapshots = List.generate(
        6,
        (index) => snap(
          taskId: 't$index',
          name: 'Task $index',
          date: date,
          completed: index < 5,
          position: index,
        ),
      );

      final days = ActivityCalculator.buildDays(
        firstDay: date,
        lastDay: date,
        snapshots: snapshots,
      );

      expect(days.first.totalCount, 6);
      expect(days.first.completedCount, 5);
      expect(days.first.percentage, closeTo(83.333, 0.01));
      expect(days.first.allCompleted, false);
    });

    test('hari dengan 6/6 task dihitung semua selesai', () {
      final date = DateTime(2026, 10, 17);
      final snapshots = List.generate(
        6,
        (index) => snap(
          taskId: 't$index',
          name: 'Task $index',
          date: date,
          completed: true,
          position: index,
        ),
      );

      final days = ActivityCalculator.buildDays(
        firstDay: date,
        lastDay: date,
        snapshots: snapshots,
      );

      expect(days.first.percentage, 100.0);
      expect(days.first.allCompleted, true);
    });

    test('persentase 1/3 dan 3/4', () {
      final one = DateTime(2026, 10, 1);
      final three = DateTime(2026, 10, 2);
      final snapshots = [
        snap(taskId: 'a', name: 'A', date: one, completed: true),
        snap(taskId: 'b', name: 'B', date: one, position: 1),
        snap(taskId: 'c', name: 'C', date: one, position: 2),
        snap(taskId: 'd', name: 'D', date: three, completed: true),
        snap(taskId: 'e', name: 'E', date: three, completed: true, position: 1),
        snap(taskId: 'f', name: 'F', date: three, completed: true, position: 2),
        snap(taskId: 'g', name: 'G', date: three, position: 3),
      ];

      final days = ActivityCalculator.buildDays(
        firstDay: one,
        lastDay: three,
        snapshots: snapshots,
      );

      expect(days[0].percentage, closeTo(33.333, 0.01));
      expect(days[1].percentage, 75.0);
    });

    test('minggu dengan hari kosong tetap tujuh titik data', () {
      final snapshots = [
        snap(
          taskId: 'a',
          name: 'A',
          date: DateTime(2026, 10, 14),
          completed: true,
        ),
      ];

      final days = ActivityCalculator.buildDays(
        firstDay: DateTime(2026, 10, 11),
        lastDay: DateTime(2026, 10, 17),
        snapshots: snapshots,
      );

      expect(days, hasLength(7));
      expect(days.where((day) => day.totalCount == 0), hasLength(6));
      expect(days[3].completedCount, 1);
      expect(days[3].totalCount, 1);
    });

    test('minggu lintas bulan menghasilkan tanggal berurutan', () {
      final days = ActivityCalculator.buildDays(
        firstDay: DateTime(2026, 1, 29),
        lastDay: DateTime(2026, 2, 4),
        snapshots: const [],
      );

      expect(days, hasLength(7));
      expect(days.first.date, DateTime(2026, 1, 29));
      expect(days.last.date, DateTime(2026, 2, 4));
      expect(days[2].date, DateTime(2026, 1, 31));
      expect(days[3].date, DateTime(2026, 2, 1));
      for (var i = 1; i < days.length; i++) {
        final previous = days[i - 1].date;
        final current = days[i].date;
        expect(
          DateTime(current.year, current.month, current.day - 1),
          previous,
        );
      }
    });

    test('periode lintas tahun tetap berurutan', () {
      final days = ActivityCalculator.buildDays(
        firstDay: DateTime(2025, 12, 30),
        lastDay: DateTime(2026, 1, 2),
        snapshots: const [],
      );

      expect(days, hasLength(4));
      expect(days.first.date, DateTime(2025, 12, 30));
      expect(days[2].date, DateTime(2026, 1, 1));
      expect(days.last.date, DateTime(2026, 1, 2));
    });

    test('rentang terbalik menghasilkan daftar kosong', () {
      final days = ActivityCalculator.buildDays(
        firstDay: DateTime(2026, 10, 17),
        lastDay: DateTime(2026, 10, 10),
        snapshots: const [],
      );

      expect(days, isEmpty);
    });

    test('snapshot historis memakai data tersimpan bukan daftar aktif', () {
      final date = DateTime(2026, 10, 10);
      final historical = [
        snap(taskId: 'old', name: 'Nama Lama', date: date, completed: true),
      ];

      final days = ActivityCalculator.buildDays(
        firstDay: date,
        lastDay: date,
        snapshots: historical,
      );

      expect(days.first.totalCount, 1);
      expect(days.first.completedCount, 1);
      expect(historical.first.name, 'Nama Lama');
    });

    test('duplikat task pada tanggal yang sama dihitung sekali', () {
      final date = DateTime(2026, 10, 10);
      final snapshots = [
        snap(taskId: 'a', name: 'A', date: date, completed: true),
        snap(taskId: 'a', name: 'A', date: date, completed: true),
        snap(taskId: 'b', name: 'B', date: date, position: 1),
      ];

      final days = ActivityCalculator.buildDays(
        firstDay: date,
        lastDay: date,
        snapshots: snapshots,
      );

      expect(days.first.totalCount, 2);
      expect(days.first.completedCount, 1);
    });

    test('detail task diurutkan berdasarkan position', () {
      final date = DateTime(2026, 10, 10);
      final snapshots = [
        snap(taskId: 'b', name: 'B', date: date, position: 1),
        snap(taskId: 'a', name: 'A', date: date, position: 0),
      ];

      final days = ActivityCalculator.buildDays(
        firstDay: date,
        lastDay: date,
        snapshots: snapshots,
        includeTaskDetails: true,
      );

      expect(days.first.tasks.map((task) => task.taskId), ['a', 'b']);
    });

    test('detail task tidak disertakan bila diminta ringan', () {
      final date = DateTime(2026, 10, 10);
      final snapshots = [
        snap(taskId: 'a', name: 'A', date: date),
      ];

      final days = ActivityCalculator.buildDays(
        firstDay: date,
        lastDay: date,
        snapshots: snapshots,
      );

      expect(days.first.tasks, isEmpty);
    });

    test('tanggal waktu dengan jam tetap dinormalisasi ke tanggal murni', () {
      final late = DateTime(2026, 10, 17, 23, 59, 59);
      final snapshots = [
        snap(taskId: 'a', name: 'A', date: late, completed: true),
      ];

      final days = ActivityCalculator.buildDays(
        firstDay: DateTime(2026, 10, 17, 6, 30),
        lastDay: DateTime(2026, 10, 17, 12, 0),
        snapshots: snapshots,
      );

      expect(days, hasLength(1));
      expect(days.first.completedCount, 1);
      expect(days.first.date, DateTime(2026, 10, 17));
    });

    test('konsisten dengan TaskProgress.compute', () {
      final date = DateTime(2026, 10, 15);
      final snapshots = [
        snap(taskId: 'a', name: 'A', date: date, completed: true),
        snap(taskId: 'b', name: 'B', date: date, position: 1),
        snap(taskId: 'c', name: 'C', date: date, completed: true, position: 2),
      ];

      final day = ActivityCalculator.buildDays(
        firstDay: date,
        lastDay: date,
        snapshots: snapshots,
      ).first;
      final progress = TaskProgress.compute(date, snapshots);

      expect(day.totalCount, progress.totalTasks);
      expect(day.completedCount, progress.completedTasks);
      expect(day.percentage, progress.percentage);
      expect(day.allCompleted, progress.allCompleted);
    });
  });

  group('ActivityCalculator.buildSummary', () {
    test('menghitung total, hari aktif, dan hari semua selesai', () {
      final first = DateTime(2026, 10, 1);
      final snapshots = [
        snap(
          taskId: 'a',
          name: 'A',
          date: DateTime(2026, 10, 1),
          completed: true,
        ),
        snap(
          taskId: 'b',
          name: 'B',
          date: DateTime(2026, 10, 2),
          completed: true,
        ),
        snap(
          taskId: 'c',
          name: 'C',
          date: DateTime(2026, 10, 2),
          position: 1,
        ),
        snap(
          taskId: 'd',
          name: 'D',
          date: DateTime(2026, 10, 3),
          completed: true,
        ),
        snap(
          taskId: 'e',
          name: 'E',
          date: DateTime(2026, 10, 3),
          completed: true,
          position: 1,
        ),
      ];

      final summary = ActivityCalculator.buildSummary(
        firstDay: first,
        lastDay: DateTime(2026, 10, 7),
        snapshots: snapshots,
      );

      expect(summary.totalAvailable, 5);
      expect(summary.totalCompleted, 4);
      expect(summary.percentage, 80.0);
      expect(summary.activeDays, 3);
      expect(summary.allCompletedDays, 2);
      expect(summary.days, hasLength(7));
    });

    test('semua hari 0/0 tidak menghitung pembagian dengan nol', () {
      final summary = ActivityCalculator.buildSummary(
        firstDay: DateTime(2026, 10, 1),
        lastDay: DateTime(2026, 10, 31),
        snapshots: const [],
      );

      expect(summary.percentage, 0.0);
      expect(summary.totalAvailable, 0);
      expect(summary.totalCompleted, 0);
      expect(summary.activeDays, 0);
      expect(summary.allCompletedDays, 0);
    });

    test('hari 0/0 bukan hari semua selesai', () {
      final summary = ActivityCalculator.buildSummary(
        firstDay: DateTime(2026, 10, 1),
        lastDay: DateTime(2026, 10, 2),
        snapshots: [
          snap(
            taskId: 'a',
            name: 'A',
            date: DateTime(2026, 10, 2),
            completed: true,
          ),
        ],
      );

      expect(summary.activeDays, 1);
      expect(summary.allCompletedDays, 1);
    });
  });

  group('ActivityCalculator.buildMonths', () {
    test('Februari 2025 memiliki 28 hari', () {
      expect(ActivityCalculator.daysInMonth(2025, 2), 28);

      final days = ActivityCalculator.buildDays(
        firstDay: DateTime(2025, 2, 1),
        lastDay: DateTime(2025, 2, 28),
        snapshots: const [],
      );

      expect(days, hasLength(28));
    });

    test('Februari 2024 kabisat memiliki 29 hari', () {
      expect(ActivityCalculator.daysInMonth(2024, 2), 29);

      final days = ActivityCalculator.buildDays(
        firstDay: DateTime(2024, 2, 1),
        lastDay: DateTime(2024, 2, 29),
        snapshots: const [],
      );

      expect(days, hasLength(29));
    });

    test('tahunan menghasilkan 12 bulan dengan agregasi benar', () {
      final days = ActivityCalculator.buildDays(
        firstDay: DateTime(2026, 1, 1),
        lastDay: DateTime(2026, 12, 31),
        snapshots: [
          snap(
            taskId: 'a',
            name: 'A',
            date: DateTime(2026, 1, 5),
            completed: true,
          ),
          snap(
            taskId: 'b',
            name: 'B',
            date: DateTime(2026, 2, 10),
            completed: true,
          ),
          snap(
            taskId: 'c',
            name: 'C',
            date: DateTime(2026, 2, 11),
          ),
          snap(
            taskId: 'd',
            name: 'D',
            date: DateTime(2026, 12, 31),
            completed: true,
          ),
        ],
      );
      final months = ActivityCalculator.buildMonths(year: 2026, days: days);

      expect(months, hasLength(12));
      expect(months[0].totalCount, 1);
      expect(months[0].completedCount, 1);
      expect(months[0].activeDays, 1);
      expect(months[0].allCompletedDays, 1);
      expect(months[1].totalCount, 2);
      expect(months[1].completedCount, 1);
      expect(months[1].percentage, 50.0);
      expect(months[1].activeDays, 1);
      expect(months[1].allCompletedDays, 1);
      expect(months[2].totalCount, 0);
      expect(months[2].percentage, 0.0);
      expect(months[11].completedCount, 1);
      expect(months[11].activeDays, 1);
    });

    test('pergantian tahun tidak mereset atau menduplikasi data', () {
      final days = ActivityCalculator.buildDays(
        firstDay: DateTime(2025, 12, 1),
        lastDay: DateTime(2026, 1, 31),
        snapshots: [
          snap(
            taskId: 'a',
            name: 'A',
            date: DateTime(2025, 12, 31),
            completed: true,
          ),
          snap(
            taskId: 'b',
            name: 'B',
            date: DateTime(2026, 1, 1),
            completed: true,
          ),
        ],
      );

      final months2025 =
          ActivityCalculator.buildMonths(year: 2025, days: days);
      final months2026 =
          ActivityCalculator.buildMonths(year: 2026, days: days);

      expect(months2025[11].completedCount, 1);
      expect(months2026[0].completedCount, 1);
      expect(
        months2025[11].completedCount + months2026[0].completedCount,
        2,
      );
    });

    test('aktif di zona waktu berbeda tidak mengubah tanggal tersimpan', () {
      final snapshots = [
        snap(
          taskId: 'a',
          name: 'A',
          date: DateTime(2026, 10, 17, 16, 0),
          completed: true,
        ),
      ];

      final jakarta = ActivityCalculator.buildSummary(
        firstDay: DateTime(2026, 10, 17, 7, 0),
        lastDay: DateTime(2026, 10, 17, 22, 0),
        snapshots: snapshots,
      );
      final utc = ActivityCalculator.buildSummary(
        firstDay: DateTime(2026, 10, 17, 0, 0),
        lastDay: DateTime(2026, 10, 17, 23, 59),
        snapshots: snapshots,
      );

      expect(jakarta.totalCompleted, utc.totalCompleted);
      expect(jakarta.totalAvailable, utc.totalAvailable);
      expect(jakarta.days.first.date, utc.days.first.date);
    });
  });

  group('ActivityCalculator.paginate', () {
    ActivitySummary summaryOf(int dayCount) {
      final days = ActivityCalculator.buildDays(
        firstDay: DateTime(2026, 1, 1),
        lastDay: DateTime(2026, 1, dayCount),
        snapshots: const [],
      );
      return ActivityCalculator.summaryFromDays(
        firstDay: DateTime(2026, 1, 1),
        lastDay: DateTime(2026, 1, dayCount),
        days: days,
      );
    }

    test('membatasi daftar hari tanpa mengubah total periode', () {
      final summary = summaryOf(40);
      final page = ActivityCalculator.paginate(summary, limit: 10, offset: 0);

      expect(page.days, hasLength(10));
      expect(page.totalAvailable, summary.totalAvailable);
      expect(page.totalCompleted, summary.totalCompleted);
      expect(page.activeDays, summary.activeDays);
      expect(page.allCompletedDays, summary.allCompletedDays);
    });

    test('offset melompati halaman sebelumnya', () {
      final summary = summaryOf(40);
      final page = ActivityCalculator.paginate(summary, limit: 10, offset: 30);

      expect(page.days, hasLength(10));
      expect(page.days.first.date, DateTime(2026, 1, 31));
      expect(page.days.last.date, DateTime(2026, 2, 9));
    });

    test('offset melewati akhir daftar aman', () {
      final summary = summaryOf(5);
      final page = ActivityCalculator.paginate(summary, limit: 10, offset: 100);

      expect(page.days, isEmpty);
      expect(page.totalAvailable, summary.totalAvailable);
    });
  });
}
