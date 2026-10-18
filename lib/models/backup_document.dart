import 'checklist_entry.dart';
import 'daily_task.dart';
import 'notification_preferences.dart';
import 'savings_transaction.dart';
import 'sleep_log.dart';
import 'task_reminder.dart';
import 'task_snapshot.dart';
import 'user_profile.dart';

class BackupSummary {
  final int currentStreak;
  final int totalSavings;
  final int taskCount;
  final int checklistCount;
  final int taskSnapshotCount;
  final int sleepLogCount;
  final int savingsTransactionCount;
  final int reminderCount;
  final String? firstActivityDate;
  final String? lastActivityDate;

  const BackupSummary({
    required this.currentStreak,
    required this.totalSavings,
    required this.taskCount,
    required this.checklistCount,
    required this.taskSnapshotCount,
    required this.sleepLogCount,
    required this.savingsTransactionCount,
    required this.reminderCount,
    this.firstActivityDate,
    this.lastActivityDate,
  });

  int get totalRecordCount =>
      taskCount +
      checklistCount +
      taskSnapshotCount +
      sleepLogCount +
      savingsTransactionCount +
      reminderCount;

  factory BackupSummary.fromMap(Map<String, dynamic> map) {
    return BackupSummary(
      currentStreak: (map['current_streak'] as num?)?.toInt() ?? 0,
      totalSavings: (map['total_savings'] as num?)?.toInt() ?? 0,
      taskCount: (map['task_count'] as num?)?.toInt() ?? 0,
      checklistCount: (map['checklist_count'] as num?)?.toInt() ?? 0,
      taskSnapshotCount: (map['task_snapshot_count'] as num?)?.toInt() ?? 0,
      sleepLogCount: (map['sleep_log_count'] as num?)?.toInt() ?? 0,
      savingsTransactionCount:
          (map['savings_transaction_count'] as num?)?.toInt() ?? 0,
      reminderCount: (map['reminder_count'] as num?)?.toInt() ?? 0,
      firstActivityDate: map['first_activity_date'] as String?,
      lastActivityDate: map['last_activity_date'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'current_streak': currentStreak,
      'total_savings': totalSavings,
      'task_count': taskCount,
      'checklist_count': checklistCount,
      'task_snapshot_count': taskSnapshotCount,
      'sleep_log_count': sleepLogCount,
      'savings_transaction_count': savingsTransactionCount,
      'reminder_count': reminderCount,
      'first_activity_date': firstActivityDate,
      'last_activity_date': lastActivityDate,
    };
  }
}

class BackupDocument {
  static const String appName = 'RESET';
  static const int schemaVersion = 1;

  final String userId;
  final String? email;
  final DateTime exportedAt;
  final UserProfile profile;
  final NotificationPreferences preferences;
  final BackupSummary summary;
  final List<DailyTask> tasks;
  final List<ChecklistEntry> checklists;
  final List<TaskSnapshot> taskSnapshots;
  final List<SleepLog> sleepLogs;
  final List<SavingsTransaction> savingsTransactions;
  final List<TaskReminder> reminders;

  const BackupDocument({
    required this.userId,
    this.email,
    required this.exportedAt,
    required this.profile,
    required this.preferences,
    required this.summary,
    required this.tasks,
    required this.checklists,
    required this.taskSnapshots,
    required this.sleepLogs,
    required this.savingsTransactions,
    required this.reminders,
  });

  static String? validateMap(Map<String, dynamic> map) {
    if (map['app'] != appName) {
      return 'File bukan backup RESET.';
    }
    final version = map['schema_version'];
    if (version is! int || version < 1) {
      return 'Schema backup tidak valid.';
    }
    if (version > schemaVersion) {
      return 'Versi backup ($version) lebih baru dari aplikasi ($schemaVersion).';
    }
    final exportedAt = map['exported_at'];
    if (exportedAt is! String || DateTime.tryParse(exportedAt) == null) {
      return 'Waktu export tidak valid.';
    }
    final userId = map['user_id'];
    if (userId is! String || userId.trim().isEmpty) {
      return 'user_id tidak ditemukan.';
    }
    if (map['profile'] is! Map) {
      return 'Bagian profile tidak ditemukan.';
    }
    if (map['preferences'] is! Map) {
      return 'Bagian preferences tidak ditemukan.';
    }
    if (map['summary'] is! Map) {
      return 'Bagian summary tidak ditemukan.';
    }
    const listSections = [
      'tasks',
      'checklists',
      'task_snapshots',
      'sleep_logs',
      'savings_transactions',
      'reminders',
    ];
    for (final section in listSections) {
      if (map[section] is! List) {
        return 'Bagian $section tidak ditemukan.';
      }
    }
    return null;
  }

  factory BackupDocument.fromMap(Map<String, dynamic> map) {
    final error = validateMap(map);
    if (error != null) {
      throw FormatException(error);
    }
    return BackupDocument(
      userId: map['user_id'] as String,
      email: map['email'] as String?,
      exportedAt: DateTime.parse(map['exported_at'] as String),
      profile: UserProfile.fromMap(_section(map, 'profile')),
      preferences: NotificationPreferences.fromMap(_section(map, 'preferences')),
      summary: BackupSummary.fromMap(_section(map, 'summary')),
      tasks: _rows(map, 'tasks').map(DailyTask.fromMap).toList(),
      checklists: _rows(map, 'checklists').map(ChecklistEntry.fromMap).toList(),
      taskSnapshots: _rows(map, 'task_snapshots').map(TaskSnapshot.fromMap).toList(),
      sleepLogs: _rows(map, 'sleep_logs').map(SleepLog.fromMap).toList(),
      savingsTransactions:
          _rows(map, 'savings_transactions').map(SavingsTransaction.fromMap).toList(),
      reminders: _rows(map, 'reminders').map(TaskReminder.fromMap).toList(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'app': appName,
      'schema_version': schemaVersion,
      'exported_at': exportedAt.toUtc().toIso8601String(),
      'user_id': userId,
      'email': email,
      'profile': profile.toMap(),
      'preferences': preferences.toMap(),
      'summary': summary.toMap(),
      'tasks': tasks.map((task) => task.toMap()).toList(),
      'checklists': checklists.map((entry) => entry.toMap()).toList(),
      'task_snapshots': taskSnapshots.map((snapshot) => snapshot.toMap()).toList(),
      'sleep_logs': sleepLogs.map((log) => log.toMap()).toList(),
      'savings_transactions':
          savingsTransactions.map((transaction) => transaction.toMap()).toList(),
      'reminders': reminders.map((reminder) => reminder.toMap()).toList(),
    };
  }

  static Map<String, dynamic> _section(Map<String, dynamic> map, String key) {
    return Map<String, dynamic>.from(map[key] as Map);
  }

  static List<Map<String, dynamic>> _rows(Map<String, dynamic> map, String key) {
    return (map[key] as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
  }
}
