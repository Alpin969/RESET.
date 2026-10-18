import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:reset_app/models/activity_day.dart';
import 'package:reset_app/models/backup_document.dart';
import 'package:reset_app/models/notification_preferences.dart';
import 'package:reset_app/models/savings_transaction.dart';
import 'package:reset_app/models/sleep_log.dart';
import 'package:reset_app/models/task_snapshot.dart';
import 'package:reset_app/models/user_profile.dart';
import 'package:reset_app/utils/export_formatter.dart';

void main() {
  group('csvField', () {
    test('null becomes empty', () {
      expect(ExportFormatter.csvField(null), '');
    });

    test('plain text is unchanged', () {
      expect(ExportFormatter.csvField('shalat subuh'), 'shalat subuh');
    });

    test('numbers are written without quoting', () {
      expect(ExportFormatter.csvField(25000), '25000');
      expect(ExportFormatter.csvField(-1000), '-1000');
      expect(ExportFormatter.csvField(999999999999999), '999999999999999');
      expect(ExportFormatter.csvField(66.66666666666666), '66.66666666666666');
    });

    test('booleans are written as true/false', () {
      expect(ExportFormatter.csvField(true), 'true');
      expect(ExportFormatter.csvField(false), 'false');
    });

    test('commas are escaped with quotes', () {
      expect(ExportFormatter.csvField('a,b'), '"a,b"');
    });

    test('quotes are doubled inside quoted field', () {
      expect(ExportFormatter.csvField('say "halo"'), '"say ""halo"""');
    });

    test('newlines and carriage returns are quoted', () {
      expect(ExportFormatter.csvField('a\nb'), '"a\nb"');
      expect(ExportFormatter.csvField('a\rb'), '"a\rb"');
    });

    test('combined comma, quote, and newline stay RFC 4180 safe', () {
      expect(
        ExportFormatter.csvField('a,"b"\nc'),
        '"a,""b""\nc"',
      );
    });

    test('formula injection triggers are prefixed', () {
      expect(ExportFormatter.csvField('=1+1'), "'=1+1");
      expect(ExportFormatter.csvField('+cmd'), "'+cmd");
      expect(ExportFormatter.csvField('-2+3'), "'-2+3");
      expect(ExportFormatter.csvField('@SUM(A1)'), "'@SUM(A1)");
      expect(ExportFormatter.csvField('\tstart'), "'\tstart");
      expect(ExportFormatter.csvField('\rstart'), '"\'\rstart"');
    });

    test('formula guard also applies before quoting', () {
      expect(ExportFormatter.csvField('=HYPERLINK("x","y")'), '"\'=HYPERLINK(""x"",""y"")"');
    });

    test('Indonesian characters and emoji pass through UTF-8', () {
      expect(ExportFormatter.csvField('Sholat Subuh \u263A'), 'Sholat Subuh \u263A');
    });
  });

  group('csvRow and buildCsv', () {
    test('row joins fields with commas', () {
      expect(ExportFormatter.csvRow(['a', 1, true, null]), 'a,1,true,');
    });

    test('buildCsv writes header, rows, and CRLF separators', () {
      final csv = ExportFormatter.buildCsv(
        headers: const ['a', 'b'],
        rows: [
          ['x', 1],
          ['y,z', 2],
        ],
      );

      expect(csv, 'a,b\r\nx,1\r\n"y,z",2\r\n');
    });

    test('buildCsv with no rows keeps header only', () {
      final csv = ExportFormatter.buildCsv(
        headers: const ['a', 'b'],
        rows: const [],
      );

      expect(csv, 'a,b\r\n');
    });
  });

  group('tasksCsv', () {
    TaskSnapshot snapshot({
      required String id,
      required String taskId,
      required String name,
      int position = 0,
      required DateTime checkDate,
      bool completed = false,
      String? icon,
    }) {
      return TaskSnapshot(
        id: id,
        taskId: taskId,
        name: name,
        icon: icon,
        position: position,
        isActive: true,
        isCompleted: completed,
        checkDate: checkDate,
      );
    }

    test('empty list produces header only', () {
      expect(
        ExportFormatter.tasksCsv(const []),
        'check_date,task_id,name,icon,position,is_active,completed,completed_at\r\n',
      );
    });

    test('rows are sorted by check_date then position', () {
      final csv = ExportFormatter.tasksCsv([
        snapshot(
          id: 's2',
          taskId: 't2',
          name: 'Kedua',
          position: 1,
          checkDate: DateTime(2026, 10, 18),
        ),
        snapshot(
          id: 's1',
          taskId: 't1',
          name: 'Pertama',
          position: 0,
          checkDate: DateTime(2026, 10, 17),
          completed: true,
        ),
      ]);
      final lines = csv.split('\r\n');

      expect(lines[0], 'check_date,task_id,name,icon,position,is_active,completed,completed_at');
      expect(lines[1], '2026-10-17,t1,Pertama,,0,true,true,');
      expect(lines[2], '2026-10-18,t2,Kedua,,1,true,false,');
    });

    test('names with commas and quotes are escaped', () {
      final csv = ExportFormatter.tasksCsv([
        snapshot(
          id: 's1',
          taskId: 't1',
          name: 'Makan, "tepat waktu"',
          position: 0,
          checkDate: DateTime(2026, 10, 17),
        ),
      ]);

      expect(csv, contains('"Makan, ""tepat waktu"""'));
    });
  });

  group('sleepCsv', () {
    test('empty list produces header only', () {
      expect(
        ExportFormatter.sleepCsv(const []),
        'sleep_start,wake_time,duration_minutes,wake_local_date\r\n',
      );
    });

    test('rows are sorted by sleep_start and formatted in UTC', () {
      final csv = ExportFormatter.sleepCsv([
        SleepLog(
          id: 'log-2',
          userId: 'user-1',
          sleepStart: DateTime.utc(2026, 10, 18, 13),
          wakeTime: DateTime.utc(2026, 10, 18, 21),
          durationMinutes: 480,
          wakeLocalDate: DateTime(2026, 10, 19),
        ),
        SleepLog(
          id: 'log-1',
          userId: 'user-1',
          sleepStart: DateTime.utc(2026, 10, 17, 16),
          wakeTime: DateTime.utc(2026, 10, 17, 23, 30),
          durationMinutes: 450,
          wakeLocalDate: DateTime(2026, 10, 18),
        ),
      ]);
      final lines = csv.split('\r\n');

      expect(lines[1], '2026-10-17T16:00:00.000Z,2026-10-17T23:30:00.000Z,450,2026-10-18');
      expect(lines[2], '2026-10-18T13:00:00.000Z,2026-10-18T21:00:00.000Z,480,2026-10-19');
    });
  });

  group('savingsCsv', () {
    test('empty list produces header only', () {
      expect(
        ExportFormatter.savingsCsv(const []),
        'transaction_date,transaction_type,amount,note,idempotency_key\r\n',
      );
    });

    test('large integer amounts keep full precision', () {
      final csv = ExportFormatter.savingsCsv([
        SavingsTransaction(
          id: 'tx-1',
          userId: 'user-1',
          transactionType: SavingsTransaction.typeDeposit,
          amount: 999999999999999,
          transactionDate: DateTime.utc(2026, 10, 18),
        ),
      ]);

      expect(csv, contains(',999999999999999,'));
      expect(csv, isNot(contains('999999999999999.0')));
    });

    test('notes with formula triggers are neutralized', () {
      final csv = ExportFormatter.savingsCsv([
        SavingsTransaction(
          id: 'tx-1',
          userId: 'user-1',
          transactionType: SavingsTransaction.typeWithdrawal,
          amount: 5000,
          note: '=HYPERLINK("http://evil")',
          transactionDate: DateTime.utc(2026, 10, 18),
        ),
      ]);

      expect(csv, contains('"\'=HYPERLINK(""http://evil"")"'));
      expect(csv, isNot(contains('=HYPERLINK("http://evil")')));
    });

    test('rows are sorted by transaction_date', () {
      final csv = ExportFormatter.savingsCsv([
        SavingsTransaction(
          id: 'tx-2',
          userId: 'user-1',
          transactionType: SavingsTransaction.typeDeposit,
          amount: 2000,
          transactionDate: DateTime.utc(2026, 10, 18),
        ),
        SavingsTransaction(
          id: 'tx-1',
          userId: 'user-1',
          transactionType: SavingsTransaction.typeDeposit,
          amount: 1000,
          transactionDate: DateTime.utc(2026, 10, 17),
        ),
      ]);
      final lines = csv.split('\r\n');

      expect(lines[1], startsWith('2026-10-17T00:00:00.000Z,deposit,1000'));
      expect(lines[2], startsWith('2026-10-18T00:00:00.000Z,deposit,2000'));
    });
  });

  group('activityCsv', () {
    test('empty list produces header only', () {
      expect(
        ExportFormatter.activityCsv(const []),
        'date,total_tasks,completed_tasks,percentage,all_completed\r\n',
      );
    });

    test('percentage is written with one decimal', () {
      final csv = ExportFormatter.activityCsv([
        ActivityDay(
          date: DateTime(2026, 10, 17),
          completedCount: 2,
          totalCount: 3,
          percentage: 66.66666666666666,
          allCompleted: false,
        ),
      ]);

      expect(csv, contains(',3,2,66.7,false'));
    });

    test('all completed day is marked true', () {
      final csv = ExportFormatter.activityCsv([
        ActivityDay(
          date: DateTime(2026, 10, 18),
          completedCount: 4,
          totalCount: 4,
          percentage: 100,
          allCompleted: true,
        ),
      ]);

      expect(csv, contains('2026-10-18,4,4,100.0,true'));
    });
  });

  group('timestamps and filenames', () {
    test('formatTimestamp converts to UTC ISO 8601', () {
      final local = DateTime(2026, 10, 18, 10, 30);
      expect(
        ExportFormatter.formatTimestamp(local),
        local.toUtc().toIso8601String(),
      );
    });

    test('formatDate normalizes to yyyy-MM-dd', () {
      expect(
        ExportFormatter.formatDate(DateTime(2026, 1, 5, 23, 59)),
        '2026-01-05',
      );
    });

    test('backupFileName uses UTC date and json extension', () {
      expect(
        ExportFormatter.backupFileName(DateTime.utc(2026, 10, 18, 3, 30)),
        'reset-backup-2026-10-18.json',
      );
    });

    test('csvFileName uses dataset slug and UTC date', () {
      expect(
        ExportFormatter.csvFileName('tasks', DateTime.utc(2026, 10, 18, 3, 30)),
        'reset-tasks-2026-10-18.csv',
      );
      expect(
        ExportFormatter.csvFileName('savings', DateTime.utc(2026, 1, 2, 23, 0)),
        'reset-savings-2026-01-02.csv',
      );
    });
  });

  group('json backup', () {
    test('encodeBackupJson produces parseable JSON with schema version', () {
      final encoded = ExportFormatter.encodeBackupJson({
        'app': 'RESET',
        'schema_version': 1,
        'user_id': 'user-1',
      });
      final decoded = jsonDecode(encoded);

      expect(decoded['app'], 'RESET');
      expect(decoded['schema_version'], 1);
    });

    test('backup of thousands of rows stays complete and valid', () {
      final transactions = List.generate(5000, (index) {
        return SavingsTransaction(
          id: 'tx-$index',
          userId: 'user-1',
          transactionType: index.isEven
              ? SavingsTransaction.typeDeposit
              : SavingsTransaction.typeWithdrawal,
          amount: 1000 + index,
          note: index % 500 == 0 ? '=SUM(A$index)' : null,
          transactionDate: DateTime.utc(2020, 1, 1).add(Duration(minutes: index)),
        );
      });

      final document = BackupDocument(
        userId: 'user-1',
        email: 'bulk@example.com',
        exportedAt: DateTime.utc(2026, 10, 18),
        profile: const UserProfile(id: 'user-1', username: 'bulk'),
        preferences: const NotificationPreferences(
          notificationsEnabled: true,
          reminderDefaultTime: '08:00',
        ),
        summary: BackupSummary(
          currentStreak: 1,
          totalSavings: transactions.fold<int>(0, (sum, tx) => sum + tx.signedAmount),
          taskCount: 0,
          checklistCount: 0,
          taskSnapshotCount: 0,
          sleepLogCount: 0,
          savingsTransactionCount: transactions.length,
          reminderCount: 0,
        ),
        tasks: const [],
        checklists: const [],
        taskSnapshots: const [],
        sleepLogs: const [],
        savingsTransactions: transactions,
        reminders: const [],
      );

      final encoded = ExportFormatter.encodeBackupJson(document.toMap());
      final decoded = jsonDecode(encoded) as Map<String, dynamic>;
      final rows = decoded['savings_transactions'] as List;

      expect(rows.length, 5000);
      expect(rows.first['amount'], 1000);
      expect(rows.last['amount'], 5999);
      expect(rows.first['amount'], isA<int>());
      expect(rows.any((row) => row['note'] == '=SUM(A0)'), isTrue);

      final restored = BackupDocument.fromMap(decoded);
      expect(restored.savingsTransactions.length, 5000);
      expect(restored.savingsTransactions.last.amount, 5999);
    });

    test('tasksCsv handles thousands of rows', () {
      final snapshots = List.generate(5000, (index) {
        final day = DateTime(2026, 1, 1).add(Duration(days: index ~/ 5));
        return TaskSnapshot(
          id: 's-$index',
          taskId: 't-${index % 5}',
          name: 'Task ${index % 5}',
          position: index % 5,
          isActive: true,
          isCompleted: index.isEven,
          checkDate: day,
        );
      });

      final csv = ExportFormatter.tasksCsv(snapshots);
      final lines = csv.split('\r\n').where((line) => line.isNotEmpty).toList();

      expect(lines.length, 5001);
    });

    test('history spanning months and years stays sorted', () {
      final snapshots = [
        TaskSnapshot(
          id: 's3',
          taskId: 't1',
          name: 'T',
          position: 0,
          isActive: true,
          isCompleted: false,
          checkDate: DateTime(2027, 1, 1),
        ),
        TaskSnapshot(
          id: 's1',
          taskId: 't1',
          name: 'T',
          position: 0,
          isActive: true,
          isCompleted: false,
          checkDate: DateTime(2025, 12, 31),
        ),
        TaskSnapshot(
          id: 's2',
          taskId: 't1',
          name: 'T',
          position: 0,
          isActive: true,
          isCompleted: false,
          checkDate: DateTime(2026, 2, 28),
        ),
      ];

      final lines = ExportFormatter
          .tasksCsv(snapshots)
          .split('\r\n')
          .where((line) => line.isNotEmpty)
          .toList();

      expect(lines[1], startsWith('2025-12-31,'));
      expect(lines[2], startsWith('2026-02-28,'));
      expect(lines[3], startsWith('2027-01-01,'));
    });
  });
}
