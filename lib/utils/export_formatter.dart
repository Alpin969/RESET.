import 'dart:convert';

import '../models/activity_day.dart';
import '../models/savings_transaction.dart';
import '../models/sleep_log.dart';
import '../models/task_snapshot.dart';
import '../utils/task_progress.dart';

class ExportFormatter {
  static const String csvLineSeparator = '\r\n';
  static final RegExp _formulaTrigger = RegExp(r'^[=+\-@\t\r]');

  static String formatTimestamp(DateTime time) {
    return time.toUtc().toIso8601String();
  }

  static String formatDate(DateTime date) {
    return TaskProgress.dateKey(TaskProgress.normalize(date));
  }

  static String csvField(Object? value) {
    if (value == null) return '';
    if (value is num) return value.toString();
    if (value is bool) return value ? 'true' : 'false';
    var text = value.toString();
    if (_formulaTrigger.hasMatch(text)) {
      text = "'$text";
    }
    if (text.contains(',') ||
        text.contains('"') ||
        text.contains('\n') ||
        text.contains('\r')) {
      text = '"${text.replaceAll('"', '""')}"';
    }
    return text;
  }

  static String csvRow(List<Object?> values) {
    return values.map(csvField).join(',');
  }

  static String buildCsv({
    required List<String> headers,
    required List<List<Object?>> rows,
  }) {
    final buffer = StringBuffer();
    buffer.write(csvRow(headers));
    buffer.write(csvLineSeparator);
    for (final row in rows) {
      buffer.write(csvRow(row));
      buffer.write(csvLineSeparator);
    }
    return buffer.toString();
  }

  static String tasksCsv(List<TaskSnapshot> snapshots) {
    final sorted = [...snapshots]
      ..sort((a, b) {
        final byDate = a.checkDate.compareTo(b.checkDate);
        if (byDate != 0) return byDate;
        return a.position.compareTo(b.position);
      });
    return buildCsv(
      headers: const [
        'check_date',
        'task_id',
        'name',
        'icon',
        'position',
        'is_active',
        'completed',
        'completed_at',
      ],
      rows: sorted
          .map((snapshot) => [
                formatDate(snapshot.checkDate),
                snapshot.taskId,
                snapshot.name,
                snapshot.icon,
                snapshot.position,
                snapshot.isActive,
                snapshot.isCompleted,
                snapshot.completedAt == null
                    ? null
                    : formatTimestamp(snapshot.completedAt!),
              ])
          .toList(),
    );
  }

  static String sleepCsv(List<SleepLog> logs) {
    final sorted = [...logs]
      ..sort((a, b) => a.sleepStart.compareTo(b.sleepStart));
    return buildCsv(
      headers: const [
        'sleep_start',
        'wake_time',
        'duration_minutes',
        'wake_local_date',
      ],
      rows: sorted
          .map((log) => [
                formatTimestamp(log.sleepStart),
                formatTimestamp(log.wakeTime),
                log.durationMinutes,
                log.wakeLocalDate == null
                    ? null
                    : formatDate(log.wakeLocalDate!),
              ])
          .toList(),
    );
  }

  static String savingsCsv(List<SavingsTransaction> transactions) {
    final sorted = [...transactions]
      ..sort((a, b) => a.transactionDate.compareTo(b.transactionDate));
    return buildCsv(
      headers: const [
        'transaction_date',
        'transaction_type',
        'amount',
        'note',
        'idempotency_key',
      ],
      rows: sorted
          .map((transaction) => [
                formatTimestamp(transaction.transactionDate),
                transaction.transactionType,
                transaction.amount,
                transaction.note,
                transaction.idempotencyKey,
              ])
          .toList(),
    );
  }

  static String activityCsv(List<ActivityDay> days) {
    final sorted = [...days]..sort((a, b) => a.date.compareTo(b.date));
    return buildCsv(
      headers: const [
        'date',
        'total_tasks',
        'completed_tasks',
        'percentage',
        'all_completed',
      ],
      rows: sorted
          .map((day) => [
                formatDate(day.date),
                day.totalCount,
                day.completedCount,
                day.percentage.toStringAsFixed(1),
                day.allCompleted,
              ])
          .toList(),
    );
  }

  static String encodeBackupJson(Map<String, dynamic> backup) {
    return jsonEncode(backup);
  }

  static String backupFileName(DateTime exportedAt) {
    return 'reset-backup-${_fileDate(exportedAt)}.json';
  }

  static String csvFileName(String dataset, DateTime exportedAt) {
    return 'reset-$dataset-${_fileDate(exportedAt)}.csv';
  }

  static String _fileDate(DateTime time) {
    final utc = time.toUtc();
    final year = utc.year.toString().padLeft(4, '0');
    final month = utc.month.toString().padLeft(2, '0');
    final day = utc.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }
}
