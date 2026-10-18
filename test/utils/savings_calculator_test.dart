import 'package:flutter_test/flutter_test.dart';
import 'package:reset_app/models/savings_transaction.dart';
import 'package:reset_app/utils/savings_calculator.dart';

void main() {
  SavingsTransaction tx({
    required String type,
    required int amount,
    required DateTime localDate,
    String? note,
  }) {
    return SavingsTransaction(
      id: 'id-$type-$amount-${localDate.toIso8601String()}',
      userId: 'user-1',
      transactionType: type,
      amount: amount,
      note: note,
      transactionDate: localDate,
      transactionLocalDate: localDate,
    );
  }

  group('saldo dari riwayat transaksi', () {
    test('pengguna baru tanpa transaksi berarti saldo Rp0', () {
      expect(SavingsCalculator.balanceOf([]), 0);
    });

    test('deposit Rp10.000 lalu Rp5.000 lalu withdrawal Rp3.000 menjadi Rp12.000', () {
      final transactions = [
        tx(
          type: SavingsTransaction.typeDeposit,
          amount: 10000,
          localDate: DateTime(2026, 10, 14),
        ),
        tx(
          type: SavingsTransaction.typeDeposit,
          amount: 5000,
          localDate: DateTime(2026, 10, 15),
        ),
        tx(
          type: SavingsTransaction.typeWithdrawal,
          amount: 3000,
          localDate: DateTime(2026, 10, 16),
        ),
      ];

      expect(SavingsCalculator.balanceOf(transactions), 12000);
    });

    test('dua deposit nominal sama tetap dihitung dua kali', () {
      final transactions = [
        tx(
          type: SavingsTransaction.typeDeposit,
          amount: 5000,
          localDate: DateTime(2026, 10, 14),
        ),
        tx(
          type: SavingsTransaction.typeDeposit,
          amount: 5000,
          localDate: DateTime(2026, 10, 15),
        ),
      ];

      expect(SavingsCalculator.balanceOf(transactions), 10000);
    });

    test('signedAmount deposit positif dan withdrawal negatif', () {
      final deposit = tx(
        type: SavingsTransaction.typeDeposit,
        amount: 7000,
        localDate: DateTime(2026, 10, 14),
      );
      final withdrawal = tx(
        type: SavingsTransaction.typeWithdrawal,
        amount: 2000,
        localDate: DateTime(2026, 10, 15),
      );

      expect(deposit.signedAmount, 7000);
      expect(withdrawal.signedAmount, -2000);
      expect(deposit.isDeposit, isTrue);
      expect(withdrawal.isWithdrawal, isTrue);
    });
  });

  group('validasi nominal', () {
    test('nominal wajib diisi', () {
      expect(
        SavingsCalculator.validateAmount(null),
        'Nominal wajib diisi.',
      );
    });

    test('nominal nol ditolak', () {
      expect(
        SavingsCalculator.validateAmount(0),
        'Nominal harus lebih besar dari nol.',
      );
    });

    test('nominal negatif ditolak', () {
      expect(
        SavingsCalculator.validateAmount(-5000),
        'Nominal harus lebih besar dari nol.',
      );
    });

    test('nominal melebihi batas maksimum ditolak', () {
      expect(
        SavingsCalculator.validateAmount(SavingsCalculator.maxAmount + 1),
        'Nominal maksimal Rp1.000.000.000.000.000.',
      );
    });

    test('nominal valid diterima', () {
      expect(SavingsCalculator.validateAmount(1), isNull);
      expect(SavingsCalculator.validateAmount(10000), isNull);
      expect(SavingsCalculator.validateAmount(SavingsCalculator.maxAmount), isNull);
    });
  });

  group('validasi catatan', () {
    test('catatan kosong menjadi null', () {
      expect(SavingsCalculator.cleanNote(null), isNull);
      expect(SavingsCalculator.cleanNote('   '), isNull);
      expect(SavingsCalculator.validateNote(null), isNull);
      expect(SavingsCalculator.validateNote('  '), isNull);
    });

    test('catatan dipotong dan valid', () {
      expect(SavingsCalculator.cleanNote('  nabung  '), 'nabung');
      expect(SavingsCalculator.validateNote('nabung'), isNull);
    });

    test('catatan melebihi 200 karakter ditolak', () {
      final longNote = 'a' * 201;
      expect(
        SavingsCalculator.validateNote(longNote),
        'Catatan maksimal 200 karakter.',
      );
    });
  });

  group('jenis transaksi', () {
    test('hanya deposit dan withdrawal yang sah', () {
      expect(SavingsCalculator.isValidType(SavingsTransaction.typeDeposit), isTrue);
      expect(SavingsCalculator.isValidType(SavingsTransaction.typeWithdrawal), isTrue);
      expect(SavingsCalculator.isValidType('transfer'), isFalse);
      expect(SavingsCalculator.isValidType(''), isFalse);
    });
  });

  group('statistik harian', () {
    test('hari tanpa transaksi tetap menampilkan saldo yang benar', () {
      final stats = SavingsCalculator.computeDaily(
        transactions: [
          tx(
            type: SavingsTransaction.typeDeposit,
            amount: 10000,
            localDate: DateTime(2026, 10, 14),
          ),
        ],
        firstDay: DateTime(2026, 10, 12),
        lastDay: DateTime(2026, 10, 18),
        openingBalance: 2000,
      );

      expect(stats.daily.length, 7);
      expect(stats.openingBalance, 2000);

      final day12 = stats.daily.first;
      expect(day12.depositTotal, 0);
      expect(day12.withdrawalTotal, 0);
      expect(day12.endBalance, 2000);

      final day14 = stats.daily[2];
      expect(day14.depositTotal, 10000);
      expect(day14.endBalance, 12000);

      final day15 = stats.daily[3];
      expect(day15.depositTotal, 0);
      expect(day15.endBalance, 12000);

      expect(stats.closingBalance, 12000);
      expect(stats.totalDeposits, 10000);
      expect(stats.totalWithdrawals, 0);
    });

    test('saldo awal periode berasal dari transaksi sebelumnya', () {
      final stats = SavingsCalculator.computeDaily(
        transactions: [
          tx(
            type: SavingsTransaction.typeDeposit,
            amount: 3000,
            localDate: DateTime(2026, 10, 15),
          ),
        ],
        firstDay: DateTime(2026, 10, 14),
        lastDay: DateTime(2026, 10, 15),
        openingBalance: 50000,
      );

      expect(stats.daily.first.endBalance, 50000);
      expect(stats.daily.last.endBalance, 53000);
      expect(stats.closingBalance, 53000);
    });

    test('deposit dan withdrawal dalam satu hari saling mengurangkan', () {
      final stats = SavingsCalculator.computeDaily(
        transactions: [
          tx(
            type: SavingsTransaction.typeDeposit,
            amount: 8000,
            localDate: DateTime(2026, 10, 15),
          ),
          tx(
            type: SavingsTransaction.typeWithdrawal,
            amount: 2500,
            localDate: DateTime(2026, 10, 15),
          ),
        ],
        firstDay: DateTime(2026, 10, 15),
        lastDay: DateTime(2026, 10, 15),
        openingBalance: 0,
      );

      final day = stats.daily.single;
      expect(day.depositTotal, 8000);
      expect(day.withdrawalTotal, 2500);
      expect(day.endBalance, 5500);
    });

    test('minggu melewati pergantian bulan', () {
      final stats = SavingsCalculator.computeDaily(
        transactions: [
          tx(
            type: SavingsTransaction.typeDeposit,
            amount: 1000,
            localDate: DateTime(2026, 9, 30),
          ),
          tx(
            type: SavingsTransaction.typeDeposit,
            amount: 2000,
            localDate: DateTime(2026, 10, 1),
          ),
        ],
        firstDay: DateTime(2026, 9, 28),
        lastDay: DateTime(2026, 10, 4),
        openingBalance: 0,
      );

      expect(stats.daily.length, 7);
      expect(stats.daily[2].depositTotal, 1000);
      expect(stats.daily[3].depositTotal, 2000);
      expect(stats.closingBalance, 3000);
    });

    test('transaksi di luar rentang tanggal tidak dihitung', () {
      final stats = SavingsCalculator.computeDaily(
        transactions: [
          tx(
            type: SavingsTransaction.typeDeposit,
            amount: 1000,
            localDate: DateTime(2026, 10, 10),
          ),
          tx(
            type: SavingsTransaction.typeDeposit,
            amount: 4000,
            localDate: DateTime(2026, 10, 15),
          ),
          tx(
            type: SavingsTransaction.typeDeposit,
            amount: 9000,
            localDate: DateTime(2026, 10, 25),
          ),
        ],
        firstDay: DateTime(2026, 10, 13),
        lastDay: DateTime(2026, 10, 18),
        openingBalance: 0,
      );

      expect(stats.totalDeposits, 4000);
      expect(stats.closingBalance, 4000);
    });

    test('kelompok tanggal memakai tanggal lokal transaksi', () {
      final utcLog = tx(
        type: SavingsTransaction.typeDeposit,
        amount: 1500,
        localDate: DateTime(2026, 10, 15),
      ).copyWith(
        transactionDate: DateTime.utc(2026, 10, 14, 17),
      );

      final stats = SavingsCalculator.computeDaily(
        transactions: [utcLog],
        firstDay: DateTime(2026, 10, 14),
        lastDay: DateTime(2026, 10, 15),
        openingBalance: 0,
      );

      expect(stats.daily.first.depositTotal, 0);
      expect(stats.daily.last.depositTotal, 1500);
    });
  });

  group('statistik tahunan', () {
    test('tahun berisi 12 bulan dengan saldo berjalan', () {
      final stats = SavingsCalculator.computeMonthly(
        transactions: [
          tx(
            type: SavingsTransaction.typeDeposit,
            amount: 100000,
            localDate: DateTime(2026, 1, 5),
          ),
          tx(
            type: SavingsTransaction.typeWithdrawal,
            amount: 40000,
            localDate: DateTime(2026, 6, 10),
          ),
          tx(
            type: SavingsTransaction.typeDeposit,
            amount: 25000,
            localDate: DateTime(2026, 12, 20),
          ),
        ],
        year: 2026,
        openingBalance: 10000,
      );

      expect(stats.monthly.length, 12);

      final january = stats.monthly.first;
      expect(january.depositTotal, 100000);
      expect(january.endBalance, 110000);

      final february = stats.monthly[1];
      expect(february.depositTotal, 0);
      expect(february.endBalance, 110000);

      final june = stats.monthly[5];
      expect(june.withdrawalTotal, 40000);
      expect(june.endBalance, 70000);

      final december = stats.monthly.last;
      expect(december.depositTotal, 25000);
      expect(december.endBalance, 95000);

      expect(stats.closingBalance, 95000);
      expect(stats.totalDeposits, 125000);
      expect(stats.totalWithdrawals, 40000);
    });

    test('transaksi tahun lain diabaikan', () {
      final stats = SavingsCalculator.computeMonthly(
        transactions: [
          tx(
            type: SavingsTransaction.typeDeposit,
            amount: 50000,
            localDate: DateTime(2025, 12, 31),
          ),
          tx(
            type: SavingsTransaction.typeDeposit,
            amount: 7000,
            localDate: DateTime(2026, 1, 1),
          ),
        ],
        year: 2026,
        openingBalance: 50000,
      );

      expect(stats.totalDeposits, 7000);
      expect(stats.openingBalance, 50000);
      expect(stats.monthly.first.endBalance, 57000);
      expect(stats.monthly[1].endBalance, 57000);
    });

    test('pergantian tahun saldo berjalan tidak reset', () {
      final stats = SavingsCalculator.computeMonthly(
        transactions: [
          tx(
            type: SavingsTransaction.typeDeposit,
            amount: 90000,
            localDate: DateTime(2026, 11, 2),
          ),
        ],
        year: 2026,
        openingBalance: 5000,
      );

      expect(stats.monthly[10].endBalance, 95000);
      expect(stats.monthly[11].endBalance, 95000);
    });

    test('tanpa transaksi seluruh bulan nol dengan saldo awal tetap', () {
      final stats = SavingsCalculator.computeMonthly(
        transactions: [],
        year: 2026,
        openingBalance: 15000,
      );

      expect(stats.monthly.every((m) => m.depositTotal == 0), isTrue);
      expect(stats.monthly.every((m) => m.endBalance == 15000), isTrue);
      expect(stats.closingBalance, 15000);
    });
  });
}
