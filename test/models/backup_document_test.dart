import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:reset_app/models/backup_document.dart';
import 'package:reset_app/models/checklist_entry.dart';
import 'package:reset_app/models/daily_task.dart';
import 'package:reset_app/models/notification_preferences.dart';
import 'package:reset_app/models/savings_transaction.dart';
import 'package:reset_app/models/sleep_log.dart';
import 'package:reset_app/models/task_reminder.dart';
import 'package:reset_app/models/task_snapshot.dart';
import 'package:reset_app/models/user_profile.dart';

void main() {
  BackupDocument buildDocument() {
    final profile = UserProfile(
      id: 'user-1',
      username: 'alvin',
      motivation: 'Bangun pagi',
      ageGroup: '18+',
      timezone: 'Asia/Jakarta',
      email: 'alvin@example.com',
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 10, 1),
    );
    return BackupDocument(
      userId: 'user-1',
      email: 'alvin@example.com',
      exportedAt: DateTime.utc(2026, 10, 18, 3, 30),
      profile: profile,
      preferences: const NotificationPreferences(
        notificationsEnabled: true,
        reminderDefaultTime: '08:00',
        timezone: 'Asia/Jakarta',
      ),
      summary: const BackupSummary(
        currentStreak: 3,
        totalSavings: 150000,
        taskCount: 2,
        checklistCount: 2,
        taskSnapshotCount: 3,
        sleepLogCount: 1,
        savingsTransactionCount: 2,
        reminderCount: 1,
        firstActivityDate: '2026-10-16',
        lastActivityDate: '2026-10-18',
      ),
      tasks: const [
        DailyTask(
          id: 'task-1',
          userId: 'user-1',
          name: 'Olahraga',
          icon: 'run',
          position: 0,
          isActive: true,
        ),
        DailyTask(
          id: 'task-2',
          userId: 'user-1',
          name: 'Membaca',
          position: 1,
          isActive: false,
        ),
      ],
      checklists: [
        ChecklistEntry(
          id: 'check-1',
          userId: 'user-1',
          taskId: 'task-1',
          checkDate: DateTime(2026, 10, 18),
          completed: true,
        ),
      ],
      taskSnapshots: const [],
      sleepLogs: const [],
      savingsTransactions: const [],
      reminders: const [],
    );
  }

  BackupDocument buildFullDocument() {
    final base = buildDocument();
    return BackupDocument(
      userId: base.userId,
      email: base.email,
      exportedAt: base.exportedAt,
      profile: base.profile,
      preferences: base.preferences,
      summary: const BackupSummary(
        currentStreak: 5,
        totalSavings: 999999999999999,
        taskCount: 1,
        checklistCount: 1,
        taskSnapshotCount: 1,
        sleepLogCount: 1,
        savingsTransactionCount: 2,
        reminderCount: 1,
        firstActivityDate: '2026-01-01',
        lastActivityDate: '2026-10-18',
      ),
      tasks: const [
        DailyTask(
          id: 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee',
          userId: 'user-1',
          name: 'Ol,ahraga "khusus"',
          position: 0,
          isActive: true,
        ),
      ],
      checklists: [
        ChecklistEntry(
          id: 'check-1',
          userId: 'user-1',
          taskId: 'task-1',
          checkDate: DateTime(2026, 10, 18),
          completed: false,
        ),
      ],
      taskSnapshots: [
        TaskSnapshot(
          id: 'snapshot-1',
          taskId: 'task-1',
          name: 'Ol,ahraga "khusus"',
          position: 0,
          isActive: true,
          isCompleted: true,
          completedAt: DateTime.utc(2026, 10, 18, 2),
          checkDate: DateTime(2026, 10, 18),
        ),
      ],
      sleepLogs: [
        SleepLog(
          id: 'log-1',
          userId: 'user-1',
          sleepStart: DateTime.utc(2026, 10, 17, 16),
          wakeTime: DateTime.utc(2026, 10, 17, 23),
          durationMinutes: 420,
          wakeLocalDate: DateTime(2026, 10, 18),
        ),
      ],
      savingsTransactions: [
        SavingsTransaction(
          id: 'tx-1',
          userId: 'user-1',
          transactionType: SavingsTransaction.typeDeposit,
          amount: 999999999999999,
          note: '=SUM(A1:A2)',
          transactionDate: DateTime.utc(2026, 10, 18, 1),
        ),
        SavingsTransaction(
          id: 'tx-2',
          userId: 'user-1',
          transactionType: SavingsTransaction.typeWithdrawal,
          amount: 25000,
          transactionDate: DateTime.utc(2026, 10, 18, 2),
        ),
      ],
      reminders: const [
        TaskReminder(
          id: 'reminder-1',
          userId: 'user-1',
          taskId: 'task-1',
          taskIsActive: true,
          taskDeleted: false,
          timeOfDay: '08:00',
          frequency: TaskReminder.frequencySpecificDays,
          daysOfWeek: [1, 3, 5],
          isEnabled: true,
        ),
      ],
    );
  }

  test('schema metadata uses app RESET and version 1', () {
    final map = buildDocument().toMap();

    expect(map['app'], 'RESET');
    expect(map['schema_version'], 1);
    expect(map['exported_at'], '2026-10-18T03:30:00.000Z');
    expect(map['user_id'], 'user-1');
    expect(map['email'], 'alvin@example.com');
  });

  test('toMap includes every section exactly once', () {
    final map = buildDocument().toMap();

    expect(
      map.keys.toList(),
      [
        'app',
        'schema_version',
        'exported_at',
        'user_id',
        'email',
        'profile',
        'preferences',
        'summary',
        'tasks',
        'checklists',
        'task_snapshots',
        'sleep_logs',
        'savings_transactions',
        'reminders',
      ],
    );
    expect((map['tasks'] as List).length, 2);
    expect((map['checklists'] as List).length, 1);
  });

  test('validateMap accepts a valid backup map', () {
    expect(BackupDocument.validateMap(buildDocument().toMap()), isNull);
  });

  test('validateMap rejects file that is not a RESET backup', () {
    final map = buildDocument().toMap();
    map['app'] = 'OtherApp';

    expect(BackupDocument.validateMap(map), 'File bukan backup RESET.');
  });

  test('validateMap rejects newer schema version', () {
    final map = buildDocument().toMap();
    map['schema_version'] = BackupDocument.schemaVersion + 1;

    expect(
      BackupDocument.validateMap(map),
      'Versi backup (${BackupDocument.schemaVersion + 1}) lebih baru dari aplikasi (${BackupDocument.schemaVersion}).',
    );
  });

  test('validateMap rejects broken schema version types', () {
    for (final version in ['1', null, 0, -3]) {
      final map = buildDocument().toMap();
      map['schema_version'] = version;
      expect(BackupDocument.validateMap(map), 'Schema backup tidak valid.');
    }
  });

  test('validateMap rejects missing or invalid exported_at', () {
    final missing = buildDocument().toMap()..remove('exported_at');
    expect(BackupDocument.validateMap(missing), 'Waktu export tidak valid.');

    final broken = buildDocument().toMap();
    broken['exported_at'] = 'not-a-date';
    expect(BackupDocument.validateMap(broken), 'Waktu export tidak valid.');
  });

  test('validateMap rejects missing user_id', () {
    final map = buildDocument().toMap()..['user_id'] = '   ';
    expect(BackupDocument.validateMap(map), 'user_id tidak ditemukan.');
  });

  test('validateMap rejects missing sections', () {
    const sections = {
      'profile': 'Bagian profile tidak ditemukan.',
      'preferences': 'Bagian preferences tidak ditemukan.',
      'summary': 'Bagian summary tidak ditemukan.',
      'tasks': 'Bagian tasks tidak ditemukan.',
      'checklists': 'Bagian checklists tidak ditemukan.',
      'task_snapshots': 'Bagian task_snapshots tidak ditemukan.',
      'sleep_logs': 'Bagian sleep_logs tidak ditemukan.',
      'savings_transactions': 'Bagian savings_transactions tidak ditemukan.',
      'reminders': 'Bagian reminders tidak ditemukan.',
    };

    for (final entry in sections.entries) {
      final map = buildDocument().toMap()..remove(entry.key);
      expect(BackupDocument.validateMap(map), entry.value);
    }
  });

  test('fromMap throws FormatException for incompatible version', () {
    final map = buildDocument().toMap();
    map['schema_version'] = 99;

    expect(
      () => BackupDocument.fromMap(map),
      throwsA(isA<FormatException>()),
    );
  });

  test('fromMap throws FormatException for corrupted file', () {
    expect(
      () => BackupDocument.fromMap({'random': 'noise'}),
      throwsA(isA<FormatException>()),
    );
  });

  test('toMap and fromMap round trip preserves data', () {
    final document = buildFullDocument();
    final decoded = jsonDecode(jsonEncode(document.toMap()));

    expect(decoded, isA<Map<String, dynamic>>());
    final restored = BackupDocument.fromMap(
      Map<String, dynamic>.from(decoded as Map),
    );

    expect(restored.userId, document.userId);
    expect(restored.email, document.email);
    expect(restored.exportedAt, document.exportedAt);
    expect(restored.profile.username, document.profile.username);
    expect(restored.preferences.reminderDefaultTime, '08:00');
    expect(restored.summary.currentStreak, 5);
    expect(restored.summary.totalSavings, 999999999999999);
    expect(restored.tasks.single.id, document.tasks.single.id);
    expect(restored.tasks.single.name, 'Ol,ahraga "khusus"');
    expect(restored.taskSnapshots.single.completedAt, DateTime.utc(2026, 10, 18, 2));
    expect(restored.sleepLogs.single.durationMinutes, 420);
    expect(restored.savingsTransactions.first.amount, 999999999999999);
    expect(restored.savingsTransactions.first.note, '=SUM(A1:A2)');
    expect(
      restored.reminders.single.daysOfWeek,
      document.reminders.single.daysOfWeek,
    );
  });

  test('encoded JSON keeps money as integers and traceable UUIDs', () {
    final encoded = jsonEncode(buildFullDocument().toMap());

    expect(encoded, contains('999999999999999'));
    expect(encoded, isNot(contains('999999999999999.0')));
    expect(
      encoded,
      contains('aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee'),
    );
  });

  test('encoded JSON contains no sensitive fields', () {
    final encoded = jsonEncode(buildFullDocument().toMap());

    expect(encoded, isNot(contains('password')));
    expect(encoded, isNot(contains('access_token')));
    expect(encoded, isNot(contains('refresh_token')));
    expect(encoded, isNot(contains('service_role')));
    expect(encoded, isNot(contains('vapid')));
    expect(encoded, isNot(contains('endpoint')));
    expect(encoded, isNot(contains('p256dh')));
    expect(encoded, isNot(contains('push_subscriptions')));
  });

  test('backup stays scoped to a single user id', () {
    final document = buildFullDocument();
    final encoded = jsonEncode(document.toMap());

    expect(document.profile.id, document.userId);
    expect(document.tasks.every((task) => task.userId == document.userId), isTrue);
    expect(
      document.savingsTransactions
          .every((tx) => tx.userId == document.userId),
      isTrue,
    );
    expect('user-2'.allMatches(encoded), isEmpty);
    expect(document.userId.allMatches(encoded).length, greaterThan(0));
  });

  test('totalRecordCount sums every section', () {
    final document = buildFullDocument();

    expect(
      document.summary.totalRecordCount,
      1 + 1 + 1 + 1 + 2 + 1,
    );
  });
}
