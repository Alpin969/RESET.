import 'package:flutter_test/flutter_test.dart';
import 'package:reset_app/models/sleep_log.dart';
import 'package:reset_app/utils/sleep_calculator.dart';

void main() {
  group('durasi tidur', () {
    test('melewati tengah malam 23.00 ke 07.00 sama dengan 8 jam', () {
      final minutes = SleepCalculator.durationMinutes(
        DateTime(2026, 10, 17, 23),
        DateTime(2026, 10, 18, 7),
      );

      expect(minutes, 480);
    });

    test('tanggal yang sama 01.00 ke 09.00 sama dengan 8 jam', () {
      final minutes = SleepCalculator.durationMinutes(
        DateTime(2026, 10, 18, 1),
        DateTime(2026, 10, 18, 9),
      );

      expect(minutes, 480);
    });

    test('durasi jam dan menit dihitung presisi', () {
      final minutes = SleepCalculator.durationMinutes(
        DateTime(2026, 10, 17, 22, 45),
        DateTime(2026, 10, 18, 6, 15),
      );

      expect(minutes, 450);
    });

    test('durasi kurang dari satu jam dihitung dalam menit', () {
      final minutes = SleepCalculator.durationMinutes(
        DateTime(2026, 10, 18, 1, 0),
        DateTime(2026, 10, 18, 1, 45),
      );

      expect(minutes, 45);
    });

    test('timestamp lintas zona tetap dihitung dari instan yang sama', () {
      final minutes = SleepCalculator.durationMinutes(
        DateTime.utc(2026, 10, 17, 16),
        DateTime.utc(2026, 10, 18, 0),
      );

      expect(minutes, 480);
    });
  });

  group('validasi waktu tidur', () {
    test('waktu wajib diisi', () {
      expect(
        SleepCalculator.validate(null, DateTime(2026, 10, 18, 7)),
        'Waktu tidur dan bangun wajib diisi.',
      );
      expect(
        SleepCalculator.validate(DateTime(2026, 10, 17, 23), null),
        'Waktu tidur dan bangun wajib diisi.',
      );
    });

    test('waktu bangun sebelum waktu tidur ditolak', () {
      expect(
        SleepCalculator.validate(
          DateTime(2026, 10, 18, 7),
          DateTime(2026, 10, 17, 23),
        ),
        'Waktu bangun harus setelah waktu mulai tidur.',
      );
    });

    test('waktu bangun sama dengan waktu tidur ditolak', () {
      expect(
        SleepCalculator.validate(
          DateTime(2026, 10, 17, 23),
          DateTime(2026, 10, 17, 23),
        ),
        'Waktu bangun harus setelah waktu mulai tidur.',
      );
    });

    test('durasi kurang dari satu menit ditolak', () {
      expect(
        SleepCalculator.validate(
          DateTime(2026, 10, 17, 23),
          DateTime(2026, 10, 17, 23, 0, 30),
        ),
        'Durasi tidur minimal 1 menit.',
      );
    });

    test('durasi tepat satu menit diterima', () {
      expect(
        SleepCalculator.validate(
          DateTime(2026, 10, 17, 23),
          DateTime(2026, 10, 17, 23, 1),
        ),
        isNull,
      );
    });

    test('durasi tepat 24 jam diterima', () {
      expect(
        SleepCalculator.validate(
          DateTime(2026, 10, 17, 22),
          DateTime(2026, 10, 18, 22),
        ),
        isNull,
      );
    });

    test('durasi lebih dari 24 jam ditolak', () {
      expect(
        SleepCalculator.validate(
          DateTime(2026, 10, 17, 22),
          DateTime(2026, 10, 18, 22, 1),
        ),
        'Durasi tidur maksimal 24 jam.',
      );
    });

    test('tidur normal diterima', () {
      expect(
        SleepCalculator.validate(
          DateTime(2026, 10, 17, 23),
          DateTime(2026, 10, 18, 7),
        ),
        isNull,
      );
    });
  });

  group('deteksi sesi tumpang tindih', () {
    final a = DateTime(2026, 10, 17, 22);
    final aWake = DateTime(2026, 10, 18, 6);

    test('sesi identik dianggap tumpang tindih', () {
      expect(
        SleepCalculator.overlaps(a, aWake, a, aWake),
        isTrue,
      );
    });

    test('sesi yang beririsan sebagian dianggap tumpang tindih', () {
      expect(
        SleepCalculator.overlaps(
          a,
          aWake,
          DateTime(2026, 10, 18, 5),
          DateTime(2026, 10, 18, 9),
        ),
        isTrue,
      );
    });

    test('sesi yang saling menutupi dianggap tumpang tindih', () {
      expect(
        SleepCalculator.overlaps(
          DateTime(2026, 10, 18, 1),
          DateTime(2026, 10, 18, 9),
          DateTime(2026, 10, 18, 2),
          DateTime(2026, 10, 18, 8),
        ),
        isTrue,
      );
    });

    test('sesi berdempetan tepat di batas tidak dianggap tumpang tindih', () {
      expect(
        SleepCalculator.overlaps(
          a,
          aWake,
          aWake,
          DateTime(2026, 10, 18, 14),
        ),
        isFalse,
      );
    });

    test('sesi yang berjauhan tidak dianggap tumpang tindih', () {
      expect(
        SleepCalculator.overlaps(
          a,
          aWake,
          DateTime(2026, 10, 18, 22),
          DateTime(2026, 10, 19, 6),
        ),
        isFalse,
      );
    });
  });

  group('rekomendasi durasi per kelompok usia', () {
    test('kelompok usia 13-17 direkomendasikan 480-600 menit', () {
      expect(SleepCalculator.recommendedRange('13-17'), [480, 600]);
    });

    test('kelompok usia 18+ direkomendasikan 420-540 menit', () {
      expect(SleepCalculator.recommendedRange('18+'), [420, 540]);
    });

    test('kelompok usia belum dipilih memberi status khusus', () {
      expect(
        SleepCalculator.statusFor(480, null),
        SleepCalculator.statusAgeGroupRequired,
      );
      expect(
        SleepCalculator.statusFor(480, 'unknown'),
        SleepCalculator.statusAgeGroupRequired,
      );
    });

    test('status di bawah, sesuai, dan di atas untuk 13-17', () {
      expect(SleepCalculator.statusFor(479, '13-17'), SleepCalculator.statusBelow);
      expect(SleepCalculator.statusFor(480, '13-17'), SleepCalculator.statusWithin);
      expect(SleepCalculator.statusFor(600, '13-17'), SleepCalculator.statusWithin);
      expect(SleepCalculator.statusFor(601, '13-17'), SleepCalculator.statusAbove);
    });

    test('status di bawah, sesuai, dan di atas untuk 18+', () {
      expect(SleepCalculator.statusFor(419, '18+'), SleepCalculator.statusBelow);
      expect(SleepCalculator.statusFor(420, '18+'), SleepCalculator.statusWithin);
      expect(SleepCalculator.statusFor(540, '18+'), SleepCalculator.statusWithin);
      expect(SleepCalculator.statusFor(541, '18+'), SleepCalculator.statusAbove);
    });
  });

  group('statistik harian', () {
    SleepLog log({
      required DateTime sleepStart,
      required DateTime wakeTime,
      required int durationMinutes,
      required DateTime wakeLocalDate,
    }) {
      return SleepLog(
        id: 'id-$sleepStart',
        userId: 'user-1',
        sleepStart: sleepStart,
        wakeTime: wakeTime,
        durationMinutes: durationMinutes,
        wakeLocalDate: wakeLocalDate,
      );
    }

    test('tanpa catatan semua hari diisi nol', () {
      final stats = SleepCalculator.computeDaily(
        logs: [],
        firstDay: DateTime(2026, 10, 12),
        lastDay: DateTime(2026, 10, 18),
        ageGroup: '18+',
      );

      expect(stats.totalCount, 0);
      expect(stats.averageMinutes, 0);
      expect(stats.belowNights, 0);
      expect(stats.withinNights, 0);
      expect(stats.aboveNights, 0);
      expect(stats.daily.length, 7);
      expect(stats.daily.every((day) => day.logCount == 0), isTrue);
      expect(stats.daily.every((day) => day.totalMinutes == 0), isTrue);
    });

    test('sesi dikelompokkan menurut tanggal bangun lokal', () {
      final stats = SleepCalculator.computeDaily(
        logs: [
          log(
            sleepStart: DateTime(2026, 10, 17, 23),
            wakeTime: DateTime(2026, 10, 18, 6),
            durationMinutes: 360,
            wakeLocalDate: DateTime(2026, 10, 18),
          ),
        ],
        firstDay: DateTime(2026, 10, 12),
        lastDay: DateTime(2026, 10, 18),
      );

      final day = stats.daily.firstWhere((d) => d.date == DateTime(2026, 10, 18));
      final previous = stats.daily
          .firstWhere((d) => d.date == DateTime(2026, 10, 17));

      expect(day.logCount, 1);
      expect(day.totalMinutes, 360);
      expect(previous.logCount, 0);
    });

    test('rata-rata dan total dihitung dari seluruh catatan', () {
      final stats = SleepCalculator.computeDaily(
        logs: [
          log(
            sleepStart: DateTime(2026, 10, 16, 23),
            wakeTime: DateTime(2026, 10, 17, 7),
            durationMinutes: 480,
            wakeLocalDate: DateTime(2026, 10, 17),
          ),
          log(
            sleepStart: DateTime(2026, 10, 17, 22),
            wakeTime: DateTime(2026, 10, 18, 5),
            durationMinutes: 420,
            wakeLocalDate: DateTime(2026, 10, 18),
          ),
        ],
        firstDay: DateTime(2026, 10, 12),
        lastDay: DateTime(2026, 10, 18),
        ageGroup: '18+',
      );

      expect(stats.totalCount, 2);
      expect(stats.averageMinutes, 450);
      expect(stats.withinNights, 2);
      expect(stats.belowNights, 0);
      expect(stats.aboveNights, 0);
    });

    test('hitung malam di bawah dan di atas rekomendasi', () {
      final stats = SleepCalculator.computeDaily(
        logs: [
          log(
            sleepStart: DateTime(2026, 10, 16, 23),
            wakeTime: DateTime(2026, 10, 17, 5),
            durationMinutes: 360,
            wakeLocalDate: DateTime(2026, 10, 17),
          ),
          log(
            sleepStart: DateTime(2026, 10, 17, 21),
            wakeTime: DateTime(2026, 10, 18, 9),
            durationMinutes: 720,
            wakeLocalDate: DateTime(2026, 10, 18),
          ),
        ],
        firstDay: DateTime(2026, 10, 12),
        lastDay: DateTime(2026, 10, 18),
        ageGroup: '18+',
      );

      expect(stats.belowNights, 1);
      expect(stats.aboveNights, 1);
      expect(stats.withinNights, 0);
    });

    test('status kelompok usia null tidak dihitung', () {
      final stats = SleepCalculator.computeDaily(
        logs: [
          log(
            sleepStart: DateTime(2026, 10, 17, 23),
            wakeTime: DateTime(2026, 10, 18, 7),
            durationMinutes: 480,
            wakeLocalDate: DateTime(2026, 10, 18),
          ),
        ],
        firstDay: DateTime(2026, 10, 12),
        lastDay: DateTime(2026, 10, 18),
      );

      expect(stats.belowNights, isNull);
      expect(stats.withinNights, isNull);
      expect(stats.aboveNights, isNull);
    });

    test('kelompok usia 13-17 memakai rentang 480-600', () {
      final stats = SleepCalculator.computeDaily(
        logs: [
          log(
            sleepStart: DateTime(2026, 10, 16, 22),
            wakeTime: DateTime(2026, 10, 17, 6, 30),
            durationMinutes: 510,
            wakeLocalDate: DateTime(2026, 10, 17),
          ),
          log(
            sleepStart: DateTime(2026, 10, 17, 23),
            wakeTime: DateTime(2026, 10, 18, 6),
            durationMinutes: 420,
            wakeLocalDate: DateTime(2026, 10, 18),
          ),
        ],
        firstDay: DateTime(2026, 10, 12),
        lastDay: DateTime(2026, 10, 18),
        ageGroup: '13-17',
      );

      expect(stats.withinNights, 1);
      expect(stats.belowNights, 1);
    });

    test('rentang tanggal berbeda zona memakai tanggal bangun lokal', () {
      final stats = SleepCalculator.computeDaily(
        logs: [
          log(
            sleepStart: DateTime.utc(2026, 10, 18, 16),
            wakeTime: DateTime.utc(2026, 10, 18, 23, 30),
            durationMinutes: 390,
            wakeLocalDate: DateTime(2026, 10, 19),
          ),
        ],
        firstDay: DateTime(2026, 10, 13),
        lastDay: DateTime(2026, 10, 19),
      );

      final nineteenth =
          stats.daily.firstWhere((d) => d.date == DateTime(2026, 10, 19));
      final eighteenth =
          stats.daily.firstWhere((d) => d.date == DateTime(2026, 10, 18));

      expect(nineteenth.logCount, 1);
      expect(eighteenth.logCount, 0);
    });
  });

  group('statistik bulanan', () {
    SleepLog log({
      required int year,
      required int month,
      required int day,
      required int durationMinutes,
    }) {
      return SleepLog(
        id: 'id-$year-$month-$day',
        userId: 'user-1',
        sleepStart: DateTime(year, month, day, 22),
        wakeTime: DateTime(year, month, day + 1, 6),
        durationMinutes: durationMinutes,
        wakeLocalDate: DateTime(year, month, day + 1),
      );
    }

    test('tahun berisi 12 bulan yang diisi nol', () {
      final stats = SleepCalculator.computeMonthly(
        logs: [],
        year: 2026,
        ageGroup: '18+',
      );

      expect(stats.monthly.length, 12);
      expect(stats.monthly.every((m) => m.logCount == 0), isTrue);
      expect(stats.totalCount, 0);
    });

    test('catatan dikelompokkan per bulan tanggal bangun lokal', () {
      final stats = SleepCalculator.computeMonthly(
        logs: [
          log(year: 2026, month: 10, day: 16, durationMinutes: 480),
          log(year: 2026, month: 10, day: 17, durationMinutes: 420),
          log(year: 2026, month: 9, day: 28, durationMinutes: 500),
        ],
        year: 2026,
      );

      final october = stats.monthly.firstWhere((m) => m.month == 10);
      final september = stats.monthly.firstWhere((m) => m.month == 9);

      expect(october.logCount, 2);
      expect(october.totalMinutes, 900);
      expect(october.averageMinutes, 450);
      expect(september.logCount, 1);
      expect(stats.totalCount, 3);
      expect(stats.averageMinutes, 467);
    });

    test('lintas akhir tahun hanya menghitung tahun yang diminta', () {
      final stats = SleepCalculator.computeMonthly(
        logs: [
          SleepLog(
            id: 'dec',
            userId: 'user-1',
            sleepStart: DateTime(2025, 12, 31, 23),
            wakeTime: DateTime(2026, 1, 1, 7),
            durationMinutes: 480,
            wakeLocalDate: DateTime(2026, 1, 1),
          ),
          SleepLog(
            id: 'old',
            userId: 'user-1',
            sleepStart: DateTime(2025, 12, 29, 23),
            wakeTime: DateTime(2025, 12, 30, 7),
            durationMinutes: 480,
            wakeLocalDate: DateTime(2025, 12, 30),
          ),
        ],
        year: 2026,
      );

      final january = stats.monthly.firstWhere((m) => m.month == 1);
      final december = stats.monthly.firstWhere((m) => m.month == 12);

      expect(stats.totalCount, 1);
      expect(january.logCount, 1);
      expect(december.logCount, 0);
    });

    test('lintas akhir bulan sesi bangun 1 Februari masuk Februari', () {
      final stats = SleepCalculator.computeMonthly(
        logs: [
          SleepLog(
            id: 'jan-feb',
            userId: 'user-1',
            sleepStart: DateTime(2026, 1, 31, 23),
            wakeTime: DateTime(2026, 2, 1, 7),
            durationMinutes: 480,
            wakeLocalDate: DateTime(2026, 2, 1),
          ),
        ],
        year: 2026,
      );

      final january = stats.monthly.firstWhere((m) => m.month == 1);
      final february = stats.monthly.firstWhere((m) => m.month == 2);

      expect(january.logCount, 0);
      expect(february.logCount, 1);
    });
  });

  group('status kelompok usia pada statistik tahunan', () {
    test('tanpa kelompok usia hitung malam tidak tersedia', () {
      final stats = SleepCalculator.computeMonthly(logs: [], year: 2026);

      expect(stats.belowNights, isNull);
      expect(stats.withinNights, isNull);
      expect(stats.aboveNights, isNull);
    });
  });
}
