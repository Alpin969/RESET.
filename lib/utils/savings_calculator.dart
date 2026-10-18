import '../models/savings_stats.dart';
import '../models/savings_transaction.dart';
import 'task_progress.dart';

class SavingsCalculator {
  static const int maxAmount = 1000000000000000;
  static const int maxNoteLength = 200;

  static String? validateAmount(int? amount) {
    if (amount == null) {
      return 'Nominal wajib diisi.';
    }
    if (amount <= 0) {
      return 'Nominal harus lebih besar dari nol.';
    }
    if (amount > maxAmount) {
      return 'Nominal maksimal Rp1.000.000.000.000.000.';
    }
    return null;
  }

  static String? validateNote(String? note) {
    final cleaned = note?.trim() ?? '';
    if (cleaned.isEmpty) return null;
    if (cleaned.length > maxNoteLength) {
      return 'Catatan maksimal $maxNoteLength karakter.';
    }
    return null;
  }

  static String? cleanNote(String? note) {
    final cleaned = note?.trim() ?? '';
    return cleaned.isEmpty ? null : cleaned;
  }

  static bool isValidType(String type) {
    return type == SavingsTransaction.typeDeposit ||
        type == SavingsTransaction.typeWithdrawal;
  }

  static int balanceOf(List<SavingsTransaction> transactions) {
    return transactions.fold<int>(0, (sum, tx) => sum + tx.signedAmount);
  }

  static SavingsStats computeDaily({
    required List<SavingsTransaction> transactions,
    required DateTime firstDay,
    required DateTime lastDay,
    required int openingBalance,
  }) {
    final start = _dateOnly(firstDay);
    final end = _dateOnly(lastDay);

    final grouped = <String, List<SavingsTransaction>>{};
    for (final tx in transactions) {
      final localDate = tx.transactionLocalDate;
      if (localDate == null) continue;
      grouped
          .putIfAbsent(TaskProgress.dateKey(localDate), () => [])
          .add(tx);
    }

    final daily = <SavingsDayStat>[];
    var balance = openingBalance;
    var totalDeposits = 0;
    var totalWithdrawals = 0;
    var day = start;

    while (!day.isAfter(end)) {
      final list = grouped[TaskProgress.dateKey(day)] ?? const [];
      var deposits = 0;
      var withdrawals = 0;

      for (final tx in list) {
        if (tx.isDeposit) {
          deposits += tx.amount;
        } else {
          withdrawals += tx.amount;
        }
      }

      balance += deposits - withdrawals;
      totalDeposits += deposits;
      totalWithdrawals += withdrawals;

      daily.add(SavingsDayStat(
        date: day,
        depositTotal: deposits,
        withdrawalTotal: withdrawals,
        endBalance: balance,
      ));

      day = DateTime(day.year, day.month, day.day + 1);
    }

    return SavingsStats(
      openingBalance: openingBalance,
      closingBalance: balance,
      totalDeposits: totalDeposits,
      totalWithdrawals: totalWithdrawals,
      daily: daily,
    );
  }

  static SavingsStats computeMonthly({
    required List<SavingsTransaction> transactions,
    required int year,
    required int openingBalance,
  }) {
    final yearTransactions = transactions
        .where((tx) => tx.transactionLocalDate?.year == year)
        .toList();

    final grouped = <String, List<SavingsTransaction>>{};
    for (final tx in yearTransactions) {
      final localDate = tx.transactionLocalDate!;
      final key =
          '${localDate.year}-${localDate.month.toString().padLeft(2, '0')}';
      grouped.putIfAbsent(key, () => []).add(tx);
    }

    final monthly = <SavingsMonthStat>[];
    var balance = openingBalance;
    var totalDeposits = 0;
    var totalWithdrawals = 0;

    for (var month = 1; month <= 12; month++) {
      final key = '$year-${month.toString().padLeft(2, '0')}';
      final list = grouped[key] ?? const <SavingsTransaction>[];
      var deposits = 0;
      var withdrawals = 0;

      for (final tx in list) {
        if (tx.isDeposit) {
          deposits += tx.amount;
        } else {
          withdrawals += tx.amount;
        }
      }

      balance += deposits - withdrawals;
      totalDeposits += deposits;
      totalWithdrawals += withdrawals;

      monthly.add(SavingsMonthStat(
        year: year,
        month: month,
        depositTotal: deposits,
        withdrawalTotal: withdrawals,
        endBalance: balance,
      ));
    }

    return SavingsStats(
      openingBalance: openingBalance,
      closingBalance: balance,
      totalDeposits: totalDeposits,
      totalWithdrawals: totalWithdrawals,
      monthly: monthly,
    );
  }

  static DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }
}
