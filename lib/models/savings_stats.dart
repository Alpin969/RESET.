class SavingsDayStat {
  final DateTime date;
  final int depositTotal;
  final int withdrawalTotal;
  final int endBalance;

  const SavingsDayStat({
    required this.date,
    required this.depositTotal,
    required this.withdrawalTotal,
    required this.endBalance,
  });
}

class SavingsMonthStat {
  final int year;
  final int month;
  final int depositTotal;
  final int withdrawalTotal;
  final int endBalance;

  const SavingsMonthStat({
    required this.year,
    required this.month,
    required this.depositTotal,
    required this.withdrawalTotal,
    required this.endBalance,
  });
}

class SavingsStats {
  final int openingBalance;
  final int closingBalance;
  final int totalDeposits;
  final int totalWithdrawals;
  final List<SavingsDayStat> daily;
  final List<SavingsMonthStat> monthly;

  const SavingsStats({
    required this.openingBalance,
    required this.closingBalance,
    required this.totalDeposits,
    required this.totalWithdrawals,
    this.daily = const [],
    this.monthly = const [],
  });
}
