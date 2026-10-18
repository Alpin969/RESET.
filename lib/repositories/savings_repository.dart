import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/savings_stats.dart';
import '../models/savings_transaction.dart';
import '../utils/savings_calculator.dart';
import '../utils/task_progress.dart';

class SavingsRepository {
  SupabaseClient get _client => Supabase.instance.client;

  String _requireUid() {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) {
      throw AuthException('Sesi tidak ditemukan. Silakan login ulang.');
    }
    return uid;
  }

  Map<String, dynamic> _asMap(dynamic value) {
    return Map<String, dynamic>.from(value as Map);
  }

  Future<DateTime> getLocalToday() async {
    _requireUid();
    final data = await _client.rpc('get_local_today');
    return TaskProgress.normalize(DateTime.parse(data.toString()));
  }

  String generateIdempotencyKey() {
    final random = Random.secure();
    final values = List<int>.generate(32, (_) => random.nextInt(16));
    return values.map((value) => value.toRadixString(16)).join();
  }

  Future<SavingsTransaction> addDeposit({
    required int amount,
    String? note,
    DateTime? transactionDate,
    String? idempotencyKey,
  }) {
    return _addTransaction(
      transactionType: SavingsTransaction.typeDeposit,
      amount: amount,
      note: note,
      transactionDate: transactionDate,
      idempotencyKey: idempotencyKey,
    );
  }

  Future<SavingsTransaction> addWithdrawal({
    required int amount,
    String? note,
    DateTime? transactionDate,
    String? idempotencyKey,
  }) {
    return _addTransaction(
      transactionType: SavingsTransaction.typeWithdrawal,
      amount: amount,
      note: note,
      transactionDate: transactionDate,
      idempotencyKey: idempotencyKey,
    );
  }

  Future<int> getCurrentBalance() async {
    _requireUid();
    final data = await _client.rpc('savings_balance');
    return (data as num).toInt();
  }

  Future<List<SavingsTransaction>> getMyTransactions({
    int limit = 50,
    int offset = 0,
  }) async {
    _requireUid();
    final data = await _client.rpc('savings_list_my', params: {
      'p_limit': limit,
      'p_offset': offset,
    });
    return (data as List)
        .map((row) => SavingsTransaction.fromMap(_asMap(row)))
        .toList();
  }

  Future<SavingsTransaction> getTransactionById(String id) async {
    _requireUid();
    final data = await _client.rpc('savings_get', params: {'p_id': id});
    return SavingsTransaction.fromMap(_asMap(data));
  }

  Future<SavingsTransaction> updateTransaction({
    required String id,
    int? amount,
    String? note,
    bool clearNote = false,
  }) async {
    _requireUid();

    if (amount != null) {
      final amountError = SavingsCalculator.validateAmount(amount);
      if (amountError != null) throw AuthException(amountError);
    }

    if (!clearNote && note != null) {
      final noteError = SavingsCalculator.validateNote(note);
      if (noteError != null) throw AuthException(noteError);
    }

    final data = await _client.rpc('savings_update_transaction', params: {
      'p_id': id,
      'p_amount': amount,
      'p_note': clearNote ? null : SavingsCalculator.cleanNote(note),
      'p_clear_note': clearNote,
    });
    return SavingsTransaction.fromMap(_asMap(data));
  }

  Future<void> deleteTransaction(String id) async {
    _requireUid();
    await _client.rpc('savings_delete_transaction', params: {'p_id': id});
  }

  Future<SavingsStats> getWeeklySavingsStats() async {
    final today = await getLocalToday();
    final first = DateTime(today.year, today.month, today.day - 6);
    return _statsForRange(first, today);
  }

  Future<SavingsStats> getMonthlySavingsStats() async {
    final today = await getLocalToday();
    final first = DateTime(today.year, today.month, 1);
    final last = DateTime(today.year, today.month + 1, 0);
    return _statsForRange(first, last);
  }

  Future<SavingsStats> getYearlySavingsStats({int? year}) async {
    final targetYear = year ?? (await getLocalToday()).year;
    final opening = await _balanceBefore(DateTime(targetYear, 1, 1));

    final data = await _client.rpc('savings_transactions_between', params: {
      'p_from': TaskProgress.dateKey(DateTime(targetYear, 1, 1)),
      'p_to': TaskProgress.dateKey(DateTime(targetYear, 12, 31)),
    });

    final transactions = (data as List)
        .map((row) => SavingsTransaction.fromMap(_asMap(row)))
        .toList();

    return SavingsCalculator.computeMonthly(
      transactions: transactions,
      year: targetYear,
      openingBalance: opening,
    );
  }

  Future<SavingsStats> _statsForRange(DateTime first, DateTime last) async {
    final opening = await _balanceBefore(first);

    final data = await _client.rpc('savings_transactions_between', params: {
      'p_from': TaskProgress.dateKey(first),
      'p_to': TaskProgress.dateKey(last),
    });

    final transactions = (data as List)
        .map((row) => SavingsTransaction.fromMap(_asMap(row)))
        .toList();

    return SavingsCalculator.computeDaily(
      transactions: transactions,
      firstDay: first,
      lastDay: last,
      openingBalance: opening,
    );
  }

  Future<int> _balanceBefore(DateTime date) async {
    _requireUid();
    final data = await _client.rpc(
      'savings_balance_before',
      params: {'p_date': TaskProgress.dateKey(date)},
    );
    return (data as num).toInt();
  }

  Future<SavingsTransaction> _addTransaction({
    required String transactionType,
    required int amount,
    String? note,
    DateTime? transactionDate,
    String? idempotencyKey,
  }) async {
    _requireUid();

    final amountError = SavingsCalculator.validateAmount(amount);
    if (amountError != null) throw AuthException(amountError);

    final noteError = SavingsCalculator.validateNote(note);
    if (noteError != null) throw AuthException(noteError);

    final cleanedNote = SavingsCalculator.cleanNote(note);
    var key = idempotencyKey?.trim();
    if (key != null && key.isEmpty) key = null;

    final data = await _client.rpc('savings_add_transaction', params: {
      'p_transaction_type': transactionType,
      'p_amount': amount,
      'p_note': cleanedNote,
      'p_transaction_date':
          transactionDate?.toUtc().toIso8601String(),
      'p_idempotency_key': key ?? generateIdempotencyKey(),
    });
    return SavingsTransaction.fromMap(_asMap(data));
  }
}
