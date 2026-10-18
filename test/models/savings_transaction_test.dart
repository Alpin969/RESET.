import 'package:flutter_test/flutter_test.dart';
import 'package:reset_app/models/savings_transaction.dart';
import 'package:reset_app/repositories/savings_repository.dart';

void main() {
  Map<String, dynamic> row() {
    return {
      'id': 'tx-1',
      'user_id': 'user-1',
      'transaction_type': 'deposit',
      'amount': 10000,
      'note': 'nabung harian',
      'transaction_date': '2026-10-17T16:00:00.000Z',
      'transaction_local_date': '2026-10-18',
      'idempotency_key': 'abc12345abc12345',
      'created_at': '2026-10-17T16:00:01.000Z',
      'updated_at': '2026-10-17T16:00:01.000Z',
    };
  }

  test('SavingsTransaction.fromMap parses full row', () {
    final tx = SavingsTransaction.fromMap(row());

    expect(tx.id, 'tx-1');
    expect(tx.userId, 'user-1');
    expect(tx.transactionType, 'deposit');
    expect(tx.amount, 10000);
    expect(tx.note, 'nabung harian');
    expect(tx.transactionDate, DateTime.utc(2026, 10, 17, 16));
    expect(tx.transactionLocalDate, DateTime(2026, 10, 18));
    expect(tx.idempotencyKey, 'abc12345abc12345');
    expect(tx.isDeposit, isTrue);
    expect(tx.isWithdrawal, isFalse);
    expect(tx.signedAmount, 10000);
  });

  test('SavingsTransaction.fromMap parses withdrawal row', () {
    final tx = SavingsTransaction.fromMap({
      ...row(),
      'transaction_type': 'withdrawal',
      'note': null,
    });

    expect(tx.isWithdrawal, isTrue);
    expect(tx.isDeposit, isFalse);
    expect(tx.signedAmount, -10000);
    expect(tx.note, isNull);
  });

  test('SavingsTransaction.fromMap handles missing optional fields', () {
    final tx = SavingsTransaction.fromMap({
      'id': 'tx-2',
      'user_id': 'user-1',
      'transaction_type': 'deposit',
      'amount': 5000,
      'transaction_date': '2026-10-17T16:00:00.000Z',
    });

    expect(tx.note, isNull);
    expect(tx.transactionLocalDate, isNull);
    expect(tx.idempotencyKey, isNull);
    expect(tx.createdAt, isNull);
    expect(tx.updatedAt, isNull);
  });

  test('SavingsTransaction.toMap round trips through fromMap', () {
    final tx = SavingsTransaction.fromMap(row());
    final restored = SavingsTransaction.fromMap(tx.toMap());

    expect(restored.id, tx.id);
    expect(restored.transactionType, tx.transactionType);
    expect(restored.amount, tx.amount);
    expect(restored.note, tx.note);
    expect(restored.transactionDate, tx.transactionDate);
    expect(restored.transactionLocalDate, tx.transactionLocalDate);
    expect(restored.idempotencyKey, tx.idempotencyKey);
  });

  test('SavingsTransaction.copyWith updates only provided fields', () {
    final tx = SavingsTransaction.fromMap(row());
    final updated = tx.copyWith(amount: 15000, note: 'dikoreksi');

    expect(updated.id, tx.id);
    expect(updated.amount, 15000);
    expect(updated.note, 'dikoreksi');
    expect(updated.transactionType, tx.transactionType);
    expect(updated.idempotencyKey, tx.idempotencyKey);
  });

  test('SavingsRepository idempotency key generator makes unique 32 char hex keys', () {
    final repository = SavingsRepository();
    final keys = <String>{};
    for (var i = 0; i < 100; i++) {
      keys.add(repository.generateIdempotencyKey());
    }

    expect(keys.length, 100);
    expect(keys.every((key) => key.length == 32), isTrue);
    expect(
      keys.every((key) => RegExp(r'^[0-9a-f]{32}$').hasMatch(key)),
      isTrue,
    );
  });
}
