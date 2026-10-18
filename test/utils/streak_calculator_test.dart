import 'package:flutter_test/flutter_test.dart';
import 'package:reset_app/models/streak_info.dart';
import 'package:reset_app/utils/streak_calculator.dart';

void main() {
  StreakInfo run(List<DateTime> dates, DateTime today) {
    return StreakCalculator.compute(activeDates: dates, today: today);
  }

  List<DateTime> days(int year, int month, List<int> days) {
    return [for (final day in days) DateTime(year, month, day)];
  }

  group('streak 0', () {
    test('belum pernah aktif', () {
      final info = run([], DateTime(2026, 10, 18));

      expect(info.currentStreak, 0);
      expect(info.lastActiveDate, isNull);
      expect(info.missedDays, 0);
      expect(info.isActiveToday, isFalse);
      expect(info.graceDaysRemaining, 2);
    });
  });

  group('hari aktif', () {
    test('satu hari aktif hari ini memberi streak 1', () {
      final info = run(days(2026, 10, [18]), DateTime(2026, 10, 18));

      expect(info.currentStreak, 1);
      expect(info.lastActiveDate, DateTime(2026, 10, 18));
      expect(info.isActiveToday, isTrue);
      expect(info.missedDays, 0);
      expect(info.graceDaysRemaining, 2);
    });

    test('banyak task pada hari yang sama tetap satu hari aktif', () {
      final info = run(
        [
          DateTime(2026, 10, 18),
          DateTime(2026, 10, 18),
          DateTime(2026, 10, 18),
        ],
        DateTime(2026, 10, 18),
      );

      expect(info.currentStreak, 1);
    });

    test('lima hari aktif berurutan memberi streak 5', () {
      final info = run(
        days(2026, 10, [14, 15, 16, 17, 18]),
        DateTime(2026, 10, 18),
      );

      expect(info.currentStreak, 5);
      expect(info.isActiveToday, isTrue);
    });

    test('tanggal setelah hari ini diabaikan', () {
      final info = run(
        days(2026, 10, [17, 18, 19, 20]),
        DateTime(2026, 10, 18),
      );

      expect(info.currentStreak, 2);
      expect(info.lastActiveDate, DateTime(2026, 10, 18));
    });
  });

  group('toleransi 1-2 hari tidak aktif', () {
    test('streak dipertahankan saat belum aktif hari ini (kemarin aktif)', () {
      final info = run(days(2026, 10, [16, 17]), DateTime(2026, 10, 18));

      expect(info.currentStreak, 2);
      expect(info.isActiveToday, isFalse);
      expect(info.missedDays, 0);
      expect(info.graceDaysRemaining, 2);
    });

    test('terlewat 1 hari, streak dipertahankan dan grace tersisa 1', () {
      final info = run(days(2026, 10, [16, 17]), DateTime(2026, 10, 19));

      expect(info.currentStreak, 2);
      expect(info.missedDays, 1);
      expect(info.graceDaysRemaining, 1);
      expect(info.isActiveToday, isFalse);
    });

    test('terlewat 2 hari, streak masih dipertahankan dengan grace 0', () {
      final info = run(days(2026, 10, [16, 17]), DateTime(2026, 10, 20));

      expect(info.currentStreak, 2);
      expect(info.missedDays, 2);
      expect(info.graceDaysRemaining, 0);
    });

    test('kembali aktif setelah terlewat 1 hari, streak bertambah', () {
      final info = run(days(2026, 10, [17, 18, 20]), DateTime(2026, 10, 20));

      expect(info.currentStreak, 3);
      expect(info.isActiveToday, isTrue);
    });

    test('kembali aktif setelah terlewat 2 hari, streak masih lanjut', () {
      final info = run(days(2026, 10, [17, 18, 21]), DateTime(2026, 10, 21));

      expect(info.currentStreak, 3);
      expect(info.isActiveToday, isTrue);
    });
  });

  group('putus setelah 3 hari tidak aktif', () {
    test('streak menjadi 0 setelah 3 hari tidak aktif', () {
      final info = run(days(2026, 10, [16, 17]), DateTime(2026, 10, 21));

      expect(info.currentStreak, 0);
      expect(info.lastActiveDate, DateTime(2026, 10, 17));
      expect(info.missedDays, 3);
      expect(info.graceDaysRemaining, 0);
      expect(info.isActiveToday, isFalse);
    });

    test('kembali aktif setelah putus dimulai dari 1', () {
      final info = run(days(2026, 10, [17, 21]), DateTime(2026, 10, 21));

      expect(info.currentStreak, 1);
      expect(info.isActiveToday, isTrue);
    });

    test('rentang lama sebelum putus tidak dihitung lagi', () {
      final info = run(
        days(2026, 10, [1, 2, 3, 20, 21]),
        DateTime(2026, 10, 21),
      );

      expect(info.currentStreak, 2);
    });
  });

  group('perubahan checklist', () {
    test('membatalkan centang hari terakhir menurunkan streak', () {
      final full = run(
        days(2026, 10, [14, 15, 16, 17, 18]),
        DateTime(2026, 10, 18),
      );
      final unchecked = run(
        days(2026, 10, [14, 15, 16, 17]),
        DateTime(2026, 10, 18),
      );

      expect(full.currentStreak, 5);
      expect(unchecked.currentStreak, 4);
      expect(unchecked.lastActiveDate, DateTime(2026, 10, 17));
      expect(unchecked.isActiveToday, isFalse);
      expect(unchecked.missedDays, 0);
    });

    test('membatalkan semua centang hari ini kembali ke streak tersimpan', () {
      final info = run(days(2026, 10, [15, 16, 17]), DateTime(2026, 10, 18));

      expect(info.currentStreak, 3);
      expect(info.isActiveToday, isFalse);
    });

    test('kosongkan seluruh checklist menghasilkan streak 0', () {
      final info = run([], DateTime(2026, 10, 18));

      expect(info.currentStreak, 0);
    });
  });

  group('pergantian timezone', () {
    final dates = days(2026, 10, [17]);

    test('hari aktif di zona lama masih hari yang sama', () {
      final info = run(dates, DateTime(2026, 10, 17));
      expect(info.currentStreak, 1);
      expect(info.isActiveToday, isTrue);
    });

    test('bergeser keesokan hari masih dalam grace', () {
      final info = run(dates, DateTime(2026, 10, 18));
      expect(info.currentStreak, 1);
      expect(info.isActiveToday, isFalse);
      expect(info.missedDays, 0);
    });

    test('bergeser tiga hari ke depan memutus streak', () {
      final info = run(dates, DateTime(2026, 10, 21));
      expect(info.currentStreak, 0);
      expect(info.missedDays, 3);
    });

    test('zona yang mundur mengabaikan tanggal aktif di masa depan', () {
      final info = run(dates, DateTime(2026, 10, 16));
      expect(info.currentStreak, 0);
      expect(info.lastActiveDate, isNull);
      expect(info.isActiveToday, isFalse);
    });
  });

  group('lintas bulan dan tahun', () {
    test('streak melewati akhir bulan', () {
      final info = run(
        [DateTime(2026, 9, 28), DateTime(2026, 9, 29), DateTime(2026, 9, 30), DateTime(2026, 10, 1)],
        DateTime(2026, 10, 1),
      );

      expect(info.currentStreak, 4);
    });

    test('streak melewati pergantian tahun', () {
      final info = run(
        [DateTime(2025, 12, 30), DateTime(2025, 12, 31), DateTime(2026, 1, 1)],
        DateTime(2026, 1, 1),
      );

      expect(info.currentStreak, 3);
    });
  });
}
