import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/activity_day.dart';
import '../models/backup_document.dart';
import '../models/checklist_entry.dart';
import '../models/daily_task.dart';
import '../models/export_file.dart';
import '../models/notification_preferences.dart';
import '../models/savings_transaction.dart';
import '../models/sleep_log.dart';
import '../models/task_reminder.dart';
import '../models/task_snapshot.dart';
import '../models/user_profile.dart';
import 'savings_repository.dart';
import 'streak_repository.dart';
import '../utils/activity_calculator.dart';
import '../utils/export_formatter.dart';
import '../utils/task_progress.dart';

class ExportRepository {
  static const int directPageSize = 500;
  static const int savingsPageSize = 200;
  static const int sleepPageSize = 500;

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

  Future<BackupDocument> exportAllData() async {
    final uid = _requireUid();
    final exportedAt = DateTime.now();

    final profileRow = await _fetchProfileRow(uid);
    final tasks = await _fetchTasks(uid);
    final checklists = await _fetchChecklists(uid);
    final snapshots = await _fetchSnapshots(uid);
    final sleepLogs = await _fetchSleepLogs();
    final savings = await _fetchSavings();
    final reminders = await _fetchReminders();

    final streakInfo = await StreakRepository().getStreakInfo();
    final totalSavings = await SavingsRepository().getCurrentBalance();

    DateTime? firstActivity;
    DateTime? lastActivity;
    for (final snapshot in snapshots) {
      if (firstActivity == null || snapshot.checkDate.isBefore(firstActivity)) {
        firstActivity = snapshot.checkDate;
      }
      if (lastActivity == null || snapshot.checkDate.isAfter(lastActivity)) {
        lastActivity = snapshot.checkDate;
      }
    }

    return BackupDocument(
      userId: uid,
      email: _client.auth.currentUser?.email,
      exportedAt: exportedAt,
      profile: UserProfile.fromMap(profileRow),
      preferences: NotificationPreferences.fromMap(profileRow),
      summary: BackupSummary(
        currentStreak: streakInfo.currentStreak,
        totalSavings: totalSavings,
        taskCount: tasks.length,
        checklistCount: checklists.length,
        taskSnapshotCount: snapshots.length,
        sleepLogCount: sleepLogs.length,
        savingsTransactionCount: savings.length,
        reminderCount: reminders.length,
        firstActivityDate:
            firstActivity == null ? null : TaskProgress.dateKey(firstActivity),
        lastActivityDate:
            lastActivity == null ? null : TaskProgress.dateKey(lastActivity),
      ),
      tasks: tasks,
      checklists: checklists,
      taskSnapshots: snapshots,
      sleepLogs: sleepLogs,
      savingsTransactions: savings,
      reminders: reminders,
    );
  }

  Future<ExportFile> exportAsJson() async {
    final document = await exportAllData();
    final content = ExportFormatter.encodeBackupJson(document.toMap());
    return ExportFile(
      type: ExportType.jsonBackup,
      fileName: ExportFormatter.backupFileName(document.exportedAt),
      content: content,
      mimeType: ExportType.jsonBackup.mimeType,
      recordCount: document.summary.totalRecordCount,
    );
  }

  Future<ExportFile> exportTasksCsv() async {
    final uid = _requireUid();
    final snapshots = await _fetchSnapshots(uid);
    final exportedAt = DateTime.now();
    return ExportFile(
      type: ExportType.tasksCsv,
      fileName: ExportFormatter.csvFileName(ExportType.tasksCsv.dataset, exportedAt),
      content: ExportFormatter.tasksCsv(snapshots),
      mimeType: ExportType.tasksCsv.mimeType,
      recordCount: snapshots.length,
    );
  }

  Future<ExportFile> exportSleepCsv() async {
    _requireUid();
    final logs = await _fetchSleepLogs();
    final exportedAt = DateTime.now();
    return ExportFile(
      type: ExportType.sleepCsv,
      fileName: ExportFormatter.csvFileName(ExportType.sleepCsv.dataset, exportedAt),
      content: ExportFormatter.sleepCsv(logs),
      mimeType: ExportType.sleepCsv.mimeType,
      recordCount: logs.length,
    );
  }

