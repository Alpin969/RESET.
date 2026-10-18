class SavingsTransaction {
  static const String typeDeposit = 'deposit';
  static const String typeWithdrawal = 'withdrawal';

  final String id;
  final String userId;
  final String transactionType;
  final int amount;
  final String? note;
  final DateTime transactionDate;
  final DateTime? transactionLocalDate;
  final String? idempotencyKey;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const SavingsTransaction({
    required this.id,
    required this.userId,
    required this.transactionType,
    required this.amount,
    this.note,
    required this.transactionDate,
    this.transactionLocalDate,
    this.idempotencyKey,
    this.createdAt,
    this.updatedAt,
  });

  bool get isDeposit => transactionType == typeDeposit;
  bool get isWithdrawal => transactionType == typeWithdrawal;

  int get signedAmount => isDeposit ? amount : -amount;

  factory SavingsTransaction.fromMap(Map<String, dynamic> map) {
    return SavingsTransaction(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      transactionType: map['transaction_type'] as String,
      amount: (map['amount'] as num).toInt(),
      note: map['note'] as String?,
      transactionDate: DateTime.parse(map['transaction_date'] as String),
      transactionLocalDate:
          DateTime.tryParse(map['transaction_local_date']?.toString() ?? ''),
      idempotencyKey: map['idempotency_key'] as String?,
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? ''),
      updatedAt: DateTime.tryParse(map['updated_at']?.toString() ?? ''),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'transaction_type': transactionType,
      'amount': amount,
      'note': note,
      'transaction_date': transactionDate.toUtc().toIso8601String(),
      'transaction_local_date':
          transactionLocalDate?.toIso8601String().split('T').first,
      'idempotency_key': idempotencyKey,
      'created_at': createdAt?.toUtc().toIso8601String(),
      'updated_at': updatedAt?.toUtc().toIso8601String(),
    };
  }

  SavingsTransaction copyWith({
    String? transactionType,
    int? amount,
    String? note,
    DateTime? transactionDate,
    DateTime? transactionLocalDate,
  }) {
    return SavingsTransaction(
      id: id,
      userId: userId,
      transactionType: transactionType ?? this.transactionType,
      amount: amount ?? this.amount,
      note: note ?? this.note,
      transactionDate: transactionDate ?? this.transactionDate,
      transactionLocalDate: transactionLocalDate ?? this.transactionLocalDate,
      idempotencyKey: idempotencyKey,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