  Future<ExportFile> exportSavingsCsv() async {
    _requireUid();
    final transactions = await _fetchSavings();
    final exportedAt = DateTime.now();
    return ExportFile(
      type: ExportType.savingsCsv,
      fileName: ExportFormatter.csvFileName(ExportType.savingsCsv.dataset, exportedAt),
      content: ExportFormatter.savingsCsv(transactions),
      mimeType: ExportType.savingsCsv.mimeType,
      recordCount: transactions.length,
    );
  }

  Future<ExportFile> exportActivityCsv() async {
    final uid = _requireUid();
    final snapshots = await _fetchSnapshots(uid);
    final exportedAt = DateTime.now();

    DateTime? first;
    DateTime? last;
    for (final snapshot in snapshots) {
      if (first == null || snapshot.checkDate.isBefore(first)) {
        first = snapshot.checkDate;
      }
      if (last == null || snapshot.checkDate.isAfter(last)) {
        last = snapshot.checkDate;
      }
    }

    final List<ActivityDay> days;
    if (first == null || last == null) {
      days = const [];
    } else {
      days = ActivityCalculator.buildDays(
        firstDay: TaskProgress.normalize(first),
        lastDay: TaskProgress.normalize(last),
        snapshots: snapshots,
        includeTaskDetails: false,
      );
    }

    return ExportFile(
      type: ExportType.activityCsv,
      fileName: ExportFormatter.csvFileName(ExportType.activityCsv.dataset, exportedAt),
      content: ExportFormatter.activityCsv(days),
      mimeType: ExportType.activityCsv.mimeType,
      recordCount: days.length,
    );
  }

  Future<Map<String, dynamic>> _fetchProfileRow(String uid) async {
    final data = await _client
        .from('profiles')
        .select()
        .eq('id', uid)
        .maybeSingle();
    if (data == null) {
      throw AuthException('Profile tidak ditemukan.');
    }
    return _asMap(data);
  }

  Future<List<DailyTask>> _fetchTasks(String uid) async {
    final rows = await _selectPaged(
      'user_tasks',
      uid: uid,
      orderBy: const ['position', 'created_at'],
    );
    return rows.map(DailyTask.fromMap).toList();
  }

  Future<List<ChecklistEntry>> _fetchChecklists(String uid) async {
    final rows = await _selectPaged(
      'task_checklists',
      uid: uid,
      orderBy: const ['check_date', 'task_id'],
    );
    return rows.map(ChecklistEntry.fromMap).toList();
  }

  Future<List<TaskSnapshot>> _fetchSnapshots(String uid) async {
    final rows = await _selectPaged(
      'task_daily_snapshots',
      uid: uid,
      orderBy: const ['check_date', 'position', 'task_id'],
    );
    return rows.map(TaskSnapshot.fromMap).toList();
  }

  Future<List<SleepLog>> _fetchSleepLogs() async {
    final rows = await _rpcPaged('sleep_list_my', pageSize: sleepPageSize);
    return rows.map(SleepLog.fromMap).toList();
  }

  Future<List<SavingsTransaction>> _fetchSavings() async {
    final rows = await _rpcPaged('savings_list_my', pageSize: savingsPageSize);
    return rows.map(SavingsTransaction.fromMap).toList();
  }

  Future<List<TaskReminder>> _fetchReminders() async {
    final data = await _client.rpc('reminder_list_my');
    return (data as List)
        .map((row) => TaskReminder.fromMap(_asMap(row)))
        .toList();
  }

  Future<List<Map<String, dynamic>>> _selectPaged(
    String table, {
    required String uid,
    required List<String> orderBy,
    int pageSize = directPageSize,
  }) async {
    final all = <Map<String, dynamic>>[];
    var offset = 0;
    while (true) {
      dynamic query = _client.from(table).select().eq('user_id', uid);
      for (final column in orderBy) {
        query = query.order(column, ascending: true);
      }
      final batch = await query.range(offset, offset + pageSize - 1) as List;
      final page = batch.map(_asMap).toList();
      all.addAll(page);
      if (page.length < pageSize) break;
      offset += pageSize;
    }
    return all;
  }

  Future<List<Map<String, dynamic>>> _rpcPaged(
    String function, {
    required int pageSize,
  }) async {
    final all = <Map<String, dynamic>>[];
    var offset = 0;
    while (true) {
      final data = await _client.rpc(function, params: {
        'p_limit': pageSize,
        'p_offset': offset,
      });
      final page = (data as List).map(_asMap).toList();
      all.addAll(page);
      if (page.length < pageSize) break;
      offset += pageSize;
    }
    return all;
  }
}
